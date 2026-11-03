# frozen_string_literal: true

require "spec_helper"
require "uri"
require "reportportal_cucumber/automation/evidence_redactor"

RSpec.describe Automation::EvidenceRedactor, "encoded URL components" do
  let(:policy) { described_class.new }
  let(:secret) { "SYNTHETIC_URL_SECRET" }
  let(:masked_json) { "%7B%22password%22%3A%22%5BREDACTED%5D%22%7D" }

  def encoded_json(key)
    URI.encode_www_form_component(%({"#{key}":"#{secret}"}))
  end

  {
    path_segment: ->(json) { "https://example.test/api/#{json}/items" },
    last_path_segment: ->(json) { "https://example.test/#{json}" },
    valueless_query: ->(json) { "https://example.test/a?#{json}" },
    valueless_query_after_pair: ->(json) { "https://example.test/a?x=1&#{json}&y=2" },
    path_and_fragment: ->(json) { "https://example.test/#{json}#section" }
  }.each do |place, build|
    %w[password pass\\u0077ord api_key].each do |key|
      it "masks a #{key} credential encoded in the #{place}" do
        output = policy.redact_url(build.call(encoded_json(key)))

        expect(URI::DEFAULT_PARSER.unescape(output)).not_to include(secret)
        expect(output).to start_with("https://example.test/")
      end
    end
  end

  it "keeps the URL structure and masked JSON shape for a path segment" do
    output = policy.redact_url("https://example.test/api/#{encoded_json('password')}/items?x=1")

    expect(output).to eq("https://example.test/api/#{masked_json}/items?x=1")
  end

  it "keeps the URL structure for a valueless query part" do
    output = policy.redact_url("https://example.test/a?x=1&#{encoded_json('password')}&y=2")

    expect(output).to eq("https://example.test/a?x=1&#{masked_json}&y=2")
  end

  it "masks encoded key=value pairs in path segments" do
    output = policy.redact_url("https://example.test/session/%70assword%3D#{secret}/next")

    expect(output).not_to include(secret)
    expect(output).to start_with("https://example.test/session/").and end_with("/next")
  end

  it "fails closed for double-encoded path credentials" do
    json = URI.encode_www_form_component(encoded_json("password"))
    output = policy.redact_url("https://example.test/#{json}")

    expect(URI::DEFAULT_PARSER.unescape(URI::DEFAULT_PARSER.unescape(output))).not_to include(secret)
  end

  it "fails closed through the malformed-URL fallback" do
    output = policy.redact_url("https://example.test/bad path/#{encoded_json('password')}")

    expect(output).not_to include(secret)
  end

  {
    encoded_space: "https://example.test/files/my%20report.pdf?page=2",
    encoded_braces: "https://example.test/users/%7Bid%7D/profile",
    safe_encoded_json: "https://example.test/a?%7B%22page%22%3A2%7D",
    valueless_flag: "https://example.test/a?debug&x=1",
    encoded_unicode: "https://example.test/%E6%B5%8B%E8%AF%95"
  }.each do |name, url|
    it "keeps #{name} byte-identical and stable" do
      expect(policy.redact_url(url)).to eq(url)
    end
  end

  it "is idempotent on its own masked output" do
    once = policy.redact_url("https://example.test/#{encoded_json('password')}?#{encoded_json('token')}")

    expect(policy.redact_url(once)).to eq(once)
    expect(policy.redact_text("GET #{once}")).to eq("GET #{once}")
  end
end
