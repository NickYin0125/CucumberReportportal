# frozen_string_literal: true

require_relative "../../../../script/acceptance/presentation_ledger_developer/support"
require "rspec/expectations"

Given("QA202 {word}") do |kind|
  input = LedgerDeveloper::Input
  case kind
  when "backslash" then raise "back\\slash"
  when "regex"
    RSpec::Expectations::ExpectationTarget.for("letters", nil).to(RSpec::Matchers::BuiltIn::Match.new(/\d+/))
  when "windows" then raise Errno::ENOENT, 'C:\\work\\missing.txt'
  when "diff"
    RSpec::Expectations::ExpectationTarget.for("alpha\ngamma", nil).to(RSpec::Matchers::BuiltIn::Eq.new("alpha\nbeta"))
  when "json_quote" then raise JSON.generate("text" => 'quoted "value"')
  when "json_secret" then raise JSON.generate("token" => "SECRET123", "text" => 'quoted "value"')
  when "values"
    pairs = [["empty", "", ""], ["spaces", "   ", " "], ["edges", " a ", "b "], ["tabs", "\t", "\n"],
      ["ordinary", "abc", "abc"], ["delta", { z: 1, missing: 2, change: 3 }, { z: 1, extra: 4, change: 5 }],
      ["nested_only", { nested: { a: 1 } }, { nested: { a: 2 } }], ["equal", { a: 1 }, { a: 1 }]]
    pairs.each do |name, expected, actual|
      values = { name: "QA202 #{name}", expected: expected, actual: actual, passed: false }
      input.record("assertion", values)
      input.app_log(self) { AppLog.assertion(**values) }
    end
    values = { name: "QA202 oversized details", expected: "a", actual: "b", passed: false,
      details: { data: "x" * 70_000 } }
    input.record("assertion", values)
    input.app_log(self) { AppLog.assertion(**values) }
  when "http"
    [201, 404, 500].each do |status|
      values = { method: "POST", url: "https://qa.example.test/ledger?plain=value", duration_ms: 17,
        request: { headers: { "Content-Type" => ["application/json"], "X-Multi" => ["first", "second"] }, body: { request: "unchanged" } },
        response: { status: status, headers: { "Content-Type" => ["application/json"], "X-Multi" => ["alpha", "beta"], "Set-Cookie" => ["a=one", "b=two"] },
          body: { outcome: "QA202 response #{status}" } } }
      input.record("http", values)
      input.app_log(self) { AppLog.http(**values) }
    end
    [99, 100, 101].each do |lines|
      values = { method: "POST", url: "https://qa.example.test/lines#{lines}",
        response: { status: 200, headers: { "Content-Type" => "text/plain" }, body: Array.new(lines, "body-line").join("\n") } }
      input.record("http", values)
      input.app_log(self) { AppLog.http(**values) }
    end
    [16_383, 16_384, 16_385].each do |size|
      values = { method: "POST", url: "https://qa.example.test/bytes#{size}", response: { status: 200, body: "x" * size } }
      input.record("http", values)
      input.app_log(self) { AppLog.http(**values) }
    end
  when "captions"
    %i[error fatal].each do |level|
      bytes = input.png
      input.record("attachment", name: "QA202-#{level}.png", mime: "image/png", bytes: bytes.bytesize,
        sha256: Digest::SHA256.hexdigest(bytes), base64: Base64.strict_encode64(bytes), level: level)
      rp_attach(bytes, name: "QA202-#{level}.png", mime: "image/png", level: level)
    end
    input.app_log(self) { AppLog.fatal("QA202 fatal plain text") }
  else
    raise "Unknown QA202 supplement"
  end
end
