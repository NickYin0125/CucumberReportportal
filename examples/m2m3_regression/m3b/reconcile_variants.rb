# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "time"
require "uri"

SOURCE_MANIFEST = ENV.fetch("M3B_SOURCE_MANIFEST")
EVIDENCE = ENV.fetch("M3B_RECONCILIATION_DIR")
ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://localhost").delete_suffix("/")
PROJECT = ENV.fetch("RP_PROJECT", "superadmin_personal")

def request(path, token: nil, body: nil)
  uri = URI.join("#{ENDPOINT}/", path)
  req = body ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
  req.basic_auth("ui", "uiman") if path == "uat/sso/oauth/token"
  req["Authorization"] = "Bearer #{token}" if token
  req["Content-Type"] = "application/x-www-form-urlencoded" if body
  req.body = body if body
  Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 60) { |http| http.request(req) }
end

def api(path, token)
  response = request(path, token: token)
  [response.code.to_i, JSON.parse(response.body)]
end

def main
  FileUtils.mkdir_p(EVIDENCE)
  source = JSON.parse(File.read(SOURCE_MANIFEST))
  auth = request("uat/sso/oauth/token", body: URI.encode_www_form(
    grant_type: "password", username: ENV.fetch("RP_USERNAME", "superadmin"), password: ENV.fetch("RP_PASSWORD", "erebus")
  ))
  raise "ReportPortal authentication failed (HTTP #{auth.code})" unless auth.is_a?(Net::HTTPSuccess)
  token = JSON.parse(auth.body).fetch("access_token")
  launches = source.fetch("variants").map do |variant|
    code, response = api("api/v1/#{PROJECT}/item/#{variant.fetch('retry_detail').fetch('id')}", token)
    raise "Retry detail endpoint returned HTTP #{code}" unless code == 200
    { launch_id: variant.fetch("launch_id"), launch_uuid: variant.fetch("launch_uuid"),
      launch_name: variant.fetch("launch_name"), retry_detail: response }
  end
  selected_launch = source.fetch("variants").last.fetch("launch_id")
  history_query = URI.encode_www_form("filter.eq.launchId" => selected_launch, "historyDepth" => 10,
                                      "isLatest" => "false", "page.page" => 1, "page.size" => 100)
  history_status, history = api("api/v1/#{PROJECT}/item/history?#{history_query}", token)
  rows = history.fetch("content", [])
  nested_attempts = launches.map do |entry|
    latest = entry.fetch(:retry_detail)
    previous = Array(latest["retries"])
    { launch_id: entry.fetch(:launch_id), launch_name: entry.fetch(:launch_name),
      latest: latest.slice("id", "uuid", "status", "testCaseId", "uniqueId", "testCaseHash", "codeRef"),
      retries: previous.map { |item| item.slice("id", "uuid", "status", "testCaseId", "uniqueId", "testCaseHash", "codeRef") } }
  end
  expected_ids = launches.map { |entry| entry.dig(:retry_detail, "testCaseId") }.uniq
  history_resources = rows.flat_map { |group| Array(group["resources"]) }
  matching_history = history_resources.select { |item| expected_ids.include?(item["testCaseId"]) }
  retry_hash = launches.first.dig(:retry_detail, "testCaseHash").to_s
  retry_group = rows.find { |group| group["groupingField"].to_s == retry_hash }
  retry_resources = Array(retry_group && retry_group["resources"])
  target_retry_records = launches.map do |entry|
    candidate = retry_resources.find { |item| item["launchId"].to_s == entry.fetch(:launch_id).to_s }
    { launch_id: entry.fetch(:launch_id), record_id: candidate && candidate["id"], uuid: candidate && candidate["uuid"],
      case_hash: candidate && candidate["testCaseHash"], test_case_id: candidate && candidate["testCaseId"],
      retries: Array(candidate && candidate["retries"]).map { |attempt| attempt.slice("id", "uuid", "status", "testCaseHash", "testCaseId") } }
  end
  path_names = history_resources.map do |item|
    { id: item["id"], testCaseId: item["testCaseId"], pathNames: item["pathNames"],
      launchId: item["launchId"], retries: Array(item["retries"]).map { |retry_item| retry_item.slice("id", "uuid", "status", "launchId") } }
  end
  checks = {
    source_cross_variant_identity_checks_all_pass: source.fetch("cross_variant_checks").except("history_response_contains_retry_case_for_both_launches").values.all?,
    two_retry_detail_endpoints_return_200: launches.length == 2,
    retry_history_identity_matches_across_launches: nested_attempts.map { |entry| entry.dig(:latest, "testCaseId") }.uniq.length == 1 &&
      nested_attempts.all? { |entry| entry.fetch(:retries).length == 1 && entry.fetch(:retries).first["status"] == "FAILED" },
    retry_attempt_uuids_are_distinct: nested_attempts.flat_map { |entry| [entry.dig(:latest, "uuid"), *entry.fetch(:retries).map { |retry_item| retry_item["uuid"] }] }.uniq.length == 4,
    history_query_http_200_with_launch_selector: history_status == 200 && history_query.include?("filter.eq.launchId"),
    history_group_contains_same_retry_case_hash: retry_group && retry_group["groupingField"].to_s == retry_hash && retry_resources.any? { |item| item["testCaseId"] == expected_ids.first },
    retry_records_cooccur_for_launches_40_and_41: target_retry_records.length == 2 &&
      target_retry_records.all? { |record| record[:record_id] && record[:case_hash].to_s == retry_hash && record[:retries].length == 1 && record[:retries].first["status"] == "FAILED" },
    history_rows_identify_launches_through_resource_launch_id_and_path_metadata: [40, 41].all? do |launch_id|
      retry_resources.any? { |item| item["launchId"].to_s == launch_id.to_s && item.dig("pathNames", "launchPathName", "name").to_s.include?(launch_id == 40 ? "variant-a-r03" : "variant-b-r03") }
    end
  }
  receipt = {
    classification: "READ-ONLY M3B API reconciliation for launches 40/41; prior false r03 aggregate is preserved",
    source_failed_aggregate: SOURCE_MANIFEST, generated_at_utc: Time.now.utc.iso8601,
    launches: nested_attempts, history_query: { endpoint: "/api/v1/#{PROJECT}/item/history", status: history_status,
      selector: "filter.eq.launchId=#{selected_launch}", parameters: URI.decode_www_form(history_query).to_h,
      grouping_count: rows.length, flattened_resource_count: history_resources.length,
      matching_target_case_resources: matching_history.length,
      launch_metadata_examples: path_names, retry_case_grouping_field: retry_hash,
      retry_case_records_for_launches_40_41: target_retry_records },
    raw_history_content: rows, checks: checks, passed: checks.values.all?,
    api_semantics: "History rows are scenario groups and omit top-level launchId; inspect pathNames and nested retries. The filter.eq.launchId selector scopes the query and a 200 response is not proof that every source launch appears as a top-level row."
  }
  File.write(File.join(EVIDENCE, "result-manifest.json"), JSON.pretty_generate(receipt) + "\n")
  puts "launches=#{nested_attempts.map { |entry| entry.fetch(:launch_id) }.join(',')} history_http=#{history_status} rows=#{rows.length} checks=#{checks.values.count(true)}/#{checks.length}"
  abort "M3B read-only reconciliation failed: #{checks.reject { |_key, value| value }.keys.join(', ')}" unless receipt.fetch(:passed)
end

main
