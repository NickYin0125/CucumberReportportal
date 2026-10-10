# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe "Independent M4 Store feedback" do
  let(:directory) { Dir.mktmpdir("m4d-store-feedback-") }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://store-feedback.example.test", project: "synthetic",
      api_key: "private-feedback-key", spool_dir: File.join(directory, "spool"),
      spool_max_bytes: 2_000_000, exit_flush_timeout_ms: 2_000,
      batch_size_logs: 20, flush_interval: 60, retry_attempts: 1
    )
  end
  let(:store) { ReportportalCucumber::Service::SpoolStore.new(config: config) }
  let(:timestamp) { Time.utc(2026, 10, 10, 0, 0, 0) }

  after { FileUtils.remove_entry(directory) if File.exist?(directory) }

  def entry(name, index = 0)
    {
      "launchUuid" => "11111111-1111-4111-8111-111111111111",
      "itemUuid" => index.zero? ? "22222222-2222-4222-8222-222222222222" : "33333333-3333-4333-8333-333333333333",
      "time" => "1791590400000", "message" => "original message #{index}", "level" => "INFO",
      "file" => { "name" => name }
    }
  end

  def queue(config)
    stub_request(:post, "#{config.endpoint}/api/v1/#{config.project}/log")
      .to_raise(ReportportalCucumber::ReportingError.new("synthetic offline transport"))
    api = ReportportalCucumber::ReportPortal::API.new(config: config)
    ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config)
  end

  def admit(processor, name, index = 0)
    wire = entry(name, index)
    processor.emit_log(
      launch_uuid: wire.fetch("launchUuid"), item_uuid: wire.fetch("itemUuid"),
      timestamp: timestamp, message: wire.fetch("message"), level: :info,
      attachment: { name: name, mime: "application/octet-stream", bytes: "owner-#{index}-bytes" }
    )
  end

  ["ordinary.bin", ".manifest.json", ".checkpoint.json", ".entries.ndjson", ".attachments-data"].each do |name|
    it "keeps Store logical name #{name.inspect} separate from private metadata" do
      wire = entry(name)
      id = store.persist(entries: [wire],
                         files: [{ name: name, mime: "application/octet-stream", bytes: "original bytes", entry_index: 0 }],
                         outcome: :failed)
      transaction = store.load_transaction(id: id)
      file = transaction.fetch(:files).first

      expect(transaction.fetch(:entries)).to eq([wire])
      expect(file).to include(name: name, entry_index: 0, length: "original bytes".bytesize,
                             sha256: Digest::SHA256.hexdigest("original bytes"), unavailable: false)
      expect(File.binread(file.fetch(:path))).to eq("original bytes")
      expect(File.basename(file.fetch(:path))).to eq("0000.blob")
      expect(store.transactions).to eq([id])
    end

    it "durably retains a public Queue log named #{name.inspect} after transport failure" do
      processor = queue(config)
      expect(admit(processor, name)).to be(true)
      receipt = processor.shutdown_receipt(timeout: 2)
      expect(receipt.spooled).to eq(1)
      expect(receipt.local_settled).to be(true)
      expect(receipt.complete).to be(false)
      expect(processor.diagnostics.dig(:counters, :spool_failed)).to eq(0)

      transaction = store.load_transaction(id: store.transactions.fetch(0))
      logical_name = name == ".attachments-data" ? ".attachments-data.bin" : name
      message = name.end_with?(".json") ? "original message 0\n\n```json\nowner-0-bytes\n```" : "original message 0"
      expected_wire = entry(logical_name).merge("level" => "info", "message" => message)
      expect(transaction.fetch(:entries)).to eq([expected_wire])
      file = transaction.fetch(:files).first
      expect(file).to include(name: logical_name, entry_index: 0, sha256: Digest::SHA256.hexdigest("owner-0-bytes"))
      expect(File.binread(file.fetch(:path))).to eq("owner-0-bytes")
      expect(a_request(:post, "#{config.endpoint}/api/v1/#{config.project}/log")).to have_been_made.once
    ensure
      processor&.shutdown(timeout: 2)
    end
  end

  it "preserves duplicate Store logical names with each owner's bytes and numbered raw path" do
    entries = [entry("same.bin", 0), entry("same.bin", 1)]
    files = entries.each_index.map do |index|
      { name: "same.bin", mime: "application/octet-stream", bytes: "owner-#{index}-bytes", entry_index: index }
    end
    id = store.persist(entries: entries, files: files, outcome: :ambiguous, diagnostics: { rawSpool: true })
    transaction = store.load_transaction(id: id)
    raw = File.readlines(File.join(config.spool_dir, "#{id}.ndjson")).map { |line| JSON.parse(line) }

    expect(transaction.fetch(:entries)).to eq(entries)
    expect(transaction.fetch(:files).map { |file| file.fetch(:path) }.uniq.length).to eq(2)
    transaction.fetch(:files).each do |file|
      index = file.fetch(:entry_index)
      expected_bytes = "owner-#{index}-bytes"
      expect(file).to include(name: "same.bin", length: expected_bytes.bytesize,
                             sha256: Digest::SHA256.hexdigest(expected_bytes))
      expect(File.binread(file.fetch(:path))).to eq(expected_bytes)
      expect(File.join(config.spool_dir, raw.fetch(index).dig("attachment", "spooledPath"))).to eq(file.fetch(:path))
      expect(raw.fetch(index)).to include("rawSpool" => true, "itemUuid" => entries.fetch(index).fetch("itemUuid"),
                                        "time" => entries.fetch(index).fetch("time"))
    end
  end

  it "keeps public Queue duplicate-name uniquification and exact attachment ownership" do
    processor = queue(config)
    2.times { |index| expect(admit(processor, "same.bin", index)).to be(true) }
    expect(processor.shutdown_receipt(timeout: 2).spooled).to eq(2)
    transaction = store.load_transaction(id: store.transactions.fetch(0))

    expect(transaction.fetch(:files).map { |file| file.fetch(:name) }).to eq(["same.bin", "same-1.bin"])
    transaction.fetch(:files).each do |file|
      index = file.fetch(:entry_index)
      expect(transaction.fetch(:entries).fetch(index)).to include(
        "itemUuid" => entry("same.bin", index).fetch("itemUuid"), "time" => entry("same.bin", index).fetch("time")
      )
      expect(File.binread(file.fetch(:path))).to eq("owner-#{index}-bytes")
    end
  ensure
    processor&.shutdown(timeout: 2)
  end

  [true, false].each do |existing_lock|
    it "rejects a symlinked root before #{existing_lock ? 'opening or chmodding' : 'creating'} an outside replay lock" do
      outside = File.join(directory, "outside")
      id = "tx-#{'a' * 32}"
      txdir = File.join(outside, "#{id}.attachments")
      FileUtils.mkdir_p(txdir, mode: 0o700)
      lock = File.join(txdir, ".replay.lock")
      if existing_lock
        File.binwrite(lock, "unrelated outside content")
        File.chmod(0o644, lock)
      end
      original_children = Dir.children(txdir)
      File.symlink(outside, config.spool_dir)

      expect { store.with_transaction(id: id) { raise "unexpected yield" } }
        .to raise_error(ReportportalCucumber::Service::SpoolStore::Error) { |error| expect(error.reason).to eq(:unsafe_root) }
      expect(Dir.children(txdir)).to eq(original_children)
      if existing_lock
        expect(File.binread(lock)).to eq("unrelated outside content")
        expect(File.stat(lock).mode & 0o777).to eq(0o644)
      else
        expect(File.exist?(lock)).to be(false)
      end
    end
  end

  it "warns once with a bounded safe reason when durable Queue retention fails" do
    limited = ReportportalCucumber::Config.new(
      endpoint: config.endpoint, project: config.project, api_key: config.api_key,
      spool_dir: config.spool_dir, spool_max_bytes: 1, batch_size_logs: 1, flush_interval: 60
    )
    output = StringIO.new
    allow(ReportportalCucumber).to receive(:logger).and_return(Logger.new(output))
    processor = queue(limited)
    3.times { |index| expect(admit(processor, "evidence.bin", index)).to be(true) }
    receipt = processor.shutdown_receipt(timeout: 2)
    warnings = output.string.lines.grep(/durable log retention failed/)

    expect(receipt.spooled).to eq(0)
    expect(processor.diagnostics.dig(:counters, :spool_failed)).to eq(3)
    expect(warnings.length).to eq(1)
    expect(warnings.first).to include("quota_exceeded", "reporting remains incomplete")
    expect(warnings.first.bytesize).to be < 512
    expect(output.string).not_to include(config.api_key, config.spool_dir, "original message", "owner-0-bytes")
  ensure
    processor&.shutdown(timeout: 2)
  end
end
