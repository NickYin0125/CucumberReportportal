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

  it "restores the baseline shape with required 1.x redaction when the card entry point raises" do
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
      allow(Automation::EvidenceRedactor).to receive(:new).and_return(redactor)
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

  it "preserves Step failed when whole-message redaction produces an empty string" do
    failure = RuntimeError.new('""')
    failure.set_backtrace([])
    formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
    expect(buffer).to have_received(:emit_log).with(hash_including(message: "Step failed"))
  end
end
