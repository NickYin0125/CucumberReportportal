# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "timeout"

require "reportportal_cucumber/automation/http_exchange"

RSpec.describe Automation::HttpExchange do
  def build_exchange(**overrides)
    defaults = {
      method: "POST",
      url: "https://api.example.test/v1/orders",
      request: {
        headers: { "Content-Type" => "application/json" },
        body: { "order" => { "id" => 42 } }
      },
      response: {
        status: 201,
        headers: { "Content-Type" => "application/json" },
        body: { "accepted" => true }
      },
      duration_ms: 18.5
    }

    described_class.new(**defaults.merge(overrides))
  end

  def split_markdown_fenced_blocks(markdown)
    lines = markdown.lines(chomp: true)
    blocks = []
    prose = []
    index = 0

    while index < lines.length
      opening = lines[index].match(/\A {0,3}(`{3,}|~{3,})([^\r\n]*)\z/)
      opening = nil if opening && opening[1].start_with?("`") && opening[2].include?("`")
      unless opening
        prose << lines[index]
        index += 1
        next
      end

      fence = opening[1]
      # A longer same-character fence also closes a CommonMark fenced block.
      closing_pattern = /\A {0,3}#{Regexp.escape(fence[0])}{#{fence.length},}[ \t]*\z/
      closing = ((index + 1)...lines.length).find { |candidate| lines[candidate].match?(closing_pattern) }
      unless closing
        prose << lines[index]
        index += 1
        next
      end

      blocks << {
        fence: fence,
        language: opening[2].strip,
        content: lines[(index + 1)...closing].join("\n")
      }
      index = closing + 1
    end

    [blocks, prose.join("\n")]
  end

  it "snapshots mutable request and response data before the first render" do
    method = +"POST"
    url = +"https://api.example.test/original"
    request = {
      headers: { "X-Trace" => +"original-request-header" },
      body: { "items" => [[{ "label" => +"original-request-body", "password" => +"original-secret" }]] }
    }
    response = {
      status: 201,
      headers: { "X-Trace" => +"original-response-header" },
      body: +'{"label":"original-response-body","token":"response-secret"}'
    }
    exchange = build_exchange(method: method, url: url, request: request, response: response, expected_status: 201)

    method.replace("DELETE")
    url.replace("https://changed.example.test/replaced")
    request[:headers]["X-Trace"].replace("changed-request-header")
    request[:body]["items"][0][0]["label"].replace("changed-request-body")
    request[:body]["items"][0][0]["password"].replace("changed-secret")
    request[:body]["items"] << { "added" => "changed-item" }
    response[:status] = 500
    response[:headers]["X-Trace"].replace("changed-response-header")
    response[:body].replace('{"label":"changed-response-body"}')

    markdown = exchange.to_markdown
    expect(exchange.summary).to include("POST", "https://api.example.test/original", "201")
    expect(exchange.level).to eq(:info)
    expect(markdown).to include("original-request-header", "original-request-body")
    expect(markdown).to include("original-response-header", "original-response-body")
    expect(markdown).not_to include("changed-", "original-secret", "response-secret")
  end

  it "snapshots a mutable error message before the first render" do
    error = +"original timeout; password=error-secret"
    exchange = build_exchange(error: error, response: nil)
    error.replace("changed-error")

    expect(exchange.summary).to include("original timeout")
    expect(exchange.to_markdown).to include("original timeout")
    expect(exchange.to_markdown).not_to include("changed-error", "error-secret")
    expect(exchange.level).to eq(:error)
  end

  it "renders deeply frozen evidence without mutating the input" do
    request = {
      headers: { "Authorization" => "Bearer frozen-request-secret" }.freeze,
      body: [{ "password" => "frozen-body-secret", "visible" => "original" }.freeze].freeze
    }.freeze
    response = { status: 200, headers: {}.freeze, body: "original response" }.freeze
    exchange = build_exchange(request: request, response: response)

    expect(exchange.to_markdown).to include("original", "original response")
    expect(exchange.to_markdown).not_to include("frozen-request-secret", "frozen-body-secret")
    expect(request[:headers]["Authorization"]).to eq("Bearer frozen-request-secret")
    expect(request[:body][0]["password"]).to eq("frozen-body-secret")
  end

  it "preserves independently observed status and timing when evidence is unsafe or oversized" do
    cycle = { "password" => "HTTP_OMITTED_CYCLE_SECRET" }
    cycle["cycle"] = cycle
    bodies = [
      "HTTP_OMITTED_LARGE_SECRET" + ("x" * Automation::EvidenceRedactor::MAX_INPUT_BYTES),
      cycle,
      Array.new(Automation::EvidenceRedactor::MAX_STRUCTURE_NODES + 1, "HTTP_OMITTED_NODE_SECRET")
    ]
    bodies.each do |body|
      exchange = build_exchange(method: :post, expected_status: 200, duration_ms: 18.5,
                                response: { status: 200, headers: {}, body: body })
      expect(exchange.level).to eq(:info)
      expect(exchange.summary).to include("POST", "status=200", "18.5ms")
      expect(exchange.to_markdown).to include("Status: `200`", Automation::EvidenceRedactor::OMITTED)
      expect(exchange.to_markdown).not_to include("HTTP_OMITTED_")
    end
  end

  it "preserves valid string status when oversized headers are omitted independently" do
    headers = { "X-Diagnostic" => "HTTP_HEADER_SECRET" + ("x" * Automation::EvidenceRedactor::MAX_INPUT_BYTES) }
    exchange = build_exchange(expected_status: 200, response: { status: "200", headers: headers, body: "safe response" })
    expect(exchange.level).to eq(:info)
    expect(exchange.to_markdown).to include("Status: `200`", "safe response", Automation::EvidenceRedactor::OMITTED)
    expect(exchange.to_markdown).not_to include("HTTP_HEADER_SECRET")
  end

  it "does not stringify unsafe cyclic or oversized structured errors after traversal omission" do
    cycle = { "password" => "HTTP_ERROR_PRIVATE_CYCLE" }
    cycle["self"] = cycle
    huge = Array.new(1100, "HTTP_ERROR_PRIVATE_NODES")
    [cycle, huge].each do |error|
      allow(error).to receive(:to_s).and_raise("raw structured error must not be stringified")
      Timeout.timeout(2) do
        exchange = build_exchange(error: error)
        expect(exchange.level).to eq(:error)
        expect(exchange.summary).to include(Automation::EvidenceRedactor::OMITTED)
        expect(exchange.to_markdown).not_to include("HTTP_ERROR_PRIVATE_")
      end
    end
  end

  it "snapshots exception diagnostics without modifying the original exception" do
    message = 'diagnostic: {"pass\u0077ord":"HTTP_ERROR_PRIVATE_EXCEPTION"}'
    original = RuntimeError.new(message)
    exchange = build_exchange(error: original)
    expect(exchange.summary).not_to include("HTTP_ERROR_PRIVATE_")
    expect(original.message).to eq(message)
    expect { raise original }.to raise_error { |caught| expect(caught).to equal(original) }
  end

  describe "#summary" do
    it "includes method, status, and timing without including request or response bodies" do
      exchange = build_exchange(
        request: { headers: {}, body: { "private_request_marker" => "must not appear" } },
        response: { status: 201, headers: {}, body: { "private_response_marker" => "must not appear" } }
      )

      summary = exchange.summary.to_s

      expect(summary).to include("POST", "201", "18.5")
      expect(summary).not_to include("private_request_marker", "private_response_marker", "must not appear")
    end

    it "collapses multiline details and bounds unusually long summaries" do
      exchange = build_exchange(error: RuntimeError.new("failure\n#{'x' * 5_000}"))
      summary = exchange.summary

      expect(summary).not_to match(/[\r\n]/)
      expect(summary.bytesize).to be <= 2_048
    end

    it "keeps URLs as plain text without Markdown backslash escaping" do
      summary = build_exchange.summary

      expect(summary).to include("https://api.example.test/v1/orders")
      expect(summary).not_to include("api\\.example")
    end
  end

  describe "#to_markdown" do
    it "renders request and response JSON sections" do
      markdown = build_exchange.to_markdown
      blocks, = split_markdown_fenced_blocks(markdown)
      json_bodies = blocks.select { |block| block[:language] == "json" }.map do |block|
        JSON.parse(block[:content])
      end

      expect(markdown).to include("Request", "Response")
      expect(json_bodies).to eq([{ "order" => { "id" => 42 } }, { "accepted" => true }])
    end

    it "treats expected client errors as informational and unexpected server errors as errors" do
      expected_client_error = build_exchange(
        expected_status: 400,
        response: { status: 400, headers: {}, body: { "message" => "invalid" } }
      )
      unexpected_server_error = build_exchange(
        expected_status: 201,
        response: { status: 500, headers: {}, body: { "message" => "failed" } }
      )

      expect(expected_client_error.level).to eq(:info)
      expect(unexpected_server_error.level).to eq(:error)
    end

    it "warns on an unexpected server error when no status was expected" do
      exchange = build_exchange(response: { status: 500, headers: {}, body: "server failed" })

      expect(exchange.level).to eq(:warn)
    end

    it "supports timeout-like errors without a response" do
      exchange = described_class.new(
        method: "GET",
        url: "https://api.example.test/slow",
        request: { headers: {}, body: nil },
        response: nil,
        duration_ms: 1_000,
        error: Timeout::Error.new("request timed out")
      )

      expect(exchange.level).to eq(:error)
      expect(exchange.to_markdown).to include("GET", "timed out")
      expect { exchange.summary }.not_to raise_error
    end

    it "uses a safe enclosing fence and preserves untrusted evidence" do
      header = "header-before\n```json\n<script>header()</script>\n``````\n~~~~~~\nheader-after"
      request_body = "request-before\n~~~html\n<img src=x onerror=alert(1)>\n~~~~~~~~\n````````\nrequest-after"
      response_body = "response-before\n```\n<script>response()</script>\n~~~\nresponse-after"
      exchange = build_exchange(
        request: {
          headers: { "X-Untrusted" => header },
          body: request_body
        },
        response: {
          status: 200,
          headers: {},
          body: response_body
        }
      )
      blocks, prose = split_markdown_fenced_blocks(exchange.to_markdown)

      expect(blocks.length).to eq(3)
      blocks.each do |block|
        fence_character = block[:fence][0]
        longest_run = block[:content].scan(/#{Regexp.escape(fence_character)}+/).map(&:length).max || 0
        expect(block[:fence].length).to be > longest_run
      end
      expect(blocks.map { |block| block[:content] }).to eq([
        "X-Untrusted: #{header}", request_body, response_body
      ])
      expect(prose).to include("Request", "Response", "Duration")
      expect(prose).not_to include("<script>", "<img")
    end

    it "renders invalid binary body bytes as valid UTF-8 without leaking credentials" do
      body = "diagnostic\xFF\nAuthorization: Bearer binary-secret\nend\xFE".b.freeze
      original_bytes = body.bytes
      markdown = build_exchange(response: { status: 200, headers: {}, body: body }).to_markdown
      blocks, = split_markdown_fenced_blocks(markdown)

      expect(markdown.encoding).to eq(Encoding::UTF_8)
      expect(markdown.valid_encoding?).to be(true)
      expect(blocks.last[:content]).to include("diagnostic", "end")
      expect(markdown).not_to include("binary-secret")
      expect(body.bytes).to eq(original_bytes)
      expect(body.encoding).to eq(Encoding::BINARY)
    end
  end

  it "can be required in a standalone process without loading ReportPortal or Cucumber" do
    lib_dir = File.expand_path("../../../lib", __dir__)
    script = <<~RUBY
      loaded_before = $LOADED_FEATURES.dup
      reportportal_before = defined?(ReportportalCucumber)
      require "reportportal_cucumber/automation/http_exchange"
      abort "missing HttpExchange" unless defined?(Automation::HttpExchange)
      exchange = Automation::HttpExchange.new(
        method: "GET", url: "https://example.test", request: { headers: {}, body: nil },
        response: { status: 200, headers: {}, body: { ok: true } }
      )
      abort "unexpected severity" unless exchange.level == :info
      abort "missing evidence" unless exchange.to_markdown.include?("ok") && exchange.summary.include?("200")
      newly_loaded = $LOADED_FEATURES - loaded_before
      core_reportportal = newly_loaded.any? do |path|
        path.include?("reportportal_cucumber") && !path.include?("/automation/")
      end
      abort "loaded ReportPortal core" if core_reportportal
      abort "loaded Cucumber" if newly_loaded.any? { |path| path.match?(%r{(?:^|/)cucumber(?:/|\\.rb)}) }
      abort "defined ReportPortal" if reportportal_before.nil? && defined?(ReportportalCucumber)
    RUBY
    stdout, stderr, status = Open3.capture3(
      "env", "-u", "RUBYOPT", "-u", "BUNDLE_GEMFILE", "-u", "BUNDLE_BIN_PATH", "-u", "BUNDLER_VERSION",
      RbConfig.ruby, "-I#{lib_dir}", "-e", script
    )

    expect(status.success?).to(be(true), "stdout: #{stdout}\nstderr: #{stderr}")
  end

  it "bounds large UTF-8 non-JSON body previews and includes a truncation marker" do
    max_bytes = described_class::MAX_PREVIEW_BYTES
    max_lines = described_class::MAX_PREVIEW_LINES
    expect(max_bytes).to be_between(128, 1_048_576)
    expect(max_lines).to be_between(2, 10_000)
    body = "敏感語句🙂\n" * (max_lines + 100) + ("x" * max_bytes)

    markdown = build_exchange(response: { status: 200, headers: {}, body: body }).to_markdown
    blocks, = split_markdown_fenced_blocks(markdown)
    preview = blocks.last[:content]

    expect(preview.bytesize).to be <= max_bytes + described_class::TRUNCATION_MARKER.bytesize + 8
    expect(preview.lines.count).to be <= max_lines + 1
    expect(preview).to include(described_class::TRUNCATION_MARKER)
    expect(preview.valid_encoding?).to be(true)
  end

  it "applies the byte and line budgets across all request and response fields" do
    max_bytes = described_class::MAX_PREVIEW_BYTES
    max_lines = described_class::MAX_PREVIEW_LINES
    exchange = build_exchange(
      request: { headers: { "X-Request" => ("request-header\n" * 150) }, body: "request-body\n" * 150 },
      response: { status: 200, headers: { "X-Response" => ("response-header\n" * 150) }, body: "response-body\n" * 150 }
    )

    markdown = exchange.to_markdown
    blocks, = split_markdown_fenced_blocks(markdown)
    preview_lines = blocks.flat_map { |block| block[:content].lines(chomp: true) }
                          .reject { |line| line == described_class::TRUNCATION_MARKER }

    expect(preview_lines.length).to be <= max_lines
    expect(preview_lines.join("\n").bytesize).to be <= max_bytes
    expect(markdown).to include(described_class::TRUNCATION_MARKER)
    expect(markdown).to be_valid_encoding
  end

  it "keeps a byte-limited single-line UTF-8 body valid at a multibyte boundary" do
    max_bytes = described_class::MAX_PREVIEW_BYTES
    body = "\u{1F642}" * max_bytes
    markdown = build_exchange(response: { status: 200, headers: {}, body: body }).to_markdown
    blocks, = split_markdown_fenced_blocks(markdown)
    preview = blocks.last[:content]

    expect(preview.bytesize).to be <= max_bytes + 8
    expect(preview.valid_encoding?).to be(true)
    expect(preview).to include(described_class::TRUNCATION_MARKER)
  end

  it "keeps an oversized backtick-only payload bounded without breaking its fence" do
    max_bytes = described_class::MAX_PREVIEW_BYTES
    body = "`" * (max_bytes * 2)

    markdown = build_exchange(response: { status: 200, headers: {}, body: body }).to_markdown
    blocks, = split_markdown_fenced_blocks(markdown)
    response_body = blocks.last

    expect(markdown.bytesize).to be <= (max_bytes * 2) + 2_048
    expect(response_body[:content]).to include(described_class::TRUNCATION_MARKER)
    fence_character = response_body[:fence][0]
    longest_run = response_body[:content].scan(/#{Regexp.escape(fence_character)}+/).map(&:length).max || 0
    expect(response_body[:fence].length).to be > longest_run
  end
end
