# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Service::QueueProcessor do
  let(:spool_dir) { Dir.mktmpdir("m4a-spool-") }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp-m4a.example.test",
      project: "m4a",
      api_key: "test-token",
      retry_attempts: 1,
      retry_base_interval: 0.01,
      retry_max_interval: 0.01,
      flush_interval: 0.01,
      exit_flush_timeout_ms: 100,
      spool_dir: spool_dir,
      queue_max_records: 2,
      queue_max_bytes: 100_000,
      batch_size_logs: 1,
      batch_max_bytes: 8_388_608,
      queue_overflow_policy: "reject_new",
      queue_admission_timeout_ms: 20
    )
  end

  class M4ABlockedAPI
    attr_reader :calls

    def initialize(block_first: true)
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @calls = []
      @entered = 0
      @released = !block_first
    end

    def log_batch(entries:, files:)
      @mutex.synchronize do
        @calls << [Marshal.load(Marshal.dump(entries)), Marshal.load(Marshal.dump(files))]
        @entered += 1
        @condition.broadcast
        @condition.wait(@mutex) until @released
      end
      { "ok" => true }
    end

    def wait_for_calls(count, timeout: 2)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      @mutex.synchronize do
        until @entered >= count
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          return false if remaining <= 0

          @condition.wait(@mutex, remaining)
        end
      end
      true
    end

    def release
      @mutex.synchronize do
        @released = true
        @condition.broadcast
      end
    end
  end

  class M4ACapturingAPI
    attr_reader :calls

    def initialize
      @mutex = Mutex.new
      @calls = []
    end

    def log_batch(entries:, files:)
      @mutex.synchronize do
        @calls << [Marshal.load(Marshal.dump(entries)), Marshal.load(Marshal.dump(files))]
      end
      { "ok" => true }
    end
  end

  class M4AKillableAPI
    attr_reader :worker_thread

    def initialize
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @entered = false
      @released = false
    end

    def log_batch(entries:, files:)
      @mutex.synchronize do
        @worker_thread = Thread.current
        @entries = Marshal.load(Marshal.dump(entries))
        @files = Marshal.load(Marshal.dump(files))
        @entered = true
        @condition.broadcast
        @condition.wait(@mutex) until @released
      end
      { "ok" => true }
    end

    def wait_until_entered(timeout: 2)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      @mutex.synchronize do
        until @entered
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          return false if remaining <= 0

          @condition.wait(@mutex, remaining)
        end
      end
      true
    end

    def release
      @mutex.synchronize do
        @released = true
        @condition.broadcast
      end
    end
  end

  def emit(processor, message, attachment: nil, item_uuid: "step-1", launch_uuid: "launch-1", level: :error,
           timestamp: Time.utc(2026, 10, 10, 1, 2, 3))
    processor.emit_log(
      item_uuid: item_uuid,
      launch_uuid: launch_uuid,
      message: message,
      level: level,
      timestamp: timestamp,
      attachment: attachment
    )
  end

  def close_processor(processor, api)
    api.release if api.respond_to?(:release)
    processor.shutdown(timeout: 2)
  end

  after do
    FileUtils.remove_entry(spool_dir) if spool_dir && File.exist?(spool_dir)
  end

  it "reserves in-flight records against the count cap and promptly rejects overflow" do
    gated_api = M4ABlockedAPI.new
    processor = described_class.new(api: gated_api, config: config, video_uploader: nil)

    expect(emit(processor, "in flight")).to be(true)
    expect(gated_api.wait_for_calls(1)).to be(true)
    expect(emit(processor, "pending")).to be(true)
    expect(emit(processor, "must be rejected")).to be(false)
    diagnostics = processor.diagnostics
    expect(diagnostics).to be_frozen
    expect(diagnostics.fetch(:current_records)).to eq(2)
    expect(diagnostics.fetch(:peak_records)).to eq(2)
    expect(diagnostics.fetch(:current_bytes)).to be <= config.queue_max_bytes
    expect(diagnostics.fetch(:peak_bytes)).to be <= config.queue_max_bytes
    expect(diagnostics.dig(:counters, :accepted)).to eq(2)
    expect(diagnostics.dig(:counters, :rejected_overflow)).to eq(1)
    expect(diagnostics.to_s).not_to include("must be rejected")
  ensure
    close_processor(processor, gated_api) if processor
  end

  it "keeps concurrent producer reservations within the configured count and byte peaks" do
    gated_api = M4ABlockedAPI.new
    producer_count = 32
    count_cap = 8
    pressure_config = ReportportalCucumber::Config.new(
      queue_max_records: count_cap,
      queue_max_bytes: 10_000,
      queue_overflow_policy: "reject_new",
      batch_size_logs: 1,
      retry_attempts: 1,
      spool_dir: spool_dir
    )
    processor = described_class.new(api: gated_api, config: pressure_config, video_uploader: nil)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    producers = producer_count.times.map do |index|
      Thread.new do
        ready << true
        start.pop
        results << emit(processor, "parallel-#{index}-#{'雪' * 20}", item_uuid: "parallel-step-#{index}")
      end
    end
    producer_count.times { ready.pop }
    producer_count.times { start << true }
    producers.each { |producer| producer.join(2) }
    expect(producers).to all(satisfy { |producer| !producer.alive? })

    outcomes = producer_count.times.map { results.pop }
    diagnostics = processor.diagnostics
    expect(outcomes.count(true)).to eq(count_cap)
    expect(outcomes.count(false)).to eq(producer_count - count_cap)
    expect(diagnostics.fetch(:peak_records)).to eq(count_cap)
    expect(diagnostics.fetch(:current_records)).to eq(count_cap)
    expect(diagnostics.fetch(:peak_bytes)).to be <= pressure_config.queue_max_bytes
    expect(diagnostics.fetch(:current_bytes)).to be <= pressure_config.queue_max_bytes
    expect(diagnostics.dig(:counters, :accepted)).to eq(count_cap)
    expect(diagnostics.dig(:counters, :rejected_overflow)).to eq(producer_count - count_cap)
  ensure
    producers&.each { |producer| producer.kill if producer.alive? }
    close_processor(processor, gated_api) if processor
  end

  it "keeps UTF-8 messages and binary attachments charged while the backend is blocked" do
    gated_api = M4ABlockedAPI.new
    byte_cap = 1_100
    byte_config = ReportportalCucumber::Config.new(
      queue_max_records: 10,
      queue_max_bytes: byte_cap,
      batch_size_logs: 1,
      batch_max_bytes: 10_000,
      queue_overflow_policy: "reject_new",
      retry_attempts: 1,
      spool_dir: spool_dir
    )
    processor = described_class.new(api: gated_api, config: byte_config, video_uploader: nil)
    expect(emit(processor, "雪" * 40, attachment: { name: "raw.bin", mime: "application/octet-stream", bytes: "\xFF".b * 180 })).to be(true)
    expect(gated_api.wait_for_calls(1)).to be(true)

    expect(emit(processor, "m" * 500)).to be(false)
    diagnostics = processor.diagnostics
    expect(diagnostics.fetch(:current_records)).to eq(1)
    expect(diagnostics.fetch(:current_bytes)).to be > 0
    expect(diagnostics.fetch(:current_bytes)).to be <= byte_cap
    expect(diagnostics.fetch(:peak_bytes)).to be <= byte_cap
    expect(diagnostics.dig(:counters, :rejected_overflow)).to eq(1)
  ensure
    close_processor(processor, gated_api) if processor
  end

  it "charges file-backed attachments by resident path metadata rather than disk contents" do
    Dir.mktmpdir("m4a-path-resident-") do |directory|
      path = File.join(directory, "large.bin")
      File.binwrite(path, "d" * (2 * 1024 * 1024))
      gated_api = M4ABlockedAPI.new
      path_cap = 1_024
      path_config = ReportportalCucumber::Config.new(
        queue_max_records: 4,
        queue_max_bytes: path_cap,
        batch_size_logs: 1,
        batch_max_bytes: 3 * 1024 * 1024,
        retry_attempts: 1,
        spool_dir: spool_dir
      )
      processor = described_class.new(api: gated_api, config: path_config, video_uploader: nil)

      expect(emit(processor, "disk attachment", attachment: {
        name: "large.bin", mime: "application/octet-stream", path: path
      })).to be(true)
      expect(gated_api.wait_for_calls(1)).to be(true)
      diagnostics = processor.diagnostics
      expect(File.size(path)).to be > path_cap * 1_000
      expect(diagnostics.fetch(:current_records)).to eq(1)
      expect(diagnostics.fetch(:current_bytes)).to be > 0
      expect(diagnostics.fetch(:current_bytes)).to be < path_cap
      expect(diagnostics.fetch(:peak_bytes)).to be <= path_cap
    ensure
      close_processor(processor, gated_api) if processor
    end
  end

  it "detects caller growth between sizing and snapshot without copying the growth" do
    capturing_api = M4ACapturingAPI.new
    processor = described_class.new(api: capturing_api, config: config, video_uploader: nil)
    message = +"bounded"
    message_copy = message
    sizing = Queue.new
    resume = Queue.new
    allow(processor).to receive(:bounded_snapshot).and_wrap_original do |original, value, expected_size, budget|
      if value.equal?(message_copy)
        sizing << true
        resume.pop
      end
      original.call(value, expected_size, budget)
    end
    allow(message).to receive(:byteslice).and_call_original

    result = Queue.new
    producer = Thread.new { result << emit(processor, message) }
    expect(sizing.pop).to be(true)
    message << ("oversized-growth" * 10_000)
    resume << true
    producer.join(2)

    expect(producer.alive?).to be(false)
    expect(result.pop).to be(false)
    expect(message).not_to have_received(:byteslice)
    diagnostics = processor.diagnostics
    expect(diagnostics.dig(:counters, :rejected_unsupported)).to eq(1)
    expect(diagnostics.fetch(:current_records)).to eq(0)
    expect(diagnostics.fetch(:peak_bytes)).to be <= config.queue_max_bytes
  ensure
    resume << true if producer&.alive?
    producer&.kill if producer&.alive?
    close_processor(processor, capturing_api) if processor
  end

  it "detaches accepted message and byte attachment data without freezing caller inputs" do
    gated_api = M4ABlockedAPI.new
    processor = described_class.new(api: gated_api, config: config, video_uploader: nil)
    expect(emit(processor, "gate")).to be(true)
    expect(gated_api.wait_for_calls(1)).to be(true)

    message = +"before mutation"
    bytes = +"file-before"
    attachment = { name: +"trace.log", mime: +"text/plain", bytes: bytes }
    expect(emit(processor, message, attachment: attachment, item_uuid: "attempt-2", level: :debug)).to be(true)
    message.replace("after mutation")
    bytes.replace("file-after!")
    attachment[:name].replace("changed.log")

    gated_api.release
    expect(processor.flush(timeout: 2)).to be(true)
    matching = gated_api.calls.find do |entries, _files|
      entries.any? { |entry| entry["message"].include?("before mutation") }
    end
    expect(matching).not_to be_nil
    entries, files = matching
    expect(entries.first).to include("itemUuid" => "attempt-2", "launchUuid" => "launch-1", "level" => "debug")
    expect(files.first).to include(name: "trace.log", mime: "text/plain", bytes: "file-before")
    expect(message).to eq("after mutation")
    expect(bytes).to eq("file-after!")
    expect(attachment[:name]).to eq("changed.log")
  ensure
    close_processor(processor, gated_api) if processor
  end

  it "blocks admission only until a genuinely charged in-flight slot is released" do
    gated_api = M4ABlockedAPI.new
    blocking_config = ReportportalCucumber::Config.new(
      queue_max_records: 1,
      queue_max_bytes: 100_000,
      queue_overflow_policy: "block",
      queue_admission_timeout_ms: 1_000,
      batch_size_logs: 1,
      retry_attempts: 1,
      spool_dir: spool_dir
    )
    processor = described_class.new(api: gated_api, config: blocking_config, video_uploader: nil)
    expect(emit(processor, "occupy slot")).to be(true)
    expect(gated_api.wait_for_calls(1)).to be(true)

    producer_result = Queue.new
    producer = Thread.new { producer_result << emit(processor, "wait for capacity") }
    expect(producer_result.empty?).to be(true)
    gated_api.release
    producer.join(2)
    expect(producer.alive?).to be(false)
    expect(producer_result.pop).to be(true)
    expect(processor.shutdown(timeout: 2)).to be(true)
  ensure
    producer&.kill if producer&.alive?
    close_processor(processor, gated_api) if processor
  end

  it "bounds block admission by its configured timeout and reports the exact reason" do
    gated_api = M4ABlockedAPI.new
    blocking_config = ReportportalCucumber::Config.new(
      queue_max_records: 1,
      queue_max_bytes: 100_000,
      queue_overflow_policy: "block",
      queue_admission_timeout_ms: 40,
      batch_size_logs: 1,
      retry_attempts: 1,
      spool_dir: spool_dir
    )
    processor = described_class.new(api: gated_api, config: blocking_config, video_uploader: nil)
    expect(emit(processor, "occupy slot")).to be(true)
    expect(gated_api.wait_for_calls(1)).to be(true)

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(emit(processor, "bounded wait")).to be(false)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    expect(elapsed).to be >= 0.025
    expect(elapsed).to be < 0.5
    diagnostics = processor.diagnostics
    expect(diagnostics.dig(:counters, :rejected_admission_timeout)).to eq(1)
    expect(diagnostics.fetch(:current_records)).to eq(1)
    expect(diagnostics.fetch(:peak_records)).to eq(1)
  ensure
    close_processor(processor, gated_api) if processor
  end

  it "returns promptly from a zero-timeout flush without retaining a control waiter" do
    gated_api = M4ABlockedAPI.new
    processor = described_class.new(api: gated_api, config: config, video_uploader: nil)
    expect(emit(processor, "still in flight")).to be(true)
    expect(gated_api.wait_for_calls(1)).to be(true)

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(processor.flush(timeout: 0)).to be(false)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.1
    expect(processor.diagnostics.dig(:counters, :control_timed_out)).to eq(0)
    gated_api.release
    expect(processor.flush(timeout: 2)).to be(true)
  ensure
    close_processor(processor, gated_api) if processor
  end

  it "removes more than 64 sequential and concurrent timed-out flush waiters" do
    gated_api = M4ABlockedAPI.new
    processor = described_class.new(api: gated_api, config: config, video_uploader: nil)
    expect(emit(processor, "hold worker for flush waiters")).to be(true)
    expect(gated_api.wait_for_calls(1)).to be(true)

    70.times { expect(processor.flush(timeout: 0.002)).to be(false) }
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    flushers = 80.times.map do
      Thread.new do
        ready << true
        start.pop
        results << processor.flush(timeout: 0.04)
      end
    end
    80.times { ready.pop }
    80.times { start << true }
    flushers.each { |flusher| flusher.join(2) }
    expect(flushers).to all(satisfy { |flusher| !flusher.alive? })
    expect(80.times.map { results.pop }).to all(be(false))
    diagnostics = processor.diagnostics
    expect(diagnostics.dig(:counters, :control_timed_out)).to be >= 70
    expect(diagnostics.dig(:counters, :control_rejected)).to be <= 80
    expect(diagnostics.dig(:counters, :control_timed_out) + diagnostics.dig(:counters, :control_rejected))
      .to eq(150)

    gated_api.release
    expect(processor.flush(timeout: 2)).to be(true)
  ensure
    flushers&.each { |flusher| flusher.kill if flusher.alive? }
    close_processor(processor, gated_api) if processor
  end

  it "splits explicit flush work into bounded FIFO chunks and waits for every chunk" do
    capturing_api = M4ACapturingAPI.new
    bounded_config = ReportportalCucumber::Config.new(
      queue_max_records: 100,
      queue_max_bytes: 1_000_000,
      batch_size_logs: 2,
      batch_max_bytes: 900,
      flush_interval: 10,
      retry_attempts: 1,
      spool_dir: spool_dir
    )
    processor = described_class.new(api: capturing_api, config: bounded_config, video_uploader: nil)
    11.times { |index| expect(emit(processor, "FIFO-#{index}-#{'x' * 100}")).to be(true) }

    expect(processor.flush(timeout: 2)).to be(true)
    batches = capturing_api.calls
    expect(batches.length).to be > 3
    expect(batches.flat_map { |entries, _files| entries }.map { |entry| entry.fetch("message") })
      .to eq(11.times.map { |index| "FIFO-#{index}-#{'x' * 100}" })
    batches.each do |entries, files|
      expect(entries.length).to be <= 2
      expect(ReportportalCucumber::Transport::MultipartHelper.log_batch_bytes(entries: entries, files: files))
        .to be <= bounded_config.batch_max_bytes
    end
  ensure
    close_processor(processor, capturing_api) if processor
  end

  it "does not send or retry an individually oversized wire record and records its spool outcome" do
    capturing_api = M4ACapturingAPI.new
    tiny_wire_config = ReportportalCucumber::Config.new(
      queue_max_records: 10,
      queue_max_bytes: 100_000,
      batch_size_logs: 4,
      batch_max_bytes: 400,
      retry_attempts: 4,
      retry_base_interval: 0,
      retry_max_interval: 0,
      spool_dir: spool_dir
    )
    processor = described_class.new(api: capturing_api, config: tiny_wire_config, video_uploader: nil)
    expect(emit(processor, "oversized-" * 100)).to be(true)
    expect(processor.flush(timeout: 2)).to be(true)
    expect(capturing_api.calls).to be_empty
    expect(processor.diagnostics.dig(:counters, :oversized_wire)).to eq(1)
    expect(processor.diagnostics.dig(:counters, :sent_batches)).to eq(0)
    expect(Dir.glob(File.join(spool_dir, "*.ndjson"))).not_to be_empty
  ensure
    close_processor(processor, capturing_api) if processor
  end

  it "rolls back a reservation when its producer is terminated during snapshot preparation" do
    processors = []
    producers = []
    [:thread_kill, :system_exit, :business_error].each do |termination|
      capturing_api = M4ACapturingAPI.new
      processor = described_class.new(api: capturing_api, config: config, video_uploader: nil)
      processors << [processor, capturing_api]
      message = "cancelled before commit: #{termination}"
      if termination == :thread_kill
        preparing = Queue.new
        allow(processor).to receive(:snapshot_record).and_wrap_original do |original, *arguments|
          preparing << true
          Queue.new.pop
          original.call(*arguments)
        end
        producer = Thread.new { emit(processor, message, item_uuid: "step-cancelled") }
        producers << producer
        expect(preparing.pop).to be(true)
        producer.kill
        producer.join(2)
        expect(producer.alive?).to be(false)
      else
        error = termination == :system_exit ? SystemExit.new(17) : RuntimeError.new("snapshot business fault")
        allow(processor).to receive(:snapshot_record).and_raise(error)
        expect { emit(processor, message, item_uuid: "step-cancelled") }
          .to raise_error(termination == :system_exit ? SystemExit : RuntimeError)
      end

      after_cancellation = processor.diagnostics
      shutdown_result = processor.shutdown(timeout: 0.05)
      after_shutdown = processor.diagnostics
      aggregate_failures(termination.to_s) do
        expect(after_cancellation.fetch(:current_records)).to eq(0)
        expect(after_cancellation.fetch(:current_bytes)).to eq(0)
        expect(after_cancellation.dig(:counters, :accepted)).to eq(0)
        expect(shutdown_result).to be(true)
        expect(after_shutdown.fetch(:worker_alive)).to be(false)
        expect(capturing_api.calls).to be_empty
      end
    end
  ensure
    producers&.each do |producer|
      producer.kill if producer.alive?
      producer.join
    end
    processors&.each do |processor, _capturing_api|
      # A failing regression must not leave the intentionally exercised worker spinning.
      mutex = processor.instance_variable_get(:@mutex)
      mutex.synchronize do
        processor.instance_variable_set(:@reserved_records, 0)
        processor.instance_variable_set(:@reserved_bytes, 0)
        processor.instance_variable_get(:@condition).broadcast
      end
      processor.shutdown(timeout: 1)
      processor.instance_variable_get(:@worker).join(1)
    end
  end

  it "retains and best-effort spools accepted in-flight work if its blocked worker is killed" do
    killable_api = M4AKillableAPI.new
    processor = described_class.new(api: killable_api, config: config, video_uploader: nil)
    expect(emit(processor, "must survive worker interruption", item_uuid: "step-killed")).to be(true)
    expect(killable_api.wait_until_entered).to be(true)
    worker = killable_api.worker_thread

    worker.kill
    worker.join(2)
    expect(worker.alive?).to be(false)

    diagnostics = processor.diagnostics
    expect(diagnostics.fetch(:closed)).to be(true)
    expect(diagnostics.fetch(:worker_alive)).to be(false)
    expect(diagnostics.dig(:counters, :worker_failed)).to be >= 1
    expect(emit(processor, "after worker death")).to be(false)
    expect(diagnostics.fetch(:current_records)).to eq(0)
    retained = Dir.glob(File.join(spool_dir, "*.ndjson")).flat_map do |path|
      File.readlines(path).map { |line| JSON.parse(line) }
    end
    expect(retained).to include(include("message" => "must survive worker interruption", "itemUuid" => "step-killed"))
  ensure
    killable_api&.release
    close_processor(processor, killable_api) if processor
  end

  it "keeps successful shutdown idempotent after draining multiple bounded chunks" do
    capturing_api = M4ACapturingAPI.new
    bounded_config = ReportportalCucumber::Config.new(
      queue_max_records: 20,
      queue_max_bytes: 100_000,
      batch_size_logs: 2,
      batch_max_bytes: 10_000,
      flush_interval: 10,
      retry_attempts: 1,
      spool_dir: spool_dir
    )
    processor = described_class.new(api: capturing_api, config: bounded_config, video_uploader: nil)
    9.times { |index| expect(emit(processor, "shutdown-#{index}")).to be(true) }

    expect(processor.shutdown(timeout: 2)).to be(true)
    expect(processor.shutdown(timeout: 2)).to be(true)
    expect(capturing_api.calls.length).to be > 3
    expect(capturing_api.calls.flat_map { |entries, _files| entries }.map { |entry| entry.fetch("message") })
      .to eq(9.times.map { |index| "shutdown-#{index}" })
    expect(processor.diagnostics.fetch(:current_records)).to eq(0)
  ensure
    close_processor(processor, capturing_api) if processor
  end

  it "bounds fallback spool chunks and preserves legacy Float timestamp serialization" do
    failure = RuntimeError.new("offline")
    capturing_api = Class.new do
      define_method(:log_batch) { |**_args| raise failure }
    end.new
    spool_config = ReportportalCucumber::Config.new(
      queue_max_records: 20,
      queue_max_bytes: 100_000,
      batch_size_logs: 2,
      batch_max_bytes: 10_000,
      retry_attempts: 1,
      spool_dir: spool_dir
    )
    processor = described_class.new(api: capturing_api, config: spool_config, video_uploader: nil)
    spool_sizes = []
    allow(processor).to receive(:spool).and_raise(IOError, "spool unavailable")
    allow(processor).to receive(:raw_spool).and_wrap_original do |original, records, *args|
      spool_sizes << records.length
      original.call(records, *args)
    end
    fractional_time = 1_791_602_523.125
    7.times do |index|
      expect(emit(processor, "fallback-#{index}", item_uuid: "step-#{index}",
                  timestamp: index.zero? ? fractional_time : Time.utc(2026, 10, 10, 1, 2, 3))).to be(true)
    end
    # Preserve the pre-M4 Float conversion when the ordinary spool path fails.
    processor.flush(timeout: 2)
    expect(spool_sizes).to all(be <= 2)
    expect(spool_sizes).not_to be_empty
    raw_files = Dir.glob(File.join(spool_dir, "*.ndjson"))
    expect(raw_files).not_to be_empty
    raw_records = raw_files.flat_map { |path| File.readlines(path).map { |line| JSON.parse(line) } }
    expect(raw_records).to all(include("rawSpool" => true))
    expect(raw_records.find { |entry| entry.fetch("message") == "fallback-0" }.fetch("time"))
      .to eq(fractional_time.to_i.to_s)
    expect(processor.diagnostics.dig(:counters, :delivery_failed)).to be >= 1
  ensure
    close_processor(processor, capturing_api) if processor
  end

  it "does not synchronously spool on zero-timeout shutdown and later spools bounded ownership" do
    gated_api = M4ABlockedAPI.new
    bounded_config = ReportportalCucumber::Config.new(
      queue_max_records: 20,
      queue_max_bytes: 100_000,
      batch_size_logs: 2,
      batch_max_bytes: 10_000,
      flush_interval: 10,
      retry_attempts: 1,
      spool_dir: spool_dir
    )
    processor = described_class.new(api: gated_api, config: bounded_config, video_uploader: nil)
    spool_sizes = []
    allow(processor).to receive(:spool).and_raise(IOError, "spool unavailable")
    allow(processor).to receive(:raw_spool).and_wrap_original do |original, records, *args|
      spool_sizes << records.length
      original.call(records, *args)
    end
    7.times { |index| expect(emit(processor, "timeout-#{index}")).to be(true) }
    expect(gated_api.wait_for_calls(1)).to be(true)

    # M4-B: zero budget returns immediately; the still-running worker owns any later fallback spool.
    expect(processor.shutdown(timeout: 0)).to be(false)
    expect(spool_sizes).to be_empty
    expect(Dir.glob(File.join(spool_dir, "*.ndjson"))).to be_empty
    gated_api.release
    expect(processor.shutdown(timeout: 2)).to be(true)
    expect(spool_sizes).to eq([2, 2, 2, 1])
    raw_records = Dir.glob(File.join(spool_dir, "*.ndjson")).flat_map do |path|
      File.readlines(path).map { |line| JSON.parse(line) }
    end
    expect(raw_records.length).to eq(7)
    expect(raw_records).to all(include("rawSpool" => true))
  ensure
    close_processor(processor, gated_api) if processor
  end

  it "keeps a raising reentrant reporting callback outside queue synchronization" do
    callback_calls = Queue.new
    processor = nil
    failure = RuntimeError.new("offline")
    raising_api = Class.new do
      define_method(:log_batch) { |**_args| raise failure }
    end.new
    callback = lambda do |_error|
      callback_calls << processor.diagnostics.fetch(:worker_alive)
      raise "callback failure is isolated"
    end
    processor = described_class.new(api: raising_api, config: config, on_error: callback, video_uploader: nil)
    expect(emit(processor, "callback record")).to be(true)
    expect(processor.flush(timeout: 2)).to be(true)
    expect(callback_calls.pop).to be(true)
    expect(processor.diagnostics.fetch(:worker_alive)).to be(true)
    expect(processor.diagnostics.dig(:counters, :delivery_failed)).to be >= 1
  ensure
    close_processor(processor, raising_api) if processor
  end

  it "returns false after shutdown and does not retain records for a dead consumer" do
    capturing_api = M4ACapturingAPI.new
    processor = described_class.new(api: capturing_api, config: config, video_uploader: nil)
    expect(processor.shutdown(timeout: 2)).to be(true)
    expect(emit(processor, "after close")).to be(false)
    expect(processor.diagnostics.to_s).not_to include("after close")
  ensure
    close_processor(processor, capturing_api) if processor
  end
end
