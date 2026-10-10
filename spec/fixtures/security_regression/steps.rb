# frozen_string_literal: true

Before { AppLog.bind(self, color: false) }
After do
  if @security_first_capture_target
    [false, Object.new, @security_first_capture_target].each do |target|
      rp_evidence(action: "LIFECYCLE_REJECTED_AFTER", error: RuntimeError.new("safe"), target: target)
    end

    rp_evidence(action: "LIFECYCLE_ACCEPTED_AFTER_NIL", error: RuntimeError.new("safe"))
    rp_evidence(action: "LIFECYCLE_ACCEPTED_AFTER_OPEN", error: RuntimeError.new("safe"),
                target: rp_capture_target)
  end
ensure
  AppLog.clear!
end

Given("I save the first security capture target") do
  @security_first_capture_target = rp_capture_target
end

When("I probe capture targets during the next step") do
  [false, Object.new, @security_first_capture_target].each do |target|
    rp_evidence(action: "LIFECYCLE_REJECTED_STEP", error: RuntimeError.new("safe"), target: target)
  end

  rp_evidence(action: "LIFECYCLE_ACCEPTED_STEP_NIL", error: RuntimeError.new("safe"))
  rp_evidence(action: "LIFECYCLE_ACCEPTED_STEP_OPEN", error: RuntimeError.new("safe"),
              target: rp_capture_target)
end

When("I emit a safe finite transport diagnostic") do
  AppLog.assertion(name: "safe finite transport boundary", expected: "safe", actual: "safe", passed: true,
                   details: "password_policy=business-only token_count=12 monkey=visible component=payments; expected [one, two]")
end

When("I emit synthetic security diagnostics through the public API") do
  escaped_json_secret = "SECURITY_CLI_JSON_" + ("j" * 17_100)
  error_secret = "SECURITY_CLI_ERROR_" + ("e" * 400)
  url_secret = "SECURITY_CLI_URL_PASSWORD_" + ("u" * 700)
  full_json = %({"\\u0070assword":"#{escaped_json_secret}","note":"safe-json-detail"})

  AppLog.assertion(
    name: "security assertion",
    expected: { "password" => "SECURITY_CLI_EXPECTED" },
    actual: { "password" => "SECURITY_CLI_ACTUAL" },
    passed: false,
    details: full_json
  )

  rp_evidence(
    action: "security evidence action",
    error: RuntimeError.new(%({"\\u0070assword":"#{error_secret}","note":"safe-error"})),
    url: "https://SECURITY_CLI_URL_USER:#{url_secret}@example.test/path",
    details: full_json,
    target: rp_capture_target
  )

  malformed_fragments = [
    'embedded {"pass\\u0077ord":"SECURITY_EMBEDDED_INCOMPLETE_QUOTE',
    'embedded {"pass\\u0077ord"\\:"SECURITY_EMBEDDED_ESCAPED_COLON"}',
    "https://example.test/path#state=ok&password%3DSECURITY_FRAGMENT_SECRET",
    "p.a.s.s.w.o.r.d=SECURITY_DOTTED_KEY_SECRET"
  ]
  rp_evidence(action: "malformed public diagnostics", error: RuntimeError.new("safe readable failure"),
              details: malformed_fragments.join("\n"), target: rp_capture_target)

  edge_sources = {
    hashrocket: 'failed: {"\\u0070assword" => "SECURITY_EDGE_HASHROCKET"}',
    equal: 'failed: {"\\u0070assword" = "SECURITY_EDGE_EQUAL"}',
    long_key: 'failed: {"' + ("." * 4_100) + '\\u0070assword":"SECURITY_EDGE_LONG_KEY"}',
    escaped_space: 'failed: {"\\u0070assword"\\u0020:"SECURITY_EDGE_ESCAPED_SPACE"}',
    partial_pair: "https://example.test/#password%3DSECURITY_EDGE_PARTIAL_PAIR=suffix"
  }
  edge_sources.each do |label, source|
    AppLog.assertion(name: "edge assertion #{label}", expected: "safe", actual: "safe",
                     passed: false, details: source)
    options = label == :partial_pair ? { url: source } : { details: source }
    rp_evidence(action: "edge public evidence #{label}", error: RuntimeError.new("safe failure"),
                target: rp_capture_target, **options)
  end
  ready5_sources = {
    object_close: 'failed: {]"\\u0070assword":"SECURITY_READY5_OBJECT_CLOSE"}',
    array_close: 'failed: [}"\\u0070assword":"SECURITY_READY5_ARRAY_CLOSE"]',
    unquoted_key: 'failed: {\\u0070assword:"SECURITY_READY5_UNQUOTED_KEY"}',
    leading_separator: "_password=SECURITY_READY5_LEADING_SEPARATOR",
    trailing_separator: "password_=SECURITY_READY5_TRAILING_SEPARATOR",
    surrounding_separators: "-password-=SECURITY_READY5_SURROUNDING_SEPARATORS"
  }
  ready5_sources.each_value do |source|
    AppLog.assertion(name: source, expected: source, actual: source, passed: false, details: source)
    rp_evidence(action: source, error: RuntimeError.new(source), details: source,
                target: rp_capture_target)
  end
  safe_business = "token_count=12 password_policy=business-only component=payments"
  AppLog.assertion(name: "safe business diagnostics", expected: "safe", actual: "safe",
                   passed: false, details: safe_business)

  png_bytes = "\x89PNG\r\n\x1A\nsynthetic-png-payload".b
  malformed_name = %({"pass\\x77ord":"SECURITY_ARTIFACT_MALFORMED"}.png)
  oversized_name = "SECURITY_ARTIFACT_OVERSIZED_" + ("n" * 70_000) + ".png"
  long_legitimate_png_bytes_name = "long-legitimate-png-bytes-" + ("n" * 140) + ".png"
  long_legitimate_png_path_name = "long-legitimate-png-path-" + ("n" * 140) + ".png"
  artifacts = [
                { bytes: png_bytes, name: "known-good.png", mime: "image/png" },
                { bytes: png_bytes, name: long_legitimate_png_bytes_name },
                { path: ENV.fetch("SECURITY_LONG_PNG_PATH"), name: long_legitimate_png_path_name },
                { bytes: "synthetic-malformed-name-bytes", name: malformed_name, mime: "image/png" },
                { bytes: "synthetic-oversized-name-bytes", name: oversized_name, mime: "image/png" }
              ]
  artifacts.concat(edge_sources.values.map do |name|
    source = ENV["SECURITY_EDGE_ARTIFACT_MODE"] == "path" ? { path: ENV.fetch("SECURITY_LONG_PNG_PATH") } : { bytes: png_bytes }
    source.merge(name: name, mime: "image/png")
  end)
  artifacts.concat(ready5_sources.values.map do |name|
    source = ENV["SECURITY_EDGE_ARTIFACT_MODE"] == "path" ? { path: ENV.fetch("SECURITY_LONG_PNG_PATH") } : { bytes: png_bytes }
    source.merge(name: name, mime: "image/png")
  end)
  rp_evidence(action: "artifact metadata regression", error: RuntimeError.new("safe readable failure"),
              artifacts: artifacts, target: rp_capture_target)

  oversized = %({"\\u0070assword":"SECURITY_CLI_OVERSIZED_#{"x" * 70_000}"})
  rp_evidence(action: "oversized security evidence", error: RuntimeError.new("safe readable failure"),
              details: oversized, target: rp_capture_target)
end
