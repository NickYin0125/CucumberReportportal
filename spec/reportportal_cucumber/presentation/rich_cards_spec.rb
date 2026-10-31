# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RP-only Ledger accents" do
  let(:accent) { ReportportalCucumber::Presentation::Accent }
  let(:presenter) { ReportportalCucumber::Service::EvidencePresenter }
  let(:builder) { ReportportalCucumber::Service::PayloadBuilder }
  let(:logger) { double("logger", warn: nil) }
  let(:error) { RuntimeError.new("failure <other> token=SECRET123") }
  let(:body) { (1..25).map { |n| "line #{n} ` <other>" }.join("\n") }

  before { allow(ReportportalCucumber).to receive(:logger).and_return(logger) }

  def step(rows: [["account", "qty"], ["a", "001.2300"]], content: nil, type: "text/plain")
    source = Struct.new(:keyword, :text, :data_table, :doc_string).new(
      "Given ", "unchanged <name>", rows && Struct.new(:rows).new(rows),
      content && Struct.new(:content, :media_type).new(content, type)
    )
    ReportportalCucumber::ReportPortal::Models::StepDesc.new(step: source)
  end

  def exchange(status: 201, expected: nil, body: self.body)
    Automation::HttpExchange.new(method: :post, url: "https://example.test/orders?token=SECRET123",
      request: { headers: { "Authorization" => "Bearer SECRET123", "Content-Type" => "text/plain" }, body: body },
      response: { status: status, headers: { "Content-Type" => "text/plain" }, body: body },
      expected_status: expected, duration_ms: 84.25)
  end

  def batch(mode, level: :info, style: "default", message: "Attachment: original", bytes: body)
    builder.build_log_batch([{ item_uuid: "step", launch_uuid: "launch", timestamp: 1234,
      message: message, level: level,
      attachment: { name: "log.txt", baseline_name: "original.txt", mime: "text/plain", bytes: bytes, caption_style: style }
    }], presentation: mode)
  end

  def check_guard(plain, rich, level: :info)
    expect(rich.bytesize).to be <= plain.bytesize + 1024
    expect(rich.lines.first).to eq(plain.lines.first) if level == :error
    expect(rich).not_to include("SECRET123")
  end

  it "folds the complete failure tail without changing ERROR identity or raw evidence" do
    frames = "/project/step.rb:5:in 'run'\n/gems/cucumber/core.rb:6:in 'call'\n-e:1"
    arguments = { error: error, message: error.message, backtrace: frames, cwd: "/project" }
    plain = ReportportalCucumber::Presentation::FailureCard.format(**arguments)
    rich = ReportportalCucumber::Presentation::FailureCard.format(**arguments, presentation: "rich")
    check_guard(plain, rich, level: :error)
    expect(rich).to include("<details><summary>Full backtrace", "</summary>\n\n```text\n#{frames}\n```\n\n</details>")
    expect(rich.gsub(/<[^>]*>/, "")).to include(frames)
  end

  [true, false].each do |passed|
    it "accents a #{passed ? 'passed' : 'failed'} assertion without changing values or summary" do
      arguments = { name: "Order <other> *literal*", expected: "001.2300", actual: "1.23", passed: passed,
                    details: { count: 1.0, values: [1, true, nil], token: "SECRET123" } }
      plain = presenter.assertion(**arguments)
      rich = presenter.assertion(**arguments, presentation: "rich")
      expect(rich[:summary]).to eq(plain[:summary])
      check_guard(plain[:markdown], rich[:markdown], level: passed ? :info : :error)
      expect(rich[:markdown]).to include("001.2300", "[1, true, null]", "1.0", "<span style=")
      expect(rich[:markdown]).to include("&lt;other&gt; \\*literal\\*")
      expect(rich[:markdown]).to include("actual    1.23") unless passed
      expect(rich[:markdown]).to include("#{accent.pill('PASS', tone: :pass)} #{accent.title('Order <other> *literal*')}") if passed
    end
  end

  it "keeps evidence summary and diagnostics byte-identical while accenting only the card metadata" do
    arguments = { action: "Find <other>", error: error, url: "https://example.test?token=SECRET123",
                  details: { count: 12 }, artifact_names: ["error.png"] }
    plain = presenter.failure(**arguments)
    rich = presenter.failure(**arguments, presentation: "rich")
    expect(rich.values_at(:summary, :details)).to eq(plain.values_at(:summary, :details))
    check_guard(plain[:card], rich[:card], level: :error)
    expect(rich[:card]).to include("#{accent.pill('FAIL', tone: :fail)} `RuntimeError`", "evidence `error.png`")
  end

  [[201, nil, :info, :pass], [302, nil, :info, :info], [404, nil, :warn, :warn],
   [503, nil, :warn, :fail], [404, 404, :info, :warn], [201, 200, :error, :pass]].each do |status, expected, level, tone|
    it "preserves HTTP #{status}/#{expected.inspect} severity and uses the #{tone} tone" do
      http = exchange(status: status, expected: expected)
      summary = http.summary
      plain = http.to_markdown
      rich = http.to_markdown(presentation: "rich")
      expect(http.level).to eq(level)
      expect(http.summary).to eq(summary)
      check_guard(plain, rich, level: level)
      expect(rich.lines.first).to eq(plain.lines.first) if level == :warn
      expect(rich).to include(accent.pill(status.to_s, tone: tone), "84 ms", "Request headers \u00b7 2",
                              "Request body \u00b7 25 lines", "Response body \u00b7 25 lines")
      expect(rich.scan(/<details>/).length).to eq(4)
      expect(rich.scan(body).length).to eq(2)
      expect(rich).to include("</summary>\n\n```text\n", "\n```\n\n</details>")
    end
  end

  it "folds HTTP bodies only above 12 displayed lines and leaves JSON scalar spellings intact" do
    [12, 13].each do |count|
      rich = exchange(body: Array.new(count, "body").join("\n")).to_markdown(presentation: "rich")
      expect(rich.scan(/<summary>Request body/).length).to eq(count > 12 ? 1 : 0)
    end
    rich = exchange(body: { values: [1, 1.0, true, nil] }).to_markdown(presentation: "rich")
    expect(rich).to include('[1, 1.0, true, null]')
  end

  it "keeps HTTP's shared 100-line evidence budget unchanged, including truncation markers" do
    http = exchange(body: "data\n" * 200)
    plain = http.to_markdown
    rich = http.to_markdown(presentation: "rich")
    expect(rich.scan(/^data$/).length).to eq(plain.scan(/^data$/).length)
    expect(rich.scan('[preview truncated]').length).to eq(plain.scan('[preview truncated]').length)
    expect(rich.scan(/^data$/).length).to eq(98)
    check_guard(plain, rich)
  end

  it "accents only admitted table headers and keeps description, name, alignment, and numeric cells unchanged" do
    descriptor = step(content: body)
    plain = descriptor.to_markdown(mode: :log)
    rich = descriptor.to_markdown(mode: :log, presentation: "rich")
    expect(rich).to include(accent.table_header("account", columns: 2), "| --- | --: |", "| a | 001.2300 |")
    expect(rich).to include("<summary>Doc string \u00b7 text/plain \u00b7 25 lines</summary>\n\n```text\n#{body}\n```\n\n</details>")
    expect(descriptor.to_markdown(presentation: "rich")).to eq(descriptor.to_markdown)
    expect(descriptor.summary_name).to eq("Given unchanged <name>")
    check_guard(plain, rich)
  end

  [6, 7, 8].each do |columns|
    it "uses TH spans only within the closed #{columns}-column boundary" do
      descriptor = step(rows: [Array.new(columns, "header"), Array.new(columns, "1.00")])
      plain = descriptor.to_markdown(mode: :log)
      rich = descriptor.to_markdown(mode: :log, presentation: "rich")
      expect(rich.scan(accent::TH).length).to eq(columns <= 6 ? columns : 0)
      expect(rich.scan('1.00').length).to eq(columns)
      check_guard(plain, rich)
    end
  end

  it "folds only DocStrings above 20 displayed lines and preserves dynamic fences and raw content" do
    [20, 21].each do |count|
      content = (Array.new(count - 1, 'raw') + ['``` </details>']).join("\n")
      descriptor = step(rows: nil, content: content, type: "<type>&")
      rich = descriptor.to_markdown(mode: :log, presentation: "rich")
      expect(rich.scan(/<details>/).length).to eq(count > 20 ? 1 : 0)
      expect(rich).to include("````\n#{content}\n````")
      expect(rich).to include("&lt;type&gt;&amp;")
    end
  end

  it "does not sacrifice table or DocString evidence when markup exceeds the added-byte budget" do
    descriptor = step(rows: [Array.new(6, "<&" * 200), Array.new(6, "100.00")], content: body)
    plain = descriptor.to_markdown(mode: :log)
    rich = descriptor.to_markdown(mode: :log, presentation: "rich")
    check_guard(plain, rich)
    expect(rich.scan('100.00').length).to eq(plain.scan('100.00').length)
    expect(rich.scan(/^line /).length).to eq(plain.scan(/^line /).length)
    expect(logger).not_to have_received(:warn)
  end

  [:info, :error, 40000].each do |level|
    it "preserves #{level} attachment ownership, bytes, metadata, and first-caption identity" do
      plain = batch("plain", level: level)
      rich = batch("rich", level: level)
      expect(rich[:files]).to eq(plain[:files])
      expect(rich[:entries].first.reject { |k, _| k == "message" }).to eq(plain[:entries].first.reject { |k, _| k == "message" })
      p, r = [plain, rich].map { |result| result[:entries].first.fetch("message") }
      check_guard(p, r, level: level == :info ? :info : :error)
      expect(r).to include("<summary>Preview \u00b7 25 lines</summary>", body)
      expect(r.include?(accent::PILL)).to eq(level == :info)
      expect(rich[:files].first[:bytes]).to eq(body)
    end
  end

  it "leaves caller text literal while accenting an ERROR attachment below that first line" do
    caller_text = "User **Markdown** <raw>\n```\nnot a card\n```"
    plain = batch("plain", level: :error, style: nil, message: caller_text)
    rich = batch("rich", level: :error, style: nil, message: caller_text)
    p, r = [plain, rich].map { |result| result[:entries].first.fetch("message") }
    expect(r).to start_with(caller_text + "\n\n" + accent.pill("Text", tone: :info))
    check_guard(p, r, level: :error)
    expect(builder.build_log_batch([{ message: caller_text, level: :error }], presentation: "rich")[:entries].first["message"])
      .to eq(caller_text)
  end

  it "folds attachment previews only above 20 lines and retains the full attached original after clipping" do
    [20, 21, 340].each do |count|
      bytes = Array.new(count, "line").join("\n")
      plain = batch("plain", bytes: bytes)
      rich = batch("rich", bytes: bytes)
      message = rich[:entries].first["message"]
      expect(message.scan(/<details>/).length).to eq(count > 20 ? 1 : 0)
      expect(message.scan(/^line$/).length).to eq([count, 100].min)
      expect(message).to end_with("_Preview \u00b7 first 100 lines \u00b7 full file attached_") if count == 340
      expect(rich[:files]).to eq(plain[:files])
      expect(rich[:files].first[:bytes]).to eq(bytes)
    end
  end

  %i[pill title guard].each do |helper|
    it "restores the exact original assertion baseline once on Accent.#{helper} fault" do
      args = { name: "Check", expected: "001.2300", actual: 1.23, passed: true }
      baseline = presenter.send(:assertion_markdown, "PASS", args[:name], args[:expected], args[:actual], nil, presentation: false).freeze
      expect(accent).to receive(helper).once.and_raise("SECRET123")
      expect(presenter.assertion(**args, presentation: "rich")[:markdown]).to eq(baseline)
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  %i[details guard].each do |helper|
    it "restores the complete pre-Ledger failure message once on Accent.#{helper} fault" do
      frames = "/project/step.rb:5\n/gems/cucumber/core.rb:6"
      expect(accent).to receive(helper).once.and_raise("SECRET123")
      result = ReportportalCucumber::Presentation::FailureCard.format(
        error: error, message: error.message, backtrace: frames, presentation: "rich"
      )
      expect(result).to eq("failure <other> token=[REDACTED]\n#{frames}")
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  it "returns the evidence summary/details baseline, not Tier 1, if rich metadata fails" do
    arguments = { action: "failed", error: error, details: { count: 1.0 } }
    plain = presenter.failure(**arguments)
    baseline = [plain[:summary], plain[:details]].join("\n\n")
    expect(accent).to receive(:pill).once.and_raise("SECRET123")
    rich = presenter.failure(**arguments, presentation: "rich")
    expect(rich[:card]).to eq(baseline)
    expect(rich[:card]).not_to eq(plain[:card])
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end

  %i[pill title details guard].each do |helper|
    it "restores the exact original HTTP baseline once on Accent.#{helper} fault" do
      http = exchange
      baseline = http.send(:render_markdown, presentation: false).freeze
      expect(accent).to receive(helper).once.and_raise("SECRET123")
      expect(http.to_markdown(presentation: "rich")).to eq(baseline)
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  %i[table_header details guard].each do |helper|
    it "restores the whole pre-Ledger step on Accent.#{helper} fault" do
      descriptor = step(content: body)
      baseline = descriptor.baseline_markdown.freeze
      expect(accent).to receive(helper).once.and_raise("SECRET123")
      expect(descriptor.to_markdown(mode: :log, presentation: "rich")).to eq(baseline)
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  %i[pill details guard].each do |helper|
    it "restores the original attachment message once on Accent.#{helper} fault" do
      expect(accent).to receive(helper).once.and_raise("SECRET123")
      expect(batch("rich")[:entries].first["message"]).to eq("Attachment: original\n\n```text\n#{body}\n```")
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  it "lets evidence helper faults reach an active caller's original-baseline fallback" do
    baseline = "Frozen caller baseline".freeze
    expect(accent).to receive(:pill).once.and_raise("SECRET123")
    result = ReportportalCucumber::Presentation::Fallback.render(fallback: -> { baseline }) do
      presenter.failure(action: "failed", error: error, presentation: "rich")[:card]
    end
    expect(result).to equal(baseline)
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end

  it "never calls accents in default/plain renderers or rich-requested descriptions" do
    %i[pill title table_header details guard].each { |entry| expect(accent).not_to receive(entry) }
    presenter.assertion(name: "Check", expected: 1, actual: 1, passed: true)
    presenter.failure(action: "failed", error: error)
    exchange.to_markdown
    step(content: body).to_markdown(mode: :log)
    step(content: body).to_markdown(mode: :description, presentation: "rich")
    batch("plain")
  end
end
