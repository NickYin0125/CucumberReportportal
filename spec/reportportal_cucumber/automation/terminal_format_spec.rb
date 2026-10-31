# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe "AppLog terminal presentation" do
  let(:output) { StringIO.new }
  let(:now) { Time.new(2026, 10, 14, 14, 32, Rational(8125, 1000), "+08:00") }
  let(:logger) { Automation::CucumberLogger.new(output: output, color: false) }

  before { allow(Time).to receive(:now).and_return(now) }

  Automation::CucumberLogger::LEVELS.each do |level|
    it "prints local date, milliseconds and an aligned #{level} level without a source prefix" do
      logger.public_send(level, "Order submitted")

      expect(output.string).to eq("2026-10-14 14:32:08.125  #{level.to_s.upcase.ljust(5)}  Order submitted\n")
      expect(output.string).not_to include("[APPLOG]", "+08:00", "\e[")
    end
  end

  it "samples the time for each output instead of keeping the logger creation time" do
    later = Time.new(2026, 10, 15, 0, 0, Rational(7, 1000), "+08:00")
    allow(Time).to receive(:now).and_return(now, later)

    logger.info("First event")
    logger.warn("Next day")

    expect(output.string.lines).to eq([
      "2026-10-14 14:32:08.125  INFO   First event\n",
      "2026-10-15 00:00:00.007  WARN   Next day\n"
    ])
  end

  Automation::CucumberLogger::LEVEL_COLORS.each do |level, color|
    it "preserves the ANSI color and reset for #{level}" do
      colored = Automation::CucumberLogger.new(output: output, color: true)
      colored.public_send(level, "Colored event")

      expect(output.string).to eq("\e[#{color}m2026-10-14 14:32:08.125  #{level.to_s.upcase.ljust(5)}  Colored event\e[0m\n")
    end
  end

  it "automatically enables colors on a TTY" do
    allow(output).to receive(:tty?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("NO_COLOR").and_return(nil)

    Automation::CucumberLogger.new(output: output).info("TTY event")

    expect(output.string).to start_with("\e[36m2026-10-14")
    expect(output.string).to end_with("\e[0m\n")
  end

  it "keeps NO_COLOR output readable on a TTY" do
    allow(output).to receive(:tty?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("NO_COLOR").and_return("1")

    Automation::CucumberLogger.new(output: output).info("Plain event")

    expect(output.string).to eq("2026-10-14 14:32:08.125  INFO   Plain event\n")
  end

  it "does not emit ANSI escapes to redirected output" do
    Automation::CucumberLogger.new(output: output).info("Redirected event")

    expect(output.string).to eq("2026-10-14 14:32:08.125  INFO   Redirected event\n")
  end

  it "keeps messages on one line and JSON out of the terminal summary" do
    logger.debug("Order\nresponse", json: { secret_payload: "not-for-terminal" }, file: "tmp/order.json")

    expect(output.string).to eq("2026-10-14 14:32:08.125  DEBUG  Order response (file: order.json) (json payload)\n")
    expect(output.string).not_to include("secret_payload", "not-for-terminal")
  end

  it "does not add the terminal timestamp or level padding to report messages" do
    native = []
    rp = []
    world = Object.new
    world.define_singleton_method(:log) { |message| native << message }
    world.define_singleton_method(:rp_active?) { true }
    world.define_singleton_method(:rp_log) { |message, **options| rp << [message, options] }
    bound = Automation::CucumberLogger.new(world: world, output: output, color: false)

    AppLog.with_logger(bound) { AppLog.info("Order response", report: true, json: { status: "ok" }) }

    expected = "Order response\n\n```json\n#{JSON.pretty_generate(status: 'ok')}\n```"
    expect(native).to eq([expected])
    expect(rp).to eq([[expected, { level: :info, mirror: false }]])
    expect(output.string).to eq("2026-10-14 14:32:08.125  INFO   Order response (Attached to Report) (json payload)\n")
  end

  it "uses the same presentation for HTTP and assertion summaries" do
    logger.http(method: :get, url: "https://example.test/orders", response: { status: 200 }, report: false)
    logger.assertion(name: "status matches", expected: 200, actual: 200, passed: true, report: false)

    expect(output.string.lines.length).to eq(2)
    expect(output.string.lines).to all(start_with("2026-10-14 14:32:08.125  INFO   "))
    expect(output.string).not_to include("[APPLOG]", "```")
  end

  it "timestamps routing warnings while preserving fail-safe delivery" do
    world = Object.new
    world.define_singleton_method(:log) { |_message| raise "native routing unavailable" }
    bound = Automation::CucumberLogger.new(world: world, output: output, color: false)

    expect { bound.info("Order response", report: true) }.not_to raise_error

    expect(output.string.lines.last).to eq(
      "2026-10-14 14:32:08.125  WARN   world_log routing failed: RuntimeError: native routing unavailable\n"
    )
  end
end
