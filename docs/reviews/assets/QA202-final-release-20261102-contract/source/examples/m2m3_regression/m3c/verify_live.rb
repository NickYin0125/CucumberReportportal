# frozen_string_literal: true

require "json"
require "net/http"
require "open3"
require "uri"

EVIDENCE = File.expand_path(ENV.fetch("M3C_LIVE_EVIDENCE"))
SUMMARY = JSON.parse(File.read(File.join(EVIDENCE, "run-summary.json")))
ITEMS = JSON.parse(File.read(File.join(EVIDENCE, "items-api.json")))
PROJECT = ENV.fetch("RP_PROJECT", "superadmin_personal")
ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://localhost")

# @param checks [Hash]
# @param label [String]
# @param condition [Boolean]
# @return [Boolean]
def assert!(checks, label, condition)
  checks[label] = !!condition
end

# @param url [String]
# @return [Integer]
def http_status(url)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 4, read_timeout: 4) do |http|
    http.request(Net::HTTP::Get.new(uri)).code.to_i
  end
end

# @return [String]
def fetch_bearer
  supplied = ENV["RP_API_KEY"].to_s.strip
  return supplied unless supplied.empty?

  uri = URI.join(ENDPOINT + "/", "uat/sso/oauth/token")
  request = Net::HTTP::Post.new(uri)
  request.basic_auth("ui", "uiman")
  request["Content-Type"] = "application/x-www-form-urlencoded"
  request.body = URI.encode_www_form(grant_type: "password", username: ENV.fetch("RP_USERNAME", "superadmin"),
                                     password: ENV.fetch("RP_PASSWORD", "erebus"))
  response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
  raise "ReportPortal local authentication failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body).fetch("access_token")
end

# @param path [String]
# @param bearer [String]
# @return [Hash]
def api_json(path, bearer)
  uri = URI.join(ENDPOINT + "/", path)
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{bearer}"
  response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
  raise "ReportPortal API returned HTTP #{response.code} for #{uri.path}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

scenarios = ITEMS.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
suites = ITEMS.select { |item| item["type"] == "SUITE" }
other_items = ITEMS - scenarios
source_sha = JSON.parse(File.read(File.join(EVIDENCE, "fixture-repo.json"))).fetch("commit")
by_case = scenarios.to_h do |item|
  attrs = Array(item["attributes"]).to_h { |attribute| [attribute.fetch("key"), attribute.fetch("value")] }
  [attrs["tms"], [item, attrs]]
end
checks = {}
assert!(checks, "two_peer_suites", suites.length == 2)
assert!(checks, "five_scenario_items", scenarios.length == 5)
assert!(checks, "expected_4_passed_1_failed", scenarios.count { |item| item["status"] == "PASSED" } == 4 && scenarios.count { |item| item["status"] == "FAILED" } == 1)
assert!(checks, "no_attributes_on_suite_items", suites.all? { |item| Array(item["attributes"]).empty? })
assert!(checks, "no_extra_links_wire_field", ITEMS.none? { |item| item.key?("links") })
assert!(checks, "all_scenario_items_have_markdown_references", scenarios.all? { |item| item.fetch("description", "").include?("### References") })
assert!(checks, "no_attributes_or_references_on_non_scenarios", other_items.all? do |item|
  Array(item["attributes"]).empty? && !item.fetch("description", "").include?("### References")
end)
assert!(checks, "scenario_uuids_and_stable_ids_unique", scenarios.map { |item| item["uuid"] }.uniq.length == scenarios.length && scenarios.map { |item| item["testCaseId"] }.uniq.length == scenarios.length)

