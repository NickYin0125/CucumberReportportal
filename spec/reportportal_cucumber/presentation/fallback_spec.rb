# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Presentation::Fallback do
  let(:logger) { double("logger", warn: nil) }
  before { allow(ReportportalCucumber).to receive(:logger).and_return(logger) }

  it "uses only the outer baseline and logs one constant warning for nested failures" do
    output = described_class.render(fallback: -> { "whole baseline" }) do
      described_class.render(fallback: -> { raise "must not use partial fallback" }) { raise "SECRET123" }
    end
    expect(output).to eq("whole baseline")
    expect(logger).to have_received(:warn).with(described_class::WARNING).once
    expect(Thread.current[described_class::ACTIVE_KEY]).to be_nil
  end

  it "does not rescue baseline failures or business work performed after rendering" do
    expect do
      described_class.render(fallback: -> { raise ArgumentError, "baseline" }) { raise "presentation" }
    end.to raise_error(ArgumentError, "baseline")
    expect do
      described_class.render(fallback: -> { "baseline" }) { "rendered" }
      raise RuntimeError, "business error"
    end.to raise_error(RuntimeError, "business error")
  end

  it "does not swallow non-StandardError exceptions, and always clears its state" do
    expect { described_class.render(fallback: -> { "baseline" }) { raise Interrupt } }.to raise_error(Interrupt)
    expect(Thread.current[described_class::ACTIVE_KEY]).to be_nil
    expect(logger).not_to have_received(:warn)
  end

  it "survives a broken warning sink without losing the original message" do
    allow(logger).to receive(:warn).and_raise("logger unavailable")
    expect(described_class.render(fallback: -> { "baseline" }) { raise "presentation" }).to eq("baseline")
  end

  it "warns per failed message rather than once per process" do
    2.times { described_class.render(fallback: -> { "baseline" }) { raise "presentation" } }
    expect(logger).to have_received(:warn).with(described_class::WARNING).twice
    expect(described_class.singleton_class.private_instance_methods(false)).to include(:warn)
    expect(described_class.respond_to?(:warn_once, true)).to be(false)
  end
end
