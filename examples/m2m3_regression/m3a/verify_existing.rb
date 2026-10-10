# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "time"

EVIDENCE = ENV.fetch("M3A_RECONCILIATION_DIR")
PRIOR = ENV.fetch("M3A_PRIOR_EVIDENCE")
ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://localhost").delete_suffix("/")
PROJECT = ENV.fetch("RP_PROJECT", "superadmin_personal")
SDK_ROOT = File.expand_path("../../../tmp/m2m3-regression-20261009/live/sdk", __dir__)

def request(path, token: nil, body: nil)
  uri = URI.join("#{ENDPOINT}/", path)
  req = body ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
  req.basic_auth("ui", "uiman") if path == "uat/sso/oauth/token"
  req["Authorization"] = "Bearer #{token}" if token
  req["Content-Type"] = "application/x-www-form-urlencoded" if body
  req.body = body if body
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 60) { |http| http.request(req) }
end

def api(path, token)
  response = request(path, token: token)
  raise "ReportPortal API returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

FileUtils.mkdir_p(EVIDENCE)
previous = JSON.parse(File.read(File.join(PRIOR, "result-manifest.json")))
raise "Prior live launch id is missing" unless previous["launch_id"]
auth = request("uat/sso/oauth/token", body: URI.encode_www_form(
  grant_type: "password", username: ENV.fetch("RP_USERNAME", "superadmin"), password: ENV.fetch("RP_PASSWORD", "erebus")
))
raise "ReportPortal authentication failed (HTTP #{auth.code})" unless auth.is_a?(Net::HTTPSuccess)
token = JSON.parse(auth.body).fetch("access_token")

launch_id = previous.fetch("launch_id")
query = URI.encode_www_form("page.page" => 1, "page.size" => 100)
launch = api("api/v1/#{PROJECT}/launch?#{query}", token).fetch("content").find { |item| item["id"].to_s == launch_id.to_s }
raise "Original M3A launch was not found" unless launch
items_query = URI.encode_www_form("filter.eq.launchId" => launch_id, "page.page" => 1, "page.size" => 500,
                                  "page.sort" => "startTime,ASC")
items = api("api/v1/#{PROJECT}/item?#{items_query}", token).fetch("content")
suites = items.select { |item| item["type"] == "SUITE" && item["hasStats"] == true }
scenarios = items.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
actions = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
native = JSON.parse(File.read(File.join(PRIOR, "cucumber.json")))
native_scenarios = native.flat_map { |feature| feature.fetch("elements", []).select { |entry| entry["type"] == "scenario" } }
native_steps = native_scenarios.flat_map { |scenario| scenario.fetch("steps", []) }
checks = {
  exact_original_launch_id: launch["id"].to_s == launch_id.to_s,
  prior_child_exit_was_zero: previous.fetch("child_exit_status") == 0,
  two_reportportal_feature_suites: suites.length == 2,
  eight_reportportal_scenario_cases: scenarios.length == 8,
  forty_expanded_reportportal_actions: actions.length == 40,
  eight_native_scenarios: native_scenarios.length == 8,
  twenty_four_native_scenario_authored_steps: native_steps.length == 24,
  all_native_scenario_steps_passed: native_steps.all? { |step| step.dig("result", "status") == "passed" },
  reportportal_statistics_eight_passed: launch.dig("statistics", "executions", "total").to_i == 8 &&
    launch.dig("statistics", "executions", "passed").to_i == 8 && launch.dig("statistics", "executions", "failed").to_i.zero?
}
receipt = {
  classification: "READ-ONLY RECONCILIATION OF EXISTING LIVE LAUNCH; does not create a launch",
  source_exploratory_attempt: PRIOR, original_validator_expected_40_native_steps: false,
  reconciled_at_utc: Time.now.utc.iso8601, launch_id: launch_id, launch_uuid: launch["uuid"],
  launch_status: launch["status"], launch_url: "#{ENDPOINT}/ui/##{PROJECT}/launches/all/#{launch_id}",
  sdk_path: previous.fetch("sdk_path"), sdk_entrypoint_sha256: previous.fetch("sdk_entrypoint_sha256"),
  fixture_sha256: Dir.glob(File.join(__dir__, "fixtures", "**", "*"), File::FNM_DOTMATCH).select { |p| File.file?(p) }
    .sort.to_h { |path| [path.delete_prefix("#{__dir__}/"), Digest::SHA256.file(path).hexdigest] },
  counts: { suites: suites.length, scenario_cases: scenarios.length, expanded_action_items: actions.length,
            native_scenarios: native_scenarios.length, native_scenario_authored_steps: native_steps.length },
  suite_items: suites.map { |item| item.slice("id", "uuid", "name", "status") },
  scenario_items: scenarios.map { |item| item.slice("id", "uuid", "name", "status", "codeRef", "testCaseId", "testCaseHash") },
  checks: checks, passed: checks.values.all?
}
File.write(File.join(EVIDENCE, "result-manifest.json"), JSON.pretty_generate(receipt) + "\n")
puts "launch_id=#{launch_id} launch_url=#{receipt.fetch(:launch_url)} counts=#{JSON.generate(receipt.fetch(:counts))}"
abort "M3A existing-launch reconciliation failed" unless receipt.fetch(:passed)
