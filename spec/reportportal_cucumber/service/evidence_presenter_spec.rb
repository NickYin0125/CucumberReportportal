# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe ReportportalCucumber::Service::EvidencePresenter do
  let(:markdown) { ReportportalCucumber::Presentation::MarkdownText }
  let(:json) { ReportportalCucumber::Presentation::LedgerJson }
  let(:logger) { double("presentation logger", warn: nil) }
  let(:call_log) do
    "Timeout 1200ms exceeded.\nCall log:\n" \
      '  - waiting for get_by_role("button", name="M2 video intentionally absent control", exact=True)'
  end

  before { allow(ReportportalCucumber).to receive(:logger).and_return(logger) }

  def assertion(**overrides)
    described_class.assertion(**{ name: "Limits", expected: 1, actual: 2, passed: false }.merge(overrides))
  end

  def failure(**overrides)
    described_class.failure(**{ action: "Submit", error: RuntimeError.new("Failed") }.merge(overrides))
  end

  def fenced_blocks(text)
    blocks = []
    lines = text.lines(chomp: true)
    until lines.empty?
      opening = lines.shift.match(/\A(`{3,}|~{3,})(text|json)\z/)
      next unless opening

      content = []
      content << lines.shift until lines.empty? || lines.first == opening[1]
      expect(lines.shift).to eq(opening[1]), "unclosed evidence fence"
      blocks << [opening[2], content.join("\n")]
    end
    blocks
  end

  it "matches the failed assertion golden with ten-column multiline continuation" do
    result = assertion(name: "Intentionally absent Typewords control can be clicked",
                       expected: "click succeeds", actual: call_log,
                       details: { api_key: "SECRET123", recording: "Playwright viewport recording is still active" })
    expect(result).to eq(
      summary: "FAIL: Intentionally absent Typewords control can be clicked",
      markdown: <<~MARKDOWN.chomp
        ## \u2717 Assertion failed \u00b7 Intentionally absent Typewords control can be clicked

        ```text
        expected  click succeeds
        actual    Timeout 1200ms exceeded.
                  Call log:
                    - waiting for get_by_role("button", name="M2 video intentionally absent control", exact=True)
        ```

        _Details_ `api_key` = `[REDACTED]` \u00b7 `recording` = `Playwright viewport recording is still active`
      MARKDOWN
    )
  end

  it "matches the passed assertion golden without a heading or actual block" do
    expect(assertion(name: "Order is accepted", expected: "ACCEPTED", actual: "ACCEPTED", passed: true)).to eq(
      summary: "PASS: Order is accepted",
      markdown: "\u2713 Assertion passed \u00b7 Order is accepted \u00b7 expected `ACCEPTED`"
    )
  end

  ["x" * 61, "x" * 120, "first\nsecond", "first\rsecond"].each do |expected|
    it "omits the passed chip for a long or multiline expected value #{expected.inspect}" do
      result = assertion(expected: expected, passed: true)
      expect(result[:markdown]).to eq("\u2713 Assertion passed \u00b7 Limits")
    end
  end

  it "includes exactly sixty characters and details on passed assertions" do
    result = assertion(expected: "x" * 60, passed: true, details: { count: 2, allowed: false, missing: nil })
    expect(result[:markdown]).to eq(
      "\u2713 Assertion passed \u00b7 Limits \u00b7 expected `#{'x' * 60}`\n\n" \
      "_Details_ `count` = `2` \u00b7 `allowed` = `false` \u00b7 `missing` = `null`"
    )
  end

  it "formats structured expected/actual as Ledger JSON without changing values or key order" do
    expected = { currency: "USD", notional: 5_000_000 }
    actual = { currency: "USD", notional: 4_000_000 }
    result = assertion(expected: expected.freeze, actual: actual.freeze)
    expect(fenced_blocks(result[:markdown])).to eq([["text",
      'expected  { "currency": "USD", "notional": 5000000 }' + "\n" +
      'actual    { "currency": "USD", "notional": 4000000 }']])
    expect(expected).to eq(currency: "USD", notional: 5_000_000)
  end

  [1.0, -0.0, 1.2345678901234567, 1.0e30, 9_007_199_254_740_993, true, false, nil].each do |value|
    it "preserves the JSON scalar spelling for #{value.inspect}" do
      comparison = fenced_blocks(assertion(expected: value, actual: value)[:markdown]).first.last
      expect(comparison).to eq("expected  #{JSON.generate(value)}\nactual    #{JSON.generate(value)}")
    end
  end

  it "does not coerce numeric-looking strings, blanks, or surrounding spaces" do
    ["001.2300", "+7", "98.10%", "1e3", "", " 42 "].each do |value|
      expect(fenced_blocks(assertion(expected: value, actual: value)[:markdown]).first.last)
        .to eq("expected  #{value}\nactual    #{value}")
    end
  end

  [{ a: { b: [1, 2] } }, (1..8).to_h { |i| ["k#{i}", i] }, { long: "v" * 81 }, [1, true, nil], "raw <other>"].each do |details|
    it "uses a Ledger JSON details fence for #{details.inspect}" do
      result = assertion(details: details)
      expect(result[:markdown]).to include("_Details_\n\n```json\n")
      expect(JSON.parse(fenced_blocks(result[:markdown]).last.last)).to eq(JSON.parse(JSON.generate(details)))
    end
  end

  it "uses pairs at the six-key and eighty-character boundaries" do
    details = (1..6).to_h { |i| ["k#{i}", "v" * 80] }
    result = assertion(details: details)
    expect(result[:markdown]).not_to include("```json")
    expect(result[:markdown]).to include("_Details_ `k1` = `#{'v' * 80}`")
    expect(result[:markdown]).to include("`k6` = `#{'v' * 80}`")
  end

  it "matches the failure evidence golden while retaining baseline summary and details" do
    error_class = Class.new(StandardError)
    stub_const("Playwright::TimeoutError", error_class)
    result = failure(action: "Missing Typewords control while recording", error: error_class.new(call_log),
                     url: "http://localhost:5567/words", artifact_names: ["failure.png", "response.json"],
                     details: { api_key: "SECRET123" })
    expect(result[:card]).to eq(<<~MARKDOWN.chomp)
      ## \u2717 Missing Typewords control while recording

      `Playwright::TimeoutError` at `http://localhost:5567/words` \u00b7 evidence `failure.png`, `response.json`

      ```text
      #{call_log}
      ```

      _Details_ `api_key` = `[REDACTED]`
    MARKDOWN
    expect(result[:summary]).to eq("Missing Typewords control while recording | Playwright::TimeoutError: #{call_log} | " \
                                   "URL: http://localhost:5567/words | Evidence: failure.png, response.json")
    expect(result[:details]).to eq('{"api_key":"[REDACTED]"}')
    expect(result.values.join).not_to include("SECRET123")
  end

  it "omits absent metadata and empty messages and defaults empty or whitespace actions" do
    ["", " \n\t"].each do |action|
      result = failure(action: action, error: RuntimeError.new(""))
      expect(result[:card]).to eq("## \u2717 Failure evidence\n\n`RuntimeError`")
      expect(result[:details]).to eq("")
    end
  end

  it "accepts artifact descriptors and retains their existing count and name bounds" do
    artifacts = [{ name: "one.png" }, { "name" => "two.json" }, {}] + Array.new(20, "x" * 200)
    result = failure(artifacts: artifacts, artifact_names: ["ignored.txt"])
    expect(result[:card]).to include("evidence `one.png`, `two.json`, `evidence`")
    expect(result[:card].scan("#{'x' * 125}...").length).to eq(13)
    expect(result[:card]).not_to include("ignored.txt", "x" * 129)
  end

  it "escapes titles but preserves literal data in chips and safe dynamic fences" do
    data = "raw <other> & *star*\n```\n~~~~\nend"
    result = assertion(name: "<other> & *star*", expected: data, actual: data,
                       details: { "<key>" => "<value> `tick` &" })
    expect(result[:markdown]).to start_with("## \u2717 Assertion failed \u00b7 &lt;other&gt; &amp; \\*star\\*")
    expect(result[:markdown]).to include("````text\n", "`<key>` = ``<value> `tick` &``")
    expect(fenced_blocks(result[:markdown]).first.last).to include("<other> & *star*")
    result = failure(action: "<action> *raw*", error: RuntimeError.new(data), artifact_names: ["`<file>`"])
    expect(result[:card]).to start_with("## \u2717 &lt;action&gt; \\*raw\\*")
    expect(result[:card]).to include("evidence `` `<file>` ``")
    expect(fenced_blocks(result[:card])).to eq([["text", data]])
  end

  it "sanitizes before rendering and keeps omission markers and all existing public bounds" do
    oversized = "SECRET123" + "x" * described_class::MAX_SANITIZATION_INPUT_BYTES
    result = failure(action: "safe", error: RuntimeError.new(oversized), details: oversized,
                     url: "https://user:SECRET123@example.test/?api_key=SECRET123")
    check = assertion(expected: oversized, actual: oversized, details: oversized)
    expect(result[:details]).to eq(described_class::OMITTED)
    expect(result[:summary].bytesize).to be <= described_class::SUMMARY_LIMIT
    expect(result[:card]).to include(described_class::OMITTED, "api_key=%5BREDACTED%5D")
    [result[:card], check[:markdown]].each do |card|
      expect(card.bytesize).to be <= described_class::DETAILS_LIMIT
      expect(card).not_to include("SECRET123")
      expect(fenced_blocks(card)).not_to be_empty
    end
  end

  it "keeps huge escaped titles and multiline evidence bounded without clipping a closing fence" do
    result = assertion(name: "<&*" * 1400, expected: "x\n" * 3000, actual: "y\n" * 3000,
                       details: "d" * 20_000)
    expect(result[:markdown].bytesize).to be <= described_class::DETAILS_LIMIT
    expect(result[:markdown]).to start_with("## \u2717 Assertion failed")
    expect(fenced_blocks(result[:markdown]).length).to eq(2)
    expect(result[:markdown]).to include("...")
    expect(logger).not_to have_received(:warn)
  end

  it "preserves every multiline value line when the indented comparison fits the card budget" do
    value = (["first"] + Array.new(500, "x") + ["last"]).join("\n")
    result = assertion(expected: value, actual: value)
    indented = value.gsub("\n", "\n          ")
    expect(fenced_blocks(result[:markdown])).to eq([["text", "expected  #{indented}\nactual    #{indented}"]])
    expect(result[:markdown].bytesize).to be <= described_class::DETAILS_LIMIT
  end

  it "retains valid UTF-8 and does not mutate caller-owned diagnostics" do
    data = "safe\xFF\napi_key=SECRET123".b.freeze
    details = { text: data }.freeze
    result = failure(error: RuntimeError.new(data), details: details)
    expect(result.values).to all(be_valid_encoding)
    expect(result.values.join).not_to include("SECRET123")
    expect(details[:text].bytes).to eq(data.bytes)
    expect(data.encoding).to eq(Encoding::BINARY)
  end

  { html: :markdown, inline: :markdown, code: :markdown, fence: :markdown, format: :json }.each do |entry, helper|
    it "restores the exact original assertion and warns once on a #{entry} fault" do
      args = { name: "<name>", expected: 1, actual: "a|b\nnext", passed: false, details: { note: "safe" } }
      allow(public_send(helper)).to receive(entry).and_raise(StandardError, "SECRET123")
      expect(described_class.assertion(**args)).to eq(
        summary: "FAIL: <name>",
        markdown: "## Assertion: <name>\n\n**Outcome:** FAIL\n\n| Expected | Actual |\n| --- | --- |\n" \
                  "| 1 | a\\|b next |\n\n### Details\n\n{\"note\":\"safe\"}"
      )
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end

    it "restores exact original failure evidence and warns once on a #{entry} fault" do
      allow(public_send(helper)).to receive(entry).and_raise(StandardError, "SECRET123")
      result = failure(action: "<action>", details: { nested: [1, 2] })
      expect(result).to eq(summary: "<action> | RuntimeError: Failed", details: '{"nested":[1,2]}',
                           card: "<action> | RuntimeError: Failed\n\n{\"nested\":[1,2]}")
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  [StandardError, JSON::GeneratorError, EncodingError].each do |error|
    it "propagates a helper's internal #{error} to the outer fallback instead of dropping details" do
      allow(json).to receive(:compact_containers).and_raise(error, "SECRET123")
      result = failure(details: { nested: [1, 2] })
      expect(result[:card]).to eq("Submit | RuntimeError: Failed\n\n{\"nested\":[1,2]}")
      expect(logger).to have_received(:warn).once
    end
  end

  it "propagates an internal Markdown helper fault through nested fallback calls" do
    allow(markdown).to receive(:longest_run).and_raise("SECRET123")
    expect(failure[:card]).to eq("Submit | RuntimeError: Failed")
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end

  it "restores all evidence when Ledger JSON cannot format a sanitized value" do
    allow(json).to receive(:format).and_return(nil)
    expect(failure(details: { nested: [1, 2] })[:card]).to eq("Submit | RuntimeError: Failed\n\n{\"nested\":[1,2]}")
    expect(logger).to have_received(:warn).once
  end

  it "renders identical cards repeatedly without mutating structured evidence" do
    expected = { currency: "USD", values: [1.0, 2, true, nil] }
    actual = { currency: "USD", values: [1.0, 3, false, nil] }
    details = { api_key: "SECRET123", nested: { values: [1, 2] } }
    before = Marshal.dump([expected, actual, details])
    args = { expected: expected, actual: actual, details: details }
    expect(assertion(**args)).to eq(assertion(**args))
    expect(failure(details: details)).to eq(failure(details: details))
    expect(Marshal.dump([expected, actual, details])).to eq(before)
  end

  it "falls back without losing evidence when no bounded dynamic fence exists" do
    data = "raw\n#{'`' * 32}\n#{'~' * 32}\nend"
    result = failure(error: RuntimeError.new(data))
    expect(result[:card]).to eq(result[:summary])
    expect(result[:card]).to include(data)
    expect(logger).to have_received(:warn).once
  end

  it "keeps terminal bytes, native routing, and levels unchanged with rich requested but inactive" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("RP_PRESENTATION").and_return("rich")
    native = []
    rp = []
    world = Object.new
    world.define_singleton_method(:log) { |message| native << message }
    world.define_singleton_method(:rp_active?) { true }
    world.define_singleton_method(:rp_log) { |message, **options| rp << [message, options] }
    output = StringIO.new
    now = Time.new(2026, 10, 31, 10, 20, 30, "+08:00")
    allow(Time).to receive(:now).and_return(now)
    bound = Automation::CucumberLogger.new(world: world, output: output, color: false)
    bound.assertion(name: "Limits", expected: 1, actual: 2, passed: false)
    bound.assertion(name: "Limits", expected: 1, actual: 1, passed: true)
    expect(output.string).to eq("2026-10-31 10:20:30.000  ERROR  FAIL: Limits (Attached to Report)\n" \
                               "2026-10-31 10:20:30.000  INFO   PASS: Limits (Attached to Report)\n")
    expect(rp).to eq([[native[0], { level: :error, mirror: false }], [native[1], { level: :info, mirror: false }]])
    expect(native.length).to eq(2)
    expect(native.join).not_to include("<details", "<span", "<summary")
  end
end
