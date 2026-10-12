# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rbconfig"

RSpec.describe "Native per-context log ownership" do
  # @param duplicate [Boolean]
  # @param after_failure [Boolean]
  # @return [Hash]
  def native_ownership(duplicate:, after_failure: false)
    root = File.expand_path("../../..", __dir__)
    Dir.mktmpdir("context-native-ownership-") do |directory|
      feature = File.join(directory, "ownership.feature")
      steps = File.join(directory, "steps.rb")
      runner = File.join(directory, "runner.rb")
      capture = File.join(directory, "capture.json")
      File.write(feature, <<~FEATURE)
        Feature: independent formatter ownership
          Scenario: evidence stays with its original launch and action
            When I publish owned evidence through every supported route
      FEATURE
      File.write(steps, <<~'RUBY')
        World(ReportportalCucumber::Cucumber::World)
        BeforeAll { $owner_hooks << { run: $owner_run, hook: "before" } }
        Before { AppLog.bind(self, color: false) }
        After do
          ($owner_targets || []).each do |formatter, target|
            $owner_late << formatter.report_evidence(action: "late", error: "synthetic", target: target)
          end
          AppLog.clear!
        end
        AfterAll do
          $owner_hooks << { run: $owner_run, hook: "after" }
          raise "OWNERSHIP_ORIGINAL_AFTERALL_FAILURE" if $owner_after_failure
        end
        When("I publish owned evidence through every supported route") do
          $owner_business << $owner_run
          $owner_rp_active << { run: $owner_run, active: AppLog.logger.rp_active? }
          owners = $owner_formatters.select { |entry| entry.fetch(:run) == $owner_run }.map { |entry| entry.fetch(:formatter) }
          $owner_targets = owners.map { |formatter| [formatter, formatter.capture_target] }
          AppLog.info("OWNED_APPLOG_#{$owner_run}", attach: true, file: $owner_file)
          if respond_to?(:rp_log)
            rp_log("OWNED_RP_LOG_#{$owner_run}", mirror: false)
            rp_attach("rp-attachment-bytes-#{$owner_run}", name: "rp-attachment.txt", mime: "text/plain",
                      message: "OWNED_RP_ATTACH_#{$owner_run}")
          end
          helpers = $owner_targets.each_with_index.map do |(formatter, target), index|
            own_item = formatter.runtime_context.validate_capture_target(target, launch_uuid: formatter.instance_variable_get(:@launch_uuid))
            raise "missing own capture target" unless own_item
            Thread.new do
              accepted = formatter.report_evidence(action: "OWNED_HELPER_#{$owner_run}_#{index}", error: RuntimeError.new("synthetic"),
                target: target, artifacts: [{ name: "helper-#{index}.txt", mime: "text/plain", bytes: "helper-bytes-#{$owner_run}-#{index}" }])
              other = $owner_targets[(index + 1) % $owner_targets.length]
              foreign = if owners.length > 1
                          formatter.report_evidence(action: "FOREIGN_MUST_NOT_PUBLISH", error: "synthetic", target: other.last)
                        else
                          false
                        end
              $owner_helper_results << { run: $owner_run, owner: index, accepted: accepted, foreign: foreign,
                                         item_uuid: own_item.uuid, launch_uuid: formatter.instance_variable_get(:@launch_uuid) }
            end
          end
          helpers.each { |helper| raise "helper publication hung" unless helper.join(2) }
        end
      RUBY
      File.write(runner, <<~'RUBY')
        require "json"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require "cucumber/cli/main"
        require "cucumber/formatter/message"
        root, feature, steps, capture, count, failure = ARGV
        require File.join(root, "spec/support/rp_mock_server")
        $owner_after_failure = failure == "true"
        $owner_formatters = []
        $owner_hooks = []
        $owner_business = []
        $owner_helper_results = Queue.new
        $owner_late = []
        $owner_rp_active = []
        $owner_completion = []
        $owner_admissions = Queue.new
        ReportportalCucumber::Runtime::LogBuffer.prepend(Module.new do
          def emit_log(**options)
            $owner_admissions << object_id
            super
          end
        end)
        $owner_native_messages = Hash.new { |hash, run| hash[run] = [] }
        Cucumber::Formatter::Message.prepend(Module.new do
          def output_envelope(envelope)
            $owner_native_messages[$owner_run] << envelope.to_json
            super
          end
        end)
        $owner_file = File.join(File.dirname(capture), "native-file.txt")
        File.write($owner_file, "native-attachment-bytes")
        class ContextOwnershipFormatter < ReportportalCucumber::Cucumber::Formatter
          def initialize(config)
            super
            $owner_formatters << { formatter: self, run: $owner_run }
          end

          # @param error [Exception, nil]
          # @return [void]
          def complete_native_run(error: nil)
            super
          ensure
            $owner_completion << { run: $owner_run, owner: @launch_uuid,
                                   active: ReportportalCucumber.current_runtime&.instance_variable_get(:@launch_uuid) }
          end
        end
        class ContextOwnershipCli < Cucumber::Cli::Main
          attr_reader :observed_runtime
          private
          def runtime(existing = nil)
            @observed_runtime = super
          end
        end
        kernel = Class.new do
          def exit(code = 0) = throw(:ownership_exit, code)
          def exit!(code = 0) = throw(:ownership_exit, code)
        end.new
        WebMock.enable!
        WebMock.disable_net_connect!
        server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: ENV.fetch("RP_ENDPOINT")).install!
        outgoing = []
        wire_mutex = Mutex.new
        WebMock.after_request do |request, _response|
          next unless request.method == :post && request.uri.path.end_with?("/log")
          entries = if request.headers.fetch("Content-Type", "").include?("multipart/")
                      server.send(:parse_multipart, request).fetch(:entries)
                    else
                      body = JSON.parse(request.body)
                      body.is_a?(Array) ? body : [body]
                    end
          wire_mutex.synchronize { outgoing.concat(entries) }
        end
        statuses = []
        runtimes = []
        unformatted_native = nil
        unformatted_start = nil
        before_unformatted_receipts = nil
        before_unformatted_admissions = nil
        3.times do |run|
          $owner_run = run
          $LOADED_FEATURES.delete(steps)
          output = StringIO.new
          errors = StringIO.new
          messages = File.join(File.dirname(capture), "messages-#{run}.ndjson")
          args = ["--no-profile", "--require", steps, "--format", "message", "--out", messages]
          if run < 2
            Integer(count).times do |index|
              args.concat(["--format", "ContextOwnershipFormatter", "--out", File.join(File.dirname(capture), "rp-#{run}-#{index}.txt")])
            end
          else
            unformatted_start = outgoing.length
            before_unformatted_receipts = $owner_formatters.map { |entry| entry.fetch(:formatter).reporting_receipt.to_h }
            before_unformatted_admissions = $owner_admissions.length
          end
          args << feature
          cli = ContextOwnershipCli.new(args, output, errors, kernel)
          status = catch(:ownership_exit) { cli.execute!; 0 }
          runtime = cli.observed_runtime
          statuses << { run: run, status: status, errors: errors.string }
          runtimes << { runtime: runtime.object_id, event_bus: runtime.configuration.event_bus.object_id,
                        registry: runtime.support_code.registry.object_id,
                        observers: Array(runtime.support_code.registry.instance_variable_get(:@reportportal_native_lifecycle_formatters)).length }
          unformatted_native = $owner_native_messages.fetch(run).join("\n") if run == 2
        end
        helpers = []
        helpers << $owner_helper_results.pop(true) until $owner_helper_results.empty?
        File.write(capture, JSON.pretty_generate(
          cucumber: Gem.loaded_specs.fetch("cucumber").version.to_s, business: $owner_business, hooks: $owner_hooks,
          statuses: statuses, runtimes: runtimes, helpers: helpers, late: $owner_late,
          before_unformatted_receipts: before_unformatted_receipts,
          unformatted_admission_attempts: $owner_admissions.length - before_unformatted_admissions,
          rp_active: $owner_rp_active, completion: $owner_completion,
          outgoing: outgoing, items: server.item_requests, multipart: server.multipart_requests,
          unformatted_log_count: outgoing.length - unformatted_start, unformatted_native: unformatted_native,
          mirror_stack: Thread.current[:rp_context_stack],
          formatters: $owner_formatters.map do |entry|
            formatter = entry.fetch(:formatter)
            { run: entry.fetch(:run), launch_uuid: formatter.instance_variable_get(:@launch_uuid),
              receipt: formatter.reporting_receipt.to_h,
              execution_states: formatter.runtime_context.instance_variable_get(:@thread_states).length }
          end
        ))
      RUBY
      env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
        "RP_ENDPOINT" => "https://context-ownership.example.test", "RP_PROJECT" => "ownership", "RP_API_KEY" => "synthetic",
        "RP_ENABLED" => "true", "RP_CLIENT_JOIN" => "false", "RP_HTTP_RETRY_ATTEMPTS" => "1",
        "RP_EXIT_FLUSH_TIMEOUT_MS" => "1000", "RP_BATCH_SIZE_LOGS" => "20", "RP_REQUIRE_COMPLETE_REPORTING" => "false",
        "RP_SPOOL_DIR" => File.join(directory, "spool"), "CUCUMBER_PROFILE" => nil
      )
      stdout, stderr, process = Open3.capture3(env, "perl", "-e", "alarm 20; exec @ARGV", RbConfig.ruby,
                                             "-I#{File.join(root, 'lib')}", runner, root, feature, steps, capture,
                                             duplicate ? "2" : "1", after_failure.to_s, chdir: directory)
      expect(process.success?).to be(true), "Native ownership child failed: #{stdout}\n#{stderr}"
      expect(File.file?(capture)).to be(true)
      JSON.parse(File.read(capture))
    end
  end

  # @param result [Hash]
  # @param count [Integer]
  # @return [void]
  def verify_native_owners(result, count:)
    expect(result.fetch("cucumber")).to eq(Gem.loaded_specs.fetch("cucumber").version.to_s)
    expect(Gem::Version.new(result.fetch("cucumber"))).to be < Gem::Version.new("11")
    expect(result.fetch("business")).to eq([0, 1, 2])
    expect(result.fetch("hooks")).to eq(3.times.flat_map { |run| [{ "run" => run, "hook" => "before" }, { "run" => run, "hook" => "after" }] })
    expect(result.fetch("runtimes").map { |runtime| runtime.fetch("event_bus") }.uniq.length).to eq(3)
    expect(result.fetch("runtimes").map { |runtime| runtime.fetch("registry") }.uniq.length).to eq(3)
    expect(result.fetch("runtimes").map { |runtime| runtime.fetch("observers") }).to eq([count, count, 0])
    expect(result.fetch("unformatted_log_count")).to eq(0)
    expect(result.fetch("unformatted_admission_attempts")).to eq(0)
    expect(result.fetch("formatters").map { |entry| entry.fetch("receipt") }).to eq(result.fetch("before_unformatted_receipts"))
    expect(result.fetch("rp_active").map { |entry| entry.fetch("active") }).to eq([true, true, false])
    expect(result.fetch("unformatted_native")).to include("OWNED_APPLOG_2")
    expect(result.fetch("mirror_stack")).to be_empty
    expect(result.fetch("helpers").length).to eq(count * 2)
    expect(result.fetch("helpers").map { |entry| entry.fetch("accepted") }).to all(be(true))
    expect(result.fetch("helpers").map { |entry| entry.fetch("foreign") }).to all(be(false))
    expect(result.fetch("late")).to eq([false] * (count * 2))
    expect(result.fetch("formatters").length).to eq(count * 2)
    expect(result.fetch("formatters").map { |entry| entry.fetch("execution_states") }).to all(eq(0))
    item_mapping = result.fetch("items").to_h { |request| [request.fetch("responseUuid"), request.fetch("body")] }
    result.fetch("outgoing").each do |log|
      next unless log["itemUuid"]

      item = item_mapping.fetch(log.fetch("itemUuid"))
      expect(log.fetch("launchUuid")).to eq(item.fetch("launchUuid")), "Log/start owner mismatch: #{log} vs #{item}"
    end
    2.times do |run|
      owners = result.fetch("formatters").select { |entry| entry.fetch("run") == run }
      expect(owners.map { |owner| owner.fetch("launch_uuid") }.uniq.length).to eq(count)
      completion = result.fetch("completion").select { |entry| entry.fetch("run") == run }
      expect(completion.map { |entry| entry.fetch("owner") }).to eq(owners.map { |owner| owner.fetch("launch_uuid") })
      expect(completion.map { |entry| entry.fetch("active") }).to eq(count == 2 ? [owners.last.fetch("launch_uuid"), nil] : [nil])
      owners.each_with_index do |owner, index|
        logs = result.fetch("outgoing").select { |log| log.fetch("launchUuid") == owner.fetch("launch_uuid") }
        expect(logs.count { |log| log.fetch("message").include?("OWNED_APPLOG_#{run}") }).to eq(1)
        helper = result.fetch("helpers").find { |entry| entry.fetch("run") == run && entry.fetch("owner") == index }
        expect(helper.fetch("launch_uuid")).to eq(owner.fetch("launch_uuid"))
        helper_logs = logs.select { |log| log.fetch("message").include?("OWNED_HELPER_#{run}_#{index}") }
        expect(helper_logs.length).to eq(1)
        expect(helper_logs.first.fetch("itemUuid")).to eq(helper.fetch("item_uuid"))
        expect(logs.filter_map { |log| log["itemUuid"] }).to all(eq(helper.fetch("item_uuid")))
        expect(item_mapping.fetch(helper.fetch("item_uuid")).fetch("name")).to include("I publish owned evidence")
        expect(logs.count { |log| log.fetch("message").include?("OWNED_RP_LOG_#{run}") }).to eq(index == count - 1 ? 1 : 0)
        expect(logs.count { |log| log.fetch("message").include?("OWNED_RP_ATTACH_#{run}") }).to eq(index == count - 1 ? 1 : 0)
        expect(owner.dig("receipt", "complete")).to be(true)
        expect(owner.dig("receipt", "confirmed")).to eq(logs.length)
      end
    end
    expect(result.fetch("outgoing").none? { |log| log.fetch("message").include?("FOREIGN_MUST_NOT_PUBLISH") }).to be(true)
    files = result.fetch("multipart").flat_map { |part| part.fetch("files") }
    expect(files.count { |file| file.fetch("bytes") == "native-attachment-bytes" }).to eq(count * 2)
    2.times do |run|
      expect(files.count { |file| file.fetch("bytes") == "rp-attachment-bytes-#{run}" }).to eq(1)
      count.times do |index|
        expect(files.count { |file| file.fetch("bytes") == "helper-bytes-#{run}-#{index}" }).to eq(1)
      end
    end
  end

  it "pairs both real duplicate formatter owners across sequential runs and a subsequent unformatted event bus" do
    result = native_ownership(duplicate: true)
    verify_native_owners(result, count: 2)
    expect(result.fetch("statuses").map { |entry| entry.fetch("status") }).to eq([0, 0, 0])
  end

  it "keeps the single formatter route and unformatted control paired correctly" do
    result = native_ownership(duplicate: false)
    verify_native_owners(result, count: 1)
    expect(result.fetch("statuses").map { |entry| entry.fetch("status") }).to eq([0, 0, 0])
  end

  it "retains each duplicate owner's evidence when native AfterAll genuinely fails" do
    result = native_ownership(duplicate: true, after_failure: true)
    verify_native_owners(result, count: 2)
    expect(result.fetch("statuses").map { |entry| entry.fetch("status") }).to eq([2, 2, 2])
    diagnostics = result.fetch("outgoing").select { |log| log.fetch("message").include?("OWNERSHIP_ORIGINAL_AFTERALL_FAILURE") }
    expect(diagnostics.length).to eq(4)
    expect(diagnostics).to all(include("level" => "error"))
    expect(diagnostics.map { |log| log["itemUuid"] }).to all(be_nil)
  end
end
