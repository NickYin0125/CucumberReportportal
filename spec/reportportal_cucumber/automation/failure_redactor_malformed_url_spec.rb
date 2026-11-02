# frozen_string_literal: true

require "spec_helper"
require "uri"
require "reportportal_cucumber/automation/failure_redactor"

# Whitespace ends the free-text URL token early; its encoded remainder must not escape redaction.
RSpec.describe Automation::FailureRedactor do
  let(:mask) { Automation::EvidenceRedactor::MASK }
  let(:omitted) { Automation::EvidenceRedactor::OMITTED }
  let(:policy) { Automation::EvidenceRedactor.new }
  let(:secret) { "SYNTHETIC_FRAME_SECRET" }
  let(:masked_fragment) { "%7B%22password%22%3A%22%5BREDACTED%5D%22%7D" }

  def safe_frames(tag = "FROZEN")
    ["/project/#{tag}/support.rb:65:in 'inner_failure'",
     "/project/#{tag}/support.rb:59:in 'deep_failure'",
     "/project/#{tag}/support.rb:136:in 'step'",
     "/project/#{tag}/features/audit.feature:5:in 'failure'"] +
      Array.new(56) { |index| "/ruby/gems/cucumber/#{tag}/runner.rb:#{index + 1}:in 'run'" } +
      ["-e:1:in 'run'", "<internal:kernel>:90:in 'require'"]
  end

  def sanitizers
    { shared_default: described_class.new, fresh_injected: described_class.new(redactor: Automation::EvidenceRedactor.new) }
  end

  def expect_no_secret(result, *secrets)
    result.to_h.each_value do |value|
      next unless value.is_a?(String)

      secrets.each { |marker| expect(value).not_to include(marker) }
    end
  end

  describe "the original deferred probe input" do
    # Byte-identical to the QA probe and the original failing fixture; never weakened.
    let(:message) { "request https://alice:FROZEN_MESSAGE_SECRET@example.test/path?token=FROZEN_MESSAGE_SECRET&count=12" }
    let(:frame) { "https://example.test/bad path#%7B%22pass%5Cu0077ord%22%3A%22FROZEN_FRAME_SECRET%22%7D" }
    let(:input) { { message: message, frames: [frame, *safe_frames].each(&:freeze).freeze } }

    it "masks the encoded credential with both policies while keeping the frame and all 62 safe frames" do
      results = sanitizers.transform_values { |sanitizer| sanitizer.redact(**input).to_h }

      expect(results.fetch(:shared_default)).to eq(results.fetch(:fresh_injected))
      results.each_value do |result|
        expect_no_secret(Automation::FailureRedactor::Result.new(**result), "FROZEN_MESSAGE_SECRET", "FROZEN_FRAME_SECRET")
        expect(result.fetch(:message)).to eq("request https://example.test/path?token=%5BREDACTED%5D&count=12")
        expect(result.fetch(:backtrace)).to eq(["https://example.test/bad path##{masked_fragment}", *safe_frames].join("\n"))
        expect(result.fetch(:baseline)).to eq([result.fetch(:message), result.fetch(:backtrace)].join("\n"))
        expect(result.fetch(:fallback_only)).to be(false)
      end
    end

    it "agrees with direct whole-URL sanitization of the malformed frame" do
      expect(policy.redact_text(frame)).to eq(policy.redact_url(frame))
    end
  end

  describe "encoded credential names after a whitespace-truncated URL" do
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
      it "masks #{name} for space and tab separators" do
        [" ", "\t", "  "].each do |separator|
          text = "https://example.test/bad#{separator}path#{tail.sub('SECRET', secret)}"
          output = policy.redact_text(text)

          expect(output).not_to include(secret)
          expect(output).to start_with("https://example.test/bad#{separator}path")
        end
      end
    end

    it "masks a query continued after whitespace once the question mark has already appeared" do
      output = policy.redact_text("https://example.test/x?a=1 b&%70assword=#{secret}")

      expect(output).to eq("https://example.test/x?a=1 b&#{mask}")
    end

    it "masks encoded credential JSON in free text with no URL token at all" do
      output = policy.redact_text("payload %7B%22password%22%3A%22#{secret}%22%7D")

      expect(output).to eq("payload #{masked_fragment}")
    end

    it "fails closed for double-encoded credential names" do
      text = "https://example.test/a b#%257B%2522password%2522%253A%2522#{secret}%2522%257D"

      expect(policy.redact_text(text)).to eq(omitted)
    end
  end

  describe "malformed and incomplete encoded input" do
    {
      truncated_value: "%7B%22password%22%3A%22SECRET",
      dangling_escape: "%7B%22password%22%3A%22SECRET%2",
      invalid_escape: "%7B%22password%22%3A%22SECRET%ZZ%22%7D",
      unterminated_key: "%7B%22pass%5Cu0077ord%22%3A%22SECRET"
    }.each do |name, fragment|
      it "does not expose the value for #{name}" do
        output = policy.redact_text("https://example.test/a b##{fragment.sub('SECRET', secret)}")

        expect(output).not_to include(secret)
        expect(output).to start_with("https://example.test/a b#").or eq(omitted)
      end
    end

    { space: " ", newline: "\n", tab_and_newline: "\t\n" }.each do |name, separator|
      it "fails closed when the encoded key and its value are split by a #{name}" do
        text = "https://example.test/a b#%7B%22pass%5Cu0077ord%22%3A#{separator}%22#{secret}%22%7D"

        expect(policy.redact_text(text)).to eq(omitted)
      end
    end

    it "fails closed when an encoded key is followed by a plain value token" do
      expect(policy.redact_text("context x#%70assword%3D #{secret}")).to eq(omitted)
    end

    it "masks encoded credential JSON in a well-formed URL path" do
      output = policy.redact_text("GET https://example.test/%7B%22password%22%3A%22#{secret}%22%7D")

      expect(output).to eq("GET https://example.test/#{masked_fragment}")
    end
  end

  describe "message and backtrace boundaries" do
    let(:frames) { safe_frames("BOUNDARY") }

    it "masks a malformed URL carried in the message without touching frames" do
      sanitizers.each_value do |sanitizer|
        result = sanitizer.redact(message: "GET https://example.test/bad path#%7B%22pass%5Cu0077ord%22%3A%22#{secret}%22%7D failed",
                                  frames: frames)

        expect(result.message).to eq("GET https://example.test/bad path##{masked_fragment} failed")
        expect(result.backtrace).to eq(frames.join("\n"))
        expect(result.fallback_only).to be(false)
      end
    end

    it "masks a URL whose encoded remainder becomes the first frame" do
      sanitizers.each_value do |sanitizer|
        result = sanitizer.redact(message: "GET https://example.test/bad",
                                  frames: ["path#%7B%22pass%5Cu0077ord%22%3A%22#{secret}%22%7D", *frames])

        expect(result.message).to eq("GET https://example.test/bad")
        expect(result.backtrace).to eq(["path##{masked_fragment}", *frames].join("\n"))
        expect(result.fallback_only).to be(false)
      end
    end

    {
      message_to_frame: ["GET https://example.test/bad path#%7B%22pass%5Cu0077ord%22%3A", ["%22SECRET%22%7D"]],
      frame_to_frame: ["boom", ["https://example.test/bad path#%7B%22password%22%3A", "%22SECRET%22%7D"]],
      encoded_separator_to_frame: ["boom", ["x#%70assword%3D", "SECRET"]]
    }.each do |name, (message, split_frames)|
      it "withholds the whole failure when an encoded key crosses #{name}" do
        sanitizers.each_value do |sanitizer|
          result = sanitizer.redact(message: message, frames: [*split_frames.map { |f| f.sub("SECRET", secret) }, *frames])

          expect_no_secret(result, secret)
          expect(result.fallback_only).to be(true)
          expect(result.baseline).to eq(omitted)
        end
      end
    end
  end

  describe "safe diagnostics" do
    {
      encoded_space_frame: "/app/my%20file.rb:10:in 'call'",
      encoded_braces_frame: "/srv/%7Bid%7D/file.rb:12:in 'run'",
      safe_encoded_fragment: "https://example.test/a b#%7B%22page%22%3A2%7D",
      percent_sign: "progress 50%25 done",
      non_hex_percent: "format %s and %d"
    }.each do |name, text|
      it "keeps #{name} byte-identical" do
        expect(policy.redact_text(text)).to eq(text)
      end
    end

    it "keeps encoded safe frames with no fallback" do
      frames = ["/app/my%20file.rb:10:in 'call'", *safe_frames("SAFE")]
      result = described_class.new.redact(message: "boom %20 ok", frames: frames)

      expect(result.to_h).to eq(message: "boom %20 ok", backtrace: frames.join("\n"),
                                baseline: "boom %20 ok\n#{frames.join("\n")}", fallback_only: false)
    end
  end
end
