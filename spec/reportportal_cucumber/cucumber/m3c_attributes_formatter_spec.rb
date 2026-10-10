# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Cucumber::Formatter do
  let(:source) do
    {
      tag_scopes: {
        feature: ["@team:checkout"], rule: [], scenario: ["@owner:qa"], examples: []
      }
    }
  end

  it "passes resolved scenario attributes only when explicitly enabled" do
    formatter, api, runtime = formatter_fixture(enabled: true)
    result = Struct.new(:attributes, :diagnostics).new([{ "key" => "team", "value" => "checkout" }], [])
    resolver = Module.new do
      define_singleton_method(:build) do |**arguments|
        Thread.current[:m3c_resolver_arguments] = arguments
        result
      end
    end
    stub_const("ReportportalCucumber::Service::ScenarioAttributes", resolver)

    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments.fetch(:attributes)).to eq(result.attributes)
      expect(arguments).to include(type: "STEP", has_stats: true, retry: false)
      "scenario-uuid"
    end

    formatter.send(:handle_test_case_started, "tags" => ["@tms:CASE-7"])

    expect(Thread.current[:m3c_resolver_arguments]).to include(
      defaults: [{ "key" => "team", "value" => "default" }],
      tag_scopes: source.fetch(:tag_scopes),
      allowed_keys: %w[team owner tms],
      explicit_id: "CASE-7"
    )
    expect(runtime).to have_received(:start_scenario)
  ensure
    Thread.current[:m3c_resolver_arguments] = nil
  end

  it "does not resolve or pass scenario attributes when explicitly disabled" do
    formatter, api, = formatter_fixture(enabled: false)
    resolver = Module.new do
      define_singleton_method(:build) { |**| raise "disabled formatter invoked resolver" }
    end
    stub_const("ReportportalCucumber::Service::ScenarioAttributes", resolver)
    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments).not_to have_key(:attributes)
      "scenario-uuid"
    end

    formatter.send(:handle_test_case_started, {})
  end

  it "keeps legacy config doubles without the new readers disabled" do
    formatter, api, = formatter_fixture(enabled: false)
    formatter.instance_variable_set(:@config, Object.new)
    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments).not_to have_key(:attributes)
      "scenario-uuid"
    end

    formatter.send(:handle_test_case_started, {})
  end

  it "uses defaults and the already-selected explicit ID when AST source is missing" do
    formatter, api, = formatter_fixture(enabled: true, source_metadata: nil)
    expect(ReportportalCucumber.logger).to receive(:warn)
      .with("Scenario attribute ignored (missing_source, scope=scenario)")
    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments.fetch(:attributes)).to eq([
        { "key" => "team", "value" => "default" },
        { "key" => "tms", "value" => "CASE-9" }
      ])
      "scenario-uuid"
    end

    formatter.send(:handle_test_case_started, "tags" => ["@team:must-not-be-guessed", "@tms:CASE-9"])
  end

  it "omits resolver failures even under strict reporting policy without suppressing the scenario start" do
    formatter, api, = formatter_fixture(enabled: true, strict: true)
    resolver = Module.new do
      define_singleton_method(:build) { |**| raise "secret @team:resolver-error" }
    end
    stub_const("ReportportalCucumber::Service::ScenarioAttributes", resolver)
    expect(ReportportalCucumber.logger).to receive(:warn)
      .with("Scenario attributes unavailable (RuntimeError)")
    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments).not_to have_key(:attributes)
      "scenario-uuid"
    end

    expect { formatter.send(:handle_test_case_started, {}) }.not_to raise_error
  end

  it "does not let added tag scopes affect stable identity" do
    arguments = {
      strategy: "stable_v1", code_ref: "feature.feature:8", feature_uri: "feature.feature",
      parameters: nil, root: Dir.pwd, namespace: "m3c-spec"
    }
    base = ReportportalCucumber::Service::ScenarioIdentity.build(
      **arguments, source: { scenario_name: "Case", identity_ambiguous: false }
    )
    with_tags = ReportportalCucumber::Service::ScenarioIdentity.build(
      **arguments, source: { scenario_name: "Case", identity_ambiguous: false, tag_scopes: source.fetch(:tag_scopes) }
    )

    expect(with_tags.test_case_id).to eq(base.test_case_id)
    expect(with_tags.unique_id).to eq(base.unique_id)
  end

  it "renders only whitelisted diagnostic reason, scope, and key fields" do
    formatter = described_class.allocate
    expect(ReportportalCucumber.logger).to receive(:warn)
      .with("Scenario attribute ignored (conflict, scope=scenario, key=owner)")

    formatter.send(
      :warn_scenario_attribute_diagnostic,
      { reason: :conflict, scope: :scenario, key: "owner", value: "must-not-leak" },
      allowed_keys: %w[owner team]
    )
  end

  it "keeps successive scenarios and concurrent attribute resolution isolated" do
    first_scopes = { feature: [], rule: [], scenario: ["@team:first"], examples: [] }
    second_scopes = { feature: [], rule: [], scenario: ["@team:second"], examples: [] }
    first_formatter, first_api, = formatter_fixture(enabled: true, source_metadata: { tag_scopes: first_scopes })
    second_formatter, second_api, = formatter_fixture(enabled: true, source_metadata: { tag_scopes: second_scopes })
    first_attributes = [{ "key" => "team", "value" => "first" }]
    second_attributes = [{ "key" => "team", "value" => "second" }]
    first_starts = []
    second_starts = []
    allow(first_api).to receive(:start_item) do |**arguments|
      first_starts << arguments.fetch(:attributes)
      "first-item"
    end
    allow(second_api).to receive(:start_item) do |**arguments|
      second_starts << arguments.fetch(:attributes)
      "second-item"
    end

    first_formatter.send(:handle_test_case_started, {})
    second_formatter.send(:handle_test_case_started, {})
    first_formatter.send(:handle_test_case_started, {})
    ready = Queue.new
    release = Queue.new
    workers = [
      [first_formatter, first_scopes], [second_formatter, second_scopes]
    ].map do |formatter, scopes|
      Thread.new do
        ready << true
        release.pop
        formatter.send(:build_scenario_attributes, source: { tag_scopes: scopes }, explicit_id: nil)
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    first_result, second_result = workers.map(&:value)

    expect(first_result).to eq(first_attributes)
    expect(second_result).to eq(second_attributes)
    expect(first_starts).to eq([first_attributes, first_attributes])
    expect(second_starts).to eq([second_attributes])
    expect(first_formatter.send(:build_scenario_attributes, source: { tag_scopes: first_scopes }, explicit_id: nil))
      .to eq(first_attributes)
  end

  private

  def formatter_fixture(enabled:, source_metadata: source, strict: false)
    config = Struct.new(:scenario_attributes_enabled, :scenario_attributes, :scenario_attribute_keys,
                        :identity_strategy, :fail_on_reporting_error?).new(
      enabled, [{ "key" => "team", "value" => "default" }], %w[team owner tms], "legacy", strict
    )
    formatter = described_class.allocate
    api = double("API")
    runtime = double("runtime context")
    feature = Struct.new(:uuid).new("feature-uuid")
    allow(formatter).to receive(:reporting_enabled?).and_return(true)
    allow(formatter).to receive(:extract_timestamp).and_return(Time.at(1))
    allow(formatter).to receive(:extract_feature_uri).and_return("feature.feature")
    allow(formatter).to receive(:ensure_feature_item).and_return(feature)
    allow(formatter).to receive(:extract_scenario_name).and_return("Case")
    allow(formatter).to receive(:extract_scenario_line).and_return(8)
    allow(formatter).to receive(:event_location_line).and_return(8)
    allow(formatter).to receive(:extract_parameters).and_return(nil)
    allow(formatter).to receive(:extract_scenario_description).and_return(nil)
    allow(formatter).to receive(:monotonic_timestamp) { |time| time }
    allow(formatter).to receive(:safe_reporting_call) { |fallback: nil, &block| block.call }
    allow(formatter).to receive(:build_scenario_key).and_return("scenario-key")
    allow(formatter).to receive(:scenario_identity).and_return(nil)
    allow(runtime).to receive(:set_current_feature)
    allow(runtime).to receive(:current_feature_uuid).and_return("feature-uuid")
    allow(runtime).to receive(:next_scenario_attempt).and_return(1)
    allow(runtime).to receive(:start_scenario)
    allow(runtime).to receive(:associate_test_case_started)
    formatter.instance_variable_set(:@config, config)
    formatter.instance_variable_set(:@api, api)
    formatter.instance_variable_set(:@runtime_context, runtime)
    formatter.instance_variable_set(:@ast_metadata, double(scenario: source_metadata))
    formatter.instance_variable_set(:@scenario_states, {})
    formatter.instance_variable_set(:@launch_uuid, "launch-uuid")
    [formatter, api, runtime]
  end
end
