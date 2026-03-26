# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Cucumber::Formatter do
  FakeConfig = Struct.new(:handlers) do
    def on_event(name, &block)
      handlers[name] = block
    end

    def include(_mod); end
  end

  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp.example.com",
      project: "demo",
      api_key: "token",
      launch: "Demo launch",
      batch_size_logs: 2,
      flush_interval: 0.1,
      retry_attempts: 1,
      join: false
    )
  end

  let(:stub_config) { FakeConfig.new({}) }

  before do
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
  end

  it "maps NDJSON fixture events to the expected ReportPortal call sequence" do
    calls = []
    start_item_counter = 0

    stub_request(:post, "https://rp.example.com/api/v1/demo/launch").to_return do |request|
      calls << [:start_launch, JSON.parse(request.body)]
      { status: 200, body: '{"id":"launch-1"}' }
    end

    stub_request(:post, %r{\Ahttps://rp\.example\.com/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      start_item_counter += 1
      body = JSON.parse(request.body)
      type =
        case start_item_counter
        when 1 then :start_suite
        when 2 then :start_scenario
        else :start_step
        end
      calls << [type, body]
      { status: 200, body: { id: "item-#{start_item_counter}" }.to_json }
    end

    stub_request(:post, "https://rp.example.com/api/v1/demo/log").to_return do |request|
      calls << [:log_batch, request.body]
      { status: 200, body: '{"responses":[{"message":"ok"}]}' }
    end

    stub_request(:put, %r{\Ahttps://rp\.example\.com/api/v1/demo/item/.*\z}).to_return do |request|
      calls << [:finish_item, JSON.parse(request.body)]
      { status: 200, body: '{"message":"ok"}' }
    end

    stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish").to_return do |request|
      calls << [:finish_launch, JSON.parse(request.body)]
      { status: 200, body: '{"message":"ok"}' }
    end

    formatter = described_class.new(stub_config)
    File.readlines(File.join(__dir__, "..", "..", "fixtures", "events.ndjson"), chomp: true).each do |line|
      formatter.ingest_event(JSON.parse(line))
    end

    sequence = calls.map(&:first)

    expect(sequence).to eq([
      :start_launch,
      :start_suite,
      :start_scenario,
      :start_step,
      :log_batch,
      :finish_item,
      :finish_item,
      :finish_item,
      :finish_launch
    ])

    start_launch_body = calls.find { |name, _| name == :start_launch }.last
    expect(start_launch_body["name"]).to eq("Demo launch")
    expect(start_launch_body["startTime"]).to match(/\A\d+\z/)

    scenario_body = calls.find { |name, body| name == :start_scenario && body["hasStats"] == true }.last
    expect(scenario_body).to include(
      "name" => "Scenario: Login ok",
      "type" => "step",
      "codeRef" => "features/login.feature:12",
      "testCaseId" => "features/login.feature:12",
      "uniqueId" => ReportportalCucumber::ReportPortal::Models.build_unique_id(code_ref: "features/login.feature:12", parameters: nil)
    )

    log_body = calls.find { |name, _| name == :log_batch }.last
    expect(log_body).to include("json_request_part")
    expect(log_body).to include("shot.png")
  end

  it "emits failed status and error logs for failing steps" do
    stub_request(:post, "https://rp.example.com/api/v1/demo/launch")
      .to_return(status: 200, body: '{"id":"launch-1"}')
    stub_request(:post, %r{\Ahttps://rp\.example\.com/api/v1/demo/item(?:/.*)?\z})
      .to_return(status: 200, body: '{"id":"item-1"}')

    recorded_logs = []
    stub_request(:post, "https://rp.example.com/api/v1/demo/log").to_return do |request|
      recorded_logs << request.body
      { status: 200, body: '{"responses":[{"message":"ok"}]}' }
    end

    finished_items = []
    stub_request(:put, %r{\Ahttps://rp\.example\.com/api/v1/demo/item/.*\z}).to_return do |request|
      finished_items << JSON.parse(request.body)
      { status: 200, body: '{"message":"ok"}' }
    end
    stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish")
      .to_return(status: 200, body: '{"message":"ok"}')

    formatter = described_class.new(stub_config)
    [
      { "type" => "test_run_started", "timestamp" => "2026-03-23T00:00:00Z" },
      { "type" => "test_case_started", "feature_uri" => "features/login.feature", "scenario_name" => "Login bad", "scenario_line" => 7 },
      { "type" => "test_step_started", "step_text" => "When credentials are wrong", "step_id" => "s1", "hook" => false },
      { "type" => "test_step_finished", "step_id" => "s1", "status" => "failed", "message" => "Boom", "backtrace" => ["a.rb:1"] },
      { "type" => "test_case_finished", "scenario_name" => "Login bad", "status" => "failed" },
      { "type" => "test_run_finished", "success" => false }
    ].each { |event| formatter.ingest_event(event) }

    expect(recorded_logs.join).to include("Boom")
    expect(recorded_logs.join).to include("a.rb:1")
    expect(finished_items.map { |body| body["status"] }).to include("failed")
  end

  it "includes rerun flags in the launch start payload" do
    rerun_config = ReportportalCucumber::Config.new(
      endpoint: "https://rp.example.com",
      project: "demo",
      api_key: "token",
      rerun: true,
      rerun_of: "prev-launch",
      join: false
    )
    allow(ReportportalCucumber::Config).to receive(:load).and_return(rerun_config)

    payloads = []
    stub_request(:post, "https://rp.example.com/api/v1/demo/launch").to_return do |request|
      payloads << JSON.parse(request.body)
      { status: 200, body: '{"id":"launch-1"}' }
    end
    stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish")
      .to_return(status: 200, body: '{"message":"ok"}')

    formatter = described_class.new(stub_config)
    formatter.ingest_event("type" => "test_run_started", "timestamp" => "2026-03-23T00:00:00Z")
    formatter.ingest_event("type" => "test_run_finished", "success" => true)

    expect(payloads.first).to include("rerun" => true, "rerunOf" => "prev-launch")
  end
end
