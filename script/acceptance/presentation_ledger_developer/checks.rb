# frozen_string_literal: true

# Self-checks of developer infrastructure, never presentation acceptance.
require "open3"
require "rbconfig"
require_relative "fixtures"
require_relative "wire"
require_relative "testcards"

checks = 0
assert = lambda do |condition, message|
  raise "Developer infrastructure check failed: #{message}" unless condition
  checks += 1
end

(1..10).each do |index|
  bytes = LedgerDeveloper::Testcards.png(index)
  assert.call(Digest::SHA256.hexdigest(bytes) == LedgerDeveloper::Testcards::SHA256.fetch(index - 1), "historical PNG #{index} bytes unchanged")
end

rows = LedgerDeveloper.catalog
assert.call(rows.map { |r| r[:id][0, 3] }.uniq.sort == (1..20).map { |n| format("F%02d", n) }, "F01-F20 catalog")
assert.call(rows.all? { |r| r[:source].lines.first.include?("@reportportal_live") }, "every template is excluded by default")
assert.call(rows.all? { |r| r[:failed].zero? || r[:negative] }, "intentional failure separation")
assert.call(rows.find { |r| r[:id] == "F08-negative" }[:negative], "base64 negative control separation")
assert.call(rows.find { |r| r[:id] == "F16c" }[:unsupported], "non-Exception fallback not faked")
assert.call(rows.find { |r| r[:id] == "F06" }[:unsupported], "parallel limitation explicit")
%w[F02 F03].each do |id|
  native = rows.find { |row| row[:id] == id }
  companion = LedgerDeveloper.legacy_companion(native)
  assert.call(native[:native_parser_sources].keys == %w[doc-first table-first], "both native parser orders retained")
  assert.call(companion[:legacy_companion_of] == id && !companion[:cucumber12] && companion[:id] != id,
              "legacy companion cannot be labelled native compound")
  assert.call(companion[:source].start_with?("@reportportal_live") && !companion[:source].include?("Given ledger combined") &&
              companion[:source].scan("Then ledger verifies separate arguments").length == 2, "separate args explicitly verified and isolated")
end
Dir.glob(File.join(LedgerDeveloper::ROOT, "features/presentation_ledger/**/*.feature")).each do |path|
  text = File.read(path)
  assert.call(text.lines.first.include?("@reportportal_live"), "on-disk tags")
  assert.call(!text.include?('"""'), "no compound grammar can enter default legacy parse")
end
before = $LOADED_FEATURES.dup
ENV.delete("LEDGER_DEVELOPER_RUN")
require_relative "support"
assert.call(($LOADED_FEATURES - before).all? { |path| path.end_with?("/support.rb") }, "guard installs no SDK, hooks or steps")
assert.call(!defined?(LedgerDeveloper::Audit), "guard installs no audit formatter")

bytes = "\0\xffraw\r\n".b
boundary = "ledger-boundary"
body = "--#{boundary}\r\nContent-Disposition: form-data; name=\"json_request_part\"\r\nContent-Type: application/json\r\n\r\n[{\"message\":\"safe\"}]\r\n".b +
       "--#{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"fixture.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".b +
       bytes + "\r\n--#{boundary}--\r\n".b
entries, files = LedgerDeveloper::Wire.multipart(body, "multipart/form-data; boundary=#{boundary}")
assert.call(entries == [{ "message" => "safe" }], "multipart JSON exact")
assert.call(Base64.strict_decode64(files.first[:base64]) == bytes && files.first[:mime] == "image/jpeg", "raw bytes and explicit MIME exact")

wire = LedgerDeveloper::Wire.new(project: "developer_checks")
begin
  request = lambda do |method, path, value|
    uri = URI(wire.endpoint + "/api/v1/developer_checks/" + path)
    req = Net::HTTP.const_get(method).new(uri)
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(value)
    Net::HTTP.start(uri.hostname, uri.port, nil) { |http| http.request(req) }
  end
  launch = request.call("Post", "launch", name: "ledger-developer-self-check")
  uuid = JSON.parse(launch.body).fetch("id")
  assert.call(launch.code == "201" && wire.launches == [uuid], "offline launch is explicitly synthetic")
  response = request.call("Post", "log", [{ launchUuid: uuid, message: "first" }, { launchUuid: uuid, message: "second" }])
  assert.call(JSON.parse(response.body).fetch("responses").length == 2, "batch gets one acknowledgement per log")
  rejected = request.call("Put", "launch/not-owned/finish", status: "PASSED")
  assert.call(rejected.code == "500", "existing launch cannot be finished")
  assert.call(wire.records.none? { |r| r.keys.any? { |k| k.to_s.match?(/authorization|api_key/i) } }, "no credentials in wire metadata")
ensure
  wire.close
end
puts "#{checks} developer infrastructure checks completed; no live calls or acceptance verdict."

# Optional native discovery check. GEM_PATH selects an already-installed runtime.
if ARGV.first == "--cucumber"
  version = ARGV.fetch(1)
  command = [RbConfig.ruby, "-e", 'gem "cucumber", ARGV.shift; load Gem.bin_path("cucumber", "cucumber")', "--", version,
             "--no-profile", "--publish-quiet", "--dry-run", "--require", File.join(__dir__, "support.rb"),
             "--tags", "not @reportportal_live and not @duration", File.join(LedgerDeveloper::ROOT, "features/presentation_ledger")]
  output, error, status = Open3.capture3({ "LEDGER_DEVELOPER_RUN" => nil, "RP_ENABLED" => "false", "CUCUMBER_PUBLISH_ENABLED" => "false" }, *command)
  raise "Discovery isolation failed: #{output}\n#{error}" unless status.success? && output.include?("0 scenarios")
  puts "Cucumber #{version}: legacy-safe parsing, zero default-selected Ledger scenarios, no support installation."
end
