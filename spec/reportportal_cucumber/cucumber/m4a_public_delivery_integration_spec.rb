# frozen_string_literal: true

require "spec_helper"
require "digest"
require "open3"
require "rbconfig"

RSpec.describe "M4-A public bounded delivery integration" do
  it "captures actual Cucumber multipart bodies, retry ownership, and partial evidence rejection" do
    Dir.mktmpdir("m4a-public-child-") do |directory|
      feature_dir = File.join(directory, "features")
      support_dir = File.join(feature_dir, "support")
      FileUtils.mkdir_p(support_dir)
      marker = File.join(directory, "first-attempt")
      capture_path = File.join(directory, "capture.json")
      File.write(File.join(feature_dir, "delivery.feature"), <<~FEATURE)
        Feature: Bounded public delivery

          Scenario: retry owns its logs and rejected artifact is observable
            When I report bounded public evidence
      FEATURE
      File.write(File.join(support_dir, "delivery_steps.rb"), <<~RUBY)
        When("I report bounded public evidence") do
          attempt = if File.exist?(ENV.fetch("M4A_ATTEMPT_MARKER"))
                      2
                    else
                      File.write(ENV.fetch("M4A_ATTEMPT_MARKER"), "seen")
                      1
                    end
          admitted = rp_attach("public-attachment-\#{attempt}", name: "public-\#{attempt}.txt", mime: "text/plain")
          rejected_before = ReportportalCucumber.current_runtime.reporting_diagnostics.dig(:counters, :rejected_oversized)
          partial = rp_evidence(
            action: "exercise public admission",
            error: RuntimeError.new("expected scenario failure"),
            details: "attempt=\#{attempt}",
            artifacts: [{ bytes: "z" * 4_096, name: "oversized-\#{attempt}.bin", mime: "application/octet-stream" }]
          )
          rejected_after = ReportportalCucumber.current_runtime.reporting_diagnostics.dig(:counters, :rejected_oversized)
          File.open(ENV.fetch("M4A_RESULT_PATH"), "a") do |result|
            result.puts(JSON.generate(attempt: attempt, attach_admitted: admitted, evidence_admitted: partial,
              explicit_oversized_rejections: rejected_after - rejected_before))
          end
          raise "intentional first attempt failure" if attempt == 1
        end
      RUBY

      runner_path = File.join(directory, "run_cucumber.rb")
      File.write(runner_path, <<~RUBY)
        require "json"
        require "digest"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require #{File.join(File.expand_path("../../support/rp_mock_server.rb", __dir__)).inspect}
        require "cucumber/cli/main"

        class M4AIntegrationKernel
          def exit(code = 0); throw :cucumber_exit, code; end
          def exit!(code = 0); throw :cucumber_exit, code; end
        end

        WebMock.enable!
        WebMock.disable_net_connect!
        endpoint = ENV.fetch("RP_ENDPOINT")
        mock_server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
        body_lengths = []
        WebMock.after_request do |request, _response|
          if request.uri.path.end_with?("/log")
            body_lengths << { bytes: request.body.to_s.bytesize, content_type: request.headers.fetch("Content-Type", "") }
          end
        end
        feature_dir, capture_path = ARGV
        stdout = StringIO.new
        stderr = StringIO.new
        args = [
          "--require", #{File.expand_path("lib/reportportal_cucumber.rb").inspect},
          "--require", File.join(feature_dir, "support", "delivery_steps.rb"),
          "--format", "ReportPortal::Cucumber::Formatter",
          "--retry", "1",
          feature_dir
        ]
        status = catch(:cucumber_exit) do
          Cucumber::Cli::Main.new(args, stdout, stderr, M4AIntegrationKernel.new).execute!
        end
        status = 0 if status.nil?
        runtime = ReportportalCucumber.current_runtime
      File.write(capture_path, JSON.generate(
          status: status,
          stdout: stdout.string,
          stderr: stderr.string,
          body_lengths: body_lengths,
          logs: mock_server.logs,
          items: mock_server.items,
          item_requests: mock_server.item_requests,
          multipart_requests: mock_server.multipart_requests,
          diagnostics: runtime&.reporting_diagnostics,
          ruby_version: RUBY_VERSION,
          cucumber_version: Gem.loaded_specs.fetch("cucumber").version.to_s,
          library_path: $LOADED_FEATURES.find { |path| path.end_with?("/lib/reportportal_cucumber.rb") }.then { |path| File.expand_path(path) },
          library_sha256: Digest::SHA256.file($LOADED_FEATURES.find { |path| path.end_with?("/lib/reportportal_cucumber.rb") }).hexdigest
      ))
      RUBY

      result_lines = File.join(directory, "attempt-results.ndjson")
      env = {
        "RP_ENDPOINT" => "https://rp-m4a-public.example.test",
        "RP_PROJECT" => "m4a",
        "RP_API_KEY" => "test-only-token",
        "RP_LAUNCH" => "M4-A public integration",
        "RP_CLIENT_JOIN" => "false",
        "RP_QUEUE_MAX_RECORDS" => "100",
        "RP_QUEUE_MAX_BYTES" => "1400",
        "RP_BATCH_SIZE_LOGS" => "2",
        "RP_BATCH_MAX_BYTES" => "5000",
        "RP_QUEUE_OVERFLOW_POLICY" => "reject_new",
        "RP_HTTP_RETRY_ATTEMPTS" => "1",
        "M4A_ATTEMPT_MARKER" => marker,
        "M4A_RESULT_PATH" => result_lines,
        "M4A_EXPECTED_CUCUMBER_VERSION" => Gem.loaded_specs.fetch("cucumber").version.to_s
      }
      _stdout, stderr, process_status = Open3.capture3(
        env,
        RbConfig.ruby,
        "-I#{File.expand_path("../../../lib", __dir__)}",
        runner_path,
        feature_dir,
        capture_path,
        chdir: File.expand_path("../../..", __dir__)
      )
      expect(process_status.success?).to be(true), "Cucumber child failed: #{stderr}"

      capture = JSON.parse(File.read(capture_path))
      if (evidence_directory = ENV["M4A_CHILD_EVIDENCE_DIR"]) && !evidence_directory.empty?
        FileUtils.mkdir_p(evidence_directory)
        FileUtils.cp(capture_path, File.join(evidence_directory, "public-delivery-child.json"))
        FileUtils.cp(result_lines, File.join(evidence_directory, "attempt-admissions.ndjson"))
      end
      expect(capture.fetch("status")).to eq(0)
      attempts = File.readlines(result_lines).map { |line| JSON.parse(line) }
      expect(attempts.map { |attempt| attempt.fetch("attempt") }).to eq([1, 2])
      expect(attempts).to all(include(
        "attach_admitted" => true, "evidence_admitted" => false, "explicit_oversized_rejections" => 1
      ))

      scenario_items = capture.fetch("item_requests").select do |item|
        body = item.fetch("body")
        body["type"] == "STEP" && body["hasStats"] == true && body.fetch("name").include?("retry owns its logs")
      end
      expect(scenario_items.length).to eq(2)
      retry_values = scenario_items.map { |item| item.fetch("body")["retry"] }
      expect(retry_values).to contain_exactly(false, true)
      scenario_uuids = scenario_items.map { |item| item.fetch("responseUuid") }
      step_items = capture.fetch("item_requests").select do |item|
        body = item.fetch("body")
        body["type"] == "STEP" && body["hasStats"] == false &&
          body.fetch("name").include?("I report bounded public evidence") && scenario_uuids.include?(item.fetch("parentUuid"))
      end
      expect(step_items.length).to eq(scenario_items.length),
        "expected named action children for attempts #{scenario_uuids.inspect}; items=#{capture.fetch('item_requests').map { |item| item.slice('name', 'parentUuid', 'type', 'responseUuid') }.inspect}"
      step_uuids = step_items.map { |item| item.fetch("responseUuid") }
      reported_logs = capture.fetch("logs").select { |entry| entry.fetch("message").start_with?("Attachment: public-") }
      expect(reported_logs.map { |entry| entry.fetch("itemUuid") }.sort).to eq(step_uuids.sort)
      expect(reported_logs.map { |entry| entry.fetch("file").fetch("name") }.sort)
        .to eq(["public-1.txt", "public-2.txt"])
      sent_attachment_names = capture.fetch("multipart_requests").flat_map do |request|
        request.fetch("files").map { |file| file.fetch("filename") }
      end
      expect(sent_attachment_names.sort).to eq(["public-1.txt", "public-2.txt"])
      expect(sent_attachment_names).not_to include("oversized-1.bin", "oversized-2.bin")

      body_lengths = capture.fetch("body_lengths")
      expect(body_lengths).not_to be_empty
      expect(body_lengths).to all(satisfy { |body| body.fetch("bytes") <= 5_000 })
      multipart_lengths = body_lengths.select { |body| body.fetch("content_type").include?("multipart/form-data") }
      expect(multipart_lengths).not_to be_empty
      expect(capture.fetch("multipart_requests").length).to eq(multipart_lengths.length)
      counters = capture.fetch("diagnostics").fetch("counters")
      extra_oversized_rejections = counters.fetch("rejected_oversized") -
        attempts.sum { |attempt| attempt.fetch("explicit_oversized_rejections") }
      expected_extra = capture.fetch("cucumber_version").start_with?("9.") ? 1 : 0
      expect(extra_oversized_rejections).to eq(expected_extra)
      expect(counters.fetch("accepted")).to eq(capture.fetch("logs").length)
      expect(counters.fetch("sent_batches")).to eq(body_lengths.length)
      expect(capture.fetch("diagnostics").fetch("current_records")).to eq(0)
      expect(capture.fetch("diagnostics").fetch("current_bytes")).to eq(0)
      expect(counters.fetch("delivery_failed")).to eq(0)
      expect(capture.fetch("ruby_version")).to eq(RUBY_VERSION)
      expect(capture.fetch("cucumber_version")).to eq(env.fetch("M4A_EXPECTED_CUCUMBER_VERSION"))
      expect(File.expand_path(capture.fetch("library_path"))).to eq(File.expand_path("lib/reportportal_cucumber.rb"))
      expect(capture.fetch("library_sha256")).to eq(Digest::SHA256.file("lib/reportportal_cucumber.rb").hexdigest)
    end
  end
end
