# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Service::QueueProcessor do
  let(:spool_dir) { Dir.mktmpdir("m4b-spool-") }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp-m4b.example.test", project: "m4b", api_key: "test-token",
      retry_attempts: 1, retry_base_interval: 0.01, retry_max_interval: 0.01, flush_interval: 10,
      exit_flush_timeout_ms: 200, spool_dir: spool_dir, queue_max_records: 20,
      queue_max_bytes: 100_000, batch_size_logs: 2, batch_max_bytes: 100_000
    )
  end

  class M4BResponseAPI
    attr_reader :calls

    def initialize(&response)
      @response = response
      @calls = []
      @mutex = Mutex.new
    end

    def log_batch(entries:, files:, **_options)
      @mutex.synchronize { @calls << [entries, files] }
      @response.call(entries, files)
    end
  end

  def emit(processor, message)
    processor.emit_log(item_uuid: "step", launch_uuid: "launch", message: message,
                       level: :info, timestamp: Time.now)
  end

  def response_for(entries)
    if entries.length == 1 && !entries.first.key?("file")
      { "id" => "log-#{entries.first.fetch('message')}" }
    else
      { "responses" => entries.map { |entry| { "id" => "log-#{entry.fetch('message')}" } } }
    end
  end

  it "keeps a barrier cutoff fixed while later records are admitted" do
    entered = Queue.new
    release = Queue.new
    blocked = false
    api = M4BResponseAPI.new do |entries, _files|
      unless blocked
        blocked = true
        entered << true
        release.pop
      end
      response_for(entries)
    end
    processor = described_class.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "before-cutoff")).to be(true)
    receipt_thread = Thread.new { processor.flush_receipt(timeout: 2) }
    expect(entered.pop).to be(true)
    expect(emit(processor, "after-cutoff")).to be(true)
    release << true

    receipt = receipt_thread.value
    expect(receipt.cutoff).to eq(1)
    expect(receipt.confirmed).to eq(1)
    expect(receipt.pending).to eq(0)
    expect(receipt).to be_frozen
    expect(receipt.to_h).to be_frozen
    expect(processor.flush(timeout: 2)).to be(true)
    expect(processor.shutdown(timeout: 2)).to be(true)
  ensure
    release << true if release && release.empty?
    processor&.shutdown(timeout: 1)
    FileUtils.remove_entry(spool_dir) if spool_dir && File.exist?(spool_dir)
  end

  it "keeps partial ordered acknowledgements and never resends a confirmed sibling" do
    api = M4BResponseAPI.new do |entries, _files|
      { "responses" => [{ "id" => "confirmed-id" }, { "message" => "bad entry" }] }
    end
    processor = described_class.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "confirmed")).to be(true)
    expect(emit(processor, "definite-failure")).to be(true)

    receipt = processor.flush_receipt(timeout: 2)
    expect(receipt.confirmed).to eq(1)
    expect(receipt.failed).to eq(1)
    expect(receipt.spooled).to eq(1)
    expect(receipt.ambiguous).to eq(0)
    expect(api.calls.length).to eq(1)
    spooled = Dir.glob(File.join(spool_dir, "*.ndjson")).flat_map do |path|
      File.readlines(path).map { |line| JSON.parse(line) }
    end
    expect(spooled).to contain_exactly(include("message" => "definite-failure", "deliveryOutcome" => "failed"))
    expect(processor.reporting_receipt.complete).to be(false)
    expect(processor.shutdown_receipt(timeout: 2).local_settled).to be(true)
  ensure
    processor&.shutdown(timeout: 1)
    FileUtils.remove_entry(spool_dir) if spool_dir && File.exist?(spool_dir)
  end

  it "treats malformed, extra, and missing response positions conservatively" do
    parser = ReportportalCucumber::Service::LogResponseParser
    entries = [{ "message" => "one" }, { "message" => "two" }]
    expect(parser.outcomes(body: { "responses" => [{ "id" => "one" }, { "message" => "bad" }] }, entries: entries))
      .to eq(%i[confirmed failed])
    expect(parser.outcomes(body: { "responses" => [{ "id" => "one" }] }, entries: entries))
      .to eq(%i[confirmed ambiguous])
    expect(parser.outcomes(body: { "responses" => [{ "id" => "one" }, { "id" => "two" }, {}] }, entries: entries))
      .to eq(%i[ambiguous ambiguous])
    expect(parser.outcomes(body: { "responses" => [{ "message" => "bad" }] }, entries: [{ "message" => "only" }]))
      .to eq([:failed])
    expect(parser.outcomes(body: { "id" => "single" }, entries: [{ "message" => "single" }]))
      .to eq([:confirmed])
    expect(parser.outcomes(body: { "responses" => [{ "id" => "attachment-id" }] },
                           entries: [{ "message" => "attached", "file" => { "name" => "a.bin" } }]))
      .to eq([:confirmed])
    expect(parser.outcomes(body: { "responses" => [{ "message" => "attachment rejected" }] },
                           entries: [{ "message" => "attached", "file" => { "name" => "a.bin" } }]))
      .to eq([:failed])
  end

  it "returns promptly at zero-timeout shutdown without synchronously spooling" do
    entered = Queue.new
    release = Queue.new
    api = M4BResponseAPI.new do |entries, files|
      entered << true
      release.pop
      response_for(entries)
    end
    processor = described_class.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "bounded-later-work")).to be(true)
    entered.pop
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    receipt = processor.shutdown_receipt(timeout: 0)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    expect(elapsed).to be < 0.1
    expect(receipt.local_settled).to be(false)
    expect(Dir.glob(File.join(spool_dir, "*.ndjson"))).to be_empty

    release << true
    expect(processor.shutdown(timeout: 2)).to be(true)
    expect(processor.reporting_receipt.confirmed).to eq(1)
  ensure
    release << true if release && release.empty?
    processor&.shutdown(timeout: 1)
    FileUtils.remove_entry(spool_dir) if spool_dir && File.exist?(spool_dir)
  end

  it "keeps the total deadline monotonic and labels async acceptance separately" do
    api = M4BResponseAPI.new { |entries, _files| response_for(entries) }
    async_config = ReportportalCucumber::Config.new(
      endpoint: "https://rp-m4b.example.test", project: "m4b", api_key: "test-token",
      retry_attempts: 1, retry_base_interval: 0.01, retry_max_interval: 0.01, flush_interval: 10,
      exit_flush_timeout_ms: 200, spool_dir: spool_dir, queue_max_records: 20,
      queue_max_bytes: 100_000, batch_size_logs: 2, batch_max_bytes: 100_000, reporting_async: true
    )
    processor = described_class.new(api: api, config: async_config, video_uploader: nil)
    expect(emit(processor, "async-entry")).to be(true)
    deadline = ReportportalCucumber::Service::ReportingDeadline.new(timeout: 1)
    receipt = processor.flush_receipt(timeout: 1, deadline: deadline)
    expect(receipt.accepted_awaiting_persistence).to eq(1)
    expect(receipt.confirmed).to eq(0)
    expect(processor.reporting_receipt.complete).to be(false)
  ensure
    processor&.shutdown(timeout: 1)
    FileUtils.remove_entry(spool_dir) if spool_dir && File.exist?(spool_dir)
  end

  it "does not spool or recount a confirmed chunk when a later payload build fails" do
    bounded_config = ReportportalCucumber::Config.new(
      endpoint: "https://rp-m4b.example.test", project: "m4b", api_key: "test-token",
      retry_attempts: 1, retry_base_interval: 0.01, retry_max_interval: 0.01, flush_interval: 10,
      exit_flush_timeout_ms: 200, spool_dir: spool_dir, queue_max_records: 20,
      queue_max_bytes: 100_000, batch_size_logs: 2, batch_max_bytes: 180
    )
    api = M4BResponseAPI.new { |entries, _files| response_for(entries) }
    processor = described_class.new(api: api, config: bounded_config, video_uploader: nil)
    allow(processor).to receive(:build_payload).and_wrap_original do |original, records|
      raise "subsequent payload failed" if records.length == 1 && records.first.item_uuid == "second"

      original.call(records)
    end
    %w[first second].each do |uuid|
      expect(processor.emit_log(item_uuid: uuid, launch_uuid: "launch", message: "entry-#{uuid}",
                                level: :info, timestamp: Time.now)).to be(true)
    end

    receipt = processor.flush_receipt(timeout: 2)
    expect(receipt.confirmed).to eq(1)
    expect(receipt.ambiguous).to eq(1)
    expect(receipt.spooled).to eq(1)
    expect(api.calls.length).to eq(1)
    spool_entries = Dir.glob(File.join(spool_dir, "*.ndjson")).flat_map do |path|
      File.readlines(path).map { |line| JSON.parse(line) }
    end
    expect(spool_entries.map { |entry| entry.fetch("message") }).to eq(["entry-second"])
  ensure
    processor&.shutdown(timeout: 1)
    FileUtils.remove_entry(spool_dir) if spool_dir && File.exist?(spool_dir)
  end

  it "uses one shutdown budget and keeps cumulative bookkeeping bounded" do
    entered = Queue.new
    release = Queue.new
    api = M4BResponseAPI.new do |entries, _files|
      entered << true
      release.pop
      response_for(entries)
    end
    processor = described_class.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "shutdown-budget")).to be(true)
    entered.pop
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    receipt = processor.shutdown_receipt(timeout: 0.05)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    expect(elapsed).to be < 0.12
    expect(receipt.local_settled).to be(false)
    expect(receipt.pending).to eq(1)
    release << true
    expect(processor.shutdown(timeout: 2)).to be(true)
    expect(processor.reporting_receipt.confirmed).to eq(1)
    expect(processor.diagnostics.fetch(:counters).keys.length).to eq(described_class::DIAGNOSTIC_KEYS.length)
  ensure
    release << true if release && release.empty?
    processor&.shutdown(timeout: 1)
    FileUtils.remove_entry(spool_dir) if spool_dir && File.exist?(spool_dir)
  end

  it "reports duplicate risk when a lost response is followed by a successful retry" do
    api = Class.new do
      attr_reader :attempts

      def initialize
        @attempts = 0
      end

      def log_batch_result(entries:, files:, **_options)
        @attempts += 1 # Server accepts attempt one, then its response is lost.
        @attempts += 1 # The transport retry is acknowledged.
        ReportportalCucumber::ReportPortal::API::LogBatchResult.new(
          body: { "id" => "retried-log-id" }, may_duplicate: true
        )
      end
    end.new
    processor = described_class.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "possibly duplicated after retry")).to be(true)
    receipt = processor.flush_receipt(timeout: 2)
    expect(api.attempts).to eq(2)
    expect(receipt.confirmed).to eq(1)
    expect(receipt.possible_duplicates).to eq(1)
    expect(processor.reporting_receipt(finalization_complete: true).complete).to be(false)
  ensure
    processor&.shutdown(timeout: 1)
    FileUtils.remove_entry(spool_dir) if spool_dir && File.exist?(spool_dir)
  end
end
