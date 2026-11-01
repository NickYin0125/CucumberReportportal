# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Service::QueueProcessor do
  let(:builder) { ReportportalCucumber::Service::PayloadBuilder }
  let(:multipart) { ReportportalCucumber::Transport::MultipartHelper }
  let(:processors) { [] }
  let(:spool_dir) { Dir.mktmpdir("render-cache-spool-") }

  before do
    allow(multipart).to receive(:standard_boundary).and_return("----rp000000000000000000000000")
  end

  after do
    processors.each { |processor| processor.shutdown(timeout: 2) }
    FileUtils.remove_entry(spool_dir) if File.exist?(spool_dir)
  end

  def processor_for(presentation:, batch_max_bytes: 1_000_000, &send_batch)
    config = ReportportalCucumber::Config.new(
      presentation: presentation, batch_size_logs: 20, batch_max_bytes: batch_max_bytes,
      queue_max_records: 100, queue_max_bytes: 1_000_000, flush_interval: 10,
      retry_attempts: 1, spool_dir: spool_dir
    )
    api = Object.new
    api.define_singleton_method(:log_batch) do |entries:, files:|
      send_batch.call(entries: entries, files: files)
    end
    described_class.new(api: api, config: config).tap { |processor| processors << processor }
  end

  def record_attributes(index, name: "#{index}.txt")
    {
      item_uuid: "owner-#{index}", launch_uuid: "launch-#{index % 2}", level: :info,
      timestamp: Time.utc(2026, 11, 1) + index, message: "Caller #{index}\0 literal\\u0000",
      attachment: { name: name, mime: "text/plain", bytes: "preview-#{index}\0 original bytes" }
    }
  end

  def wire_body(entries:, files:)
    parts = [{ name: "json_request_part", content_type: "application/json", body: JSON.generate(entries) }]
    files.each do |file|
      parts << { name: "file", filename: file.fetch(:name), content_type: file.fetch(:mime), body: file.fetch(:bytes) }
    end
    multipart.encode(parts: parts, boundary: multipart.standard_boundary)
  end

  %w[plain rich].each do |mode|
    it "preserves #{mode} wire bytes when duplicate explicit filenames split across chunks" do
      records = %w[evidence.txt evidence.txt evidence-1.txt evidence.txt evidence.txt evidence-1.txt]
        .each_with_index.map { |name, index| record_attributes(index, name: name) }
      limit = records.each_slice(2).map do |chunk|
        multipart.log_batch_bytes(**builder.build_log_batch(chunk, presentation: mode))
      end.max
      records.each_cons(3) do |chunk|
        expect(multipart.log_batch_bytes(**builder.build_log_batch(chunk, presentation: mode))).to be > limit
      end
      cache_enabled = false
      allow(builder).to receive(:build_log_batch).and_wrap_original do |original, batch, **options, &state|
        options.delete(:rendered_messages) unless cache_enabled
        original.call(batch, **options, &state)
      end
      deliveries = [false, true].map do |enabled|
        cache_enabled = enabled
        sent = []
        processor = processor_for(presentation: mode, batch_max_bytes: limit) do |entries:, files:|
          sent << { entries: entries, files: files, wire: wire_body(entries: entries, files: files) }
          { "responses" => entries.map { { "id" => "confirmed" } } }
        end
        records.each { |attributes| expect(processor.emit_log(**attributes)).to be(true) }
        expect(processor.shutdown(timeout: 2)).to be(true)
        expect(processor.diagnostics.dig(:counters, :confirmed)).to eq(records.length)
        sent
      end

      uncached, cached = deliveries
      expect(cached).to eq(uncached)
      expect(cached.map { |batch| batch[:entries].length }).to eq([2, 2, 2])
      expect(cached.flat_map { |batch| batch[:entries] }.map { |entry| entry["itemUuid"] })
        .to eq(records.map { |record| record[:item_uuid] })
      cached.each do |batch|
        expect(batch[:wire].bytesize).to be <= limit
        expect(batch[:entries].map { |entry| entry.dig("file", "name") }).to eq(batch[:files].map { |file| file[:name] })
      end
      expect(cached.last[:files].map { |file| file[:name] }).to eq(["evidence.txt", "evidence-1.txt"])
      expect(cached.flat_map { |batch| batch[:files] }.map { |file| file[:bytes] })
        .to eq(records.map { |record| record.dig(:attachment, :bytes).b })
    end

    it "renders #{mode} messages once per record and clears each 20-record flush cache" do
      caches = []
      sizes = []
      allow(builder).to receive(:enrich_log_message).and_call_original
      allow(builder).to receive(:build_log_batch).and_wrap_original do |original, batch, **options, &state|
        cache = options.fetch(:rendered_messages)
        caches << cache
        original.call(batch, **options, &state).tap { sizes << cache.length }
      end
      processor = processor_for(presentation: mode) do |entries:, files:|
        { "responses" => entries.map { { "id" => "confirmed" } } }
      end
      2.times do
        20.times { |index| expect(processor.emit_log(**record_attributes(index))).to be(true) }
        expect(processor.flush(timeout: 2)).to be(true)
      end
      expect(processor.shutdown(timeout: 2)).to be(true)

      expect(builder).to have_received(:enrich_log_message).exactly(40).times
      expect(caches.uniq(&:object_id).length).to eq(2)
      expect(caches).to all(be_empty)
      expect(sizes.max).to eq(20)
      expect(processor.diagnostics.dig(:counters, :confirmed)).to eq(40)
    end

    it "keeps #{mode} fallback messages and warnings unchanged across collision-sensitive probes" do
      caches = []
      allow(builder).to receive(:build_log_batch).and_wrap_original do |original, batch, **options, &state|
        caches << options.fetch(:rendered_messages)
        original.call(batch, **options, &state)
      end
      records = 4.times.map { |index| record_attributes(index, name: "duplicate.txt") }
      baseline = records.map do |record|
        "#{record[:message]}\n\n```text\npreview-#{record[:item_uuid].delete_prefix('owner-')}\0 original bytes\n```"
      end
      expect(ReportportalCucumber::Presentation::AttachmentCaption).to receive(:format).exactly(4).times.and_raise("SECRET123")
      expect(ReportportalCucumber.logger).to receive(:warn)
        .with(ReportportalCucumber::Presentation::Fallback::WARNING).exactly(4).times
      sent = []
      processor = processor_for(presentation: mode, batch_max_bytes: 1200) do |entries:, files:|
        sent.concat(entries)
        { "responses" => entries.map { { "id" => "confirmed" } } }
      end
      records.each { |attributes| expect(processor.emit_log(**attributes)).to be(true) }
      expect(processor.shutdown(timeout: 2)).to be(true)

      expect(sent.map { |entry| entry["message"] }).to eq(baseline)
      expect(caches).to all(be_empty)
      expect(processor.diagnostics.dig(:counters, :confirmed)).to eq(4)
    end
  end

  it "clears the local cache if a size probe fails partway through a flush" do
    caches = []
    allow(builder).to receive(:build_log_batch).and_wrap_original do |original, batch, **options, &state|
      caches << options.fetch(:rendered_messages)
      original.call(batch, **options, &state)
    end
    allow(multipart).to receive(:log_batch_bytes).and_wrap_original do |original, **payload|
      raise "size probe failed" if payload[:entries].length == 2

      original.call(**payload)
    end
    processor = processor_for(presentation: "plain") { |entries:, files:| raise "must not send" }
    allow(processor).to receive(:safe_spool).and_return(true)
    3.times { |index| expect(processor.emit_log(**record_attributes(index))).to be(true) }
    expect(processor.shutdown(timeout: 2)).to be(true)

    expect(caches).not_to be_empty
    expect(caches).to all(be_empty)
    expect(processor.diagnostics.dig(:counters, :ambiguous)).to eq(3)
    expect(processor).to have_received(:safe_spool).once
  end

  it "does not share the active flush cache with a concurrent spool build" do
    entered = Queue.new
    release = Queue.new
    builds = Queue.new
    persisted = []
    allow(builder).to receive(:build_log_batch).and_wrap_original do |original, batch, **options, &state|
      builds << [Thread.current, options[:rendered_messages]]
      original.call(batch, **options, &state)
    end
    processor = processor_for(presentation: "rich") do |entries:, files:|
      entered << true
      release.pop
      { "responses" => entries.map { { "id" => "confirmed" } } }
    end
    allow(processor.instance_variable_get(:@spool_store)).to receive(:persist) do |**payload|
      persisted << payload
    end
    20.times { |index| expect(processor.emit_log(**record_attributes(index))).to be(true) }
    Timeout.timeout(2) { entered.pop }
    spool_record = described_class::LogRecord.new(**record_attributes(99), sequence: 1)
    spool_thread = Thread.new { processor.send(:spool, [spool_record], RuntimeError.new("spool test")) }
    spool_thread.value
    release << true
    expect(processor.shutdown(timeout: 2)).to be(true)
    calls = builds.size.times.map { builds.pop }

    expect(calls.select { |thread, _cache| thread == spool_thread }.map(&:last)).to eq([nil])
    worker_caches = calls.reject { |thread, _cache| thread == spool_thread }.map(&:last)
    expect(worker_caches).not_to be_empty
    expect(worker_caches).to all(be_a(Hash).and(be_empty))
    expect(persisted.first[:entries].first["message"]).to start_with("Caller 99")
  ensure
    release << true if release && release.empty?
    spool_thread&.join(2)
  end
end
