# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::ReportPortal::Models::StepDesc do
  Cell = Struct.new(:value)
  Row = Struct.new(:cells)
  DataTable = Struct.new(:rows)
  DocString = Struct.new(:media_type, :content)
  Step = Struct.new(:keyword, :text, :data_table, :doc_string)

  it "renders gherkin keyword and data tables as markdown" do
    step = Step.new(
      "When ",
      "I submit a verification matrix",
      DataTable.new([
        Row.new([Cell.new("buyer"), Cell.new("region")]),
        Row.new([Cell.new("JPM"), Cell.new("APAC")]),
        Row.new([Cell.new("GS"), Cell.new("EMEA")])
      ]),
      nil
    )

    markdown = described_class.new(step: step).to_markdown

    expect(markdown).to include("**When** I submit a verification matrix")
    expect(markdown).to include("| buyer | region |")
    expect(markdown).to include("| JPM | APAC |")
  end

  it "formats JSON doc strings as fenced code blocks" do
    step = Step.new(
      "Then ",
      "the payload should be visible",
      nil,
      DocString.new("application/json", '{"buyer":"JPM","amount":10}')
    )

    markdown = described_class.new(step: step, multiline_content: '{"buyer":"JPM","amount":10}').to_markdown

    expect(markdown).to include("**Then** the payload should be visible")
    expect(markdown).to include("```json")
    expect(markdown).to include('"buyer": "JPM"')
  end
end
