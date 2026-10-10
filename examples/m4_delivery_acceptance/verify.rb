# frozen_string_literal: true

require "digest"
require "json"

abort "Refusing live verification without Master approval" unless ENV["M4_LIVE_D_APPROVED"] == "1"
require_relative "auth"
ENV["RP_API_KEY"] = M4DeliveryAuth.bearer(ENV.fetch("RP_ENDPOINT"))

pointer = File.realpath(ARGV.fetch(0))
receipt_path = if File.basename(pointer) == "latest.json"
                 File.realpath(JSON.parse(File.read(pointer)).fetch("receipt"))
               else
                 pointer
               end
receipt = JSON.parse(File.read(receipt_path))
raise "receipt directory is not private" unless (File.stat(File.dirname(receipt_path)).mode & 0o077).zero?

require "reportportal_cucumber"
config = ReportportalCucumber::Config.load
api = ReportportalCucumber::ReportPortal::API.new(config: config)
launch = api.launch_by_uuid(uuid: receipt.fetch("launch_uuid"))
item = api.item_by_uuid(uuid: receipt.fetch("item_uuid"))
raise "launch did not preserve business failure" unless (launch["status"] || launch["state"]).to_s.upcase == "FAILED"
raise "item is not finalized PASSED" unless (item["status"] || item["state"]).to_s.upcase == "PASSED"
raise "live replay did not confirm exactly two entries" unless receipt.dig("replay_open_summary", "confirmed") == 2
raise "closed target replay was not refused" unless receipt.fetch("replay_closed_refused_without_checkpoint_change")
raise "business failure was not retained" unless receipt.fetch("feature_exit_status") == 1 && receipt.fetch("feature_failure_preserved")
raise "feature did not include pass and failure outcomes" unless receipt.fetch("feature_scenario_statuses").include?("passed") && receipt.fetch("feature_scenario_statuses").include?("failed")
acks = receipt.fetch("acknowledged_ids")
raise "per-entry acknowledgement IDs are missing or duplicated" unless acks.length == 2 && acks.all? { |id| id.is_a?(String) && !id.empty? } && acks.uniq == acks

puts "m4_live_verify=PASS launch=#{receipt.fetch('launch_uuid')} item=#{receipt.fetch('item_uuid')} confirmed=2 closed_refusal=true"
