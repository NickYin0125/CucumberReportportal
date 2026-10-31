# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "digest"
require "time"
require "fileutils"

stamp = ARGV.fetch(0)
abort "Invalid capture stamp" unless stamp.match?(/\A[0-9A-Za-z-]+\z/)
revision = ARGV[1]
abort "Invalid output revision" if revision && !revision.match?(/\A[0-9A-Za-z-]+\z/)
abort "Master must securely inject RP_API_KEY" if ENV["RP_API_KEY"].to_s.empty?
base = "http://rp-2607.localhost:18080/api/v1/superadmin_personal/"
failures = []
%w[2.0.1 1.3.2].each do |version|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  destination = File.join(root, "docs/reviews/assets/ledger-qa-retry-read-#{stamp}#{revision ? "-#{revision}" : ''}")
  abort "Immutable retry supplement already exists; choose a new explicit output scheme rather than overwrite" if File.exist?(destination)
  FileUtils.mkdir_p(destination)
  get = lambda do |path|
    attempt = 0
    begin
      attempt += 1
      uri = URI(base + path)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{ENV.fetch('RP_API_KEY')}"
      response = Net::HTTP.start(uri.hostname, uri.port, nil, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
      raise IOError, "Required read failed" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout, EOFError, IOError, SystemCallError, SocketError => error
      retryable = !response || [408, 429, 500, 502, 503, 504].include?(response.code.to_i)
      transient = { at: Time.now.utc.iso8601, path: path, method: "GET", attempt: attempt,
        error_class: error.class.name, status: response&.code&.to_i, retrying: retryable && attempt < 3 }
      File.open(File.join(destination, "transients.ndjson"), "a") { |file| file.puts(JSON.generate(transient)) }
      if transient[:retrying]
        sleep(0.25 * attempt)
        response = nil
        retry
      end
      raise IOError, "Required GET incomplete after bounded retries"
    end
  end
  pages = lambda do |path|
    results, number = [], 1
    loop do
      page = get.call("#{path}&page.size=100&page.page=#{number}")
      results << page
      break if number >= page.fetch("page").fetch("totalPages")
      number += 1
    end
    results
  end
  aggregate = JSON.parse(File.read(File.join(root, "docs/reviews/assets/ledger-qa-read-api-audit-#{stamp}.json")))
  aggregate.reject { |row| row["items_complete"] && row["logs_complete"] }.each do |reference|
    id = reference.fetch("launch_id")
    begin
      original = JSON.parse(File.read(reference.fetch("audit_file")))
      snapshot_path = original.fetch("source_snapshot")
      snapshot = JSON.parse(File.read(snapshot_path))
      launch = get.call("launch/#{id}")
      raise "Unowned launch" unless launch.fetch("name").start_with?("ledger-developer-independent-QA-") && launch["name"].include?(stamp)
      page_data = pages.call("item?filter.eq.launchId=#{id}")
      visible = page_data.flat_map { |page| page.fetch("content") }
      expected = snapshot.fetch("items").to_h { |item| [item.fetch("id"), item] }
      missing = expected.keys - visible.map { |item| item.fetch("id") }
      embedded = []
      walk = lambda do |item, container|
        Array(item["retries"]).each do |retry_item|
          embedded << { "container_id" => container, "retry" => retry_item }
          walk.call(retry_item, container)
        end
      end
      visible.each { |item| walk.call(item, item.fetch("id")) }
      direct, validations = [], []
      missing.each do |missing_id|
        row = get.call("item/#{missing_id}")
        direct << row
        origin = expected.fetch(missing_id)
        containers = embedded.select { |entry| entry.dig("retry", "id") == missing_id }
        latest = visible.find { |item| item["id"] == containers.first&.fetch("container_id") }
        chain, cursor, seen = [], row, []
        loop do
          raise "Cyclic parent lineage" if seen.include?(cursor.fetch("id"))
          seen << cursor.fetch("id")
          chain << cursor
          break unless cursor["parent"]
          cursor = get.call("item/#{cursor.fetch('parent')}")
        end
        lineage = chain.last
        filters = { "prefix" => get.call("log?filter.eq.item=#{missing_id}&filter.cnt.message=%21%21%21MARKDOWN_MODE%21%21%21&page.size=1"),
          "secret" => get.call("log?filter.eq.item=#{missing_id}&filter.cnt.message=SECRET123&page.size=1") }
        logs = pages.call("log?filter.eq.item=#{missing_id}").flat_map { |page| page.fetch("content") }
        ok = containers.length == 1 && row["id"] == missing_id && row["uuid"] == origin["uuid"] && row["parent"] == origin["parent"] &&
          row["status"] == origin["status"] && row["status"] != "IN_PROGRESS" && row["type"] == origin["type"] && row["hasStats"] == origin["hasStats"] &&
          lineage["launchId"] == id && lineage["type"] == "SUITE" && latest && latest["parent"] == row["parent"] &&
          %w[testCaseId codeRef].all? { |field| latest[field] == row[field] } &&
          filters.values.all? { |value| value.dig("page", "totalElements") == 0 } &&
          !JSON.generate(row).include?("SECRET123") && logs.none? { |log| log["message"].match?(/SECRET123|!!!MARKDOWN_MODE!!!/) }
        validations << { id: missing_id, embedded_containers: containers, direct_item: row, parent_lineage: chain,
          per_item_filter_responses: filters, per_item_logs: logs, expected_snapshot_item: origin, verdict: ok ? "PASS" : "FAIL" }
      end
      expanded_ids = (visible + direct).map { |item| item.fetch("id") }.uniq.sort
      expanded_logs = (original.fetch("full_log_ids") + validations.flat_map { |row| row[:per_item_logs].map { |log| log["id"] } }).uniq.sort
      value = { schema: "immutable-retry-read-supplement/1", launch_id: id, observed_at: Time.now.utc.iso8601,
        original_audit: reference["audit_file"].delete_prefix(root + "/"), original_audit_sha256: Digest::SHA256.file(reference["audit_file"]).hexdigest,
        source_snapshot: snapshot_path.delete_prefix(root + "/"), source_snapshot_sha256: Digest::SHA256.file(snapshot_path).hexdigest,
        launch: launch, raw_item_pages_with_actual_retry_nesting: page_data, discovered_missing_ids: missing, validations: validations,
        expanded_item_ids: expanded_ids, expected_snapshot_item_ids: expected.keys.sort,
        expanded_log_ids: expanded_logs, expected_snapshot_log_ids: snapshot.fetch("logs").map { |log| log["id"] }.sort,
        note: "Original audit mismatch is preserved, not overwritten. Missing first-attempt scenarios must be discovered inside actual retry arrays and directly read with verified UUID/parent/Suite-Launch lineage and per-item scans." }
      passed = !missing.empty? && validations.all? { |row| row[:verdict] == "PASS" } && expanded_ids == expected.keys.sort && expanded_logs == value[:expected_snapshot_log_ids]
      value[:verdict] = passed ? "PASS" : "FAIL"
      serialized = JSON.pretty_generate(value) + "\n"
      abort "Refusing credential-bearing evidence" if serialized.include?(ENV.fetch("RP_API_KEY"))
      File.write(File.join(destination, "launch-#{id}.json"), serialized)
      failures << [version, id] unless passed
      puts JSON.generate(version: version, launch: id, missing_attempts: missing.length, expanded_items: expanded_ids.length, verdict: value[:verdict])
    rescue StandardError => error
      File.write(File.join(destination, "launch-#{id}-incomplete.json"), JSON.pretty_generate(launch_id: id, status: "INCOMPLETE", error_class: error.class.name) + "\n")
      failures << [version, id]
      puts JSON.generate(version: version, launch: id, status: "INCOMPLETE", error_class: error.class.name)
    end
  end
end
abort "Retry supplement has unresolved failures/incomplete reads" unless failures.empty?
