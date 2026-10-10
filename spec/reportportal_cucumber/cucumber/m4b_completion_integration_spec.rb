# frozen_string_literal: true

require "spec_helper"
require "cucumber/cli/main"
require "open3"
require "rbconfig"
require "stringio"

RSpec.describe "M4-B formatter completion receipts" do
  class M4BCompletionKernel
    def exit(code = 0)
      throw :cucumber_exit, code
    end

    def exit!(code = 0)
      throw :cucumber_exit, code
    end
  end

  class M4BFakeCucumberConfig
    def on_event(_name, &_handler); end
    def include(_mod); end
  end

  let(:root) { File.expand_path("../../..", __dir__) }

  it "confirms singleton JSON and single-PNG multipart IDs through the actual formatter while preserving business failure" do
    Dir.mktmpdir("m4b-formatter-ack-") do |directory|
      feature_dir = File.join(directory, "features")
      support_dir = File.join(feature_dir, "support")
      FileUtils.mkdir_p(support_dir)
      File.write(File.join(feature_dir, "completion.feature"), <<~FEATURE)
        Feature: M4-B delivery receipts

          Scenario: reporting failure does not replace the business failure
            When I emit a JSON log and PNG then fail the business step
      FEATURE
      File.write(File.join(support_dir, "completion_steps.rb"), <<~RUBY)
        When("I emit a JSON log and PNG then fail the business step") do
          rp_log("json acknowledgement", mirror: false)
          rp_attach("\\x89PNG\\r\\n\\x1A\\nimage-data".b, name: "receipt.png", mime: "image/png")
          raise "deliberate business failure"
        end
      RUBY
      runner = File.join(directory, "run_cucumber.rb")
      capture = File.join(directory, "capture.json")
      File.write(runner, <<~RUBY)
        require "base64"
        require "json"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require "cucumber/cli/main"
        require #{File.join(root, "spec/support/rp_mock_server.rb").inspect}

        class M4BCompletionKernel
          def exit(code = 0)
            throw :cucumber_exit, code
          end

          def exit!(code = 0)
            throw :cucumber_exit, code
          end
        end

        M4BFormatterCapture = Module.new do
          define_method(:new) do |*arguments, **keywords, &block|
            instance = super(*arguments, **keywords, &block)
            $m4b_formatter_instance = instance
            instance
          end
        end
        ReportportalCucumber::Cucumber::Formatter.singleton_class.prepend(M4BFormatterCapture)

        WebMock.enable!
        WebMock.disable_net_connect!
        endpoint = ENV.fetch("RP_ENDPOINT")
        server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
        WebMock.stub_request(:put, %r{\\A\#{Regexp.escape(endpoint)}/api/v1/([^/]+)/item/[^/]+\\z})
          .to_return(status: 500, body: { "message" => "temporary item finalization failure" }.to_json)
        log_responses = []
        WebMock.after_request do |request, response|
          if request.uri.path.end_with?("/log")
            log_responses << { "content_type" => request.headers.fetch("Content-Type", ""),
                               "status" => response.status, "body" => response.body }
          end
        end

        output = StringIO.new
        errors = StringIO.new
        progress_path = ARGV.fetch(2)
        args = ["--require", #{File.join(root, "lib/reportportal_cucumber.rb").inspect},
                "--require", File.join(ARGV.fetch(0), "support", "completion_steps.rb"),
                "--format", "progress", "--out", progress_path,
                "--format", "ReportPortal::Cucumber::Formatter", ARGV.fetch(0)]
        status = catch(:cucumber_exit) do
          Cucumber::Cli::Main.new(args, output, errors, M4BCompletionKernel.new).execute!
        end
        formatter = $m4b_formatter_instance
        raise "Cucumber did not instantiate the ReportPortal formatter" unless formatter
        File.write(ARGV.fetch(1), JSON.generate(
          status: status || 0,
          stdout: File.read(progress_path),
          stderr: errors.string,
          receipt: formatter.reporting_receipt.to_h,
          logs: server.logs,
          multipart: server.multipart_requests.map do |request|
            { "entries" => request.fetch(:entries),
              "files" => request.fetch(:files).map do |file|
                { "filename" => file.fetch(:filename), "content_type" => file.fetch(:content_type),
                  "bytes_base64" => Base64.strict_encode64(file.fetch(:bytes)) }
              end }
          end,
          log_responses: log_responses,
          item_requests: server.item_requests
        ))
      RUBY

      spool_dir = File.join(directory, "spool")
      progress_path = File.join(directory, "progress.txt")
      child_env = {
        "RP_ENDPOINT" => "https://rp-m4b-completion.example.test",
        "RP_PROJECT" => "m4b",
        "RP_API_KEY" => "m4b-test-only-token",
        "RP_LAUNCH" => "M4-B formatter completion",
        "RP_CLIENT_JOIN" => "false",
        "RP_BATCH_SIZE_LOGS" => "1",
        "RP_FLUSH_INTERVAL" => "0.01",
        "RP_HTTP_RETRY_ATTEMPTS" => "1",
        "RP_SPOOL_DIR" => spool_dir
      }
      stdout, stderr, process = Open3.capture3(
        child_env, RbConfig.ruby, "-I#{File.join(root, 'lib')}", runner,
        feature_dir, capture, progress_path, chdir: root
      )
      expect(process.success?).to be(true), "Cucumber harness failed: #{stderr}\n#{stdout}"

      result = JSON.parse(File.read(capture))
      expect(result.fetch("status")).to eq(1)
      expect(result.fetch("stdout")).to include("1 scenario (1 failed)")
      expect(result.fetch("stdout") + result.fetch("stderr")).to include("deliberate business failure")
      expect(result.fetch("logs").map { |entry| entry.fetch("message") }).to include("json acknowledgement")
      expect(result.fetch("multipart").length).to eq(1)
      multipart = result.fetch("multipart").first
      expect(multipart.fetch("entries").length).to eq(1)
      expect(multipart.fetch("files").length).to eq(1)
      png = multipart.fetch("files").first
      expect(png.fetch("filename")).to eq("receipt.png")
      expect(png.fetch("content_type")).to eq("image/png")
      expect(Base64.strict_decode64(png.fetch("bytes_base64"))).to eq("\x89PNG\r\n\x1A\nimage-data".b)

      responses = result.fetch("log_responses").map { |response| JSON.parse(response.fetch("body")) }
      expect(responses.length).to eq(3)
      expect(responses.count { |body| body.is_a?(Hash) && body["id"].is_a?(String) }).to eq(2)
      expect(responses.count do |body|
        body.is_a?(Hash) && body["responses"].is_a?(Array) && body["responses"].length == 1 &&
          body["responses"].first["id"].is_a?(String)
      end).to eq(1)

      receipt = result.fetch("receipt")
      expect(receipt.fetch("cutoff")).to eq(receipt.fetch("settled"))
      expect(receipt.fetch("confirmed")).to eq(receipt.fetch("cutoff"))
      expect(receipt.fetch("pending")).to eq(0)
      expect(receipt.fetch("metadata_failures")).to be > 0
      expect(receipt.fetch("complete")).to be(false)
      expect(receipt.fetch("local_settled")).to be(true)
      expect(result.fetch("item_requests").map { |item| item.fetch("responseUuid") }.uniq.length)
        .to eq(result.fetch("item_requests").length)
    end
  end

  it "marks completion false when a capture writer outlives the finalization close budget" do
    spool_dir = Dir.mktmpdir("m4b-capture-timeout-")
    config = ReportportalCucumber::Config.new(
      endpoint: "https://rp-m4b-capture.example.test", project: "m4b", api_key: "m4b-test-only-token",
      launch: "M4-B capture close", join: false, retry_attempts: 1, flush_interval: 0.01,
      exit_flush_timeout_ms: 90, spool_dir: spool_dir, batch_size_logs: 1
    )
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
    server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: config.endpoint).install!
    formatter = ReportportalCucumber::Cucumber::Formatter.new(M4BFakeCucumberConfig.new)
    formatter.ingest_event("type" => "test_run_started", "timestamp" => "2026-10-10T00:00:00Z")
    formatter.ingest_event("type" => "test_suite_started", "feature_uri" => "features/held.feature")
    formatter.ingest_event("type" => "test_case_started", "feature_uri" => "features/held.feature",
                           "scenario_name" => "held capture", "scenario_line" => 3)
    formatter.ingest_event("type" => "test_step_started", "step_text" => "hold capture", "step_id" => "held-step")

    target = formatter.rp_capture_target
    launch_uuid = server.launches.keys.fetch(0)
    leased_item = formatter.runtime_context.acquire_capture_target(target, launch_uuid: launch_uuid)
    expect(leased_item).not_to be_nil
    formatter.ingest_event("type" => "test_run_finished", "success" => true)

    receipt = formatter.reporting_receipt
    expect(receipt.capture_close_timeouts).to eq(1)
    expect(receipt.complete).to be(false)
    expect(receipt.to_h).to be_frozen
  ensure
    formatter&.runtime_context&.release_capture_target(target) if target
    stop_formatter_worker(formatter)
    FileUtils.remove_entry(spool_dir) if spool_dir && File.exist?(spool_dir)
  end

  def stop_formatter_worker(formatter)
    return unless formatter

    buffer = formatter.instance_variable_get(:@log_buffer)
    processor = buffer.instance_variable_get(:@processor)
    worker = processor.instance_variable_get(:@worker)
    worker.kill if worker.alive?
    worker.join(0.2)
  end
end
