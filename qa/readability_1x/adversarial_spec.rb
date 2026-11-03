# frozen_string_literal: true

require "json"
require "uri"
require "stringio"
require "rspec"
gem "cucumber", ENV.fetch("QA_CUCUMBER", "10.2.0")
$LOAD_PATH.unshift(File.join(ENV.fetch("QA_SOURCE"), "lib"))
require "reportportal_cucumber"

RSpec.describe "Independent percent-depth adversarial boundaries" do
  sentinel = "SYNTHETIC_DEPTH_SENTINEL"
  layers = lambda do |value, depth, all_bytes: false|
    if all_bytes
      value = value.bytes.map { |byte| format("%%%02X", byte) }.join
      depth -= 1
    end
    depth.times { value = URI.encode_www_form_component(value) }
    value
  end
  layouts = {
    json_path: ->(depth) { "https://example.test/" + layers.call(JSON.generate(password: sentinel), depth) },
    unicode_json_key_path: ->(depth) { "https://example.test/" + layers.call('{"\\u0070assword":"' + sentinel + '"}', depth) },
    json_query_value: ->(depth) { "https://example.test/?payload=" + layers.call(JSON.generate(password: sentinel), depth) },
    json_fragment: ->(depth) { "https://example.test/#" + layers.call(JSON.generate(password: sentinel), depth) },
    fully_encoded_key_and_value: ->(depth) { "https://example.test/?" + layers.call("password", depth, all_bytes: true) + "=" + layers.call(sentinel, depth, all_bytes: true) },
    fully_encoded_path_assignment: ->(depth) { "https://example.test/" + layers.call("password=" + sentinel, depth, all_bytes: true) },
    malformed_host_path_and_fragment: ->(depth) { "http://[invalid]/" + layers.call(JSON.generate(password: sentinel), depth) + "#" + layers.call("token=" + sentinel, depth, all_bytes: true) }
  }

  layouts.each do |name, make_url|
    [1, 2, 3, 4, 5].each do |depth|
      it("SEC #{name} depth=#{depth} never survives any automatic channel") do
        url = make_url.call(depth)
        exchange = Automation::HttpExchange.new(method: :get, url: url, response: { status: 200 })
        outputs = { direct: Automation::EvidenceRedactor.new.redact_url(url), summary: exchange.summary,
          native: exchange.native_markdown, plain: exchange.to_markdown, rich: exchange.to_markdown(presentation: "rich"),
          diagnostic: ReportportalCucumber::Service::EvidencePresenter.sanitize_diagnostic(url),
          evidence: ReportportalCucumber::Service::EvidencePresenter.failure(action: "independent depth", error: RuntimeError.new("business failure"), url: url).fetch(:card) }
        aggregate_failures("all #{name} depth #{depth} channels") do
          outputs.each do |channel, output|
            decoded = output.dup
            6.times do
              decoded = URI.decode_www_form_component(decoded)
            rescue ArgumentError
              break
            end
            expect(decoded).not_to include(sentinel), "#{channel} leaked #{name} at depth #{depth}"
          end
        end
      end
    end
  end

  [4, 5].each do |depth|
    ["BENIGN_OVERDEPTH", "[REDACTED]"].each do |value|
      it("SEC remaining percent escapes are intentionally withheld at depth=#{depth}, value=#{value}") do
        encoded = layers.call(JSON.generate(note: value), depth)
        result = Automation::EvidenceRedactor.new.redact_url("https://example.test/" + encoded)
        expect(result).to include("[REDACTED]")
        expect(result).not_to include("%25")
      end
    end
  end

  it "INV plain public redaction APIs preserve safe originals and input objects" do
    redactor = Automation::EvidenceRedactor.new
    safe_url = "https://example.test/orders?region=eu&page=2#section"
    safe_text = "normal diagnostic with no credentials"
    safe_hash = { "order" => 42, "tags" => ["one", "two"] }
    original = Marshal.load(Marshal.dump(safe_hash))
    expect(redactor.redact_url(safe_url)).to eq(safe_url)
    expect(redactor.redact_text(safe_text)).to eq(safe_text)
    expect(redactor.redact(safe_hash)).to eq(original)
    expect(safe_hash).to eq(original)
    expect(redactor.redact("password" => sentinel)).to eq("password" => "[REDACTED]")
  end

  it "INV benign native HTTP has its original request-first plain API bytes" do
    exchange = Automation::HttpExchange.new(method: :get, url: "https://example.test/orders",
      request: { body: "request" }, response: { status: 200, body: "response" })
    expect(exchange.native_markdown).to eq(<<~MARKDOWN)
      ### Request
      - `GET` `https://example.test/orders`
      - Body:
      ```text
      request
      ```

      ### Response
      - Status: `200`
      - Body:
      ```text
      response
      ```
    MARKDOWN
  end

  it "SEC plaintext duplicated Bearer has no residual credential in automatic evidence" do
    source = "Authorization: Bearer Bearer SYNTHETIC_BEARER_SENTINEL"
    http = Automation::HttpExchange.new(method: :get, url: "https://example.test/orders", error: source)
    presenter = ReportportalCucumber::Service::EvidencePresenter
    outputs = { direct: Automation::EvidenceRedactor.new.redact_text(source),
      structured: Automation::EvidenceRedactor.new.redact("message" => source).fetch("message"),
      summary: http.summary, native: http.native_markdown, plain: http.to_markdown, rich: http.to_markdown(presentation: "rich"),
      diagnostic: presenter.sanitize_diagnostic(source),
      evidence: presenter.failure(action: "independent double bearer", error: RuntimeError.new(source)).fetch(:card) }
    aggregate_failures("all duplicated-Bearer automatic channels") do
      outputs.each do |channel, output|
        expect(output).not_to include("SYNTHETIC_BEARER_SENTINEL"), "#{channel} retains a credential after duplicated Bearer"
      end
    end
  end
end
