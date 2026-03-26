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
end
