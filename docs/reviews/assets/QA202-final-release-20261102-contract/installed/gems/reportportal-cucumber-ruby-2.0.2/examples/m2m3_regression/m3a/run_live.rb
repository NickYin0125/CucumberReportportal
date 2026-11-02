# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "securerandom"
require "time"
require "uri"

EXAMPLE = __dir__
EVIDENCE = ENV.fetch("M3A_LIVE_EVIDENCE")
ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://localhost").delete_suffix("/")
PROJECT = ENV.fetch("RP_PROJECT", "superadmin_personal")
LAUNCH = ENV.fetch("RP_LAUNCH", "m3a-regression-20261009-#{SecureRandom.hex(3)}")
SDK_ROOT = File.expand_path("../../../tmp/m2m3-regression-20261009/live/sdk", EXAMPLE)

def request(path, token: nil, body: nil)
  uri = URI.join("#{ENDPOINT}/", path)
  req = body ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
  req.basic_auth("ui", "uiman") if path == "uat/sso/oauth/token"
  req["Authorization"] = "Bearer #{token}" if token
  req["Content-Type"] = "application/x-www-form-urlencoded" if body
  req.body = body if body
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 60) do |http|
    http.request(req)
  end
end

def api_json(path, token)
  response = request(path, token: token)
  raise "ReportPortal API returned HTTP #{response.code} for #{URI(path).path}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

def main
  FileUtils.mkdir_p(EVIDENCE)
  auth = request("uat/sso/oauth/token", body: URI.encode_www_form(
    grant_type: "password", username: ENV.fetch("RP_USERNAME", "superadmin"), password: ENV.fetch("RP_PASSWORD", "erebus")
  ))
  raise "ReportPortal authentication failed (HTTP #{auth.code})" unless auth.is_a?(Net::HTTPSuccess)

  token = JSON.parse(auth.body).fetch("access_token")
  command = ["bundle", "exec", "ruby", "run.rb", "--format", "json", "--out", File.join(EVIDENCE, "cucumber.json"),
             "--format", "ReportPortal::Cucumber::Formatter", "--out", File.join(EVIDENCE, "formatter.log")]
  env = {
    "BUNDLE_GEMFILE" => File.join(EXAMPLE, "Gemfile"), "RP_ENDPOINT" => ENDPOINT, "RP_PROJECT" => PROJECT,
    "RP_API_KEY" => token, "RP_LAUNCH" => LAUNCH, "RP_LAUNCH_DESCRIPTION" => "M3A bilingual AST live regression",
    "RP_ATTRIBUTES" => "suite:m3a,mode:live-cucumber10", "RP_CLIENT_JOIN" => "false",
    "RP_FAIL_ON_REPORTING_ERROR" => "true", "RP_BATCH_SIZE_LOGS" => "1", "RP_FLUSH_INTERVAL" => "0.2",
    "CUCUMBER_PUBLISH_QUIET" => "true", "M3A_STDOUT_FORMAT" => "progress"
  }
  started = Time.now.utc
  output, status = Open3.capture2e(env, *command, chdir: EXAMPLE)
  raise "Sensitive credential appeared in child output" if output.include?(token)
  File.write(File.join(EVIDENCE, "cucumber.stdout.log"), output)

  observation = {
    launch_name: LAUNCH, child_exit_status: status.exitstatus, command: command,
    observed_at_utc: Time.now.utc.iso8601, started_at_utc: started.iso8601,
    sdk_path: SDK_ROOT,
    sdk_entrypoint_sha256: Digest::SHA256.file(File.join(SDK_ROOT, "lib/reportportal_cucumber.rb")).hexdigest,
    cucumber_version: `PATH=/opt/homebrew/opt/ruby/bin:$PATH BUNDLE_GEMFILE=#{Shellwords.escape(File.join(EXAMPLE, "Gemfile"))} bundle exec cucumber --version`.strip
  }

  launch = nil
  60.times do
    query = URI.encode_www_form("filter.cnt.name" => LAUNCH, "page.page" => 1, "page.size" => 20, "page.sort" => "startTime,DESC")
    launch = api_json("api/v1/#{PROJECT}/launch?#{query}", token).fetch("content", []).find { |item| item["name"] == LAUNCH }
    break if launch && launch["statistics"] && launch["status"] != "IN_PROGRESS"

    sleep 1
  end
  raise "Completed launch was not found by exact name" unless launch

  query = URI.encode_www_form("filter.eq.launchId" => launch.fetch("id"), "page.page" => 1, "page.size" => 500,
                              "page.sort" => "startTime,ASC")
  items = api_json("api/v1/#{PROJECT}/item?#{query}", token).fetch("content")
  scenarios = items.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
  suites = items.select { |item| item["type"] == "SUITE" && item["hasStats"] == true }
  actions = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
  native = JSON.parse(File.read(File.join(EVIDENCE, "cucumber.json")))
  native_scenarios = native.flat_map { |feature| feature.fetch("elements", []).select { |entry| entry["type"] == "scenario" } }
  native_steps = native_scenarios.flat_map { |scenario| scenario.fetch("steps", []) }
  passed_native = native_scenarios.all? do |scenario|
    scenario.fetch("steps").all? { |step| step.dig("result", "status") == "passed" }
  end
  checks = {
    observed_child_exit_zero: observation.fetch(:child_exit_status) == 0,
    expected_native_8_scenarios_24_explicit_steps: native_scenarios.length == 8 && native_steps.length == 24,
    every_native_step_passed: passed_native,
    two_stats_suites: suites.length == 2,
    eight_stats_scenario_items: scenarios.length == 8,
    forty_action_items: actions.length == 40,
    reportportal_statistics_match: launch.dig("statistics", "executions", "total").to_i == 8 &&
      launch.dig("statistics", "executions", "passed").to_i == 8 && launch.dig("statistics", "executions", "failed").to_i.zero?
  }
  observation.merge!(launch_id: launch.fetch("id"), launch_uuid: launch.fetch("uuid"),
                     launch_status: launch.fetch("status"), checks: checks,
                     counts: { suites: suites.length, scenarios: scenarios.length, actions: actions.length,
                               native_scenarios: native_scenarios.length, native_steps: native_steps.length },
                     scenario_items: scenarios.map { |item| item.slice("id", "uuid", "name", "status", "codeRef", "testCaseId", "testCaseHash") },
                     suite_items: suites.map { |item| item.slice("id", "uuid", "name", "status") },
                     launch_url: "#{ENDPOINT}/ui/##{PROJECT}/launches/all/#{launch.fetch('id')}")
  File.write(File.join(EVIDENCE, "result-manifest.json"), JSON.pretty_generate(observation) + "\n")
  puts "launch_id=#{launch.fetch('id')} launch_url=#{observation.fetch(:launch_url)}"
  puts "counts=#{JSON.generate(observation.fetch(:counts))} child_exit=#{status.exitstatus}"
  raise "M3A live checks failed: #{checks.reject { |_key, value| value }.keys.join(', ')}" unless checks.values.all?
end

require "shellwords"
main
