# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "production formatter lifecycle" do
  def native_case(fault: "none", complete: false, strict: false, business_failed: false,
                  hook_failure: nil, env_overrides: {}, mode: "single", directory: nil)
    root = File.expand_path("../../..", __dir__)
    owned_directory = directory.nil?
    directory ||= Dir.mktmpdir("rp-native-lifecycle-")
    feature = File.join(directory, "lifecycle.feature")
    steps = File.join(directory, "steps.rb")
    runner = File.join(directory, "runner.rb")
    capture = File.join(directory, "capture.json")
    File.write(feature, <<~FEATURE)
      Feature: genuine native lifecycle
        Scenario: business execution
          When the lifecycle business runs
    FEATURE
    File.write(steps, <<~RUBY)
      BeforeAll do
        $native_marks << "before_all"
        $native_threads_before = Thread.list.length
        if #{hook_failure == :before_all}
          $native_original = RuntimeError.new("ORIGINAL_BEFORE_ALL")
          raise $native_original
        end
      end
      When("the lifecycle business runs") do
        $native_marks << "business"
        $native_threads_business = Thread.list.length
        #{fault == "overflow" ? '10.times { rp_log("x" * 200, mirror: false) }' : 'rp_log("first", mirror: false); rp_log("second", mirror: false)'}
        if #{business_failed}
          $native_original = RuntimeError.new("ORIGINAL_BUSINESS")
          raise $native_original
        end
      end
      AfterAll do
        $native_marks << "after_all"
        $native_teardown_receipt = $native_formatter&.reporting_receipt&.to_h
        if #{hook_failure == :after_all}
          $native_original = RuntimeError.new("ORIGINAL_AFTER_ALL password=synthetic-private-value")
          raise $native_original
        end
      end
    RUBY
    File.write(runner, <<~'RUBY')
      require "bundler/setup"
      gem "cucumber", ">= 9", "< 11"
      require "json"
      require "stringio"
      require "webmock"
      require "reportportal_cucumber"
      require "cucumber/cli/main"
      root, feature, steps, capture, fault, mode = ARGV
      require File.join(root, "spec/support/rp_mock_server")
      $native_marks = []
      $native_formatters = []
      $native_completions = Hash.new(0)
      $native_join_constructions = 0
      ReportportalCucumber::Runtime::Join.singleton_class.prepend(Module.new do
        def new(...)
          $native_join_constructions += 1
          super
        end
      end)
      ReportportalCucumber::Cucumber::Formatter.prepend(Module.new do
        def initialize(*)
          super
          $native_formatter = self
          $native_formatters << self
          if ENV["LIFECYCLE_DUPLICATE_ATTACH"] == "true"
            2.times do
              ReportportalCucumber::Cucumber::NativeLifecycle.attach(cucumber_config: @cucumber_config, formatter: self)
            end
          end
        end

        def complete_native_run(error: nil)
          $native_completions[object_id] += 1
          $native_hook_exception_identity = error.equal?($native_original) if error
          super
        end

        def handle_test_step_finished(event)
          if $native_original && send(:extract_status, event) == "failed"
            $native_business_exception_identity = send(:extract_error, event).equal?($native_original)
          end
          super
        end
      end)
      class LifecycleRuntime < Cucumber::Runtime
        def run!
          super
        rescue Exception => original
          $native_run_exception_identity = original.equal?($native_original) if $native_original
          raise
        end
      end
      class LifecycleKernel
        def exit(code = 0) = throw(:native_exit, code)
        def exit!(code = 0) = throw(:native_exit, code)
      end
      class LifecycleCLI < Cucumber::Cli::Main
        private

        def runtime(_existing_runtime = nil)
          LifecycleRuntime.new(configuration)
        end
      end
      WebMock.enable!
      WebMock.disable_net_connect!
      endpoint = ENV["RP_ENDPOINT"] || "https://rp-lifecycle.example.test"
      server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
      if (uuid = ENV["RP_LAUNCH_UUID"])
        server.launches[uuid] = { "uuid" => uuid, "name" => "CI-owned existing launch", "items" => [], "status" => "IN_PROGRESS" }
      end
      if fault == "partial"
        WebMock.stub_request(:post, %r{\A#{Regexp.escape(endpoint)}/api/v1/lifecycle/log\z}).to_return(
          status: 200, body: '{"responses":[{"id":"confirmed"},{"message":"rejected"}]}'
        )
      elsif fault == "async"
        # Simulated v2 acknowledgements, explicitly not evidence of persistence.
        WebMock.stub_request(:post, %r{\A#{Regexp.escape(endpoint)}/api/v2/lifecycle/launch\z}).to_return do |request|
          body = JSON.parse(request.body)
          { status: 200, body: { id: body.fetch("uuid") }.to_json }
        end
        WebMock.stub_request(:post, %r{\A#{Regexp.escape(endpoint)}/api/v2/lifecycle/item(?:/[^/]+)?\z}).to_return do |request|
          body = JSON.parse(request.body)
          server.item_requests << body.merge("body" => body)
          { status: 200, body: { id: body.fetch("uuid") }.to_json }
        end
        WebMock.stub_request(:put, %r{\A#{Regexp.escape(endpoint)}/api/v2/lifecycle/(?:item/[^/]+|launch/[^/]+/finish)\z})
          .to_return(status: 200, body: '{"message":"accepted"}')
        WebMock.stub_request(:post, %r{\A#{Regexp.escape(endpoint)}/api/v2/lifecycle/log\z})
          .to_return(status: 202, body: '{"responses":[{"id":"accepted-1"},{"id":"accepted-2"}]}')
      elsif fault == "deadline"
        WebMock.stub_request(:put, %r{\A#{Regexp.escape(endpoint)}/api/v1/lifecycle/launch/[^/]+/finish\z})
          .to_return(status: 503, body: '{"message":"finish unavailable"}')
      elsif fault == "slow_finish"
        WebMock.stub_request(:put, %r{\A#{Regexp.escape(endpoint)}/api/v1/lifecycle/(?:item/[^/]+|launch/[^/]+/finish)\z})
          .with { $native_marks.last == "after_all" }.to_return do
            sleep(1)
            { status: 200, body: '{"message":"ok"}' }
          end
      end
      errors = StringIO.new
      output = StringIO.new
      statuses = []
      runs = mode == "sequential" ? 2 : 1
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      runs.times do |index|
        $native_formatter = nil
        # Cucumber requires support files once per process; each registry needs fresh definitions.
        run_steps = steps + ".#{index}.rb"
        FileUtils.cp(steps, run_steps)
        args = ["--no-profile", "--publish-quiet", "--require", run_steps,
                "--format", "progress", "--out", File.join(File.dirname(capture), "progress-#{index}.txt"),
                "--format", "ReportPortal::Cucumber::Formatter", "--out", File::NULL, feature]
        args.concat(["--format", "ReportPortal::Cucumber::Formatter", "--out", capture + ".second-rp"]) if mode == "duplicate"
        cli = LifecycleCLI.new(args, output, errors, LifecycleKernel.new)
        status = catch(:native_exit) { cli.execute! } || 0
        statuses << status
        if mode == "duplicate"
          # Idempotent attachment must not wrap this formatter a second time.
          ReportportalCucumber::Cucumber::NativeLifecycle.attach(
            cucumber_config: $native_formatter.instance_variable_get(:@cucumber_config), formatter: $native_formatter
          )
        end
      end
      requests = WebMock::RequestRegistry.instance.requested_signatures.hash.map do |request, count|
        { method: request.method, path: request.uri.path, count: count, body: request.body }
      end
      File.write(capture, JSON.generate(
        statuses: statuses, errors: errors.string, marks: $native_marks, requests: requests,
        launches: server.launches.values, items: server.item_requests, logs: server.logs,
        receipts: $native_formatters.map { |formatter| formatter.reporting_receipt.to_h },
        diagnostics: $native_formatters.map { |formatter| formatter.reporting_diagnostics },
        completions: $native_formatters.map { |formatter| $native_completions[formatter.object_id] },
        native_attached: $native_formatters.map { |formatter| formatter.instance_variable_get(:@native_lifecycle) },
        resources: $native_formatters.map { |formatter| [formatter.instance_variable_get(:@api).nil?, formatter.instance_variable_get(:@log_buffer).nil?] },
        join_constructions: $native_join_constructions, teardown_receipt: $native_teardown_receipt,
        hook_exception_identity: $native_hook_exception_identity, run_exception_identity: $native_run_exception_identity,
        business_exception_identity: $native_business_exception_identity,
        threads_before: $native_threads_before, threads_business: $native_threads_business,
        elapsed: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
        cucumber_version: Gem.loaded_specs.fetch("cucumber").version.to_s
      ))
      exit(statuses.last)
    RUBY
    env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
      "RP_CONFIG" => File::NULL, "RP_ENDPOINT" => "https://rp-lifecycle.example.test", "RP_PROJECT" => "lifecycle",
      "RP_API_KEY" => "synthetic-token", "RP_HTTP_RETRY_ATTEMPTS" => "1", "RP_EXIT_FLUSH_TIMEOUT_MS" => "500",
      "RP_REQUIRE_COMPLETE_REPORTING" => complete.to_s, "RP_FAIL_ON_REPORTING_ERROR" => strict.to_s,
      "RP_BATCH_SIZE_LOGS" => "20", "RP_FLUSH_INTERVAL" => "60", "RP_REPORTING_ASYNC" => (fault == "async").to_s,
      "RP_SPOOL_DIR" => File.join(directory, "spool"), "CUCUMBER_PROFILE" => nil,
      "BUNDLE_GEMFILE" => File.expand_path(ENV.fetch("BUNDLE_GEMFILE")),
      "LIFECYCLE_DUPLICATE_ATTACH" => (mode == "duplicate").to_s
    ).merge(env_overrides)
    env["RP_QUEUE_MAX_BYTES"] = "512" if fault == "overflow"
    stdout, stderr, process = Open3.capture3(env, "perl", "-e", "alarm 20; exec @ARGV", RbConfig.ruby,
                                           "-I#{File.join(root, 'lib')}", runner, root, feature, steps, capture, fault, mode,
                                           chdir: directory)
    expect(File.file?(capture)).to be(true), "Native capture missing: #{stdout}\n#{stderr}"
    result = JSON.parse(File.read(capture))
    expect(Gem::Version.new(result.fetch("cucumber_version"))).to be < Gem::Version.new("11")
    expect(result.fetch("cucumber_version")).to eq(Gem.loaded_specs.fetch("cucumber").version.to_s)
    result.merge("exit" => process.exitstatus, "console" => stdout + stderr)
  ensure
    FileUtils.remove_entry(directory) if owned_directory && directory
  end

  [
    { "RP_ENABLED" => "false", "RP_ENDPOINT" => nil },
    { "RP_ENABLED" => "false", "RP_ENDPOINT" => nil, "RP_PROJECT" => nil, "RP_API_KEY" => nil },
    { "RP_ENABLED" => "false" }
  ].each do |env|
    it "intentionally disables required reporting without transport for #{env}" do
      result = native_case(complete: true, strict: true, env_overrides: env)
      expect(result).to include("exit" => 0, "marks" => %w[before_all business after_all], "requests" => [])
      expect(result.fetch("resources")).to eq([[true, true]])
      expect(result.fetch("threads_business")).to eq(result.fetch("threads_before"))
      expect(result.fetch("receipts")).to all(include("complete" => true, "metadata_failures" => 0))
      expect(result.fetch("native_attached")).to eq([false])
      expect(result.fetch("join_constructions")).to eq(0)
    end
  end

  [
    { "RP_ENDPOINT" => nil },
    { "RP_PROJECT" => nil },
    { "RP_API_KEY" => nil },
    { "RP_ENDPOINT" => nil, "RP_PROJECT" => nil, "RP_API_KEY" => nil }
  ].each do |missing|
    [false, nil].each do |complete_setting|
      it "keeps resource-free best-effort execution for missing #{missing.keys} with completeness #{complete_setting.inspect}" do
        result = native_case(strict: true, env_overrides: missing.merge("RP_REQUIRE_COMPLETE_REPORTING" => complete_setting&.to_s))
        expect(result).to include("exit" => 0, "marks" => %w[before_all business after_all], "requests" => [])
        expect(result.fetch("resources")).to eq([[true, true]])
        expect(result.fetch("threads_business")).to eq(result.fetch("threads_before"))
        expect(result.fetch("join_constructions")).to eq(0)
        expect(result.fetch("receipts")).to all(include("complete" => false, "metadata_failures" => 1))
        expect(result.fetch("diagnostics")).to all(include("reporting_requested" => true, "missing_configuration" => missing.keys))
        expect(result.fetch("errors")).to be_empty
      end
    end

    it "gates missing #{missing.keys} only after the business and real AfterAll finish" do
      result = native_case(complete: true, strict: true, env_overrides: missing.merge("RP_CLIENT_JOIN" => "true"))
      expect(result).to include("exit" => 2, "marks" => %w[before_all business after_all], "requests" => [],
                               "completions" => [1], "native_attached" => [true], "join_constructions" => 0)
      expect(result.fetch("resources")).to eq([[true, true]])
      expect(result.fetch("threads_business")).to eq(result.fetch("threads_before"))
      expect(result.fetch("teardown_receipt")).to include("complete" => false, "metadata_failures" => 1)
      expect(result.fetch("receipts")).to all(include("complete" => false, "metadata_failures" => 1, "confirmed" => 0))
      expect(result.fetch("errors")).to include("required reporting configuration is incomplete", *missing.keys)
      expect(result.fetch("errors")).to include("ReportportalCucumber::ReportingError")
    end

    it "keeps original business exit one instead of the missing #{missing.keys} configuration gate" do
      result = native_case(complete: true, strict: true, business_failed: true, env_overrides: missing)
      expect(result).to include("exit" => 1, "business_exception_identity" => true, "marks" => %w[before_all business after_all],
                               "requests" => [], "join_constructions" => 0)
      expect(result.fetch("resources")).to eq([[true, true]])
      expect(result.fetch("receipts")).to all(include("complete" => false, "metadata_failures" => 1))
      expect(result.fetch("errors")).not_to include("required reporting configuration is incomplete")
    end

    it "keeps the original AfterAll exception instead of the missing #{missing.keys} configuration gate" do
      result = native_case(complete: true, strict: true, hook_failure: :after_all, env_overrides: missing)
      expect(result).to include("exit" => 2, "hook_exception_identity" => true, "run_exception_identity" => true,
                               "marks" => %w[before_all business after_all], "requests" => [], "join_constructions" => 0)
      expect(result.fetch("resources")).to eq([[true, true]])
      expect(result.fetch("receipts")).to all(include("complete" => false, "metadata_failures" => 1))
      expect(result.fetch("errors")).to include("ORIGINAL_AFTER_ALL")
      expect(result.fetch("errors")).not_to include("required reporting configuration is incomplete")
    end
  end

  it "never includes configured endpoint, project or key values in missing-configuration diagnostics" do
    result = native_case(complete: true, env_overrides: {
      "RP_ENDPOINT" => "https://example.test/?token=CONFIG_PRIVATE", "RP_PROJECT" => nil, "RP_API_KEY" => "CONFIG_PRIVATE"
    })
    expect(result.fetch("exit")).to eq(2)
    expect(result.fetch("errors")).to include("missing RP_PROJECT")
    expect([result.fetch("errors"), result.fetch("console"), result.fetch("diagnostics").to_s].join).not_to include("CONFIG_PRIVATE")
    expect(result.fetch("requests")).to be_empty
  end

  it "preserves original business failure when required reporting is explicitly disabled" do
    result = native_case(complete: true, business_failed: true, env_overrides: {
      "RP_ENABLED" => "false", "RP_ENDPOINT" => nil, "RP_PROJECT" => nil, "RP_API_KEY" => nil
    })
    expect(result).to include("exit" => 1, "business_exception_identity" => true, "requests" => [])
    expect(result.fetch("receipts")).to all(include("complete" => true, "metadata_failures" => 0))
    expect(result.fetch("errors")).not_to include("required reporting configuration is incomplete")
  end

  it "preserves the original AfterAll failure when required reporting is explicitly disabled" do
    result = native_case(complete: true, hook_failure: :after_all, env_overrides: {
      "RP_ENABLED" => "false", "RP_ENDPOINT" => nil, "RP_PROJECT" => nil, "RP_API_KEY" => nil
    })
    expect(result).to include("exit" => 2, "run_exception_identity" => true, "requests" => [])
    expect(result.fetch("errors")).to include("ORIGINAL_AFTER_ALL")
    expect(result.fetch("errors")).not_to include("required reporting configuration is incomplete")
  end

  %w[passed failed].each do |status|
    it "preserves synthetic event-driven finalization for required missing configuration and #{status} business" do
      config = ReportportalCucumber::Config.new(require_complete_reporting: true, join: true)
      allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
      expect(ReportportalCucumber::ReportPortal::API).not_to receive(:new)
      expect(ReportportalCucumber::Runtime::Join).not_to receive(:new)
      expect(ReportportalCucumber::Runtime::LogBuffer).not_to receive(:new)
      event_config = Object.new
      event_config.define_singleton_method(:on_event) { |_name, &_block| }
      formatter = ReportportalCucumber::Cucumber::Formatter.new(event_config)
      expect(formatter.instance_variable_get(:@native_lifecycle)).to be(false)
      expect { formatter.ingest_event("type" => "test_run_started") }.not_to raise_error
      completion = -> { formatter.ingest_event("type" => "test_run_finished", "status" => status) }
      if status == "passed"
        expect(&completion).to raise_error(ReportportalCucumber::ReportingError, /missing RP_ENDPOINT, RP_PROJECT, RP_API_KEY/)
      else
        expect(&completion).not_to raise_error
      end
      expect(formatter.reporting_receipt.to_h).to include(complete: false, metadata_failures: 1, local_settled: true)
      expect(&completion).not_to raise_error
    end
  end

  [nil, :after_all].each do |hook_failure|
    it "completes both resource-free required-configuration formatters while preserving #{hook_failure || 'reporting'} error precedence" do
      result = native_case(mode: "duplicate", complete: true, hook_failure: hook_failure, env_overrides: {
        "RP_ENDPOINT" => nil, "RP_PROJECT" => nil, "RP_API_KEY" => nil
      })
      expect(result).to include("exit" => 2, "marks" => %w[before_all business after_all], "completions" => [1, 1],
                               "native_attached" => [true, true], "requests" => [], "join_constructions" => 0)
      expect(result.fetch("resources")).to eq([[true, true], [true, true]])
      expect(result.fetch("receipts")).to all(include("complete" => false, "metadata_failures" => 1))
      if hook_failure
        expect(result).to include("run_exception_identity" => true, "hook_exception_identity" => true)
        expect(result.fetch("errors")).to include("ORIGINAL_AFTER_ALL")
        expect(result.fetch("errors")).not_to include("required reporting configuration is incomplete")
      else
        expect(result.fetch("errors")).to include("required reporting configuration is incomplete")
      end
    end
  end

  it "finishes a native successful launch only after genuine AfterAll returns" do
    result = native_case
    expect(result).to include("exit" => 0, "marks" => %w[before_all business after_all], "native_attached" => [true])
    expect(result.fetch("teardown_receipt")).to include("complete" => false)
    expect(result.fetch("launches")).to all(include("status" => "PASSED"))
    expect(result.fetch("receipts")).to all(include("complete" => true))
    expect(result.fetch("completions")).to eq([1])
    expect(result.fetch("join_constructions")).to eq(0)
    expect(result.fetch("items").map { |item| item.fetch("type") }).not_to include("BEFORE_CLASS", "AFTER_CLASS")
  end

  it "warns that explicitly opted-in legacy join is not a CI completion barrier" do
    result = native_case(env_overrides: { "RP_CLIENT_JOIN" => "true" })
    expect(result.fetch("exit")).to eq(0), result.fetch("errors")
    expect(result.fetch("join_constructions")).to eq(1)
    expect(result.fetch("console")).to include("legacy join cannot guarantee shared launch completion", "RP_LAUNCH_UUID")
  end

  it "reports failed native AfterAll truthfully and preserves the very same original exception" do
    result = native_case(hook_failure: :after_all, complete: true, strict: true)
    expect(result).to include("exit" => 2, "hook_exception_identity" => true, "run_exception_identity" => true)
    expect(result.fetch("errors")).to include("ORIGINAL_AFTER_ALL")
    expect(result.fetch("launches")).to all(include("status" => "FAILED"))
    expect(result.fetch("receipts")).to all(include("complete" => true))
    error_log = result.fetch("logs").find { |log| log.fetch("message").include?("Native AfterAll failed") }
    expect(error_log).to include("level" => "error")
    expect(error_log["itemUuid"]).to be_nil
    expect(error_log.fetch("message")).not_to include("synthetic-private-value")
    expect(result.fetch("items").map { |item| item.fetch("type") }).not_to include("BEFORE_CLASS", "AFTER_CLASS")
  end

  it "leaves no misleading passed launch when native BeforeAll aborts before formatter construction" do
    result = native_case(hook_failure: :before_all, complete: true, strict: true)
    expect(result).to include("exit" => 2, "marks" => ["before_all"], "requests" => [], "receipts" => [], "run_exception_identity" => true)
    expect(result.fetch("errors")).to include("ORIGINAL_BEFORE_ALL")
    expect(result.fetch("launches")).to be_empty
  end

  it "keeps sequential native runtimes bound to their own event buses and completion observers" do
    result = native_case(mode: "sequential")
    expect(result).to include("statuses" => [0, 0], "native_attached" => [true, true], "completions" => [1, 1])
    expect(result.fetch("marks")).to eq(%w[before_all business after_all before_all business after_all])
    expect(result.fetch("launches").map { |launch| launch.fetch("uuid") }.uniq.length).to eq(2)
    expect(result.fetch("receipts")).to all(include("complete" => true, "confirmed" => 2))
  end

  it "completes duplicate native formatters once each without executing AfterAll twice" do
    result = native_case(mode: "duplicate")
    expect(result).to include("exit" => 0, "marks" => %w[before_all business after_all], "completions" => [1, 1])
    expect(result.fetch("launches").length).to eq(2)
    expect(result.fetch("receipts")).to all(include("complete" => true))
  end

  it "does not misclassify a duplicate formatter's strict reporting error as a native hook failure" do
    result = native_case(mode: "duplicate", fault: "partial", complete: true)
    expect(result).to include("exit" => 2, "marks" => %w[before_all business after_all], "completions" => [1, 1])
    expect(result.fetch("launches")).to all(include("status" => "PASSED"))
    expect(result.fetch("errors")).to include("final reporting receipt is incomplete")
    expect(result.fetch("logs").map { |log| log.fetch("message") }.join).not_to include("Native AfterAll failed")
  end

  %w[partial async overflow].each do |fault|
    it "keeps best effort exit zero for #{fault}, even with legacy strict exceptions enabled" do
      result = native_case(fault: fault, strict: true)
      expect(result.fetch("exit")).to eq(0)
      expect(result.fetch("receipts")).to all(include("complete" => false))
    end

    it "exits reporting error only after business and genuine teardown finish for strict completeness #{fault}" do
      result = native_case(fault: fault, complete: true)
      expect(result).to include("exit" => 2, "marks" => %w[before_all business after_all])
      expect(result.fetch("errors")).to include("final reporting receipt is incomplete")
      receipt = result.fetch("receipts").first
      expect(receipt).to include("complete" => false)
      expect(receipt.fetch("failed")).to be > 0 if fault == "partial"
      expect(receipt.fetch("accepted_awaiting_persistence")).to be > 0 if fault == "async"
      expect(receipt.fetch("rejected")).to be > 0 if fault == "overflow"
    end

    it "preserves business exit one and original exception for incomplete #{fault}" do
      result = native_case(fault: fault, complete: true, business_failed: true)
      expect(result).to include("exit" => 1, "business_exception_identity" => true, "marks" => %w[before_all business after_all])
      expect(result.fetch("errors")).not_to include("final reporting receipt is incomplete")
      expect(result.fetch("receipts")).to all(include("complete" => false))
    end

    it "preserves original run-hook failure instead of strict completeness #{fault}" do
      result = native_case(fault: fault, complete: true, hook_failure: :after_all)
      expect(result).to include("exit" => 2, "hook_exception_identity" => true, "run_exception_identity" => true)
      expect(result.fetch("errors")).to include("ORIGINAL_AFTER_ALL")
      expect(result.fetch("errors")).not_to include("final reporting receipt is incomplete")
      expect(result.fetch("receipts")).to all(include("complete" => false))
    end
  end

  it "retains the original AfterAll exception and a bounded final deadline on launch finish failure" do
    result = native_case(fault: "deadline", complete: true, strict: true, hook_failure: :after_all)
    expect(result).to include("exit" => 2, "run_exception_identity" => true, "hook_exception_identity" => true)
    expect(result.fetch("errors")).to include("ORIGINAL_AFTER_ALL")
    expect(result.fetch("elapsed")).to be < 2
    expect(result.fetch("receipts")).to all(include("complete" => false, "metadata_failures" => 1))
  end

  it "shares one final deadline across teardown diagnostic, final metadata and shutdown without replacing AfterAll" do
    result = native_case(fault: "slow_finish", complete: true, strict: true, hook_failure: :after_all,
                         env_overrides: { "RP_EXIT_FLUSH_TIMEOUT_MS" => "50" })
    expect(result).to include("exit" => 2, "run_exception_identity" => true, "hook_exception_identity" => true)
    expect(result.fetch("elapsed")).to be < 0.5
    expect(result.fetch("errors")).to include("ORIGINAL_AFTER_ALL")
    expect(result.fetch("receipts")).to all(include("complete" => false))
    expect(result.fetch("receipts").first.fetch("metadata_failures")).to be >= 1
  end

  it "reports a CI worker's native teardown failure without touching launch ownership" do
    uuid = "01234567-89ab-4cde-8123-456789abcdef"
    result = native_case(hook_failure: :after_all, complete: true, strict: true,
                         env_overrides: { "RP_LAUNCH_UUID" => uuid, "RP_CLIENT_JOIN" => "true" })
    expect(result).to include("exit" => 2, "run_exception_identity" => true, "join_constructions" => 0)
    expect(result.fetch("requests").select { |request| request.fetch("path").include?("/launch") }).to be_empty
    expect(result.fetch("launches")).to contain_exactly(include("uuid" => uuid, "status" => "IN_PROGRESS"))
    expect(result.fetch("receipts")).to all(include("complete" => true))
    expect(result.fetch("logs")).to include(include("launchUuid" => uuid, "level" => "error", "message" => /Native AfterAll failed/))
  end

  it "uses the exact CI-owned UUID for late workers after its creator exits without launch requests or Join files" do
    Dir.mktmpdir do |dir|
      creator = fork { exit!(0) }
      Process.wait(creator)
      uuid = "01234567-89ab-4cde-8123-456789abcdef"
      File.write(File.join(dir, "legacy-sync.json"), JSON.generate(launchUuid: "stale", pid: creator))
      original_sync = File.read(File.join(dir, "legacy-sync.json"))
      [false, true, false].each do |failed|
        result = native_case(directory: dir, business_failed: failed, complete: true, env_overrides: {
          "RP_LAUNCH_UUID" => uuid, "RP_CLIENT_JOIN" => "true",
          "RP_CLIENT_JOIN_LOCK_FILE_NAME" => "must-not-create.lock", "RP_CLIENT_JOIN_SYNC_FILE_NAME" => "legacy-sync.json"
        })
        expect(result.fetch("exit")).to eq(failed ? 1 : 0)
        expect(result.fetch("join_constructions")).to eq(0)
        expect(result.fetch("requests").select { |request| request.fetch("path").include?("/launch") }).to be_empty
        expect(result.fetch("items")).to all(include("body" => include("launchUuid" => uuid)))
        expect(result.fetch("receipts")).to all(include("complete" => true))
        expect(result.fetch("launches")).to contain_exactly(include("uuid" => uuid, "status" => "IN_PROGRESS"))
      end
      expect(File.exist?(File.join(dir, "must-not-create.lock"))).to be(false)
      expect(File.read(File.join(dir, "legacy-sync.json"))).to eq(original_sync)
    end
  end
end

RSpec.describe ReportportalCucumber::Cucumber::NativeLifecycle do
  it "refuses to observe another run's registry even when a current DSL registry exists" do
    dsl = Cucumber::Glue::Dsl
    previous = dsl.instance_variable_get(:@rb_language)
    bus = Object.new
    registry = Object.new
    registry.instance_variable_set(:@configuration, double(event_bus: bus))
    registry.define_singleton_method(:after_all) { :native_result }
    dsl.instance_variable_set(:@rb_language, registry)
    formatter = instance_double(ReportportalCucumber::Cucumber::Formatter)
    expect(formatter).not_to receive(:complete_native_run)
    expect(described_class.attach(cucumber_config: double(event_bus: Object.new, dry_run?: false), formatter: formatter)).to be(false)
    expect(registry.after_all).to eq(:native_result)
    expect(registry.instance_variable_get(:@reportportal_native_lifecycle_formatters)).to be_nil
  ensure
    dsl.instance_variable_set(:@rb_language, previous) if dsl
  end
end
