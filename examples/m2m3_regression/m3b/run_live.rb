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
EVIDENCE = ENV.fetch("M3B_LIVE_EVIDENCE")
ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://localhost").delete_suffix("/")
PROJECT = ENV.fetch("RP_PROJECT", "superadmin_personal")
WORK = File.join(EVIDENCE, "work")
NAMESPACE = "m3b-live-regression-20261009"
SDK_ROOT = File.expand_path("../../../tmp/m2m3-regression-20261009/live/sdk", EXAMPLE)

def request(path, token: nil, body: nil)
  uri = URI.join("#{ENDPOINT}/", path)
  req = body ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
  req.basic_auth("ui", "uiman") if path == "uat/sso/oauth/token"
  req["Authorization"] = "Bearer #{token}" if token
  req["Content-Type"] = "application/x-www-form-urlencoded" if body
  req.body = body if body
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 60) { |http| http.request(req) }
end

def api_response(path, token)
  request(path, token: token)
end

def api_json(path, token)
  response = api_response(path, token)
  raise "ReportPortal API returned HTTP #{response.code} for #{URI(path).path}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

def write_json(path, value)
  File.write(path, JSON.pretty_generate(value) + "\n")
end

def item_logs(items, token)
  items.to_h do |item|
    query = URI.encode_www_form("filter.eq.item" => item.fetch("id"), "page.page" => 1, "page.size" => 200)
    [item.fetch("id").to_s, api_json("api/v1/#{PROJECT}/log?#{query}", token).fetch("content", [])]
  end
end

def case_key(item)
  name = item.fetch("name")
  return "explicit" if name.include?("Explicit payment identity")
  return "fallback" if name.include?("Source fallback identity")
  return "retry" if name.include?("Retry keeps case identity")
  return "dataset:#{Array(item['parameters']).to_h { |parameter| [parameter.fetch('key'), parameter.fetch('value')] }.fetch('case')}" if name.include?("Dataset identity")

  raise "Unrecognized M3B scenario item name: #{name}"
end

def canonical_parameters(item)
  Array(item["parameters"]).map { |parameter| parameter.slice("key", "value") }.sort_by { |pair| [pair["key"], pair["value"]] }
end

def launch_for(name, token)
  90.times do
    query = URI.encode_www_form("filter.cnt.name" => name, "page.page" => 1, "page.size" => 20, "page.sort" => "startTime,DESC")
    launch = api_json("api/v1/#{PROJECT}/launch?#{query}", token).fetch("content", []).find { |item| item["name"] == name }
    return launch if launch && launch["statistics"] && launch["status"] != "IN_PROGRESS"

    sleep 1
  end
  raise "Completed ReportPortal launch was not found by exact name: #{name}"
end

