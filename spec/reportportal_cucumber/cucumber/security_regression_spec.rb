# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rbconfig"
require "base64"

RSpec.describe "Public Cucumber security regression" do
  def persist_security_receipt(directory, label, stdout, stderr)
    destination = ENV["SECURITY_REGRESSION_RECEIPT_DIR"]
    return unless destination

    destination = File.join(destination, label)
    FileUtils.mkdir_p(destination)
    %w[result.json messages.ndjson].each do |name|
      path = File.join(directory, name)
      FileUtils.cp(path, File.join(destination, name)) if File.file?(path)
    end
    File.write(File.join(destination, "child.stdout"), stdout)
    File.write(File.join(destination, "child.stderr"), stderr)
  end

  def formatter_config
    Class.new do
      def on_event(_name, &_block); end
      def include(_mod); end
    end.new
  end

  it "keeps synthetic canaries out of terminal, native messages, and actual API log payloads" do
    feature = File.expand_path("../../fixtures/security_regression/security.feature", __dir__)
    steps = File.expand_path("../../fixtures/security_regression/steps.rb", __dir__)
    mock_helper = File.expand_path("../../support/rp_mock_server.rb", __dir__)
    library = File.expand_path("../../../lib/reportportal_cucumber.rb", __dir__)

    Dir.mktmpdir("security-cucumber-") do |directory|
      messages = File.join(directory, "messages.ndjson")
      result_path = File.join(directory, "result.json")
      runner = File.join(directory, "run.rb")
      long_png_path = File.join(directory, "synthetic-long-png.png")
      png_bytes = "\x89PNG\r\n\x1A\nsynthetic-png-payload".b
      File.binwrite(long_png_path, png_bytes)
      File.write(runner, <<~RUBY)
        require "json"
        require "base64"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require #{mock_helper.inspect}
        require "cucumber/cli/main"

        class SecurityRegressionKernel
          def exit(code = 0) = throw(:cucumber_exit, code)
          def exit!(code = 0) = throw(:cucumber_exit, code)
        end

        WebMock.enable!
        WebMock.disable_net_connect!
        endpoint = ENV.fetch("RP_ENDPOINT")
        mock = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
        feature, steps, messages, result_path = ARGV
        stdout = StringIO.new
        stderr = StringIO.new
        args = ["--require", #{library.inspect}, "--require", steps,
                "--format", "ReportPortal::Cucumber::Formatter",
                "--format", "message", "--out", messages, feature]
        status = catch(:cucumber_exit) do
          Cucumber::Cli::Main.new(args, stdout, stderr, SecurityRegressionKernel.new).execute!
        end
        multipart = mock.multipart_requests.map do |payload|
          payload.merge(files: payload.fetch(:files).map do |file|
            file.merge(bytes_base64: Base64.strict_encode64(file.fetch(:bytes)), bytes: nil)
          end)
        end
        File.write(result_path, JSON.generate(status: status || 0, stdout: stdout.string,
          stderr: stderr.string, logs: mock.logs, items: mock.item_requests, multipart: multipart))
      RUBY

      endpoint = "https://security-regression.example.test"
      stdout, stderr, process_status = Open3.capture3(
        { "RP_ENDPOINT" => endpoint, "RP_PROJECT" => "demo", "RP_API_KEY" => "synthetic-never-sent",
          "SECURITY_LONG_PNG_PATH" => long_png_path,
          "RP_LAUNCH" => "Security regression", "RP_CLIENT_JOIN" => "false",
          "RP_BATCH_SIZE_LOGS" => "1", "RP_HTTP_RETRY_ATTEMPTS" => "1" },
        RbConfig.ruby, "-I#{File.expand_path("../../../lib", __dir__)}", runner,
        feature, steps, messages, result_path, chdir: File.expand_path("../../..", __dir__)
      )

      persist_security_receipt(directory, "successful-http", stdout, stderr)
      expect(process_status.success?).to be(true), "Cucumber process failed: #{stderr}"
      result = JSON.parse(File.read(result_path))
      expect(result.fetch("status")).to eq(0), "Cucumber failed: #{result.inspect}"
      expect(result.fetch("logs")).not_to be_empty
      native_text = File.read(messages)
      expect(result.fetch("multipart")).not_to be_empty
      multipart_json = result.fetch("multipart").to_json
      expect(multipart_json).not_to include("SECURITY_ARTIFACT_MALFORMED", "SECURITY_ARTIFACT_OVERSIZED_", "SECURITY_EDGE_")
      expect(multipart_json).not_to include("SECURITY_READY5_")
      all_sinks = [stdout, stderr, result.fetch("stdout"), result.fetch("stderr"),
                   native_text, result.fetch("logs").to_json].join("\n")
      expect(all_sinks).not_to include(
        "SECURITY_CLI_JSON_", "SECURITY_CLI_ERROR_", "SECURITY_CLI_URL_USER",
        "SECURITY_CLI_URL_PASSWORD_", "SECURITY_CLI_EXPECTED", "SECURITY_CLI_ACTUAL",
        "SECURITY_CLI_OVERSIZED_", "SECURITY_EMBEDDED_INCOMPLETE_QUOTE",
        "SECURITY_EMBEDDED_ESCAPED_COLON", "SECURITY_FRAGMENT_SECRET", "SECURITY_DOTTED_KEY_SECRET",
        "SECURITY_ARTIFACT_MALFORMED", "SECURITY_ARTIFACT_OVERSIZED_", "SECURITY_EDGE_"
      )
      expect(all_sinks).to include("security assertion", "security evidence action", "safe readable failure")
      expect(all_sinks).not_to include("SECURITY_READY5_")
      expect(all_sinks).to include("token_count=12 password_policy=business-only component=payments")
      known_png = result.fetch("multipart").flat_map { |payload| payload.fetch("files") }
        .find { |file| file.fetch("filename") == "known-good.png" }
      expect(known_png.fetch("content_type")).to eq("image/png")
      expect(Base64.strict_decode64(known_png.fetch("bytes_base64"))).to eq("\x89PNG\r\n\x1A\nsynthetic-png-payload".b)
      files = result.fetch("multipart").flat_map { |payload| payload.fetch("files") }
      long_png_bytes = files.find { |file| file.fetch("filename").start_with?("long-legitimate-png-bytes-") }
      expect(long_png_bytes.fetch("content_type")).to eq("image/png")
      expect(Base64.strict_decode64(long_png_bytes.fetch("bytes_base64"))).to eq(png_bytes)
      long_png_path = files.find { |file| file.fetch("filename").start_with?("long-legitimate-png-path-") }
      expect(long_png_path.fetch("content_type")).to eq("image/png")
      expect(Base64.strict_decode64(long_png_path.fetch("bytes_base64"))).to eq(png_bytes)
    end
  end

  it "keeps public capture targets on the active step and actual After hook without fallback logs" do
    feature = File.expand_path("../../fixtures/security_regression/security.feature", __dir__)
    steps = File.expand_path("../../fixtures/security_regression/steps.rb", __dir__)
    mock_helper = File.expand_path("../../support/rp_mock_server.rb", __dir__)
    library = File.expand_path("../../../lib/reportportal_cucumber.rb", __dir__)

    Dir.mktmpdir("security-capture-targets-") do |directory|
      messages = File.join(directory, "messages.ndjson")
      result_path = File.join(directory, "result.json")
      runner = File.join(directory, "run.rb")
      File.write(runner, <<~RUBY)
        require "json"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require #{mock_helper.inspect}
        require "cucumber/cli/main"

        class SecurityRegressionKernel
          def exit(code = 0) = throw(:cucumber_exit, code)
          def exit!(code = 0) = throw(:cucumber_exit, code)
        end

        WebMock.enable!
        WebMock.disable_net_connect!
        endpoint = ENV.fetch("RP_ENDPOINT")
        mock = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
        feature, steps, messages, result_path = ARGV
        stdout = StringIO.new
        stderr = StringIO.new
        args = ["--require", #{library.inspect}, "--require", steps,
                "--format", "ReportPortal::Cucumber::Formatter",
                "--format", "message", "--out", messages, "--name", "Capture targets stay bound", feature]
        status = catch(:cucumber_exit) do
          Cucumber::Cli::Main.new(args, stdout, stderr, SecurityRegressionKernel.new).execute!
        end
        File.write(result_path, JSON.generate(status: status || 0, stdout: stdout.string,
          stderr: stderr.string, logs: mock.logs, items: mock.item_requests))
      RUBY

      endpoint = "https://security-capture-targets.example.test"
      stdout, stderr, process_status = Open3.capture3(
        { "RP_ENDPOINT" => endpoint, "RP_PROJECT" => "demo", "RP_API_KEY" => "synthetic-never-sent",
          "RP_LAUNCH" => "Security capture target regression", "RP_CLIENT_JOIN" => "false",
          "RP_BATCH_SIZE_LOGS" => "1", "RP_HTTP_RETRY_ATTEMPTS" => "1" },
        RbConfig.ruby, "-I#{File.expand_path("../../../lib", __dir__)}", runner,
        feature, steps, messages, result_path, chdir: File.expand_path("../../..", __dir__)
      )

      persist_security_receipt(directory, "capture-lifecycle", stdout, stderr)
      expect(process_status.success?).to be(true), "Cucumber process failed: #{stderr}"
      result = JSON.parse(File.read(result_path))
      expect(result.fetch("status")).to eq(0), "Cucumber failed: #{result.inspect}"
      lifecycle_logs = result.fetch("logs").select { |entry| entry.fetch("message", "").include?("LIFECYCLE_") }
      lifecycle_prefixes = [
        "LIFECYCLE_ACCEPTED_STEP_NIL", "LIFECYCLE_ACCEPTED_STEP_OPEN",
        "LIFECYCLE_ACCEPTED_AFTER_NIL", "LIFECYCLE_ACCEPTED_AFTER_OPEN"
      ]
      expect(lifecycle_logs.map { |entry| lifecycle_prefixes.find { |prefix| entry.fetch("message").start_with?(prefix) } }).to contain_exactly(
        *lifecycle_prefixes
      )

      items_by_uuid = result.fetch("items").to_h { |item| [item.fetch("responseUuid"), item.fetch("body")] }
      expect(lifecycle_logs.map { |entry| items_by_uuid.fetch(entry.fetch("itemUuid")).fetch("name") }.uniq.length).to eq(2)
      log_for = ->(prefix) { lifecycle_logs.find { |entry| entry.fetch("message").start_with?(prefix) } }
      step_log = log_for.call("LIFECYCLE_ACCEPTED_STEP_NIL")
      explicit_step_log = log_for.call("LIFECYCLE_ACCEPTED_STEP_OPEN")
      after_log = log_for.call("LIFECYCLE_ACCEPTED_AFTER_NIL")
      explicit_after_log = log_for.call("LIFECYCLE_ACCEPTED_AFTER_OPEN")
      expect(step_log.fetch("itemUuid")).to eq(explicit_step_log.fetch("itemUuid"))
      expect(after_log.fetch("itemUuid")).to eq(explicit_after_log.fetch("itemUuid"))
      expect(items_by_uuid.fetch(step_log.fetch("itemUuid")).fetch("type")).to eq("STEP")
      expect(items_by_uuid.fetch(after_log.fetch("itemUuid")).fetch("type")).to include("AFTER")

      all_sinks = [result.fetch("stdout"), result.fetch("stderr"), File.read(messages), result.fetch("logs").to_json].join("\n")
      expect(all_sinks).not_to include("LIFECYCLE_REJECTED", "invalid-marker", "fallback")
    end
  end

  %w[ordinary fallback].each do |mode|
    it "keeps native public artifact metadata safe in a natural #{mode} transport-failure spool" do
      feature = File.expand_path("../../fixtures/security_regression/security.feature", __dir__)
      steps = File.expand_path("../../fixtures/security_regression/steps.rb", __dir__)
      mock_helper = File.expand_path("../../support/rp_mock_server.rb", __dir__)
      library = File.expand_path("../../../lib/reportportal_cucumber.rb", __dir__)

      Dir.mktmpdir("security-native-spool-") do |directory|
        messages = File.join(directory, "messages.ndjson")
        result_path = File.join(directory, "result.json")
        runner = File.join(directory, "run.rb")
        png_path = File.join(directory, "synthetic-path.png")
        File.binwrite(png_path, "\x89PNG\r\n\x1A\nsynthetic-png-payload".b)
        File.write(runner, <<~RUBY)
          require "json"
          require "base64"
          require "stringio"
          require "webmock"
          require "reportportal_cucumber"
          require #{mock_helper.inspect}
          require "cucumber/cli/main"

          class SecurityRegressionKernel
            def exit(code = 0) = throw(:cucumber_exit, code)
            def exit!(code = 0) = throw(:cucumber_exit, code)
          end

          WebMock.enable!
          WebMock.disable_net_connect!
          endpoint = ENV.fetch("RP_ENDPOINT")
          ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
          requests = []
          transport_cases = []
          finite_transport_errors = {
            original: '{"\\\\u0070assword":"SECURITY_NATIVE_TRANSPORT_SECRET","detail":"safe offline transport diagnostic"}',
            object_close: 'failed: {]"\\\\u0070assword":"SECURITY_READY5_OBJECT_CLOSE"}',
            array_close: 'failed: [}"\\\\u0070assword":"SECURITY_READY5_ARRAY_CLOSE"]',
            unquoted_key: 'failed: {\\\\u0070assword:"SECURITY_READY5_UNQUOTED_KEY"}',
            leading_separator: "_password=SECURITY_READY5_LEADING_SEPARATOR",
            trailing_separator: "password_=SECURITY_READY5_TRAILING_SEPARATOR",
            surrounding_separators: "-password-=SECURITY_READY5_SURROUNDING_SEPARATORS"
          }.to_a
          stub = WebMock.stub_request(:post, endpoint + "/api/v1/demo/log")
          stub.to_return do |request|
            requests << Base64.strict_encode64(request.body)
            path = ENV.fetch("SECURITY_LONG_PNG_PATH")
            if ENV.fetch("SECURITY_SPOOL_MODE") == "fallback" && request.body.include?("long-legitimate-png-path-") && File.file?(path)
              File.delete(path)
            end
            label, transport_error = finite_transport_errors[(requests.length - 1) % finite_transport_errors.length]
            transport_cases << label
            raise RuntimeError, transport_error
          end
          feature, steps, messages, result_path = ARGV
          stdout = StringIO.new
          stderr = StringIO.new
          args = ["--require", #{library.inspect}, "--require", steps,
                  "--format", "ReportPortal::Cucumber::Formatter",
                  "--format", "message", "--out", messages, "--name", "Public diagnostics stay bounded|Finite transport diagnostics", feature]
          status = catch(:cucumber_exit) do
            Cucumber::Cli::Main.new(args, stdout, stderr, SecurityRegressionKernel.new).execute!
          end
          spool = Dir[File.join(ENV.fetch("RP_SPOOL_DIR"), "*.ndjson")].flat_map do |path|
            File.readlines(path, chomp: true).map { |line| JSON.parse(line) }
          end
          File.write(result_path, JSON.generate(status: status || 0, stdout: stdout.string,
            stderr: stderr.string, requests: requests, spool: spool, transport_cases: transport_cases))
        RUBY

        stdout, stderr, process_status = Open3.capture3(
          { "RP_ENDPOINT" => "https://security-native-spool.example.test", "RP_PROJECT" => "demo",
            "RP_API_KEY" => "synthetic-never-sent", "RP_LAUNCH" => "Security native spool regression",
            "RP_CLIENT_JOIN" => "false", "RP_BATCH_SIZE_LOGS" => "1", "RP_HTTP_RETRY_ATTEMPTS" => "1",
            "RP_SPOOL_DIR" => File.join(directory, "spool"), "SECURITY_LONG_PNG_PATH" => png_path,
            "SECURITY_SPOOL_MODE" => mode, "SECURITY_EDGE_ARTIFACT_MODE" => "path" },
          RbConfig.ruby, "-I#{File.expand_path("../../../lib", __dir__)}", runner,
          feature, steps, messages, result_path, chdir: File.expand_path("../../..", __dir__)
        )

        persist_security_receipt(directory, "spool-#{mode}", stdout, stderr)
        expect(process_status.success?).to be(true), "Cucumber process failed: #{stderr}"
        result = JSON.parse(File.read(result_path))
        expect(result.fetch("status")).to eq(0)
        expect(result.fetch("requests")).not_to be_empty
        expect(result.fetch("spool")).not_to be_empty
        expect(result.fetch("transport_cases").uniq).to contain_exactly(
          "original", "object_close", "array_close", "unquoted_key", "leading_separator",
          "trailing_separator", "surrounding_separators"
        )
        raw_records = result.fetch("spool").select { |record| record["rawSpool"] }
        mode == "fallback" ? expect(raw_records).not_to(be_empty) : expect(raw_records).to(be_empty)
        request_text = result.fetch("requests").map { |body| Base64.strict_decode64(body) }.join("\n")
        all_sinks = [stdout, stderr, result.fetch("stdout"), result.fetch("stderr"), File.read(messages),
                     request_text, result.fetch("spool").to_json].join("\n")
        expect(all_sinks).not_to include(
          "SECURITY_EDGE_", "SECURITY_ARTIFACT_MALFORMED", "SECURITY_ARTIFACT_OVERSIZED_",
          "SECURITY_NATIVE_TRANSPORT_SECRET", "SECURITY_CLI_JSON_", "SECURITY_CLI_ERROR_",
          "SECURITY_CLI_URL_USER", "SECURITY_CLI_URL_PASSWORD_", "SECURITY_CLI_EXPECTED",
          "SECURITY_CLI_ACTUAL", "SECURITY_CLI_OVERSIZED_"
        )
        expect(all_sinks).to include("RuntimeError", "safe offline transport diagnostic")
        expect(all_sinks).not_to include("SECURITY_READY5_")
        expect(all_sinks).to include("password_policy=business-only token_count=12 monkey=visible component=payments; expected [one, two]")
        result.fetch("spool").each do |record|
          expect(record.fetch("spoolError").bytesize).to be <= 2_048
          expect(record.fetch("fallbackSpoolError").bytesize).to be <= 2_048 if record["fallbackSpoolError"]
        end
      end
    end
  end

  it "sanitizes the formatter warning on a natural queue transport failure" do
    Dir.mktmpdir("security-warning-spool-") do |directory|
      endpoint = "https://security-warning.example.test"
      mock = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
      url_password = "SECURITY_WARNING_URL_PASSWORD_" + ("u" * 700)
      error_secret = "SECURITY_WARNING_ERROR_" + ("e" * 400)
      transport_error = %({"\\u0070assword":"#{error_secret}","url":"https://user:#{url_password}@example.test/","padding":"#{"x" * 70_000}"})
      stub_request(:post, "#{endpoint}/api/v1/demo/log").to_raise(RuntimeError.new(transport_error))

      config = ReportportalCucumber::Config.new(
        endpoint: endpoint, project: "demo", api_key: "synthetic-only", batch_size_logs: 1,
        retry_attempts: 1, join: false, spool_dir: File.join(directory, "spool"), exit_flush_timeout_ms: 2_000
      )
      allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
      warnings = []
      allow(ReportportalCucumber.logger).to receive(:warn) { |message| warnings << message.to_s }
      formatter = ReportportalCucumber::Cucumber::Formatter.new(formatter_config)
      formatter.ingest_event("type" => "test_run_started")
      formatter.ingest_event("type" => "test_suite_started", "feature_uri" => "features/security.feature")
      formatter.ingest_event("type" => "test_case_started", "feature_uri" => "features/security.feature",
                             "scenario_name" => "warning boundary", "scenario_line" => 3)
      formatter.ingest_event("type" => "test_step_started", "step_id" => "warning-step",
                             "step_text" => "send a safe short log")
      formatter.emit_world_log(message: "safe short queued diagnostic", level: :error, timestamp: Time.now)

      expect(formatter.instance_variable_get(:@log_buffer).flush(timeout: 3)).to be(true)
      warning_text = warnings.join("\n")
      spool_text = Dir[File.join(directory, "spool", "*.ndjson")].flat_map do |path|
        File.readlines(path, chomp: true)
      end.join("\n")

      expect(warning_text).to include("RuntimeError")
      expect(warning_text).not_to include("SECURITY_WARNING_URL_PASSWORD_", "SECURITY_WARNING_ERROR_")
      expect(spool_text).not_to include("SECURITY_WARNING_URL_PASSWORD_", "SECURITY_WARNING_ERROR_")
      expect(warnings.none?(&:empty?)).to be(true)
      expect(mock.logs).to be_empty
    ensure
      if formatter
        formatter.send(:finalize_reporting, status: "passed", end_time: Time.now)
        formatter.instance_variable_get(:@log_buffer).shutdown(timeout: 3)
      end
    end
  end
end
