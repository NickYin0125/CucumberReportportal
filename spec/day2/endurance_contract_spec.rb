# frozen_string_literal: true

require "spec_helper"
require "rack/mock"
require "stringio"
require_relative "../../features/support/clearing_mock_server"
require_relative "../../examples/day2_endurance/support"

# Do not leave singleton DSL stubs behind for native CLI examples in this process.
main_singleton = singleton_class
names = %i[Given When Then World]
originals = names.to_h do |name|
  direct = main_singleton.instance_methods(false) + main_singleton.private_instance_methods(false)
  [name, direct.include?(name) ? main_singleton.instance_method(name) : nil]
end
begin
  names.each { |name| main_singleton.define_method(name) { |*| nil } }
  require_relative "../../features/step_definitions/duration_pbt_steps"
  require_relative "../../features/step_definitions/duration_workflow_steps"
ensure
  originals.each do |name, original|
    original ? main_singleton.define_method(name, original) : main_singleton.remove_method(name)
  end
end

RSpec.describe "Day2 endurance contracts" do
  let(:app) { Rack::MockRequest.new(ClearingMockServer::App) }
  let(:trade) { { trade_id: "seed-1", currency: "USD", counterparty: "BANK", notional: 12_500 } }

  around do |example|
    saved = ENV.to_h
    ENV["CLEARING_MOCK_DISABLE_CHAOS"] = "true"
    ENV["CLEARING_MOCK_LATENCY_SCALE"] = "0"
    ClearingMockServer::App.reset!
    AppLog.with_logger(Automation::CucumberLogger.new(output: StringIO.new)) { example.run }
  ensure
    ENV.replace(saved)
    Day2Endurance.session = nil
    Day2Endurance.formatter = nil
  end

  def post(path, payload)
    app.post(path, "CONTENT_TYPE" => "application/json", input: JSON.generate(payload))
  end

  it "does not autostart based on feature arguments" do
    ENV.delete("CLEARING_MOCK_AUTOSTART")
    expect(ClearingMockServer.autostart?).to be(false)
  end

  it "requires explicit opt-in and honors disable" do
    ENV["CLEARING_MOCK_AUTOSTART"] = "true"
    ENV["CLEARING_MOCK_DISABLED"] = "false"
    expect(ClearingMockServer.autostart?).to be(true)
    ENV["CLEARING_MOCK_DISABLED"] = "true"
    expect(ClearingMockServer.autostart?).to be(false)
  end

  [nil, [], 7, "text"].each do |value|
    it "rejects non-object JSON #{value.inspect}" do
      expect(post("/api/v1/trades/ingest", value).status).to eq(400)
    end
  end

  it "rejects malformed JSON" do
    expect(app.post("/api/v1/clearing/validate", input: "{").status).to eq(400)
  end

  [0, -1, "123", nil].each do |amount|
    it "rejects invalid notional #{amount.inspect}" do
      result = post("/api/v1/clearing/validate", trade.merge(notional: amount))
      expect(result.status).to eq(400)
      expect(JSON.parse(result.body).fetch("violations")).to include("notional must be positive")
    end
  end

  it "validates every trade rather than only the first" do
    expect(post("/api/v1/trades/ingest", trades: [trade, trade.merge(counterparty: "")]).status).to eq(400)
  end

  it "accepts a valid batch with its original identity" do
    result = post("/api/v1/trades/ingest", batch_id: "original", trades: [trade])
    expect(result.status).to eq(202)
    expect(JSON.parse(result.body)).to include("batch_id" => "original", "status" => "ACCEPTED")
  end

  it "nets large integers without Float loss" do
    value = 10**36
    result = post("/api/v1/clearing/netting", trades: [{ direction: "PAY", notional: value }, { direction: "RECEIVE", notional: value + 1 }])
    expect(JSON.parse(result.body).fetch("net_notional")).to eq(1)
  end

  [0, 1, 10_000, 12_345, 10**36].each do |amount|
    it "agrees with the decimal margin oracle for #{amount}" do
      payload = { positions: [{ netNotional: amount }] }
      result = post("/api/v1/margin/calculate", payload)
      expect(Day2Endurance.check_margin(payload, JSON.parse(result.body))).to be(true)
    end
  end

  it "does not let a 2xx response conceal wrong arithmetic" do
    expect { Day2Endurance.check_margin({ positions: [{ notional: 50_000 }] }, { "total_margin" => 1000 }) }.to raise_error(Day2Endurance::InvariantError)
  end

  it "progresses settlement state monotonically and keeps its ledger" do
    rows = 4.times.map { JSON.parse(app.get("/api/v1/settlement/batch/b1").body) }
    expect(rows.map { |row| row.fetch("status") }).to eq(%w[PENDING PROCESSING COMPLETED COMPLETED])
    expect(rows.last.fetch("ledger_reference")).not_to be_empty
    expect(rows.last.fetch("ledger_reference")).to eq(rows[-2].fetch("ledger_reference"))
  end

  it "reproduces full boundary JSON from the same seed" do
    first, second = 2.times.map { DurationPbt::TradeGenerator.new(seed: 42) }
    expect(20.times.map { |index| first.trade_payload(iteration: index) }).to eq(20.times.map { |index| second.trade_payload(iteration: index) })
  end

  it "changes generated input with a different seed" do
    expect(DurationPbt::TradeGenerator.new(seed: 41).trade_payload(iteration: 1)).not_to eq(DurationPbt::TradeGenerator.new(seed: 42).trade_payload(iteration: 1))
  end

  it "reproduces interleaved ingest and margin request pairs" do
    runs = 2.times.map do
      generator = DurationPbt::TradeGenerator.new(seed: 77)
      12.times.map do |iteration|
        payload = generator.trade_payload(iteration: iteration)
        [payload, generator.margin_payload_for(payload, iteration: iteration)]
      end
    end
    expect(runs.first).to eq(runs.last)
  end

  it "checks 500 randomized boundary cases through the Rack HTTP contracts" do
    generator = DurationPbt::TradeGenerator.new(seed: 20261013)
    500.times do |iteration|
      payload = generator.trade_payload(iteration: iteration)
      expect(JSON.parse(JSON.generate(payload))).to eq(Day2Endurance.json_value(payload))
      valid = !payload[:counterparty].strip.empty? && payload[:notional].positive?
      expect(post("/api/v1/trades/ingest", payload).status).to eq(valid ? 202 : 400)
      margin = generator.margin_payload_for(payload, iteration: iteration)
      expect(Day2Endurance.check_margin(margin, JSON.parse(post("/api/v1/margin/calculate", margin).body))).to be(true)
    end
  end

  [499, 1001].each do |count|
    it "refuses non-acceptance iteration count #{count}" do
      ENV["DURATION_REGRESSION_SMOKE"] = "false"
      ENV["DURATION_REGRESSION_ITERATIONS"] = count.to_s
      expect { DurationPbt.configured_iterations }.to raise_error(ArgumentError)
    end
  end

  it "bounds smoke iterations" do
    ENV["DURATION_REGRESSION_SMOKE"] = "true"
    ENV["DURATION_REGRESSION_ITERATIONS"] = "1000"
    expect(DurationPbt.configured_iterations).to eq(25)
  end

  it "fails a completed workflow with the wrong batch identity" do
    client = double(get_json: { status: "COMPLETED", batch_id: "other", ledger_reference: "L" })
    expect { DurationWorkflow::SettlementPoller.new(client: client, smoke: true).wait_until_completed("original") }.to raise_error(Day2Endurance::InvariantError, "settlement batch identity")
  end

  it "fails terminal settlement failures" do
    client = double(get_json: { status: "FAILED", batch_id: "original" })
    expect { DurationWorkflow::SettlementPoller.new(client: client, smoke: true).wait_until_completed("original") }.to raise_error(/ended in FAILED/)
  end

  it "reads CSV quoting, escaped quotes and embedded newlines" do
    expect(Day2Endurance.csv_rows("a,b\n\"one, two\",\"line\n\"\"quote\"\"\"\n")).to eq([["a", "b"], ["one, two", "line\n\"quote\""]])
  end
end
