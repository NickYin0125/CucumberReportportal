# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe Automation::HttpExchange, "Ledger cards" do
  let(:markdown) { ReportportalCucumber::Presentation::MarkdownText }
  let(:json) { ReportportalCucumber::Presentation::LedgerJson }
  let(:units) { ReportportalCucumber::Presentation::Units }
  let(:logger) { double("presentation logger", warn: nil) }

  before { allow(ReportportalCucumber).to receive(:logger).and_return(logger) }

  def exchange(**overrides)
    described_class.new(**{ method: "POST", url: "https://api.example.test/api/orders",
                           response: { status: 201 }, duration_ms: 84 }.merge(overrides))
  end

  it "renders the INFO golden layout with declared content types, real byte sizes, and compact JSON" do
    request = { account: "JPM-PRIME", side: "BUY", notional: 5_000_000 }
    response = { orderId: "ORD-20261031-0042", status: "ACCEPTED" }
    result = exchange(request: { headers: { "Content-Type" => "application/json" }, body: request },
                      response: { status: 201, headers: { "content-type" => "application/json" }, body: response })
    expect(result.to_markdown).to eq(<<~MARKDOWN.chomp)
      \u2713 POST /api/orders \u2192 201 \u00b7 84 ms

      _Response_ \u00b7 `application/json` \u00b7 51 B

      ```json
      { "orderId": "ORD-20261031-0042", "status": "ACCEPTED" }
      ```

      `https://api.example.test/api/orders`

      _Request_ \u00b7 `application/json` \u00b7 55 B

      ```json
      { "account": "JPM-PRIME", "side": "BUY", "notional": 5000000 }
      ```

      _Request headers \u00b7 1_

      ```text
      Content-Type: application/json
      ```

      _Response headers \u00b7 1_

      ```text
      content-type: application/json
      ```
    MARKDOWN
    expect(result.summary).to eq("POST https://api.example.test/api/orders status=201 84ms")
    expect(result.level).to eq(:info)
    expect(JSON.generate(request).bytesize).to eq(55)
    expect(JSON.generate(response).bytesize).to eq(51)
  end

  [
    [201, nil, nil, :info, "\u2713"],
    [302, nil, nil, :info, "\u2713"],
    [404, nil, nil, :warn, "## \u26a0"],
    [500, nil, nil, :warn, "## \u26a0"],
    [500, 200, nil, :error, "## \u2717"],
    [404, 404, nil, :info, "\u2713"],
    [200, 201, nil, :error, "## \u2717"],
    [nil, nil, "Connection refused", :error, "## \u2717"],
    [nil, nil, nil, :info, "\u2713"]
  ].each do |status, expected, error, level, prefix|
    it "preserves severity #{level} for status=#{status.inspect}, expected=#{expected.inspect}, error=#{error.inspect}" do
      result = exchange(method: "GET", url: "/words", response: { status: status },
                        expected_status: expected, error: error, duration_ms: 31)
      expect(result.level).to eq(level)
      expect(result.to_markdown.lines.first.chomp).to eq("#{prefix} GET /words \u2192 #{status || 'unknown'} \u00b7 31 ms")
      meta = ["`/words`"]
      meta << "expected `#{expected}`" unless expected.nil?
      meta << "error `#{error}`" unless error.nil?
      expect(result.to_markdown.split("\n\n").last).to eq(meta.join(" \u00b7 "))
    end
  end

  { 0 => "0 ms", 84 => "84 ms", 18.5 => "19 ms", 999 => "999 ms", 1000 => "1.0 s", 1400 => "1.4 s" }.each do |duration, formatted|
    it "formats duration #{duration} only in the card, not in the terminal summary" do
      result = exchange(duration_ms: duration)
      expect(result.to_markdown.lines.first.chomp).to end_with(" \u00b7 #{formatted}")
      expect(result.summary).to end_with(" #{duration}ms")
    end
  end

  it "omits absent durations, headers and bodies without inventing a content type" do
    result = exchange(duration_ms: nil, request: {}, response: { status: 200 })
    expect(result.to_markdown).to eq("\u2713 POST /api/orders \u2192 200\n\n`https://api.example.test/api/orders`")
    expect(exchange(response: { status: 200, body: "{\"safe\":true}" }).to_markdown)
      .to include("_Response_ \u00b7 13 B\n\n```json\n{ \"safe\": true }")
  end

  it "uses bytes of sanitized source bodies, not the length of pretty-printed previews" do
    body = JSON.generate(password: "SECRET123", visible: [1, true, nil])
    sanitized = Automation::EvidenceRedactor.new.redact(body)
    result = exchange(response: { status: 200, body: body })
    expect(result.to_markdown).to include("_Response_ \u00b7 #{sanitized.bytesize} B")
    expect(result.to_markdown).to include('"visible": [1, true, null]')
    expect(result.to_markdown).not_to include("SECRET123")
  end

  it "redacts the path/query title, full URL, headers, expected status, and error metadata" do
    result = exchange(url: "https://user:SECRET123@example.test/orders?token=SECRET123&page=2",
                      request: { headers: { "Authorization" => "Bearer SECRET123" } },
                      expected_status: "api_key=SECRET123", error: "Connection refused; password=SECRET123")
    card = result.to_markdown
    expect(card.lines.first).to include("/orders?token=%5BREDACTED%5D&amp;page=2")
    expect(card).to include("expected `api_key=[REDACTED]`", "error `Connection refused; password=[REDACTED]`")
    expect(card).to include("Authorization: [REDACTED]")
    expect(card + result.summary).not_to include("SECRET123")
  end

  it "escapes method, path and type data without activating user markup" do
    result = exchange(method: "get*<b>", url: "/words?label=*x*<other>&page=2",
                      response: { status: 200, headers: { "CONTENT-TYPE" => "<type> `raw`" }, body: "<raw>&" })
    card = result.to_markdown
    expect(card.lines.first).to include("GET\\*&lt;B&gt;", "\\*x\\*%3Cother%3E&amp;page=2")
    expect(card).to include("_Response_ \u00b7 `` <type> `raw` `` \u00b7 6 B")
    expect(card).to include("```text\n<raw>&\n```")
    expect(card).not_to include("&lt;raw&gt;", "&lt;type&gt;")
  end

  it "retains numeric values and spelling in Ledger JSON bodies" do
    body = { amount: 1.2345678901234567, large: 9_007_199_254_740_993, signed: -0.0,
             exponent: 1.0e30, string: "001.2300", nested: [1, true, nil] }
    card = exchange(response: { status: 200, body: body }).to_markdown
    json_text = card.split("```json\n", 2).last.split("\n```", 2).first
    expect(JSON.parse(json_text)).to eq(JSON.parse(JSON.generate(body)))
    expect(json_text).to include('"signed": -0.0', '"exponent": 1.0e+30', '"string": "001.2300"')
    expect(json_text).to include('"nested": [1, true, null]')
  end

  it "uses all four header counts and preserves header ordering" do
    headers = { "Content-Type" => "application/json", "X-One" => "one", "X-Two" => "two", "X-Three" => "three" }
    card = exchange(request: { headers: headers }).to_markdown
    expect(card).to include("_Request headers \u00b7 4_\n\n```text\nContent-Type: application/json\nX-One: one\nX-Two: two\nX-Three: three\n```")
    expect(card).not_to include("_Request_", "_Response_")
  end

  it "uses tilde fences when backtick runs exceed the helper's 32-byte maximum" do
    body = "before\n#{'`' * 32}\n<raw>\nafter"
    card = exchange(response: { status: 200, body: body }).to_markdown
    expect(card).to include("~~~text\n#{body}\n~~~")
    expect(logger).not_to have_received(:warn)
  end

  it "restores baseline evidence rather than dropping a body that cannot have a bounded fence" do
    body = "before\n#{'`' * 32}\n#{'~' * 32}\nafter"
    result = exchange(response: { status: 200, body: body })
    baseline = result.send(:render_markdown, presentation: false)
    expect(result.to_markdown).to eq(baseline)
    expect(baseline).to include(body)
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end

  { html: :markdown, inline: :markdown, code: :markdown, fence: :markdown,
    format: :json, duration: :units, bytes: :units }.each do |entry, helper|
    it "returns the exact original HTTP format with one warning when #{entry} raises" do
      result = exchange(request: { headers: { "Content-Type" => "application/json" }, body: { count: 2 } },
                        response: { status: 200, body: "<raw>" }, expected_status: 201)
      allow(public_send(helper)).to receive(entry).and_raise(StandardError, "SECRET123")
      expect(result.to_markdown).to eq(<<~MARKDOWN.chomp)
        ### Request
        - `POST` `https://api.example.test/api/orders`
        - Headers:
        ```text
        Content-Type: application/json
        ```
        - Body:
        ```json
        {
          "count": 2
        }
        ```

        ### Response
        - Status: `200`
        - Body:
        ```text
        <raw>
        ```

        - Duration: `84` ms
      MARKDOWN
      expect(result.level).to eq(:error)
      expect(result.summary).to eq("POST https://api.example.test/api/orders status=200 84ms")
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  [JSON::GeneratorError, TypeError, StandardError].each do |error|
    it "does not swallow a Ledger JSON #{error} as if the body were not JSON" do
      result = exchange(response: { status: 200, body: { count: 2 } })
      baseline = result.send(:render_markdown, presentation: false)
      allow(json).to receive(:compact_containers).and_raise(error, "SECRET123")
      expect(result.to_markdown).to eq(baseline)
      expect(logger).to have_received(:warn).once
    end
  end

  it "leaves rich inactive and preserves exact terminal bytes and both native/reporting routes" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("RP_PRESENTATION").and_return("rich")
    native = []
    rp = []
    world = Object.new
    world.define_singleton_method(:log) { |message| native << message }
    world.define_singleton_method(:rp_active?) { true }
    world.define_singleton_method(:rp_log) { |message, **options| rp << [message, options] }
    output = StringIO.new
    allow(Time).to receive(:now).and_return(Time.new(2026, 10, 31, 10, 20, 30, "+08:00"))
    bound = Automation::CucumberLogger.new(world: world, output: output, color: false)
    bound.http(method: :get, url: "https://example.test/words", response: { status: 404 }, duration_ms: 18.5)
    expect(output.string).to eq("2026-10-31 10:20:30.000  WARN   GET https://example.test/words status=404 18.5ms (Attached to Report)\n")
    expect(native).to eq(["### Request\n- `GET` `https://example.test/words`\n\n### Response\n- Status: `404`\n\n- Duration: `18.5` ms"])
    expect(rp).to eq([["## \u26a0 GET /words \u2192 404 \u00b7 19 ms\n\n`https://example.test/words`", { level: :warn, mirror: false }]])
  end
end
