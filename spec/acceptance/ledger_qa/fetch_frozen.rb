# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "digest"
require "fileutils"

abort "Master must inject RP_API_KEY; this tool only performs GET requests" if ENV["RP_API_KEY"].to_s.empty?
endpoint = "http://rp-2607.localhost:18080"
project = "superadmin_personal"
get = lambda do |path|
  uri = URI("#{endpoint}/api/v1/#{project}/#{path}")
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{ENV.fetch('RP_API_KEY')}"
  response = Net::HTTP.start(uri.hostname, uri.port, nil, open_timeout: 5, read_timeout: 20) { |http| http.request(request) }
  abort "Frozen input GET failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end
pages = lambda do |path|
  rows, page = [], 1
  loop do
    result = get.call("#{path}&page.size=100&page.page=#{page}")
    rows.concat(result.fetch("content"))
    break if page >= result.fetch("page").fetch("totalPages")
    page += 1
  end
  rows
end
items = pages.call("item?filter.eq.launchId=76")
abort "Historical item query did not remain inside Launch 76" unless items.any? && items.all? { |item| item["launchId"] == 76 }
rows = items.flat_map { |item| pages.call("log?filter.eq.item=#{item.fetch('id')}") }.uniq { |log| log.fetch("id") }
matches = rows.select { |l| l["message"].to_s.include?("INDEPENDENT_FULL_BACKTRACE") }
abort "Expected exactly one original F04 marker log; observed #{matches.length}" unless matches.length == 1
log = matches.first
message = log.fetch("message")
title, tail = message.split("\n", 2)
sha = Digest::SHA256.hexdigest(tail)
abort "Frozen input differs from the independent raw-DOM capture" unless sha == "3fd9692c6e95a2e7e1868111ad41fd5f2584f95098c67d18ccc9756d66eca75d" && tail.lines.length == 62 && message.bytesize == 10_086
abort "Refusing to persist any credential" if message.include?(ENV.fetch("RP_API_KEY"))
value = { source_launch_id: 76, source_item_id: log["itemId"], source_log_id: log["id"], source_level: log["level"],
          source_api: "#{endpoint}/api/v1/#{project}/log?filter.eq.item=#{log['itemId']}", source_api_verified: true,
          capture_method: "Read API, independently matched to owner-signed-in raw DOM textContent",
          exception_class: "RuntimeError", error_message: title, raw_message: message, backtrace: tail,
          frame_count: 62, raw_bytes: message.bytesize, raw_sha256: Digest::SHA256.hexdigest(message), backtrace_sha256: sha }
%w[2.0.1 1.3.2].each do |version|
  path = "/Users/nick/Documents/crr-qa-#{version}/docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json"
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, JSON.pretty_generate(value) + "\n")
end
puts JSON.generate(value.reject { |key, _| %i[raw_message backtrace].include?(key) })
