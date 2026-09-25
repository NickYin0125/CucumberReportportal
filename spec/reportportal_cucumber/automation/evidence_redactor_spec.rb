# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rbconfig"
require "uri"

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
