# frozen_string_literal: true

require "reportportal_cucumber"
require "base64"
require "fileutils"
require "stringio"
require "tmpdir"
require_relative "../helpers/world"
require_relative "../helpers/api_client"
require_relative "../helpers/fixture_server"

module CurrentSDK
  module SelfTest
    PNG = Base64.strict_decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=").freeze
    Scenario = Struct.new(:name, :exception) do
      def failed? = !exception.nil?
    end

    class Page
      attr_accessor :failure
      attr_reader :captures

      def initialize
        @captures = []
      end

      def screenshot(**options)
        raise failure if failure

        @captures << options
        File.binwrite(options.fetch(:path), PNG)
      end
    end

    class Buffer
      attr_reader :records

      def initialize
        @records = []
      end

      def emit_log(**record)
        @records << record
        true
      end
    end

    # Exercise the real World/formatter attachment route, replacing only its
    # network queue and initialization. No server, credentials or delivery claim.
    class Formatter < ReportportalCucumber::Cucumber::Formatter
      attr_reader :buffer

      def initialize(enabled: true)
        @config = ReportportalCucumber::Config.new(enabled: enabled, endpoint: "https://example.test",
                                                  project: "synthetic", api_key: "synthetic", join: false)
        @runtime_context = ReportportalCucumber::Runtime::Context.new
        @buffer = @log_buffer = Buffer.new
        @launch_uuid = "synthetic-launch"
        item = ReportportalCucumber::Runtime::Context::ItemHandle
        @runtime_context.start_scenario("synthetic", item.new(uuid: "scenario", kind: :scenario, name: "Scenario"))
        @runtime_context.push_step(item.new(uuid: "closed-step", kind: :step, parent_uuid: "scenario"))
        @runtime_context.pop_step(expected_uuid: "closed-step")
        @runtime_context.push_step(item.new(uuid: "open-after", kind: :hook, parent_uuid: "scenario", name: "After"))
      end
    end

    class World
      include ReportportalCucumber::Cucumber::World
      include CurrentSDK::World
      attr_reader :native, :page

      def initialize
        @page = Page.new
        @native = []
      end

      def log(message)
        @native << {body: message, level: Automation::ReportContext.current.fetch(:level, :info)}
      end

      def attach(*)
        raise "Failure evidence must not call native attach"
      end

      def rp_evidence(*)
        raise "Failure evidence must not add a separate evidence entry"
      end

      def rp_capture_target
        raise "No capture API extension or retargeting is needed"
      end
    end

    class Steps
      attr_reader :definitions

      def initialize
        @definitions = {}
      end

      %i[Given When Then].each do |keyword|
        define_method(keyword) { |name, &block| @definitions[name] = block }
      end
    end

    def self.assert(condition, message)
      raise message unless condition
    end

    def self.raised
      yield
    rescue StandardError => error
      error
    else
      raise "Expected the original business failure"
    end

    def self.check(name, directory, enabled: true)
      previous_runtime = ReportportalCucumber.current_runtime
      previous_directory = ENV["REPORT_DIR"]
      ENV["REPORT_DIR"] = directory
      formatter = Formatter.new(enabled: enabled)
      ReportportalCucumber.current_runtime = formatter
      world = World.new
      output = StringIO.new
      AppLog.with_logger(Automation::CucumberLogger.new(world: world, output: output, color: false)) do
        yield world, formatter.buffer.records, output, formatter
      end
      puts "PASS #{name}"
    ensure
      formatter&.runtime_context&.clear_current_scenario
      ReportportalCucumber.current_runtime = previous_runtime
      ENV["REPORT_DIR"] = previous_directory
    end

    def self.run(directory)
      check("last PASSED action, one captioned PNG, open After owner, original error", directory) do |world, records, output, formatter|
        assert(world.ui_action("Open practice page") { :opened } == :opened, "UI helper lost its return value")
        error = RuntimeError.new("locator missing")
        trace = ["ui_steps.rb:17:in 'click'", "C:\\suite\\browser.rb:4", "last frame\ncontinued"].freeze
        error.set_backtrace(trace)
        caught = raised { world.ui_action("Click missing button") { raise error } }
        assert(caught.equal?(error) && caught.backtrace == trace, "UI helper replaced the exception/backtrace")
        world.native.clear
        world.capture_failure(Scenario.new("Missing locator / retry", error))
        assert(records.length == 1, "Expected exactly one RP evidence entry")
        record = records.fetch(0)
        assert(record[:item_uuid] == "open-after" && record[:level] == :error, "Evidence must belong to current After at ERROR")
        assert(formatter.runtime_context.current_step_item.uuid == "open-after", "Capture changed current ownership")
        assert(record[:message].lines.first.chomp == "Failure evidence: Missing locator / retry - Click missing button", "Wrong evidence title")
        assert(record[:message].include?("Last browser action (passed): Open practice page"), "Last passed action lost")
        assert(!record[:message].include?("Last browser action (passed): Click missing button"), "Failed action labelled passed")
        payload = record.fetch(:attachment)
        assert(payload[:name].match?(/\Amissing-locator-retry-click-missing-button-[0-9a-f]{8}\.png\z/), "Unreadable screenshot name")
        assert(payload[:mime] == "image/png" && File.binread(payload.fetch(:path)) == PNG, "PNG bytes changed")
        assert(world.native.empty?, "RP-only evidence leaked into native output")
        assert(output.string.lines.count { |line| line.include?("  ERROR  Failure evidence:") } == 1, "Duplicate terminal failure summary")
        assert(error.message == "locator missing" && error.backtrace == trace, "Capture mutated original failure")
      end

      check("assertion checkpoint is not the last successful browser action", directory) do |world, records|
        world.ui_action("Save practice word") { true }
        error = raised { world.check_equal("practice status", "Saved", "Pending") }
        trace = error.backtrace.dup
        world.native.clear
        world.capture_failure(Scenario.new("Save a practice word", error))
        assert(records.length == 1, "Assertion capture duplicated evidence")
        caption = records.first.fetch(:message)
        assert(caption.start_with?("Failure evidence: Save a practice word - practice status\n"), "Assertion title uses wrong checkpoint")
        assert(caption.include?("Last browser action (passed): Save practice word"), "Successful action missing from details")
        assert(world.native.empty? && error.backtrace == trace, "Assertion capture changed native failure")
      end

      check("an assertion inside a UI action retains the narrower failed check", directory) do |world, records|
        error = raised { world.ui_action("Save word") { world.check_equal("saved flag", true, false) } }
        world.capture_failure(Scenario.new("Save", error))
        assert(records.first.fetch(:message).start_with?("Failure evidence: Save - saved flag\n"), "UI rescue overwrote failed check")
        assert(records.first.fetch(:message).include?("Last browser action (passed): none"), "Invented passed browser action")
      end

      check("RP disabled keeps local PNG but emits no RP/native evidence", directory, enabled: false) do |world, records|
        world.capture_failure(Scenario.new("Disabled reporting", RuntimeError.new("original")))
        assert(world.page.captures.length == 1 && File.binread(world.page.captures.first.fetch(:path)) == PNG, "RP off lost local PNG")
        assert(records.empty? && world.native.empty?, "RP off emitted evidence")
      end

      check("no formatter still captures a local PNG without evidence or exceptions", directory) do |world, records|
        ReportportalCucumber.current_runtime = nil
        world.capture_failure(Scenario.new("No formatter", RuntimeError.new("original")))
        assert(world.page.captures.length == 1 && records.empty? && world.native.empty?, "Missing runtime was not fail-safe")
      end

      check("screenshot failure never replaces the original exception", directory) do |world, records, output|
        world.page.failure = IOError.new("synthetic screenshot failure")
        error = raised { world.ui_action("Missing button") { raise "original failure" } }
        trace = error.backtrace.dup
        world.native.clear
        world.capture_failure(Scenario.new("Screenshot unavailable", error))
        assert(records.empty? && world.native.empty?, "Capture failure emitted partial evidence")
        assert(error.message == "original failure" && error.backtrace == trace, "Capture failure replaced original")
        assert(output.string.include?("Failure evidence unavailable: IOError"), "Missing capture warning")
      end

      check("attachment failure never replaces the original exception", directory) do |world, records, output|
        world.define_singleton_method(:rp_attach) { |*, **| raise IOError, "synthetic reporting failure" }
        error = RuntimeError.new("original")
        error.set_backtrace(["business.rb:9"])
        world.capture_failure(Scenario.new("Reporting unavailable", error))
        assert(records.empty? && world.native.empty? && world.page.captures.length == 1, "Reporting failure lost local evidence")
        assert(error.message == "original" && error.backtrace == ["business.rb:9"], "Reporting failure replaced original")
        assert(output.string.include?("Failure evidence unavailable: IOError"), "Missing reporting warning")
      end

      check("passing scenarios and missing pages do not capture", directory) do |world, records|
        world.capture_failure(Scenario.new("Passed", nil))
        page = world.page
        world.instance_variable_set(:@page, nil)
        world.capture_failure(Scenario.new("No page", RuntimeError.new("failed")))
        assert(page.captures.empty? && records.empty? && world.native.empty?, "Unneeded evidence was captured")
      end

      check("repeated captures have unique bounded safe names", directory) do |world, records|
        scenario = Scenario.new("../Same scenario (focus)", RuntimeError.new("failed"))
        3.times { world.capture_failure(scenario) }
        names = world.page.captures.map { |capture| File.basename(capture.fetch(:path)) }
        assert(records.length == 3 && names.uniq.length == 3, "Repeated screenshots overwrite evidence")
        assert(names.all? { |name| name.match?(/\Asame-scenario-focus-ui-scenario-failure-[0-9a-f]{8}\.png\z/) }, "Unsafe or unreadable screenshot name")
        path = world.send(:screenshot_path, "a" * 1000, "b" * 1000)
        assert(File.basename(path).bytesize <= 134 && File.dirname(path) == directory, "Unbounded filename or escaped directory")
        fallback = world.send(:screenshot_path, "\u6d4b\u8bd5", "???")
        assert(File.basename(fallback).match?(/\Ascenario-checkpoint-[0-9a-f]{8}\.png\z/), "Missing safe slug fallback")
      end

      check("caption redaction does not mutate the original exception", directory) do |world, records, output|
        error = RuntimeError.new("token=wp2-synthetic-secret")
        error.set_backtrace(["raw-backtrace-frame"])
        world.capture_failure(Scenario.new("Safe synthetic scenario", error))
        assert(!records.first.fetch(:message).include?("wp2-synthetic-secret"), "Caption exposed a secret")
        assert(!output.string.include?("wp2-synthetic-secret"), "Terminal exposed a secret")
        assert(error.message == "token=wp2-synthetic-secret" && error.backtrace == ["raw-backtrace-frame"], "Redaction mutated original evidence")
      end

      check("diagnostic-only step emits exactly one INFO observation", directory) do |world, records, output|
        steps = Steps.new
        path = File.expand_path("../features/step_definitions/api_steps.rb", __dir__)
        steps.instance_eval(File.read(path), path)
        world.instance_exec(&steps.definitions.fetch("I record a non-fatal diagnostic comparison"))
        assert(world.native.length == 1 && world.native.first[:level] == :info, "Diagnostic is not one INFO observation")
        assert(world.native.first[:body].start_with?("Diagnostic only (non-fatal):"), "Diagnostic is not clearly nonfatal")
        assert(records.empty? && !output.string.include?("ERROR"), "Diagnostic emitted a direct error record")
      end

      check("API helper emits one HTTP exchange, no duplicate response snapshot", directory) do |world|
        fixture = CurrentSDK::FixtureServer.new.start
        begin
          response = CurrentSDK::ApiClient.new(fixture.url).request("POST", "/api/practice", body: '{"word":""}', expected_status: 400)
          assert(response.code == "400", "Fixture did not return expected rejection")
          assert(world.native.length == 2, "Expected DEBUG plus a single HTTP exchange")
          assert(world.native.map { |entry| entry[:level] } == %i[debug info], "Expected 400 must remain INFO")
          assert(world.native.last[:body].include?("word_required"), "HTTP exchange lost response body")
          assert(world.native.none? { |entry| entry[:body].include?("API response snapshot") }, "Duplicate response snapshot")
        ensure
          fixture.stop
        end
      end

      setup = File.read(File.expand_path("../bin/setup", __dir__))
      assert(setup.include?('system("npm", "install", "--prefix", Dir.pwd, "--no-save", "playwright-core@#{version}")'),
             "npm install must explicitly target the consumer directory")
      assert(!File.exist?(File.expand_path("../package.json", __dir__)), "Example must not require a package.json")
      puts "PASS setup prefix contract and no package.json"
      puts "13 example self-tests passed (RP queue boundary only; no live ingestion)."
    end
  end
end

scratch = File.expand_path("../artifacts", __dir__)
created_scratch = !Dir.exist?(scratch)
FileUtils.mkdir_p(scratch)
begin
  Dir.mktmpdir("example-self-test-", scratch) { |directory| CurrentSDK::SelfTest.run(directory) }
ensure
  Dir.rmdir(scratch) if created_scratch && Dir.empty?(scratch)
end
