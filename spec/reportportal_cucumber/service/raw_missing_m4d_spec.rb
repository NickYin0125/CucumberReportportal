# frozen_string_literal: true

require "spec_helper"

RSpec.describe "M4 raw Queue retention after attachment disappearance" do
  let(:directory) { Dir.mktmpdir("m4d-raw-missing-") }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://raw-missing.example.test", project: "synthetic", api_key: "synthetic-key",
      spool_dir: File.join(directory, "spool"), batch_size_logs: 20, flush_interval: 60,
      retry_attempts: 1, exit_flush_timeout_ms: 2_000
    )
  end
  let(:store) { ReportportalCucumber::Service::SpoolStore.new(config: config) }
  let(:api) { ReportportalCucumber::ReportPortal::API.new(config: config) }
  let(:processor) { ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config) }
  let(:log_url) { "#{config.endpoint}/api/v1/#{config.project}/log" }
  let(:timestamp) { Time.utc(2026, 10, 10) }
  let(:png) { "\x89PNG\r\n\x1A\n\xFF\xFE\x80\x00".b }
  let(:launch_uuid) { "11111111-1111-4111-8111-111111111111" }
  let(:item_uuids) do
    ["22222222-2222-4222-8222-222222222222", "33333333-3333-4333-8333-333333333333"]
  end
  let(:transport_secret) { "RAW_MISSING_TRANSPORT_SECRET" }
  let(:builder_secret) { "RAW_MISSING_BUILDER_SECRET" }

  after do
    processor.shutdown(timeout: 2)
    FileUtils.remove_entry(directory) if File.exist?(directory)
  end

  def inject_builder_fault_after_transport
    transport_failed = false
    allow(api).to receive(:log_batch).and_wrap_original do |original, **arguments|
      begin
        original.call(**arguments)
      rescue StandardError
        transport_failed = true
        raise
      end
    end
    @builder_faults = 0
    allow(ReportportalCucumber::Service::PayloadBuilder).to receive(:build_log_batch).and_wrap_original do |original, records|
      if transport_failed
        @builder_faults += 1
        raise RuntimeError, %({"\\u0070assword":"#{builder_secret}","detail":"safe builder failure"})
      end

      original.call(records)
    end
  end

  def admit(attachment, index)
    processor.emit_log(
      launch_uuid: launch_uuid, item_uuid: item_uuids.fetch(index),
      message: "original evidence #{index}", level: :error, timestamp: timestamp, attachment: attachment
    )
  end

  it "publishes explicit unavailable metadata and exact sibling bytes after a real failed POST" do
    source = File.join(directory, "deleted.png")
    File.binwrite(source, png)
    attachment = { path: source.dup, name: "client\\evidence\\deleted".dup, mime: "image/png".dup }
    sibling = { bytes: png.dup, name: "known-good.png", mime: "image/png" }
    requests = []
    warnings = []
    allow(ReportportalCucumber.logger).to receive(:warn) { |message| warnings << message }
    stub_request(:post, log_url).to_return do |request|
      requests << request.body.b
      File.delete(source)
      attachment.fetch(:path).replace(File.join(directory, "changed.png"))
      attachment.fetch(:name).replace("changed.txt")
      attachment.fetch(:mime).replace("text/plain")
      sibling.fetch(:bytes).replace("changed bytes")
      raise RuntimeError, %({"\\u0070assword":"#{transport_secret}","detail":"safe transport failure"})
    end
    inject_builder_fault_after_transport

    expect(admit(attachment, 0)).to be(true)
    expect(admit(sibling, 1)).to be(true)
    receipt = processor.shutdown_receipt(timeout: 2)

    expect(receipt).to have_attributes(spooled: 2, ambiguous: 2, confirmed: 0, local_settled: true, complete: false)
    expect(@builder_faults).to eq(1)
    expect(a_request(:post, log_url)).to have_been_made.once
    expect(requests.fetch(0).scan(png).length).to eq(2)
    expect(requests.fetch(0)).to include('filename="deleted.png"', 'filename="known-good.png"')
    expect(store.transactions.length).to eq(1)
    transaction = store.load_transaction(id: store.transactions.fetch(0))
    records = File.readlines(Dir[File.join(config.spool_dir, "*.ndjson")].fetch(0), chomp: true)
      .map { |line| JSON.parse(line) }
    records.each_with_index do |record, index|
      expect(record).to include("rawSpool" => true, "launchUuid" => launch_uuid,
                               "itemUuid" => item_uuids.fetch(index), "time" => "1791590400000",
                               "message" => "original evidence #{index}", "level" => "error")
      expect(record.fetch("spoolError").bytesize).to be <= 2_048
      expect(record.fetch("fallbackSpoolError").bytesize).to be <= 2_048
    end
    expect(records.fetch(0).fetch("attachment")).to eq(
      "name" => "deleted.png", "mime" => "image/png", "missing" => true, "unavailable" => true
    )
    missing = transaction.fetch(:files).fetch(0)
    expect(missing).to include(name: "deleted.png", mime: "image/png", entry_index: 0,
                              unavailable: true, reason: "source_unavailable")
    expect(missing).not_to have_key(:length)
    expect(missing).not_to have_key(:sha256)
    expect(File.exist?(File.join(transaction.fetch(:directory), missing.fetch(:path)))).to be(false)
    healthy = transaction.fetch(:files).fetch(1)
    expect(healthy).to include(name: "known-good.png", mime: "image/png", entry_index: 1,
                              unavailable: false, length: png.bytesize, sha256: Digest::SHA256.hexdigest(png))
    expect(File.binread(healthy.fetch(:path))).to eq(png)
    expect(File.join(config.spool_dir, records.fetch(1).dig("attachment", "spooledPath")))
      .to eq(healthy.fetch(:path))
    expect(transaction.fetch(:entries)).to eq(records.map do |record|
      record.slice("launchUuid", "itemUuid", "time", "message", "level", "file")
    end)
    expect(transaction.fetch(:checkpoint).fetch("states")).to eq(Array.new(2) { { "state" => "ambiguous" } })
    expect([records.to_json, transaction.fetch(:manifest).to_json, warnings.join, requests.join].join)
      .not_to include(transport_secret, builder_secret, "changed.png", "changed.txt", "changed bytes")
    expect(processor.diagnostics).to include(current_records: 0, current_bytes: 0, worker_alive: false)
    expect(processor.diagnostics.fetch(:counters)).to include(spool_failed: 0, settled: 2)
  end

  it "still refuses a path replaced by a symlink rather than publishing external bytes or empty success" do
    source = File.join(directory, "original.png")
    external = File.join(directory, "external.png")
    File.binwrite(source, png)
    File.binwrite(external, "external private bytes")
    File.chmod(0o640, external)
    original_mode = File.stat(external).mode
    warnings = []
    allow(ReportportalCucumber.logger).to receive(:warn) { |message| warnings << message }
    stub_request(:post, log_url).to_return do |_request|
      File.delete(source)
      File.symlink(external, source)
      raise RuntimeError, %({"\\u0070assword":"#{transport_secret}"})
    end
    inject_builder_fault_after_transport

    expect(admit({ path: source, name: "original.png", mime: "image/png" }, 0)).to be(true)
    expect(processor.shutdown_receipt(timeout: 2))
      .to have_attributes(spooled: 0, ambiguous: 1, local_settled: true, complete: false)
    expect(@builder_faults).to eq(1)
    expect(a_request(:post, log_url)).to have_been_made.once
    expect(store.transactions).to be_empty
    expect(Dir[File.join(config.spool_dir, "*.ndjson")]).to be_empty
    expect(File.binread(external)).to eq("external private bytes")
    expect(File.stat(external).mode).to eq(original_mode)
    expect(warnings.length).to eq(1)
    expect(warnings.join).not_to include(source, external, transport_secret, builder_secret)
    expect(processor.diagnostics).to include(current_records: 0, current_bytes: 0, worker_alive: false)
    expect(processor.diagnostics.fetch(:counters)).to include(spool_failed: 1, settled: 1)
  end
end
