# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Ledger client Markdown escaping" do
  let(:markdown) { ReportportalCucumber::Presentation::MarkdownText }
  let(:logger) { double("presentation logger", warn: nil) }
  let(:formatter) { ReportportalCucumber::Cucumber::Formatter.allocate }
  let(:source) do
    Struct.new(:keyword, :text, :data_table, :doc_string).new(
      "Given ", "<other> *literal*", Struct.new(:rows).new([["key", "value"], ["combined", "<other>&"]]), nil
    )
  end
  let(:descriptor) { ReportportalCucumber::ReportPortal::Models::StepDesc.new(step: source) }

  before { allow(ReportportalCucumber).to receive(:logger).and_return(logger) }

  it "escapes data outside code while leaving names and user descriptions unchanged" do
    expect(descriptor.summary_name).to eq("Given <other> *literal*")
    expect(descriptor.to_markdown).to eq("**Given** &lt;other&gt; \\*literal\\*\n\n| key | value |\n| --- | --- |\n| combined | &lt;other&gt;&amp; |")
    metadata = { description: "User **Markdown** <tag>", examples_name: "<other>", example_row_line: 12,
                 parameters: { "<key>" => "<value>\nnext" } }
    expect(formatter.send(:extract_scenario_description, feature_uri: "a.feature", scenario_line: 1, metadata: metadata))
      .to eq("User **Markdown** <tag>\n\nExamples: &lt;other&gt; \u00b7 line 12\n\n| &lt;key&gt; |\n| --- |\n| &lt;value&gt;<br>next |")
    expect(metadata[:parameters]).to eq("<key>" => "<value>\nnext")
  end

  %i[html cell inline].each do |entry|
    it "restores the entire baseline step message and warns once when #{entry} raises" do
      allow(markdown).to receive(entry).and_raise(StandardError, "api_key=SECRET123\nunsafe")
      expect(descriptor.to_markdown).to eq("**Given** <other> *literal*\n\n| key | value |\n| --- | --- |\n| combined | <other>& |")
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  it "restores the whole Outline description, not just the cell that failed" do
    allow(markdown).to receive(:cell).and_raise("SECRET123")
    metadata = { description: "Original", examples_name: "<example>", example_row_line: 12,
                 parameters: { "<key>" => "a|b\nnext" } }
    expect(formatter.send(:extract_scenario_description, feature_uri: "a.feature", scenario_line: 1, metadata: metadata))
      .to eq("Original\n\nExamples: <example>\n\nExample row: 12\n\n| <key> |\n| --- |\n| a\\|b<br>next |")
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end

  it "restores an assertion's exact baseline and keeps its terminal summary unchanged" do
    args = { name: "<name>", expected: "<expected>\nnext", actual: "<actual>", passed: false }
    presenter = ReportportalCucumber::Service::EvidencePresenter
    result = presenter.assertion(**args)
    expect(result[:markdown]).to include("## \u2717 Assertion failed \u00b7 &lt;name&gt;", "expected  <expected>\n          next\nactual    <actual>")
    allow(markdown).to receive(:fence).and_raise("SECRET123")
    failed = presenter.assertion(**args)
    expect(failed).to eq(summary: "FAIL: <name>", markdown: "## Assertion: <name>\n\n**Outcome:** FAIL\n\n| Expected | Actual |\n| --- | --- |\n| <expected> next | <actual> |")
    expect(failed[:summary]).to eq(result[:summary])
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end

  it "restores the HTTP message without changing status, summary, redaction or bodies" do
    exchange = Automation::HttpExchange.new(method: "GET", url: "https://example.test/?token=SECRET123",
                                           response: { status: 200, body: "<raw>\n**body**" })
    baseline = exchange.send(:render_markdown, presentation: false)
    summary = exchange.summary
    allow(markdown).to receive(:code).and_raise("SECRET123")
    expect(exchange.to_markdown).to eq(baseline)
    expect(exchange.to_markdown).to include("<raw>\n**body**")
    expect(exchange.summary).to eq(summary)
    expect(exchange.level).to eq(:info)
    expect(baseline).not_to include("SECRET123")
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).twice
  end

  it "keeps escaping expansion within the existing step budget" do
    source.text = "&" * 4096
    source.data_table = Struct.new(:rows).new(Array.new(100) { ["&" * 512] })
    output = descriptor.to_markdown
    expect(output.bytesize).to be <= ReportportalCucumber::ReportPortal::Models::StepDesc::CONTENT_BYTE_LIMIT
    expect(output).not_to match(/&(?!amp;)/)
  end

  it "retains the baseline text limit for ordinary oversized step text" do
    source.text = "a" * 5000
    expect(descriptor.to_markdown).to start_with("**Given** #{'a' * 4096}\\[truncated\\]")
  end
end
