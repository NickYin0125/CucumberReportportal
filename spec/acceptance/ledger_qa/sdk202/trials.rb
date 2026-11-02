# frozen_string_literal: true

require_relative "host"
require "net/http"
require "uri"

module Ledger202Trials
  IDS = [3847, 3848, 3849, 3850, 3851, 3852].freeze
  SEED = "/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/master-rp-capture.json"

  def self.get(path, binary: false)
    uri = URI("http://rp-2607.localhost:18080/api/v1/#{path}")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{ENV.fetch('RP_API_KEY')}"
    response = Net::HTTP.start(uri.hostname, uri.port, nil, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
    raise "Read API HTTP #{response.code}" unless response.code.to_i == 200
    binary ? [response.body.b, response["content-type"]] : JSON.parse(response.body)
  end

  def self.pages(path)
    page, rows = 1, []
    loop do
      data = get("superadmin_personal/#{path}&page.size=100&page.page=#{page}")
      rows.concat(data.fetch("content"))
      break if page >= data.fetch("page").fetch("totalPages")
      page += 1
    end
    rows
  end

  def self.run
    directory = File.join(Ledger202Host::OUTPUT, "trial-readback")
    raise "Never overwrite readback" if File.exist?(directory)
    seed = JSON.parse(File.read(SEED))
    IDS.each do |id|
      supplied = seed.find { |r| r.dig("launch", "id") == id }
      raise "Final comparable missing from supplied inventory" unless supplied
      launch = get("superadmin_personal/launch/#{id}")
      # Launch-scoped logs are deliberately not used as an absence test.
      items = supplied.fetch("items").map { |item| get("superadmin_personal/item/#{item.fetch('id')}") }
      raise "Wrong Launch membership" if items.any? { |i| i["launchId"] && i["launchId"] != id }
      logs = items.flat_map { |item| pages("log?filter.eq.item=#{item.fetch('id')}") }.uniq { |log| log.fetch("id") }
      files = logs.filter_map do |log|
        next unless log["binaryContent"]
        bytes, type = get("data/superadmin_personal/#{log.fetch('binaryContent').fetch('id')}", binary: true)
        { log_id: log["id"], item_id: log["itemId"], content_type: type, bytes: bytes.bytesize,
          sha256: Digest::SHA256.hexdigest(bytes), base64: Base64.strict_encode64(bytes) }
      end
      secret = get("superadmin_personal/log?filter.eq.launch=#{id}&filter.cnt.message=SECRET123&page.size=1")
      fields = logs.map { |l| l["message"] } + (items + [launch]).flat_map { |r| r.values_at("name", "description", "attributes") }
      exposed = JSON.generate(fields).include?("SECRET123") || secret.dig("page", "totalElements") != 0
      Ledger202Host.write_new(File.join(directory, "#{id}.json"), launch: launch, items: items, logs: logs, files: files,
        item_seed_path: SEED, item_seed_sha256: Digest::SHA256.file(SEED).hexdigest,
        log_retrieval: "Independent paginated GET by every supplied item ID; no launch-log absence inference",
        secret_marker_total: secret.dig("page", "totalElements"), safety: exposed ? "STOP_PROBE_SECRET" : "CLEAR")
      puts JSON.generate(launch: id, items: items.length, logs: logs.length, files: files.length, safety: exposed ? "STOP" : "CLEAR")
      abort "STOP: probe exposure; inspect retained IDs without quoting secret" if exposed
    end
  end
end

Ledger202Trials.run if $PROGRAM_NAME == __FILE__
