# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "time"
require "uri"

EVIDENCE = ENV.fetch("M3A_METADATA_EVIDENCE")
ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://localhost").delete_suffix("/")
PROJECT = ENV.fetch("RP_PROJECT", "superadmin_personal")
LAUNCH_ID = ENV.fetch("RP_EXISTING_LAUNCH_ID")

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

def log_text(record)
  message = record["message"]
  message.is_a?(Hash) ? message.fetch("text", "").to_s : message.to_s
end

FileUtils.mkdir_p(EVIDENCE)
auth = request("uat/sso/oauth/token", body: URI.encode_www_form(
  grant_type: "password", username: ENV.fetch("RP_USERNAME", "superadmin"), password: ENV.fetch("RP_PASSWORD", "erebus")
))
raise "ReportPortal authentication failed (HTTP #{auth.code})" unless auth.is_a?(Net::HTTPSuccess)
token = JSON.parse(auth.body).fetch("access_token")

launch_query = URI.encode_www_form("page.page" => 1, "page.size" => 100)
launch = api("api/v1/#{PROJECT}/launch?#{launch_query}", token).fetch("content").find { |item| item["id"].to_s == LAUNCH_ID }
raise "M3A launch was not found" unless launch
items_query = URI.encode_www_form("filter.eq.launchId" => LAUNCH_ID, "page.page" => 1, "page.size" => 500,
                                  "page.sort" => "startTime,ASC")
items = api("api/v1/#{PROJECT}/item?#{items_query}", token).fetch("content")
suites = items.select { |item| item["type"] == "SUITE" && item["hasStats"] == true }
scenarios = items.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
actions = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
suite_by_id = suites.to_h { |item| [item["id"].to_s, item] }
scenario_by_uuid = scenarios.to_h { |item| [item["uuid"], item] }

english_suite = suites.find { |item| item["name"].to_s.include?("M3A English metadata fixture") }
chinese_suite = suites.find { |item| item["name"].to_s.include?("M3A 中文元数据夹具") }
english_cases = scenarios.select { |item| item["codeRef"].to_s.include?("english.feature") }
chinese_cases = scenarios.select { |item| item["codeRef"].to_s.include?("zh-CN.feature") }
case_actions = actions.group_by { |item| item["parent"].to_s }
rich_actions = actions.select { |item| item["name"].to_s.match?(/M3A table|M3A document|M3A 表格|M3A 文档/) }
rich_logs = {}
rich_actions.each do |item|
  query = URI.encode_www_form("filter.eq.item" => item.fetch("id"), "page.page" => 1, "page.size" => 100)
  records = api("api/v1/#{PROJECT}/log?#{query}", token).fetch("content", [])
  rich_logs[item.fetch("uuid")] = records
end

expected_rows = {
  "English outlined case alpha" => { "record" => "alpha", "value" => "first", "template" => "token-a" },
  "English outlined case beta" => { "record" => "beta", "value" => "second", "template" => "token-b" },
  "English outlined case gamma" => { "record" => "gamma", "value" => "third", "template" => "token-c" },
  "English outlined case delta" => { "record" => "delta", "value" => "fourth", "template" => "token-d" },
  "中文示例用例 一组" => { "record" => "一组", "value" => "first", "template" => "token-1" },
  "中文示例用例 二组" => { "record" => "二组", "value" => "second", "template" => "token-2" }
}
outline_checks = expected_rows.to_h do |suffix, expected|
  item = scenarios.find { |scenario| scenario["name"] == "Scenario: #{suffix}" }
  params = Array(item && item["parameters"]).to_h { |parameter| [parameter.fetch("key"), parameter.fetch("value")] }
  owned = Array(item && case_actions[item["id"].to_s])
  table = owned.find { |action| action["name"].to_s.match?(/M3A table|M3A 表格/) }
  document = owned.find { |action| action["name"].to_s.match?(/M3A document|M3A 文档/) }
  table_message = table && log_text(Array(rich_logs[table["uuid"]]).first || {})
  document_message = document && log_text(Array(rich_logs[document["uuid"]]).first || {})
  language = suffix.start_with?("中文") ? "zh-CN" : "english"
  table_step_name = suffix.start_with?("中文") ? "当 我验证 M3A 表格 \"#{expected.fetch('record')}\":" : "When I verify the M3A table for \"#{expected.fetch('record')}\":"
  source_prose = suffix.start_with?("中文") ? "<record> 的大纲描述。" : "Outline description for <record>."
  checks = {
    case_exists: !item.nil?,
    parameters_match: params == expected,
    parameter_keys_and_values_match: params == expected && params.keys.sort == %w[record template value],
    code_ref_matches_language: item && item["codeRef"].to_s.include?("#{language}.feature"),
    description_contains_expanded_row: item && %w[record value template].all? { |word| item.fetch("description", "").include?(expected.fetch(word)) },
    source_outline_prose_placeholder_retained: item && item.fetch("description", "").include?(source_prose),
    outline_prose_substitution_missing: item && item.fetch("description", "").include?(source_prose) && !item.fetch("description", "").include?(expected.fetch("record")),
    table_action_name_matches: table && table["name"] == table_step_name,
    table_log_renders_values_and_escapes: table_message && table_message.include?(expected.fetch("record")) &&
      table_message.include?(expected.fetch("value")) && table_message.include?("A\\|B") && table_message.include?("line<br>next"),
    document_log_renders_substitution: document_message && document_message.include?("\"record\": \"#{expected.fetch('record')}\"") &&
      document_message.include?("\"template\": \"#{expected.fetch('template')}\"")
  }
  [suffix, checks]