expected = {
  "CASE-UI/42" => { "component" => "recovery", "team" => "identity", "owner" => "identity-team", "layer" => "api", "priority" => "p1", "browser" => "webkit", "tms" => "CASE-UI/42" },
  "CASE-UI/43" => { "component" => "recovery", "team" => "identity", "owner" => "scenario-owner", "layer" => "api", "priority" => "p2", "browser" => "chromium", "tms" => "CASE-UI/43" },
  "CASE-UI/44" => { "component" => "identity", "team" => "identity", "owner" => "quality", "layer" => "api", "priority" => "p1", "browser" => "chromium", "tms" => "CASE-UI/44" },
  "CASE-UI/45" => { "component" => "identity", "team" => "identity", "owner" => "quality", "layer" => "api", "priority" => "p1", "browser" => "chromium", "tms" => "CASE-UI/45" },
  "" => { "component" => "preferences", "team" => "experience", "owner" => "profile-team", "layer" => "ui", "priority" => "p2", "browser" => "firefox" }
}
attrs_match = expected.all? do |case_id, values|
  item_and_attrs = case_id.empty? ? by_case.values.find { |item, attrs| item["name"].include?("Save a profile preference") && !attrs.key?("tms") } : by_case[case_id]
  item_and_attrs && item_and_attrs[1] == values
end
assert!(checks, "case_ids_and_row_attributes_match", attrs_match)
assert!(checks, "stable_v1_wire_ids_distinct_from_case_ids", scenarios.all? { |item| item.fetch("testCaseId", "").start_with?("rp:stable-v1:") })
staff_desc = by_case.fetch("CASE-UI/42").first.fetch("description")
guest_desc = by_case.fetch("CASE-UI/43").first.fetch("description")
assert!(checks, "scenario_and_rule_prose_and_examples_table_preserved", staff_desc.include?("instructions remain readable") && staff_desc.include?("Rule: Recovery links") && staff_desc.include?("API ownership boundary") && staff_desc.include?("| staff | ready |"))
assert!(checks, "outline_examples_row_lines_distinct", staff_desc.include?("?line=22") && guest_desc.include?("?line=27"))
assert!(checks, "encoded_tms_case_destination", staff_desc.include?("/cases/CASE-UI%2F42"))
assert!(checks, "rule_and_scenario_scope_override_visible", by_case.fetch("CASE-UI/42")[1]["layer"] == "api" && by_case.fetch("CASE-UI/43")[1]["owner"] == "scenario-owner")
source_lines = { "CASE-UI/42" => 22, "CASE-UI/43" => 27, "CASE-UI/44" => 30, "CASE-UI/45" => 40, "" => 8 }
local_run_url = "http://127.0.0.1:8883/runs/#{SUMMARY.fetch('acceptance_run_id')}"
links_exact = expected.all? do |case_id, _values|
  item_and_attrs = case_id.empty? ? by_case.values.find { |item, attrs| item["name"].include?("Save a profile preference") && !attrs.key?("tms") } : by_case[case_id]
  next false unless item_and_attrs

  item = item_and_attrs.first
  path = item["codeRef"].to_s.start_with?("features/profile settings.feature") ? "features/profile%20settings.feature" : "features/account%20recovery.feature"
  source_url = "http://127.0.0.1:8883/source/#{source_sha}/#{path}?line=#{source_lines.fetch(case_id)}"
  references = ["[Source](<#{source_url}>)", "[CI Run](<#{local_run_url}>)"]
  references << "[TMS](<http://127.0.0.1:8883/cases/#{URI.encode_www_form_component(case_id).gsub('+', '%20')}>)" unless case_id.empty?
  block = item.fetch("description", "").split("### References\n\n", 2)[1].to_s.strip
  block == references.join(" | ")
end
assert!(checks, "exact_reference_destinations_match_each_case", links_exact)
no_id_case = by_case.values.find { |item, attrs| item["name"].include?("Save a profile preference") && !attrs.key?("tms") }
no_id_reference_block = no_id_case&.first&.fetch("description", "")&.split("### References\n\n", 2)&.last.to_s.strip
assert!(checks, "no_explicit_id_case_has_no_tms_and_only_source_ci_references",
        no_id_case && no_id_case[1].keys.sort == %w[browser component layer owner priority team] &&
          no_id_case.first.fetch("testCaseId", "").start_with?("rp:stable-v1:") &&
          no_id_reference_block.scan(/\[[^\]]+\]/).length == 2 && !no_id_reference_block.include?("[TMS]") &&
          no_id_reference_block.include?("/source/#{source_sha}/features/profile%20settings.feature?line=8") &&
          no_id_reference_block.include?("/runs/#{SUMMARY.fetch('acceptance_run_id')}"))

