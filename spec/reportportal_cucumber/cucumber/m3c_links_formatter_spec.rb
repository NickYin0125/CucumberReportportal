# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Cucumber::Formatter do
  it "adds references to the existing scenario description without changing scenario identity or shape" do
    formatter, api, runtime = formatter_fixture(
      enabled: true,
      description: "Existing scenario prose\n\n| input | value |",
      source: { example_row_line: 23 }
    )
    result = Struct.new(:description, :links, :diagnostics).new(
      "Existing scenario prose\n\n| input | value |\n\n### References\n\n[Source](<https://code.example/a.feature#L23>)",
      [{ label: "Source", url: "https://code.example/a.feature#L23" }],
      []
    )
    builder = Module.new do
      define_singleton_method(:build) do |**arguments|
        Thread.current[:m3c_links_arguments] = arguments
        result
      end
    end
    stub_const("ReportportalCucumber::Service::ScenarioLinks", builder)

    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments).to include(
        name: "Scenario: Case", type: "STEP", has_stats: true, retry: false,
        description: result.description
      )
      expect(arguments).not_to have_key(:links)
      expect(arguments.fetch(:test_case_id)).to eq(
        ReportportalCucumber::ReportPortal::Models.build_test_case_id(
          explicit_id: "CASE-42", code_ref: "feature.feature:8", parameters: nil
        )
      )
      expect(arguments.fetch(:unique_id)).to eq(
        ReportportalCucumber::ReportPortal::Models.build_unique_id(code_ref: "feature.feature:8", parameters: nil)
      )
      "scenario-uuid"
    end

    formatter.send(:handle_test_case_started, "tags" => ["@tms:CASE-42"])

    expect(Thread.current[:m3c_links_arguments]).to include(
      description: "Existing scenario prose\n\n| input | value |",
      feature_uri: File.expand_path("feature.feature", Dir.pwd),
      scenario_line: 8,
      example_row_line: 23,
      explicit_id: "CASE-42",
      source_url_template: "https://code.example/{path}#L{line}",
      source_commit: "a" * 40,
      source_root: Dir.pwd,
      ci_run_url: nil,
      tms_url_template: nil
    )
    expect(runtime).to have_received(:start_scenario)
  ensure
    Thread.current[:m3c_links_arguments] = nil
  end

  it "does not call the builder or alter the description when links are disabled" do
    formatter, api, = formatter_fixture(enabled: false, description: nil)
    builder = Module.new do
      define_singleton_method(:build) { |**| raise "disabled formatter invoked link builder" }
    end
    stub_const("ReportportalCucumber::Service::ScenarioLinks", builder)
    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments).to have_key(:description)
      expect(arguments[:description]).to be_nil
      "scenario-uuid"
    end

    formatter.send(:handle_test_case_started, {})
  end

  it "keeps safe diagnostic reasons and does not discard valid sibling links" do
    formatter, api, = formatter_fixture(enabled: true, description: "Keep this text")
    result = Struct.new(:description, :links, :diagnostics).new(
      "Keep this text\n\n### References\n\n[CI Run](<https://ci.example/run/1>)",
      [{ label: "CI Run", url: "https://ci.example/run/1" }],
      [{ reason: :source_unavailable, id: "CASE-SECRET", url: "https://user:secret@example.test" }]
    )
    builder = Module.new do
      define_singleton_method(:build) { |**| result }
    end
    stub_const("ReportportalCucumber::Service::ScenarioLinks", builder)
    expect(ReportportalCucumber.logger).to receive(:warn).with("Scenario link omitted (source_unavailable)")
    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments[:description]).to eq(result.description)
      "scenario-uuid"
    end

    formatter.send(:handle_test_case_started, "tags" => ["@tms:CASE-SECRET"])
  end

  it "maps unknown diagnostic text to a fixed reason without leaking it" do
    formatter, api, = formatter_fixture(enabled: true, description: "Original text")
    result = Struct.new(:description, :links, :diagnostics).new(
      "Original text", [], [{ reason: "secret_marker" }]
    )
    builder = Module.new do
      define_singleton_method(:build) { |**| result }
    end
    stub_const("ReportportalCucumber::Service::ScenarioLinks", builder)
    expect(ReportportalCucumber.logger).to receive(:warn).with("Scenario link omitted (invalid_link)")
    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments[:description]).to eq("Original text")
      "scenario-uuid"
    end

    formatter.send(:handle_test_case_started, {})
  end

  it "passes traversal paths through unchanged for helper rejection and preserves identity inputs" do
    traversal_uri = "../outside/feature.feature"
    formatter, api, = formatter_fixture(
      enabled: true, description: "Original text", feature_uri: traversal_uri
    )
    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments[:code_ref]).to eq("#{traversal_uri}:8")
      expect(arguments[:description]).to eq("Original text")
      expect(arguments[:test_case_id]).to eq(
        ReportportalCucumber::ReportPortal::Models.build_test_case_id(
          explicit_id: nil, code_ref: "#{traversal_uri}:8", parameters: nil
        )
      )
      "scenario-uuid"
    end

    formatter.send(:handle_test_case_started, {})
  end

  it "falls back to the exact original description after unexpected errors even in strict mode" do
    formatter, api, = formatter_fixture(enabled: true, description: "Original text", strict: true)
    builder = Module.new do
      define_singleton_method(:build) { |**| raise "secret URL https://user:secret@example.test" }
    end
    stub_const("ReportportalCucumber::Service::ScenarioLinks", builder)
    expect(ReportportalCucumber.logger).to receive(:warn).with("Scenario links unavailable (RuntimeError)")
    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments[:description]).to eq("Original text")
      "scenario-uuid"
    end

    expect { formatter.send(:handle_test_case_started, {}) }.not_to raise_error
  end

  it "keeps legacy config doubles disabled without invoking the builder" do
    formatter, api, = formatter_fixture(enabled: false, description: "Original text")
    formatter.instance_variable_set(:@config, Object.new)
    builder = Module.new do
      define_singleton_method(:build) { |**| raise "unexpected link builder call" }
    end
    stub_const("ReportportalCucumber::Service::ScenarioLinks", builder)
    expect(api).to receive(:start_item) do |**arguments|
      expect(arguments[:description]).to eq("Original text")
      "scenario-uuid"
    end

    formatter.send(:handle_test_case_started, {})
  end

  private

  def formatter_fixture(enabled:, description:, source: { example_row_line: nil }, strict: false,
                        feature_uri: "feature.feature")
    config_class = Struct.new(
      :scenario_links_enabled, :source_url_template, :source_commit, :source_root,
      :ci_run_url, :tms_url_template, :fail_on_reporting_error?
    )
    config = config_class.new(
      enabled, "https://code.example/{path}#L{line}", "a" * 40, Dir.pwd,
      nil, nil, strict
    )
    config.define_singleton_method(:scenario_links_enabled?) { scenario_links_enabled }
    formatter = described_class.allocate
    api = double("API")
    runtime = double("runtime context")
    feature = Struct.new(:uuid).new("feature-uuid")
    allow(formatter).to receive(:reporting_enabled?).and_return(true)
    allow(formatter).to receive(:extract_timestamp).and_return(Time.at(1))
    allow(formatter).to receive(:extract_feature_uri).and_return(feature_uri)
    allow(formatter).to receive(:ensure_feature_item).and_return(feature)
    allow(formatter).to receive(:extract_scenario_name).and_return("Case")
    allow(formatter).to receive(:extract_scenario_line).and_return(8)
    allow(formatter).to receive(:event_location_line).and_return(8)
    allow(formatter).to receive(:extract_parameters).and_return(nil)
    allow(formatter).to receive(:extract_scenario_description).and_return(description)
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
    formatter.instance_variable_set(:@ast_metadata, double(scenario: source))
    formatter.instance_variable_set(:@scenario_states, {})
    formatter.instance_variable_set(:@launch_uuid, "launch-uuid")
    [formatter, api, runtime]
  end
end