end

english_ordinary = scenarios.find { |item| item["name"] == "Scenario: English ordinary case" }
chinese_ordinary = scenarios.find { |item| item["name"] == "Scenario: 中文普通用例" }
ordinary_checks = {
  english_case_description_preserves_rule_and_scenario: english_ordinary &&
    %w[English\ rule\ metadata Rule\ description\ belongs\ to\ the\ case\ context Ordinary\ scenario\ description].all? { |text| english_ordinary.fetch("description", "").include?(text.gsub("\\", "")) },
  chinese_case_description_preserves_rule_and_scenario: chinese_ordinary &&
    ["中文规则元数据", "规则描述属于用例上下文", "普通场景描述"].all? { |text| chinese_ordinary.fetch("description", "").include?(text) },
  scenario_descriptions_do_not_copy_feature_descriptions: scenarios.none? { |item| item.fetch("description", "").include?("Feature description line one") },
  english_suite_description_is_feature_scoped: english_suite && %w[Feature\ description\ line\ one. Feature\ description\ line\ two].all? { |text| english_suite.fetch("description", "").include?(text.gsub("\\", "")) },
  chinese_suite_description_is_feature_scoped: chinese_suite && ["功能描述第一行。", "功能描述第二行。"].all? { |text| chinese_suite.fetch("description", "").include?(text) }
}

table_action = actions.find { |item| item["name"].to_s.include?("verify the M3A table for \"ordinary\"") }
document_action = actions.find { |item| item["name"].to_s.include?("verify the M3A document") }
table_text = table_action && log_text(Array(rich_logs[table_action["uuid"]]).first || {})
document_text = document_action && log_text(Array(rich_logs[document_action["uuid"]]).first || {})
all_rich_text = rich_logs.values.flatten.map { |entry| log_text(entry) }.join("\n")
parentage = scenarios.all? do |scenario|
  parent = suite_by_id[scenario["parent"].to_s]
  expected_suite = scenario["codeRef"].to_s.include?("english.feature") ? english_suite : chinese_suite
  parent && expected_suite && parent["uuid"] == expected_suite["uuid"]
end
per_scenario_actions = scenarios.to_h do |scenario|
  owned = Array(case_actions[scenario.fetch("id").to_s])
  backgrounds = owned.count { |item| item.fetch("name", "").start_with?("[Background]") }
  record = scenario.fetch("name").include?("ordinary") || scenario.fetch("name").include?("普通用例") ? "ordinary" : scenario.fetch("name").split.last
  expected_names = if scenario.fetch("codeRef").include?("english.feature")
                     ["[Background] Given the shared M3A feature context", "[Background] Given the shared M3A context",
                      "Given the shared M3A context", "When I verify the M3A table for \"#{record}\":", "Then I verify the M3A document:"]
                   else
                     ["[Background] 假如 共享的 M3A 功能上下文", "[Background] 假如 共享的 M3A 上下文",
                      "假如 共享的 M3A 上下文", "当 我验证 M3A 表格 \"#{record}\":", "那么 我验证 M3A 文档:"]
                   end
  [scenario.fetch("name"), { count: owned.length, expanded_background_actions: backgrounds,
                              exact_action_names_and_keywords: owned.map { |item| item.fetch("name") }.sort == expected_names.sort,
                              all_actions_resolved: owned.none? { |item| item.fetch("name", "").match?(/<record>|<value>|<template>/) } }]