actual_head, head_status = Open3.capture2("git", "-C", File.join(EVIDENCE, "sandbox"), "rev-parse", "HEAD")
assert!(checks, "source_sha_is_synthetic_fixture_head", head_status.success? && actual_head.strip == source_sha)
server_source = "http://127.0.0.1:8883/source/#{source_sha}/features/account%20recovery.feature?line=22"
server_run = "http://127.0.0.1:8883/runs/#{SUMMARY.fetch('acceptance_run_id')}"
server_case = "http://127.0.0.1:8883/cases/CASE-UI%2F42"
ref_status = { "source" => http_status(server_source), "run" => http_status(server_run), "encoded_case" => http_status(server_case) }
assert!(checks, "all_reference_destinations_http_200", ref_status.values.all? { |code| code == 200 })

parent_by_id = ITEMS.to_h { |item| [item["id"].to_s, item] }
scenario_parents = scenarios.all? do |item|
  parent = parent_by_id[item["parent"].to_s]
  expected_name = item["codeRef"].to_s.start_with?("features/profile settings.feature") ? "Feature: Profile settings" : "Feature: Account recovery"
  parent && parent["type"] == "SUITE" && parent["name"].include?(expected_name)
end
assert!(checks, "scenarios_have_expected_peer_suite_parents", scenario_parents)
actions = ITEMS.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
scenario_ids = scenarios.map { |item| item["id"].to_s }
actions_have_scenario_parents = actions.all? do |item|
  parent_id = item["parent"].to_s
  parent = parent_by_id[parent_id]
  scenario_ids.include?(parent_id) && parent && parent["type"] == "STEP" && parent["hasStats"] == true
end
assert!(checks, "actions_are_children_of_scenarios", actions_have_scenario_parents)

failed = by_case.fetch("CASE-UI/45").first
failed_action = ITEMS.find { |item| item["type"] == "STEP" && item["hasStats"] == false && item["status"] == "FAILED" && item["parent"].to_s == failed["id"].to_s }
raise "Failed Scenario action was absent from API items" unless failed_action
bearer = fetch_bearer
logs_query = URI.encode_www_form("filter.eq.item" => failed_action.fetch("id"), "page.page" => 1, "page.size" => 100)
logs_response = api_json("api/v1/#{PROJECT}/log?#{logs_query}", bearer)
logs = logs_response.fetch("content", [])
error_log = logs.any? do |entry|
  message = entry["message"].is_a?(Hash) ? entry.dig("message", "text").to_s : entry["message"].to_s
  message.include?("M3C live acceptance deliberate service error") && entry["level"].to_s.upcase == "ERROR"
end
assert!(checks, "error_level_failure_log_retained", error_log)
error_owner = failed_action["parent"].to_s == failed.fetch("id").to_s && logs.any? do |entry|
  entry["itemId"].to_s == failed_action["id"].to_s || entry["itemUuid"].to_s == failed_action["uuid"].to_s
end
assert!(checks, "error_log_query_and_action_owner_match", error_owner)

receipt = {
  "launch_id" => SUMMARY.fetch("launch_id"),
  "launch_uuid" => SUMMARY.fetch("launch_uuid"),
  "launch_url" => SUMMARY.fetch("launch_url"),
  "reference_urls" => { "source" => server_source, "local_run" => server_run, "synthetic_tms" => server_case },
  "reference_http_status" => ref_status,
  "failed_item_id" => failed.fetch("id"),
  "failed_action_item_id" => failed_action.fetch("id"),
  "failed_log_count" => logs.length,
  "failed_log_verified" => error_log,
  "failed_log_owner_item_id" => failed_action.fetch("id"),
  "failed_log_levels" => logs.map { |entry| entry["level"] }.uniq,
  "expected_counts" => SUMMARY.fetch("expected_counts"),
  "observed_counts" => SUMMARY.fetch("observed_counts"),
  "checks" => checks,
  "passed" => checks.values.all?
}
File.write(File.join(EVIDENCE, "api-verification.json"), JSON.pretty_generate(receipt) + "\n")
puts "checks=#{checks.values.count(true)}/#{checks.length} references=#{ref_status.inspect} failed_logs=#{logs.length}"
abort("Live API evidence checks failed; see api-verification.json") unless receipt.fetch("passed")
