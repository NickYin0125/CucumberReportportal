# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "Native Cucumber Ledger channel separation" do
  # Keep every nonvolatile native field; normalize only independently generated
  # UUIDs, clock timestamps and durations, not messages, ownership or statuses.
  def stable(value, ids = {})
    case value
    when Hash
      value.reject { |key, _| %w[timestamp duration startTime endTime time].include?(key) }
        .transform_values { |entry| stable(entry, ids) }
    when Array then value.map { |entry| stable(entry, ids) }
    when String
      value.gsub(/[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}/i) { |id| ids[id] ||= "uuid-#{ids.length}" }
    else value
    end
  end

  it "changes only RP card bodies across unset, plain, rich and invalid modes" do
    root = File.expand_path("../../..", __dir__)
    Dir.mktmpdir("ledger-rich-native-") do |dir|
      feature = File.join(dir, "cards.feature")
      steps = File.join(dir, "steps.rb")
      runner = File.join(dir, "runner.rb")
      File.write(feature, <<~FEATURE)
        Feature: Ledger channel contract
          Scenario: all generated cards
            Given a numeric table
              | account | qty      |
              | alpha   | 001.2300 |
            And a long document
              """text/plain
              #{Array.new(25, "literal document").join("\n      ")}
              """
            When I report structured cards and original caller text
            Then the original business error remains
      FEATURE
      File.write(steps, <<~'RUBY')
        Before(name: "Open browser") do
          $ledger_runtime = ReportportalCucumber.current_runtime
          AppLog.bind(self, output: $ledger_terminal, color: false)
        end
        After(name: "Close browser") { AppLog.clear! }
        AfterStep(name: "Check browser") {}
        Given("a numeric table") { |_table| }
        Given("a long document") { |_doc| }
        When("I report structured cards and original caller text") do
          AppLog.assertion(name: "Order <other>", expected: "001.2300", actual: "001.2300", passed: true)
          AppLog.assertion(name: "Rejected order", expected: 1.0, actual: 2.0, passed: false, details: { token: "SECRET123" })
          [201, 404, 503].each do |status|
            AppLog.http(method: :post, url: "https://example.test/orders?token=SECRET123",
              request: { headers: { "Authorization" => "Bearer SECRET123" }, body: "request\n" * 14 },
              response: { status: status, body: { count: 1.0, values: [1, true, nil] } },
              expected_status: status == 503 ? 200 : nil, duration_ms: 84)
          end
          AppLog.info("Caller **literal** <other>", attach: true)
          log("Native **literal** <other>")
          attach("preview line\n" * 25, "text/plain", "native.txt")
          rp_attach("error preview\n" * 25, mime: "text/plain", name: "error.txt", level: :error)
          rp_evidence(action: "Find order", error: RuntimeError.new("token=SECRET123 missing"),
            details: { count: 1.0 }, artifacts: [{ name: "evidence.txt", mime: "text/plain", bytes: "evidence\n" * 25 }])
        end
        Then("the original business error remains") do
          raise "BUSINESS_ERROR_UNCHANGED"
        end
      RUBY
      File.write(runner, <<~RUBY)
        require "json"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require #{File.join(root, "spec/support/rp_mock_server.rb").inspect}
        require "cucumber/cli/main"
        class LedgerKernel
          def exit(code = 0) = throw(:cucumber_exit, code)
          def exit!(code = 0) = throw(:cucumber_exit, code)
        end
        WebMock.enable!
        WebMock.disable_net_connect!
        mock = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: ENV.fetch("RP_ENDPOINT")).install!
        $ledger_terminal = StringIO.new
        warnings = StringIO.new
        ReportportalCucumber.logger = Logger.new(warnings)
        stdout, stderr = StringIO.new, StringIO.new
        feature, steps, messages, capture = ARGV
        args = ["--require", #{File.join(root, "lib/reportportal_cucumber.rb").inspect}, "--require", steps,
          "--format", "ReportPortal::Cucumber::Formatter", "--format", "message", "--out", messages, feature]
        status = catch(:cucumber_exit) { Cucumber::Cli::Main.new(args, stdout, stderr, LedgerKernel.new).execute! } || 0
        files = mock.multipart_requests.flat_map { |batch| batch[:files] }
        File.write(capture, JSON.generate(status: status, logs: mock.logs, items: mock.items.values,
          launches: mock.launches.values, files: files, stdout: stdout.string, stderr: stderr.string,
          terminal: $ledger_terminal.string, warnings: warnings.string,
          retained_hook_names: $ledger_runtime.instance_variable_get(:@hook_names).length))
      RUBY
      env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
        "RP_ENDPOINT" => "https://ledger-rich.example.test", "RP_PROJECT" => "demo", "RP_API_KEY" => "synthetic-only",
        "RP_LAUNCH" => "Ledger channels", "RP_LAUNCH_DESCRIPTION" => "Original launch <literal>",
        "RP_CLIENT_JOIN" => "false", "RP_HTTP_RETRY_ATTEMPTS" => "1", "RP_BATCH_SIZE_LOGS" => "20",
        "RP_FLUSH_INTERVAL" => "0.05", "CUCUMBER_PUBLISH_QUIET" => "true"
      )
      results = [nil, "plain", "rich", "fancy"].to_h do |mode|
        messages = File.join(dir, "#{mode || 'unset'}.ndjson")
        capture = File.join(dir, "#{mode || 'unset'}.json")
        stdout, stderr, process = Open3.capture3(env.merge("RP_PRESENTATION" => mode), "perl", "-e", "alarm 30; exec @ARGV",
          RbConfig.ruby, "-I#{File.join(root, 'lib')}", runner, feature, steps, messages, capture, chdir: root)
        expect(process.success?).to be(true), "#{mode}: #{stdout}\n#{stderr}"
        result = JSON.parse(File.read(capture))
        result["native"] = File.readlines(messages).map { |line| JSON.parse(line) }
        expect(result["status"]).to eq(1)
        expect(result["retained_hook_names"]).to eq(0)
        expect(result["items"].map { |item| item["name"] }).to include(
          "Before hook \u00b7 Open browser", "After hook \u00b7 Close browser", "AfterStep hook \u00b7 Check browser")
        expect(result["logs"].length).to eq(14)
        expect(result["logs"].to_json).not_to include("SECRET123")
        [mode, result]
      end
      plain, rich = results.values_at("plain", "rich")
      plain_ownership = { "items" => plain["items"], "logs" => plain["logs"].map { |entry| entry.reject { |key, _| key == "message" } } }
      rich_ownership = { "items" => rich["items"], "logs" => rich["logs"].map { |entry| entry.reject { |key, _| key == "message" } } }
      expect(stable(rich_ownership)).to eq(stable(plain_ownership))
      [nil, "fancy"].each do |mode|
        expect(stable(results[mode]["logs"])).to eq(stable(plain["logs"]))
      end
      results.each_value do |result|
        expect(stable(result["native"])).to eq(stable(plain["native"]))
        expect(stable(result["items"])).to eq(stable(plain["items"]))
        expect(stable(result["launches"])).to eq(stable(plain["launches"]))
        expect(result["files"]).to eq(plain["files"])
        terminal = result["terminal"].gsub(/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{3}/, "CLOCK")
        expect(terminal).to eq(plain["terminal"].gsub(/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{3}/, "CLOCK"))
        expect(result["native"].to_json).not_to include("<span style", "<details>", "SECRET123")
        expect(result["items"].to_json).not_to include("<span style", "<details>")
      end
      expect(results["fancy"]["warnings"].scan(ReportportalCucumber::Config::PRESENTATION_WARNING).length).to eq(1)
      [nil, "plain", "rich"].each { |mode| expect(results[mode]["warnings"]).not_to include("Invalid RP_PRESENTATION") }
      expect(plain["logs"].to_json).not_to include("<span style", "<details>")
      expect(rich["logs"].map { |entry| entry["message"] }.join).to include("<span style=", "<details><summary>Full backtrace",
        "<details><summary>Preview", "<details><summary>Doc string", "<details><summary>Request headers")
      rich["logs"].zip(plain["logs"]).each do |r, p|
        expect(stable(r.reject { |key, _| key == "message" })).to eq(stable(p.reject { |key, _| key == "message" }))
        expect(r["message"].bytesize).to be <= p["message"].bytesize + 1024
        expect(r["message"].lines.first).to eq(p["message"].lines.first) if p["level"] == "error"
        if p["message"].start_with?("Caller", "Native")
          expect(r["message"]).to eq(p["message"])
        end
      end
      native_bodies = plain["native"].filter_map { |entry| entry.dig("attachment", "body") }
      expect(native_bodies).to include("Caller **literal** <other>", "Native **literal** <other>")
      expect(plain["files"].map { |file| file["bytes"] }).to eq(["preview line\n" * 25, "error preview\n" * 25, "evidence\n" * 25])
    end
  end
end
