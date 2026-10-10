# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "M3B stable scenario identity in the Cucumber formatter" do
  let(:config) do
    value = ReportportalCucumber::Config.new(
      endpoint: "https://rp.example.com",
      project: "demo",
      api_key: "token",
      launch: "M3B identity spec",
      retry_attempts: 1,
      join: false,
      identity_strategy: "stable_v1",
      identity_root: Dir.pwd,
      identity_namespace: "m3b-spec"
    )
    value
  end

  let(:stub_config) { Object.new }

  before do
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
  end

  it "keeps canonical identity across line and parameter-order changes while generating fresh execution UUIDs" do
    source = { scenario_name: "Submit <record>", identity_ambiguous: false }
    first = ReportportalCucumber::Service::ScenarioIdentity.build(
      strategy: "stable_v1", code_ref: "features/orders.feature:8", feature_uri: "features/orders.feature",
      source: source, parameters: { "record" => "r-1", "region" => "east" }, root: Dir.pwd, namespace: "m3b-spec"
    )
    moved = ReportportalCucumber::Service::ScenarioIdentity.build(
      strategy: "stable_v1", code_ref: "features/orders.feature:18", feature_uri: "features/orders.feature",
      source: source, parameters: { "region" => "east", "record" => "r-1" }, root: Dir.pwd, namespace: "m3b-spec"
    )

    expect(moved.test_case_id).to eq(first.test_case_id)
    expect(moved.unique_id).to eq(first.unique_id)
    expect(moved.parameters).to eq(first.parameters)
    expect(first.test_case_id).not_to include(":8", "line")
    other_namespace = ReportportalCucumber::Service::ScenarioIdentity.build(
      strategy: "stable_v1", code_ref: "features/orders.feature:8", feature_uri: "features/orders.feature",
      source: source, parameters: { "record" => "r-1", "region" => "east" }, root: Dir.pwd, namespace: "other"
    )
    expect(other_namespace.test_case_id).not_to eq(first.test_case_id)
  end

  it "marks native same-group retries and keeps the API execution UUID unique per attempt" do
    with_formatter do |formatter, started|
      formatter.ingest_event("type" => "test_run_started")
      start_scenario(formatter, "Checkout", 2, @feature_uri, { "a" => "1", "b" => "2" }, explicit_tag: "@tms:CHECKOUT")
      formatter.ingest_event("type" => "test_case_finished", "status" => "failed")
      start_scenario(formatter, "Checkout", 3, @feature_uri, { "b" => "2", "a" => "1" }, explicit_tag: "@tms:CHECKOUT")
      formatter.ingest_event("type" => "test_case_finished", "status" => "passed")
      formatter.ingest_event("type" => "test_run_finished", "success" => true)

      scenarios = started.select { |item| item.fetch(:body)["type"] == "STEP" && item.fetch(:body)["hasStats"] == true }
      expect(scenarios.map { |item| item.fetch(:body).fetch("testCaseId") }.uniq.length).to eq(1)
      expect(scenarios.map { |item| item.fetch(:body).fetch("uniqueId") }.uniq.length).to eq(1)
      expect(scenarios.map { |item| item.fetch(:body).fetch("retry") }).to eq([false, true])
      expect(scenarios.map { |item| item.fetch(:body).fetch("uuid") }.uniq.length).to eq(2)
      expect(scenarios.map { |item| item.fetch(:body).fetch("parameters").map { |entry| entry.fetch("key") }.first(2) }.uniq.length).to eq(1)
    end
  end

  it "finishes the Suite passed when a failed attempt is followed by a passing retry" do
    with_formatter do |formatter, _started, finished_suites|
      formatter.ingest_event("type" => "test_run_started")
      formatter.ingest_event("type" => "test_suite_started", "feature_uri" => @feature_uri)
      start_scenario(formatter, "Checkout", 2, @feature_uri, nil)
      formatter.ingest_event("type" => "test_case_finished", "status" => "failed")
      start_scenario(formatter, "Checkout", 2, @feature_uri, nil)
      formatter.ingest_event("type" => "test_case_finished", "status" => "passed")
      formatter.ingest_event("type" => "test_suite_finished", "feature_uri" => @feature_uri)

      expect(finished_suites.fetch(0)).to eq("passed")
    end
  end

  it "retains class-hook failure when the latest outcome for every scenario group passed" do
    with_formatter do |formatter, _started, finished_suites|
      formatter.ingest_event("type" => "test_run_started")
      formatter.ingest_event("type" => "test_suite_started", "feature_uri" => @feature_uri)
      formatter.ingest_event("type" => "test_step_started", "hook_type" => "before_class", "step_text" => "class setup")
      formatter.ingest_event("type" => "test_step_finished", "status" => "failed")
      start_scenario(formatter, "Checkout", 2, @feature_uri, nil)
      formatter.ingest_event("type" => "test_case_finished", "status" => "failed")
      start_scenario(formatter, "Checkout", 2, @feature_uri, nil)
      formatter.ingest_event("type" => "test_case_finished", "status" => "passed")
      formatter.ingest_event("type" => "test_suite_finished", "feature_uri" => @feature_uri)

      expect(finished_suites.fetch(0)).to eq("failed")
    end
  end

  it "retains a different scenario group's failure after another group's retry passes" do
    with_formatter do |formatter, _started, finished_suites|
      formatter.ingest_event("type" => "test_run_started")
      start_scenario(formatter, "Checkout", 2, @feature_uri, nil)
      formatter.ingest_event("type" => "test_case_finished", "status" => "failed")
      start_scenario(formatter, "Checkout", 2, @feature_uri, nil)
      formatter.ingest_event("type" => "test_case_finished", "status" => "passed")
      start_scenario(formatter, "Other case", 4, @feature_uri, nil)
      formatter.ingest_event("type" => "test_case_finished", "status" => "failed")
      formatter.ingest_event("type" => "test_suite_finished", "feature_uri" => @feature_uri)

      expect(finished_suites.fetch(0)).to eq("failed")
    end
  end

  it "keeps an explicit suite-finished status authoritative over retry aggregation" do
    with_formatter do |formatter, _started, finished_suites|
      formatter.ingest_event("type" => "test_run_started")
      start_scenario(formatter, "Checkout", 2, @feature_uri, nil)
      formatter.ingest_event("type" => "test_case_finished", "status" => "failed")
      formatter.ingest_event("type" => "test_suite_finished", "feature_uri" => @feature_uri, "status" => "passed")

      expect(finished_suites.fetch(0)).to eq("passed")
    end
  end

  it "warns once and returns legacy identity when AST source metadata is unavailable" do
    formatter = ReportportalCucumber::Cucumber::Formatter.allocate
    formatter.instance_variable_set(:@config, config)
    formatter.instance_variable_set(:@identity_warnings, Set.new)
    expect(ReportportalCucumber.logger).to receive(:warn).once
      .with("Stable scenario identity unavailable; using legacy identity (missing_source)")

    result = 2.times.map do
      formatter.send(
        :scenario_identity,
        feature_uri: "missing.feature", code_ref: "missing.feature:3", parameters: nil,
        explicit_id: nil, source: nil
      )
    end.first

    expect(result.strategy).to eq("legacy")
    expect(result.fallback_reason).to eq(:missing_source)
  end

  it "safely falls back for invalid stable parameters without logging parameter contents" do
    formatter = ReportportalCucumber::Cucumber::Formatter.allocate
    formatter.instance_variable_set(:@config, config)
    formatter.instance_variable_set(:@identity_warnings, Set.new)
    expect(ReportportalCucumber.logger).to receive(:warn).once
      .with("Stable scenario identity unavailable; using legacy identity (identity_error_ArgumentError)")

    result = formatter.send(
      :scenario_identity,
      feature_uri: "feature.feature", code_ref: "feature.feature:1",
      parameters: { "secret" => Object.new }, explicit_id: nil,
      source: { scenario_name: "Case", identity_ambiguous: false }
    )

    expect(result).to be_nil
  end

  it "preserves environment explicit-ID precedence over a scenario tag" do
    formatter = ReportportalCucumber::Cucumber::Formatter.allocate
    previous = ENV["RP_TEST_CASE_ID"]
    ENV["RP_TEST_CASE_ID"] = "ENV-CASE"
    expect(formatter.send(:explicit_test_case_id_for, "tags" => ["@tms:TAG-CASE"])).to eq("ENV-CASE")
  ensure
    previous.nil? ? ENV.delete("RP_TEST_CASE_ID") : ENV["RP_TEST_CASE_ID"] = previous
  end

  it "re-raises the original identity error under strict reporting policy" do
    strict_config = ReportportalCucumber::Config.new(
      endpoint: "https://rp.example.com", project: "demo", api_key: "token",
      identity_strategy: "stable_v1", fail_on_reporting_error: true
    )
    formatter = ReportportalCucumber::Cucumber::Formatter.allocate
    formatter.instance_variable_set(:@config, strict_config)
    formatter.instance_variable_set(:@identity_warnings, Set.new)
    failure = ArgumentError.new("Invalid scenario identity parameters")
    allow(ReportportalCucumber::Service::ScenarioIdentity).to receive(:build).and_raise(failure)

    expect do
      formatter.send(
        :scenario_identity,
        feature_uri: "feature.feature", code_ref: "feature.feature:1", parameters: Object.new,
        explicit_id: nil, source: { scenario_name: "Case", identity_ambiguous: false }
      )
    end.to raise_error { |error| expect(error).to equal(failure) }
  end

  it "does not retry when the wire name, parent feature, or dataset changes despite an explicit case ID" do
    with_formatter do |formatter, started|
      second_feature = File.join(File.dirname(@feature_uri), "second.feature")
      File.write(second_feature, "Feature: Second\n  Scenario: Checkout\n    Given an order exists\n")
      formatter.ingest_event("type" => "test_run_started")
      start_scenario(formatter, "Checkout", 2, @feature_uri, { "dataset" => "one" }, explicit_tag: "@tms:SAME")
      formatter.ingest_event("type" => "test_case_finished", "status" => "passed")
      start_scenario(formatter, "Renamed", 2, @feature_uri, { "dataset" => "one" }, explicit_tag: "@tms:SAME")
      formatter.ingest_event("type" => "test_case_finished", "status" => "passed")
      start_scenario(formatter, "Checkout", 2, second_feature, { "dataset" => "one" }, explicit_tag: "@tms:SAME")
      formatter.ingest_event("type" => "test_case_finished", "status" => "passed")
      start_scenario(formatter, "Checkout", 2, @feature_uri, { "dataset" => "two" }, explicit_tag: "@tms:SAME")
      formatter.ingest_event("type" => "test_case_finished", "status" => "passed")

      scenario_bodies = started.filter_map do |item|
        body = item.fetch(:body)
        body if body["type"] == "STEP" && body["hasStats"] == true
      end
      expect(scenario_bodies.map { |body| body.fetch("retry") }).to eq([false, false, false, false])
      ids = scenario_bodies.map { |body| body.fetch("testCaseId") }
      expect(ids.first(3).uniq.length).to eq(1)
      expect(ids.last).not_to eq(ids.first)
    end
  end

  it "starts a fresh retry group when the launch UUID changes" do
    formatter = ReportportalCucumber::Cucumber::Formatter.allocate
    formatter.instance_variable_set(:@launch_uuid, "launch-a")
    runtime = ReportportalCucumber::Runtime::Context.new
    first_key = formatter.send(
      :stable_retry_key, parent_uuid: "feature-a", wire_name: "Scenario: Checkout", unique_id: "stable-case"
    )
    expect(runtime.next_scenario_attempt(first_key)).to eq(1)
    formatter.instance_variable_set(:@launch_uuid, "launch-b")
    second_key = formatter.send(
      :stable_retry_key, parent_uuid: "feature-a", wire_name: "Scenario: Checkout", unique_id: "stable-case"
    )

    expect(second_key).not_to eq(first_key)
    expect(runtime.next_scenario_attempt(second_key)).to eq(1)
  end

  it "does not treat multiple Examples rows as duplicate Scenario headers" do
    Dir.mktmpdir("m3b-ambiguous-") do |directory|
      uri = File.join(directory, "outline.feature")
      File.write(uri, <<~FEATURE)
        Feature: Rows are not headers
          Scenario Outline: Submit <value>
            Given a value exists
            Examples:
              | value |
              | one   |
              | two   |
              | three |
        FEATURE

      metadata = ReportportalCucumber::Cucumber::AstMetadata.new
      expect(metadata.scenario(uri: uri, location_line: 6)).to include(scenario_name: "Submit <value>", identity_ambiguous: false)
      expect(metadata.scenario(uri: uri, location_line: 7)).to include(scenario_name: "Submit <value>", identity_ambiguous: false)
      expect(metadata.scenario(uri: uri, location_line: 8)).to include(scenario_name: "Submit <value>", identity_ambiguous: false)
    end
  end

  it "marks same-named scenarios in duplicate-named Rules as ambiguous" do
    Dir.mktmpdir("m3b-duplicate-rules-") do |directory|
      uri = File.join(directory, "duplicate-rules.feature")
      File.write(uri, <<~FEATURE)
        Feature: Duplicate rules
          Rule: Shared
            Scenario: Same case
              Given one case exists
          Rule: Shared
            Scenario: Same case
              Given another case exists
        FEATURE

      metadata = ReportportalCucumber::Cucumber::AstMetadata.new
      expect(metadata.scenario(uri: uri, location_line: 3)).to include(scenario_name: "Same case", identity_ambiguous: true)
      expect(metadata.scenario(uri: uri, location_line: 6)).to include(scenario_name: "Same case", identity_ambiguous: true)
    end
  end

  private

  def with_formatter
    started = []
    finished_suites = []
    suite_uuid = nil
    item_counter = 0
    Dir.mktmpdir("m3b-identity-", Dir.pwd) do |directory|
      @feature_uri = File.join(directory, "checkout.feature")
      File.write(@feature_uri, <<~FEATURE)
        Feature: Checkout
          Scenario: Checkout
            Given an order exists
          Scenario: Other case
            Given another order exists
      FEATURE
      stub_request(:post, "https://rp.example.com/api/v1/demo/launch")
      .to_return(status: 200, body: '{"id":"launch-1"}')
      stub_request(:post, %r{\Ahttps://rp\.example\.com/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      item_counter += 1
      body = JSON.parse(request.body)
      suite_uuid = "item-#{item_counter}" if body["type"] == "SUITE"
      started << { id: "item-#{item_counter}", body: body }
      { status: 200, body: { id: "item-#{item_counter}" }.to_json }
    end
      stub_request(:put, %r{\Ahttps://rp\.example\.com/api/v1/demo/item/.*\z}).to_return do |request|
      body = JSON.parse(request.body)
      finished_suites << body.fetch("status") if request.uri.path.end_with?("/item/#{suite_uuid}")
      { status: 200, body: '{"message":"ok"}' }
    end
      stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish")
        .to_return(status: 200, body: '{"message":"ok"}')
      stub_request(:post, "https://rp.example.com/api/v1/demo/log")
        .to_return(status: 200, body: '{"responses":[{"message":"ok"}]}')

      formatter = ReportportalCucumber::Cucumber::Formatter.new(stub_config)
      yield formatter, started, finished_suites
    ensure
      if formatter && !formatter.instance_variable_get(:@finalized)
        formatter.ingest_event("type" => "test_run_finished", "success" => true)
      end
    end
  end

  def start_scenario(formatter, name, line, uri, parameters, explicit_tag: nil)
    tags = explicit_tag ? [explicit_tag] : []
    formatter.ingest_event(
      "type" => "test_case_started",
      "feature_uri" => uri,
      "scenario_name" => name,
      "scenario_line" => line,
      "parameters" => parameters,
      "tags" => tags
    )
  end
end
