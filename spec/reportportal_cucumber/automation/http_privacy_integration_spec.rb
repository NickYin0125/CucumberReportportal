# frozen_string_literal: true

require "spec_helper"
require "base64"
require "open3"
require "rbconfig"

RSpec.describe "Native AppLog HTTP privacy" do
  it "keeps escaped synthetic credentials out of full native attachments, RP wire, and terminal without rewriting business failures" do
    root = File.expand_path("../../..", __dir__)
    Dir.mktmpdir("native-http-privacy-") do |directory|
      feature = File.join(directory, "privacy.feature")
      steps = File.join(directory, "steps.rb")
      runner = File.join(directory, "runner.rb")
      messages = File.join(directory, "messages.ndjson")
      capture = File.join(directory, "capture.json")
      File.write(feature, <<~FEATURE)
        Feature: HTTP evidence privacy
          Scenario: malformed and embedded evidence
            When I publish synthetic HTTP privacy cases
          Scenario: original business exception
            When a business failure is reported unchanged
      FEATURE
      File.write(steps, <<~'RUBY')
        # frozen_string_literal: true
        Before { AppLog.bind(self, color: false) }
        After { AppLog.clear! }
        When("I publish synthetic HTTP privacy cases") do
          cases = [
            '{"pass\u0077ord":"NATIVE_HTTP_PRIVATE_MALFORMED"',
            'diagnostic: {"pass\u0077ord":"NATIVE_HTTP_PRIVATE_EMBEDDED"}',
            '"pass\u0077ord":"NATIVE_HTTP_PRIVATE_FRAGMENT"',
            '{"pass\word":"NATIVE_HTTP_PRIVATE_INVALID_ESCAPE"}',
            '{"pass\u0077ord":"NATIVE_HTTP_PRIVATE_VALID","visible":"safe decoded JSON"}',
            JSON.generate(payload: '{"pass\u0077ord":"NATIVE_HTTP_PRIVATE_NESTED"'),
            'diagnostic: {"visible":"NATIVE_HTTP_PRIVATE_BEFORE_CLIP' + ("x" * 20_000) + '","pass\u0077ord":"NATIVE_HTTP_PRIVATE_AFTER_CLIP"}'
          ]
          cases.each_with_index do |payload, index|
            AppLog.http(method: :post,
              url: "https://service.example.test/privacy-#{index}?payload=#{URI.encode_www_form_component(payload)}",
              request: { headers: { "Authorization" => "Bearer NATIVE_HTTP_PRIVATE_HEADER", "X-Diagnostic" => payload }, body: payload },
              response: { status: 200, headers: {}, body: payload },
              expected_status: 200, duration_ms: 18.5, error: payload)
          end
          cycle = { "password" => "NATIVE_HTTP_PRIVATE_CYCLE" }
          cycle["self"] = cycle
          omitted = ["NATIVE_HTTP_PRIVATE_OVERSIZED" + ("x" * 70_000), cycle,
                     Array.new(1100, "NATIVE_HTTP_PRIVATE_NODE_LIMIT")]
          omitted.each_with_index do |body, index|
            AppLog.http(method: :get, url: "https://service.example.test/omitted-#{index}",
              response: { status: 200, body: body }, expected_status: 200, duration_ms: 7)
          end
          AppLog.http(method: :get, url: "https://service.example.test/safe-control",
            response: { status: 200, body: "safe diagnostic\ntoken_count=12 password_policy=business-only component=payments" },
            expected_status: 200)
        end
        When("a business failure is reported unchanged") do
          original = RuntimeError.new("HTTP_BUSINESS_EXCEPTION_UNCHANGED")
          begin
            raise original
          rescue RuntimeError => caught
            AppLog.http(method: :get, url: "https://service.example.test/business", error: caught)
            raise "business exception replaced" unless caught.equal?(original)
            raise
          end
        end
      RUBY
      File.write(runner, <<~RUBY)
        # frozen_string_literal: true
        require "json"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require #{File.join(root, "spec/support/rp_mock_server.rb").inspect}
        require "cucumber/cli/main"
        class PrivacyKernel
          # @param code [Integer] Native Cucumber exit code.
          # @return [void]
          def exit(code = 0) = throw(:cucumber_exit, code)
          # @param code [Integer] Native Cucumber exit code.
          # @return [void]
          def exit!(code = 0) = throw(:cucumber_exit, code)
        end
        WebMock.enable!
        WebMock.disable_net_connect!
        mock = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: ENV.fetch("RP_ENDPOINT")).install!
        wire = []
        WebMock.after_request do |request, _response|
          wire << request.body.to_s if request.method == :post && request.uri.path.end_with?("/log")
        end
        feature, steps, messages, capture = ARGV
        stdout = StringIO.new
        stderr = StringIO.new
        args = ["--require", #{File.join(root, "lib/reportportal_cucumber.rb").inspect}, "--require", steps,
                "--format", "ReportPortal::Cucumber::Formatter", "--format", "message", "--out", messages, feature]
        status = catch(:cucumber_exit) do
          Cucumber::Cli::Main.new(args, stdout, stderr, PrivacyKernel.new).execute!
        end
        status ||= 0
        File.write(capture, JSON.generate(status: status, stdout: stdout.string, stderr: stderr.string,
          logs: mock.logs, wire: wire, cucumber_version: Cucumber::VERSION, ruby: RUBY_VERSION))
        exit(status)
      RUBY
      child_env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
        "RP_ENDPOINT" => "https://native-http-privacy.example.test", "RP_PROJECT" => "synthetic",
        "RP_API_KEY" => "synthetic-only-rp-key", "RP_LAUNCH" => "Native HTTP privacy",
        "RP_CLIENT_JOIN" => "false", "RP_BATCH_SIZE_LOGS" => "1", "RP_HTTP_RETRY_ATTEMPTS" => "1")
      stdout, stderr, status = Open3.capture3(child_env, "perl", "-e", "alarm 20; exec @ARGV",
        RbConfig.ruby, "-I#{File.join(root, 'lib')}", runner, feature, steps, messages, capture, chdir: root)
      expect(status.exitstatus).to eq(1), "Unexpected native exit: #{stdout}\n#{stderr}"
      result = JSON.parse(File.read(capture))
      expect(result.fetch("status")).to eq(1)
      expect(Gem::Version.new(result.fetch("cucumber_version"))).to be < Gem::Version.new("11")
      expect(result.fetch("wire").length).to be >= 12
      raw_native = File.read(messages)
      envelopes = raw_native.lines.map { |line| JSON.parse(line) }
      attachments = envelopes.filter_map do |envelope|
        attachment = envelope["attachment"]
        next unless attachment

        body = attachment.fetch("body")
        attachment["contentEncoding"] == "BASE64" ? Base64.strict_decode64(body) : body
      end
      terminal = [stdout, stderr, result.fetch("stdout"), result.fetch("stderr")].join("\n")
      sinks = [terminal, raw_native, attachments.join("\n"), result.fetch("wire").join("\n"), result.fetch("logs").to_json]
      sinks.each { |sink| expect(sink).not_to include("NATIVE_HTTP_PRIVATE_") }
      expect(terminal).to include("status=200", "HTTP_BUSINESS_EXCEPTION_UNCHANGED")
      expect(attachments.join("\n")).to include("token_count=12 password_policy=business-only component=payments", "safe decoded JSON")
      omitted_logs = result.fetch("logs").select { |entry| entry.fetch("message").include?("/omitted-") }
      expect(omitted_logs.length).to eq(3)
      omitted_logs.each do |entry|
        expect(entry.fetch("level")).to eq("info")
        expect(entry.fetch("message")).to include("Status: `200`", Automation::EvidenceRedactor::OMITTED)
      end
      http_logs = result.fetch("logs").select { |entry| entry.fetch("message").start_with?("### Request") }
      expect(http_logs.length).to eq(12)
      http_logs.each { |entry| expect(attachments.map(&:strip)).to include(entry.fetch("message").strip) }
    end
  end
end
