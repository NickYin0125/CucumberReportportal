# frozen_string_literal: true

# Requiring this file without the runner must not install steps, hooks or formats.
return unless ENV["LEDGER_DEVELOPER_RUN"] == "1"

require "base64"
require "digest"
require "json"
require "zlib"
require "reportportal_cucumber"
require_relative "fixtures"

module LedgerDeveloper
  module Input
    module_function

    def record(kind, data = {})
      File.open(File.join(ENV.fetch("LEDGER_EVIDENCE"), "inputs.ndjson"), "a", 0o600) do |file|
        file.puts(JSON.generate({ kind: kind }.merge(data)))
      end
    end

    def png(number = 1)
      File.binread(File.join(ENV.fetch("LEDGER_MEDIA"), format("screenshot-%02d.png", number)))
    end

    # Launch 74's prior IndependentCucumber12.payload("png") uses png(71),
    # not the 640x360 gallery card. Preserve that exact binary control here.
    def native_input_png
      chunk = lambda { |type, body| [body.bytesize].pack("N") + type.b + body + [Zlib.crc32(type.b + body)].pack("N") }
      pixel = [71 * 19 % 256, 71 * 47 % 256, 71 * 83 % 256].pack("C*")
      "\x89PNG\r\n\x1a\n".b + chunk.call("IHDR", [2, 2, 8, 2, 0, 0, 0].pack("NNC5")) +
        chunk.call("IDAT", Zlib::Deflate.deflate(("\0".b + pixel * 2) * 2)) + chunk.call("IEND", "".b)
    end

    def attachment(world, bytes, mime, name = nil)
      record("attachment", name: name, mime: mime, bytes: bytes.bytesize,
             sha256: Digest::SHA256.hexdigest(bytes), base64: Base64.strict_encode64(bytes))
      world.attach(bytes, mime, name)
    end

    def deep_failure
      inner_failure
    end

    def inner_failure
      record("expected_backtrace", lines: caller)
      raise "INDEPENDENT_FULL_BACKTRACE"
    end

    def app_log(world)
      AppLog.with_logger(Automation::CucumberLogger.new(world: world, color: false)) { yield }
    end
  end

  class Audit
    def initialize(config)
      runtime = ReportportalCucumber.current_runtime
      source_hashes = $LOADED_FEATURES.grep(%r{/reportportal_cucumber(?:/|\.rb)}).to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }
      config.on_event(:test_step_created) do |event|
        next unless event.respond_to?(:pickle_step)
        step = event.pickle_step
        argument = step.argument
        table = argument.data_table if argument.respond_to?(:data_table)
        Input.record("compiled_step", text: step.text,
                     table: table && table.rows.map { |row| row.cells.map(&:value) })
      end
      at_exit do
        value = { ruby: RUBY_DESCRIPTION, cucumber: Gem.loaded_specs.fetch("cucumber").version.to_s,
                  sdk_version: ReportportalCucumber::VERSION,
                  loaded_sdk_sha256_at_start: source_hashes,
                  sdk_source_changed_during_fixture: source_hashes.any? { |path, sha| Digest::SHA256.file(path).hexdigest != sha },
                  loaded_sdk_files: $LOADED_FEATURES.grep(%r{/reportportal_cucumber(?:/|\.rb)}),
                  receipt: runtime.respond_to?(:reporting_receipt) ? runtime.reporting_receipt.to_h : nil,
                  diagnostics: runtime.respond_to?(:reporting_diagnostics) ? runtime.reporting_diagnostics : nil }
        File.write(File.join(ENV.fetch("LEDGER_EVIDENCE"), "runtime.json"), JSON.pretty_generate(value) + "\n")
      end
    end
  end
end

World(ReportportalCucumber::Cucumber::World)

if ENV["LEDGER_FIXTURE"] == "F15"
  Before("@ledger_hooks") { log("LEDGER_BEFORE") }
  After("@ledger_hooks") { log("LEDGER_AFTER") }
  AfterStep("@ledger_hooks") { log("LEDGER_AFTER_STEP") }
end
if ENV["LEDGER_FIXTURE"] == "F15-global"
  BeforeAll { log("LEDGER_BEFORE_ALL") }
  AfterAll { log("LEDGER_AFTER_ALL") }
end
if ENV["LEDGER_FIXTURE"] == "F15-negative"
  After("@ledger_after_failure") { raise "LEDGER_INTENTIONAL_AFTER_FAILURE" }
end
if ENV["LEDGER_FIXTURE"] == "F15-named"
  Before(name: "Open browser") { log("LEDGER_NAMED_BEFORE") }
end
if ENV["LEDGER_FIXTURE"] == "F04"
  After("@ledger_failure_jpeg") do |scenario|
    if scenario.failed?
      LedgerDeveloper::Input.attachment(self, File.binread(ENV.fetch("LEDGER_JPEG")), "image/jpeg", "after-failure.jpg")
    end
  end
