# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "cucumber/core/test/location"

RSpec.describe ReportportalCucumber::Cucumber::AstMetadata do
  it "reads feature, Rule, Scenario Outline, and multiple Examples blocks from the official AST" do
    Dir.mktmpdir do |directory|
      uri = File.join(directory, "metadata.feature")
      File.write(uri, <<~FEATURE)
        # language: en
        Feature: Checkout
          Feature overview
          across two lines.

          Rule: Card payments
            Rule overview

            Scenario Outline: Charges <amount>
              Scenario details.

              Examples: Valid
                | amount | note |
                | 10     |      |

              Examples: Escaped
                | amount | note |
                | 20     | a\\|b |
      FEATURE

      metadata = described_class.new
      expect(metadata.feature(uri: uri)).to include(
        name: "Checkout",
        keyword: "Feature",
        description: "Feature overview\n  across two lines.",
        language: "en"
      )
      expect(metadata.scenario(uri: uri, location_line: 9)).to include(
        scenario_line: 9,
        description: "Scenario details.",
        examples_name: nil,
        example_row_line: nil,
        parameters: nil
      )
      expect(metadata.scenario(uri: uri, location_line: 14)).to include(
        scenario_line: 9,
        description: "Scenario details.",
        rule_name: "Card payments",
        rule_description: "Rule overview",
        examples_name: "Valid",
        example_row_line: 14,
        parameters: { "amount" => "10", "note" => "" }
      )
      expect(metadata.scenario(uri: uri, location_line: 18)).to include(
        examples_name: "Escaped",
        parameters: { "amount" => "20", "note" => "a|b" }
      )
    end
  end

  it "identifies Background steps by source line rather than matching step text" do
    Dir.mktmpdir do |directory|
      uri = File.join(directory, "background.feature")
      File.write(uri, <<~FEATURE)
        Feature: Duplicate text
          Background:
            Given the same action

          Scenario: Ordinary action
            Given the same action

          Rule: Scoped
            Background:
              Given the same action
            Scenario: Another action
              Given the same action
      FEATURE

      background = Struct.new(:location).new(::Cucumber::Core::Test::Location.new(uri, [6, 3]))
      ordinary = Struct.new(:location).new(::Cucumber::Core::Test::Location.new(uri, 6))
      rule_background = Struct.new(:location).new(::Cucumber::Core::Test::Location.new(uri, [12, 10]))

      metadata = described_class.new
      expect(metadata.step(background)).to include(background: true, background_scope: :feature)
      expect(metadata.step(ordinary)).to be_nil
      expect(metadata.step(rule_background)).to include(background: true, background_scope: :rule, rule_name: "Scoped")
    end
  end

  it "parses localized Gherkin keywords and preserves original descriptions" do
    Dir.mktmpdir do |directory|
      uri = File.join(directory, "localized.feature")
      File.write(uri, <<~FEATURE)
        # language: zh-CN
        功能: 登录
          功能说明第一行
          功能说明第二行

          场景: 成功
            当用户登录
      FEATURE

      metadata = described_class.new
      expect(metadata.feature(uri: uri)).to include(name: "登录", keyword: "功能", language: "zh-CN")
      expect(metadata.feature(uri: uri).fetch(:description)).to eq("功能说明第一行\n  功能说明第二行")
      expect(metadata.scenario(uri: uri, location_line: 6)).to include(scenario_line: 6)
    end
  end
end

RSpec.describe ReportportalCucumber::Cucumber::Formatter do
  it "keeps event parameters ahead of parsed outline values, including an empty hash" do
    Dir.mktmpdir do |directory|
      uri = File.join(directory, "precedence.feature")
      File.write(uri, <<~FEATURE)
        Feature: Parameters
          Scenario Outline: Value <amount>
            Given amount is <amount>

            Examples:
              | amount |
              | 10     |
      FEATURE

      formatter = described_class.allocate
      formatter.instance_variable_set(:@ast_metadata, ReportportalCucumber::Cucumber::AstMetadata.new)
      row_event = { feature_uri: uri, scenario_line: 7 }

      expect(formatter.send(:extract_parameters, row_event)).to eq("amount" => "10")
      expect(formatter.send(:extract_parameters, row_event.merge(parameters: { "amount" => "caller" })))
        .to eq("amount" => "caller")
      expect(formatter.send(:extract_parameters, row_event.merge(parameters: {}))).to eq({})
    end
  end

  it "renders example parameters as a safely escaped three-line Markdown table" do
    formatter = described_class.allocate
    parameters = { "slash\\pipe|" => "value\\with|pipe\r\nnext", "blank" => "" }

    expect(formatter.send(:parameter_description_table, parameters).lines(chomp: true)).to eq([
      "| slash\\\\pipe\\| | blank |",
      "| --- | --- |",
      "| value\\\\with\\|pipe<br>next |  |"
    ])
    expect(parameters).to eq({ "slash\\pipe|" => "value\\with|pipe\r\nnext", "blank" => "" })
  end
end
