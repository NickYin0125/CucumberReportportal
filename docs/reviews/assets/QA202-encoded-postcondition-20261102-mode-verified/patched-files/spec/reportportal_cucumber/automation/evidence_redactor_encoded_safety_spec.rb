# frozen_string_literal: true

require "spec_helper"
require "uri"
require "reportportal_cucumber/automation/http_exchange"
require "reportportal_cucumber/automation/failure_redactor"

RSpec.describe Automation::EvidenceRedactor, "encoded output safety" do
  let(:secret) { "SYNTHETIC_INDEPENDENT_SECRET" }
  let(:policy) { described_class.new }

  # Encode the value as well as the syntax, so searching only raw output cannot pass accidentally.
  def encode_layers(value, layers)
    layers.times { value = value.bytes.map { |byte| format("%%%02X", byte) }.join }
    value
  end

  def decoded(value)
    3.times { value = URI::DEFAULT_PARSER.unescape(value) }
    value
  end

  def outputs(url)
    exchange = Automation::HttpExchange.new(method: "GET", url: url, response: { status: 200 })
    failure = Automation::FailureRedactor.new.redact(message: "request failed", frames: [url, "safe.rb:1:in run"])
    [policy.redact_url(url), policy.redact_text(url), failure.baseline,
     exchange.summary, exchange.to_markdown(presentation: "plain"), exchange.to_markdown(presentation: "rich"),
     ReportportalCucumber::Service::EvidencePresenter.failure(
       action: "request", error: RuntimeError.new("request failed"), url: url
     ).values.join("\n")]
  end

  { plain: "password", normalized: "pass word", unicode: 'pass\\u0077ord' }.each do |label, key|
    [false, true].each do |mask_prefix|
      [1, 2, 3].each do |layers|
        %i[path query fragment malformed].each do |location|
          it "masks #{label} keys, prefix=#{mask_prefix}, layers=#{layers}, in #{location}" do
            value = "#{mask_prefix ? described_class::MASK : ''}#{secret}"
            part = encode_layers(%({"#{key}":"#{value}"}), layers)
            url = case location
                  when :path then "https://example.test/#{part}"
                  when :query then "https://example.test/?#{part}"
                  when :fragment then "https://example.test/#x=#{part}"
                  when :malformed then "https://example.test/bad path##{part}"
                  end

            outputs(url.freeze).each { |output| expect(decoded(output)).not_to include(secret) }
          end
        end
      end
    end
  end

  [1, 2, 3].each do |layers|
    %i[path query malformed].each do |location|
      it "masks a Bearer value through #{layers} encoding layers in #{location}" do
        part = encode_layers("Bearer #{secret}", layers)
        url = case location
              when :path then "https://example.test/#{part}"
              when :query then "https://example.test/?#{part}"
              when :malformed then "https://example.test/bad path##{part}"
              end
        outputs(url).each { |output| expect(decoded(output)).not_to include(secret) }
      end
    end
  end

  it "uses the configured normalized key policy in the decoded post-condition" do
    custom = described_class.new(sensitive_keys: ["member_code"])
    part = encode_layers(JSON.generate("member code" => secret), 2)
    expect(decoded(custom.redact_url("https://example.test/#{part}"))).not_to include(secret)
  end

  it "accepts complete masks without confusing a prefix for a complete mask" do
    ['{"password":"[REDACTED]"}', 'password=[REDACTED]', 'Bearer [REDACTED]'].each do |value|
      [1, 2, 3].each do |layers|
        url = "https://example.test/#{encode_layers(value, layers)}"
        once = policy.redact_url(url)
        expect(once).not_to eq(described_class::OMITTED)
        expect(policy.redact_url(once)).to eq(once)
      end
    end
  end

  ["https://example.test/files/my%20report.pdf?page=2",
   "https://example.test/users/%7Bid%7D/profile",
   "https://example.test/a?%7B%22page%22%3A2%7D",
   "https://example.test/a?debug&token_count=12",
   "https://example.test/%E6%B5%8B%E8%AF%95"].each do |url|
    it "preserves the safe URL #{url}" do
      expect(policy.redact_url(url)).to eq(url)
    end
  end
end
