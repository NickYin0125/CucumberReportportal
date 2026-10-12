# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rbconfig"

RSpec.describe "Native capture publication under saturation" do
  # @param mode [String]
  # @param require_complete [Boolean]
  # @return [Hash]
  def run_native(mode, require_complete: false)
    root = File.expand_path("../../..", __dir__)
    Dir.mktmpdir("native-capture-publication-") do |directory|
      feature = File.join(directory, "capture.feature")
      steps = File.join(directory, "steps.rb")
      runner = File.join(directory, "runner.rb")
      result = File.join(directory, "result.json")
      File.write(feature, <<~FEATURE)
        Feature: bounded evidence publication
          Scenario: helper evidence retains the original owner
            When I saturate reporting and publish evidence
            Then a late target cannot attach to this step
      FEATURE
      File.write(steps, <<~'RUBY')
        When("I saturate reporting and publish evidence") do
          formatter = $capture_formatter
          $capture_target = formatter.capture_target
          $capture_item = formatter.runtime_context.current_step_item.uuid
          unless $capture_mode == "partial"
            formatter.emit_world_log(message: "already accepted", level: :info, timestamp: Time.now)
            Timeout.timeout(2) { $backend_entered.pop }
          end
          count = $capture_mode == "oversized" ? 17 : 12
          artifacts = count.times.map { |index| { name: "artifact-#{index}.txt", mime: "text/plain", bytes: "bytes-#{index}" } }
          $capture_helper = Thread.new do
            $capture_result = formatter.report_evidence(action: "original action", error: RuntimeError.new("synthetic"),
                                                       artifacts: artifacts, target: $capture_target)
          end
          Timeout.timeout(2) { $backend_entered.pop } if $capture_mode == "partial"
          if $capture_mode == "oversized"
            raise "oversized publication hung" unless $capture_helper.join(0.5)
          else
            Timeout.timeout(2) { $admission_entered.pop }
          end
        end

        Then("a late target cannot attach to this step") do
          raise "helper retained full per-artifact delay" unless $capture_helper.join(0.2)
          $late_result = $capture_formatter.report_evidence(action: "late", error: RuntimeError.new("late"),
                                                          target: $capture_target)
          $late_item = $capture_formatter.runtime_context.current_step_item.uuid
          $business_executed = true
        end
      RUBY
      File.write(runner, <<~'RUBY')
        require "json"
        require "stringio"
        require "timeout"
        require "webmock"
        require "reportportal_cucumber"
        require "cucumber/cli/main"
        root, feature, steps, result, $capture_mode = ARGV
        require File.join(root, "spec/support/rp_mock_server")
        $backend_entered = Queue.new
        $backend_release = Queue.new
        $admission_entered = Queue.new
        $close_elapsed = []
        $finalization_elapsed = []
        ReportportalCucumber::Cucumber::Formatter.prepend(Module.new do
          def initialize(*)
            super
            $capture_formatter = self
          end

          def finalize_reporting(**options)
            started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            super
          ensure
            $finalization_elapsed << Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          end
        end)
        ReportportalCucumber::Runtime::Context.prepend(Module.new do
          def close_capture_target_for_item(*args, **options)
            started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            super
          ensure
            $close_elapsed << Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          end
        end)
        ReportportalCucumber::Service::QueueProcessor.prepend(Module.new do
          def emit_log(**options)
            if options[:cancelled] && ($capture_mode != "partial" || options[:attachment])
              original = options.fetch(:cancelled)
              options[:cancelled] = -> { value = original.call; $admission_entered << true unless value; value }
            end
            super(**options)
          end
        end)
        ReportportalCucumber::ReportPortal::API.prepend(Module.new do
          def log_batch_result(**options)
            $backend_entered << true
            $backend_release.pop
            super
          end
        end)
        WebMock.enable!
        WebMock.disable_net_connect!
        server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: ENV.fetch("RP_ENDPOINT")).install!
        kernel = Class.new do
          def exit(code = 0) = throw(:capture_exit, code)
          def exit!(code = 0) = throw(:capture_exit, code)
        end.new
        args = ["--require", File.join(root, "lib/reportportal_cucumber.rb"), "--require", steps,
                "--format", "ReportPortal::Cucumber::Formatter", feature]
        output = StringIO.new
        errors = StringIO.new
        status = catch(:capture_exit) { Cucumber::Cli::Main.new(args, output, errors, kernel).execute! } || 0
        before = $capture_formatter.reporting_receipt.to_h
        4.times { $backend_release << true }
        $capture_helper&.join(2)
        $capture_formatter.instance_variable_get(:@log_buffer).shutdown(timeout: 2)
        File.write(result, JSON.pretty_generate(
          status: status, helper_result: $capture_result, helper_alive: $capture_helper&.alive?,
          late_result: $late_result, original_item: $capture_item, late_item: $late_item,
          business_executed: $business_executed, close_elapsed: $close_elapsed,
          finalization_elapsed: $finalization_elapsed, before: before,
          receipt: $capture_formatter.reporting_receipt.to_h,
          diagnostics: $capture_formatter.reporting_diagnostics,
          logs: server.logs, cucumber_version: Gem.loaded_specs.fetch("cucumber").version.to_s,
          errors: errors.string
        ))
      RUBY
      env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
        "RP_ENDPOINT" => "https://native-capture.example.test", "RP_PROJECT" => "capture", "RP_API_KEY" => "synthetic",
        "RP_CLIENT_JOIN" => "false", "RP_HTTP_RETRY_ATTEMPTS" => "1", "RP_EXIT_FLUSH_TIMEOUT_MS" => "80",
        "RP_QUEUE_MAX_RECORDS" => "1", "RP_QUEUE_OVERFLOW_POLICY" => "block",
        "RP_QUEUE_ADMISSION_TIMEOUT_MS" => "1000", "RP_BATCH_SIZE_LOGS" => "1",
        "RP_REQUIRE_COMPLETE_REPORTING" => require_complete.to_s,
        "RP_SPOOL_DIR" => File.join(directory, "spool"), "CUCUMBER_PROFILE" => nil
      )
      stdout, stderr, process = Open3.capture3(env, "perl", "-e", "alarm 15; exec @ARGV", RbConfig.ruby,
                                             "-I#{File.join(root, 'lib')}", runner, root, feature, steps, result, mode,
                                             chdir: directory)
      expect(process.success?).to be(true), "Native child failed: #{stdout}\n#{stderr}"
      expect(File.file?(result)).to be(true)
      JSON.parse(File.read(result))
    end
  end

  it "bounds close/finalization and cancels every pending artifact without retargeting or accounting loss" do
    result = run_native("saturated")
    expect(Gem::Version.new(result.fetch("cucumber_version"))).to be < Gem::Version.new("11")
    expect(result.fetch("business_executed")).to be(true)
    expect(result.fetch("helper_alive")).to be(false)
    expect(result.fetch("helper_result")).to be(false)
    expect(result.fetch("late_result")).to be(false)
    expect(result.fetch("original_item")).not_to eq(result.fetch("late_item"))
    expect(result.fetch("close_elapsed")).to all(be < 0.15)
    expect(result.fetch("finalization_elapsed")).to all(be < 0.2)
    expect(result.dig("diagnostics", "counters", "accepted")).to eq(1)
    expect(result.dig("diagnostics", "counters", "rejected_closed")).to eq(13)
    expect(result.dig("diagnostics", "counters", "rejected_admission_timeout")).to eq(0)
    expect(result.dig("diagnostics", "current_records")).to eq(0)
    expect(result.dig("receipt", "confirmed")).to eq(1)
    expect(result.dig("receipt", "rejected")).to eq(13)
    expect(result.dig("receipt", "complete")).to be(false)
    expect(result.fetch("logs").map { |log| log.fetch("itemUuid") }).to eq([result.fetch("original_item")])
  end

  it "refuses an excessive batch explicitly without silently truncating or marking reporting complete" do
    result = run_native("oversized")
    expect(result.fetch("helper_result")).to be(false)
    expect(result.fetch("business_executed")).to be(true)
    expect(result.dig("diagnostics", "counters", "accepted")).to eq(1)
    expect(result.dig("diagnostics", "counters", "rejected_unsupported")).to eq(18)
    expect(result.dig("receipt", "confirmed")).to eq(1)
    expect(result.dig("receipt", "rejected")).to eq(18)
    expect(result.dig("receipt", "complete")).to be(false)
    expect(result.fetch("logs").length).to eq(1)
  end

  it "retains the admitted failure summary when close rejects its remaining binary artifacts" do
    result = run_native("partial")
    expect(result.fetch("helper_result")).to be(false)
    expect(result.fetch("business_executed")).to be(true)
    expect(result.dig("receipt", "confirmed")).to eq(1)
    expect(result.dig("receipt", "rejected")).to eq(12)
    expect(result.dig("diagnostics", "counters", "accepted")).to eq(1)
    expect(result.dig("diagnostics", "counters", "rejected_closed")).to eq(12)
    expect(result.fetch("logs").map { |log| log.fetch("itemUuid") }).to eq([result.fetch("original_item")])
    expect(result.fetch("logs").first.fetch("message")).to include("original action")
  end

  it "makes the strict reporting gate observe cancellation as incomplete reporting" do
    result = run_native("saturated", require_complete: true)
    expect(result.fetch("status")).not_to eq(0)
    expect(result.fetch("business_executed")).to be(true)
    expect(result.dig("receipt", "rejected")).to eq(13)
    expect(result.dig("receipt", "complete")).to be(false)
  end
end
