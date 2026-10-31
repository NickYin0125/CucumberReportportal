# frozen_string_literal: true

require_relative "cucumber12_live_support"

module Cucumber12Live
  module CampaignAudit
    module_function

    def run
      Cucumber12Live.preflight!
      root = File.join(ROOT, "tmp/cucumber12-independent/live")
      output = File.join(root, "audit-all-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}")
      FileUtils.mkdir_p(output)
      launches = {}
      items = {}
      empty_attempts = []
      Dir.glob(File.join(root, "**/wire.json")).sort.each do |path|
        wire = JSON.parse(File.read(path))
        empty_attempts << path if wire.empty?
        wire.each do |entry|
          next unless entry["method"] == "POST" && entry["status"] && (200..299).cover?(entry["status"])
          if entry.fetch("path").end_with?("/launch")
            raise "Campaign ledger contains non-acceptance launch" unless entry.dig("json", "name").start_with?("c12-independent-C-")
            uuid = entry.fetch("response").fetch("id")
            launches[uuid] ||= { "uuid" => uuid, "name" => entry.dig("json", "name"), "wire_sources" => [] }
            launches[uuid].fetch("wire_sources") << path
          elsif entry.fetch("path").match?(%r{/item(?:/[^/]+)?$})
            uuid = entry.fetch("response").fetch("id")
            items[uuid] ||= { "uuid" => uuid, "launch_uuid" => entry.dig("json", "launchUuid"),
                              "parent_uuid" => entry.dig("json", "parentUuid"), "name" => entry.dig("json", "name"), "wire_source" => path }
          end
        end
      end
      raise "Unowned item in campaign ledger" unless items.values.all? { |item| launches.key?(item.fetch("launch_uuid")) }
      client = Client.new(Cucumber12Live.token)
      launches.each_value { |launch| launch["actual"] = client.get("launch/uuid/#{launch.fetch('uuid')}") }
      items.each_value { |item| item["actual"] = client.get("item/uuid/#{item.fetch('uuid')}") }
      unfinished_launches = launches.values.select { |entry| entry.dig("actual", "status") == "IN_PROGRESS" || !entry.dig("actual", "endTime") }
      unfinished_items = items.values.select { |entry| entry.dig("actual", "status") == "IN_PROGRESS" || !entry.dig("actual", "endTime") }
      bad_parents = items.values.select do |entry|
        parent = entry["parent_uuid"]
        parent ? entry.dig("actual", "parent") != items.fetch(parent).dig("actual", "id") : !!entry.dig("actual", "parent")
      end
      result = {
        "pass_no_hanging_items" => unfinished_launches.empty? && unfinished_items.empty? && bad_parents.empty?,
        "scope" => "Every successful launch/item creation in every reviewer-C wire ledger, including abandoned harness attempts and superseded cohorts; no cleanup writes",
        "launch_count" => launches.length, "item_count" => items.length, "zero_request_attempts" => empty_attempts,
        "unfinished_launches" => unfinished_launches, "unfinished_items" => unfinished_items, "incorrect_parents" => bad_parents,
        "launches" => launches.values, "items" => items.values,
        "manual_cleanup_performed" => false, "does_not_override_delivery_or_TC04_findings" => true
      }
      Cucumber12Live.write(File.join(output, "result.json"), result)
      Cucumber12Live.write(File.join(output, "queries.json"), client.queries)
      puts JSON.generate(result.slice("pass_no_hanging_items", "launch_count", "item_count", "manual_cleanup_performed"))
      puts "All-attempt ledger: #{output}"
      result["pass_no_hanging_items"] ? 0 : 1
    end
  end
end

exit Cucumber12Live::CampaignAudit.run if $PROGRAM_NAME == __FILE__
