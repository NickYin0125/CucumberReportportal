# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Service::QueueProcessor do
  let(:builder) { ReportportalCucumber::Service::PayloadBuilder }
  let(:caption) { ReportportalCucumber::Presentation::AttachmentCaption }
  let(:multipart) { ReportportalCucumber::Transport::MultipartHelper }
  let(:logger) { double("presentation logger", warn: nil) }
  let(:processors) { [] }
  let(:spool_dir) { Dir.mktmpdir("presentation-failures-spool-") }

  before do
    allow(ReportportalCucumber).to receive(:logger).and_return(logger)
  end

  after do
    processors.each { |processor| processor.shutdown(timeout: 2) }
    FileUtils.remove_entry(spool_dir) if File.exist?(spool_dir)
  end

  def processor_for(presentation:, batch_max_bytes: 100_000, &send_batch)
    config = ReportportalCucumber::Config.new(
      presentation: presentation, batch_size_logs: 2, batch_max_bytes: batch_max_bytes,
      queue_max_records: 20, queue_max_bytes: 100_000, flush_interval: 10,
      retry_attempts: 1, spool_dir: spool_dir
    )
    api = Object.new
    api.define_singleton_method(:log_batch) do |entries:, files:|
      send_batch.call(entries: entries, files: files)
    end
    described_class.new(api: api, config: config).tap { |processor| processors << processor }
  end

  def attributes(index)
    {
      item_uuid: "owner-#{index}", launch_uuid: "launch", level: :info,
      timestamp: Time.utc(2026, 11, 1) + index, message: "Caller #{index}\0 literal\\u0000",
      attachment: { name: "#{index}.txt", mime: "text/plain", bytes: "preview-#{index}\0original" }
    }
  end

  def baseline_payload(records, presentation:)
    payload = builder.build_log_batch(records, presentation: presentation)
    payload[:entries].zip(records).each do |entry, record|
      entry["message"] = builder.baseline_log_message(record[:message], record[:attachment])
    end
    payload
  end

  def wire_body(payload)
    parts = [{ name: "json_request_part", content_type: "application/json", body: JSON.generate(payload[:entries]) }]
    payload[:files].each do |file|
      parts << { name: "file", filename: file.fetch(:name), content_type: file.fetch(:mime), body: file.fetch(:bytes) }
    end
    multipart.encode(parts: parts, boundary: "----rp000000000000000000000000")
  end

  def observe_builds(processor, builds)
    # Keep RSpec's prepended Method intact through Ruby 3.1 keyword forwarding.
    allow(processor).to receive(:build_payload).and_wrap_original do |original, records, options = {}|
      failures = options[:presentation_failures]
      builds << {
        thread: Thread.current, failures: failures, cache: options[:rendered_messages],
        latched: failures && failures.select { |_sequence, state| state[:failed] }.keys
      }
      original.call(records, **options)
    end
  end

  %w[plain rich].each do |mode|
    it "isolates a concurrent #{mode} standalone spool from the worker's latched sequence 1 failure" do
      entered = Queue.new
      release = Queue.new
      builds = Queue.new
      persisted = Queue.new
      record = attributes(0)
      expected = builder.build_log_batch([record], presentation: mode)
      baseline = baseline_payload([record], presentation: mode)
      sent = []
      processor = processor_for(presentation: mode) do |entries:, files:|
        sent << { entries: entries, files: files }
        entered << true
        release.pop
        { "responses" => entries.map { { "id" => "confirmed" } } }
      end
      worker = processor.instance_variable_get(:@worker)
      observe_builds(processor, builds)
      allow(caption).to receive(:format).and_wrap_original do |original, options|
        raise "SECRET123" if Thread.current == worker

        original.call(**options)
      end
      allow(processor.instance_variable_get(:@spool_store)).to receive(:persist) { |**payload| persisted << payload }
      expect(processor.emit_log(**record)).to be(true)
      flusher = Thread.new { processor.flush(timeout: 2) }
      Timeout.timeout(2) { entered.pop }

      standalone_record = described_class::LogRecord.new(**record, sequence: 1)
      spool_thread = Thread.new { processor.send(:safe_spool, [standalone_record], RuntimeError.new("standalone spool")) }
      expect(Timeout.timeout(2) { spool_thread.value }).to be(true)
      spooled = persisted.pop
      events = builds.size.times.map { builds.pop }
      worker_events = events.select { |event| event[:thread] == worker }
      standalone_events = events.select { |event| event[:thread] == spool_thread }

      expect(worker_events.last[:latched]).to eq([1])
      expect(worker_events.map { |event| event[:failures].object_id }.uniq.length).to eq(1)
      expect(standalone_events.length).to eq(1)
      expect(standalone_events.first).to include(failures: nil, cache: nil, latched: nil)
      expect(wire_body(spooled)).to eq(wire_body(expected))
      expect(wire_body(sent.first)).to eq(wire_body(baseline))
      expect(spooled[:entries].first["message"]).not_to eq(sent.first[:entries].first["message"])
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
      release << true
      expect(flusher.value).to be(true)
      expect(processor.shutdown(timeout: 2)).to be(true)
      expect(worker_events.map { |event| event[:failures] }).to all(be_empty)
      expect(processor.instance_variables).not_to include(:@presentation_failures)
    ensure
      release << true if release && release.empty?
      spool_thread&.join(2)
      flusher&.join(2)
    end

    %i[delivery_error incomplete_ack oversized_wire probe_error].each do |failure|
      it "retains one #{mode} warning per record when #{failure} sends the worker's records to its own spool" do
        records = 2.times.map { |index| attributes(index) }
        expected = baseline_payload(records, presentation: mode)
        expected_wire = wire_body(expected)
        builds = Queue.new
        persisted = []
        sent = []
        processor = processor_for(presentation: mode, batch_max_bytes: failure == :oversized_wire ? 1 : 100_000) do |entries:, files:|
          sent << { entries: entries, files: files }
          raise IOError, "delivery failed" if failure == :delivery_error

          { "responses" => [{ "message" => "rejected" }, nil] }
        end
        observe_builds(processor, builds)
        allow(processor.instance_variable_get(:@spool_store)).to receive(:persist) { |**payload| persisted << payload }
        allow(caption).to receive(:format).and_raise("SECRET123")
        if failure == :probe_error
          allow(multipart).to receive(:log_batch_bytes).and_wrap_original do |original, payload|
            raise "probe failed" if payload[:entries].length == 2

            original.call(**payload)
          end
        end
        records.each { |record| expect(processor.emit_log(**record)).to be(true) }
        expect(processor.shutdown(timeout: 2)).to be(true)

        events = builds.size.times.map { builds.pop }
        spool_events = events.select { |event| event[:cache].nil? }
        expect(spool_events).not_to be_empty
        expect(spool_events).to all(include(latched: [1, 2])) unless failure == :oversized_wire
        expect(events.map { |event| event[:failures].object_id }.uniq.length).to eq(1)
        expect(events.map { |event| event[:failures] }).to all(be_a(Hash).and(be_empty))
        expect(caption).to have_received(:format).exactly(2).times
        expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).exactly(2).times
        expect(processor.diagnostics.dig(:counters, :spooled)).to eq(2)
        expect(persisted.flat_map { |payload| payload[:entries] }).to eq(expected[:entries])
        expect(persisted.flat_map { |payload| payload[:files] }).to eq(expected[:files])
        if %i[delivery_error incomplete_ack].include?(failure)
          expect(wire_body(sent.first)).to eq(expected_wire)
        else
          expect(sent).to be_empty
        end
        persisted.each do |payload|
          indexes = payload[:entries].map { |entry| entry["itemUuid"].delete_prefix("owner-").to_i }
          expected_chunk = { entries: indexes.map { |index| expected[:entries][index] },
                             files: indexes.map { |index| expected[:files][index] } }
          expect(wire_body(payload)).to eq(wire_body(expected_chunk))
        end
      end
    end
  end
end
