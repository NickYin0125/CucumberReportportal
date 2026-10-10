# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "open3"
require "securerandom"
require "time"
require "uri"

EVIDENCE = File.expand_path(ENV.fetch("M3C_LIVE_EVIDENCE"))
SANDBOX = File.join(EVIDENCE, "sandbox")
ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://localhost")
PROJECT = ENV.fetch("RP_PROJECT", "superadmin_personal")
ACCEPTANCE_RUN_ID = "m3c-live-20261009-r02-#{SecureRandom.hex(4)}"
LAUNCH = "M3C-C-LIVE-20261009-r02-#{Time.now.utc.strftime('%H%M%S')}-#{SecureRandom.hex(2)}"
REFERENCE_BASE = "http://127.0.0.1:8883"
SDK_ROOT = File.expand_path("../../../tmp/m2m3-regression-20261009/live/sdk", __dir__)
DEFAULT_GEMFILE = File.expand_path("../m3b/Gemfile", __dir__)
EXPECTED = { "suite_count" => 2, "scenario_count" => 5, "passed_count" => 4, "failed_count" => 1 }
FEATURE_FILES = ["features/account recovery.feature", "features/profile settings.feature"].freeze

# @return [String]
def token
  supplied = ENV["RP_API_KEY"].to_s.strip
  return supplied unless supplied.empty?

  uri = URI.join(ENDPOINT + "/", "uat/sso/oauth/token")
  request = Net::HTTP::Post.new(uri)
  request.basic_auth("ui", "uiman")
  request["Content-Type"] = "application/x-www-form-urlencoded"
  request.body = URI.encode_www_form(
    grant_type: "password",
    username: ENV.fetch("RP_USERNAME", "superadmin"),
    password: ENV.fetch("RP_PASSWORD", "erebus")
  )
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
  raise "ReportPortal local authentication failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body).fetch("access_token")
end

# @param path [String]
# @param bearer [String]
# @return [Hash]
def api_get(path, bearer)
  uri = URI.join(ENDPOINT + "/", path)
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{bearer}"
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
  raise "ReportPortal API returned HTTP #{response.code} for #{uri.path}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

# @param bearer [String]
# @return [Hash]
def wait_for_launch(bearer)
  90.times do
    query = URI.encode_www_form("filter.eq.name" => LAUNCH, "page.page" => 1, "page.size" => 10)
    launch = api_get("api/v1/#{PROJECT}/launch?#{query}", bearer).fetch("content", []).find { |entry| entry["name"] == LAUNCH }
    executions = launch&.dig("statistics", "executions")
    terminal = launch && %w[PASSED FAILED].include?(launch["status"]) && launch["endTime"]
    expected = executions == { "total" => EXPECTED.fetch("scenario_count"),
                              "passed" => EXPECTED.fetch("passed_count"),
                              "failed" => EXPECTED.fetch("failed_count") }
    return launch if terminal && expected

    sleep 1
  end
  raise "Completed ReportPortal launch was not visible by exact name"
end

# @param path [String]
# @param value [Object]
# @return [Integer]
def write_json(path, value)
  File.write(path, JSON.pretty_generate(value) + "\n")
end

