# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "digest"
require "time"

abort "Master must inject RP_API_KEY securely" if ENV["RP_API_KEY"].to_s.empty?
root = "/Users/nick/Documents/crr-qa-1.3.2"
stamp = ARGV.fetch(0, "20261031T072147Z")
abort "Invalid stamp" unless stamp.match?(/\A[0-9A-Za-z-]+\z/)
request = lambda do |path|
  uri = URI("http://rp-2607.localhost:18080/api/v1/#{path}")
  req = Net::HTTP::Get.new(uri)
  req["Authorization"] = "Bearer #{ENV.fetch('RP_API_KEY')}"
  response = Net::HTTP.start(uri.hostname, uri.port, nil, open_timeout: 5, read_timeout: 30) { |http| http.request(req) }
  abort "Read-only NUL audit failed HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  response
end
pages = lambda do |path|
  rows, page = [], 1
  loop do
    response = request.call("superadmin_personal/#{path}&page.size=100&page.page=#{page}")
    data = JSON.parse(response.body)
    rows.concat(data.fetch("content"))
    break if page >= data.fetch("page").fetch("totalPages")
    page += 1
  end
  rows
end
results = %w[baseline plain-1 plain-2 rich-1 rich-2].flat_map do |mode|
  %w[F08 F09].map do |fixture|
    dir = File.join(root, "docs/reviews/assets/ledger-qa-live/#{stamp}-#{mode}/#{fixture}")
    snapshot = JSON.parse(File.read(File.join(dir, "snapshot.json")))
    wire = JSON.parse(File.read(File.join(dir, "wire.json")))
    process = JSON.parse(File.read(File.join(dir, "process.json")))
    environment = JSON.parse(File.read(File.join(dir, "environment.json")))
    guard = JSON.parse(File.read(File.join(dir, "source-guard.json")))
    launch = snapshot.fetch("launches").first
    abort "Unowned Launch" unless launch.fetch("name").start_with?("ledger-developer-independent-QA-") && launch.fetch("name").include?(stamp)
    logs = snapshot.fetch("items").flat_map do |item|
      pages.call("log?filter.eq.item=#{item.fetch('id')}")
    end
    files = logs.filter_map do |log|
      binary = log["binaryContent"]
      next unless binary
      response = request.call("data/superadmin_personal/#{binary.fetch('id')}")
      { log_id: log["id"], item_id: log["itemId"], binary: binary,
        content_type: response["content-type"], content_disposition: response["content-disposition"],
        bytes: response.body.bytesize, sha256: Digest::SHA256.hexdigest(response.body) }
    end
    submissions = wire.select { |entry| entry["method"] == "POST" && entry["path"].end_with?("/log") }.map do |entry|
      emitted = entry["entries"] || entry["json"]
      { http_status: entry["status"], response: entry["response"],
        files: entry.fetch("files", []).map { |file| file.slice("name", "mime", "bytes", "sha256") },
        messages: Array(emitted).map do |log|
          item = snapshot.fetch("items").find { |i| i["uuid"] == log["itemUuid"] }
          message = log.fetch("message")
          { item_id: item && item["id"], item_name: item && item["name"],
            bytes: message.bytesize, sha256: Digest::SHA256.hexdigest(message),
            raw_nul: message.include?("\0"), escaped_nul: message.include?("\\u0000"),
            full_message: message }
        end }
    end
    spool = environment["RP_SPOOL_DIR"]
    spool_files = spool && Dir[File.join(spool, "**", "*")].select { |path| File.file?(path) }
    { fixture: fixture, mode: mode, observed_at: Time.now.utc.iso8601,
      launch_id: launch["id"], source_guard: guard, initial_snapshot: dir.delete_prefix(root + "/") + "/snapshot.json",
      submitted_logs: submissions.sum { |entry| entry[:messages].length },
      submitted_files: submissions.flat_map { |entry| entry[:files] }, submissions: submissions,
      initial_log_ids: snapshot.fetch("logs").map { |log| log["id"] }.sort,
      delayed_log_ids: logs.map { |log| log["id"] }.sort, delayed_logs: logs, delayed_files: files,
      child_exit: process["exit"], stdout: process["stdout"], stderr: process["stderr"],
      spool_directory: spool, spool_files: spool_files,
      reason_scope: "POST responses were HTTP acceptance acknowledgements. A successful empty per-item GET is absence, not an API reject reason. No server error cause is inferred from absence alone." }
  end
end
destination = File.join(root, "docs/reviews/assets/ledger-qa-nul-delayed-#{stamp}.json")
serialized = JSON.pretty_generate(results) + "\n"
abort "Refusing credential-bearing artifact" if serialized.include?(ENV.fetch("RP_API_KEY"))
File.write(destination, serialized)
results.each do |result|
  puts JSON.generate(result.slice(:fixture, :mode, :launch_id, :submitted_logs, :child_exit).merge(
    delayed_logs: result[:delayed_log_ids].length, delayed_files: result[:delayed_files].length,
    http_statuses: result[:submissions].map { |entry| entry[:http_status] }.uniq))
end
puts "NUL_AUDIT=#{destination}"
