# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rbconfig"
require "uri"
require "timeout"

require "reportportal_cucumber/automation/evidence_redactor"

RSpec.describe Automation::EvidenceRedactor do
  REDACTED = "[REDACTED]" unless const_defined?(:REDACTED)

  def redactor(**options)
    described_class.new(**options)
  end

  describe "#redact" do
    it "recursively redacts credential headers and sensitive fields case-insensitively" do
      input = {
        "Authorization" => "Bearer header-secret",
        "X-API-KEY" => "header-api-secret",
        "nested" => [
          { "Token" => "token-secret", "Password" => "password-secret" },
          { "api_key" => "key-secret", "Client_Secret" => "client-secret" }
        ]
      }

      result = redactor.redact(input)

      %w[header-secret header-api-secret token-secret password-secret key-secret client-secret].each do |secret|
        expect(result.inspect).not_to include(secret)
      end
      expect(result["Authorization"]).to eq(REDACTED)
      expect(result["nested"][0]["Token"]).to eq(REDACTED)
      expect(result["nested"][1]["Client_Secret"]).to eq(REDACTED)
    end

    it "redacts sensitive fields in JSON-encoded bodies while preserving valid JSON" do
      encoded = '{"profile":{"name":"Ada","password":"json-secret"},"items":[{"api_key":"item-secret"}]}'

      result = redactor.redact(encoded)

      expect { JSON.parse(result) }.not_to raise_error
      expect(result).not_to include("json-secret", "item-secret")
      expect(result).to include(REDACTED)
    end

    it "handles nested arrays and custom sensitive keys" do
      result = redactor(sensitive_keys: ["member_code"]).redact(
        [{ "group" => [[{ "MEMBER_CODE" => "custom-secret", "visible" => "ok" }]] }]
      )

      expect(result.dig(0, "group", 0, 0, "MEMBER_CODE")).to eq(REDACTED)
      expect(result.dig(0, "group", 0, 0, "visible")).to eq("ok")
      expect(result.inspect).not_to include("custom-secret")
    end

    it "omits ambiguous double-escaped structured keys instead of emitting their values" do
      input = { 'pass\u0077ord' => "PRIVACY_DOUBLE_ESCAPED_KEY" }
      [input, JSON.generate(input)].each do |value|
        expect(redactor.redact(value)).to eq(described_class::OMITTED)
      end
    end

    it "normalizes credential keys with repeated separators at every nesting level" do
      input = {
        "outer" => [{ "P___A---S_S_W_O_R_D" => "separator-password-canary",
                      "x_____api-----key" => "separator-api-canary",
                      "visible" => "kept" }]
      }

      result = redactor.redact(input)

      expect(result.dig("outer", 0, "P___A---S_S_W_O_R_D")).to eq(REDACTED)
      expect(result.dig("outer", 0, "x_____api-----key")).to eq(REDACTED)
      expect(result.dig("outer", 0, "visible")).to eq("kept")
      expect(result.inspect).not_to include("separator-password-canary", "separator-api-canary")
    end

    it "does not mutate deeply frozen input" do
      input = {
        "headers" => { "Authorization" => "Bearer frozen-secret" }.freeze,
        "payload" => [{ "password" => "frozen-password" }.freeze].freeze
      }.freeze

      expect { redactor.redact(input) }.not_to raise_error
      expect(input["headers"]["Authorization"]).to eq("Bearer frozen-secret")
      expect(input["payload"][0]["password"]).to eq("frozen-password")
    end
  end

  describe "#redact_url" do
    it "removes userinfo and redacts every duplicate sensitive query key" do
      result = redactor.redact_url(
        "https://alice:password-secret@example.test/path?token=first-secret&x=1&TOKEN=second-secret&api_key=key-secret"
      )

      expect(result).not_to include("alice", "password-secret", "first-secret", "second-secret", "key-secret")
      expect(result).to include("example.test", "x=1", "token=")
    end

    it "fails closed on malformed URLs containing credentials" do
      urls = [
        "https://alice:malformed-password@example.test/bad path?token=malformed-token",
        "https://alice:malformed-password@example.test/%ZZ?token=malformed-token",
        "https://alice:malformed-password@[broken/path?token=malformed-token"
      ]

      urls.each do |url|
        result = redactor.redact_url(url)
        expect(result).not_to include("alice", "malformed-password", "malformed-token")
      end
    end

    it "preserves duplicate query pairs and stays stable when redacted repeatedly" do
      sanitizer = redactor
      url = "https://alice:url-secret@example.test/path?token=first-secret&x=1&TOKEN=second-secret" \
            "&x=2&api_key=key-secret&label=a%2Bb"
      once = sanitizer.redact_url(url)
      pairs = URI.decode_www_form(URI.parse(once).query)

      expect(pairs).to eq([
        ["token", REDACTED], ["x", "1"], ["TOKEN", REDACTED],
        ["x", "2"], ["api_key", REDACTED], ["label", "a+b"]
      ])
      expect(sanitizer.redact_url(sanitizer.redact_url(once))).to eq(once)
      expect(sanitizer.redact_text("request #{once}")).to eq("request #{once}")
    end
  end

  describe "#redact_text" do
    it "fails closed on escaped keys in malformed, embedded, and opening-brace-free JSON" do
      inputs = [
        '{"pass\u0077ord":"PRIVACY_ESCAPED_MALFORMED"',
        'diagnostic: {"pass\u0077ord":"PRIVACY_ESCAPED_EMBEDDED"}',
        'diagnostic: {]"\u0070assword":"PRIVACY_ESCAPED_MISMATCH"}',
        '"pass\u0077ord":"PRIVACY_ESCAPED_FRAGMENT"',
        "\"pass\\u0077ord\"\r\n : \"PRIVACY_ESCAPED_MULTILINE_FRAGMENT\"",
        '\u0070assword: "PRIVACY_ESCAPED_UNQUOTED_FRAGMENT"',
        '{"pass\word":"PRIVACY_ESCAPED_INVALID"}',
        JSON.generate(payload: '{"pass\u0077ord":"PRIVACY_ESCAPED_NESTED"')
      ]
      inputs.each do |input|
        expect(redactor.redact_text(input)).not_to include("PRIVACY_ESCAPED_")
        expect(redactor.redact_text(input)).to include(REDACTED)
      end
    end

    it "decodes valid escaped and JSON-string-encoded keys including custom keys" do
      input = '{"pass\u0077ord":"PRIVACY_DECODE_PASSWORD","member_\u0063ode":"PRIVACY_DECODE_CUSTOM","visible":"kept"}'
      sanitizer = redactor(sensitive_keys: ["member_code"])
      [input, JSON.generate(input), JSON.generate(payload: input)].each do |text|
        safe = sanitizer.redact_text(text)
        expect(safe).not_to include("PRIVACY_DECODE_")
        expect(safe).to include("kept", REDACTED)
      end
    end

    it "checks the complete input before clipping or oversized omission" do
      input = 'diagnostic: {"visible":"PRIVACY_BEFORE_ESCAPE' + ("x" * 20_000) + '","pass\u0077ord":"PRIVACY_AFTER_ESCAPE"}'
      expect(redactor.redact_text(input)).to eq(described_class::OMITTED)
      oversized = 'password="PRIVACY_OVERSIZED' + ("x" * described_class::MAX_INPUT_BYTES) + '"'
      expect(redactor.redact_text(oversized)).to eq(described_class::OMITTED)
    end

    it "bounds parsed depth, node count, repeated decoding, cycles, and integer conversion" do
      cycle = []
      cycle << cycle
      deep = ("[" * 30) + '{"password":"PRIVACY_DEEP"}' + ("]" * 30)
      repeated = 20.times.reduce('{"password":"PRIVACY_DECODE_DEPTH"}') { |text, _| JSON.generate(text) }
      inputs = [cycle, deep, repeated, Array.new(described_class::MAX_STRUCTURE_NODES + 1, "safe"), 2**20_000]
      Timeout.timeout(2) do
        inputs.each { |input| expect(redactor.redact(input)).to eq(described_class::OMITTED) }
      end
    end

    it "keeps safe business controls and ordinary multiline diagnostics readable" do
      text = "safe diagnostic\ntoken_count=12 password_policy=business-only component=payments\npath=C:\\tmp\\recording"
      expect(redactor.redact_text(text)).to eq(text)
    end

    it "redacts bearer credentials in ordinary and multiline text" do
      result = redactor.redact_text("Authorization: Bearer abc.def-123\nnext line")

      expect(result).not_to include("abc.def-123")
      expect(result).to include("Authorization", "next line", REDACTED)
    end

    it "preserves non-JSON multiline text" do
      text = "first line\nordinary diagnostic\nlast line"
      result = redactor.redact_text(text)

      expect(result).to eq(text)
    end

    it "redacts plain password fields in multiline non-JSON text" do
      result = redactor.redact_text("first line\nPassword: plain-secret\nlast line")

      expect(result).not_to include("plain-secret")
      expect(result).to include("first line", "last line", REDACTED)
    end

    it "redacts quoted JSON values clipped mid-string, including escaped nested JSON" do
      secret = "M2-quoted-canary-" + ("q" * 1_000)
      clipped = %({"password":"#{secret})
      nested = JSON.generate(payload: JSON.generate(password: secret))[0, 80]
      nested += "password\\\":\\\"#{secret}"

      [clipped, nested].each do |text|
        result = redactor.redact_text(text)
        expect(result).not_to include("M2-quoted-canary-")
        expect(result).to include(REDACTED)
      end
    end

    it "redacts clipped values ending in a dangling escape and values with escaped quotes" do
      limit = ReportportalCucumber::Service::EvidencePresenter::DETAILS_LIMIT
      head = '{"password":"CANARY_DANGLING_'
      dangling_prefix = head + ("x" * (limit - head.bytesize - 1)) + "\\"
      escaped_quote_prefix = JSON.generate(password: 'CANARY_ESCAPED_"tail' + ("e" * 1_000))[0, 80]

      [dangling_prefix, escaped_quote_prefix].each do |prefix|
        result = redactor.redact_text(prefix)
        expect(result).not_to include("CANARY_DANGLING_", "CANARY_ESCAPED_")
        expect(result).to include(REDACTED)
      end
    end

    it "redacts clipped JSON keys separated from values by JSON whitespace" do
      prefix = %({"password":\r\n "CANARY_MULTILINE_#{"m" * 1_000})

      result = redactor.redact_text(prefix)

      expect(result).not_to include("CANARY_MULTILINE_")
      expect(result).to include(REDACTED)
    end

    it "sanitizes invalid binary bytes without mutating or truncating the input" do
      text = ("prefix\xFF\n".b + ("x" * 20_000) + "\nPassword: binary-secret\nend\xFE".b).freeze
      original_bytes = text.bytes
      result = redactor.redact_text(text)

      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to be(true)
      expect(result).to include("prefix", "x" * 20_000, "end", REDACTED)
      expect(result).not_to include("binary-secret")
      expect(text.bytes).to eq(original_bytes)
      expect(text.encoding).to eq(Encoding::BINARY)
    end
  end

  it "redacts escaped JSON inside query values and malformed URL fragments" do
    payload = 'diagnostic: {"pass\u0077ord":"PRIVACY_URL_VALUE"}'
    query = URI.encode_www_form_component(payload)
    urls = ["https://example.test/?payload=#{query}", "https://example.test/bad path##{query}"]
    urls.each { |url| expect(redactor.redact_url(url)).not_to include("PRIVACY_URL_VALUE") }
  end

  it "can be required in a standalone process without loading ReportPortal or Cucumber" do
    lib_dir = File.expand_path("../../../lib", __dir__)
    script = <<~RUBY
      loaded_before = $LOADED_FEATURES.dup
      reportportal_before = defined?(ReportportalCucumber)
      require "reportportal_cucumber/automation/evidence_redactor"
      abort "missing EvidenceRedactor" unless defined?(Automation::EvidenceRedactor)
      sanitizer = Automation::EvidenceRedactor.new
      abort "unredacted field" if sanitizer.redact({ password: "standalone-secret" }).inspect.include?("standalone-secret")
      abort "unredacted URL" if sanitizer.redact_url("https://example.test/?token=url-secret").include?("url-secret")
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
end
