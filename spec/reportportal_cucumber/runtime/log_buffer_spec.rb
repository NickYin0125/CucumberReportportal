# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Runtime::LogBuffer do
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp.example.com",
      project: "demo",
      api_key: "token",
      batch_size_logs: 2,
      flush_interval: 5,
      retry_attempts: 1
    )
  end

  let(:api) { instance_double(ReportportalCucumber::ReportPortal::API) }

  it "flushes two logs as a single batch request" do
    captured = []
    allow(api).to receive(:log_batch) do |entries:, files:|
      captured << [entries, files]
    end

    buffer = described_class.new(api: api, config: config)
    buffer.emit_log(item_uuid: "item-1", launch_uuid: "launch-1", message: "one", level: :info, timestamp: Time.now)
    buffer.emit_log(item_uuid: "item-1", launch_uuid: "launch-1", message: "two", level: :info, timestamp: Time.now)
    buffer.flush(timeout: 2)
    buffer.shutdown(timeout: 2)

    expect(captured.length).to eq(1)
    expect(captured.first.first.map { |entry| entry["message"] }).to eq(%w[one two])
    expect(captured.first.last).to eq([])
  end

  it "flushes all pending logs on shutdown" do
    captured = []
    allow(api).to receive(:log_batch) do |entries:, files:|
      captured << [entries, files]
    end

    buffer = described_class.new(api: api, config: config)
    buffer.emit_log(item_uuid: "item-1", launch_uuid: "launch-1", message: "one", level: :info, timestamp: Time.now)
    buffer.emit_log(item_uuid: "item-1", launch_uuid: "launch-1", message: "two", level: :info, timestamp: Time.now)
    buffer.emit_log(item_uuid: "item-1", launch_uuid: "launch-1", message: "three", level: :info, timestamp: Time.now)
    buffer.shutdown(timeout: 2)

    messages = captured.flat_map { |entries, _files| entries.map { |entry| entry["message"] } }
    expect(messages).to eq(%w[one two three])
  end

  it "raw-spools logs when payload construction itself fails" do
    Dir.mktmpdir do |dir|
      spool_config = ReportportalCucumber::Config.new(
        endpoint: "https://rp.example.com",
        project: "demo",
        api_key: "token",
        batch_size_logs: 1,
        flush_interval: 0.1,
        retry_attempts: 1,
        spool_dir: File.join(dir, "spool")
      )
      errors = []
      allow(ReportportalCucumber::Service::PayloadBuilder).to receive(:build_log_batch)
        .and_raise(ArgumentError, "builder broke")
      allow(api).to receive(:log_batch)

      buffer = described_class.new(api: api, config: spool_config, on_error: ->(error) { errors << error })
      buffer.emit_log(
        item_uuid: "step-1",
        launch_uuid: "launch-1",
        message: "raw evidence",
        level: :info,
        timestamp: Time.utc(2026, 5, 30, 12, 0, 0),
        attachment: { name: "../../trace;bad.log", mime: "text/plain", bytes: "trace" }
      )
      expect(buffer.shutdown(timeout: 2)).to be(true)

      ndjson = Dir[File.join(dir, "spool", "*.ndjson")].first
      record = JSON.parse(File.read(ndjson))
      attachment_path = Dir[File.join(dir, "spool", "*.attachments", "*")].first

      expect(errors.first).to be_a(ArgumentError)
      expect(api).not_to have_received(:log_batch)
      expect(record).to include("rawSpool" => true, "message" => "raw evidence")
      expect(record.dig("attachment", "name")).to eq("trace_bad.log")
      expect(File.basename(attachment_path)).to eq("trace_bad.log")
      expect(File.binread(attachment_path)).to eq("trace")
    end
  end
end
