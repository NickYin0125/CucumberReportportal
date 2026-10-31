# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "digest"
require "time"

stamp = ARGV.fetch(0)
abort "Secure RP_API_KEY environment required" if ENV["RP_API_KEY"].to_s.empty?
abort "Invalid QA run stamp" unless stamp.match?(/\A[0-9A-Za-z-]+\z/)
base = "http://rp-2607.localhost:18080/api/v1/superadmin_personal/"
transient_file = "/Users/nick/Documents/crr-qa-2.0.1/docs/reviews/assets/ledger-qa-read-api-transients-#{stamp}.ndjson"
audit_error = Class.new(StandardError)
get = lambda do |path|
  attempt = 0
  begin
    attempt += 1
    uri = URI(base + path)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{ENV.fetch('RP_API_KEY')}"
    response = Net::HTTP.start(uri.hostname, uri.port, nil, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
    raise audit_error, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue Net::OpenTimeout, Net::ReadTimeout, EOFError, IOError, SystemCallError, SocketError, audit_error => error
    retryable = !response || [408, 429, 500, 502, 503, 504].include?(response.code.to_i)
    record = { at: Time.now.utc.iso8601, method: "GET", path: path, attempt: attempt,
               error_class: error.class.name, http_status: response && response.code.to_i,
               retrying: retryable && attempt < 3 }
    File.open(transient_file, "a") { |file| file.puts(JSON.generate(record)) }
    if record[:retrying]
      sleep(0.25 * attempt)
      response = nil
      retry
    end
    raise audit_error, "Read incomplete after #{attempt} attempt(s)"
  end
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
incomplete = false
%w[2.0.1 1.3.2].each do |version|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  results = []
  aggregate = File.join(root, "docs/reviews/assets/ledger-qa-read-api-audit-#{stamp}.json")
  Dir[File.join(root, "docs/reviews/assets/ledger-qa-live/#{stamp}-*/**/snapshot.json")].sort.each do |path|
    snapshot = JSON.parse(File.read(path))
    snapshot.fetch("launches", []).each do |reference|
      destination = File.join(File.dirname(path), "read-api-audit.json")
      if File.file?(destination)
        prior = JSON.parse(File.read(destination))
        item_ids = snapshot.fetch("items").map { |item| item["id"] }.sort
        log_ids = snapshot.fetch("logs").map { |log| log["id"] }.sort
        reusable = prior["launch_id"] == reference["id"] && prior["source_snapshot"] == path &&
          prior["full_item_ids"] == item_ids && prior["full_log_ids"] == log_ids &&
          prior.fetch("filters", []).map { |filter| filter["item_id"] }.sort == item_ids
        if reusable
          results << { launch_id: prior["launch_id"], audit_file: destination,
            items_complete: true, logs_complete: true, prefix_hits: prior.fetch("prefix_logs").length,
            secret_hits: prior.fetch("secret_logs").length, metadata_secret: prior["metadata_secret"],
            resumed_completed_audit: true, original_file_mtime: File.mtime(destination).utc.iso8601 }
          File.write(aggregate, JSON.pretty_generate(results) + "\n")
          puts "READ_AUDIT_RESUME launch=#{reference['id']}"
          next
        end
      end
      begin
      launch = get.call("launch/#{reference.fetch('id')}")
      abort "Unowned Launch in audit input" unless launch.fetch("name").start_with?("ledger-developer-independent-QA-") && launch["name"].include?(stamp)
      items = pages.call("item?filter.eq.launchId=#{launch.fetch('id')}")
      abort "Cross-Launch item query" unless items.all? { |item| item["launchId"] == launch["id"] }
      filters = items.map do |item|
        id = item.fetch("id")
        prefix = get.call("log?filter.eq.item=#{id}&filter.cnt.message=%21%21%21MARKDOWN_MODE%21%21%21&page.size=1")
        secret = get.call("log?filter.eq.item=#{id}&filter.cnt.message=SECRET123&page.size=1")
        { item_id: id, prefix_hits: prefix.dig("page", "totalElements"), secret_hits: secret.dig("page", "totalElements") }
      end
      logs = (items.flat_map { |item| pages.call("log?filter.eq.item=#{item.fetch('id')}") } +
              pages.call("log?filter.eq.launch=#{launch.fetch('id')}")).uniq { |log| log.fetch("id") }
      value = { launch_id: launch["id"], observed_at: Time.now.utc.iso8601, source_snapshot: path,
                snapshot_sha256: Digest::SHA256.file(path).hexdigest, full_item_ids: items.map { |i| i["id"] }.sort,
                snapshot_item_ids: snapshot.fetch("items").map { |i| i["id"] }.sort, filters: filters,
                full_log_ids: logs.map { |l| l["id"] }.sort, snapshot_log_ids: snapshot.fetch("logs").map { |l| l["id"] }.sort,
                prefix_logs: logs.select { |l| l["message"].include?("!!!MARKDOWN_MODE!!!") },
                secret_logs: logs.select { |l| l["message"].include?("SECRET123") },
                metadata_secret: JSON.generate(items + [launch.slice("attributes", "description", "name")]).include?("SECRET123"),
                log_digests: logs.map { |l| { log_id: l["id"], item_id: l["itemId"], level: l["level"], message_sha256: Digest::SHA256.hexdigest(l["message"]) } } }
      serialized = JSON.pretty_generate(value) + "\n"
      abort "Refusing credential-bearing audit artifact" if serialized.include?(ENV.fetch("RP_API_KEY"))
      File.write(destination, serialized)
      puts "READ_AUDIT launch=#{launch['id']} items=#{items.length} logs=#{logs.length} prefix=#{value[:prefix_logs].length} secret=#{value[:secret_logs].length}"
      results << { launch_id: launch["id"], audit_file: destination, items_complete: value[:full_item_ids] == value[:snapshot_item_ids],
        logs_complete: value[:full_log_ids] == value[:snapshot_log_ids], prefix_hits: value[:prefix_logs].length,
        secret_hits: value[:secret_logs].length, metadata_secret: value[:metadata_secret] }
      rescue audit_error => error
        incomplete = true
        value = { launch_id: reference["id"], source_snapshot: path, observed_at: Time.now.utc.iso8601,
                  status: "INCOMPLETE", error_class: error.class.name,
                  reason: "A required GET failed after bounded retries; no zero-hit inference is valid." }
        File.write(File.join(File.dirname(path), "read-api-audit-error.json"), JSON.pretty_generate(value) + "\n")
        results << value
        puts "READ_AUDIT_INCOMPLETE launch=#{reference['id']}"
      end
      File.write(aggregate, JSON.pretty_generate(results) + "\n")
    end
  end
end
abort "Read audit incomplete; preserve errors and re-run to resume" if incomplete
