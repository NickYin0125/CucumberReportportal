# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Cucumber::Formatter do
  let(:formatter) { described_class.allocate }
  let(:buffer) { double("buffer", emit_log: nil) }
  let(:logger) { double("logger", warn: nil) }
  let(:timestamp) { Time.utc(2026, 10, 31) }
  let(:emissions) { [] }
  let(:error) do
    RuntimeError.new("api_key=SECRET123 failure").tap { |failure| failure.set_backtrace(["support.rb:1:in 'fail'"]) }
  end

  before do
    formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new)
    formatter.instance_variable_set(:@launch_uuid, "launch-1")
    formatter.instance_variable_set(:@log_buffer, buffer)
    allow(formatter).to receive(:monotonic_timestamp).with(timestamp).and_return(timestamp)
    allow(ReportportalCucumber).to receive(:logger).and_return(logger)
    allow(buffer).to receive(:emit_log) { |payload| emissions << payload }
    expect_any_instance_of(Automation::EvidenceRedactor).not_to receive(:redact_text)
  end

  # The message join from v1.3.1 (4ca2f77), including non-Exception inputs.
  def original_message(failure)
    details = failure.respond_to?(:message) ? failure.message.to_s : failure.to_s
    trace = if failure.respond_to?(:backtrace)
              Array(failure.backtrace).join("\n")
            else
              formatter.send(:fetch_value, failure, :backtrace).to_s
            end
    message = [details, trace].reject(&:empty?).join("\n")
    message.empty? ? "Step failed" : message
  end

  def assertion_failure
    yield
  rescue RSpec::Expectations::ExpectationNotMetError => failure
    failure
  else
    raise "Expected a real RSpec assertion failure"
  end

  it "changes only the error message, never count, level, target or time" do
    original_message = error.message.dup
    original_backtrace = error.backtrace.dup
    formatter.send(:emit_error_log, item_uuid: "after-hook", error: error, timestamp: timestamp)
    expect(buffer).to have_received(:emit_log).once.with(
      item_uuid: "after-hook", launch_uuid: "launch-1", level: :error, timestamp: timestamp,
      message: start_with("## \u2717 RuntimeError: api\\_key=SECRET123 failure")
    )
    expect(error.message).to eq(original_message)
    expect(error.backtrace).to eq(original_backtrace)
  end

  it "restores the exact v1.3.1 bytes when the card entry point raises" do
    allow(ReportportalCucumber::Presentation::FailureCard).to receive(:format).and_raise("SECRET123")
    formatter.send(:emit_error_log, item_uuid: "after-hook", error: error, timestamp: timestamp)
    expect(buffer).to have_received(:emit_log).once.with(
      item_uuid: "after-hook", launch_uuid: "launch-1", level: :error, timestamp: timestamp,
      message: original_message(error)
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
    it "makes zero redaction calls for a normal #{mode} failure emission" do
      formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new("rp.presentation" => mode))
      expect(Automation::EvidenceRedactor).not_to receive(:new)
      formatter.send(:emit_error_log, item_uuid: "step-1", error: error, timestamp: timestamp)
      expect(buffer).to have_received(:emit_log).with(hash_including(message: start_with("## \u2717 RuntimeError:")))
    end

    {
      f14_backslash: 'back\\slash',
      windows_path: 'No such file or directory @ rb_sysopen - C:\\logs\\failure.json',
      json_escaped_quote: 'HTTP 500 body: {"message":"a\\"b"}'
    }.each do |name, message|
      it "keeps the #{name} raw message and v1.3.1 tail in a #{mode} card" do
        formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new("rp.presentation" => mode))
        trace = ["C:\\project\\steps.rb:42:in 'work'", "/project/features/raw.feature:5", "", "support.rb:1\n"]
        failure = RuntimeError.new(message).tap { |exception| exception.set_backtrace(trace) }
        formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
        output = emissions.fetch(0).fetch(:message)
        expect(output).to start_with("## \u2717 RuntimeError: #{ReportportalCucumber::Presentation::MarkdownText.inline(message)}")
        expect(output).to include("```text\n#{trace.join("\n")}\n```")
        expect(output).not_to include("Message withheld")
      end
    end

    %i[eq_diff regex_match].each do |kind|
      it "preserves an actual RSpec #{kind} message and every frame in #{mode} mode" do
        formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new("rp.presentation" => mode))
        failure = assertion_failure do
          if kind == :eq_diff
            expect("first\nsecond").to eq("first\nchanged")
          else
            expect("ABC").to match(/\d+/)
          end
        end
        expect(failure.message).to include(kind == :eq_diff ? "Diff:" : '/\\d+/')
        formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
        output = emissions.fetch(0).fetch(:message)
        expect(output).to include("```text\n#{failure.message}\n```")
        expect(output).to include("```text\n#{failure.backtrace.join("\n")}\n```")
        expect(output).not_to include("Message withheld")
      end
    end
  end

  it "preserves Step failed for an empty non-exception failure" do
    failure = Struct.new(:message, :backtrace).new("", [])
    formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
    expect(buffer).to have_received(:emit_log).with(hash_including(message: "Step failed"))
  end

  it "preserves literal quotes rather than decoding a JSON empty string" do
    failure = RuntimeError.new('""')
    failure.set_backtrace([])
    formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
    expect(buffer).to have_received(:emit_log).with(hash_including(message: "## \u2717 RuntimeError: \"\""))
  end

  ["support.rb:1\nsupport.rb:2\n", ["support.rb:1", ["nested.rb:2", ""], nil]].each do |trace|
    it "retains the v1.3.1 join for a non-Exception backtrace #{trace.class}" do
      failure = Struct.new(:message, :backtrace).new("struct failure", trace)
      formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
      expect(emissions.fetch(0).fetch(:message)).to include("```text\n#{Array(trace).join("\n")}\n```")
    end
  end

  [nil, { backtrace: ["hash.rb:1", "hash.rb:2"] }, Struct.new(:message, :backtrace).new("", [])].each do |failure|
    it "falls back byte-for-byte for v1.3.1 #{failure.class} input" do
      allow(ReportportalCucumber::Presentation::FailureCard).to receive(:format).and_raise("presentation failure")
      formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
      expect(emissions.fetch(0).fetch(:message).b).to eq(original_message(failure).b)
    end
  end

  it "retains the exact baseline for an invalid-UTF-8 message" do
    failure = Struct.new(:message, :backtrace).new("failure \xff".b.force_encoding(Encoding::UTF_8), ["support.rb:1"])
    formatter.send(:emit_error_log, item_uuid: "step-1", error: failure, timestamp: timestamp)
    expect(emissions.fetch(0).fetch(:message).b).to eq(original_message(failure).b)
  end
end
