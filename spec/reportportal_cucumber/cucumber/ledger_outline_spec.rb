# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Ledger Outline descriptions" do
  let(:formatter) { ReportportalCucumber::Cucumber::Formatter.allocate }
  let(:source) do
    { examples_name: "Table-only substitution", example_row_line: 12,
      parameters: { "value" => "TABLE_ONLY_AMBER" } }
  end

  def description(metadata)
    formatter.send(:extract_scenario_description, feature_uri: "features/outline.feature", scenario_line: 4, metadata: metadata)
  end

  it "matches the exact short Outline golden and retains parameter order" do
    expect(description(source)).to eq("`value` = `TABLE_ONLY_AMBER` · _Examples: Table-only substitution · line 12_")
    expect(description(source.merge(parameters: { "b" => "2", "a" => "1" })))
      .to eq("`b` = `2` · `a` = `1` · _Examples: Table-only substitution · line 12_")
  end

  it "omits the Examples colon when there is no name" do
    expect(description(source.merge(examples_name: nil))).to eq("`value` = `TABLE_ONLY_AMBER` · _Examples · line 12_")
  end

  it "keeps source descriptions and Rule information before the row metadata" do
    metadata = source.merge(description: "Scenario description", rule_name: "a < b", rule_description: "Rule description")
    expect(description(metadata)).to start_with("Scenario description\n\nRule: a &lt; b\n\nRule description\n\n`value`")
  end

  it "falls back to an escaped table for more than four parameters" do
    metadata = source.merge(examples_name: "<cases>", parameters: { "a" => "1", "b" => "2", "c" => "3", "d" => "4", "e" => "<other>" })
    expect(description(metadata)).to eq("Examples: &lt;cases&gt; · line 12\n\n| a | b | c | d | e |\n| --- | --- | --- | --- | --- |\n| 1 | 2 | 3 | 4 | &lt;other&gt; |")
    expect(description(metadata)).not_to include("Example row:")
  end

  it "falls back for long or multiline values, but counts Unicode characters rather than bytes" do
    ["a" * 41, "a\nb", "a\rb"].each do |value|
      expect(description(source.merge(parameters: { "value" => value }))).to start_with("Examples: Table-only substitution · line 12\n\n| value |")
    end
    expect(description(source.merge(parameters: { "value" => "中" * 40 }))).to start_with("`value` = `#{'中' * 40}` · _Examples:")
    expect(description(source.merge(parameters: { "value" => "a\nb" }))).to include("| a<br>b |")
  end

  it "keeps literal markup inside dynamic code spans and never mutates parameters" do
    values = { "tick`key" => "<other> & value" }.freeze
    metadata = source.merge(parameters: values).freeze
    expect(description(metadata)).to start_with("``tick`key`` = `<other> & value`")
    expect(metadata[:parameters]).to equal(values)
    expect(values).to eq("tick`key" => "<other> & value")
  end

  it "preserves the exact baseline and warns once when a presentation helper fails" do
    expected = formatter.send(:scenario_description, source, presentation: false)
    allow(ReportportalCucumber::Presentation::MarkdownText).to receive(:code).and_raise("SECRET failure")
    expect(ReportportalCucumber.logger).to receive(:warn).with("ReportPortal presentation failed; using baseline format").once
    expect(description(source)).to eq(expected)
  end
end
