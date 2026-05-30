# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

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
      launch_description: "Formatter spec launch",
      launch_attributes: [{ "key" => "suite", "value" => "spec" }],
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
    expect(start_launch_body["description"]).to eq("Formatter spec launch")
    expect(start_launch_body["attributes"]).to eq([{ "key" => "suite", "value" => "spec" }])

    scenario_body = calls.find { |name, body| name == :start_scenario && body["hasStats"] == true }.last
    expect(scenario_body).to include(
      "name" => "Scenario: Login ok",
      "type" => "test",
      "codeRef" => "features/login.feature:12",
      "testCaseId" => "features/login.feature:12",
      "uniqueId" => ReportportalCucumber::ReportPortal::Models.build_unique_id(code_ref: "features/login.feature:12", parameters: nil)
    )
    start_suite_body = calls.find { |name, _body| name == :start_suite }.last
    start_step_body = calls.find { |name, _body| name == :start_step }.last
    expect(start_suite_body.fetch("startTime").to_i).to be < scenario_body.fetch("startTime").to_i
    expect(scenario_body.fetch("startTime").to_i).to be < start_step_body.fetch("startTime").to_i

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

  it "starts scenarios through the active feature child endpoint" do
    start_items = []
    start_item_counter = 0

    stub_request(:post, "https://rp.example.com/api/v1/demo/launch")
      .to_return(status: 200, body: '{"id":"launch-1"}')
    stub_request(:post, %r{\Ahttps://rp\.example\.com/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      start_item_counter += 1
      body = JSON.parse(request.body)
      start_items << { id: "item-#{start_item_counter}", body: body, path: request.uri.path }
      { status: 200, body: { id: "item-#{start_item_counter}" }.to_json }
    end
    stub_request(:put, %r{\Ahttps://rp\.example\.com/api/v1/demo/item/.*\z})
      .to_return(status: 200, body: '{"message":"ok"}')
    stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish")
      .to_return(status: 200, body: '{"message":"ok"}')

    formatter = described_class.new(stub_config)
    [
      { "type" => "test_run_started", "timestamp" => "2026-03-23T00:00:00Z" },
      { "type" => "test_suite_started", "feature_uri" => "features/nesting.feature", "timestamp" => "2026-03-23T00:00:01Z" },
      { "type" => "test_case_started", "feature_uri" => "features/nesting.feature", "scenario_name" => "Nested scenario", "scenario_line" => 11 },
      { "type" => "test_case_finished", "status" => "passed" },
      { "type" => "test_run_finished", "success" => true }
    ].each { |event| formatter.ingest_event(event) }

    expect(start_items[0]).to include(path: "/api/v1/demo/item")
    expect(start_items[0].fetch(:body)).to include("type" => "suite")
    expect(start_items[1]).to include(path: "/api/v1/demo/item/item-1")
    expect(start_items[1].fetch(:body)).to include("type" => "test")
    expect(start_items[1].fetch(:body)).to include("parentUuid" => "item-1")
  end

  it "labels background steps and maps before/after hooks under the scenario" do
    start_items = []
    start_item_counter = 0

    stub_request(:post, "https://rp.example.com/api/v1/demo/launch")
      .to_return(status: 200, body: '{"id":"launch-1"}')
    stub_request(:post, %r{\Ahttps://rp\.example\.com/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      start_item_counter += 1
      body = JSON.parse(request.body)
      start_items << { id: "item-#{start_item_counter}", body: body, path: request.uri.path }
      { status: 200, body: { id: "item-#{start_item_counter}" }.to_json }
    end
    stub_request(:put, %r{\Ahttps://rp\.example\.com/api/v1/demo/item/.*\z})
      .to_return(status: 200, body: '{"message":"ok"}')
    stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish")
      .to_return(status: 200, body: '{"message":"ok"}')

    formatter = described_class.new(stub_config)
    [
      { "type" => "test_run_started", "timestamp" => "2026-03-23T00:00:00Z" },
      { "type" => "test_case_started", "feature_uri" => "features/hooks.feature", "scenario_name" => "Hooked scenario", "scenario_line" => 3 },
      { "type" => "test_step_started", "step_id" => "before-1", "step_text" => "setup browser", "hook_type" => "before" },
      { "type" => "test_step_finished", "step_id" => "before-1", "status" => "passed" },
      { "type" => "test_step_started", "step_id" => "bg-1", "step_text" => "Given shared customer exists", "background" => true },
      { "type" => "test_step_finished", "step_id" => "bg-1", "status" => "passed" },
      { "type" => "test_step_started", "step_id" => "after-1", "step_text" => "close browser", "hook_type" => "after" },
      { "type" => "test_step_finished", "step_id" => "after-1", "status" => "passed" },
      { "type" => "test_case_finished", "status" => "passed" },
      { "type" => "test_run_finished", "success" => true }
    ].each { |event| formatter.ingest_event(event) }

    before_hook = start_items[2]
    background = start_items[3]
    after_hook = start_items[4]

    expect(before_hook).to include(path: "/api/v1/demo/item/item-2")
    expect(before_hook.fetch(:body)).to include("name" => "Before Hook: setup browser", "type" => "before_method", "hasStats" => false)
    expect(background).to include(path: "/api/v1/demo/item/item-2")
    expect(background.fetch(:body)).to include("name" => "[Background] Given shared customer exists", "type" => "step", "hasStats" => false)
    expect(after_hook).to include(path: "/api/v1/demo/item/item-2")
    expect(after_hook.fetch(:body)).to include("name" => "After Hook: close browser", "type" => "after_method", "hasStats" => false)
  end

  it "maps before_all and after_all hooks under the feature suite" do
    start_items = []
    start_item_counter = 0

    stub_request(:post, "https://rp.example.com/api/v1/demo/launch")
      .to_return(status: 200, body: '{"id":"launch-1"}')
    stub_request(:post, %r{\Ahttps://rp\.example\.com/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      start_item_counter += 1
      body = JSON.parse(request.body)
      start_items << { id: "item-#{start_item_counter}", body: body, path: request.uri.path }
      { status: 200, body: { id: "item-#{start_item_counter}" }.to_json }
    end
    stub_request(:put, %r{\Ahttps://rp\.example\.com/api/v1/demo/item/.*\z})
      .to_return(status: 200, body: '{"message":"ok"}')
    stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish")
      .to_return(status: 200, body: '{"message":"ok"}')

    formatter = described_class.new(stub_config)
    [
      { "type" => "test_run_started", "timestamp" => "2026-03-23T00:00:00Z" },
      { "type" => "test_suite_started", "feature_uri" => "features/class_hooks.feature" },
      { "type" => "test_step_started", "feature_uri" => "features/class_hooks.feature", "step_id" => "before-all", "step_text" => "seed database", "hook_type" => "before_all" },
      { "type" => "test_step_finished", "step_id" => "before-all", "status" => "passed" },
      { "type" => "test_case_started", "feature_uri" => "features/class_hooks.feature", "scenario_name" => "Class hook scenario", "scenario_line" => 8 },
      { "type" => "test_case_finished", "status" => "passed" },
      { "type" => "test_step_started", "feature_uri" => "features/class_hooks.feature", "step_id" => "after-all", "step_text" => "drop database", "hook_type" => "after_all" },
      { "type" => "test_step_finished", "step_id" => "after-all", "status" => "passed" },
      { "type" => "test_run_finished", "success" => true }
    ].each { |event| formatter.ingest_event(event) }

    before_all = start_items[1]
    scenario = start_items[2]
    after_all = start_items[3]

    expect(before_all).to include(path: "/api/v1/demo/item/item-1")
    expect(before_all.fetch(:body)).to include("name" => "BeforeAll Hook: seed database", "type" => "before_class", "hasStats" => false)
    expect(scenario).to include(path: "/api/v1/demo/item/item-1")
    expect(scenario.fetch(:body)).to include("name" => "Scenario: Class hook scenario", "type" => "test", "hasStats" => true)
    expect(after_all).to include(path: "/api/v1/demo/item/item-1")
    expect(after_all.fetch(:body)).to include("name" => "AfterAll Hook: drop database", "type" => "after_class", "hasStats" => false)
  end

  it "closes open steps and scenarios before feature and launch when run finishes early" do
    calls = []
    start_item_counter = 0

    stub_request(:post, "https://rp.example.com/api/v1/demo/launch").to_return do |request|
      calls << [:start_launch, JSON.parse(request.body)]
      { status: 200, body: '{"id":"launch-1"}' }
    end
    stub_request(:post, %r{\Ahttps://rp\.example\.com/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      start_item_counter += 1
      body = JSON.parse(request.body)
      calls << [:start_item, "item-#{start_item_counter}", body]
      { status: 200, body: { id: "item-#{start_item_counter}" }.to_json }
    end
    stub_request(:put, %r{\Ahttps://rp\.example\.com/api/v1/demo/item/.*\z}).to_return do |request|
      calls << [:finish_item, request.uri.path.split("/").last, JSON.parse(request.body)]
      { status: 200, body: '{"message":"ok"}' }
    end
    stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish").to_return do |request|
      calls << [:finish_launch, JSON.parse(request.body)]
      { status: 200, body: '{"message":"ok"}' }
    end

    formatter = described_class.new(stub_config)
    [
      { "type" => "test_run_started", "timestamp" => "2026-03-23T00:00:00Z" },
      { "type" => "test_case_started", "feature_uri" => "features/interrupted.feature", "scenario_name" => "Interrupted", "scenario_line" => 9 },
      { "type" => "test_step_started", "step_text" => "When the process stops", "step_id" => "s1", "hook" => false },
      { "type" => "test_run_finished", "success" => false }
    ].each { |event| formatter.ingest_event(event) }

    expect(calls.map(&:first)).to eq([
      :start_launch,
      :start_item,
      :start_item,
      :start_item,
      :finish_item,
      :finish_item,
      :finish_item,
      :finish_launch
    ])
    finished_items = calls.select { |name, _id, _body| name == :finish_item }
    expect(finished_items.map { |_name, id, _body| id }).to eq(%w[item-3 item-2 item-1])
    expect(finished_items.map { |_name, _id, body| body["status"] }).to eq(%w[failed failed failed])
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

  it "derives outline parameters and stable scenario line from example rows" do
    formatter = described_class.new(stub_config)

    Dir.mktmpdir do |dir|
      feature_path = File.join(dir, "outline.feature")
      File.write(feature_path, <<~FEATURE)
        Feature: Outline verification
          Scenario Outline: Stable test case id
            Given user <user> pays <amount>

            Examples:
              | user  | amount |
              | alice | 10     |
              | bob   | 20     |
      FEATURE

      metadata = formatter.send(:parse_outline_metadata, feature_path, 7)

      expect(metadata).to eq(
        scenario_line: 2,
        parameters: {
          "user" => "alice",
          "amount" => "10"
        }
      )
    end
  end

  it "binds world attachments to the active step item" do
    log_buffer = instance_double(ReportportalCucumber::Runtime::LogBuffer, emit_log: nil, flush: true, shutdown: true)
    allow(ReportportalCucumber::Runtime::LogBuffer).to receive(:new).and_return(log_buffer)

    formatter = described_class.new(stub_config)
    feature = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "feature-1", kind: :feature, name: "Feature", type: "suite", has_stats: false)
    scenario = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "scenario-1", kind: :scenario, name: "Scenario", parent_uuid: "feature-1", type: "test", has_stats: true)
    step = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "step-1", kind: :step, name: "When upload", parent_uuid: "scenario-1", type: "step", has_stats: false)

    formatter.runtime_context.register_feature("features/a.feature", feature)
    formatter.runtime_context.activate_feature("features/a.feature", feature)
    formatter.runtime_context.start_scenario("features/a.feature:1:uniq", scenario)
    formatter.runtime_context.push_step(step)

    formatter.emit_world_attachment(
      message: "Failure screenshot",
      level: :info,
      timestamp: Time.utc(2026, 3, 26, 12, 0, 0),
      attachment: {
        name: "error.png",
        mime: "image/png",
        bytes: "png-bytes"
      }
    )

    expect(log_buffer).to have_received(:emit_log).with(hash_including(item_uuid: "step-1", attachment: hash_including(name: "error.png")))
    formatter.instance_variable_set(:@finalized, true)
  end

  it "binds native Cucumber attach calls to the active step item" do
    log_buffer = instance_double(ReportportalCucumber::Runtime::LogBuffer, emit_log: nil, flush: true, shutdown: true)
    allow(ReportportalCucumber::Runtime::LogBuffer).to receive(:new).and_return(log_buffer)

    formatter = described_class.new(stub_config)
    scenario = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "scenario-1", kind: :scenario, name: "Scenario", type: "test", has_stats: true)
    step = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "step-1", kind: :step, name: "When upload", parent_uuid: "scenario-1", type: "step", has_stats: false)

    formatter.runtime_context.start_scenario("features/a.feature:1:uniq", scenario)
    formatter.runtime_context.push_step(step)
    formatter.attach("hello", "text/plain", "native.txt")

    expect(formatter).to respond_to(:attach)
    expect(log_buffer).to have_received(:emit_log).with(
      hash_including(
        item_uuid: "step-1",
        message: "Attachment: native.txt",
        attachment: hash_including(name: "native.txt", mime: "text/plain", bytes: "hello")
      )
    )
    formatter.instance_variable_set(:@finalized, true)
  end

  it "flushes manual step logs before finishing the manual step item" do
    api = instance_double(ReportportalCucumber::ReportPortal::API)
    log_buffer = instance_double(ReportportalCucumber::Runtime::LogBuffer)
    call_order = []

    allow(ReportportalCucumber::Runtime::LogBuffer).to receive(:new).and_return(log_buffer)
    allow(log_buffer).to receive(:emit_log) { call_order << :emit_log }
    allow(log_buffer).to receive(:flush) { call_order << :flush_before_finish; true }
    allow(log_buffer).to receive(:shutdown).and_return(true)
    allow(api).to receive(:start_item).and_return("manual-uuid")
    allow(api).to receive(:finish_item) { call_order << :finish_item }

    formatter = described_class.new(stub_config)
    formatter.instance_variable_set(:@api, api)
    formatter.instance_variable_set(:@launch_uuid, "launch-uuid")
    scenario = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "scenario-1", kind: :scenario, name: "Scenario", type: "test", has_stats: true)
    formatter.runtime_context.start_scenario("features/a.feature:1:uniq", scenario)

    formatter.with_manual_step("Manual group") do
      formatter.emit_world_log(message: "inside", level: :info, timestamp: Time.utc(2026, 5, 30))
    end

    expect(call_order).to eq(%i[emit_log flush_before_finish finish_item])
    formatter.instance_variable_set(:@finalized, true)
  end
end
