# frozen_string_literal: true

require "spec_helper"

RSpec.describe Automation::HttpExchange, "response-first presentation" do
  let(:request) do
    { headers: { "Content-Type" => ["application/json"], "X-Route" => ["primary", "secondary"] },
      body: '{"item":42}' }
  end
  let(:response) do
    { status: 201, headers: { "content-type" => ["application/json"], "Vary" => ["Accept", "Accept-Encoding"] },
      body: { "result" => "received" } }
  end

  def exchange(**overrides)
    described_class.new(**{ method: :post, url: "https://api.example.test/orders", request: request,
                           response: response, duration_ms: 84 }.merge(overrides))
  end

  def fenced_bodies(card)
    card.scan(/^```(?:text|json)\n(.*?)\n```$/m).flatten
  end

  def evidence_lines(card)
    fenced_bodies(card).flat_map { |body| body.lines(chomp: true) }
                       .reject { |line| line == described_class::TRUNCATION_MARKER }
  end

  let(:plain_headers) do
    <<~MARKDOWN.chomp
      _Request headers \u00b7 2_

      ```text
      Content-Type: application/json
      X-Route: primary
      X-Route: secondary
      ```

      _Response headers \u00b7 2_

      ```text
      content-type: application/json
      Vary: Accept
      Vary: Accept-Encoding
      ```
    MARKDOWN
  end

  let(:rich_headers) do
    <<~MARKDOWN.chomp
      <details><summary>Request headers \u00b7 2</summary>

      ```text
      Content-Type: application/json
      X-Route: primary
      X-Route: secondary
      ```

      </details>

      <details><summary>Response headers \u00b7 2</summary>

      ```text
      content-type: application/json
      Vary: Accept
      Vary: Accept-Encoding
      ```

      </details>
    MARKDOWN
  end

  [
    [201, 201, nil, :info, "\u2713", "color:#276E50;background:#E6F5EE"],
    [404, nil, nil, :warn, "## \u26a0", "color:#8A5A00;background:#FFF3D6"],
    [503, nil, nil, :warn, "## \u26a0", "color:#B23B3B;background:#FBEAEA"],
    [500, 201, "upstream failure", :error, "## \u2717", nil]
  ].each do |status, expected, error, level, prefix, tone|
    %w[plain rich].each do |mode|
      it "matches the exact ordered #{mode} golden at #{level} / #{status}" do
        result = exchange(response: response.merge(status: status), expected_status: expected, error: error)
        title = "#{prefix} POST /orders \u2192 #{status} \u00b7 84 ms"
        metadata = "`https://api.example.test/orders`"
        metadata += " \u00b7 expected `#{expected}`" if expected
        metadata += " \u00b7 error `#{error}`" if error
        accented = mode == "rich" && level != :error
        if accented
          pill = %(<span style="display:inline-block;padding:0 7px;border-radius:9px;font:600 10.5px/1.7 system-ui,-apple-system,Segoe UI,sans-serif;letter-spacing:.04em;#{tone}">#{status}</span>)
          if level == :info
            title = %(#{pill} <span style="font:600 13.5px/1.5 system-ui,-apple-system,Segoe UI,sans-serif;color:#2B2B2D">POST /orders</span> \u00b7 84 ms)
          else
            metadata = "#{pill} \u00b7 #{metadata}"
          end
        end

        expect(result.level).to eq(level)
        expect(result.to_markdown(presentation: mode)).to eq(<<~MARKDOWN.chomp)
          #{title}

          _Response_ \u00b7 `application/json` \u00b7 21 B

          ```json
          { "result": "received" }
          ```

          #{metadata}

          _Request_ \u00b7 `application/json` \u00b7 11 B

          ```json
          { "item": 42 }
          ```

          #{accented ? rich_headers : plain_headers}
        MARKDOWN
        expect(result.to_markdown(presentation: "rich").b).to eq(result.to_markdown.b) if level == :error
      end
    end
  end

  %w[plain rich].each do |mode|
    it "keeps empty bodies visible before headers in #{mode} mode" do
      result = exchange(request: request.merge(body: ""), response: response.merge(body: ""))
      card = result.to_markdown(presentation: mode)
      expect(card).to include(<<~MARKDOWN.chomp)
        _Response_ \u00b7 `application/json` \u00b7 0 B

        ```text

        ```

        `https://api.example.test/orders`

        _Request_ \u00b7 `application/json` \u00b7 0 B

        ```text

        ```
      MARKDOWN
      expect(fenced_bodies(card)).to eq(["", "", "Content-Type: application/json\nX-Route: primary\nX-Route: secondary",
                                       "content-type: application/json\nVary: Accept\nVary: Accept-Encoding"])
    end

    [[:request, :response], [:response, :request]].each do |absent, present|
      it "omits a nil #{absent} body without moving the #{present} body behind headers in #{mode} mode" do
        section = public_send(absent).merge(body: nil)
        card = exchange(**{ absent => section }).to_markdown(presentation: mode)
        expect(card).not_to include("_#{absent.capitalize}_")
        expect(card.index("_#{present.capitalize}_")).to be < card.index("Request headers")
        expect(fenced_bodies(card).length).to eq(3)
      end
    end

    it "preserves every repeated header value, including whitespace and empty values, in #{mode} mode" do
      values = [" first, second ", "", "<raw> & *literal*", "last"]
      card = exchange(request: { headers: { "X-Raw" => values, "X-Scalar" => "scalar" } }).to_markdown(presentation: mode)
      expect(fenced_bodies(card)[1]).to eq("X-Raw:  first, second \nX-Raw: \nX-Raw: <raw> & *literal*\nX-Raw: last\nX-Scalar: scalar")
      expect(card).not_to include(values.inspect)
    end

    it "shows every content-type value as text, not an array, in #{mode} subtitles" do
      types = ["application/json; charset=utf-8", "application/problem+json"]
      card = exchange(response: response.merge(headers: { "CONTENT-TYPE" => types })).to_markdown(presentation: mode)
      expect(card).to include("_Response_ \u00b7 `application/json; charset=utf-8, application/problem+json` \u00b7 21 B")
      expect(fenced_bodies(card).last).to eq("CONTENT-TYPE: application/json; charset=utf-8\nCONTENT-TYPE: application/problem+json")
      expect(card).not_to include(types.inspect)
    end

    it "does not invent a media type or a header value for empty arrays in #{mode} mode" do
      card = exchange(response: response.merge(headers: { "content-type" => [] })).to_markdown(presentation: mode)
      expect(card).to include("_Response_ \u00b7 21 B")
      expect(fenced_bodies(card).last).to eq("")
      expect(card).not_to include("[]", "content-type:")
    end

    it "keeps oversized repeated content types within the existing metadata and preview bounds in #{mode} mode" do
      types = Array.new(120) { |index| "application/x-#{index}-#{'a' * 1000}" }
      result = exchange(response: response.merge(headers: { "content-type" => types }))
      card = result.to_markdown(presentation: mode)
      subtitle = card.lines.find { |line| line.start_with?("_Response_") }
      expect(subtitle).to include("...[truncated]")
      expect(subtitle.bytesize).to be <= described_class::MAX_METADATA_BYTES + 32
      expect(card.bytesize).to be < 20 * 1024
      expect(card).to include(described_class::TRUNCATION_MARKER)
      expect(fenced_bodies(card).sum { |body| body.split("\n#{described_class::TRUNCATION_MARKER}", 2).first.bytesize })
        .to be <= described_class::MAX_PREVIEW_BYTES
      expect(result.instance_variable_get(:@response)[:headers]["content-type"]).to eq(types)
    end

    [[:info, 201, nil], [:warn, 503, nil], [:error, 500, 201]].each do |level, status, expected|
      it "shares exactly 100 preview lines across bodies and repeated headers at #{level} in #{mode} mode" do
        response_body = Array.new(60, "response").join("\n")
        request_body = Array.new(30, "request").join("\n")
        values = (1..20).map { |number| "value-#{number}" }
        result = exchange(request: { body: request_body, headers: { "X-Request" => values } },
                          response: { status: status, body: response_body, headers: { "X-Response" => values } },
                          expected_status: expected)
        card = result.to_markdown(presentation: mode)
        marker = described_class::TRUNCATION_MARKER
        expect(described_class::MAX_PREVIEW_LINES).to eq(100)
        expect(fenced_bodies(card)).to eq([
          response_body, request_body, values.first(10).map { |value| "X-Request: #{value}" }.join("\n") + "\n#{marker}", marker
        ])
        expect(evidence_lines(card).length).to eq(100)
        expect(evidence_lines(card).join("\n").bytesize).to be <= described_class::MAX_PREVIEW_BYTES
        expect(result.instance_variable_get(:@request)[:headers]["X-Request"]).to eq(values)
        expect(result.instance_variable_get(:@response)[:headers]["X-Response"]).to eq(values)
        expect(result.level).to eq(level)
      end

      it "shares exactly 16 KiB across response then request at #{level} in #{mode} mode without clipping snapshots" do
        response_body = "r" * 8192
        request_body = "q" * 9000
        result = exchange(request: request.merge(body: request_body),
                          response: response.merge(status: status, body: response_body), expected_status: expected)
        native = result.native_markdown
        card = result.to_markdown(presentation: mode)
        marker = described_class::TRUNCATION_MARKER
        expect(described_class::MAX_PREVIEW_BYTES).to eq(16 * 1024)
        expect(fenced_bodies(card)).to eq([response_body, "#{'q' * 8192}\n#{marker}", marker, marker])
        expect(evidence_lines(card).sum(&:bytesize)).to eq(16 * 1024)
        expect(evidence_lines(card).length).to eq(2)
        expect(result.instance_variable_get(:@request)[:body]).to eq(request_body)
        expect(result.instance_variable_get(:@response)[:body]).to eq(response_body)
        expect(result.native_markdown.b).to eq(native.b)
        expect(result.level).to eq(level)
      end
    end

    it "bounds an already oversized response before any later evidence in #{mode} mode" do
      body = "response\n" * 200
      result = exchange(response: response.merge(body: body))
      card = result.to_markdown(presentation: mode)
      marker = described_class::TRUNCATION_MARKER
      expect(fenced_bodies(card)).to eq([(Array.new(100, "response") + [marker]).join("\n"), marker, marker, marker])
      expect(evidence_lines(card).length).to eq(100)
      expect(result.instance_variable_get(:@response)[:body]).to eq(body)
      expect(card.bytesize).to be < 4096
    end

    it "retains redaction of URL, body, header arrays, expected status and error in #{mode} mode" do
      result = exchange(url: "https://user:HTTP_PRIVATE_USER@api.example.test/orders?token=HTTP_PRIVATE_URL",
        request: { headers: { "Authorization" => ["HTTP_PRIVATE_AUTH1", "HTTP_PRIVATE_AUTH2"],
                              "X-Trace" => ["Bearer HTTP_PRIVATE_BEARER", "safe trace"] },
                   body: { password: "HTTP_PRIVATE_PASSWORD", visible: "safe request" } },
        response: { status: 500, headers: { "set-cookie" => ["HTTP_PRIVATE_COOKIE1", "HTTP_PRIVATE_COOKIE2"],
                                           "X-Custom" => ["HTTP_PRIVATE_CUSTOM1", "HTTP_PRIVATE_CUSTOM2"] },
                    body: '{"token":"HTTP_PRIVATE_BODY","visible":"safe response"}' },
        expected_status: "api_key=HTTP_PRIVATE_EXPECTED", error: "password=HTTP_PRIVATE_ERROR", sensitive_keys: ["X-Custom"])
      card = result.to_markdown(presentation: mode)
      expect(card + result.native_markdown + result.summary).not_to include("HTTP_PRIVATE_")
      expect(card).to include("Authorization: [REDACTED]", "set-cookie: [REDACTED]", "X-Custom: [REDACTED]",
                              "X-Trace: Bearer [REDACTED]\nX-Trace: safe trace", "safe request", "safe response",
                              "expected `api_key=[REDACTED]`", "error `password=[REDACTED]`")
      expect(result.to_markdown(presentation: "rich").b).to eq(result.to_markdown.b)
    end
  end

  it "retains the exact native format, raw snapshot values and terminal summary after either card render" do
    result = exchange(expected_status: 201)
    original_request = Marshal.dump(request)
    original_response = Marshal.dump(response)
    native = <<~MARKDOWN.chomp
      ### Request
      - `POST` `https://api.example.test/orders`
      - Headers:
      ```text
      Content-Type: ["application/json"]
      X-Route: ["primary", "secondary"]
      ```
      - Body:
      ```json
      {
        "item": 42
      }
      ```

      ### Response
      - Status: `201`
      - Headers:
      ```text
      content-type: ["application/json"]
      Vary: ["Accept", "Accept-Encoding"]
      ```
      - Body:
      ```json
      {
        "result": "received"
      }
      ```

      - Duration: `84` ms
    MARKDOWN
    %w[plain rich].each do |mode|
      result.to_markdown(presentation: mode)
      expect(result.native_markdown.b).to eq(native.b)
      expect(result.summary).to eq("POST https://api.example.test/orders status=201 84ms")
      expect(result.instance_variable_get(:@request)).to eq(request.merge(status: nil))
      expect(result.instance_variable_get(:@response)).to eq(response)
      expect(Marshal.dump(request)).to eq(original_request)
      expect(Marshal.dump(response)).to eq(original_response)
    end
  end

  it "snapshots repeated header values before caller mutation without flattening the stored arrays" do
    result = exchange
    plain = result.to_markdown
    rich = result.to_markdown(presentation: "rich")
    native = result.native_markdown
    request[:headers]["X-Route"][0] = "changed"
    request[:headers]["X-Route"] << "added"
    response[:headers]["Vary"].clear
    expect(result.to_markdown).to eq(plain)
    expect(result.to_markdown(presentation: "rich")).to eq(rich)
    expect(result.native_markdown).to eq(native)
    snapshot = result.instance_variable_get(:@request)[:headers]["X-Route"]
    expect(snapshot).to eq(["primary", "secondary"])
    expect(snapshot).to be_frozen
    expect(snapshot).to all(be_frozen)
  end

  it "does not call rich decorators for an ERROR card with long bodies and repeated headers" do
    result = exchange(response: response.merge(status: 500, body: "response\n" * 20), expected_status: 201)
    accent = ReportportalCucumber::Presentation::Accent
    %i[pill title details guard].each { |method| expect(accent).not_to receive(method) }
    expect(result.to_markdown(presentation: "rich").b).to eq(result.to_markdown.b)
  end
end
