# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Cucumber::Formatter do
  let(:formatter) { described_class.allocate }
  let(:buffer) { double("buffer", emit_log: nil) }
  let(:logger) { double("logger", warn: nil) }
  let(:timestamp) { Time.utc(2026, 10, 31) }
  let(:error) do
    RuntimeError.new("api_key=SECRET123 failure").tap { |failure| failure.set_backtrace(["support.rb:1:in 'fail'"]) }
  end

  before do
    formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new)
    formatter.instance_variable_set(:@launch_uuid, "launch-1")
    formatter.instance_variable_set(:@log_buffer, buffer)
    allow(formatter).to receive(:monotonic_timestamp).with(timestamp).and_return(timestamp)
    allow(ReportportalCucumber).to receive(:logger).and_return(logger)
  end

  it "changes only the error message, never count, level, target or time" do
    original_message = error.message.dup
    original_backtrace = error.backtrace.dup
    formatter.send(:emit_error_log, item_uuid: "after-hook", error: error, timestamp: timestamp)
    expect(buffer).to have_received(:emit_log).once.with(
      item_uuid: "after-hook", launch_uuid: "launch-1", level: :error, timestamp: timestamp,
      message: start_with("## \u2717 RuntimeError: api\\_key=\\[REDACTED\\] failure")
    )
    expect(error.message).to eq(original_message)
    expect(error.backtrace).to eq(original_backtrace)
  end

  it "restores the exact pre-Ledger redacted message when the card entry point raises" do
    allow(ReportportalCucumber::Presentation::FailureCard).to receive(:format).and_raise("SECRET123")
    formatter.send(:emit_error_log, item_uuid: "after-hook", error: error, timestamp: timestamp)
    expect(buffer).to have_received(:emit_log).once.with(
      item_uuid: "after-hook", launch_uuid: "launch-1", level: :error, timestamp: timestamp,
      message: "api_key=[REDACTED] failure\nsupport.rb:1:in 'fail'"
    )
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end

  it "does not swallow reporting failures or retry emission as a presentation fallback" do
    allow(buffer).to receive(:emit_log).and_raise(ReportportalCucumber::ReportingError, "delivery failed")
    expect { formatter.send(:emit_error_log, item_uuid: "step-1", error: error, timestamp: timestamp) }
      .to raise_error(ReportportalCucumber::ReportingError, "delivery failed")
    expect(buffer).to have_received(:emit_log).once
    expect(logger).not_to have_received(:warn)
  end

  %w[plain rich].each do |mode|
    it "redacts exactly two units for a normal #{mode} failure emission" do
      formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new("rp.presentation" => mode))
      redactor = Automation::EvidenceRedactor.new
      failure_redactor = Automation::FailureRedactor.new(redactor: redactor)
      allow(Automation::FailureRedactor).to receive(:new).and_return(failure_redactor)
      expect(redactor).to receive(:redact_text).with(error.message).once.and_call_original
      expect(redactor).to receive(:redact_text).with(error.backtrace.join("\n")).once.and_call_original
      formatter.send(:emit_error_log, item_uuid: "step-1", error: error, timestamp: timestamp)
      expect(buffer).to have_received(:emit_log).with(hash_including(message: start_with("## \u2717 RuntimeError:")))
    end
  end

  it "preserves Step failed for an empty non-exception failure" do
    failure = Struct.new(:message, :backtrace).new("", [])
    formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
    expect(buffer).to have_received(:emit_log).with(hash_including(message: "Step failed"))
  end

  probes = [
    [RuntimeError.new('back\\slash'), :kept],
    [RuntimeError.new('expected "ABC" to match /\\d+/'), :kept],
    [Errno::ENOENT.new('C:\\logs\\failure.json'), :kept],
    [RuntimeError.new("expected: \"first\\nsecond\"\n     got: \"first\\nchanged\"\nDiff:\n- second\n+ changed"), :withheld],
    [RuntimeError.new('HTTP 500 body: {"message":"a\\"b"}'), :withheld],
    [RuntimeError.new('request failed: "{\\"api_key\\":\\"F1_PROBE_SECRET\\"}"'), :withheld]
  ]
  %w[plain rich].each do |mode|
    probes.each_with_index do |(failure, disposition), index|
      it "keeps all 62 frame bytes for #{mode} F1 probe #{index + 1} (#{disposition})" do
        formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new("rp.presentation" => mode))
        frames = Array.new(62) { |i| "/project/features/support/helper_#{i}.rb:#{i + 1}:in '<top (required)>'" }
        failure.set_backtrace(frames)
        expect(buffer).to receive(:emit_log).once do |entry|
          expect(entry.except(:message)).to eq(item_uuid: "step-1", launch_uuid: "launch-1", level: :error, timestamp: timestamp)
          body = entry.fetch(:message)
          # The rich wrapper may differ, but the fenced raw tail must not.
          tail = body.scan(/```text\n(.*?)\n```/m).last.fetch(0)
          expect(tail.b).to eq(frames.join("\n").b)
          expect(body).not_to include("F1_PROBE_SECRET")
          if disposition == :withheld
            expect(body.lines[2].chomp).to eq("Message withheld: unsafe or ambiguous input")
            expect(body.lines.first).to include(failure.class.name)
          else
            escaped = ReportportalCucumber::Presentation::MarkdownText.inline(failure.message)
            expect(body.lines.first).to include(escaped)
            expect(body).not_to include("Message withheld:")
          end
        end
        formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
        expect(failure.backtrace).to eq(frames)
      end
    end
  end

  it "preserves Step failed when whole-message redaction produces an empty string" do
    failure = RuntimeError.new('""')
    failure.set_backtrace([])
    formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
    expect(buffer).to have_received(:emit_log).with(hash_including(message: "Step failed"))
  end
end
