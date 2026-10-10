# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "time"
require "uri"

EVIDENCE = ENV.fetch("M3A_DETAILED_EVIDENCE")
PRIOR = ENV.fetch("M3A_PRIOR_EVIDENCE")
ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://localhost").delete_suffix("/")
PROJECT = ENV.fetch("RP_PROJECT", "superadmin_personal")

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
  raise "ReportPortal API returned HTTP #{response.code} for #{URI(path).path}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

def text(value)
  value.is_a?(Hash) ? value.fetch("text", value.to_json) : value.to_s
end

def main
  FileUtils.mkdir_p(EVIDENCE)
  previous = JSON.parse(File.read(File.join(PRIOR, "result-manifest.json")))
  launch_id = previous.fetch("launch_id").to_s
  auth = request("uat/sso/oauth/token", body: URI.encode_www_form(
    grant_type: "password", username: ENV.fetch("RP_USERNAME", "superadmin"), password: ENV.fetch("RP_PASSWORD", "erebus")
  ))
  raise "ReportPortal authentication failed (HTTP #{auth.code})" unless auth.is_a?(Net::HTTPSuccess)
  token = JSON.parse(auth.body).fetch("access_token")

  query = URI.encode_www_form("page.page" => 1, "page.size" => 100)
  launch = api("api/v1/#{PROJECT}/launch?#{query}", token).fetch("content").find { |entry| entry["id"].to_s == launch_id }
  raise "Original M3A launch #{launch_id} not found" unless launch
  item_query = URI.encode_www_form("filter.eq.launchId" => launch_id, "page.page" => 1, "page.size" => 500,
                                   "page.sort" => "startTime,ASC")
  items = api("api/v1/#{PROJECT}/item?#{item_query}", token).fetch("content")
  by_id = items.to_h { |item| [item.fetch("id").to_s, item] }
  suites = items.select { |item| item["type"] == "SUITE" && item["hasStats"] == true }
  cases = items.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
  actions = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
  native = JSON.parse(File.read(File.join(PRIOR, "cucumber.json")))
  native_cases = native.flat_map { |feature| feature.fetch("elements", []).select { |entry| entry["type"] == "scenario" } }

  expected_cases = {
    "English ordinary case" => { suite: "Feature: M3A English metadata fixture", record: nil, row: nil, example: nil },
    "English outlined case alpha" => { suite: "Feature: M3A English metadata fixture", record: "alpha", row: "55", example: "English first examples block" },
    "English outlined case beta" => { suite: "Feature: M3A English metadata fixture", record: "beta", row: "56", example: "English first examples block" },
    "English outlined case gamma" => { suite: "Feature: M3A English metadata fixture", record: "gamma", row: "61", example: "English second examples block" },
    "English outlined case delta" => { suite: "Feature: M3A English metadata fixture", record: "delta", row: "62", example: "English second examples block" },
    "中文普通用例" => { suite: "功能: M3A 中文元数据夹具", record: nil, row: nil, example: nil },
    "中文示例用例 一组" => { suite: "功能: M3A 中文元数据夹具", record: "一组", row: "55", example: "中文示例数据" },
    "中文示例用例 二组" => { suite: "功能: M3A 中文元数据夹具", record: "二组", row: "56", example: "中文示例数据" }
  }
  cases_by_key = cases.to_h do |item|
    key = expected_cases.keys.find { |name| item.fetch("name").include?(name) }
    raise "Unexpected or duplicate scenario item: #{item['name']}" unless key && !cases.any? { |other| other != item && other.fetch("name").include?(key) }
    [key, item]
  end

  parentage = cases.all? do |item|
    expected = expected_cases.find { |name, _| item.fetch("name").include?(name) }&.last
    suite = by_id[item.fetch("parent").to_s]
    expected && suite && suite["type"] == "SUITE" && suite["name"] == expected.fetch(:suite)
  end
  per_case = cases.all? do |item|
    child_actions = actions.select { |action| action["parent"].to_s == item["id"].to_s }
    expected = expected_cases.find { |name, _| item.fetch("name").include?(name) }&.last
    next false unless expected && child_actions.length == 5

    names = child_actions.map { |action| action.fetch("name") }
    names.any? { |name| name.include?("[Background]") } &&
      child_actions.count { |action| action.fetch("name").include?("[Background]") } == 2 &&
      child_actions.count { |action| action.fetch("name").match?(/\A(?:Given|假如)\b/) } == 1 &&
      child_actions.count { |action| action.fetch("name").match?(/\A(?:When|当)\b/) } == 1 &&
      child_actions.count { |action| action.fetch("name").match?(/\A(?:Then|那么)\b/) } == 1
  end
  rich = actions.select { |action| action["name"].to_s.match?(/(?:table for|document:|表格|文档)/) }
  log_results = rich.to_h do |action|
    logs_query = URI.encode_www_form("filter.eq.item" => action.fetch("id"), "page.page" => 1, "page.size" => 100)
    [action.fetch("id").to_s, api("api/v1/#{PROJECT}/log?#{logs_query}", token).fetch("content", [])]
  end
  expected_table = { "ordinary" => "ordinary", "alpha" => "alpha", "beta" => "beta", "gamma" => "gamma", "delta" => "delta", "中文普通用例" => "ordinary", "一组" => "一组", "二组" => "二组" }
  rich_case_checks = cases.to_h do |item|
    key, expected = expected_cases.find { |name, _| item.fetch("name").include?(name) }
    row = item.fetch("parameters", []).to_h { |entry| [entry.fetch("key"), entry.fetch("value")] }
    record = expected.fetch(:record) || (key.include?("中文") ? (key.include?("普通") ? "中文普通用例" : key.split.last) : "ordinary")
    owned = rich.select { |action| action["parent"].to_s == item["id"].to_s }
    table = owned.find { |action| action["name"].to_s.match?(/(?:table for|表格)/) }
    doc = owned.find { |action| action["name"].to_s.match?(/(?:document:|文档)/) }
    table_logs = table && log_results.fetch(table["id"].to_s, [])
    doc_logs = doc && log_results.fetch(doc["id"].to_s, [])
    table_text = [table&.fetch("description", ""), *Array(table_logs).map { |entry| text(entry["message"]) }].join("\n")
    doc_text = [doc&.fetch("description", ""), *Array(doc_logs).map { |entry| text(entry["message"]) }].join("\n")
    row_ok = expected.fetch(:record) ? row["record"] == expected.fetch(:record) : row.empty?
    [key, {
      expected_parameters: row_ok,
      table_log_owner_and_rendering: table_logs&.length == 1 && table_text.include?(expected_table.fetch(record)) &&
        table_text.include?("A\\|B") && table_text.include?("line<br>next") && table_text.include?("|  |"),
      docstring_log_owner_and_substitution: doc_logs&.length == 1 && doc_text.include?(expected_table.fetch(record)) &&
        doc_text.include?("path\\\\leaf") && doc_text.include?("````json") &&
        (expected.fetch(:record) ? !doc_text.match?(/<(?:record|value|template)>/) : doc_text.include?("<not-a-parameter>"))
    }]
  end
  rich_checks = rich_case_checks.values.all? { |entry| entry.values.all? }
  native_steps = native_cases.flat_map { |scenario| scenario.fetch("steps", []) }
  checks = {
    exact_original_launch_and_uuid: launch["uuid"] == previous["launch_uuid"],
    prior_live_child_exit_zero: previous["child_exit_status"] == 0,
    independent_source_oracle_eight_cases: cases_by_key.keys.sort == expected_cases.keys.sort,
    two_feature_suites_and_eight_cases: suites.length == 2 && cases.length == 8,
    forty_reportportal_actions_and_twenty_four_native_authored_steps: actions.length == 40 && native_steps.length == 24,
    scenario_parents_match_feature_suites: parentage,
    each_case_has_two_background_and_three_authored_actions: per_case,
    sixteen_rich_actions_each_with_one_owned_log: rich.length == 16 && log_results.values.all? { |logs| logs.length == 1 },
    outlined_parameters_and_action_payloads_match_literal_examples: rich_checks,
    eight_native_cases_and_all_authored_steps_passed: native_cases.length == 8 && native_steps.all? { |step| step.dig("result", "status") == "passed" },
    launch_statistics_eight_passed: launch.dig("statistics", "executions", "total").to_i == 8 && launch.dig("statistics", "executions", "passed").to_i == 8 && launch.dig("statistics", "executions", "failed").to_i.zero?
  }
  receipt = {
    classification: "READ-ONLY detailed M3A API oracle; no launch created; historical false receipts preserved",
    source_receipt: File.join(PRIOR, "result-manifest.json"), generated_at_utc: Time.now.utc.iso8601,
    launch_id: launch["id"], launch_uuid: launch["uuid"], launch_status: launch["status"],
    source_child_exit_status: previous["child_exit_status"],
    counts: { suites: suites.length, scenarios: cases.length, reportportal_actions: actions.length,
              native_scenarios: native_cases.length, native_authored_steps: native_steps.length, rich_actions: rich.length },
    id_types: { launch_id: launch["id"].class.name, item_id: cases.first&.fetch("id")&.class&.name,
                parent_id: cases.first&.fetch("parent")&.class&.name },
    checks: checks, passed: checks.values.all?,
    rich_case_checks: rich_case_checks,
    scenario_items: cases.map { |item| item.slice("id", "uuid", "name", "status", "parent", "description", "parameters", "codeRef") },
    action_items: actions.map { |item| item.slice("id", "uuid", "name", "status", "parent", "description") },
    rich_log_owners: log_results.transform_values { |logs| logs.map { |entry| entry.slice("id", "itemId", "itemUuid", "level", "message") } },
    visual_boundary: "RP Markdown swallowed raw <record> prose in the original Master UI review; API metadata success does not claim visual perfection."
  }
  File.write(File.join(EVIDENCE, "result-manifest.json"), JSON.pretty_generate(receipt) + "\n")
  puts "launch_id=#{launch_id} counts=#{JSON.generate(receipt.fetch(:counts))} checks=#{checks.values.count(true)}/#{checks.length}"
  abort "M3A detailed live oracle failed: #{checks.reject { |_key, value| value }.keys.join(', ')}" unless receipt.fetch(:passed)
end

main
