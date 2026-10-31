# frozen_string_literal: true

require "spec_helper"
require "cucumber/events"

RSpec.describe "Ledger attachment ownership and batching" do
  let(:context_class) { ReportportalCucumber::Runtime::Context }
  let(:builder) { ReportportalCucumber::Service::PayloadBuilder }
  let(:time) { Time.utc(2026, 10, 31) }

  def setup_formatter(buffer)
    formatter = ReportportalCucumber::Cucumber::Formatter.allocate
    formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new(enabled: true))
    formatter.instance_variable_set(:@runtime_context, context_class.new)
    formatter.instance_variable_set(:@log_buffer, buffer)
    formatter.instance_variable_set(:@launch_uuid, "launch")
    formatter.instance_variable_set(:@attachment_name_mutex, Mutex.new)
    formatter.instance_variable_set(:@attachment_name_counts, Hash.new(0))
    allow(formatter).to receive(:reporting_enabled?).and_return(true)
    scenario = context_class::ItemHandle.new(uuid: "scenario", name: "Scenario", kind: :scenario, type: "STEP")
    formatter.runtime_context.start_scenario("case", scenario)
    formatter
  end

  def owner(formatter, uuid, name, kind: :step)
    item = context_class::ItemHandle.new(uuid: uuid, name: name, kind: kind, type: kind == :hook ? "AFTER_METHOD" : "STEP",
                                        parent_uuid: "scenario", has_stats: false)
    formatter.runtime_context.push_step(item)
    formatter.runtime_context.register_capture_target(item, launch_uuid: "launch", owner: formatter)
    item
  end

  def attachment_run(batch_size)
    calls = []
    api = Object.new
    api.define_singleton_method(:log_batch) do |entries:, files:|
      calls << { entries: entries, files: files }
      { "responses" => entries.map { { "message" => "ok" } } }
    end
    config = ReportportalCucumber::Config.new(batch_size_logs: batch_size, flush_interval: 0.1,
                                             queue_max_records: 100, queue_max_bytes: 1_000_000, batch_max_bytes: 1_000_000)
    buffer = ReportportalCucumber::Runtime::LogBuffer.new(api: api, config: config)
    formatter = setup_formatter(buffer)
    owner(formatter, "step", "Then the order is confirmed")
    world = Object.new.extend(ReportportalCucumber::Cucumber::World)
    ReportportalCucumber.current_runtime = formatter
    bytes = "literal-not-an-image".b.freeze
    world.rp_attach(bytes, mime: "image/png")
    formatter.send(:handle_attach_called, ::Cucumber::Events::AttachCalled.new(bytes, "image/png", nil))
    world.rp_attach(bytes, mime: "image/png", name: "explicit.png", message: "Caller **message**")
    formatter.emit_world_log(message: "User <literal>", level: :debug, timestamp: time,
                             attachment: { bytes: "{}", mime: "application/json" })
    owner(formatter, "after", "After hook", kind: :hook)
    formatter.send(:handle_attach_called, ::Cucumber::Events::AttachCalled.new(bytes, "image/jpeg", nil))
    expect(buffer.flush(timeout: 2)).to be(true)
    calls.flat_map do |call|
      call[:entries].zip(call[:files]).map do |entry, file|
        { owner: entry["itemUuid"], name: file[:name], mime: file[:mime], bytes: file[:bytes],
          level: entry["level"], message: entry["message"] }
      end
    end
  ensure
    buffer&.shutdown(timeout: 2)
    ReportportalCucumber.current_runtime = nil
  end

  it "assigns per-owner names once, independent of batch size, and leaves After-hook bytes on the hook" do
    small = attachment_run(1)
    normal = attachment_run(20)
    expect(small).to eq(normal)
    expect(small.map { |entry| entry[:name] }).to eq([
      "then-the-order-is-confirmed.png", "then-the-order-is-confirmed-1.png", "explicit.png",
      "then-the-order-is-confirmed-2.json", "after-hook.jpg"
    ])
    expect(small.map { |entry| entry[:owner] }).to eq(%w[step step step step after])
    expect(small.last).to include(mime: "image/jpeg", bytes: "literal-not-an-image", level: "info")
    expect(small[2][:message]).to start_with("Caller **message**\n\n`explicit.png`")
    expect(small[3][:message]).to start_with("User <literal>\n\n`then-the-order-is-confirmed-2.json`")
    expect(small.map { |entry| entry[:message] }).not_to include(start_with("Attachment:"))
  end

  it "preserves literal native log text and does not consume a default-name index for logs" do
    records = []
    buffer = double("buffer")
    allow(buffer).to receive(:emit_log) { |**record| records << record; true }
    formatter = setup_formatter(buffer)
    owner(formatter, "step", "Given values")
    formatter.send(:handle_attach_called, ::Cucumber::Events::AttachCalled.new("<raw> **log**", "text/x.cucumber.log+plain", nil))
    formatter.send(:handle_attach_called, ::Cucumber::Events::AttachCalled.new("bytes", "image/png", nil))
    expect(records.first[:message]).to eq("<raw> **log**")
    expect(records.first[:attachment]).to be_nil
    expect(records.last[:attachment][:name]).to eq("given-values.png")
  end

  it "uses one emission counter across MIME types and releases it after the owner closes" do
    formatter = setup_formatter(double("buffer", emit_log: true))
    item = owner(formatter, "step", "Then the order is confirmed")
    names = %w[image/png application/json image/png].map do |mime|
      formatter.send(:attachment_for_owner, { mime: mime, bytes: "AAAA" }, item)[:name]
    end
    expect(names).to eq(%w[then-the-order-is-confirmed.png then-the-order-is-confirmed-1.json then-the-order-is-confirmed-2.png])
    expect(formatter.send(:close_capture_target_for_item, item)).to be(true)
    expect(formatter.instance_variable_get(:@attachment_name_counts)).to be_empty
  end

  it "clears remaining name counters during finalization even when completeness enforcement raises" do
    formatter = setup_formatter(nil)
    item = owner(formatter, "step", "Given values")
    formatter.send(:attachment_for_owner, { mime: "image/png", bytes: "AAAA" }, item)
    formatter.instance_variable_set(:@combined_step_tables_mutex, Mutex.new)
    formatter.instance_variable_set(:@combined_step_tables, {})
    allow(formatter).to receive(:reporting_lifecycle_active?).and_return(true)
    allow(formatter).to receive(:emit_incomplete_reporting_summary)
    failure = StandardError.new("original reporting failure")
    allow(formatter).to receive(:enforce_complete_reporting).and_raise(failure)
    expect { formatter.send(:finalize_reporting, status: "passed", end_time: time) }.to raise_error { |error| expect(error).to equal(failure) }
    expect(formatter.instance_variable_get(:@attachment_name_counts)).to be_empty
  end

  it "keeps explicitly named input immutable and chooses ASCII fallback slugs" do
    buffer = double("buffer", emit_log: true)
    formatter = setup_formatter(buffer)
    item = owner(formatter, "step", "\u4e2d\u6587")
    input = { name: "explicit.png", mime: "image/png", bytes: "AAAA".freeze }.freeze
    expect(formatter.send(:attachment_for_owner, input, item)).to equal(input)
    generated = formatter.send(:attachment_for_owner, { mime: "image/png", bytes: "AAAA" }, item)
    expect(generated[:name]).to eq("attachment.png")
    expect(input[:name]).to eq("explicit.png")
  end

  it "falls back without further helper calls or advancing the counter when slug formatting fails" do
    records = []
    buffer = double("buffer")
    allow(buffer).to receive(:emit_log) { |**record| records << record; true }
    formatter = setup_formatter(buffer)
    owner(formatter, "step", "Given values")
    logger = double("logger", warn: nil, debug: nil)
    allow(ReportportalCucumber).to receive(:logger).and_return(logger)
    expect(ReportportalCucumber::Presentation::AttachmentCaption).to receive(:slug).once.and_raise("SECRET123")
    expect(ReportportalCucumber::Presentation::AttachmentCaption).not_to receive(:format)
    formatter.send(:handle_attach_called, ::Cucumber::Events::AttachCalled.new("hello", "text/plain", nil))
    result = builder.build_log_batch(records)
    expect(result[:entries].first["message"]).to eq("Attachment\n\n```text\nhello\n```")
    expect(result[:files].first[:name]).to eq("attachment.txt")
    expect(formatter.instance_variable_get(:@attachment_name_counts)["step"]).to eq(0)
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end

  it "emits one warning per failed message across queue size probes and final delivery" do
    calls = []
    api = Object.new
    api.define_singleton_method(:log_batch) do |entries:, files:|
      calls.concat(entries)
      { "responses" => entries.map { { "message" => "ok" } } }
    end
    config = ReportportalCucumber::Config.new(batch_size_logs: 20, flush_interval: 0.1)
    buffer = ReportportalCucumber::Runtime::LogBuffer.new(api: api, config: config)
    logger = double("logger", warn: nil)
    allow(ReportportalCucumber).to receive(:logger).and_return(logger)
    expect(ReportportalCucumber::Presentation::AttachmentCaption).to receive(:format).exactly(2).times.and_raise("SECRET123")
    2.times do |index|
      buffer.emit_log(item_uuid: "step", launch_uuid: "launch", message: "Attachment: #{index}.txt", level: :info,
                      timestamp: time, attachment: { name: "#{index}.txt", mime: "text/plain", bytes: "hello", caption_style: "default" })
    end
    expect(buffer.flush(timeout: 2)).to be(true)
    expect(calls.map { |entry| entry["message"] }).to eq(["Attachment: 0.txt\n\n```text\nhello\n```", "Attachment: 1.txt\n\n```text\nhello\n```"])
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).twice
  ensure
    buffer&.shutdown(timeout: 2)
  end

  it "marks evidence artifacts without altering summary count, artifact ownership, or bytes" do
    records = []
    buffer = double("buffer")
    allow(buffer).to receive(:emit_log) { |**record| records << record; true }
    formatter = setup_formatter(buffer)
    item = owner(formatter, "after", "After hook", kind: :hook)
    target = formatter.capture_target
    expect(formatter.report_evidence(action: "failed", error: RuntimeError.new("original"), target: target,
                                     artifacts: [{ name: "evidence.png", mime: "image/png", bytes: "AAAA" }])).to be(true)
    expect(records.length).to eq(2)
    expect(records).to all(include(item_uuid: item.uuid, level: :error))
    result = builder.build_log_batch(records)
    expect(result[:entries].last["message"]).to eq("`evidence.png` \u00b7 PNG \u00b7 4 B \u00b7 failure evidence")
    expect(result[:files].first[:bytes]).to eq("AAAA")
  end
end
