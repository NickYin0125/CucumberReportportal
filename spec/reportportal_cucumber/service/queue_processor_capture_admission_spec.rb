# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Cancellable capture admission" do
  let(:directory) { Dir.mktmpdir("capture-admission-") }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://capture.example.test", project: "capture", api_key: "synthetic",
      queue_max_records: 1, queue_max_bytes: 100_000, queue_overflow_policy: "block",
      queue_admission_timeout_ms: 1_000, batch_size_logs: 1, retry_attempts: 1, spool_dir: directory
    )
  end
  let(:entered) { Queue.new }
  let(:release) { Queue.new }
  let(:api) do
    gate = entered
    resume = release
    Class.new do
      define_method(:log_batch_result) do |entries:, files:|
        gate << entries
        resume.pop
        ReportportalCucumber::ReportPortal::API::LogBatchResult.new(body: { "id" => "confirmed" })
      end
    end.new
  end
  let(:buffer) { ReportportalCucumber::Runtime::LogBuffer.new(api: api, config: config) }

  # @param options [Hash]
  # @return [Boolean]
  def emit(**options)
    buffer.emit_log(item_uuid: "original-step", launch_uuid: "launch-1", message: "record",
                    level: :error, timestamp: Time.now, **options)
  end

  after do
    4.times { release << true }
    buffer.shutdown(timeout: 2)
    FileUtils.remove_entry(directory)
  end

  it "cancels a blocked producer, counts every rejected artifact and retains accepted accounting" do
    expect(emit).to be(true)
    Timeout.timeout(2) { entered.pop }
    context = ReportportalCucumber::Runtime::Context.new
    item = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "original-step", kind: :step)
    target = context.register_capture_target(item, launch_uuid: "launch-1")
    waiting = Queue.new
    results = Queue.new
    publisher = Thread.new do
      context.publish_capture_target(target, launch_uuid: "launch-1") do |_original, cancelled|
        observed = -> { value = cancelled.call; waiting << true unless value; value }
        results << 13.times.map { emit(cancelled: observed) }
      end
    end
    Timeout.timeout(2) { waiting.pop }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(context.close_capture_target(target, timeout: 0.1)).to be(true)
    expect(publisher.join(0.2)).not_to be_nil
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.2
    expect(results.pop).to eq([false] * 13)
    expect(context.close_capture_target(target, timeout: 0)).to be(true)
    diagnostics = buffer.diagnostics
    expect(diagnostics.dig(:counters, :accepted)).to eq(1)
    expect(diagnostics.dig(:counters, :rejected_closed)).to eq(13)
    expect(diagnostics.fetch(:current_records)).to eq(1)
    expect(diagnostics.fetch(:peak_records)).to eq(1)
    expect(diagnostics.dig(:counters, :rejected_admission_timeout)).to eq(0)
    release << true
    expect(buffer.shutdown(timeout: 2)).to be(true)
    receipt = buffer.reporting_receipt(finalization_complete: true)
    expect(receipt.confirmed).to eq(1)
    expect(receipt.rejected).to eq(13)
    expect(receipt.complete).to be(false)
  ensure
    publisher&.join(2)
  end

  it "uses one absolute deadline across the batch instead of one delay per artifact" do
    expect(emit).to be(true)
    Timeout.timeout(2) { entered.pop }
    deadline = ReportportalCucumber::Service::ReportingDeadline.new(timeout: 0.03)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(13.times.map { emit(deadline: deadline) }).to eq([false] * 13)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.15
    expect(buffer.diagnostics.dig(:counters, :rejected_admission_timeout)).to eq(13)
    expect(buffer.diagnostics.dig(:counters, :accepted)).to eq(1)
  end

  it "keeps an already-reserved snapshot accounted when close cancels all later admissions" do
    context = ReportportalCucumber::Runtime::Context.new
    item = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "original-step", kind: :step)
    target = context.register_capture_target(item, launch_uuid: "launch-1")
    processor = buffer.instance_variable_get(:@processor)
    preparing = Queue.new
    resume = Queue.new
    allow(processor).to receive(:snapshot_record).and_wrap_original do |original, *args|
      preparing << true
      resume.pop
      original.call(*args)
    end
    results = Queue.new
    publisher = Thread.new do
      context.publish_capture_target(target, launch_uuid: "launch-1") do |_original, cancelled|
        results << [emit(cancelled: cancelled), emit(cancelled: cancelled)]
      end
    end
    Timeout.timeout(2) { preparing.pop }
    expect(context.close_capture_target(target, timeout: 0)).to be(false)
    resume << true
    expect(publisher.join(0.2)).not_to be_nil
    expect(results.pop).to eq([true, false])
    expect(buffer.diagnostics.dig(:counters, :accepted)).to eq(1)
    expect(buffer.diagnostics.dig(:counters, :rejected_closed)).to eq(1)
    Timeout.timeout(2) { entered.pop }
    release << true
    expect(buffer.shutdown(timeout: 2)).to be(true)
    receipt = buffer.reporting_receipt(finalization_complete: true)
    expect(receipt.confirmed).to eq(1)
    expect(receipt.rejected).to eq(1)
    expect(receipt.complete).to be(false)
  ensure
    resume << true if publisher&.alive?
    publisher&.join(2)
  end

  it "rejects expired or cancelled work even when capacity is free, without reserving bytes" do
    expect(emit(deadline: ReportportalCucumber::Service::ReportingDeadline.new(timeout: 0))).to be(false)
    expect(emit(cancelled: -> { true })).to be(false)
    expect(buffer.reject_logs(count: 18)).to be(false)
    diagnostics = buffer.diagnostics
    expect(diagnostics.fetch(:current_records)).to eq(0)
    expect(diagnostics.fetch(:current_bytes)).to eq(0)
    expect(diagnostics.dig(:counters, :accepted)).to eq(0)
    expect(buffer.reporting_receipt(finalization_complete: true).rejected).to eq(20)
    expect { buffer.reject_logs(count: 0) }.to raise_error(ArgumentError)
  end
end
