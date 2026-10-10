# frozen_string_literal: true

require "spec_helper"
require "cucumber/core"

RSpec.describe ReportportalCucumber::ReportPortal::Models::StepDesc do
  Cell = Struct.new(:value)
  Row = Struct.new(:cells)
  SourceDataTable = Struct.new(:rows)
  SourceDocString = Struct.new(:media_type, :content)
  SourceStep = Struct.new(:keyword, :text, :data_table, :doc_string)
  StepSource = Struct.new(:step)

  let(:ast_lookup_class) do
    Class.new do
      def initialize(source)
        @source = source
      end

      def step_source(_test_step)
        @source
      end
    end
  end

  def native_test_step(text:, argument: Cucumber::Core::Test::EmptyMultilineArgument.new)
    Cucumber::Core::Test::Step.new("step-id", text, nil, argument)
  end

  def descriptor(source_step, test_step)
    described_class.from_test_step(test_step, ast_lookup: ast_lookup_class.new(StepSource.new(source_step)))
  end

  it "renders localized keyword with executed Outline text and table values" do
    source = SourceStep.new(
      "Когда ",
      "I submit <buyer> for <region>",
      SourceDataTable.new([Row.new([Cell.new("<buyer>"), Cell.new("<region>")])]),
      nil
    )
    runtime_table = Cucumber::Core::Test::DataTable.new([["JPM", "APAC"]])
    test_step = native_test_step(text: "I submit JPM for APAC", argument: runtime_table)

    result = descriptor(source, test_step)

    expect(result.summary_name).to eq("Когда I submit JPM for APAC")
    expect(result.gherkin_text).to eq("I submit JPM for APAC")
    expect(result.to_markdown).to include("**Когда** I submit JPM for APAC")
    expect(result.to_markdown).to include("| JPM | APAC |")
    expect(result.to_markdown).not_to include("<buyer>", "<region>")
  end

  it "renders executed Outline DocString content and compatible JSON media types" do
    source = SourceStep.new(
      "Then ",
      "the payload for <buyer>",
      nil,
      SourceDocString.new("application/json", '{"buyer":"<buyer>"}')
    )
    runtime_doc = Cucumber::Core::Test::DocString.new('{"buyer":"JPM"}', "application/problem+json; charset=utf-8")
    result = descriptor(source, native_test_step(text: "the payload for JPM", argument: runtime_doc))

    expect(result.to_markdown).to include("**Then** the payload for JPM")
    expect(result.to_markdown).to include("```json\n{\n  \"buyer\": \"JPM\"")
    expect(result.to_markdown).not_to include("<buyer>")
  end

  it "preserves empty runtime text, cells, and DocString instead of restoring placeholders" do
    source = SourceStep.new(
      "When ",
      "<value>",
      SourceDataTable.new([Row.new([Cell.new("<value>"), Cell.new("source")])]),
      nil
    )
    table = Cucumber::Core::Test::DataTable.new([["", ""]])
    empty_text_step = native_test_step(text: "runtime text", argument: table)
    empty_text_step.instance_variable_set(:@text, "")
    result = descriptor(source, empty_text_step)

    expect(result.gherkin_text).to eq("")
    expect(result.to_markdown).to include("**When**\n\n|  |  |", "| --- | --- |")
    expect(result.to_markdown).not_to include("<value>", "source")

    source.doc_string = SourceDocString.new("text/plain", "<value>")
    source.data_table = nil
    empty_doc = Cucumber::Core::Test::DocString.new("", "text/plain")
    empty_doc_step = native_test_step(text: "runtime text", argument: empty_doc)
    empty_doc_step.instance_variable_set(:@text, "")
    doc_result = descriptor(source, empty_doc_step)
    expect(doc_result.to_markdown).not_to include("```", "<value>")
  end

  it "escapes table pipes, backslashes, newlines, and retains trailing empty cells" do
    source = SourceStep.new("Given ", "values", nil, nil)
    cells = ["left|right", "slash\\path", "line1\nline2", ""].map(&:freeze).freeze
    rows = [cells].freeze
    table = Cucumber::Core::Test::DataTable.new(rows)
    markdown = descriptor(source, native_test_step(text: "values", argument: table)).to_markdown

    expect(markdown).to include("| left\\|right | slash\\\\path | line1<br>line2 |  |")
    expect(markdown).to include("| --- | --- | --- | --- |")
    expect(table.raw).to equal(rows)
    expect(table.raw.first).to equal(cells)
    expect(cells).to all(be_frozen)
  end

  it "uses a fence longer than any embedded backtick run" do
    source = SourceStep.new("Then ", "show text", nil, SourceDocString.new("text/plain", "ignored"))
    runtime_doc = Cucumber::Core::Test::DocString.new("before ``` inside\nafter", "text/plain")
    markdown = descriptor(source, native_test_step(text: "show text", argument: runtime_doc)).to_markdown

    expect(markdown).to include("````text\nbefore ``` inside\nafter\n````")
  end

  it "uses native DocString aliases and bounded JSON auto-detection" do
    source = SourceStep.new("Then ", "payload", nil, nil)
    {
      "json" => ["```json", '"key": "value"'],
      "text" => ["```text", "plain value"],
      "markdown" => ["```markdown", "**bold**"]
    }.each do |content_type, (fence, content)|
      doc = Cucumber::Core::Test::DocString.new(content, content_type)
      markdown = descriptor(source, native_test_step(text: "payload", argument: doc)).to_markdown
      expect(markdown).to include(fence, content)
    end

    json_without_type = Cucumber::Core::Test::DocString.new('{"key":"value"}', "")
    markdown = descriptor(source, native_test_step(text: "payload", argument: json_without_type)).to_markdown
    expect(markdown).to include("```json", '"key": "value"')
  end

  it "falls back to bounded text when auto-detected JSON pretty output exceeds the remaining budget" do
    rows = Array.new(16) { Row.new([Cell.new("t" * 512)]) }
    json = "[#{Array.new(2000, "0").join(",")}]"
    source = SourceStep.new("Then ", "payload", SourceDataTable.new(rows), SourceDocString.new("", json))
    markdown = described_class.new(step: source).to_markdown

    expect(markdown).to include("[JSON pretty-print skipped; showing text]", json)
    expect(markdown).not_to include("[DocString omitted: preview limit exceeded]")
    expect(markdown.bytesize).to be <= described_class::CONTENT_BYTE_LIMIT
  end

  it "bounds wide and aggregate tables without emitting partial rows" do
    source = SourceStep.new("Given ", "wide table", nil, nil)
    wide = Cucumber::Core::Test::DataTable.new([["x"] * (described_class::TABLE_COLUMN_LIMIT + 1)])
    wide_markdown = descriptor(source, native_test_step(text: "wide table", argument: wide)).to_markdown
    expect(wide_markdown).to include("[table omitted: preview limit exceeded]")
    expect(wide_markdown).not_to include("| x | x |")

    aggregate = Cucumber::Core::Test::DataTable.new(Array.new(100) { Array.new(32, "x" * 80) })
    aggregate_markdown = descriptor(source, native_test_step(text: "wide table", argument: aggregate)).to_markdown
    expect(aggregate_markdown.bytesize).to be <= described_class::CONTENT_BYTE_LIMIT
    expect(aggregate_markdown).to include("[table omitted: preview limit exceeded]")
    table_lines = aggregate_markdown.lines.grep(/^\|/)
    expect(table_lines).not_to be_empty
    expect(table_lines).to all(satisfy { |line| line.count("|") == 33 })

    source.doc_string = SourceDocString.new("text/plain", "d" * described_class::CONTENT_BYTE_LIMIT)
    combined_markdown = descriptor(source, native_test_step(text: "wide table", argument: aggregate)).to_markdown
    expect(combined_markdown.bytesize).to be <= described_class::CONTENT_BYTE_LIMIT
    expect(combined_markdown).to include("[DocString omitted: preview limit exceeded]")
  end

  it "accounts for separators in adversarial near-limit tables" do
    source = SourceStep.new("Given ", "grid", nil, nil)
    rows = Array.new(90) { ["x" * 180] }
    table = Cucumber::Core::Test::DataTable.new(rows)
    markdown = descriptor(source, native_test_step(text: "grid", argument: table)).to_markdown

    expect(markdown.bytesize).to be <= described_class::CONTENT_BYTE_LIMIT
    expect(markdown).to include("[table omitted: preview limit exceeded]")
  end

  it "bounds large UTF-8 DocStrings and avoids parsing oversized JSON" do
    source = SourceStep.new("Then ", "large content", nil, nil)
    large_utf8 = ("界" * 20_000)
    result = descriptor(
      source,
      native_test_step(text: "large content", argument: Cucumber::Core::Test::DocString.new(large_utf8, "text/plain"))
    )
    markdown = result.to_markdown

    expect(markdown).to be_valid_encoding
    expect(markdown).to include("[truncated]")
    expect(markdown.bytesize).to be < described_class::CONTENT_BYTE_LIMIT + 128

    large_json = "not-json\n" * 120
    json_result = descriptor(
      source,
      native_test_step(text: "large content", argument: Cucumber::Core::Test::DocString.new(large_json, "application/json"))
    ).to_markdown
    expect(json_result).to include("[truncated]")
    expect(json_result.scan("not-json").length).to eq(described_class::CONTENT_LINE_LIMIT)
  end

  it "renders malformed and invalid-byte DocStrings safely within the preview cap" do
    source = SourceStep.new("Then ", "content", nil, nil)
    malformed = Cucumber::Core::Test::DocString.new("{invalid", "application/json")
    malformed_markdown = descriptor(source, native_test_step(text: "content", argument: malformed)).to_markdown
    expect(malformed_markdown).to include("```json\n{invalid\n[invalid JSON; shown as text]\n```")

    invalid = ("ok" * 20) + "\xFF" + ("x" * 20_000)
    invalid.force_encoding(Encoding::UTF_8)
    invalid_doc = Cucumber::Core::Test::DocString.new(invalid, "text/plain")
    markdown = descriptor(source, native_test_step(text: "content", argument: invalid_doc)).to_markdown
    expect(markdown).to be_valid_encoding
    expect(markdown).to include("�", "[truncated]")
    expect(markdown.bytesize).to be < described_class::CONTENT_BYTE_LIMIT + 128
  end

  it "keeps repaired invalid UTF-8 and non-truncated large JSON within exact preview caps" do
    source = SourceStep.new("Then ", "content", nil, nil)
    invalid = "\xFF" * described_class::CONTENT_BYTE_LIMIT
    invalid.force_encoding(Encoding::UTF_8)
    doc = Cucumber::Core::Test::DocString.new(invalid, "text")
    markdown = descriptor(source, native_test_step(text: "content", argument: doc)).to_markdown
    expect(markdown).to be_valid_encoding
    expect(markdown.bytesize).to be <= described_class::CONTENT_BYTE_LIMIT
    expect(markdown).to include("[truncated]")

    large_json = Cucumber::Core::Test::DocString.new("\"#{'x' * 5000}\"", "json")
    large_markdown = descriptor(source, native_test_step(text: "content", argument: large_json)).to_markdown
    expect(large_markdown).to include("[JSON pretty-print skipped; showing text]")
    expect(large_markdown).not_to include("[truncated]")
    expect(large_markdown.bytesize).to be <= described_class::CONTENT_BYTE_LIMIT
  end

  it "bounds fence overhead and omits DocStrings with no safe short fence" do
    source = SourceStep.new("Then ", "content", nil, nil)
    backtick_content = "`" * (described_class::MAX_FENCE_BYTES + 10)
    backtick_doc = Cucumber::Core::Test::DocString.new(backtick_content, "text")
    backtick_markdown = descriptor(source, native_test_step(text: "content", argument: backtick_doc)).to_markdown
    expect(backtick_markdown).to include("~~~text")
    expect(backtick_markdown.bytesize).to be <= described_class::CONTENT_BYTE_LIMIT

    unsafe_content = ("`" * 40) + ("~" * 40)
    unsafe_doc = Cucumber::Core::Test::DocString.new(unsafe_content, "text")
    unsafe_markdown = descriptor(source, native_test_step(text: "content", argument: unsafe_doc)).to_markdown
    expect(unsafe_markdown).to include("[DocString omitted: preview limit exceeded]")
    expect(unsafe_markdown.bytesize).to be <= described_class::CONTENT_BYTE_LIMIT
  end

  it "keeps source-only rendering compatible" do
    source = SourceStep.new(
      "When ",
      "I submit a verification matrix",
      SourceDataTable.new([
        Row.new([Cell.new("buyer"), Cell.new("region")]),
        Row.new([Cell.new("JPM"), Cell.new("APAC")]),
        Row.new([Cell.new("GS"), Cell.new("EMEA")])
      ]),
      nil
    )
    result = described_class.new(step: source)

    expect(result.summary_name).to eq("When I submit a verification matrix")
    expect(result.to_markdown).to include("| buyer | region |", "| JPM | APAC |", "| GS | EMEA |")
    expect(result).to be_rich
  end

  it "formats source-only JSON DocStrings and leaves plain steps non-rich" do
    source = SourceStep.new("Then ", "the payload should be visible", nil,
                            SourceDocString.new("application/json", '{"buyer":"JPM","amount":10}'))
    markdown = described_class.new(step: source, multiline_content: '{"buyer":"JPM","amount":10}').to_markdown
    plain = described_class.new(step: SourceStep.new("Given ", "a user exists", nil, nil))

    expect(markdown).to include("**Then** the payload should be visible", "```json", '"buyer": "JPM"')
    expect(plain).not_to be_rich
  end
end
