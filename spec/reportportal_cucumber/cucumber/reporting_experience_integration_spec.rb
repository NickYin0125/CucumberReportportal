# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "ReportPortal reporting experience integration" do
  it "routes AppLog and HTTP evidence through a real Cucumber subprocess and the stateful mock API" do
    Dir.mktmpdir("reporting-routing-") do |directory|
      feature_dir = File.join(directory, "features")
      support_dir = File.join(feature_dir, "support")
      FileUtils.mkdir_p(support_dir)
      api_capture = File.join(directory, "mock-api.json")
      native_messages = File.join(directory, "cucumber-messages.ndjson")

      File.write(File.join(feature_dir, "routing.feature"), <<~FEATURE)
        Feature: AppLog reporting routes

          Scenario: logs and HTTP evidence belong to the running step
            When I emit routed reporting evidence
      FEATURE

      File.write(File.join(support_dir, "routing_steps.rb"), <<~RUBY)
        Before { AppLog.bind(self, color: false) }
        After { AppLog.clear! }

        When("I emit routed reporting evidence") do
          AppLog.debug("integration debug", report: true)
          AppLog.error("integration error", report: true)
          log("integration native Cucumber log")
          AppLog.http(
            method: :post,
            url: "https://service.example.test/orders",
            request: {
              headers: { "Authorization" => "Bearer secret-value", "Content-Type" => "application/json" },
              body: { order_id: 73 }
            },
            response: {
              status: 201,
              headers: { "Content-Type" => "application/json" },
              body: { accepted: true }
            },
            duration_ms: 14,
            expected_status: 201,
            error: nil,
            report: true
          )
        end
      RUBY

      runner_path = File.join(directory, "run_cucumber.rb")
      File.write(runner_path, <<~RUBY)
        require "json"
        require "base64"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require #{File.join(File.expand_path("../../support/rp_mock_server.rb", __dir__)).inspect}
        require "cucumber/cli/main"

        class IntegrationKernel
          def exit(code = 0)
            throw :cucumber_exit, code
          end

          def exit!(code = 0)
            throw :cucumber_exit, code
          end
        end

        WebMock.enable!
        WebMock.disable_net_connect!
        endpoint = ENV.fetch("RP_ENDPOINT")
        mock_server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
        feature_dir = ARGV.fetch(0)
        capture_path = ARGV.fetch(1)
        native_messages_path = ARGV.fetch(2)
        stdout = StringIO.new
        stderr = StringIO.new
        args = [
          "--require", #{File.expand_path("lib/reportportal_cucumber.rb").inspect},
          "--require", File.join(feature_dir, "support", "routing_steps.rb"),
          "--format", "ReportPortal::Cucumber::Formatter",
          "--format", "message",
          "--out", native_messages_path,
          feature_dir
        ]
        status = catch(:cucumber_exit) do
          Cucumber::Cli::Main.new(args, stdout, stderr, IntegrationKernel.new).execute!
        end
        status = 0 if status.nil?
        File.write(capture_path, JSON.generate(
          status: status,
          stdout: stdout.string,
          stderr: stderr.string,
          logs: mock_server.logs,
          items: mock_server.items,
          item_requests: mock_server.item_requests,
          multipart_requests: mock_server.multipart_requests
        ))
      RUBY

      child_env = {
        "RP_ENDPOINT" => "https://rp-routing-child.example.test",
        "RP_PROJECT" => "demo",
        "RP_API_KEY" => "child-only-test-token",
        "RP_LAUNCH" => "Child routing integration",
        "RP_CLIENT_JOIN" => "false",
        "RP_BATCH_SIZE_LOGS" => "1",
        "RP_FLUSH_INTERVAL" => "0.05",
        "RP_HTTP_RETRY_ATTEMPTS" => "1"
      }
      process_stdout, process_stderr, process_status = Open3.capture3(
        child_env,
        RbConfig.ruby,
        "-I#{File.expand_path("../../../lib", __dir__)}",
        runner_path,
        feature_dir,
        api_capture,
        native_messages,
        chdir: File.expand_path("../../..", __dir__)
      )
      expect(process_status.success?).to be(true), "Cucumber subprocess failed:\n#{process_stderr}"

      result = JSON.parse(File.read(api_capture))
      expect(result.fetch("status")).to eq(0)
      logs = result.fetch("logs")
      step_item = result.fetch("item_requests").find do |item|
        body = item.fetch("body")
        body["type"] == "STEP" && body["hasStats"] == false && body["name"].include?("I emit routed reporting evidence")
      end
      expect(step_item).not_to be_nil, "Could not identify the RP step. Requests: #{result.fetch('item_requests').inspect}"
      step_uuid = step_item.fetch("responseUuid")

      debug_entries = logs.select { |entry| entry.fetch("message").include?("integration debug") }
      error_entries = logs.select { |entry| entry.fetch("message").include?("integration error") }
      native_entries = logs.select { |entry| entry.fetch("message").include?("integration native Cucumber log") }
      expect(debug_entries.length).to eq(1)
      expect(error_entries.length).to eq(1)
      expect(native_entries.length).to eq(1)
      expect(debug_entries.first).to include("level" => "debug", "itemUuid" => step_uuid)
      expect(error_entries.first).to include("level" => "error", "itemUuid" => step_uuid)
      expect(native_entries.first).to include("level" => "info", "itemUuid" => step_uuid)

      http_entries = logs.select { |entry| entry.fetch("message").include?("/orders") }
      expect(http_entries.length).to eq(1)
      http_message = http_entries.first.fetch("message")
      expect(http_entries.first).to include("level" => "info", "itemUuid" => step_uuid)
      expect(http_message.delete("`")).to include("POST https://service.example.test/orders", '"order_id": 73', '"accepted": true', "201", "14 ms")
      expect(http_message).to include("[REDACTED]")
      expect(http_message).not_to include("secret-value")

      terminal = process_stdout + process_stderr + result.fetch("stdout") + result.fetch("stderr")
      expect(terminal).to include("POST https://service.example.test/orders", "status=201", "14ms")
      expect(terminal).not_to include("secret-value", "order_id", "accepted")

      envelopes = File.readlines(native_messages, chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }
      expect(envelopes.any? { |envelope| envelope.key?("testStepFinished") }).to be(true)
      attachments = envelopes.filter_map do |envelope|
        attachment = envelope["attachment"]
        next unless attachment

        body = attachment.fetch("body", "")
        text = attachment["contentEncoding"] == "BASE64" ? Base64.decode64(body) : body
        { text: text, test_step_id: attachment["testStepId"] }
      end
      expected_native_messages = ["integration debug", "integration error", "integration native Cucumber log", "/orders"]
      native_records = expected_native_messages.map do |message|
        matching = attachments.select { |attachment| attachment[:text].include?(message) }
        expect(matching.length).to eq(1)
        matching.first
      end
      expect(native_records).not_to include(nil)
      expect(native_records.last.fetch(:text)).to eq(http_message)
      expect(native_records.last.fetch(:text)).not_to include("secret-value")
      expect(native_records.map { |record| record[:test_step_id] }.uniq.length).to eq(1)
      step_started = envelopes.find do |envelope|
        step = envelope["testStepStarted"]
        step && step.fetch("testStepId") == native_records.first.fetch(:test_step_id)
      end
      expect(step_started).not_to be_nil
    end
  end
end
