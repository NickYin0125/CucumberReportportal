# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "cucumber/hooks"
require "cucumber/core/test/hook_step"
require "cucumber/events"
require "cucumber/core/event_bus"
require "cucumber/core"

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

  context "with native compiled combined-argument tables" do
    let(:bus) { Cucumber::Events.make_event_bus }
    let(:native_config) do
      double("native event configuration", event_bus: bus).tap do |value|
        allow(value).to receive(:on_event) { |id, &handler| bus.on(id, &handler) }
      end
    end

    def compile_combined_arguments
      events = []
      bus.on(:test_step_created) { |event| events << event }
      feature = <<~FEATURE
        Feature: Compiled arguments
          Scenario Outline: Display
            Given combined display
              """text
              COMBINED_DOCUMENT
              """
              | combined | <value> |
            And ordinary document
              """text
              DOCUMENT_ONLY
              """
            And ordinary table
              | table | <value> |
            Examples:
              | other | value |
              | must not expand twice | <other> |
              | unused | TABLE_ONLY_BIRCH |
      FEATURE
      receiver = double("compiler receiver", test_case: nil, done: nil)
      Object.new.extend(Cucumber::Core).compile(
        [Cucumber::Core::Gherkin::Document.new("combined.feature", feature)], receiver, [], bus
      )
      events
    end

    %i[before after].each do |subscription|
      it "retains only needed table references with subscription #{subscription} compilation, including retry clones" do
        formatter = described_class.new(native_config) if subscription == :before
        events = compile_combined_arguments
        formatter ||= described_class.new(native_config)
        tables = formatter.instance_variable_get(:@combined_step_tables)
        combined = events.select { |event| event.pickle_step.argument.doc_string && event.pickle_step.argument.data_table }

        expect(tables.keys).to match_array(combined.map { |event| event.test_step.id })
        combined.zip(["&lt;other&gt;", "TABLE_ONLY_BIRCH"]).each do |event, expected|
          expect(tables.fetch(event.test_step.id)).to equal(event.pickle_step.argument.data_table)
          2.times do
            retried = event.test_step.with_action {}
            result = formatter.send(:build_step_descriptor, test_step: retried)
            expect(result.to_markdown).to include("| combined | #{expected} |", "COMBINED_DOCUMENT")
            expect(result.to_markdown).not_to include("must not expand twice")
          end
        end
        expect(tables.size).to eq(2)
        bus.test_run_finished(true)
        expect(tables).to be_empty
        Thread.new { combined.each { |event| bus.test_step_created(event.test_step, event.pickle_step) } }.value
        expect(tables).to be_empty
      ensure
        formatter&.ingest_event(type: "test_run_finished", success: true)
      end
    end

    it "keeps disabled formatters from retaining compiled tables" do
      allow(config).to receive(:enabled?).and_return(false)
      formatter = described_class.new(native_config)
      compile_combined_arguments

      expect(formatter.instance_variable_get(:@combined_step_tables)).to be_empty
      bus.test_run_finished(true)
      expect(formatter.instance_variable_get(:@combined_step_tables)).to be_empty
    end

    it "clears table references even when final reporting enforcement raises" do
      formatter = described_class.new(native_config)
      compile_combined_arguments
      allow(formatter).to receive(:enforce_complete_reporting).and_raise(ReportportalCucumber::ReportingError, "test refusal")

      expect { bus.test_run_finished(true) }.to raise_error(ReportportalCucumber::ReportingError, "test refusal")
      expect(formatter.instance_variable_get(:@combined_step_tables)).to be_empty
    ensure
      formatter&.ingest_event(type: "test_run_finished", success: true)
    end
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

    suite_body = calls.find { |name, _body| name == :start_suite }.last
    scenario_body = calls.find { |name, body| name == :start_scenario && body["hasStats"] == true }.last
    step_body = calls.find { |name, _body| name == :start_step }.last
    expect(suite_body).to include("type" => "SUITE", "hasStats" => true)
    expect(scenario_body).to include(
      "name" => "Scenario: Login ok",
      "type" => "STEP",
      "hasStats" => true,
      "parentUuid" => "item-1",
      "codeRef" => "features/login.feature:12",
      "testCaseId" => "features/login.feature:12",
      "uniqueId" => ReportportalCucumber::ReportPortal::Models.build_unique_id(code_ref: "features/login.feature:12", parameters: nil)
    )
    expect(step_body).to include("type" => "STEP", "hasStats" => false, "parentUuid" => "item-2")
    expect(suite_body.fetch("startTime").to_i).to be < scenario_body.fetch("startTime").to_i
    expect(scenario_body.fetch("startTime").to_i).to be < step_body.fetch("startTime").to_i

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
    expect(start_items[0].fetch(:body)).to include("type" => "SUITE", "hasStats" => true)
    expect(start_items[1]).to include(path: "/api/v1/demo/item/item-1")
    expect(start_items[1].fetch(:body)).to include("type" => "STEP", "hasStats" => true, "parentUuid" => "item-1")
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
    expect(before_hook.fetch(:body)).to include("name" => "Before Hook: setup browser", "type" => "BEFORE_METHOD", "hasStats" => false)
    expect(background).to include(path: "/api/v1/demo/item/item-2")
    expect(background.fetch(:body)).to include("name" => "[Background] Given shared customer exists", "type" => "STEP", "hasStats" => false)
    expect(after_hook).to include(path: "/api/v1/demo/item/item-2")
    expect(after_hook.fetch(:body)).to include("name" => "After Hook: close browser", "type" => "AFTER_METHOD", "hasStats" => false)
  end

  context "with real Cucumber HookStep events" do
    let(:native_start_items) { [] }
    let(:native_formatter) { described_class.new(stub_config) }

    before do
      counter = 0
      stub_request(:post, "https://rp.example.com/api/v1/demo/launch")
        .to_return(status: 200, body: '{"id":"launch-1"}')
      stub_request(:post, %r{\Ahttps://rp\.example\.com/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
        counter += 1
        native_start_items << { path: request.uri.path, body: JSON.parse(request.body) }
        { status: 200, body: { id: "item-#{counter}" }.to_json }
      end
      stub_request(:put, %r{\Ahttps://rp\.example\.com/api/v1/demo/item/.*\z})
        .to_return(status: 200, body: '{"message":"ok"}')
      stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish")
        .to_return(status: 200, body: '{"message":"ok"}')
      native_formatter.ingest_event("type" => "test_run_started")
      native_formatter.ingest_event("type" => "test_case_started", "feature_uri" => "features/native-hooks.feature",
                                    "scenario_name" => "Native hooks", "scenario_line" => 3)
    end

    after do
      native_formatter.ingest_event("type" => "test_step_finished", "status" => "passed")
      native_formatter.ingest_event("type" => "test_case_finished", "status" => "passed")
      native_formatter.ingest_event("type" => "test_run_finished", "success" => true)
    end

    { before: "BEFORE_METHOD", after: "AFTER_METHOD" }.each do |kind, rp_type|
      it "maps the installed #{kind} HookStep to #{rp_type} under the Scenario" do
        location = ::Cucumber::Core::Test::Location.new("features/support/hooks.rb", 10)
        step = ::Cucumber::Hooks.public_send("#{kind}_hook", "native-#{kind}", location) {}
        expect(step).to be_a(::Cucumber::Core::Test::HookStep)
        expect(step.hook?).to eq(true)
        expect(step.respond_to?(:hook_type)).to eq(false)

        event = ::Cucumber::Events.registry.fetch(:test_step_started).new(step)
        expect(event.test_step).to equal(step)
        stub_config.handlers.fetch(:test_step_started).call(event)

        expect(native_start_items.last).to include(path: "/api/v1/demo/item/item-2")
        expect(native_start_items.last.fetch(:body)).to include("type" => rp_type, "hasStats" => false, "parentUuid" => "item-2")
      end
    end

    it "keeps a real nonhook Gherkin Step named After as STEP" do
      location = ::Cucumber::Core::Test::Location.new("features/native-hooks.feature", 4)
      step = ::Cucumber::Core::Test::Step.new("gherkin-after", "After a normal operation", location)
      expect(step.hook?).to eq(false)

      event = ::Cucumber::Events.registry.fetch(:test_step_started).new(step)
      expect(event.test_step).to equal(step)
      stub_config.handlers.fetch(:test_step_started).call(event)

      expect(native_start_items.last.fetch(:body)).to include("type" => "STEP", "hasStats" => false,
                                                            "parentUuid" => "item-2", "name" => "After a normal operation")
    end
  end

  it "detects background steps from the feature file when Cucumber events do not flag them" do
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

    Dir.mktmpdir do |directory|
      feature_path = File.join(directory, "background.feature")
      File.write(feature_path, <<~FEATURE)
        Feature: Background fallback
          Background:
            Given shared customer exists

          Scenario: Uses background
            Then the scenario passes
      FEATURE

      formatter = described_class.new(stub_config)
      [
        { "type" => "test_run_started", "timestamp" => "2026-03-23T00:00:00Z" },
        { "type" => "test_case_started", "feature_uri" => feature_path, "scenario_name" => "Uses background", "scenario_line" => 5 },
        { "type" => "test_step_started", "step_id" => "bg-1", "step_text" => "Given shared customer exists" },
        { "type" => "test_step_finished", "step_id" => "bg-1", "status" => "passed" },
        { "type" => "test_case_finished", "status" => "passed" },
        { "type" => "test_run_finished", "success" => true }
      ].each { |event| formatter.ingest_event(event) }
    end

    background = start_items.find { |item| item.fetch(:body)["name"].include?("shared customer exists") }
    expect(background.fetch(:body)).to include("name" => "[Background] Given shared customer exists", "type" => "STEP", "hasStats" => false)
  end

  it "always starts Cucumber steps under the scenario even if another step is still active" do
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

    formatter = described_class.new(stub_config)
    [
      { "type" => "test_run_started", "timestamp" => "2026-03-23T00:00:00Z" },
      { "type" => "test_case_started", "feature_uri" => "features/stale.feature", "scenario_name" => "Stale active step", "scenario_line" => 3 },
      { "type" => "test_step_started", "step_id" => "s1", "step_text" => "Given first step is still active" },
      { "type" => "test_step_started", "step_id" => "s2", "step_text" => "When second step starts" }
    ].each { |event| formatter.ingest_event(event) }

    first_step = start_items[2]
    second_step = start_items[3]

    expect(first_step.fetch(:body)).to include("type" => "STEP", "hasStats" => false, "parentUuid" => "item-2")
    expect(second_step).to include(path: "/api/v1/demo/item/item-2")
    expect(second_step.fetch(:body)).to include("type" => "STEP", "hasStats" => false, "parentUuid" => "item-2")
    formatter.instance_variable_set(:@finalized, true)
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
    expect(before_all.fetch(:body)).to include("name" => "BeforeAll Hook: seed database", "type" => "BEFORE_CLASS", "hasStats" => false)
    expect(scenario).to include(path: "/api/v1/demo/item/item-1")
    expect(scenario.fetch(:body)).to include("name" => "Scenario: Class hook scenario", "type" => "STEP", "hasStats" => true)
    expect(after_all).to include(path: "/api/v1/demo/item/item-1")
    expect(after_all.fetch(:body)).to include("name" => "AfterAll Hook: drop database", "type" => "AFTER_CLASS", "hasStats" => false)
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
    feature = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "feature-1", kind: :feature, name: "Feature", type: "SUITE", has_stats: true)
    scenario = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "scenario-1", kind: :scenario, name: "Scenario", parent_uuid: "feature-1", type: "STEP", has_stats: true)
    step = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "step-1", kind: :step, name: "When upload", parent_uuid: "scenario-1", type: "STEP", has_stats: false)

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
    scenario = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "scenario-1", kind: :scenario, name: "Scenario", type: "STEP", has_stats: true)
    step = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "step-1", kind: :step, name: "When upload", parent_uuid: "scenario-1", type: "STEP", has_stats: false)

    formatter.runtime_context.start_scenario("features/a.feature:1:uniq", scenario)
    formatter.runtime_context.push_step(step)
    event = ::Cucumber::Events::AttachCalled.new("hello", "text/plain", "native.txt")
    expect(event).to be_a(::Cucumber::Core::Event::Base)
    stub_config.handlers.fetch(:attach_called).call(event)

    expect(log_buffer).to have_received(:emit_log).with(
      hash_including(
        item_uuid: "step-1",
        message: "Attachment: native.txt",
        attachment: hash_including(name: "native.txt", mime: "text/plain", bytes: "hello")
      )
    )
    formatter.instance_variable_set(:@finalized, true)
  end

  context "with external replay attachments independent of native generated envelopes" do
    let(:buffer) { instance_double(ReportportalCucumber::Runtime::LogBuffer, emit_log: true, shutdown: true, reject_logs: false) }
    let(:formatter) { described_class.new(stub_config) }

    before do
      allow(ReportportalCucumber::Runtime::LogBuffer).to receive(:new).and_return(buffer)
      scenario = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "scenario-replay", kind: :scenario, type: "STEP", has_stats: true)
      step = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "step-replay", kind: :step, parent_uuid: "scenario-replay", type: "STEP", has_stats: false)
      formatter.runtime_context.start_scenario("replay:1", scenario)
      formatter.runtime_context.associate_test_case_started("attempt-replay", scenario)
      formatter.runtime_context.push_step(step)
      formatter.runtime_context.associate_test_step("native-step-replay", step)
    end

    after { formatter.instance_variable_set(:@finalized, true) }

    def replay_attachment
      { "test_step_id" => "native-step-replay", "test_case_started_id" => "attempt-replay",
        "file_name" => "replay.txt", "media_type" => "text/plain", "content_encoding" => "BASE64",
        "body" => Base64.strict_encode64("replay\x00\r\n") }
    end

    it "retains the public direct attachment replay path and exact original bytes" do
      formatter.ingest_event(replay_attachment.merge("type" => "attachment"))
      expect(buffer).to have_received(:emit_log).once.with(hash_including(
        item_uuid: "step-replay", attachment: hash_including(name: "replay.txt", mime: "text/plain", bytes: "replay\x00\r\n")
      ))
    end

    it "retains explicit public envelope replay while ignoring the identical native generated envelope" do
      payload = { "attachment" => replay_attachment }
      stub_config.handlers.fetch(:envelope).call(payload)
      expect(buffer).not_to have_received(:emit_log)
      formatter.ingest_event("type" => "envelope", "envelope" => payload)
      expect(buffer).to have_received(:emit_log).once.with(hash_including(
        item_uuid: "step-replay", attachment: hash_including(bytes: "replay\x00\r\n")
      ))
    end

    it "rejects unknown explicit step/attempt IDs rather than retargeting to the current action" do
      formatter.ingest_event(replay_attachment.merge("type" => "attachment", "test_step_id" => "stale-step"))
      formatter.ingest_event(replay_attachment.merge("type" => "attachment", "test_case_started_id" => "stale-attempt"))
      expect(buffer).not_to have_received(:emit_log)
      expect(buffer).to have_received(:reject_logs).with(count: 1).twice
    end

    it "accepts a resolvable explicit Step owner from a joined thread without guessing its context" do
      subject = formatter
      payload = replay_attachment.merge("type" => "attachment")
      Thread.new { subject.ingest_event(payload) }.value
      expect(buffer).to have_received(:emit_log).once.with(hash_including(item_uuid: "step-replay"))
      expect(buffer).not_to have_received(:reject_logs)
    end

    it "preserves explicit replay Step/Scenario log targets while a different manual group is active" do
      manual = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "manual-replay", kind: :manual_step,
                                                                    parent_uuid: "step-replay", type: "STEP", has_stats: false)
      formatter.runtime_context.push_step(manual)
      payload = replay_attachment.merge("type" => "attachment", "media_type" => "text/x.cucumber.log+plain",
                                        "content_encoding" => "IDENTITY", "body" => "requested step log")
      formatter.ingest_event(payload)
      formatter.ingest_event(payload.reject { |key, _| key == "test_step_id" }.merge("body" => "requested scenario log"))
      expect(buffer).to have_received(:emit_log).with(hash_including(item_uuid: "step-replay", message: "requested step log"))
      expect(buffer).to have_received(:emit_log).with(hash_including(item_uuid: "scenario-replay", message: "requested scenario log"))
      expect(buffer).not_to have_received(:emit_log).with(hash_including(item_uuid: "manual-replay"))
    end
  end

  it "flushes manual step logs before finishing the manual step item" do
    api = instance_double(ReportportalCucumber::ReportPortal::API)
    log_buffer = instance_double(ReportportalCucumber::Runtime::LogBuffer)
    call_order = []

    allow(ReportportalCucumber::Runtime::LogBuffer).to receive(:new).and_return(log_buffer)
    allow(log_buffer).to receive(:emit_log) { call_order << :emit_log }
    allow(log_buffer).to receive(:flush) { call_order << :flush_before_finish; true }
    allow(log_buffer).to receive(:flush_receipt) do
      call_order << :flush_before_finish
      double(local_settled: true)
    end
    allow(log_buffer).to receive(:shutdown).and_return(true)
    allow(api).to receive(:start_item).and_return("manual-uuid")
    allow(api).to receive(:finish_item) { call_order << :finish_item }

    formatter = described_class.new(stub_config)
    formatter.instance_variable_set(:@api, api)
    formatter.instance_variable_set(:@launch_uuid, "launch-uuid")
    scenario = ReportportalCucumber::Runtime::Context::ItemHandle.new(uuid: "scenario-1", kind: :scenario, name: "Scenario", type: "STEP", has_stats: true)
    formatter.runtime_context.start_scenario("features/a.feature:1:uniq", scenario)

    formatter.with_manual_step("Manual group") do
      formatter.emit_world_log(message: "inside", level: :info, timestamp: Time.utc(2026, 5, 30))
    end

    expect(call_order).to eq(%i[emit_log flush_before_finish finish_item])
    formatter.instance_variable_set(:@finalized, true)
  end

  it "preserves the original manual-step error when strict finish reporting and its warning logger fail" do
    api = instance_double(ReportportalCucumber::ReportPortal::API)
    allow(ReportportalCucumber::Runtime::LogBuffer).to receive(:new).and_return(
      instance_double(ReportportalCucumber::Runtime::LogBuffer, emit_log: nil, shutdown: true)
    )
    allow(api).to receive(:start_item).and_return("manual-uuid")
    allow(api).to receive(:finish_item).and_raise(ReportportalCucumber::ReportingError, "finish failed")
    allow(ReportportalCucumber.logger).to receive(:warn).and_raise(IOError, "logger unavailable")
    allow(config).to receive(:fail_on_reporting_error?).and_return(true)

    formatter = described_class.new(stub_config)
    formatter.instance_variable_set(:@api, api)
    formatter.instance_variable_set(:@launch_uuid, "launch-uuid")
    scenario = ReportportalCucumber::Runtime::Context::ItemHandle.new(
      uuid: "scenario-1", kind: :scenario, name: "Scenario", type: "STEP", has_stats: true
    )
    formatter.runtime_context.start_scenario("features/a.feature:1:uniq", scenario)
    allow(formatter).to receive(:flush_before_finish)
    allow(formatter).to receive(:emit_error_log)

    original = RuntimeError.new("business failed")
    raised = nil
    expect do
      formatter.with_manual_step("Manual group") { raise original }
    end.to raise_error { |error| raised = error }

    expect(raised).to equal(original)
    expect(raised.message).to eq("business failed")
    formatter.instance_variable_set(:@finalized, true)
  end
end
