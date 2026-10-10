# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "Queue spool diagnostic security" do
  def adversarial_transport_message
    json_password = "SECURITY_SPOOL_JSON_" + ("p" * 320)
    user = "SECURITY_SPOOL_USER_" + ("u" * 620)
    url_password = "SECURITY_SPOOL_URL_PASSWORD_" + ("v" * 320)
    oversized = "SECURITY_SPOOL_OVERSIZED_" + ("x" * 70_000)
    url = "https://#{user}:#{url_password}@example.test/path"
    %({"\\u0070assword":"#{json_password}","url":"#{url}","diagnostic":"#{oversized}"})
  end

  def config_for(directory)
    ReportportalCucumber::Config.new(
      endpoint: "https://security-spool.example.test", project: "demo", api_key: "synthetic-only",
      batch_size_logs: 1, flush_interval: 0.01, retry_attempts: 1, join: false,
      spool_dir: File.join(directory, "spool"), exit_flush_timeout_ms: 2_000
    )
  end

  def install_transport_failure(message)
    stub_request(:post, "https://security-spool.example.test/api/v1/demo/log")
      .to_raise(RuntimeError.new(message))
  end

  def spool_records(directory)
    Dir[File.join(directory, "spool", "*.ndjson")].flat_map do |path|
      File.readlines(path, chomp: true).map { |line| JSON.parse(line) }
    end
  end

  def expect_no_adversarial_canaries(text)
    expect(text).not_to include(
      "SECURITY_SPOOL_JSON_", "SECURITY_SPOOL_USER_", "SECURITY_SPOOL_URL_PASSWORD_",
      "SECURITY_SPOOL_OVERSIZED_", "SECURITY_SPOOL_ARTIFACT_MALFORMED",
      "SECURITY_SPOOL_ARTIFACT_OVERSIZED_"
    )
  end

  it "sanitizes raw transport exception metadata in the ordinary NDJSON spool" do
    Dir.mktmpdir("security-ordinary-spool-") do |directory|
      install_transport_failure(adversarial_transport_message)
      api = ReportportalCucumber::ReportPortal::API.new(config: config_for(directory))
      processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config_for(directory))
      processor.emit_log(item_uuid: "synthetic-step", launch_uuid: "synthetic-launch",
                         message: "safe short transport diagnostic", level: :error, timestamp: Time.now)

      expect(processor.flush(timeout: 3)).to be(true)
      expect(processor.shutdown(timeout: 3)).to be(true)
      records = spool_records(directory)
      expect(records).not_to be_empty
      expect(records.first.fetch("message")).to eq("safe short transport diagnostic")
      expect_no_adversarial_canaries(records.to_json)
      expect(records.first.fetch("spoolError").bytesize).to be <= 2_048
    ensure
      processor&.shutdown(timeout: 2)
    end
  end

  it "sanitizes ordinary and fallback metadata after a natural payload-build failure" do
    Dir.mktmpdir("security-fallback-spool-") do |directory|
      transport_message = adversarial_transport_message
      install_transport_failure(transport_message)
      config = config_for(directory)
      api = ReportportalCucumber::ReportPortal::API.new(config: config)
      processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config)
      transport_failed = false
      allow(api).to receive(:log_batch).and_wrap_original do |original, **arguments|
        begin
          original.call(**arguments)
        rescue StandardError
          transport_failed = true
          raise
        end
      end
      injected_faults = 0
      allow(ReportportalCucumber::Service::PayloadBuilder).to receive(:build_log_batch).and_wrap_original do |original, records|
        if transport_failed
          injected_faults += 1
          raise RuntimeError, "SECURITY_SPOOL_FALLBACK_#{transport_message}"
        end

        original.call(records)
      end
      processor.emit_log(item_uuid: "synthetic-step", launch_uuid: "synthetic-launch",
                         message: "safe short fallback diagnostic".freeze,
                         level: :error, timestamp: Time.now)

      expect(processor.flush(timeout: 3)).to be(true)
      expect(processor.shutdown(timeout: 3)).to be(true)
      records = spool_records(directory)
      expect(records).not_to be_empty
      expect(records.first.fetch("rawSpool")).to be(true)
      expect(records.first.fetch("message")).to eq("safe short fallback diagnostic")
      expect_no_adversarial_canaries(records.to_json)
      expect(records.first.fetch("spoolError").bytesize).to be <= 2_048
      expect(records.first.fetch("fallbackSpoolError").bytesize).to be <= 2_048
      expect(injected_faults).to eq(1)
      expect(a_request(:post, "https://security-spool.example.test/api/v1/demo/log")).to have_been_made.once
    ensure
      processor&.shutdown(timeout: 2)
    end
  end

  it "redacts an in-budget escaped-key JSON transport error in ordinary spool metadata" do
    Dir.mktmpdir("security-in-budget-spool-") do |directory|
      secret = "SECURITY_SPOOL_IN_BUDGET_JSON"
      message = %({"\\u0070assword":"#{secret}","detail":"safe transport diagnostic"})
      expect(message.bytesize).to be < 64 * 1024
      install_transport_failure(message)
      config = config_for(directory)
      api = ReportportalCucumber::ReportPortal::API.new(config: config)
      processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config)
      processor.emit_log(item_uuid: "synthetic-step", launch_uuid: "synthetic-launch",
                         message: "safe short ordinary message", level: :error, timestamp: Time.now)

      expect(processor.flush(timeout: 3)).to be(true)
      expect(processor.shutdown(timeout: 3)).to be(true)
      metadata = spool_records(directory).first.fetch("spoolError")
      expect(metadata.bytesize).to be <= 2_048
      expect(metadata).not_to include(secret)
      parsed = JSON.parse(metadata)
      expect(parsed.fetch("detail")).to eq("safe transport diagnostic")
    ensure
      processor&.shutdown(timeout: 2)
    end
  end

  it "redacts in-budget ordinary and fallback metadata on the natural fallback path" do
    Dir.mktmpdir("security-in-budget-fallback-") do |directory|
      original_secret = "SECURITY_FALLBACK_ORIGINAL_JSON"
      original_error = %({"\\u0070assword":"#{original_secret}","detail":"safe original"})
      user = "synthetic-user-" + ("u" * 620)
      fallback_secret = "SECURITY_FALLBACK_URL_PASSWORD"
      fallback_error = "https://#{user}:#{fallback_secret}@example.test/path"
      expect(original_error.bytesize).to be < 64 * 1024
      install_transport_failure(original_error)
      config = config_for(directory)
      api = ReportportalCucumber::ReportPortal::API.new(config: config)
      processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config)
      transport_failed = false
      allow(api).to receive(:log_batch).and_wrap_original do |original, **arguments|
        begin
          original.call(**arguments)
        rescue StandardError
          transport_failed = true
          raise
        end
      end
      injected_faults = 0
      allow(ReportportalCucumber::Service::PayloadBuilder).to receive(:build_log_batch).and_wrap_original do |original, records|
        if transport_failed
          injected_faults += 1
          raise RuntimeError, fallback_error
        end

        original.call(records)
      end
      processor.emit_log(item_uuid: "synthetic-step", launch_uuid: "synthetic-launch",
                         message: "safe short fallback diagnostic".freeze,
                         level: :error, timestamp: Time.now)

      expect(processor.flush(timeout: 3)).to be(true)
      expect(processor.shutdown(timeout: 3)).to be(true)
      record = spool_records(directory).first
      expect(record.fetch("rawSpool")).to be(true)
      expect(record.fetch("spoolError").bytesize).to be <= 2_048
      expect(record.fetch("fallbackSpoolError").bytesize).to be <= 2_048
      expect(record.fetch("spoolError")).not_to include(original_secret)
      expect(record.fetch("fallbackSpoolError")).not_to include(fallback_secret, user)
      expect(record.fetch("fallbackSpoolError")).to include("example.test")
      expect(injected_faults).to eq(1)
      expect(a_request(:post, "https://security-spool.example.test/api/v1/demo/log")).to have_been_made.once
    ensure
      processor&.shutdown(timeout: 2)
    end
  end

  it "keeps malformed and oversized public evidence names out of a natural transport-failure spool" do
    Dir.mktmpdir("security-artifact-spool-") do |directory|
      config = config_for(directory)
      allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
      ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: config.endpoint).install!
      transport_secret = "SECURITY_SPOOL_ARTIFACT_TRANSPORT_" + ("t" * 300)
      stub_request(:post, "https://security-spool.example.test/api/v1/demo/log")
        .to_raise(RuntimeError.new(%({"\\u0070assword":"#{transport_secret}"})))
      formatter_config = Class.new do
        def on_event(_name, &_block); end
        def include(_mod); end
      end.new
      formatter = ReportportalCucumber::Cucumber::Formatter.new(formatter_config)
      formatter.ingest_event("type" => "test_run_started")
      formatter.ingest_event("type" => "test_suite_started", "feature_uri" => "features/security.feature")
      formatter.ingest_event("type" => "test_case_started", "feature_uri" => "features/security.feature",
                             "scenario_name" => "artifact spool boundary", "scenario_line" => 3)
      formatter.ingest_event("type" => "test_step_started", "step_id" => "artifact-spool-step",
                             "step_text" => "attach synthetic PNG")
      malformed_name = %({"pass\\x77ord":"SECURITY_SPOOL_ARTIFACT_MALFORMED"}.png)
      oversized_name = "SECURITY_SPOOL_ARTIFACT_OVERSIZED_" + ("n" * 70_000) + ".png"
      expect(formatter.rp_evidence(
        action: "safe artifact spool action", error: RuntimeError.new("safe"),
        artifacts: [
          { bytes: "synthetic", name: malformed_name, mime: "image/png" },
          { bytes: "synthetic", name: oversized_name, mime: "image/png" }
        ], target: formatter.rp_capture_target
      )).to be(true)

      expect(formatter.instance_variable_get(:@log_buffer).flush(timeout: 3)).to be(true)
      spool_text = Dir[File.join(directory, "spool", "*.ndjson")].map { |path| File.read(path) }.join("\n")
      expect_no_adversarial_canaries(spool_text)
      expect(spool_text).not_to include(transport_secret)
    ensure
      if formatter
        formatter.send(:finalize_reporting, status: "passed", end_time: Time.now)
        formatter.instance_variable_get(:@log_buffer).shutdown(timeout: 3)
      end
    end
  end
end
