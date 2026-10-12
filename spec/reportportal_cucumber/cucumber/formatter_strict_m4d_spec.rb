# frozen_string_literal: true

require "spec_helper"
require "digest"
require "json"
require "open3"
require "rbconfig"

RSpec.describe "M4-D native formatter strict business precedence" do
  def native_case(strict:, business_failed:, early: false)
    root = File.expand_path("../../..", __dir__)
    evidence = ENV["M4_FORMATTER_STRICT_EVIDENCE"]
    FileUtils.mkdir_p(evidence) if evidence
    directory = Dir.mktmpdir("m4d-native-strict-", evidence)
    feature = File.join(directory, "business.feature")
    steps = File.join(directory, "steps.rb")
    runner = File.join(directory, "runner.rb")
    capture = File.join(directory, "capture.json")
    progress = File.join(directory, "progress.txt")
    File.write(feature, <<~FEATURE)
      Feature: strict reporting preserves the completed business outcome
        Scenario: the original action controls business failure
          When I complete the strict precedence action
    FEATURE
    File.write(steps, <<~RUBY)
      #{early ? 'Before { true }' : ''}
      When("I complete the strict precedence action") do
        $m4d_business_executed = true
        $m4d_business_failure = #{business_failed}
        #{business_failed ? '$m4d_original = RuntimeError.new("Original M4-D native business assertion"); raise $m4d_original' : 'true'}
      end
    RUBY
    File.write(runner, <<~'RUBY')
      require "digest"
      require "json"
      require "stringio"
      require "webmock"
      require "reportportal_cucumber"
      require "cucumber/cli/main"
      root, feature, steps, capture, progress, mode = ARGV
      require File.join(root, "spec/support/rp_mock_server")

      class M4DStrictKernel
        def exit(code = 0) = throw(:m4d_strict_exit, code)
        def exit!(code = 0) = throw(:m4d_strict_exit, code)
      end
      probe = Module.new do
        def initialize(*)
          super
          $m4d_formatter = self
        end

        def handle_test_step_finished(event)
          if $m4d_original && send(:extract_status, event) == "failed"
            $m4d_native_same_exception = send(:extract_error, event).equal?($m4d_original)
          end
          super
        end
      end
      ReportportalCucumber::Cucumber::Formatter.prepend(probe)
      WebMock.enable!
      WebMock.disable_net_connect!
      endpoint = ENV.fetch("RP_ENDPOINT")
      server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
      faults = []
      WebMock.stub_request(:put, %r{\A#{Regexp.escape(endpoint)}/api/v1/strict/item/[^/]+\z})
        .with do |request|
          item = server.item_requests.find { |entry| entry.fetch("responseUuid") == request.uri.path.split("/").last }
          item && (mode == "early" ? !$m4d_business_executed && item.fetch("type") == "BEFORE_METHOD" :
            $m4d_business_executed && item.fetch("name") == "When I complete the strict precedence action")
        end.to_return do |request|
          item = server.item_requests.find { |entry| entry.fetch("responseUuid") == request.uri.path.split("/").last }
          faults << { name: item.fetch("name"), body: JSON.parse(request.body),
                      business_executed: !!$m4d_business_executed, business_failure: !!$m4d_business_failure }
          { status: 503, body: '{"message":"controlled action finish failure"}' }
        end
      errors = StringIO.new
      output = StringIO.new
      status = nil
      begin
        args = ["--require", File.join(root, "lib/reportportal_cucumber.rb"), "--require", steps,
                "--format", "progress", "--out", progress,
                "--format", "ReportPortal::Cucumber::Formatter", "--out", progress + ".rp", feature]
        status = catch(:m4d_strict_exit) { Cucumber::Cli::Main.new(args, output, errors, M4DStrictKernel.new).execute! } || 0
      ensure
        loaded = $LOADED_FEATURES.select { |path| path.include?("reportportal_cucumber") && File.file?(path) }
        File.write(capture, JSON.pretty_generate(
          status: status, business_executed: !!$m4d_business_executed, business_failure: !!$m4d_business_failure,
          native_same_exception: $m4d_native_same_exception, faults: faults, errors: errors.string,
          receipt: $m4d_formatter&.reporting_receipt&.to_h,
          cucumber_version: Gem.loaded_specs.fetch("cucumber").version.to_s,
          loaded_sdk: loaded.to_h { |path| [File.realpath(path), Digest::SHA256.file(path).hexdigest] }
        ))
      end
      exit(status)
    RUBY
    env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
      "RP_ENDPOINT" => "https://rp-strict.example.test", "RP_PROJECT" => "strict", "RP_API_KEY" => "synthetic-token",
      "RP_CLIENT_JOIN" => "false", "RP_HTTP_RETRY_ATTEMPTS" => "1", "RP_EXIT_FLUSH_TIMEOUT_MS" => "500",
      "RP_FAIL_ON_REPORTING_ERROR" => strict.to_s, "RP_SPOOL_DIR" => File.join(directory, "spool"),
      "CUCUMBER_PROFILE" => nil
    )
    stdout, stderr, process = Open3.capture3(env, "perl", "-e", "alarm 20; exec @ARGV", RbConfig.ruby,
                                           "-I#{File.join(root, 'lib')}", runner, root, feature, steps, capture, progress,
                                           early ? "early" : "action", chdir: directory)
    File.write(File.join(directory, "child.stdout"), stdout)
    File.write(File.join(directory, "child.stderr"), stderr)
    expect(File.file?(capture)).to be(true), "Native child produced no capture: #{stderr}"
    result = JSON.parse(File.read(capture))
    formatter_path = File.join(File.realpath(root), "lib/reportportal_cucumber/cucumber/formatter.rb")
    expect(result.fetch("loaded_sdk").fetch(formatter_path)).to eq(Digest::SHA256.file(formatter_path).hexdigest)
    parent_version = Gem.loaded_specs.fetch("cucumber").version
    expect(parent_version).to be >= Gem::Version.new("9.0")
    expect(parent_version).to be < Gem::Version.new("11.0")
    expect(result.fetch("cucumber_version")).to eq(parent_version.to_s)
    result.merge("process_status" => process.exitstatus, "console" => stdout + stderr,
                 "progress" => File.file?(progress) ? File.read(progress) : "")
  ensure
    FileUtils.remove_entry(directory) if directory && !evidence
  end

  [false, true].each do |strict|
    it "keeps native business exit 1 and its original exception when completed-action PUT 503 occurs with strict #{strict}" do
      result = native_case(strict: strict, business_failed: true)

      expect(result).to include("business_executed" => true, "business_failure" => true, "native_same_exception" => true)
      expect(result.fetch("faults")).not_to be_empty
      expect(result.fetch("faults")).to all(include("business_executed" => true, "business_failure" => true,
                                                   "body" => include("status" => "failed")))
      expect(result.fetch("process_status")).to eq(1)
      expect(result.fetch("status")).to eq(1)
      expect(result.fetch("progress")).to include("Original M4-D native business assertion", "1 scenario (1 failed)")
      expect(result.fetch("console")).to include("HTTP 503", "ReportPortal reporting incomplete:", "business=failed")
      expect(result.fetch("receipt")).to include("complete" => false)
    end
  end

  it "keeps strict opt-in native exit 2 for a reporting error after an otherwise-passing action" do
    result = native_case(strict: true, business_failed: false)

    expect(result).to include("business_executed" => true, "business_failure" => false, "status" => 2, "process_status" => 2)
    expect(result.fetch("faults")).not_to be_empty
    expect(result.fetch("faults").first.fetch("body")).to include("status" => "passed")
    expect(result.fetch("errors")).to include("HTTP 503")
  end

  it "does not swallow an early strict Before-hook reporting failure before any business exception exists" do
    result = native_case(strict: true, business_failed: false, early: true)

    expect(result).to include("business_executed" => false, "business_failure" => false, "status" => 2, "process_status" => 2)
    expect(result.fetch("faults")).not_to be_empty
    expect(result.fetch("faults").first).to include("business_executed" => false, "body" => include("status" => "passed"))
    expect(result.fetch("errors")).to include("HTTP 503")
  end
end
