# frozen_string_literal: true

require_relative "cucumber12_live"

module Cucumber12Live
  module OutlineAngle
    module_function

    def run
      Cucumber12Live.preflight!
      directory = File.join(ROOT, "tmp/cucumber12-independent/live", "outline-angle-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}")
      FileUtils.mkdir_p(directory)
      observer = Observer.new(directory)
      token = Cucumber12Live.token
      client = Client.new(token)
      env = Runner.child_environment(token, observer, directory, async: false,
                                     launch_name: "c12-independent-C-outline-angle-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(3)}")
      env["C12_LIVE_AFTERALL"] = "false"
      args = ["--no-profile", "--require", File.join(FIXTURES, "support/env.rb"), "--format", "progress",
              "--format", "ReportPortal::Cucumber::Formatter", "--out", File.join(directory, "rp.out"),
              "--format", "Cucumber12LiveAudit", "--out", File.join(directory, "audit.out"),
              "--format", "message", "--out", File.join(directory, "native.ndjson"), File.join(FIXTURES, "outline-angle.feature")]
      process = Runner.execute(env, [RUBY, "-e", "load Gem.bin_path('cucumber', 'cucumber', '12.0.1')", "--", *args], directory)
      wire = observer.records
      uuid = wire.find { |entry| entry["method"] == "POST" && entry.fetch("path").end_with?("/launch") }.fetch("response").fetch("id")
      snapshot = client.snapshot(uuid, Runner.item_starts(wire).map { |entry| entry.fetch("response").fetch("id") })
      worker = JSON.parse(File.read(File.join(directory, "worker-single.json")))
      expected = ["TABLE_ONLY_AMBER <other>", "TABLE_ONLY_BIRCH <other>"] * 2
      native_values = worker.fetch("native_pickle_tables").map { |table| table.fetch("rows").fetch(1).fetch(1) }
      actions = snapshot.fetch("items").select { |item| item["hasStats"] == false }
      logs = snapshot.fetch("logs")
      by_uuid = snapshot.fetch("items").to_h { |item| [item.fetch("uuid"), item] }
      starts = Runner.item_starts(wire)
      checks = {
        "native_exit_0_four_scenarios" => process["exit"] == 0 && actions.length == 4,
        "compiled_native_values_preserve_literal_other" => native_values.sort == expected.sort,
        "descriptions_match_each_native_value_exactly" => actions.length == 4 && expected.uniq.all? { |value| actions.count { |item| item.fetch("description").include?(value) } == 2 },
        "persisted_Markdown_logs_match_each_native_value" => logs.length == 4 && expected.uniq.all? { |value| logs.count { |log| log.fetch("message").include?(value) } == 2 },
        "no_unexpanded_Outline_placeholder" => (actions.map { |item| item["description"] } + logs.map { |log| log["message"] }).none? { |text| text.include?("<value>") },
        "every_created_UUID_closed_and_launch_finished" => snapshot.fetch("items").length == 9 && snapshot.fetch("items").all? { |item| item["status"] == "PASSED" && item["endTime"] } && snapshot.dig("launch", "status") == "PASSED" && !!snapshot.dig("launch", "endTime"),
        "exact_action_log_ownership" => actions.all? { |item| logs.count { |log| log["itemId"] == item["id"] && log["message"] == item["description"] } == 1 },
        "exact_parent_UUID_path_and_persisted_parent" => starts.all? do |entry|
          parent = entry.dig("json", "parentUuid")
          item = by_uuid.fetch(entry.fetch("response").fetch("id"))
          parent ? entry.fetch("path").end_with?("/item/#{parent}") && item["parent"] == by_uuid.fetch(parent)["id"] : !item["parent"]
        end,
        "all_HTTP_acknowledged_and_empty_closed_queue" => wire.all? { |entry| entry["status"] && (200..299).cover?(entry["status"]) } &&
          worker.dig("receipt", "confirmed") == 4 && worker.dig("receipt", "pending") == 0 && worker.dig("receipt", "complete") && !worker.dig("diagnostics", "worker_alive") && worker.dig("diagnostics", "counters", "worker_failed") == 0,
        "correct_installed_candidate" => worker["package_sha256"] == GEM_SHA && worker.fetch("loaded_sdk_files").all? { |file| file.start_with?(SDK_HOME + "/") }
      }
      result = { "pass" => checks.values.all?, "checks" => checks, "launch_uuid" => uuid,
                 "launch_id" => snapshot.dig("launch", "id"), "package_sha256" => GEM_SHA,
                 "native_values" => native_values, "nodes" => 9, "logs" => logs.length,
                 "scope" => "Both combined Outline orders and both rows; native literal <other> preserved in persisted API text, not a UI HTML rendering claim" }
      Cucumber12Live.write(File.join(directory, "snapshot.json"), snapshot)
      Cucumber12Live.write(File.join(directory, "queries.json"), client.queries)
      Cucumber12Live.write(File.join(directory, "result.json"), result)
      puts JSON.generate(result)
      result["pass"] ? 0 : 1
    ensure
      observer&.close
    end
  end
end

exit Cucumber12Live::OutlineAngle.run if $PROGRAM_NAME == __FILE__
