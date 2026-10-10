# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe "M2 assertion diagnostics" do
  it "presents concise failure summary and bounded details" do
    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "submit", error: RuntimeError.new("request failed"),
      url: "https://user:password@example.test/?token=secret",
      details: "Password: private\n" + ("detail " * 50_000), artifact_names: []
    )

    expect(result).to include(:summary, :details)
    expect(result.fetch(:summary)).to include("submit", "RuntimeError")
    expect(result.values.join).not_to include("password", "secret", "private")
    expect(result.fetch(:details).bytesize).to be <= 16_384
  end

  it "redacts quoted JSON secrets before bounded details and error summaries are clipped" do
    canary = "CANARY_M2_" + ("x" * 17_000)
    long_json = JSON.generate(password: canary)
    error_secret = "CANARY_M2_ERROR_" + ("y" * 300)

    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "request", error: RuntimeError.new(JSON.generate(password: error_secret)),
      details: long_json
    )

    expect(result.values.join).not_to include("CANARY_M2_")
    expect(result.fetch(:details).bytesize).to be <= 16_384
    expect(result.fetch(:summary).bytesize).to be <= 512
  end

  it "fails closed on a dangling escape and JSON whitespace at the public details limit" do
    limit = ReportportalCucumber::Service::EvidencePresenter::DETAILS_LIMIT
    head = '{"password":"CANARY_DANGLING_'
    clipped_at_escape = head + ("d" * (limit - head.bytesize - 1)) + "\\"
    complete_source = clipped_at_escape + %q("tail"})
    multiline = "{\"password\":\r\n  \"CANARY_MULTILINE_#{"m" * (limit + 100)}\"}"

    expect(JSON.parse(complete_source).fetch("password")).to start_with("CANARY_DANGLING_")
    expect(JSON.parse(multiline).fetch("password")).to start_with("CANARY_MULTILINE_")

    [complete_source, multiline].each do |details|
      result = ReportportalCucumber::Service::EvidencePresenter.failure(
        action: "request", error: RuntimeError.new("failed"), details: details
      )

      expect(result.fetch(:details)).not_to include("CANARY_DANGLING_", "CANARY_MULTILINE_")
      expect(result.fetch(:details).bytesize).to be <= limit
    end
  end

  it "reports pass and failure comparisons without changing Cucumber outcome" do
    world = double("Cucumber world", log: nil)
    output = StringIO.new
    AppLog.bind(world, output: output, color: false)
    expect { AppLog.assertion(name: "total", expected: 3, actual: 3, passed: true) }.not_to raise_error
    expect { AppLog.assertion(name: "total", expected: 3, actual: 4, passed: false) }.not_to raise_error

    expect(output.string).to include("PASS", "FAIL", "total")
    expect(output.string).not_to include("expected: 3", "actual: 4")
  ensure
    AppLog.clear!
  end

  it "redacts assertion values in terminal, native Cucumber logs, and ReportPortal payloads" do
    native = []
    rp_entries = []
    world = Object.new
    world.define_singleton_method(:rp_active?) { true }
    world.define_singleton_method(:log) { |message| native << message }
    world.define_singleton_method(:rp_log) do |message, level = nil, **_options|
      rp_entries << [message, level]
    end
    output = StringIO.new
    AppLog.bind(world, output: output, color: false)
    long_secret = "CANARY_M2_ASSERTION_" + ("z" * 17_000)

    AppLog.assertion(
      name: "credential check", expected: { password: "expected-secret" },
      actual: { password: "actual-secret" }, passed: false,
      details: JSON.generate(payload: { password: long_secret }), report: true
    )

    [output.string, native.join, rp_entries.inspect].each do |text|
      expect(text).not_to include("expected-secret", "actual-secret", "CANARY_M2_ASSERTION_")
    end
    expect(output.string.bytesize).to be <= 600
    expect(native.first.bytesize).to be <= ReportportalCucumber::Service::EvidencePresenter::DETAILS_LIMIT
    expect(rp_entries.first.first.bytesize).to be <= ReportportalCucumber::Service::EvidencePresenter::DETAILS_LIMIT
    expect(native.join).to include("credential check", "FAIL")
    expect(rp_entries.join).to include("credential check", "FAIL")
  ensure
    AppLog.clear!
  end

  it "does not mutate caller-owned values or make a failed diagnostic an assertion exception" do
    expected = { password: "keep-secret" }.freeze
    actual = { value: [1, 2].freeze }.freeze
    world = double("Cucumber world", log: nil)
    AppLog.bind(world, output: StringIO.new, color: false)

    expect do
      AppLog.assertion(name: "diagnostic", expected: expected, actual: actual,
                       passed: false, report: false)
    end.not_to raise_error
    expect(expected[:password]).to eq("keep-secret")
    expect(actual[:value]).to eq([1, 2])
  ensure
    AppLog.clear!
  end

  it "sanitizes complete escaped-key JSON and long error text before applying output limits" do
    secret = "SECURITY_FULL_JSON_" + ("s" * 300)
    error_secret = "SECURITY_LONG_ERROR_" + ("e" * 300)
    userinfo_secret = "SECURITY_LONG_URL_PASSWORD_" + ("u" * 600)
    details = %({"\\u0070assword":"#{secret}","note":"safe-detail"}) + (" " * 17_000)
    error = RuntimeError.new(%({"\\u0070assword":"#{error_secret}","note":"safe-error"}))
    url = "https://SECURITY_LONG_URL_USER:#{userinfo_secret}@example.test/path"

    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "security regression", error: error, url: url, details: details
    )

    expect(result.fetch(:summary).bytesize).to be <= 512
    expect(result.fetch(:details).bytesize).to be <= 16_384
    expect(result.values.join).not_to include("SECURITY_FULL_JSON_", "SECURITY_LONG_ERROR_",
                                              "SECURITY_LONG_URL_USER", "SECURITY_LONG_URL_PASSWORD_")
    expect(result.values.join).to include("security regression", "RuntimeError")
  end

  it "fails closed for oversized, cyclic, nested, and invalid-encoding diagnostics" do
    oversized = %({"\\u0070assword":"SECURITY_OVER_BUDGET_#{"x" * 70_000}"})
    cycle = { "safe" => "readable", "nested" => [] }
    cycle["nested"] << cycle
    binary = ("Password: SECURITY_INVALID_UTF8_SECRET\xFF".b).freeze
    original = Marshal.dump(cycle)
    unsupported = Object.new
    unsupported_calls = 0
    unsupported.define_singleton_method(:to_s) do
      unsupported_calls += 1
      "SECURITY_UNKNOWN_OBJECT_SECRET"
    end

    [oversized, cycle, binary, unsupported].each do |details|
      expect do
        ReportportalCucumber::Service::EvidencePresenter.failure(
          action: "bounded security regression", error: RuntimeError.new("safe failure"), details: details
        )
      end.not_to raise_error
    end

    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "bounded security regression", error: RuntimeError.new("safe failure"), details: oversized
    )
    expect(result.values.join).not_to include("SECURITY_OVER_BUDGET_")
    expect(result.fetch(:details).bytesize).to be <= 16_384
    expect(result.values.join).to include("bounded security regression", "safe failure")
    expect(Marshal.dump(cycle)).to eq(original)
    expect(binary.encoding).to eq(Encoding::BINARY)
    expect(binary.bytes).to include(0xFF)
    expect(unsupported_calls).to eq(0)
  end

  it "keeps safe short diagnostics readable and omits unsupported titles and artifact names" do
    unsupported = Object.new
    calls = 0
    unsupported.define_singleton_method(:to_s) { calls += 1; "SECURITY_UNSUPPORTED_NAME" }
    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "safe action remains readable", error: RuntimeError.new("safe short failure"),
      details: "safe short details", artifact_names: ["screen.png", unsupported]
    )
    assertion = ReportportalCucumber::Service::EvidencePresenter.assertion(
      name: unsupported, expected: "safe expected", actual: "safe actual", passed: false
    )

    expect(result.fetch(:summary)).to include("safe action remains readable", "safe short failure", "screen.png")
    expect(result.fetch(:details)).to include("safe short details")
    expect(assertion.fetch(:summary)).to include("FAIL")
    expect(result.values.join + assertion.values.join).not_to include("SECURITY_UNSUPPORTED_NAME")
    expect(calls).to eq(0)

    secret = "SECURITY_ARTIFACT_TITLE_SECRET"
    encoded = %({"\\u0070assword":"#{secret}"})
    unsafe_names = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: encoded, error: RuntimeError.new("safe failure"), artifact_names: [encoded]
    )
    expect(unsafe_names.values.join).not_to include(secret)

    malformed = %({"\\u0070assword" : "SECURITY_MALFORMED_EMBEDDED_KEY)
    malformed_result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "safe action", error: RuntimeError.new("safe failure"),
      details: "prefix text #{malformed}"
    )
    expect(malformed_result.fetch(:details)).not_to include("SECURITY_MALFORMED_EMBEDDED_KEY")
  end

  it "does not expose a credential embedded in a percent-encoded URL fragment" do
    secret = "SECURITY_PERCENT_FRAGMENT_SECRET"
    url = "https://example.test/path#%7B%22password%22%3A%22#{secret}%22%7D"
    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "fragment check", error: RuntimeError.new("safe failure"), url: url
    )

    expect(result.fetch(:summary)).not_to include(secret)
    expect(result.fetch(:summary).bytesize).to be <= 512
  end

  it "fails closed on complete and embedded JSON with malformed escaped credential keys" do
    malformed_keys = {
      complete_hex_escape: %({"pass\\x77ord":"SECURITY_MALFORMED_HEX_KEY"}),
      complete_unicode_escape: %({"\\u00ZZpassword":"SECURITY_MALFORMED_UNICODE_KEY"}),
      embedded_hex_escape: %(prefix diagnostic {"pass\\x77ord":"SECURITY_EMBEDDED_MALFORMED_KEY"})
    }

    malformed_keys.each do |label, source|
      result = ReportportalCucumber::Service::EvidencePresenter.failure(
        action: "malformed key #{label}", error: RuntimeError.new("safe failure"), details: source
      )

      expect(result.fetch(:summary).bytesize).to be <= 512
      expect(result.fetch(:details).bytesize).to be <= 16_384
      expect(result.values.join).not_to include(
        "SECURITY_MALFORMED_HEX_KEY", "SECURITY_MALFORMED_UNICODE_KEY", "SECURITY_EMBEDDED_MALFORMED_KEY"
      )
    end
  end

  {
    embedded_hashrocket: 'failed: {"\\u0070assword" => "SECURITY_EDGE_HASHROCKET"}',
    embedded_equal: 'failed: {"\\u0070assword" = "SECURITY_EDGE_EQUAL"}',
    embedded_long_key: 'failed: {"' + ("." * 4_100) + '\\u0070assword":"SECURITY_EDGE_LONG_KEY"}',
    embedded_escaped_space: 'failed: {"\\u0070assword"\\u0020:"SECURITY_EDGE_ESCAPED_SPACE"}'
  }.each do |label, source|
    it "fails closed for the review escaped-key edge #{label}" do
      original = source.dup
      result = ReportportalCucumber::Service::EvidencePresenter.failure(
        action: "safe edge action", error: RuntimeError.new("safe failure"), details: source
      )
      expect(result.values.join).not_to include("SECURITY_EDGE_")
      expect(result.fetch(:summary).bytesize).to be <= 512
      expect(result.fetch(:details).bytesize).to be <= 16_384
      expect(source).to eq(original)
    end
  end

  it "redacts a partially encoded fragment pair whose value contains another equals sign" do
    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "safe fragment action", error: RuntimeError.new("safe failure"),
      url: "https://example.test/#password%3DSECURITY_EDGE_PARTIAL_PAIR=suffix"
    )
    expect(result.values.join).not_to include("SECURITY_EDGE_PARTIAL_PAIR")
    expect(result.fetch(:summary).bytesize).to be <= 512
  end

  it "keeps safe business diagnostics readable after escaped-key validation" do
    safe = "token_count=12 password_policy=business-only component=payments"
    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "safe business action", error: RuntimeError.new("safe failure"), details: safe
    )
    expect(result.fetch(:details)).to eq(safe)
  end

  {
    mismatched_object_close: 'failed: {]"\\u0070assword":"SECURITY_READY5_OBJECT_CLOSE"}',
    mismatched_array_close: 'failed: [}"\\u0070assword":"SECURITY_READY5_ARRAY_CLOSE"]',
    unquoted_escaped_key: 'failed: {\\u0070assword:"SECURITY_READY5_UNQUOTED_KEY"}',
    leading_separator: "_password=SECURITY_READY5_LEADING_SEPARATOR",
    trailing_separator: "password_=SECURITY_READY5_TRAILING_SEPARATOR",
    surrounding_separators: "-password-=SECURITY_READY5_SURROUNDING_SEPARATORS"
  }.each do |label, source|
    it "sanitizes the finite READY5 diagnostic edge #{label}", :aggregate_failures do
      original = source.dup
      result = ReportportalCucumber::Service::EvidencePresenter.failure(
        action: source, error: RuntimeError.new(source), details: source, artifact_names: [source]
      )
      assertion = ReportportalCucumber::Service::EvidencePresenter.assertion(
        name: source, expected: source, actual: source, passed: false, details: source
      )

      [[result, :details], [assertion, :markdown]].each do |diagnostic, body_key|
        expect(diagnostic.values.join).not_to include("SECURITY_READY5_")
        expect(diagnostic.fetch(:summary).bytesize).to be <= 512
        expect(diagnostic.fetch(body_key).bytesize).to be <= 16_384
      end
      expect(source).to eq(original)
      expect(assertion.fetch(:summary)).to include("FAIL")
      if label.to_s.include?("separator")
        key = source.split("=", 2).first
        expect(Automation::CredentialKeys.sensitive?(key)).to be(true)
      end
    end
  end

  it "keeps finite READY5 safe business controls readable", :aggregate_failures do
    details = "password_policy=business-only token_count=12 monkey=visible " \
      "component=payments; expected [one, two]; received [three]"
    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "safe business action", error: RuntimeError.new("safe short failure"), details: details,
      url: "https://example.test/#component%3Dpayments=suffix&state=ok", artifact_names: ["safe-control.png"]
    )
    expect(result.fetch(:details)).to eq(details)
    expect(result.fetch(:summary)).to include("safe business action", "safe short failure", "safe-control.png")
    expect(result.fetch(:summary)).to include("component%3Dpayments=suffix&state=ok")
    %w[password_policy token_count monkey component].each do |key|
      expect(Automation::CredentialKeys.sensitive?(key)).to be(false)
    end
  end

  it "bounds each structural value and traversal while preserving safe neighboring values" do
    details = {
      "safe" => "visible-" + ("v" * 5_000),
      "password" => "SECURITY_STRUCTURED_SECRET",
      "many" => Array.new(300, "small")
    }
    original = Marshal.dump(details)
    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "structured safe action", error: RuntimeError.new("safe failure"), details: details
    )
    parsed = JSON.parse(result.fetch(:details))

    expect(parsed.fetch("safe").bytesize).to be <= 4_096
    expect(parsed.fetch("safe")).to start_with("visible-v")
    expect(parsed.fetch("password")).not_to include("SECURITY_STRUCTURED_SECRET")
    expect(parsed.fetch("many").length).to be <= 256
    expect(result.fetch(:details).bytesize).to be <= 16_384
    expect(result.fetch(:summary).bytesize).to be <= 512
    expect(Marshal.dump(details)).to eq(original)
  end

  it "charges rejected hash keys against the structural traversal budget" do
    counted_hash = Class.new(Hash) do
      attr_reader :visited_entries

      def initialize
        super
        @visited_entries = 0
      end

      def each
        return enum_for(:each) unless block_given?

        super do |key, value|
          @visited_entries += 1
          yield key, value
        end
      end
    end.new
    400.times do |index|
      counted_hash[Object.new] = "SECURITY_REJECTED_KEY_VALUE_#{index}"
      counted_hash["password"] = "SECURITY_SENSITIVE_KEY_VALUE_#{index}"
      counted_hash["invalid key #{index}"] = "SECURITY_INVALID_KEY_VALUE_#{index}"
      counted_hash["k" * 129 + index.to_s] = "SECURITY_OVERSIZED_KEY_VALUE_#{index}"
    end

    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "bounded key traversal", error: RuntimeError.new("safe failure"), details: counted_hash
    )

    expect(counted_hash.visited_entries).to be <= 256
    expect(result.fetch(:details).bytesize).to be <= 16_384
    expect(result.fetch(:details)).not_to include(
      "SECURITY_REJECTED_KEY_VALUE_", "SECURITY_SENSITIVE_KEY_VALUE_399"
    )
  end

  it "honors tiny public sanitizer limits without invoking unsupported scalar methods" do
    unsupported = Object.new
    unsupported_calls = 0
    unsupported.define_singleton_method(:to_s) do
      unsupported_calls += 1
      "SECURITY_UNSUPPORTED_SCALAR"
    end
    oversized = "SECURITY_OVERSIZED_SCALAR_" + ("x" * 70_000)
    giant_integer = 10**40_000
    hostile_numeric = Class.new(Numeric) do
      attr_reader :calls

      def initialize
        @calls = 0
      end

      def to_json(*)
        @calls += 1
        '{"password":"SECURITY_CUSTOM_NUMERIC"}'
      end

      def to_s
        @calls += 1
        "SECURITY_CUSTOM_NUMERIC"
      end

      def <=>(other) = other.to_i <=> 1
      def coerce(other) = [other, 1]
      def to_i = 1
      def to_f = 1.0
    end.new
    sanitizer = ReportportalCucumber::Service::EvidencePresenter

    (0..3).each do |limit|
      ["safe", oversized, unsupported, giant_integer, hostile_numeric].each do |value|
        result = sanitizer.sanitize_diagnostic(value, limit: limit)
        expect(result.bytesize).to be <= limit
      end
    end
    expect(unsupported_calls).to eq(0)
    expect(hostile_numeric.calls).to eq(0)
  end
end