end
if ENV["LEDGER_FIXTURE"] == "F17"
  After("@ledger_unnamed_after") do
    LedgerDeveloper::Input.attachment(self, File.binread(ENV.fetch("LEDGER_JPEG")), "image/jpeg")
  end
end

Given(/^ledger literal ([\s\S]*)$/) do |value|
  LedgerDeveloper::Input.record("literal", value: value)
  log(value)
end
Given("ledger records this table:") { |table| LedgerDeveloper::Input.record("table", rows: table.raw) }
Given("ledger document:") { |document| LedgerDeveloper::Input.record("document", value: document) }
Given("ledger legacy separate document:") do |document|
  (@ledger_argument_order ||= []) << "doc"
  @ledger_separate_document = document
  LedgerDeveloper::Input.record("legacy_document", value: document)
end
Given("ledger legacy separate table:") do |table|
  (@ledger_argument_order ||= []) << "table"
  @ledger_separate_table = table.raw
  LedgerDeveloper::Input.record("legacy_table", rows: table.raw)
end
Then("ledger verifies separate arguments {string} in {string} order") do |value, order|
  expected_order = order == "doc-first" ? %w[doc table] : %w[table doc]
  verified = @ledger_separate_document == "CONSTANT_DOC" && @ledger_separate_table == [%w[key value], ["combined", value]] && @ledger_argument_order == expected_order
  LedgerDeveloper::Input.record("legacy_separate_verification", value: value, document: @ledger_separate_document,
                                rows: @ledger_separate_table, order: @ledger_argument_order, verified: verified)
  raise "Legacy separate argument data or order changed" unless verified
end
Given("ledger combined {string}:") do |order, document|
  LedgerDeveloper::Input.record("compound", order: order, native_selected_argument: document)
  raise "Native selected DocString changed" unless document == "CONSTANT_DOC"
end
Given("ledger visible media") do
  input = LedgerDeveloper::Input
  input.attachment(self, input.png, "image/png", "visible-fixture.png")
  input.attachment(self, LedgerDeveloper::TEXT, "text/plain", "visible-fixture.txt")
  input.attachment(self, LedgerDeveloper::JSON_TEXT, "application/json", "visible-fixture.json")
end
Given("ledger screenshot {int}") do |number|
  LedgerDeveloper::Input.attachment(self, LedgerDeveloper::Input.png(number), "image/png", format("screenshot-%02d.png", number))
end
Given("ledger rapid record {int}") do |number|
  log("TC15 rapid record #{number}")
  if number <= 10
    LedgerDeveloper::Input.attachment(self, LedgerDeveloper::Input.png(number), "image/png", "tc15-#{number}.png")
  end
end
Given("ledger deep failure") { LedgerDeveloper::Input.deep_failure }
Then("ledger follower must not execute") { raise "HARNESS_ERROR: skipped follower executed" }
Given("ledger media {string} as {string}") do |kind, form|
  bytes, mime = case kind
                when "png" then [LedgerDeveloper::Input.native_input_png, "image/png"]
                when "text" then ["independent text\r\nline two\n\x00end".b, "text/plain"]
                when "json" then ['{"source":"independent","values":[1,true,null]}', "application/json"]
                end
  filename = "#{kind}-#{form}.#{kind == 'text' ? 'txt' : kind}"
  path = File.join(ENV.fetch("LEDGER_EVIDENCE"), filename)
  File.binwrite(path, bytes)
  expected = form == "plain_base64" ? Base64.strict_encode64(bytes) : bytes
  LedgerDeveloper::Input.record("attachment_input", form: form, name: filename, mime: mime,
                                base64: Base64.strict_encode64(expected), sha256: Digest::SHA256.hexdigest(expected), bytes: expected.bytesize)
  case form
  when "file" then File.open(path, "rb") { |file| attach(file, mime, filename) }
  when "path" then attach(path, mime, filename)
  when "binread" then attach(File.binread(path), mime, filename)
  when "binary" then attach(bytes, mime, filename)
  when "encoded" then attach(Base64.strict_encode64(bytes), "#{mime};base64", filename)
  when "plain_base64" then attach(Base64.strict_encode64(bytes), mime, filename)
  end
end
Given("ledger NUL inputs") do
  LedgerDeveloper::Input.attachment(self, "minimal\0NUL payload\n".b, "text/plain", "nul-repro.txt")
  ["native log\0NUL message\n", 'native log\u0000NUL message' + "\n"].each do |value|
    LedgerDeveloper::Input.record("native_log", message: value)
    log(value)
  end
