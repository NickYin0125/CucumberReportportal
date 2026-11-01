# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "digest"
require "fileutils"
require "securerandom"
require_relative "final_wp5_context"

abort "Master must inject RP_API_KEY through environment only" if ENV["RP_API_KEY"].to_s.empty?
stamp = LedgerWP5Context.stamp
attempt = ENV.fetch("QA_CONSOLE_ATTEMPT", "attempt2")
raise "Invalid replay attempt" unless attempt.match?(/\A[a-zA-Z0-9-]+\z/)
level = lambda do |raw|
  normalized = raw.to_s.upcase
  raise "Unknown RP severity" unless %w[TRACE DEBUG INFO WARN ERROR FATAL].include?(normalized)
  normalized
end
base = "http://rp-2607.localhost:18080/api/v1/superadmin_personal/"
%w[12.0.1 9.2.1 10.2.0].each do |cucumber|
  version = cucumber == "12.0.1" ? "2.0.1" : "1.3.2"
  root = "/Users/nick/Documents/crr-qa-#{version}"
  plan = JSON.parse(File.read(File.join(root, "docs/reviews/assets/#{stamp}/screenshot-plan.json")))
  source = plan.fetch("rows").find { |row| row["shot"] == "S12" && row["fixture"] == "F04-frozen" && row["cucumber"] == cucumber }
  raise "Missing source plan" unless source
  original_path = File.join(root, source.fetch("source_snapshot"))
  original = JSON.parse(File.read(original_path))
  log = original.fetch("logs").find { |row| row["id"] == source.fetch("log_ids").first }
  raise "Wrong source log" unless log && log["level"] == "error" && log.fetch("message").start_with?("## ")
  output = File.join(root, "docs/reviews/assets/ledger-qa-live/#{stamp}-console-flat-#{attempt}-c#{cucumber}/F04-frozen")
  raise "Preserve earlier replay" if File.exist?(output)
  FileUtils.mkdir_p(output)
  records = []
  owned_launch = owned_item = nil
  launch_name = "ledger-independent-QA-#{stamp}-Decision17-Console-c#{cucumber}"
  item_name = "S12 flat F04 Console-only replay"
  completed = item_finished = launch_finished = false
  write = lambda do |name, value|
    bytes = JSON.pretty_generate(value) + "\n"
    raise "Refusing credential-bearing evidence" if bytes.include?(ENV.fetch("RP_API_KEY"))
    File.write(File.join(output, name), bytes, perm: 0o600)
  end
  request = lambda do |method, path, payload = nil|
    allowed = method == "GET" || (method == "POST" && path == "launch" && payload["rerun"] == false) ||
      (method == "POST" && path == "item" && payload["launchUuid"] == owned_launch) ||
      (method == "POST" && path == "log" && payload["launchUuid"] == owned_launch && payload["itemUuid"] == owned_item) ||
      (method == "PUT" && path == "item/#{owned_item}" && payload["launchUuid"] == owned_launch) ||
      (method == "PUT" && path == "launch/#{owned_launch}/finish")
    raise "Unowned mutation blocked" unless allowed
    uri = URI(base + path)
    req = Net::HTTP.const_get(method.capitalize).new(uri)
    req["Authorization"] = "Bearer #{ENV.fetch('RP_API_KEY')}"
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(payload) if payload
    response = Net::HTTP.start(uri.hostname, uri.port, nil, open_timeout: 10, read_timeout: 30) { |http| http.request(req) }
    parsed = JSON.parse(response.body)
    records << { method: method, path: path, payload: payload, status: response.code.to_i, response: parsed }
    write.call("protocol.json", records)
    raise "RP protocol rejected HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    parsed
  end
  begin
  persisted_source = request.call("GET", "log/#{log.fetch('id')}")
  source_comparison = { exact_message_bytes: persisted_source.fetch("message").b == log.fetch("message").b,
    exact_item_id: persisted_source["itemId"] == log["itemId"], snapshot_level: log["level"], direct_get_level: persisted_source["level"],
    canonical_levels: [level.call(log["level"]), level.call(persisted_source["level"])],
    snapshot_message_sha256: Digest::SHA256.hexdigest(log.fetch("message")), direct_get_message_sha256: Digest::SHA256.hexdigest(persisted_source.fetch("message")),
    scope: "RP list and direct GET severity casing is canonicalized explicitly; no message byte or item identity normalization." }
  write.call("source-comparison.json", source_comparison)
  raise "Original source changed" unless source_comparison[:exact_message_bytes] && source_comparison[:exact_item_id] && source_comparison[:canonical_levels].uniq.length == 1
  start = (Time.now.to_f * 1000).to_i.to_s
  owned_launch = SecureRandom.uuid
  created_launch = request.call("POST", "launch", { "name" => launch_name, "uuid" => owned_launch,
    "startTime" => start, "mode" => "DEFAULT", "rerun" => false,
    "description" => "Decision17: exact F04 message flat replay for Console rendering only. Original runtime/topology remains unchanged." }).fetch("id")
  raise "Launch UUID not preserved" unless created_launch == owned_launch
  owned_item = SecureRandom.uuid
  created_item = request.call("POST", "item", { "name" => item_name, "type" => "STEP", "hasStats" => true,
    "startTime" => start, "launchUuid" => owned_launch, "uuid" => owned_item }).fetch("id")
  raise "Item UUID not preserved" unless created_item == owned_item
  request.call("POST", "log", { "launchUuid" => owned_launch, "itemUuid" => owned_item, "time" => start,
    "level" => persisted_source.fetch("level"), "message" => log.fetch("message") })
  finish = (Time.now.to_f * 1000).to_i.to_s
  request.call("PUT", "item/#{owned_item}", { "launchUuid" => owned_launch, "endTime" => finish, "status" => "FAILED" })
  item_finished = true
  request.call("PUT", "launch/#{owned_launch}/finish", { "endTime" => finish, "status" => "FAILED" })
  launch_finished = true
  launch = request.call("GET", "launch/uuid/#{owned_launch}")
  item = request.call("GET", "item/uuid/#{owned_item}")
  copies = request.call("GET", "log?filter.eq.item=#{item.fetch('id')}&page.size=100").fetch("content")
  raise "Replay not exact" unless copies.length == 1 && copies.first.fetch("message").b == log.fetch("message").b &&
    level.call(copies.first["level"]) == level.call(persisted_source["level"]) && copies.first["itemId"] == item.fetch("id")
  write.call("snapshot.json", { persistence: "live_readback", launches: [launch], items: [item], logs: copies, files: [] })
  mapping = { decision: 17, owner_exact_answer: "允许补充平铺回放（推荐）", cucumber: cucumber, runtime_sha: LedgerWP5Context.heads.fetch(version),
    source_snapshot: source.fetch("source_snapshot"), source_snapshot_sha256: Digest::SHA256.file(original_path).hexdigest,
    source_launch_id: source.fetch("launch_id"), source_item_id: log.fetch("itemId"), source_log_id: log.fetch("id"),
    source_message_sha256: Digest::SHA256.hexdigest(log.fetch("message")), source_message_bytes: log.fetch("message").bytesize,
    snapshot_level: log.fetch("level"), source_direct_get_level: persisted_source.fetch("level"), posted_level: persisted_source.fetch("level"),
    supplemental_list_level: copies.first.fetch("level"), level: level.call(persisted_source["level"]), attempt: attempt,
    supplemental_launch_id: launch.fetch("id"), supplemental_item_id: item.fetch("id"), supplemental_log_id: copies.first.fetch("id"),
    supplemental_message_sha256: Digest::SHA256.hexdigest(copies.first.fetch("message")), exact_message_and_level: true,
    supplemental_snapshot: File.join(output, "snapshot.json").delete_prefix(root + "/"),
    ui_url: "http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/#{launch.fetch('id')}/#{item.fetch('id')}/log",
    scope: "Console renderer only; not a Cucumber execution, SDK runtime retest, topology proof, replacement failure or original Launch modification." }
  write.call("mapping.json", mapping)
  completed = true
  puts JSON.generate(cucumber: cucumber, launch: launch.fetch("id"), item: item.fetch("id"), log: copies.first.fetch("id"),
    message_sha256: mapping[:source_message_sha256], mapping: File.join(output, "mapping.json"))
  $stdout.flush
  rescue StandardError => error
    write.call("failure.json", { verdict: "BLOCKED", error_class: error.class.name, last_protocol_stage: records.last && records.last.slice(:method, :path, :status),
      source_log_id: log.fetch("id"), original_mutated_by_replay: false, message: "Replay failed; original Launch is read-only. See key-free protocol and bounded cleanup records." })
    raise
  ensure
    unless completed
      cleanup = []
      begin
        # Client-generated UUIDs allow a read-only ownership check even after an ambiguous POST response.
        launch_check = owned_launch && request.call("GET", "launch/uuid/#{owned_launch}")
        if launch_check && launch_check["name"] == launch_name
          if owned_item && !item_finished
            begin
              item_check = request.call("GET", "item/uuid/#{owned_item}")
              if item_check["name"] == item_name && item_check["launchId"] == launch_check["id"]
                request.call("PUT", "item/#{owned_item}", { "launchUuid" => owned_launch, "endTime" => (Time.now.to_f * 1000).to_i.to_s, "status" => "INTERRUPTED" })
                cleanup << { node: "item", uuid: owned_item, closed: true }
              end
            rescue StandardError => cleanup_error
              cleanup << { node: "item", uuid: owned_item, closed: false, error_class: cleanup_error.class.name }
            end
          end
          unless launch_finished
            request.call("PUT", "launch/#{owned_launch}/finish", { "endTime" => (Time.now.to_f * 1000).to_i.to_s, "status" => "INTERRUPTED" })
            cleanup << { node: "launch", uuid: owned_launch, closed: true }
          end
        end
      rescue StandardError => cleanup_error
        cleanup << { node: "launch", uuid: owned_launch, closed: false, error_class: cleanup_error.class.name }
      end
      write.call("failure-cleanup.json", { bounded: "At most one ownership GET and one closing PUT per newly created node; no retries or existing Launch writes.",
        records: cleanup, incomplete_cleanup: cleanup.any? { |row| row[:closed] == false } })
    end
  end
end
