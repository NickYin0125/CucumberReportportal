# frozen_string_literal: true

require "net/http"
require "json"
require "time"

OUT = File.expand_path(__dir__)
BASE = "http://rp-2607.localhost:18080/api/v1/superadmin_personal"
KEY = ENV.fetch("RP_API_KEY")
ALLOWED = [3847, 3849, 3850, 3851, 3852].freeze

def get_json(path, query = {})
  uri = URI("#{BASE}/#{path}")
  uri.query = URI.encode_www_form(query) unless query.empty?
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{KEY}"
  response = Net::HTTP.start(uri.host, uri.port, nil, open_timeout: 5, read_timeout: 30) { |http| http.request(request) }
  raise "RP GET failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

def collection(path, query)
  records = []
  pages = []
  number = 1
  loop do
    page = get_json(path, query.merge("page.page" => number, "page.size" => 300))
    pages << page
    records.concat(page.fetch("content"))
    break if number >= page.fetch("page").fetch("totalPages")
    number += 1
  end
  [records, pages]
end

ARGV.map(&:to_i).each do |id|
  raise "Launch outside review allowlist" unless ALLOWED.include?(id)
  launch = get_json("launch/#{id}")
  items, pages = collection("item", "filter.eq.launchId" => id)
  File.write(File.join(OUT, "launch-#{id}.json"), JSON.pretty_generate(launch))
  File.write(File.join(OUT, "items-#{id}.json"), JSON.pretty_generate(pages))
  all_logs = []
  items.each do |item|
    logs, log_pages = collection("log", "filter.eq.item" => item.fetch("id"))
    File.write(File.join(OUT, "logs-#{item.fetch('id')}.json"), JSON.pretty_generate(log_pages))
    all_logs.concat(logs)
  end
  receipt = {captured_at: Time.now.utc.iso8601, launch_id: id, item_count: items.size,
             log_count: all_logs.size, method: "GET; logs queried by item, not launch", launch_status: launch["status"]}
  File.write(File.join(OUT, "capture-#{id}.json"), JSON.pretty_generate(receipt))
  puts receipt.to_json
end
