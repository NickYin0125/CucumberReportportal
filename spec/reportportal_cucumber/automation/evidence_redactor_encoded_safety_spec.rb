# frozen_string_literal: true

require "spec_helper"
require "uri"
require "reportportal_cucumber/automation/evidence_redactor"

RSpec.describe Automation::EvidenceRedactor, "encoded output safety" do
  let(:secret) { "SYNTHETIC_INDEPENDENT_SECRET" }
  let(:policy) { described_class.new }

  # Encode the value as well as the syntax so raw-output checks cannot pass accidentally.
  def encode_layers(value, layers)
    layers.times { value = value.bytes.map { |byte| format("%%%02X", byte) }.join }
    value
  end

  def decoded(value)
    3.times { value = URI::DEFAULT_PARSER.unescape(value) }
    value
  end

  def outputs(url)
    structured = policy.redact({ "url" => url }.freeze)
    structured = structured.fetch("url") if structured.is_a?(Hash)
    [policy.redact_url(url), policy.redact_text(url), structured]
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
                  end.freeze

            outputs(url).each { |output| expect(decoded(output)).not_to include(secret) }
          end
        end
      end
    end
  end

  [false, true].each do |mask_prefix|
    [1, 2, 3].each do |layers|
      %i[path query fragment malformed].each do |location|
        it "masks Bearer values, prefix=#{mask_prefix}, layers=#{layers}, in #{location}" do
          value = "#{mask_prefix ? described_class::MASK : ''}#{secret}"
          part = encode_layers("Bearer #{value}", layers)
          url = case location
                when :path then "https://example.test/#{part}"
                when :query then "https://example.test/?#{part}"
                when :fragment then "https://example.test/##{part}"
                when :malformed then "https://example.test/bad path##{part}"
                end.freeze

          outputs(url).each { |output| expect(decoded(output)).not_to include(secret) }
        end
      end
    end
  end

  it "uses the configured normalized key policy in the decoded post-condition" do
    custom = described_class.new(sensitive_keys: ["member_code"])
    ["member code", "M___E---M_B_E_R.C_O_D_E", 'member_\\u0063ode'].each do |key|
      [1, 2, 3].each do |layers|
        part = encode_layers(%({"#{key}":"#{secret}"}), layers)
        url = "https://example.test/#{part}"
        [custom.redact_url(url), custom.redact_text(url)].each do |output|
          expect(decoded(output)).not_to include(secret)
        end
      end
    end
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
      outputs(url.freeze).each { |output| expect(output).to eq(url) }
    end
  end

  it "retains the input-size limit before any percent decoding" do
    oversized = ("%25" * described_class::MAX_INPUT_BYTES).freeze

    expect(policy.redact_url(oversized)).to eq(described_class::OMITTED)
    expect(policy.redact_text(oversized)).to eq(described_class::OMITTED)
  end
end
