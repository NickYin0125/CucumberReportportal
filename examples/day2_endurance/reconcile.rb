# frozen_string_literal: true

require "net/http"
require "uri"
require_relative "support"

module Day2Endurance
  class Reconciler
    attr_reader :observed

    def initialize(endpoint:, bearer:, project: "superadmin_personal")
      @endpoint, @bearer, @project = endpoint, bearer, project
      @observed = {}
    end

    def response(path)
      uri = URI.join(@endpoint + "/", path)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@bearer}"
      http = Net::HTTP.new(uri.host, uri.port, nil)
      http.ipaddr = "127.0.0.1" if uri.host.end_with?(".localhost")
      http.use_ssl = uri.scheme == "https"
      http.open_timeout, http.read_timeout = 5, 30
      result = http.start { |connection| connection.request(request) }
      raise "RP query HTTP #{result.code} at #{uri.path}" unless result.code == "200"
      result
    end

    def query(resource, filters)
      all, page = [], 1
      loop do
        args = filters.merge("page.size" => 100, "page.page" => page)
        result = JSON.parse(response("api/v1/#{@project}/#{resource}?#{URI.encode_www_form(args)}").body)
        rows = result.fetch("content")
        all.concat(rows)
        total = result.fetch("page").fetch("totalPages")
        break if page >= total
        raise "RP pagination did not converge" if page >= 10_000
        page += 1
      end
      all
    end

    def run(name:, receipt:, native:, artifacts:, pbt:)
      launch = nil
      60.times do
        launch = query("launch", "filter.eq.name" => name).find { |row| row["name"] == name }
        break if launch && launch["endTime"] && launch["status"] != "IN_PROGRESS"
        sleep 1
      end
      Day2Endurance.check("RP launch completed", launch && launch["endTime"])
      @observed[:launch] = launch
      items = query("item", "filter.eq.launchId" => launch.fetch("id"))
      @observed[:items] = items
      cases = items.select { |row| row["hasStats"] && row["type"] == "STEP" }
      native_cases = native.flat_map { |feature| Array(feature["elements"]) }.select { |row| row["type"] == "scenario" }
      Day2Endurance.check("native and RP case counts", native_cases.size == 8 && cases.size == 8)
      Day2Endurance.check("native all steps passed", native_cases.all? { |row| row.fetch("steps").all? { |step| step.dig("result", "status") == "passed" } })
      Day2Endurance.check("RP all cases passed", cases.all? { |row| row["status"] == "PASSED" })
      Day2Endurance.check("RP native case names", cases.map { |row| row["name"] }.sort == native_cases.map { |row| "Scenario: #{row['name']}" }.sort)
      suites = items.select { |row| row["type"] == "SUITE" }
      Day2Endurance.check("RP cases owned by their suites", cases.all? { |row| suites.any? { |suite| suite["id"].to_s == row["parent"].to_s } })
      Day2Endurance.check("RP statistics total", launch.dig("statistics", "executions", "total") == 8)
      Day2Endurance.check("RP statistics passed", launch.dig("statistics", "executions", "passed") == 8)
      Day2Endurance.check("RP launch passed", launch["status"] == "PASSED")
      ids = items.map { |row| row.fetch("id").to_s }
      Day2Endurance.check("RP item owners", items.all? { |row| row["type"] == "SUITE" || ids.include?(row["parent"].to_s) })
      Day2Endurance.check("RP UUID uniqueness", items.map { |row| row.fetch("uuid") }.uniq.size == items.size)
      # Launch-owned logs and item-owned logs are separate server selectors.
      logs_by_owner = items.to_h { |item| [item.fetch("id").to_s, query("log", "filter.eq.item" => item.fetch("id"))] }
      Day2Endurance.check("RP per-query log owners", logs_by_owner.all? { |id, rows| rows.all? { |row| row["itemId"].to_s == id } })
      launch_logs = query("log", "filter.eq.launch" => launch.fetch("id"))
      logs = (launch_logs + logs_by_owner.values.flatten).uniq { |row| row.fetch("id") }
      @observed[:logs] = logs
      @observed[:counts] = { cases: cases.size, items: items.size, logs: logs.size }
      Day2Endurance.check("delivery receipt complete", receipt.fetch(:complete))
      Day2Endurance.check("no lost or ambiguous delivery", %i[rejected pending spooled failed ambiguous possible_duplicates degraded_evidence metadata_failures capture_close_timeouts].all? { |key| receipt.fetch(key).zero? })
      Day2Endurance.check("exact RP log count equals receipt confirmed (actual=#{logs.size} expected=#{receipt.fetch(:confirmed)})", logs.size == receipt.fetch(:confirmed))
      Day2Endurance.check("RP log owners", logs.all? { |row| row["itemId"].nil? || ids.include?(row["itemId"].to_s) })
      Day2Endurance.check("huge JSON logs preserved", logs.count { |row| row["message"].to_s.start_with?("Duration huge JSON iteration=") && row["message"].bytesize > 500_000 } == pbt.fetch("huge_json_logs"))
      summaries = logs.select { |row| row["message"].to_s.start_with?("Duration PBT invariant checks iteration=") }
      Day2Endurance.check("all per-iteration AppLog summaries present", summaries.size == pbt.fetch("iterations"))
      iterations = summaries.map { |row| row["message"][/iteration=(\d+)/, 1].to_i }.sort
      Day2Endurance.check("per-iteration AppLog uniqueness", iterations == (1..pbt.fetch("iterations")).to_a)
      summary_owners = summaries.map { |row| row["itemId"].to_s }.uniq
      Day2Endurance.check("per-iteration logs stay on original PBT action", summary_owners.size == 1 && items.any? { |row| row["id"].to_s == summary_owners.first && row["name"].to_s.include?("bombard the clearing duration APIs") })
      downloaded = artifacts.map do |artifact|
        owner = items.find { |row| row["uuid"] == artifact.fetch(:owner_uuid) }
        Day2Endurance.check("CSV owner exists", !owner.nil?)
        candidates = logs.select { |row| row["itemId"].to_s == owner.fetch("id").to_s && row["binaryContent"] }
        matches = candidates.filter_map do |row|
          binary = response("api/v1/data/#{@project}/#{row.fetch('binaryContent').fetch('id')}").body.b
          next unless binary.bytesize == artifact.fetch(:bytes) && Digest::SHA256.hexdigest(binary) == artifact.fetch(:sha256)
          { log_id: row.fetch("id"), owner_id: owner.fetch("id"), owner_uuid: owner.fetch("uuid"),
            bytes: binary.bytesize, sha256: Digest::SHA256.hexdigest(binary), name: artifact.fetch(:name) }
        end
        Day2Endurance.check("CSV bytes and hash match RP original owner", matches.size == 1)
        matches.first
      end
      { launch: launch, items: items, logs: logs, counts: { cases: cases.size, items: items.size, logs: logs.size },
        attachments: downloaded, launch_url: "#{@endpoint}/ui/##{@project}/launches/all/#{launch.fetch('id')}" }
    end
  end
end
