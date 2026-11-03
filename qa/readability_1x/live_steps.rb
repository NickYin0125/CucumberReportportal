# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "securerandom"
require "zlib"
require "reportportal_cucumber"

World(ReportportalCucumber::Cucumber::World)

module IndependentPNG
  def self.chunk(type, data)
    [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
  end

  def self.bytes(value)
    "\x89PNG\r\n\x1a\n".b + chunk("IHDR", [1, 1, 8, 2, 0, 0, 0].pack("NNCCCCC")) +
      chunk("IDAT", Zlib::Deflate.deflate([0, value, 128, 255 - value].pack("C*"))) + chunk("IEND", "")
  end
end

Around do |_scenario, block|
  AppLog.with_logger(Automation::CucumberLogger.new(world: self, color: false)) { block.call }
ensure
  AppLog.clear!
end

When("independent structured HTTP evidence is recorded") do
  AppLog.http(method: :post, url: "https://example.test/orders?token=SYNTHETIC_HTTP_SECRET&page=2",
    request: { body: { order: 42 }, headers: { "X-Repeat" => ["one", "two"] } },
    response: { status: 201, body: { accepted: true }, headers: { "Content-Type" => ["application/json"] } }, duration_ms: 23)
  AppLog.http(method: :get, url: "https://example.test/failure", response: { status: 503, body: "ERROR_RESPONSE_BODY" }, expected_status: 200)
  AppLog.assertion(name: "blank is not whitespace", expected: "", actual: " \t", passed: false)
  AppLog.assertion(name: "shallow keys", expected: { gone: true, changed: 1 }, actual: { extra: false, changed: 2 }, passed: false)
end

When("independent DocString evidence is recorded") do |text|
  raise "DocString changed" unless text.include?("<script>") && text.include?("back\\slash")
end

When("independent DataTable evidence is recorded") do |table|
  raise "DataTable changed" unless table.rows.first.last.include?("onerror")
end

Then("independent attachment previews are recorded") do
  rp_attach((1..340).map { |line| "QA line #{line} <script>qa_text</script>" }.join("\n"), name: "qa-340-lines.txt", mime: "text/plain")
  rp_attach("x" * (48 * 1024), name: "qa-48k.txt", mime: "text/plain")
  rp_attach(JSON.pretty_generate((1..25).to_h { |number| ["key#{number}", number] }), name: "qa-25-lines.json", mime: "application/json")
end

When("independent outline value {string} is checked") do |value|
  raise "Outline substitution failed" unless %w[literal-one literal-two].include?(value)
  AppLog.info("OUTLINE_VALUE=#{value}", report: true)
end

When("independent raw business failure {string} occurs") do |value|
  @independent_case = value
  raise RuntimeError, "\nQA_ORIGINAL_#{value}\nexpected: \"first\\nchanged\"\nactual: \"first\\nsecond\"\nC:\\qa\\logs\\failure.json api_key=SYNTHETIC_RAW_1X\n"
end

After("@independent_failure") do |scenario|
  if scenario.failed?
    directory = ENV.fetch("QA_LIVE_OUT")
    name = "qa-after-#{@independent_case}-#{SecureRandom.hex(8)}.png"
    bytes = IndependentPNG.bytes(@independent_case == "first" ? 80 : 180)
    File.binwrite(File.join(directory, name), bytes)
    # Deliberately RP-only: one caption-plus-PNG entry under the open After Hook.
    # This does not claim the passed-After / Hide All Passed Logs issue is fixed.
    rp_attach(bytes, name: name, mime: "image/png", message: "QA_AFTER_PNG #{@independent_case}", level: :error)
    record = { case: @independent_case, name: name, sha256: Digest::SHA256.hexdigest(bytes),
      expected_owner: "After Hook", original_message: scenario.exception.message, original_frames: scenario.exception.backtrace }
    File.write(File.join(directory, "expected-#{@independent_case}.json"), JSON.pretty_generate(record) + "\n")
  end
end