end
checks = {
  exact_live_topology_2_8_40_and_50_total_items: suites.length == 2 && scenarios.length == 8 && actions.length == 40 && items.length == 50,
  unique_item_ids_and_uuids: items.map { |item| item["id"].to_s }.uniq.length == items.length && items.map { |item| item["uuid"] }.uniq.length == items.length,
  suite_names_and_feature_descriptions: english_suite && chinese_suite && english_suite.fetch("description", "").include?("Feature description line one.") &&
    chinese_suite.fetch("description", "").include?("功能描述第一行。"),
  five_english_and_three_chinese_cases: english_cases.length == 5 && chinese_cases.length == 3,
  every_case_has_its_correct_feature_suite_parent: parentage,
  every_scenario_has_two_expanded_background_and_three_authored_actions: per_scenario_actions.values.all? do |entry|
    entry.fetch(:count) == 5 && entry.fetch(:expanded_background_actions) == 2 &&
      entry.fetch(:exact_action_names_and_keywords) && entry.fetch(:all_actions_resolved)
  end,
  exactly_sixteen_rich_actions_with_one_owned_log_each: rich_actions.length == 16 && rich_logs.values.all? { |records| records.length == 1 },
  no_outline_placeholders_in_actions_or_rich_logs: actions.none? { |item| item.fetch("name", "").match?(/<record>|<value>|<template>/) } &&
    !all_rich_text.match?(/<record>|<value>|<template>/),
  ordinary_escaped_table_and_docstring_rendering: table_text && table_text.include?("| key | value | escaped | newline | trailing |") &&
    table_text.include?("| ordinary | plain | A\\|B | line<br>next |  |") && document_text && document_text.include?("````json") &&
    document_text.include?("line one\\nline two") && document_text.include?("path\\\\leaf") && document_text.include?("\"fence\": \"```json\""),
  six_outline_rows_each_have_detailed_data_checks: outline_checks.length == 6 && outline_checks.values.all? do |row|
    row.except(:outline_prose_substitution_missing).values.all?
  end,
  outline_prose_substitution_gap_detected_in_all_six_rows: outline_checks.values.all? { |row| row.fetch(:outline_prose_substitution_missing) },
  ordinary_scenario_and_feature_scope_text: ordinary_checks.values.all?,
  launch_statistics_eight_passed: launch.dig("statistics", "executions", "total").to_i == 8 &&
    launch.dig("statistics", "executions", "passed").to_i == 8 && launch.dig("statistics", "executions", "failed").to_i.zero?
}
receipt = {
  classification: "READ-ONLY DETAILED API RECONCILIATION OF EXISTING M3A LAUNCH",
  verified_at_utc: Time.now.utc.iso8601, launch_id: LAUNCH_ID, launch_uuid: launch["uuid"], launch_status: launch["status"],
  launch_url: "#{ENDPOINT}/ui/##{PROJECT}/launches/all/#{LAUNCH_ID}",
  counts: { suites: suites.length, scenarios: scenarios.length, expanded_actions: actions.length, total_items: items.length,
            rich_actions: rich_actions.length },
  detailed_outline_checks: outline_checks, ordinary_and_suite_metadata_checks: ordinary_checks,
  per_scenario_action_detail: per_scenario_actions,
  scenario_items: scenarios.map { |item| item.slice("id", "uuid", "name", "status", "parent", "parentUuid", "codeRef", "description", "parameters") },
  suite_items: suites.map { |item| item.slice("id", "uuid", "name", "status", "description") },
  action_item_ids: actions.map { |item| item.slice("id", "uuid", "name", "parent", "parentUuid") },
  checks: checks, verifier_passed: checks.values.all?, acceptance_passed: checks.values.all? && !checks.fetch(:outline_prose_substitution_gap_detected_in_all_six_rows),
  findings: [{ severity: "M3A metadata/rendering gap", description: "The six outline descriptions retain literal <record> in the API; Master observed the tag stripped from Chinese outline prose in the RP UI. No SDK change was made." }]
}
File.write(File.join(EVIDENCE, "result-manifest.json"), JSON.pretty_generate(receipt) + "\n")
puts "launch_id=#{LAUNCH_ID} checked_items=#{items.length} checks=#{checks.values.count(true)}/#{checks.length} outline_rows=#{outline_checks.length}"
abort "M3A detailed verifier checks failed: #{checks.reject { |_key, value| value }.keys.join(', ')}" unless receipt.fetch(:verifier_passed)
