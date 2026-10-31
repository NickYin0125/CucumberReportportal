# frozen_string_literal: true

require "spec_helper"
require "cucumber/core"

RSpec.describe "Ledger legacy argument companions (Decision 4)" do
  let(:doc) { "      \"\"\"text\n      CONSTANT_DOC\n      \"\"\"\n" }
  let(:table) { "      | key | value |\n      | combined | <value> |\n" }
  let(:examples) { "    Examples: Table-only substitution\n      | value |\n      | TABLE_ONLY_AMBER <other> |\n      | TABLE_ONLY_BIRCH |\n" }

  %w[doc-first table-first].each do |order|
    it "records native #{order} compound parser rejection rather than inventing support" do
      arguments = order == "doc-first" ? doc + table : table + doc
      source = "Feature: Legacy compound\n  Scenario Outline: Display\n    Given combined display\n" + arguments + examples
      envelopes = Gherkin.from_source("compound.feature", source, include_source: false,
                                     include_gherkin_document: true, include_pickles: true).to_a
      errors = envelopes.filter_map(&:parse_error)
      expect(errors).not_to be_empty
      expect(errors.map(&:message).join("\n")).to include("expected:")
      expect(envelopes.filter_map(&:pickle)).to be_empty
    end

    it "preserves #{order} separate-argument Outline values, descriptions and captioned logs" do
      arguments = if order == "doc-first"
                    "    Given document\n#{doc}    Then table\n#{table}"
                  else
                    "    Given table\n#{table}    Then document\n#{doc}"
                  end
      source = "Feature: Legacy companions\n  Scenario Outline: Display\n" + arguments + examples
      Dir.mktmpdir("ledger-legacy-") do |directory|
        path = File.join(directory, "separate.feature")
        File.write(path, source)
        bus = Cucumber::Core::EventBus.new
        config = double("legacy events")
        allow(config).to receive(:on_event) { |id, &handler| bus.on(id, &handler) }
        lookup = Cucumber::Formatter::AstLookup.new(config)
        steps = []
        bus.on(:test_step_created) { |event| steps << event.test_step }
        receiver = double("compiler receiver", test_case: nil, done: nil)
        Object.new.extend(Cucumber::Core).compile([Cucumber::Core::Gherkin::Document.new(path, source)], receiver, [], bus)
        descriptors = steps.map do |step|
          ReportportalCucumber::ReportPortal::Models::StepDesc.from_test_step(step, ast_lookup: lookup)
        end
        expect(descriptors.length).to eq(4)
        tables = descriptors.select { |descriptor| descriptor.to_markdown(mode: :log).start_with?("_Data table") }
        documents = descriptors - tables
        expect(tables.length).to eq(2)
        tables.zip(["TABLE_ONLY_AMBER &lt;other&gt;", "TABLE_ONLY_BIRCH"]).each do |descriptor, value|
          expect(descriptor.to_markdown(mode: :log)).to eq("_Data table \u00b7 2 columns \u00d7 1 row_\n\n| key | value |\n| --- | --- |\n| combined | #{value} |")
          expect(descriptor.to_markdown).to start_with(order == "doc-first" ? "**Then** table" : "**Given** table")
          expect(descriptor.to_markdown).to include("| combined | #{value} |")
        end
        expect(documents.length).to eq(2)
        documents.each do |descriptor|
          expect(descriptor.to_markdown(mode: :log)).to eq("_Doc string \u00b7 text/plain_\n\n```text\nCONSTANT_DOC\n```")
          expect(descriptor.to_markdown).to start_with(order == "doc-first" ? "**Given** document" : "**Then** document")
        end
        metadata = ReportportalCucumber::Cucumber::AstMetadata.new(ast_lookup: lookup)
        formatter = ReportportalCucumber::Cucumber::Formatter.allocate
        source.lines.each_with_index.select { |line, _index| line.include?("TABLE_ONLY_") }.each do |line, index|
          row = metadata.scenario(uri: path, location_line: index + 1)
          value = line.split("|")[1].strip
          expect(row[:parameters]).to eq("value" => value)
          description = formatter.send(:extract_scenario_description, feature_uri: path, scenario_line: index + 1, metadata: row)
          expect(description).to include("Table-only substitution", value.split.first)
        end
      end
    end
  end
end
