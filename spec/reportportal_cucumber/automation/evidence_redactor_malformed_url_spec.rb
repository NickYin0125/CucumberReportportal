# frozen_string_literal: true

require "spec_helper"
require "reportportal_cucumber/automation/evidence_redactor"

RSpec.describe Automation::EvidenceRedactor, "whitespace-truncated URLs" do
  let(:policy) { described_class.new }
  let(:secret) { "SYNTHETIC_WHITESPACE_SECRET" }
  let(:masked_fragment) { "%7B%22password%22%3A%22%5BREDACTED%5D%22%7D" }

  it "agrees with whole-URL sanitization after whitespace ends the URL token" do
    url = "https://example.test/bad path#%7B%22pass%5Cu0077ord%22%3A%22#{secret}%22%7D".freeze
    expected = "https://example.test/bad path##{masked_fragment}"

    expect(policy.redact_url(url)).to eq(expected)
    expect(policy.redact_text(url)).to eq(expected)
  end

  {
    json_unicode_escape: "#%7B%22pass%5Cu0077ord%22%3A%22SECRET%22%7D",
    lowercase_hex: "#%7b%22pass%5cu0077ord%22%3a%22SECRET%22%7d",
    fully_percent_encoded_name: "#%7B%22%70%61%73%73%77%6F%72%64%22%3A%22SECRET%22%7D",
    fragment_query_name: "#%70assword=SECRET",
    encoded_separator: "#password%3DSECRET",
    query_name: "?x=1&pass%77ord=SECRET",
    underscore_name: "?api%5Fkey=SECRET",
    access_token_name: "#access%5Ftoken=SECRET"
  }.each do |name, tail|
    it "masks #{name} after space and tab separators" do
      [" ", "\t", "  "].each do |separator|
        text = "https://example.test/bad#{separator}path#{tail.sub('SECRET', secret)}".freeze
        output = policy.redact_text(text)

        expect(output).not_to include(secret)
        expect(output).to start_with("https://example.test/bad#{separator}path")
      end
    end
  end

  it "masks a query continued after whitespace following a question mark" do
    output = policy.redact_text("https://example.test/x?a=1 b&%70assword=#{secret}")

    expect(output).to eq("https://example.test/x?a=1 b&#{described_class::MASK}")
  end

  it "masks encoded credential JSON in free text without a URL token" do
    output = policy.redact_text("payload %7B%22password%22%3A%22#{secret}%22%7D")

    expect(output).to eq("payload #{masked_fragment}")
  end

  it "fails closed for double-encoded credential names" do
    text = "https://example.test/a b#%257B%2522password%2522%253A%2522#{secret}%2522%257D"

    expect(policy.redact_text(text)).to eq(described_class::OMITTED)
  end

  {
    truncated_value: "%7B%22password%22%3A%22SECRET",
    dangling_escape: "%7B%22password%22%3A%22SECRET%2",
    invalid_escape: "%7B%22password%22%3A%22SECRET%ZZ%22%7D",
    unterminated_key: "%7B%22pass%5Cu0077ord%22%3A%22SECRET"
  }.each do |name, fragment|
    it "does not expose the value for #{name}" do
      output = policy.redact_text("https://example.test/a b##{fragment.sub('SECRET', secret)}")

      expect(output).not_to include(secret)
      expect(output).to start_with("https://example.test/a b#").or eq(described_class::OMITTED)
    end
  end

  { space: " ", newline: "\n", tab_and_newline: "\t\n" }.each do |name, separator|
    it "fails closed when an encoded key and its value are split by #{name}" do
      text = "https://example.test/a b#%7B%22pass%5Cu0077ord%22%3A#{separator}%22#{secret}%22%7D"

      expect(policy.redact_text(text)).to eq(described_class::OMITTED)
    end
  end

  it "fails closed when an encoded key is followed by a plain value token" do
    expect(policy.redact_text("context x#%70assword%3D #{secret}")).to eq(described_class::OMITTED)
  end

  it "masks encoded credential JSON in a well-formed URL path" do
    output = policy.redact_text("GET https://example.test/%7B%22password%22%3A%22#{secret}%22%7D")

    expect(output).to eq("GET https://example.test/#{masked_fragment}")
  end

  {
    encoded_space: "/app/my%20file.rb:10:in 'call'",
    encoded_braces: "/srv/%7Bid%7D/file.rb:12:in 'run'",
    safe_encoded_fragment: "https://example.test/a b#%7B%22page%22%3A2%7D",
    percent_sign: "progress 50%25 done",
    non_hex_percent: "format %s and %d"
  }.each do |name, text|
    it "keeps #{name} byte-identical" do
      expect(policy.redact_text(text)).to eq(text)
    end
  end

  describe "#cross_unit_credential? without activating failure-log redaction" do
    {
      encoded_json: ["path#%7B%22password%22%3A", "%22SYNTHETIC_BOUNDARY_SECRET%22%7D"],
      unicode_key: ["path#%7B%22pass%5Cu0077ord%22%3A", "%22SYNTHETIC_BOUNDARY_SECRET%22%7D"],
      encoded_separator: ["x#%70assword%3D", "SYNTHETIC_BOUNDARY_SECRET"],
      plain_key: ["password=", "SYNTHETIC_BOUNDARY_SECRET"]
    }.each do |name, units|
      it "detects a credential across #{name} units" do
        frozen_units = units.map(&:freeze).freeze

        expect(policy.cross_unit_credential?(frozen_units)).to be(true)
      end
    end

    it "does not flag safe encoded units or a credential contained within one unit" do
      expect(policy.cross_unit_credential?(["safe %20 text", "/app/%7Bid%7D/file.rb:12"])).to be(false)
      expect(policy.cross_unit_credential?(["password=SYNTHETIC_LOCAL_SECRET", "safe line"])).to be(false)
      expect(policy.cross_unit_credential?(["password=SYNTHETIC_LOCAL_SECRET"])).to be(false)
    end
  end
end
