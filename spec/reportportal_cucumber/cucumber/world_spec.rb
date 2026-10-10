# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe ReportportalCucumber::Cucumber::World do
  after do
    ReportportalCucumber.current_runtime = nil
  end

  subject(:world) do
    Class.new do
      include ReportportalCucumber::Cucumber::World
    end.new
  end

  it "supports rp_attach(file_path, mime_type: nil) without reading the attachment into memory" do
    Dir.mktmpdir do |dir|
      video_path = File.join(dir, "failure.mp4")
      File.binwrite(video_path, "mp4-bytes")
      runtime = instance_double("runtime")
      ReportportalCucumber.current_runtime = runtime

      expect(runtime).to receive(:emit_world_attachment).with(
        hash_including(
          message: "Attachment: failure.mp4",
          attachment: {
            name: "failure.mp4",
            mime: "video/mp4",
            path: video_path
          }
        )
      )

      world.rp_attach(video_path, mime_type: nil)
    end
  end

  it "keeps backwards-compatible byte attachments with explicit name and mime" do
    runtime = instance_double("runtime")
    ReportportalCucumber.current_runtime = runtime

    expect(runtime).to receive(:emit_world_attachment).with(
      hash_including(
        message: "Attachment: trace.log",
        attachment: {
          name: "trace.log",
          mime: "text/plain",
          bytes: "trace"
        }
      )
    )

    world.rp_attach("trace", name: "trace.log", mime: "text/plain")
  end

  it "forwards unsupported streams unconsumed for bounded queue rejection diagnostics", :m4a do
    config = ReportportalCucumber::Config.new(
      queue_max_records: 4,
      queue_max_bytes: 100_000,
      batch_size_logs: 1,
      batch_max_bytes: 100_000,
      retry_attempts: 1,
      spool_dir: Dir.mktmpdir("m4a-world-spool-")
    )
    api_calls = []
    api = Object.new
    api.define_singleton_method(:log_batch) { |entries:, files:| api_calls << [entries, files] }
    log_buffer = ReportportalCucumber::Runtime::LogBuffer.new(api: api, config: config, video_uploader: nil)
    forwarded_attachments = []
    runtime = Object.new
    runtime.define_singleton_method(:emit_world_attachment) do |message:, level:, timestamp:, attachment:|
      forwarded_attachments << attachment
      log_buffer.emit_log(
        item_uuid: "public-step", launch_uuid: "public-launch", message: message,
        level: level, timestamp: timestamp, attachment: attachment
      )
    end
    ReportportalCucumber.current_runtime = runtime

    stream_class = Class.new do
      attr_reader :unbounded_reads, :bounded_reads, :position

      def initialize
        @unbounded_reads = 0
        @bounded_reads = []
        @position = 0
      end

      def read(length = nil)
        unless length && length.positive?
          @unbounded_reads += 1
          raise ArgumentError, "unbounded reads are forbidden"
        end

        @bounded_reads << length
        return nil if @position.positive?

        @position += 64
        "x" * [length, 64].min
      end
    end
    stream = stream_class.new
    log_output = StringIO.new
    previous_logger = ReportportalCucumber.logger
    ReportportalCucumber.logger = Logger.new(log_output)

    results = 12.times.map do
      world.rp_attach(stream, name: "stream.bin", mime: "application/octet-stream")
    end

    expect(stream.unbounded_reads).to eq(0)
    expect(stream.bounded_reads).to be_empty
    expect(stream.position).to eq(0)
    expect(results).to all(be(false))
    expect(forwarded_attachments.length).to eq(12)
    expect(forwarded_attachments).to all(include(bytes: stream))
    expect(log_buffer.diagnostics.dig(:counters, :rejected_unsupported)).to eq(12)
    expect(log_output.string.scan(/admission rejected/).length).to be <= 1
    expect(log_output.string.bytesize).to be < 1_024
    expect(log_output.string).not_to include("x" * 64, "stream.bin")
    expect(api_calls).to be_empty
  ensure
    log_buffer&.shutdown(timeout: 2)
    ReportportalCucumber.logger = previous_logger if previous_logger
  end

  it "rejects oversized raw text without expanding its content as a candidate path", :m4a do
    oversized = +("raw evidence " * 100_000)
    allow(oversized).to receive(:byteslice).and_call_original
    config = ReportportalCucumber::Config.new(
      queue_max_records: 4,
      queue_max_bytes: 1_024,
      batch_size_logs: 1,
      batch_max_bytes: 4_096,
      retry_attempts: 1,
      spool_dir: Dir.mktmpdir("m4a-world-size-spool-")
    )
    api = Object.new
    api.define_singleton_method(:log_batch) { |entries:, files:| raise "oversized attachment reached API" }
    log_buffer = ReportportalCucumber::Runtime::LogBuffer.new(api: api, config: config, video_uploader: nil)
    runtime = Object.new
    runtime.define_singleton_method(:emit_world_attachment) do |message:, level:, timestamp:, attachment:|
      log_buffer.emit_log(
        item_uuid: "public-step", launch_uuid: "public-launch", message: message,
        level: level, timestamp: timestamp, attachment: attachment
      )
    end
    ReportportalCucumber.current_runtime = runtime
    allow(File).to receive(:expand_path).and_call_original
    expect(File).not_to receive(:expand_path).with(oversized)

    expect(world.rp_attach(oversized, name: "evidence.txt", mime: "text/plain")).to be(false)
    expect(oversized).not_to have_received(:byteslice)
    expect(log_buffer.diagnostics.dig(:counters, :rejected_oversized)).to eq(1)
    expect(log_buffer.diagnostics.fetch(:current_bytes)).to eq(0)
  ensure
    log_buffer&.shutdown(timeout: 2)
  end

  it "rejects an IO.pipe through diagnostics without probing path or reading it", :m4a do
    reader, writer = IO.pipe
    config = ReportportalCucumber::Config.new(
      queue_max_records: 4,
      queue_max_bytes: 4_096,
      batch_size_logs: 1,
      batch_max_bytes: 4_096,
      retry_attempts: 1,
      spool_dir: Dir.mktmpdir("m4a-world-pipe-spool-")
    )
    api = Object.new
    api.define_singleton_method(:log_batch) { |entries:, files:| raise "unsupported IO reached API" }
    log_buffer = ReportportalCucumber::Runtime::LogBuffer.new(api: api, config: config, video_uploader: nil)
    forwarded = []
    runtime = Object.new
    runtime.define_singleton_method(:emit_world_attachment) do |message:, level:, timestamp:, attachment:|
      forwarded << attachment
      log_buffer.emit_log(
        item_uuid: "public-step", launch_uuid: "public-launch", message: message,
        level: level, timestamp: timestamp, attachment: attachment
      )
    end
    ReportportalCucumber.current_runtime = runtime
    expect(reader).not_to receive(:read)
    expect(reader).not_to receive(:path)

    result = nil
    expect do
      result = world.rp_attach(reader, name: "pipe.bin", mime: "application/octet-stream")
    end.not_to raise_error
    expect(result).to be(false)
    expect(forwarded).to all(include(bytes: reader))
    expect(log_buffer.diagnostics.dig(:counters, :rejected_unsupported)).to eq(1)
    expect(log_buffer.diagnostics.fetch(:current_records)).to eq(0)
  ensure
    reader&.close unless reader&.closed?
    writer&.close unless writer&.closed?
    log_buffer&.shutdown(timeout: 2)
  end

  it "preserves a StringIO caller cursor while admitting its backing bytes", :m4a do
    config = ReportportalCucumber::Config.new(
      queue_max_records: 4,
      queue_max_bytes: 100_000,
      batch_size_logs: 1,
      batch_max_bytes: 100_000,
      retry_attempts: 1,
      spool_dir: Dir.mktmpdir("m4a-stringio-spool-")
    )
    api_calls = []
    api = Object.new
    api.define_singleton_method(:log_batch) { |entries:, files:| api_calls << [entries, files] }
    log_buffer = ReportportalCucumber::Runtime::LogBuffer.new(api: api, config: config, video_uploader: nil)
    runtime = Object.new
    runtime.define_singleton_method(:emit_world_attachment) do |message:, level:, timestamp:, attachment:|
      log_buffer.emit_log(
        item_uuid: "public-step", launch_uuid: "public-launch", message: message,
        level: level, timestamp: timestamp, attachment: attachment
      )
    end
    ReportportalCucumber.current_runtime = runtime
    source = StringIO.new("prefix: full backing evidence")
    source.seek(7)

    expect(world.rp_attach(source, name: "evidence.txt", mime: "text/plain")).to be(true)
    expect(source.pos).to eq(7)
    expect(log_buffer.flush(timeout: 2)).to be(true)
    expect(api_calls.flat_map(&:last).first).to include(name: "evidence.txt", bytes: "prefix: full backing evidence")
  ensure
    log_buffer&.shutdown(timeout: 2)
  end

  it "mirrors rp_log to stdout when console mirror mode is enabled" do
    config = instance_double("config", console_mirror?: true)
    runtime = instance_double("runtime", config: config)
    timestamp = Time.utc(2026, 3, 26, 0, 0, 0)
    ReportportalCucumber.current_runtime = runtime

    expect(runtime).to receive(:emit_world_log).with(
      message: "{\"ok\":true}",
      level: "INFO",
      timestamp: timestamp,
      attachment: nil
    )

    expect do
      world.rp_log("{\"ok\":true}", "INFO", timestamp: timestamp)
    end.to output("[RP-MIRROR] [INFO] {\"ok\":true}\n").to_stdout
  end

  it "does not mirror rp_log when console mirror mode is disabled" do
    config = instance_double("config", console_mirror?: false)
    runtime = instance_double("runtime", config: config)
    ReportportalCucumber.current_runtime = runtime

    expect(runtime).to receive(:emit_world_log).with(
      hash_including(message: "quiet", level: :debug, attachment: nil)
    )

    expect do
      world.rp_log("quiet", level: :debug)
    end.not_to output.to_stdout
  end
end