end
Given("ledger assertion {word}") do |letter|
  values = case letter
           when "a" then { name: "Order is accepted", expected: "ACCEPTED", actual: "ACCEPTED", passed: true }
           when "b" then { name: "Payload matches", expected: "x" * 120, actual: "x" * 120, passed: true }
           when "c" then { name: "Intentionally absent Typewords control can be clicked", expected: "click succeeds", actual: LedgerDeveloper::CALL_LOG, passed: false,
                           details: { api_key: "SECRET123", recording: "Playwright viewport recording is still active" } }
           when "d" then { name: "Limits", expected: { currency: "USD", notional: 5_000_000 }, actual: { currency: "USD", notional: 4_000_000 }, passed: false,
                           details: (1..8).to_h { |n| ["key#{n}", n] } }
           when "e" then { name: "Nested details", expected: 1, actual: 2, passed: false, details: { a: { b: [1, 2] } } }
           end
  LedgerDeveloper::Input.record("assertion", values)
  LedgerDeveloper::Input.app_log(self) { AppLog.assertion(**values) }
end
Given("ledger HTTP {word}") do |letter|
  values = case letter
           when "a"
             { method: "POST", url: "https://api.example.test/api/orders", duration_ms: 84,
               request: { headers: { "Content-Type" => "application/json", "Accept" => "application/json", "X-Request-Id" => "ledger-42", "X-Fixture" => "F11a" },
                          body: { account: "JPM-PRIME", side: "BUY", notional: 5_000_000 } },
               response: { status: 201, headers: { "Content-Type" => "application/json" }, body: { orderId: "ORD-20261031-0042", status: "ACCEPTED" } } }
           when "b" then { method: "GET", url: "/words", response: { status: 404 }, duration_ms: 31 }
           when "c" then { method: "GET", url: "/words", response: { status: 500 }, expected_status: 200, duration_ms: 31 }
           when "d" then { method: "GET", url: "/words", error: "Connection refused" }
           when "e" then { method: "GET", url: "https://api.example.test/orders", response: { status: 200, headers: { "Content-Type" => "application/json" },
                           body: JSON.pretty_generate((1..38).to_h { |n| ["line#{n}", n] }) } }
           when "f" then { method: "GET", url: "https://api.example.test/orders?token=SECRET123&page=2", response: { status: 200 } }
           end
  LedgerDeveloper::Input.record("http", values)
  LedgerDeveloper::Input.app_log(self) { AppLog.http(**values) }
end
Given("ledger failure evidence") do
  error_class = Class.new(StandardError) { def self.name; "Playwright::TimeoutError"; end }
  error = error_class.new(LedgerDeveloper::CALL_LOG)
  artifacts = [{ name: "failure.png", mime: "image/png", bytes: LedgerDeveloper::Input.png },
               { name: "response.json", mime: "application/json", bytes: LedgerDeveloper::JSON_TEXT }]
  LedgerDeveloper::Input.record("evidence", action: "Missing Typewords control while recording", error_class: error.class.name,
                                error: error.message, url: "http://localhost:5567/words", details: { api_key: "SECRET123" },
                                artifacts: artifacts.map { |a| a.reject { |k, _| k == :bytes }.merge(base64: Base64.strict_encode64(a[:bytes])) })
  rp_evidence(action: "Missing Typewords control while recording", error: error, url: "http://localhost:5567/words",
              details: { api_key: "SECRET123" }, artifacts: artifacts)
  rp_evidence(action: "", error: error)
  bytes = LedgerDeveloper::Input.png
  LedgerDeveloper::Input.record("attachment", name: "caller-message.png", mime: "image/png", bytes: bytes.bytesize,
                                sha256: Digest::SHA256.hexdigest(bytes), base64: Base64.strict_encode64(bytes))
  rp_attach(LedgerDeveloper::Input.png, name: "caller-message.png", mime: "image/png", message: "Caller **Markdown** stays authored")
end
Given("ledger escaping failure {int}") { |index| raise LedgerDeveloper::ESCAPES.fetch(index) }
Given("ledger failure shape {word}") do |letter|
  case letter
  when "a" then raise "LEDGER_MULTI_LINE\nsecond line <other>\nthird line `tick`"
  when "b" then JSON.parse("{")
  when "d" then raise RuntimeError, ""
  when "e" then raise "L" * 500
  when "f" then raise "api_key=SECRET123 failed"
  end
end
Then("the order is confirmed") do
  input = LedgerDeveloper::Input
  input.attachment(self, input.png, "image/png")
  input.attachment(self, input.png(2), "image/png")
  input.attachment(self, File.binread(ENV.fetch("LEDGER_PROGRESSIVE_JPEG")), "image/jpeg")
  input.attachment(self, LedgerDeveloper::JSON_TEXT, "application/json")
  input.attachment(self, LedgerDeveloper::TEXT, "text/plain")
end
Given("ledger large previews") do
  input = LedgerDeveloper::Input
  input.attachment(self, (1..340).map { |n| "line #{n}\n" }.join, "text/plain", "340-lines.txt")
  input.attachment(self, JSON.pretty_generate((1..23).to_h { |n| ["line#{n}", n] }), "application/json", "25-lines.json")
  input.attachment(self, "x" * (48 * 1024), "text/plain", "48-kib.txt")
  input.attachment(self, JSON.generate(oversized: "x" * (48 * 1024)), "application/json", "oversized.json")
end
