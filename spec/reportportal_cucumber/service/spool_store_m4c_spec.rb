# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Service::SpoolStore do
  let(:directory) { Dir.mktmpdir("m4c-store-") }
  let(:config) do
    ReportportalCucumber::Config.new(endpoint: "https://rp.example.test", project: "synthetic",
                                     api_key: "never-persist-this", spool_dir: File.join(directory, "spool"),
                                     spool_max_bytes: 2_000_000, exit_flush_timeout_ms: 1_000)
  end
  let(:store) { described_class.new(config: config) }
  let(:entry) do
    { "launchUuid" => "launch-original", "itemUuid" => "step-original", "time" => "1234",
      "message" => "retained message", "level" => "ERROR" }
  end

  after { FileUtils.remove_entry(directory) if File.exist?(directory) }

  it "publishes a private transaction and returns only canonical wire entries" do
    id = store.persist(entries: [entry], files: [], outcome: :failed,
                       diagnostics: { spoolError: "synthetic failure" })
    transaction = store.load_transaction(id: id)

    expect(store.transactions).to eq([id])
    expect(transaction.fetch(:entries)).to eq([entry])
    expect(transaction.fetch(:manifest).fetch("entries").fetch("sha256")).to match(/\A[0-9a-f]{64}\z/)
    expect(File.stat(transaction.fetch(:directory)).mode & 0o777).to eq(0o700)
    expect(File.stat(File.join(transaction.fetch(:directory), ".manifest.json")).mode & 0o777).to eq(0o600)
    expect(File.read(File.join(config.spool_dir, "#{id}.ndjson"))).to include("spoolError")
    expect(File.read(File.join(config.spool_dir, "#{id}.ndjson"))).not_to include("never-persist-this")
  end

  it "streams attachments with a digest and preserves an explicit unavailable marker" do
    source = File.join(directory, "evidence.txt")
    File.binwrite(source, "artifact-bytes")
    attached_entry = entry.merge("file" => { "name" => "evidence.txt" })
    id = store.persist(entries: [attached_entry], files: [{ name: "evidence.txt", mime: "text/plain", path: source }],
                       outcome: :ambiguous)
    loaded = store.load_transaction(id: id).fetch(:files).first
    expect(File.binread(loaded.fetch(:path))).to eq("artifact-bytes")
    expect(loaded.fetch(:sha256)).to eq(Digest::SHA256.hexdigest("artifact-bytes"))
    expect(store.load_transaction(id: id).fetch(:checkpoint).fetch("states").first.fetch("state")).to eq("ambiguous")

    missing = File.join(directory, "gone.txt")
    missing_id = store.persist(entries: [entry.merge("file" => { "name" => "gone.txt" })],
                               files: [{ name: "gone.txt", mime: "text/plain", path: missing }], outcome: :failed)
    unavailable = store.load_transaction(id: missing_id).fetch(:files).first
    expect(unavailable).to include(unavailable: true, reason: "source_unavailable")
    expect(unavailable).not_to have_key(:length)
    expect(unavailable).not_to have_key(:sha256)
  end

  it "rejects a symlinked attachment directory instead of reading outside the transaction" do
    source = File.join(directory, "evidence.txt")
    File.binwrite(source, "safe")
    id = store.persist(entries: [entry.merge("file" => { "name" => "evidence.txt" })],
                       files: [{ name: "evidence.txt", mime: "text/plain", path: source }], outcome: :failed)
    txdir = File.join(config.spool_dir, "#{id}.attachments")
    FileUtils.remove_entry(File.join(txdir, ".attachments-data"))
    outside = File.join(directory, "outside")
    Dir.mkdir(outside)
    File.binwrite(File.join(outside, "0000.blob"), "safe")
    File.symlink(outside, File.join(txdir, ".attachments-data"))

    expect { store.load_transaction(id: id) }.to raise_error(described_class::Error, "Spool transaction unavailable")
  end

  it "binds checkpoints to transaction identity and makes confirmed acknowledgements immutable" do
    first = store.persist(entries: [entry], files: [], outcome: :failed)
    second = store.persist(entries: [entry], files: [], outcome: :failed)
    checkpoint_path = File.join(config.spool_dir, "#{first}.attachments", ".checkpoint.json")
    checkpoint = JSON.parse(File.read(checkpoint_path))
    checkpoint["transactionId"] = second
    File.write(checkpoint_path, JSON.generate(checkpoint))
    expect { store.load_transaction(id: first) }.to raise_error(described_class::Error)

    state = [{ "state" => "confirmed", "id" => "rp-log-1" }]
    updated = store.update_checkpoint(id: second, states: state)
    expect(updated.fetch("states")).to eq(state)
    expect { store.update_checkpoint(id: second, states: [{ "state" => "pending" }]) }
      .to raise_error(described_class::Error)
  end

  it "maps a durable in-flight checkpoint to ambiguity after reopening" do
    id = store.persist(entries: [entry], files: [], outcome: :failed)
    store.update_checkpoint(id: id, states: [{ "state" => "in_flight" }])
    reopened = described_class.new(config: config).load_transaction(id: id)
    expect(reopened.fetch(:checkpoint).fetch("states").first.fetch("state")).to eq("ambiguous")
  end

  it "does not publish or synchronously spool after an expired deadline" do
    deadline = ReportportalCucumber::Service::ReportingDeadline.new(timeout: 0)
    expect { store.persist(entries: [entry], files: [], outcome: :failed, deadline: deadline) }
      .to raise_error(described_class::Error)
    expect(store.transactions).to be_empty
  end

  it "charges staging residue to quota without exposing it as a transaction" do
    FileUtils.mkdir_p(config.spool_dir)
    residue = File.join(config.spool_dir, ".staging-interrupted")
    Dir.mkdir(residue, 0o700)
    File.write(File.join(residue, "partial-entries"), "x" * 2_000_001)
    expect(store.transactions).to be_empty
    expect { store.persist(entries: [entry], files: [], outcome: :failed) }
      .to raise_error(described_class::Error)
  end

  it "serializes concurrent process writers against one global quota" do
    shared_config = ReportportalCucumber::Config.new(endpoint: "https://rp.example.test", project: "synthetic",
                                                      spool_dir: File.join(directory, "fork-spool"),
                                                      spool_max_bytes: 5_000, exit_flush_timeout_ms: 2_000)
    Dir.mkdir(shared_config.spool_dir, 0o700)
    ready_read, ready_write = IO.pipe
    start_read, start_write = IO.pipe
    result_read, result_write = IO.pipe
    pids = 2.times.map do |index|
      fork do
        ready_read.close
        start_write.close
        result_read.close
        ready_write.write("r")
        ready_write.flush
        start_read.read(1)
        child_store = described_class.new(config: shared_config)
        child_entry = entry.merge("message" => "x" * 3_000, "itemUuid" => "step-#{index}")
        result = begin
          child_store.persist(entries: [child_entry], files: [], outcome: :failed)
          "published"
        rescue described_class::Error
          "quota-refused"
        end
        result_write.write("#{result}\n")
        result_write.flush
        exit! 0
      end
    end
    ready_write.close
    start_read.close
    result_write.close
    2.times { ready_read.read(1) }
    start_write.write("gg")
    start_write.close
    results = result_read.read.lines.map(&:strip)
    pids.each { |pid| Process.wait(pid) }

    expect(results).to contain_exactly("published", "quota-refused")
    expect(described_class.new(config: shared_config).transactions.length).to eq(1)
  ensure
    [ready_read, ready_write, start_read, start_write, result_read, result_write].compact.each { |pipe| pipe.close unless pipe.closed? }
    pids&.each { |pid| Process.kill("KILL", pid) rescue nil; Process.wait(pid) rescue nil }
  end

  it "refuses a finite default lock wait when another process owns the quota lock" do
    short_config = ReportportalCucumber::Config.new(endpoint: "https://rp.example.test", project: "synthetic",
                                                     spool_dir: File.join(directory, "locked-spool"),
                                                     exit_flush_timeout_ms: 60)
    Dir.mkdir(short_config.spool_dir, 0o700)
    lock_path = File.join(short_config.spool_dir, ".quota.lock")
    ready_read, ready_write = IO.pipe
    pid = fork do
      ready_read.close
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        ready_write.write("r")
        ready_write.flush
        sleep 0.3
      end
      exit! 0
    end
    ready_write.close
    ready_read.read(1)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect { described_class.new(config: short_config).persist(entries: [entry], files: [], outcome: :failed) }
      .to raise_error(described_class::Error)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.2
  ensure
    ready_read&.close unless ready_read&.closed?
    ready_write&.close unless ready_write&.closed?
    begin
      Process.kill("KILL", pid) if pid
      Process.wait(pid) if pid
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end

  it "rejects evidence changed during a bounded streaming copy" do
    source = File.join(directory, "growing.txt")
    File.binwrite(source, "a" * (described_class::COPY_CHUNK_BYTES * 2))
    attachment_entry = entry.merge("file" => { "name" => "growing.txt" })
    changed = false
    allow(store).to receive(:write_quota_chunk).and_wrap_original do |original, output, bytes, deadline|
      result = original.call(output, bytes, deadline)
      if output.path.end_with?("0000.blob") && !changed
        changed = true
        File.open(source, "ab") { |file| file.write("growth") }
      end
      result
    end

    expect do
      store.persist(entries: [attachment_entry],
                    files: [{ name: "growing.txt", mime: "text/plain", path: source }], outcome: :failed)
    end.to raise_error(described_class::Error)
    expect(store.transactions).to be_empty
  end

  it "retains no published receipt when disk-full interrupts writing or commit-marker publication" do
    allow(store).to receive(:write_quota_chunk).and_raise(Errno::ENOSPC)
    expect { store.persist(entries: [entry], files: [], outcome: :failed) }
      .to raise_error(described_class::Error)
    expect(store.transactions).to be_empty

    second_store = described_class.new(config: config)
    allow(File).to receive(:link).and_raise(Errno::ENOSPC)
    expect { second_store.persist(entries: [entry], files: [], outcome: :failed) }
      .to raise_error(described_class::Error)
    expect(second_store.transactions).to be_empty
  end

  it "keeps the old in-flight checkpoint when old-plus-temporary quota is unavailable" do
    id = store.persist(entries: [entry], files: [], outcome: :failed)
    store.update_checkpoint(id: id, states: [{ "state" => "in_flight" }])
    root_bytes = Dir.glob(File.join(config.spool_dir, "**/*"), File::FNM_DOTMATCH)
                    .select { |path| File.file?(path) }.sum { |path| File.size(path) }
    store.instance_variable_set(:@max_bytes, root_bytes)

    expect { store.update_checkpoint(id: id, states: [{ "state" => "confirmed", "id" => "ack" }]) }
      .to raise_error(described_class::Error)
    raw = JSON.parse(File.read(File.join(config.spool_dir, "#{id}.attachments", ".checkpoint.json")))
    expect(raw.fetch("states").first.fetch("state")).to eq("in_flight")
  end

  it "does not bypass a failed queue spool into a temporary directory" do
    queue_dir = File.join(directory, "quota-queue")
    queue_config = ReportportalCucumber::Config.new(endpoint: "https://rp.example.test", project: "synthetic",
                                                    spool_dir: queue_dir, spool_max_bytes: 1,
                                                    exit_flush_timeout_ms: 500, batch_size_logs: 1,
                                                    flush_interval: 0.1)
    api = Object.new
    def api.log_batch(entries:, files:)
      {}
    end
    processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: queue_config, video_uploader: nil)
    expect(processor.emit_log(item_uuid: "step", launch_uuid: "launch", message: "quota refusal",
                              level: :error, timestamp: Time.now)).to be(true)
    receipt = processor.flush_receipt(timeout: 1)

    expect(receipt.ambiguous).to eq(1)
    expect(receipt.spooled).to eq(0)
    expect(processor.diagnostics.dig(:counters, :spool_failed)).to eq(1)
    expect(Dir.glob(File.join(queue_dir, "*.ndjson"))).to be_empty
  ensure
    processor&.shutdown(timeout: 0)
    FileUtils.remove_entry(directory) if directory && File.exist?(directory)
  end
end