# @return [void]
def main
  FileUtils.mkdir_p(EVIDENCE)
  bearer = token
  version, version_status = Open3.capture2("bundle", "exec", "cucumber", "--version", chdir: SANDBOX,
                                                   unsetenv_others: false)
  raise "Cucumber version check failed" unless version_status.success? && version.include?("10.2.0")

  env = ENV.keys.grep(/\A(?:RP_|CUCUMBER_)/).to_h { |key| [key, nil] }.merge(
    "BUNDLE_GEMFILE" => ENV.fetch("M3C_LIVE_GEMFILE", DEFAULT_GEMFILE),
    "CUCUMBER_PUBLISH_QUIET" => "true",
    "RP_ENDPOINT" => ENDPOINT,
    "RP_PROJECT" => PROJECT,
    "RP_API_KEY" => bearer,
    "RP_LAUNCH" => LAUNCH,
    "RP_LAUNCH_DESCRIPTION" => "M3C 2026-10-09 r02 live regression; synthetic local references only",
    "RP_SCENARIO_ATTRIBUTES_ENABLED" => "true",
    "RP_SCENARIO_ATTRIBUTE_KEYS" => "component,team,owner,layer,priority,browser,tms",
    "RP_SCENARIO_ATTRIBUTES" => "{\"team\":\"quality-platform\",\"layer\":\"integration\"}",
    "RP_SCENARIO_LINKS_ENABLED" => "true",
    "RP_SOURCE_URL_TEMPLATE" => "#{REFERENCE_BASE}/source/{commit}/{path}?line={line}",
    "RP_SOURCE_COMMIT" => JSON.parse(File.read(File.join(EVIDENCE, "fixture-repo.json"))).fetch("commit"),
    "RP_SOURCE_ROOT" => SANDBOX,
    "RP_CI_RUN_URL" => "#{REFERENCE_BASE}/runs/#{ACCEPTANCE_RUN_ID}",
    "RP_TMS_URL_TEMPLATE" => "#{REFERENCE_BASE}/cases/{id}",
    "RP_IDENTITY_STRATEGY" => "stable_v1",
    "RP_IDENTITY_ROOT" => SANDBOX,
    "RP_IDENTITY_NAMESPACE" => "m3c-live-20261009-r02",
    "RP_CLIENT_JOIN" => "false",
    "RP_FAIL_ON_REPORTING_ERROR" => "true",
    "RP_BATCH_SIZE_LOGS" => "1",
    "RP_FLUSH_INTERVAL" => "0.2",
    "RP_HTTP_READ_TIMEOUT" => "30",
    "RP_HTTP_WRITE_TIMEOUT" => "30",
    "RP_CONSOLE_MIRROR" => "false",
    "RP_TEST_CASE_ID" => nil,
    "RP_CONFIG" => nil,
    "CUCUMBER_PROFILE" => nil,
    "CUCUMBER_OPTS" => nil,
    "M3C_LIVE_ACCEPTANCE_RUN_ID" => ACCEPTANCE_RUN_ID
  )
  cmd = ["bundle", "exec", "cucumber", *FEATURE_FILES, "--require",
         File.join(SDK_ROOT, "lib/reportportal_cucumber.rb"),
         "--require", "features/step_definitions/live_steps.rb",
         "--format", "pretty", "--format", "json", "--out", File.join(EVIDENCE, "cucumber.json"),
         "--format", "ReportPortal::Cucumber::Formatter", "--out", File.join(EVIDENCE, "formatter.log")]
  stdout, status = Open3.capture2e(env, *cmd, chdir: SANDBOX)
  File.write(File.join(EVIDENCE, "cucumber.stdout.log"), stdout)
  raise "Expected the deliberate failure to produce Cucumber exit 1; got #{status.exitstatus}" unless status.exitstatus == 1

  launch = wait_for_launch(bearer)
  items_query = URI.encode_www_form("filter.eq.launchId" => launch.fetch("id"), "page.page" => 1, "page.size" => 500,
                                    "page.sort" => "startTime,ASC")
  items = api_get("api/v1/#{PROJECT}/item?#{items_query}", bearer).fetch("content")
  scenarios = items.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
  suites = items.select { |item| item["type"] == "SUITE" }
  errors = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false && item["status"] == "FAILED" }
  counts = { "suite_count" => suites.length, "scenario_count" => scenarios.length,
             "passed_count" => scenarios.count { |item| item["status"] == "PASSED" },
             "failed_count" => scenarios.count { |item| item["status"] == "FAILED" } }
  ui_url = "#{ENDPOINT}/ui/#{'#'}#{PROJECT}/launches/all/#{launch.fetch('id')}"
  summary = {
    "classification" => "LOCAL CI-STYLE DEMO; not an external CI provider",
    "acceptance_run_id" => ACCEPTANCE_RUN_ID,
    "launch_name" => LAUNCH,
    "launch_id" => launch.fetch("id"),
    "launch_uuid" => launch["uuid"],
    "launch_status" => launch.fetch("status"),
    "launch_end_time" => launch.fetch("endTime"),
    "launch_url" => ui_url,
    "launch_statistics" => launch["statistics"],
    "expected_counts" => EXPECTED,
    "observed_counts" => counts,
    "feature_files" => FEATURE_FILES,
    "cucumber_exit_status" => status.exitstatus,
    "cucumber_version" => version.strip,
    "credential_source" => if ENV["RP_API_KEY"].to_s.empty? then "existing local demo authentication flow; short-lived bearer kept in memory"
                            else "RP_API_KEY supplied by caller; value not recorded"
                            end
  }
  write_json(File.join(EVIDENCE, "run-summary.json"), summary)
  FileUtils.mkdir_p(File.join(EVIDENCE, "runs"))
  write_json(File.join(EVIDENCE, "runs", "#{ACCEPTANCE_RUN_ID}.json"), summary)
  handoff = summary.merge("scenario_items" => scenarios.map { |item| item.slice("id", "uuid", "name", "status", "testCaseId", "testCaseHash", "codeRef") },
                          "suite_items" => suites.map { |item| item.slice("id", "uuid", "name", "status") },
                          "failed_action_items" => errors.map { |item| item.slice("id", "uuid", "name", "status", "parent") })
  write_json(File.join(EVIDENCE, "handoff.json"), handoff)
  write_json(File.join(EVIDENCE, "items-api.json"), items)
  puts "launch_id=#{launch.fetch('id')}"
  puts "launch_url=#{ui_url}"
  puts "counts=#{JSON.generate(counts)}"
  puts "scenario_item_ids=#{scenarios.map { |item| item['id'] }.join(',')}"

  raise "Observed ReportPortal topology/status counts differ from source-derived expectation" unless counts == EXPECTED
  raise "Expected a retained failed action for the deliberate error" if errors.empty?
end

main
