# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "time"
require "uri"

EVIDENCE = ENV.fetch("M3B_RECONCILIATION_DIR")
LAUNCH_ID = ENV.fetch("M3B_LAUNCH_ID")
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

def json(path, token)
  response = request(path, token: token)
  [response.code.to_i, response.body]
end

def main
  FileUtils.mkdir_p(EVIDENCE)
  auth = request("uat/sso/oauth/token", body: URI.encode_www_form(
    grant_type: "password", username: ENV.fetch("RP_USERNAME", "superadmin"), password: ENV.fetch("RP_PASSWORD", "erebus")
  ))
  raise "ReportPortal authentication failed (HTTP #{auth.code})" unless auth.is_a?(Net::HTTPSuccess)
  token = JSON.parse(auth.body).fetch("access_token")
  launch_query = URI.encode_www_form("page.page" => 1, "page.size" => 100)
  launch = JSON.parse(json("api/v1/#{PROJECT}/launch?#{launch_query}", token).last).fetch("content").find { |entry| entry["id"].to_s == LAUNCH_ID }
  raise "Launch #{LAUNCH_ID} was not found" unless launch
  item_query = URI.encode_www_form("filter.eq.launchId" => LAUNCH_ID, "page.page" => 1, "page.size" => 500,
                                   "page.sort" => "startTime,ASC")
  items_code, items_body = json("api/v1/#{PROJECT}/item?#{item_query}", token)
  raise "Item query returned HTTP #{items_code}" unless items_code == 200
  items = JSON.parse(items_body).fetch("content")
  actions = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
  marker_logs = {}
  actions.each do |item|
    query = URI.encode_www_form("filter.eq.item" => item.fetch("id"), "page.page" => 1, "page.size" => 100)
    code, body = json("api/v1/#{PROJECT}/log?#{query}", token)
    next unless code == 200
    JSON.parse(body).fetch("content", []).each do |entry|
      message = entry["message"].is_a?(Hash) ? entry.dig("message", "text").to_s : entry["message"].to_s
      marker_logs[message] = { action: item.slice("id", "uuid", "name", "parent", "status"), log: entry.slice("id", "itemId", "itemUuid", "level", "message") } if message.include?("M3B_RETRY_ATTEMPT")
    end
  end
  retry_parent_ids = marker_logs.values.map { |entry| entry.dig(:action, "parent").to_s }.uniq
  parent_fetches = retry_parent_ids.to_h do |id|
    code, body = json("api/v1/#{PROJECT}/item/#{URI.encode_www_form_component(id)}", token)
    [id, { status: code, body: (JSON.parse(body) rescue { "response_text" => body.to_s[0, 1000] }) }]
  end
  native = JSON.parse(File.read(File.join(ENV.fetch("M3B_PRIOR_EVIDENCE"), "cucumber.json")))
  stdout = File.read(File.join(ENV.fetch("M3B_PRIOR_EVIDENCE"), "cucumber.stdout.log"))
  observation = {
    classification: "READ-ONLY M3B retry API reconciliation; no launch or item mutation",
    observed_at_utc: Time.now.utc.iso8601, launch_id: launch["id"], launch_uuid: launch["uuid"],
    launch_name: launch["name"], launch_status: launch["status"], launch_statistics: launch["statistics"],
    counts: { default_api_items: items.length, suites: items.count { |item| item["type"] == "SUITE" },
              scenario_items_default_query: items.count { |item| item["type"] == "STEP" && item["hasStats"] == true },
              action_items: actions.length, native_scenarios: native.flat_map { |feature| feature.fetch("elements", []).select { |element| element["type"] == "scenario" } }.length },
    native_cucumber_stats: stdout.lines.find { |line| line.match?(/\d+ scenarios? \(/) }&.strip,
    item_id_types: { id: items.first&.fetch("id")&.class&.name, parent: items.first&.fetch("parent", nil)&.class&.name },
    marker_records_by_exact_message: marker_logs, retry_parent_item_endpoint_responses: parent_fetches,
    raw_api_items: items.map { |item| item.slice("id", "uuid", "name", "type", "hasStats", "status", "parent", "retry", "testCaseId", "uniqueId", "testCaseHash", "codeRef") },
    note: "Compare action parent IDs and marker ownership before interpreting scenario rows; the UI Retries selector may reveal hidden attempts omitted from the default launch item query."
  }
  File.write(File.join(EVIDENCE, "result-manifest.json"), JSON.pretty_generate(observation) + "\n")
  puts "launch_id=#{launch['id']} counts=#{JSON.generate(observation.fetch(:counts))} markers=#{marker_logs.keys.sort.join('|')}"
end

main
