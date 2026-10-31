# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Ledger step arguments" do
  let(:step_class) { ReportportalCucumber::ReportPortal::Models::StepDesc }

  def descriptor(rows: nil, content: nil, type: "", text: "combined <value>")
    table = Struct.new(:rows).new(rows) if rows
    doc = Struct.new(:media_type, :content).new(type, content) unless content.nil?
    source = Struct.new(:keyword, :text, :data_table, :doc_string).new("Given ", text, table, doc)
    step_class.new(step: source)
  end

  it "matches the P7 combined-argument golden without the repeated step line" do
    step = descriptor(rows: [["key", "value"], ["combined", "TABLE_ONLY_AMBER <other>"]], content: "CONSTANT_DOC")
    expected = "_Data table \u00b7 2 columns \u00d7 1 row_\n\n" \
               "| key | value |\n| --- | --- |\n| combined | TABLE_ONLY_AMBER &lt;other&gt; |\n\n" \
               "_Doc string_\n\n```\nCONSTANT_DOC\n```"
    expect(step.to_markdown(mode: :log)).to eq(expected)
    expect(step.to_markdown(mode: :description)).to eq("**Given** combined &lt;value&gt;\n\n" \
      "| key | value |\n| --- | --- |\n| combined | TABLE_ONLY_AMBER &lt;other&gt; |\n\n```\nCONSTANT_DOC\n```")
    expect(step.summary_name).to eq("Given combined <value>")
  end

  it "right-aligns numeric body columns without changing their values" do
    rows = [%w[account qty price change pct code mixed blank],
            ["a", "100", "1,234.50", "-12", "12%", "1.2.3", "10", ""],
            ["b", "1,250", "0.5", "+7", "0.5%", "USD 100", "n/a", ""],
            ["c", "12,345,678", "98.10", " 42 ", "100%", "1e3", "30", ""]].map(&:freeze).freeze
    step = descriptor(rows: rows)
    %i[log description].each do |mode|
      output = step.to_markdown(mode: mode)
      expect(output).to include("| --- | --: | --: | --: | --: | --- | --- | --- |")
      expect(output).to include("| c | 12,345,678 | 98.10 |  42  | 100% | 1e3 | 30 |  |")
    end
    expect(rows[3][3]).to eq(" 42 ")
  end

  it "never tests headers and rejects the specified numeric negative controls" do
    [".5", "1e3", "1,23", "\u221212", "", "  "].each do |value|
      output = descriptor(rows: [["123"], [value]]).to_markdown(mode: :log)
      expect(output).to include("| --- |")
    end
    expect(descriptor(rows: [["not numeric"], [""], ["+1.0%"]]).to_markdown).to include("| --: |")
    expect(descriptor(rows: [["123"]]).to_markdown(mode: :log)).to include("1 column \u00d7 0 rows", "| --- |")
  end

  it "includes hidden body rows in numeric classification" do
    rows = [["value"]] + Array.new(100) { ["10"] } + [["n/a"]]
    output = descriptor(rows: rows).to_markdown(mode: :log)
    expect(output).to include("| --- |", "[table omitted: preview limit exceeded]")
    expect(output).not_to include("n/a")
  end

  it "uses declared or detected JSON captions and compact JSON, but respects other media types" do
    ["", "json", "application/json", "application/problem+json; charset=utf-8"].each do |type|
      expect(descriptor(content: '{"values":[1,true,null]}', type: type).to_markdown(mode: :log))
        .to eq("_Doc string \u00b7 JSON_\n\n```json\n{\n  \"values\": [1, true, null]\n}\n```")
    end
    expect(descriptor(content: "<raw>\n**body**", type: "text/markdown").to_markdown(mode: :log))
      .to eq("_Doc string \u00b7 text/markdown_\n\n```markdown\n<raw>\n**body**\n```")
    expect(descriptor(content: "plain", type: "<unsafe>_*x*").to_markdown(mode: :log))
      .to start_with("_Doc string \u00b7 &lt;unsafe&gt;\\_\\*x\\*_")
    expect(descriptor(content: "null").to_markdown(mode: :log)).to eq("_Doc string \u00b7 JSON_\n\n```json\nnull\n```")
    expect(descriptor(content: "null").baseline_markdown).to end_with("```\nnull\n```")
  end

  it "keeps the existing row, column, DocString and aggregate preview bounds in both modes" do
    steps = [descriptor(rows: Array.new(120) { Array.new(32, "&" * 512) }, content: "x" * 50_000),
             descriptor(rows: [["x"] * 33], content: "line\n" * 200),
             descriptor(content: "\xFF".b * 20_000), descriptor(content: "`" * 40 + "~" * 40)]
    steps.each do |step|
      %i[log description].each do |mode|
        output = step.to_markdown(mode: mode)
        expect(output.bytesize).to be <= step_class::CONTENT_BYTE_LIMIT
        expect(output).to be_valid_encoding
        expect(output).to match(/truncated|omitted/)
      end
    end
    output = descriptor(content: "line\n" * 200).to_markdown(mode: :log)
    expect(output.scan(/^line$/).length).to eq(100)
    expect(output).to include("[truncated]")
  end

  [StandardError, JSON::GeneratorError].each do |failure_class|
    it "restores the whole original message for a Ledger JSON #{failure_class}" do
      step = descriptor(rows: [["value"], ["1"]], content: '{"a":1}', type: "json")
      logger = double("logger", warn: nil)
      allow(ReportportalCucumber).to receive(:logger).and_return(logger)
      allow(ReportportalCucumber::Presentation::LedgerJson).to receive(:format).and_raise(failure_class, "SECRET123")
      expect(step.to_markdown(mode: :log)).to eq("**Given** combined <value>\n\n| value |\n| --- |\n| 1 |\n\n```json\n{\n  \"a\": 1\n}\n```")
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  it "restores the complete old message when captions or fences fail, without helper reentry" do
    step = descriptor(rows: [["value"], ["1"]], content: "raw")
    baseline = step.baseline_markdown
    logger = double("logger", warn: nil)
    allow(ReportportalCucumber).to receive(:logger).and_return(logger)
    expect(ReportportalCucumber::Presentation::Units).to receive(:count).once.and_raise("SECRET123")
    expect(step.to_markdown(mode: :log)).to eq(baseline)
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end
end
