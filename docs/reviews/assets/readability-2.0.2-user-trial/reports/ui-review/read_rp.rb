# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "time"

ROOT = File.expand_path(__dir__)
BASE = "http://rp-2607.localhost:18080/api/v1/superadmin_personal"
LAUNCHES = [3847, 3848, 3849, 3850, 3851, 3852].freeze
UI_LAUNCHES = [3848, 3850, 3852].freeze
KEY = ENV.fetch("RP_API_KEY")

def get_json(path, query = {})
  uri = URI("#{BASE}/#{path}")
  uri.query = URI.encode_www_form(query) unless query.empty?
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{KEY}"
  response = Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
  unless response.code == "200"
    warn "Read-only endpoint #{path}: HTTP #{response.code}"
    detail = JSON.parse(response.body.gsub(KEY, "[REDACTED]")) rescue {}
    warn JSON.generate(detail.slice("errorCode", "message"))
    raise "API request failed"
  end

  JSON.parse(response.body.gsub(KEY, "[REDACTED]"))
end

def save(name, value)
  File.write(File.join(ROOT, name), JSON.pretty_generate(value) + "\n")
end

begin
  master = JSON.parse(File.read(File.join(ROOT, "..", "master-rp-capture.json")))
  index = []
  LAUNCHES.each do |id|
    launch = get_json("launch/#{id}")
    save("launch-#{id}.json", launch)
    next unless UI_LAUNCHES.include?(id)

    items = master.find { |entry| entry.dig("launch", "id") == id }.fetch("items")
    save("items-#{id}.json", items)
    items.reject { |item| item["hasStats"] || item["type"] == "SUITE" }.each do |item|
      page = 1
      logs = []
      loop do
        result = get_json("log", "filter.eq.item" => item.fetch("id"), "page.page" => page, "page.size" => 200)
        logs.concat(result.fetch("content"))
        break if page >= result.fetch("page").fetch("totalPages")
        page += 1
      end
      logs.sort_by! { |log| [log["time"], log["id"]] }
      save("logs-item-#{item['id']}.json", logs)
      index << {launch: id, item: item["id"], name: item["name"], status: item["status"], path: item["path"],
                logs: logs.map { |log| log.slice("id", "level", "itemId", "binaryContent") }}
    end
  end
  save("api-evidence-index.json", {captured_at: Time.now.utc.iso8601, runtime_sha_supplied: "9bf3356cff350d8e2ba11bad1c33aa89881ac456", items_source: "master-rp-capture.json; logs freshly fetched per item", index: index})
  puts "Read-only capture complete: #{LAUNCHES.length} launch summaries and #{index.length} UI item log sets."
rescue StandardError => error
  warn "Read-only capture failed (#{error.class}); credential-bearing exception detail withheld."
  exit 1
end
