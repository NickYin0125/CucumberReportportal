# frozen_string_literal: true

require "spec_helper"
require "digest"
require "json"
require "stringio"

RSpec.describe "Independent Ledger acceptance properties" do
  let(:presentation) { ReportportalCucumber::Presentation }
  let(:md) { presentation::MarkdownText }

  def corpus
    rng = Random.new(20261031)
    atoms = ["a", "<other>", "<b>x</b>", "&amp;", "|", "\\", "*", "_", "`", "~", "[", "]",
             "# ", "1. ", ">", "-", "+", "\n", "\r", "\r\n", "\0", "\t", "\x7f", "\u4e2d\u6587", "\u{1f7e2}"]
    Array.new(1_200) { Array.new(rng.rand(0..40)) { atoms.sample(random: rng) }.join } +
      ["`" * 33, "~" * 33, "`" * 33 + "~" * 33, "\xff\xfe\0".b, "<" * 65_537]
  end

  %i[html inline cell code fence].each do |method|
    it "P2.3 #{method}: 1,205 independent generated inputs never raise or close markup early" do
      values = corpus
      values.each_with_index do |value, index|
        output = md.public_send(method, value)
        case method
        when :html, :inline
          expect(output).not_to match(/[<>]/), "#{method} input #{index}: #{output.inspect}"
          expect(output).not_to match(/[\r\n]/) if method == :inline
        when :cell
          expect(output.gsub("<br>", "")).not_to match(/[<>\r\n]/)
          output.enum_for(:scan, /\|/).each do
            position = Regexp.last_match.begin(0)
            slashes = output[0...position][/\\*\z/].length
            expect(slashes.odd?).to be(true), "Unescaped pipe in generated cell #{index}"
          end
        when :code
          delimiter = output[/\A`+/]
          expect(delimiter).not_to be_nil
          expect(output).to end_with(delimiter)
          content = output[delimiter.length...-delimiter.length]
          expect(content.scan(/`+/).map(&:length).max.to_i).to be < delimiter.length
          expect(content).not_to match(/[\x00-\x1f\x7f]/)
        when :fence
          next if output.nil? # Explicit omission when neither bounded delimiter is safe.
          first, *rest = output.lines(chomp: true)
          expect(first).to match(/\A(?:`{3,32}|~{3,32})\z/)
          expect(rest.pop).to eq(first)
          rest.each { |line| expect(line).not_to match(/\A {0,3}#{Regexp.escape(first[0])}{#{first.length},}\s*\z/) }
        end
        expect(output.nil? || output.valid_encoding?).to be(true)
      end
    end
  end

  it "P7.2 tests the numeric grammar against independent positive and negative cases" do
    positives = ["100", "1,250", "12,345,678", "1,234.50", "0.5", "98.10", "-12", "+7", " 42 ", "12%", "0.5%", "100%"]
    negatives = [".5", "1e3", "1,23", "\u221212", "1.2.3", "USD 100", "n/a", "", " "]
    (positives + negatives).each do |value|
      step = Struct.new(:keyword, :text, :data_table).new("Given ", "numeric", Struct.new(:rows).new([["value"], [value]]))
      rendered = ReportportalCucumber::ReportPortal::Models::StepDesc.new(step: step).to_markdown(mode: :log)
      alignment = rendered.lines.find { |line| line.match?(/\A\| (?:--:|---) \|/) }
      expect(alignment.to_s.strip).to eq(positives.include?(value) ? "| --: |" : "| --- |")
    end
  end

  it "P1 has a byte-preserved 62-frame tail, explicit non-Exception and title limits" do
    frames = ["/outside/runtime-support.rb:65:in 'IndependentCucumber12.inner_failure'",
              "/outside/runtime-support.rb:59:in 'IndependentCucumber12.deep_failure'",
              "/outside/runtime-support.rb:136:in 'block in <top (required)>'",
              "/project/features/audit.feature:5:in 'independent fail'"] +
             (1..56).map { |i| "/ruby/gems/cucumber/runner.rb:#{i}:in 'run'" } + ["-e:1:in 'run'", "<internal:kernel>:90:in 'require'"]
    tail = frames.join("\n")
    card = presentation::FailureCard.format(error: RuntimeError.new, message: "INDEPENDENT_FULL_BACKTRACE", backtrace: tail, cwd: "/project")
    expect(card).to end_with("```text\n#{tail}\n```")
    expect(card).to include("62 frames", "56 framework and 2 runner frames not shown above")
    struct = Struct.new(:message, :backtrace).new("non Exception failure", [])
    expect(presentation::FailureCard.format(error: struct, message: struct.message, backtrace: "")).to eq("## \u2717 non Exception failure")
    expect(presentation::FailureCard.format(error: RuntimeError.new, message: "", backtrace: "")).to eq("## \u2717 RuntimeError")
    title = presentation::FailureCard.format(error: RuntimeError.new, message: "L" * 500, backtrace: "").lines.first.chomp
    expect(title.length).to eq(200)
    expect(title).to end_with("\u2026")
  end

  it "Ledger JSON round trips 1,200 nested values deterministically without changing key order" do
    rng = Random.new(20261031)
    1_200.times do |index|
      value = { "sequence" => index, "values" => [rng.rand(10_000), true, nil], "nested" => { "currency" => "USD", "notional" => rng.rand(1_000_000) } }
      actual = presentation::LedgerJson.format(value)
      expect(JSON.parse(actual)).to eq(value)
      expect(actual).to eq(presentation::LedgerJson.format(value))
      expect(JSON.parse(actual).keys).to eq(value.keys)
      expect(actual).to include('"values": [')
    end
  end

  it "P8.9 retains the existing size limits and omission marker" do
    presenter = ReportportalCucumber::Service::EvidencePresenter
    expect([presenter::SUMMARY_LIMIT, presenter::DETAILS_LIMIT, presenter::VALUE_LIMIT]).to eq([512, 16_384, 4_096])
    ["x" * 65_537, { "huge" => "x" * 65_537 }].each do |value|
      actual = presenter.assertion(name: "Oversized", expected: 1, actual: 2, passed: false, details: value)
      expect(actual[:markdown]).to include(presenter::OMITTED)
      expect(actual[:markdown].bytesize).to be < 16_384
    end
  end

  def failure_call
    presentation::FailureCard.format(error: RuntimeError.new("business"), message: "business", backtrace: "/project/step.rb:1:in 'run'", presentation: "rich")
  end

  # These are message transactions, not stubs of the safety mechanism itself.
  {
    "MarkdownText.html" => :failure, "MarkdownText.inline" => :failure,
    "MarkdownText.code" => :failure, "MarkdownText.fence" => :failure,
    "Units.count" => :failure, "Accent.details" => :failure, "Accent.guard" => :failure
  }.each do |entry, _|
    it "G9 restores the complete baseline and warns once if #{entry} raises" do
      module_name, method = entry.split(".")
      target = presentation.const_get(module_name)
      logger = double("qa_logger", warn: nil)
      allow(ReportportalCucumber).to receive(:logger).and_return(logger)
      allow(target).to receive(method.to_sym).and_raise(StandardError, "QA injected presentation failure")
      expect(failure_call).to eq("business\n/project/step.rb:1:in 'run'")
      expect(logger).to have_received(:warn).with(presentation::Fallback::WARNING).once
    end
  end
end
