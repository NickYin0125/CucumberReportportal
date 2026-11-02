# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "digest"

base = "http://rp-2607.localhost:18080/api/v1/superadmin_personal/"
get = lambda do |path|
  uri = URI(base + path)
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{ENV.fetch('RP_API_KEY')}"
  response = Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
  abort "RP read failed: #{response.code}" unless response.code == "200"
  JSON.parse(response.body)
end
pages = lambda do |path|
  rows = []
  page = 1
  loop do
    body = get.call("#{path}#{path.include?('?') ? '&' : '?'}page.size=300&page.page=#{page}")
    rows.concat(body.fetch("content"))
    break if page >= body.fetch("page").fetch("totalPages")
    page += 1
  end
  rows
end
launches = pages.call("launch?filter.cnt.name=Trial%202.0.2").sort_by { |launch| launch.fetch("id") }
data = launches.map do |launch|
  id = launch.fetch("id")
  items = pages.call("item?filter.eq.launchId=#{id}")
  logs = if [3847, 3848, 3849, 3850, 3851, 3852].include?(id)
           items.flat_map { |item| pages.call("log?filter.eq.item=#{item.fetch('id')}") }.uniq { |log| log.fetch("id") }
         else
           []
         end
  {launch: launch, items: items, logs: logs}
end
path = File.join(__dir__, "master-rp-capture.json")
File.write(path, JSON.pretty_generate(data) + "\n")
puts JSON.pretty_generate(data.map do |row|
  launch = row.fetch(:launch)
  {id: launch["id"], name: launch["name"], status: launch["status"], attributes: launch["attributes"],
   statistics: launch["statistics"], items: row[:items].length, logs: row[:logs].length}
end)
