# frozen_string_literal: true

require "spec_helper"
require "base64"
require "digest"
require "timeout"

RSpec.describe "Spool deadline and receipt semantics" do
  SPOOL_DEADLINE_WATCHDOG = 5

  class ManuallyExpiringSpoolDeadline
    def initialize
      @mutex = Mutex.new
      @expired = false
    end

    def remaining
      expired? ? 0 : SPOOL_DEADLINE_WATCHDOG
    end

    def expired?
      @mutex.synchronize { @expired }
    end

    def expire!
      @mutex.synchronize { @expired = true }
    end
  end

  class GatedSpoolResponseAPI
    attr_reader :calls

    def initialize(response:, entered:, release:)
      @response = response
      @entered = entered
      @release = release
      @calls = []
    end

    def log_batch(entries:, files:, deadline: nil)
      @calls << { entries: entries, files: files, deadline: deadline }
      @entered << true
      Timeout.timeout(SPOOL_DEADLINE_WATCHDOG) { @release.pop }
      @response
    end
  end

  let(:directory) { Dir.mktmpdir("spool-deadline-semantics-") }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://spool-deadline.example.test", project: "synthetic",
      spool_dir: File.join(directory, "spool"), exit_flush_timeout_ms: 30_000,
      batch_size_logs: 20, flush_interval: 10
    )
  end
  let(:deadline) { ManuallyExpiringSpoolDeadline.new }
  let(:png) do
    Base64.strict_decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nXxkAAAAASUVORK5CYII=").b
  end
  let(:mixed_response) { { "responses" => [nil, nil, { "id" => "confirmed-diagnostic" }] } }

  before do
    @entered = Queue.new
    @release = Queue.new
    @observers = []
  end

  after do
    @release << true
    begin
      @observers.each { |thread| finish_thread(thread) }
    ensure
      begin
        if @processor
          @processor.shutdown_receipt(timeout: SPOOL_DEADLINE_WATCHDOG)
          finish_thread(@processor.instance_variable_get(:@worker))
          expect(@processor.diagnostics.fetch(:worker_alive)).to be(false)
        end
      ensure
        FileUtils.remove_entry(directory) if File.directory?(directory)
      end
    end
  end

  def finish_thread(thread)
    expect(thread.join(SPOOL_DEADLINE_WATCHDOG)).not_to be_nil, "spool semantics liveness watchdog expired"
    thread.value
  ensure
    if thread.alive?
      thread.kill
      thread.join(SPOOL_DEADLINE_WATCHDOG)
    end
  end

  def start_processor(response)
    @api = GatedSpoolResponseAPI.new(response: response, entered: @entered, release: @release)
    @processor = ReportportalCucumber::Service::QueueProcessor.new(api: @api, config: config, video_uploader: nil)
    @store = @processor.instance_variable_get(:@spool_store)
  end

  def emit(owner, attachment: nil)
    expect(@processor.emit_log(
      launch_uuid: "original-launch", item_uuid: owner, message: "evidence for #{owner}",
      timestamp: Time.utc(2026, 10, 10), level: :info, attachment: attachment
    )).to be(true)
  end

  def emit_png
    emit("original-png-owner", attachment: { bytes: png, name: "original.png", mime: "image/png" })
  end

  def emit_compound
    emit("original-log-owner")
    emit_png
    emit("diagnostic-owner")
  end

  def observe(deadline: nil)
    thread = Thread.new { @processor.flush_receipt(timeout: SPOOL_DEADLINE_WATCHDOG, deadline: deadline) }
    @observers << thread
    expect(Timeout.timeout(SPOOL_DEADLINE_WATCHDOG) { @entered.pop }).to be(true)
    thread
  end

  def expire_after_real_sync
    synchronized = []
    allow(@store).to receive(:sync_directory).and_wrap_original do |original, path|
      result = original.call(path)
      synchronized << path
      # Entries and PNG have really been synced before this staging-directory sync.
      deadline.expire! if File.basename(path).start_with?(".staging-")
      result
    end
    synchronized
  end

  def reopened_transactions
    store = ReportportalCucumber::Service::SpoolStore.new(config: config)
    store.transactions.map { |id| store.load_transaction(id: id) }
  end

  def expect_png(transaction)
    files = transaction.fetch(:files)
    expect(files.length).to eq(1)
    file = files.first
    expect(file).to include(name: "original.png", mime: "image/png", length: png.bytesize,
                            sha256: Digest::SHA256.hexdigest(png), unavailable: false)
    expect(File.binread(file.fetch(:path))).to eq(png)
    expect(Digest::SHA256.file(file.fetch(:path)).hexdigest).to eq(file.fetch(:sha256))
  end

  it "keeps a zero-timeout observer pending while the API is gated, then durably retains the original PNG" do
    start_processor("responses" => [nil])
    allow(@store).to receive(:persist).and_call_original
    emit_png
    observer = observe

    snapshot = @processor.flush_receipt(timeout: 0)
    expect(snapshot.to_h).to include(cutoff: 1, settled: 0, spooled: 0, pending: 1,
                                     timed_out: true, local_settled: false, complete: false)
    expect(@store).not_to have_received(:persist)
    expect(reopened_transactions).to be_empty
    @release << true

    receipt = finish_thread(observer)
    expect(receipt.to_h).to include(settled: 1, ambiguous: 1, spooled: 1, pending: 0,
                                    timed_out: false, local_settled: true, complete: false)
    expect(snapshot.pending).to eq(1)
    transactions = reopened_transactions
    expect(transactions.length).to eq(1)
    expect(transactions.first.fetch(:entries)).to eq(@api.calls.first.fetch(:entries))
    expect_png(transactions.first)
    expect(@store).to have_received(:persist).once
    expect(@api.calls.length).to eq(1)
  end

  { failed: { "message" => "definitive refusal" }, ambiguous: nil }.each do |outcome, response|
    it "truthfully settles #{outcome} without publication when the explicit deadline expires after a real directory sync" do
      start_processor("responses" => [response])
      synchronized = expire_after_real_sync
      expect(@store).to receive(:persist).with(hash_including(deadline: deadline)).and_call_original
      emit_png
      observer = observe(deadline: deadline)
      expect(deadline).not_to be_expired
      @release << true

      receipt = finish_thread(observer)
      expect(synchronized.length).to eq(2)
      expect(synchronized.first).to eq(config.spool_dir)
      expect(synchronized.last).to start_with(File.join(config.spool_dir, ".staging-"))
      expect(deadline).to be_expired
      expect(receipt.to_h).to include(settled: 1, confirmed: 0, spooled: 0, pending: 0,
                                      failed: outcome == :failed ? 1 : 0,
                                      ambiguous: outcome == :ambiguous ? 1 : 0,
                                      local_settled: true, complete: false)
      expect(@processor.diagnostics.dig(:counters, :spool_failed)).to eq(1)
      expect(reopened_transactions).to be_empty
      expect(Dir.glob(File.join(config.spool_dir, "tx-*.ndjson"))).to be_empty
      expect(@api.calls.length).to eq(1)
    end
  end

  it "distinguishes the aggregate mixed receipt from durable retention after expiry" do
    start_processor(mixed_response)
    synchronized = expire_after_real_sync
    emit_compound
    observer = observe(deadline: deadline)
    @release << true
    finish_thread(observer)

    expect(synchronized.length).to eq(2)
    expect(synchronized.first).to eq(config.spool_dir)
    expect(synchronized.last).to start_with(File.join(config.spool_dir, ".staging-"))
    expect(@processor.reporting_receipt.to_h).to include(
      cutoff: 3, settled: 3, confirmed: 1, ambiguous: 2, failed: 0, spooled: 0, pending: 0,
      local_settled: true, timed_out: false, complete: false
    )
    expect(@processor.diagnostics.dig(:counters, :spool_failed)).to eq(1)
    expect(reopened_transactions).to be_empty
    expect(Dir.glob(File.join(config.spool_dir, "tx-*.ndjson"))).to be_empty
    expect(@api.calls.length).to eq(1)
  end

  it "skips the store after explicit shared expiry instead of using its longer configured default" do
    start_processor("responses" => [nil])
    expect(config.exit_flush_timeout_ms / 1000.0).to be > deadline.remaining
    expect(@store).not_to receive(:persist)
    expect(@store).not_to receive(:default_deadline)
    expect(@store).not_to receive(:sync_directory)
    emit_png
    observer = observe(deadline: deadline)
    expect(@api.calls.first.fetch(:deadline)).to equal(deadline)
    deadline.expire!
    @release << true

    receipt = finish_thread(observer)
    expect(receipt.to_h).to include(settled: 1, ambiguous: 1, confirmed: 0, spooled: 0, pending: 0,
                                    local_settled: true, complete: false)
    expect(@processor.diagnostics.dig(:counters, :spool_failed)).to eq(0)
    expect(reopened_transactions).to be_empty
    expect(File.exist?(config.spool_dir)).to be(false)
    expect(@api.calls.length).to eq(1)
  end

  it "durably retains only the two original owners and PNG in the non-expired compound control" do
    start_processor(mixed_response)
    expect(@store).to receive(:persist).with(hash_including(deadline: deadline)).and_call_original
    emit_compound
    observer = observe(deadline: deadline)
    @release << true

    receipt = finish_thread(observer)
    expect(receipt.to_h).to include(cutoff: 3, settled: 3, confirmed: 1, ambiguous: 2, failed: 0,
                                    spooled: 2, pending: 0, local_settled: true, timed_out: false, complete: false)
    expect(deadline).not_to be_expired
    transactions = reopened_transactions
    expect(transactions.length).to eq(1)
    transaction = transactions.first
    expect(transaction.fetch(:entries)).to eq(@api.calls.first.fetch(:entries).first(2))
    expect(transaction.fetch(:entries).map { |entry| entry.fetch("itemUuid") })
      .to eq(%w[original-log-owner original-png-owner])
    expect(transaction.fetch(:entries).map { |entry| entry.fetch("launchUuid") }).to eq(["original-launch"] * 2)
    expect(transaction.fetch(:checkpoint).fetch("states")).to eq([{ "state" => "ambiguous" }] * 2)
    expect_png(transaction)
    expect(@api.calls.length).to eq(1)
  end
end