def run_variant(label, variant_path, token)
  output_dir = File.join(EVIDENCE, label)
  FileUtils.mkdir_p(output_dir)
  feature_path = File.join(WORK, "m3b.feature")
  FileUtils.cp(variant_path, feature_path)
  FileUtils.cp(feature_path, File.join(output_dir, "m3b.feature"))
  source_sha = Digest::SHA256.file(feature_path).hexdigest
  launch_name = "m3b-live-regression-20261009-#{label}"
  formatter_path = File.join(output_dir, "formatter.log")
  native_path = File.join(output_dir, "cucumber.json")
  command = ["bundle", "exec", "cucumber", "m3b.feature", "--require", File.join(SDK_ROOT, "lib/reportportal_cucumber.rb"),
             "--require", File.join(EXAMPLE, "fixtures/support/m3b_steps.rb"),
             "--format", "pretty", "--format", "json", "--out", native_path,
             "--format", "ReportPortal::Cucumber::Formatter", "--out", formatter_path, "--retry", "1"]
  env = ENV.keys.grep(/\A(?:RP_|CUCUMBER_)/).to_h { |key| [key, nil] }.merge(
    "BUNDLE_GEMFILE" => File.join(EXAMPLE, "Gemfile"), "CUCUMBER_PUBLISH_QUIET" => "true",
    "RP_ENDPOINT" => ENDPOINT, "RP_PROJECT" => PROJECT, "RP_API_KEY" => token, "RP_LAUNCH" => launch_name,
    "RP_LAUNCH_DESCRIPTION" => "M3B stable identity history and retry live regression",
    "RP_CLIENT_JOIN" => "false", "RP_FAIL_ON_REPORTING_ERROR" => "true", "RP_BATCH_SIZE_LOGS" => "1",
    "RP_FLUSH_INTERVAL" => "0.1", "RP_HTTP_READ_TIMEOUT" => "30", "RP_HTTP_WRITE_TIMEOUT" => "30",
    "RP_HTTP_RETRY_ATTEMPTS" => "1", "RP_CONSOLE_MIRROR" => "false",
    "RP_IDENTITY_STRATEGY" => "stable_v1", "RP_IDENTITY_ROOT" => WORK, "RP_IDENTITY_NAMESPACE" => NAMESPACE,
    "RP_TEST_CASE_ID" => nil, "M3B_RETRY_MARKER" => File.join(output_dir, "retry.marker")
  )
  stdout, status = Open3.capture2e(env, *command, chdir: WORK)
  sensitive = [token, ENV.fetch("RP_PASSWORD", "erebus")].reject(&:empty?)
  raise "Sensitive data found in Cucumber output" if sensitive.any? { |value| stdout.include?(value) }
  File.write(File.join(output_dir, "cucumber.stdout.log"), stdout)
  observation = {
    launch_name: launch_name, launch_created: status.success?, child_exit_status: status.exitstatus,
    command: command, source_sha256: source_sha, source_path: feature_path, sdk_path: SDK_ROOT,
    sdk_entrypoint_sha256: Digest::SHA256.file(File.join(SDK_ROOT, "lib/reportportal_cucumber.rb")).hexdigest,
    observed_at_utc: Time.now.utc.iso8601
  }
  write_json(File.join(output_dir, "run-observation.json"), observation)
  unless status.success?
    write_json(File.join(output_dir, "result-manifest.json"), observation.merge(
      classification: "EXPLORATORY PRE-LAUNCH CHILD FAILURE; no ReportPortal launch created"
    ))
    raise "M3B #{label} child exited #{status.exitstatus} before launch creation; see preserved exploratory receipt"
  end

  launch = launch_for(launch_name, token)
  items_query = URI.encode_www_form("filter.eq.launchId" => launch.fetch("id"), "page.page" => 1,
                                    "page.size" => 500, "page.sort" => "startTime,ASC")
  items = api_json("api/v1/#{PROJECT}/item?#{items_query}", token).fetch("content")
  scenarios = items.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
  suites = items.select { |item| item["type"] == "SUITE" && item["hasStats"] == true }
  actions = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
  logs = item_logs(items, token)
  retry_case = scenarios.find { |item| case_key(item) == "retry" }
  retry_detail = retry_case && api_json("api/v1/#{PROJECT}/item/#{retry_case.fetch('id')}", token)
  attempts = if retry_detail
               Array(retry_detail["retries"]).map { |item| item.merge("retry" => false) } + [retry_detail.merge("retry" => true)]
             else
               []
             end
  markers = %w[M3B_RETRY_ATTEMPT\ 1 M3B_RETRY_ATTEMPT\ 2].map do |marker|
    owners = logs.filter_map do |owner_id, records|
      record = records.find { |entry| (entry["message"].is_a?(Hash) ? entry.dig("message", "text") : entry["message"]).to_s.include?(marker) }
      record && { item_id: owner_id, log_id: record["id"], level: record["level"], message: marker }
    end
    { marker: marker.tr("\\", ""), owners: owners }
  end
  stats = launch.dig("statistics", "executions") || {}
  native = JSON.parse(File.read(native_path))
  native_stats = stdout.lines.find { |line| line.match?(/\d+ scenarios? \(/) }&.strip
  checks = {
    observed_child_exit_zero: status.exitstatus == 0,
    native_cucumber_reports_one_flaky_case: native_stats.to_s.include?("5 scenarios (1 flaky, 4 passed)"),
    one_stats_suite: suites.length == 1,
    five_default_server_scenario_rows_with_one_nested_retry: scenarios.length == 5 && attempts.length == 2,
    six_server_action_items: actions.length == 6,
    exact_failed_then_passed_retry: attempts.map { |item| [item["retry"], item["status"]] } == [[false, "FAILED"], [true, "PASSED"]],
    retry_attempts_share_case_identity: attempts.length == 2 && attempts.map { |item| item["testCaseId"] }.uniq.length == 1 &&
      attempts.map { |item| item["uniqueId"] }.uniq.length == 1 && attempts.map { |item| item["testCaseHash"] }.uniq.length == 1,
    stable_wire_identity_used: scenarios.all? { |item| item.fetch("testCaseId", "").start_with?("rp:stable-v1:") },
    each_retry_marker_owned_by_its_attempt: markers.all? do |entry|
      entry.fetch(:owners).length == 1 && attempts.any? do |attempt|
        owner = items.find { |item| item["id"].to_s == entry.fetch(:owners).first.fetch(:item_id) }
        owner && owner["parent"].to_s == attempt["id"].to_s && attempt["retry"] == (entry.fetch(:marker).end_with?("2")) &&
          owner["status"] == (attempt["retry"] ? "PASSED" : "FAILED")
      end
    end,
    launch_statistics_latest_attempts_only: stats["total"].to_i == 5 && stats["passed"].to_i == 5 && stats["failed"].to_i.zero?,
    source_uri_is_the_shared_fixture: scenarios.all? { |item| item.fetch("codeRef", "").start_with?("m3b.feature:") }
  }
  scenarios_by_case = scenarios.group_by { |item| case_key(item) }.transform_values do |entries|
    entries.sort_by { |item| item["retry"] ? 1 : 0 }
  end
  receipt = {
    launch_name: launch_name, launch_id: launch.fetch("id"), launch_uuid: launch.fetch("uuid"),
    launch_status: launch.fetch("status"), launch_url: "#{ENDPOINT}/ui/##{PROJECT}/launches/all/#{launch.fetch('id')}",
    child_exit_status: status.exitstatus, native_cucumber_stats: native_stats, launch_statistics: stats,
    source_sha256: source_sha, source_path: feature_path, source_variant: label,
    source_sha256_identity_loaded: Digest::SHA256.file(File.join(SDK_ROOT, "lib/reportportal_cucumber.rb")).hexdigest,
    sdk_path: SDK_ROOT, namespace: NAMESPACE,
    suites: suites.map { |item| item.slice("id", "uuid", "name", "status") },
    retry_detail: retry_detail&.slice("id", "uuid", "name", "status", "testCaseId", "uniqueId", "testCaseHash", "retries"),
    scenarios_by_case: scenarios_by_case.transform_values do |entries|
      entries.map { |item| item.slice("id", "uuid", "name", "status", "parent", "retry", "testCaseId", "uniqueId", "testCaseHash", "codeRef", "parameters") }
    end,
    retry_marker_logs: markers, checks: checks,
    native_result_file: File.basename(native_path), formatter_file: File.basename(formatter_path)
  }
  write_json(File.join(output_dir, "result-manifest.json"), receipt)
  raise "M3B #{label} checks failed: #{checks.reject { |_key, value| value }.keys.join(', ')}" unless checks.values.all?

  receipt
end

def main
  FileUtils.mkdir_p([EVIDENCE, WORK])
  auth = request("uat/sso/oauth/token", body: URI.encode_www_form(
    grant_type: "password", username: ENV.fetch("RP_USERNAME", "superadmin"), password: ENV.fetch("RP_PASSWORD", "erebus")
  ))
  raise "ReportPortal authentication failed (HTTP #{auth.code})" unless auth.is_a?(Net::HTTPSuccess)
  token = JSON.parse(auth.body).fetch("access_token")

  results = %w[variant-a-r03 variant-b-r03].map do |label|
    filename = label.start_with?("variant-a") ? "variant_a.feature" : "variant_b.feature"
    run_variant(label, File.join(EXAMPLE, "fixtures", filename), token)
  end
  by_case = results.map { |run| run.fetch(:scenarios_by_case) }
  keys = by_case.first.keys
  compare = {
    same_five_logical_cases: keys.sort == by_case.last.keys.sort,
    stable_test_case_ids_equal_across_variants: keys.all? do |key|
      left = by_case.first.fetch(key).first
      right = by_case.last.fetch(key).first
      left["testCaseId"] == right["testCaseId"]
    end,
    stable_unique_ids_equal_across_variants: keys.all? do |key|
      by_case.first.fetch(key).first["uniqueId"] == by_case.last.fetch(key).first["uniqueId"]
    end,
    server_test_case_hash_equal_across_variants: keys.all? do |key|
      by_case.first.fetch(key).map { |item| item["testCaseHash"] }.uniq == by_case.last.fetch(key).map { |item| item["testCaseHash"] }.uniq
    end,
    source_code_refs_changed_between_variants: keys.all? do |key|
      by_case.first.fetch(key).first["codeRef"] != by_case.last.fetch(key).first["codeRef"]
    end,
    retry_uuids_are_new_per_launch: keys.include?("retry") &&
      by_case.first.fetch("retry").map { |item| item["uuid"] }.none? { |uuid| by_case.last.fetch("retry").any? { |item| item["uuid"] == uuid } }
  }

  history_query = URI.encode_www_form("filter.eq.launchId" => results.last.fetch(:launch_id), "historyDepth" => 10,
                                     "isLatest" => "false", "page.page" => 1, "page.size" => 100)
  history_response = api_response("api/v1/#{PROJECT}/item/history?#{history_query}", token)
  history_content = history_response.is_a?(Net::HTTPSuccess) ? JSON.parse(history_response.body).fetch("content", []) : []
  compare[:history_query_http_200_with_launch_selector] = history_response.code == "200" && history_query.include?("filter.eq.launchId")
  retry_case_ids = results.map { |run| run.fetch(:scenarios_by_case).fetch("retry").last.fetch("testCaseId") }
  compare[:history_response_contains_retry_case_for_both_launches] = retry_case_ids.uniq.length == 1 &&
    history_content.any? { |item| item["launchId"].to_s == results.first.fetch(:launch_id).to_s } &&
    history_content.any? { |item| item["launchId"].to_s == results.last.fetch(:launch_id).to_s }
  final = {
    generated_at_utc: Time.now.utc.iso8601,
    classification: "Two new live stable_v1 launches; source variants sequentially used the same fixture URI; API default rows include latest retry with prior attempt nested in retries",
    sdk_path: SDK_ROOT,
    sdk_entrypoint_sha256: Digest::SHA256.file(File.join(SDK_ROOT, "lib/reportportal_cucumber.rb")).hexdigest,
    namespace: NAMESPACE, variants: results, history_query: {
      endpoint: "/api/v1/#{PROJECT}/item/history", status: history_response.code,
      query_parameters: URI.decode_www_form(history_query).to_h.reject { |key, _| key == "filter.eq.launchId" }.merge("filter.eq.launchId" => results.last.fetch(:launch_id)),
      history_rows: history_content.length, launches_in_response: history_content.map { |item| item["launchId"] }.uniq,
      selector: "filter.eq.launchId=#{results.last.fetch(:launch_id)}", expected_retry_test_case_id: retry_case_ids.first
    },
    cross_variant_checks: compare, passed: compare.values.all?
  }
  write_json(File.join(EVIDENCE, "result-manifest.json"), final)
  puts "launches=#{results.map { |run| run.fetch(:launch_id) }.join(',')} history_http=#{history_response.code} checks=#{compare.values.count(true)}/#{compare.length}"
  raise "M3B cross-variant checks failed: #{compare.reject { |_key, value| value }.keys.join(', ')}" unless final.fetch(:passed)
end

main
