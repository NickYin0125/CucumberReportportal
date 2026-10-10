# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe ReportportalCucumber::Cucumber::AstMetadata do
  it "returns independent feature, Rule, Scenario, and executed Examples tag scopes" do
    Dir.mktmpdir do |directory|
      uri = File.join(directory, "scopes.feature")
      File.write(uri, <<~FEATURE)
        @feature:common
        Feature: Scoped tags
          @rule:payments
          Rule: Card payments
            @scenario:charge
            Scenario Outline: Charge <amount>
              Given a card is charged

              @examples:first
              Examples: First set
                | amount |
                | 10     |

              @examples:second
              Examples: Second set
                | amount |
                | 20     |

          @rule:shipping
          Rule: Shipping
            @scenario:dispatch
            Scenario: Dispatch
              Given a parcel is shipped
      FEATURE

      metadata = described_class.new
      first_row = metadata.scenario(uri: uri, location_line: 12)
      second_row = metadata.scenario(uri: uri, location_line: 17)
      other_rule_scenario = metadata.scenario(uri: uri, location_line: 22)

      expect(first_row.fetch(:tag_scopes)).to eq(
        feature: ["@feature:common"], rule: ["@rule:payments"],
        scenario: ["@scenario:charge"], examples: ["@examples:first"]
      )
      expect(second_row.fetch(:tag_scopes)).to eq(
        feature: ["@feature:common"], rule: ["@rule:payments"],
        scenario: ["@scenario:charge"], examples: ["@examples:second"]
      )
      expect(first_row.fetch(:example_row_line)).to eq(12)
      expect(second_row.fetch(:example_row_line)).to eq(17)
      expect(other_rule_scenario.fetch(:tag_scopes)).to eq(
        feature: ["@feature:common"], rule: ["@rule:shipping"],
        scenario: ["@scenario:dispatch"], examples: []
      )
    end
  end

  it "preserves localized feature and scenario tag names" do
    Dir.mktmpdir do |directory|
      uri = File.join(directory, "localized.feature")
      File.write(uri, <<~FEATURE)
        # language: zh-CN
        @feature:登录
        功能: 登录
          @scenario:成功
          场景: 成功
            当用户登录
      FEATURE

      expect(described_class.new.scenario(uri: uri, location_line: 5).fetch(:tag_scopes)).to eq(
        feature: ["@feature:登录"], rule: [], scenario: ["@scenario:成功"], examples: []
      )
    end
  end

  it "returns no scenario metadata when AST source cannot be resolved" do
    metadata = described_class.new

    expect(metadata.scenario(uri: "/missing/source.feature", location_line: 7)).to be_nil
  end

  it "does not fabricate source metadata when native AST lookup raises" do
    Dir.mktmpdir do |directory|
      uri = File.join(directory, "fallback.feature")
      File.write(uri, "Feature: Fallback\n  Scenario: Available\n    Given a source exists\n")
      lookup = Object.new
      lookup.define_singleton_method(:gherkin_document) { |_path| raise "lookup unavailable" }

      expect(described_class.new(ast_lookup: lookup).scenario(uri: uri, location_line: 2)).to be_nil
    end
  end
end
