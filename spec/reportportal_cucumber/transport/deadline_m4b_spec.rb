# frozen_string_literal: true

require "spec_helper"

RSpec.describe "M4-B queue and transport deadlines" do
  let(:spool_dir) { Dir.mktmpdir("m4b-deadline-") }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp-m4b-deadline.example.test", project: "m4b", api_key: "m4b-test-only-token",
      retry_attempts: 1, retry_base_interval: 0.01, retry_max_interval: 0.01, flush_interval: 0.02,
      exit_flush_timeout_ms: 200, spool_dir: spool_dir, queue_max_records: 100,
      queue_max_bytes: 100_000, batch_size_logs: 10, batch_max_bytes: 700,
      queue_overflow_policy: "reject_new", queue_admission_timeout_ms: 20
    )
  end

  class M4BDeadlineAPI
    attr_reader :calls

    def initialize(&handler)
      @handler = handler || ->(entries, _files, _deadline) { M4BDeadlineAPI.response(entries) }
      @calls = Queue.new
    end

    def log_batch(entries:, files:, deadline: nil)
      @calls << { entries: entries, files: files, deadline: deadline }
      @handler.call(entries, files, deadline)
    end

    def self.response(entries)
      if entries.length == 1 && !entries.first.key?("file")
        { "id" => "log-#{entries.first.fetch('message')}" }
      else
        { "responses" => entries.map { |entry| { "id" => "log-#{entry.fetch('message')}" } } }
      end
    end
  end

  def emit(processor, message)
    processor.emit_log(item_uuid: "step", launch_uuid: "launch", message: message,
                       level: :info, timestamp: Time.now)
  end

  def wait_until(timeout: 1)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      raise "condition was not reached before the deterministic test deadline" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      Thread.pass
    end
  end

  def terminate_worker_for_cleanup(processor)
    return unless processor

    worker = processor.instance_variable_get(:@worker)
    worker.kill if worker.alive?
    worker.join(0.2)
  end

  after do
    FileUtils.remove_entry(spool_dir) if spool_dir && File.exist?(spool_dir)
  end

  it "uses one positive shutdown budget across barrier wait and worker join, then supports repeated shutdown" do
    entered = Queue.new
    release = Queue.new
    calls = 0
    api = M4BDeadlineAPI.new do |entries, _files, _deadline|
      calls += 1
      if calls == 1
        entered << true
        release.pop
      end
      M4BDeadlineAPI.response(entries)
    end
    processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "positive-budget")).to be(true)
    expect(entered.pop).to be(true)

    budget = 0.08
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    receipt = processor.shutdown_receipt(timeout: budget)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    expect(elapsed).to be < budget + 0.05
    expect(receipt.local_settled).to be(false)
    expect(receipt.timed_out).to be(true)

    release << true
    settled_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
    wait_until { processor.diagnostics.dig(:counters, :settled) == 1 && Process.clock_gettime(Process::CLOCK_MONOTONIC) < settled_deadline }
    expect(processor.shutdown_receipt(timeout: 1).local_settled).to be(true)
    expect(processor.shutdown_receipt(timeout: 1).local_settled).to be(true)
    expect(processor.diagnostics.fetch(:worker_alive)).to be(false)
  ensure
    release << true if release && release.empty?
    terminate_worker_for_cleanup(processor)
  end

  it "keeps zero-timeout shutdown nonblocking and lets a later positive repeated shutdown settle" do
    entered = Queue.new
    release = Queue.new
    api = M4BDeadlineAPI.new do |entries, _files, _deadline|
      entered << true
      release.pop
      M4BDeadlineAPI.response(entries)
    end
    processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "zero-budget")).to be(true)
    expect(entered.pop).to be(true)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    receipt = processor.shutdown_receipt(timeout: 0)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.04
    expect(receipt.local_settled).to be(false)
    expect(Dir.glob(File.join(spool_dir, "*.ndjson"))).to be_empty

    release << true
    expect(processor.shutdown_receipt(timeout: 1).local_settled).to be(true)
    expect(processor.shutdown(timeout: 1)).to be(true)
    expect(processor.diagnostics.fetch(:worker_alive)).to be(false)
  ensure
    release << true if release && release.empty?
    terminate_worker_for_cleanup(processor)
  end

  it "wakes the worker when shutdown is called with an already-settled empty cutoff" do
    api = M4BDeadlineAPI.new
    processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, video_uploader: nil)

    receipt = processor.shutdown_receipt(timeout: 0.12)

    expect(receipt.local_settled).to be(true)
    expect(processor.diagnostics.fetch(:worker_alive)).to be(false)
  ensure
    terminate_worker_for_cleanup(processor)
  end

  it "does not let a later producer extend an earlier barrier cutoff" do
    entered = Queue.new
    release_first = Queue.new
    release_second = Queue.new
    allow(config).to receive(:flush_interval).and_return(10)
    calls = 0
    api = M4BDeadlineAPI.new do |entries, _files, _deadline|
      calls += 1
      if calls == 1
        entered << :first
        release_first.pop
      else
        entered << :second
        release_second.pop
      end
      M4BDeadlineAPI.response(entries)
    end
    processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "before-cutoff")).to be(true)
    receipt_thread = Thread.new { processor.flush_receipt(timeout: 1) }
    expect(entered.pop).to eq(:first)
    expect(emit(processor, "after-cutoff")).to be(true)
    processor_mutex = processor.instance_variable_get(:@mutex)
    wait_until { processor_mutex.synchronize { processor.instance_variable_get(:@flush_requests).length == 1 } }
    release_first << true

    receipt = receipt_thread.value
    expect(receipt.cutoff).to eq(1)
    expect(receipt.confirmed).to eq(1)
    expect(receipt.pending).to eq(0)
    expect(entered.pop).to eq(:second)
    second_receipt_thread = Thread.new { processor.flush_receipt(timeout: 1) }
    wait_until { processor_mutex.synchronize { processor.instance_variable_get(:@flush_requests).length == 1 } }
    release_second << true
    expect(second_receipt_thread.value.confirmed).to eq(2)
    expect(processor.shutdown(timeout: 1)).to be(true)
  ensure
    release_first << true if release_first && release_first.empty?
    release_second << true if release_second && release_second.empty?
    terminate_worker_for_cleanup(processor)
  end

  it "bounds concurrent flush control waiters at 64 while settling accepted waiters" do
    entered = Queue.new
    release = Queue.new
    start_gate = Queue.new
    api = M4BDeadlineAPI.new do |entries, _files, _deadline|
      entered << true
      release.pop
      M4BDeadlineAPI.response(entries)
    end
    processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "waiter-cutoff")).to be(true)
    waiters = 65.times.map do
      Thread.new do
        start_gate.pop
        processor.flush_receipt(timeout: 2)
      end
    end
    expect(entered.pop).to be(true)
    65.times { start_gate << true }
    processor_mutex = processor.instance_variable_get(:@mutex)
    wait_until do
      queued, rejected = processor_mutex.synchronize do
        [processor.instance_variable_get(:@flush_requests).length,
         processor.instance_variable_get(:@counters).fetch(:control_rejected)]
      end
      queued == 64 && rejected == 1
    end
    expect(processor.diagnostics.dig(:counters, :control_rejected)).to eq(1)

    release << true
    receipts = waiters.map(&:value)
    expect(receipts.count(&:local_settled)).to eq(64)
    expect(receipts.count { |receipt| receipt.timed_out || !receipt.local_settled }).to eq(1)
    expect(processor.shutdown(timeout: 1)).to be(true)
  ensure
    release << true if release && release.empty?
    waiters&.each { |thread| thread.kill if thread.alive? }
    terminate_worker_for_cleanup(processor)
  end

  it "does not carry an expired ordinary flush deadline into later producers" do
    entered = Queue.new
    release = Queue.new
    api = M4BDeadlineAPI.new do |entries, _files, deadline|
      entered << deadline
      release.pop if entries.first.fetch("message") == "first-with-deadline"
      M4BDeadlineAPI.response(entries)
    end
    allow(config).to receive(:flush_interval).and_return(10)
    processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "first-with-deadline")).to be(true)
    first_deadline = ReportportalCucumber::Service::ReportingDeadline.new(timeout: 0.06)
    receipt = processor.flush_receipt(timeout: 0.3, deadline: first_deadline)
    expect(receipt.timed_out).to be(true)
    expect(entered.pop).to equal(first_deadline)
    release << true
    wait_until { processor.diagnostics.dig(:counters, :settled) == 1 }

    expect(emit(processor, "later-without-deadline")).to be(true)
    later_receipt = processor.flush_receipt(timeout: 1)
    expect(later_receipt.confirmed).to eq(2)
    calls = 2.times.map { api.calls.pop }
    later_call = calls.find { |call| call.fetch(:entries).first.fetch("message") == "later-without-deadline" }
    expect(later_call).not_to be_nil
    expect(later_call.fetch(:deadline)).to be_nil
    expect(processor.shutdown(timeout: 1)).to be(true)
  ensure
    release << true if release && release.empty?
    terminate_worker_for_cleanup(processor)
  end

  it "does not spool or recount a confirmed first byte-split chunk when a later payload build fails" do
    api = M4BDeadlineAPI.new
    allow(config).to receive(:flush_interval).and_return(10)
    processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, video_uploader: nil)
    expect(emit(processor, "first-#{'a' * 220}")).to be(true)
    expect(emit(processor, "second-#{'b' * 220}")).to be(true)
    allow(ReportportalCucumber::Service::PayloadBuilder).to receive(:build_log_batch).and_wrap_original do |original, records|
      raise "injected later chunk builder fault" if records.length == 1 && records.first.message.start_with?("second-")

      original.call(records)
    end

    receipt = processor.flush_receipt(timeout: 1)

    expect(api.calls.size).to eq(1)
    expect(receipt.confirmed).to eq(1)
    expect(receipt.ambiguous).to eq(1)
    expect(receipt.settled).to eq(2)
    spooled = Dir.glob(File.join(spool_dir, "*.ndjson")).flat_map do |path|
      File.readlines(path).map { |line| JSON.parse(line) }
    end
    expect(spooled.map { |record| record.fetch("message") }).to all(start_with("second-"))
    expect(processor.shutdown_receipt(timeout: 1).local_settled).to be(true)
  ensure
    terminate_worker_for_cleanup(processor)
  end

  it "applies a single finalization deadline across slow item/launch finishes" do
    endpoint = "https://rp-m4b-deadline.example.test"
    launch_uuid = "launch-deadline"
    item_ids = %w[suite-deadline scenario-deadline step-deadline]
    starts = 0
    stub_request(:post, "#{endpoint}/api/v1/m4b/launch")
      .to_return(status: 200, body: { "id" => launch_uuid }.to_json)
    stub_request(:post, %r{\A#{Regexp.escape(endpoint)}/api/v1/m4b/item(?:/.*)?\z}).to_return do |_request|
      starts += 1
      { status: 200, body: { "id" => item_ids.fetch(starts - 1) }.to_json }
    end
    stub_request(:put, %r{\A#{Regexp.escape(endpoint)}/api/v1/m4b/item/[^/]+\z}).to_return do |_request|
      sleep 0.06
      { status: 200, body: { "id" => "finished-item" }.to_json }
    end
    stub_request(:put, "#{endpoint}/api/v1/m4b/launch/#{launch_uuid}/finish").to_return do |_request|
      sleep 0.06
      { status: 200, body: { "id" => launch_uuid }.to_json }
    end
    config = ReportportalCucumber::Config.new(
      endpoint: endpoint, project: "m4b", api_key: "m4b-test-only-token", launch: "shared deadline",
      join: false, retry_attempts: 1, retry_base_interval: 0.01, retry_max_interval: 0.01,
      flush_interval: 0.01, exit_flush_timeout_ms: 120, spool_dir: spool_dir, batch_size_logs: 1
    )
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
    formatter = ReportportalCucumber::Cucumber::Formatter.new(M4BDeadlineFakeCucumberConfig.new)
    formatter.ingest_event("type" => "test_run_started", "timestamp" => "2026-10-10T00:00:00Z")
    formatter.ingest_event("type" => "test_suite_started", "feature_uri" => "features/deadline.feature")
    formatter.ingest_event("type" => "test_case_started", "feature_uri" => "features/deadline.feature",
                           "scenario_name" => "deadline case", "scenario_line" => 4)
    formatter.ingest_event("type" => "test_step_started", "step_text" => "slow finalization", "step_id" => "deadline-step")

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    formatter.ingest_event("type" => "test_run_finished", "success" => true)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    receipt = formatter.reporting_receipt

    expect(elapsed).to be < 0.18
    expect(receipt.metadata_failures).to be > 0
    expect(receipt.complete).to be(false)
  ensure
    stop_formatter_worker(formatter)
  end

  it "caps slow HTTP I/O and retry backoff at the same monotonic deadline" do
    client = ReportportalCucumber::Transport::HTTPClient.new(config: config)
    deadline = ReportportalCucumber::Service::ReportingDeadline.new(timeout: 0.07)
    allow(client).to receive(:perform) do
      sleep 0.5
      ReportportalCucumber::Transport::HTTPClient::Response.new(status: 200, headers: {}, body: {})
    end
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect do
      client.post_json(path: "api/v1/m4b/log", body: { "message" => "slow" }, deadline: deadline)
    end.to raise_error(Timeout::Error)

    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.12
  end

  it "does not spend a fresh deadline on retry backoff" do
    retry_config = ReportportalCucumber::Config.new(
      endpoint: "https://rp-m4b-deadline.example.test", project: "m4b", api_key: "m4b-test-only-token",
      retry_attempts: 5, retry_base_interval: 0.5, retry_max_interval: 0.5,
      spool_dir: spool_dir
    )
    client = ReportportalCucumber::Transport::HTTPClient.new(config: retry_config)
    deadline = ReportportalCucumber::Service::ReportingDeadline.new(timeout: 0.07)
    allow(client).to receive(:perform).and_return(
      ReportportalCucumber::Transport::HTTPClient::Response.new(status: 503, headers: {}, body: {})
    )
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect do
      client.post_json(path: "api/v1/m4b/log", body: { "message" => "retry" }, deadline: deadline)
    end.to raise_error(Timeout::Error)

    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.12
    expect(client).to have_received(:perform).once
  end

  class M4BDeadlineFakeCucumberConfig
    def on_event(_name, &_handler); end
    def include(_mod); end
  end

  def stop_formatter_worker(formatter)
    return unless formatter

    processor = formatter.instance_variable_get(:@log_buffer).instance_variable_get(:@processor)
    worker = processor.instance_variable_get(:@worker)
    worker.kill if worker.alive?
    worker.join(0.2)
  end
end
