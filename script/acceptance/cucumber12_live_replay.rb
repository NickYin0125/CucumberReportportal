# frozen_string_literal: true

require_relative "cucumber12_live"

module Cucumber12Live
  module Replay
    module_function

    def audit(wire, snapshot, worker, process, baseline, row, media_expectation: nil)
      starts = Runner.item_starts(wire)
      items = snapshot.fetch("items")
      by_uuid = items.to_h { |item| [item.fetch("uuid"), item] }
      logs = wire.flat_map { |entry| entry.fetch("entries", []) }
      expected_items = baseline.fetch("wire").fetch("items").values.sort_by { |item| item.fetch("startSequence") }
      finishes = wire.select { |entry| entry["method"] == "PUT" && entry.fetch("path", "").match?(%r{/item/[^/]+$}) }
      downloaded = snapshot.fetch("downloaded_files")
      files = wire.flat_map { |entry| entry.fetch("files", []) }
      tuple = lambda do |entry|
        [entry["itemUuid"] ? by_uuid.fetch(entry.fetch("itemUuid")).fetch("id") : 0, entry.fetch("message"), entry["level"].to_s.downcase]
      end
      checks = {
        "expected_native_exit" => process.fetch("exit") == row.fetch("exit"),
        "expected_item_topology" => starts.map { |entry| entry.fetch("json").values_at("name", "type", "retry") } == expected_items.map { |item| item.values_at("name", "type", "retry") },
        "all_created_UUIDs_individually_queried" => by_uuid.keys.sort == starts.map { |entry| entry.fetch("response").fetch("id") }.sort,
        "no_IN_PROGRESS_at_any_depth_or_retry_attempt" => items.all? { |item| item["endTime"] && item["status"] != "IN_PROGRESS" } && !!snapshot.dig("launch", "endTime") && snapshot.dig("launch", "status") != "IN_PROGRESS",
        "stored_status_matches_actual_finish_per_UUID" => finishes.length == items.length && finishes.all? do |entry|
          by_uuid.fetch(entry.fetch("path").split("/").last).fetch("status").downcase == entry.fetch("json").fetch("status").downcase
        end,
        "stored_parent_matches_parent_UUID_path" => starts.all? do |entry|
          item = by_uuid.fetch(entry.fetch("response").fetch("id"))
          parent = entry.fetch("json")["parentUuid"]
          parent ? entry.fetch("path").end_with?("/item/#{parent}") && item["parent"] == by_uuid.fetch(parent).fetch("id") : !item["parent"]
        end,
        "all_real_HTTP_requests_succeeded" => wire.all? { |entry| entry["status"] && (200..299).cover?(entry["status"]) },
        "exact_persisted_log_count" => logs.length == snapshot.fetch("logs").length && logs.length == baseline.fetch("wire").fetch("logs").length,
        "exact_persisted_log_owner_message_level" => logs.map(&tuple).sort == snapshot.fetch("logs").map { |entry| [entry["itemId"] || 0, entry.fetch("message"), entry["level"].to_s.downcase] }.sort,
        "all_media_downloaded_hash_matched_with_exact_owner" => files.length == downloaded.length && logs.select { |entry| entry["file"] }.all? do |entry|
          file = files.find { |candidate| candidate["name"] == entry.dig("file", "name") }
          actual = downloaded.find { |candidate| candidate["itemId"] == by_uuid.fetch(entry.fetch("itemUuid")).fetch("id") && candidate["message"] == entry["message"] }
          file && actual && file["sha256"] == actual["sha256"] && file["bytes"] == actual["bytes"]
        end,
        "finish_after_every_owned_log_ack" => finishes.all? do |finish|
          uuid = finish.fetch("path").split("/").last
          wire.select { |entry| entry.fetch("entries", []).any? { |log| log["itemUuid"] == uuid } }.all? { |entry| entry.fetch("finished") <= finish.fetch("started") }
        end,
        "installed_gem_only" => worker.fetch("loaded_sdk_files").all? { |file| file.start_with?(SDK_HOME + "/") } && worker["cucumber"] == "12.0.1",
        "exact_accepted_confirmed_and_empty_closed_queue" => worker.dig("diagnostics", "counters", "accepted") == logs.length && worker.dig("receipt", "confirmed") == logs.length &&
          worker.dig("receipt", "pending") == 0 && worker.dig("receipt", "complete") && worker.dig("diagnostics", "current_records") == 0 && worker.dig("diagnostics", "closed") && !worker.dig("diagnostics", "worker_alive"),
        "zero_background_exceptions" => worker.dig("diagnostics", "counters", "worker_failed") == 0 && !process.fetch("stderr").match?(/terminated with exception|report_on_exception|Exception in thread/)
      }
      if row.fetch("label") == "ten-distinct-screenshots"
        pngs = downloaded.select { |file| file["mime"] == "image/png" }
        checks["ten_distinguishable_pngs_under_ten_correct_action_nodes"] = pngs.size == 10 && pngs.map { |file| file["sha256"] }.uniq.size == 10 &&
          pngs.map { |file| file["itemId"] }.uniq.size == 10 && pngs.all? do |file|
            number = file.fetch("message")[/screenshot-(\d+)/, 1].to_i
            item = items.find { |candidate| candidate["id"] == file["itemId"] }
            item && item["hasStats"] == false && item.fetch("name").match?(/independent screenshot #{number}\b/)
          end
      end
      if row.fetch("case") == "TC10"
        checks["after_failure_media_belongs_to_open_After_hook"] = downloaded.size == 1 && items.find { |item| item["id"] == downloaded.first["itemId"] }&.fetch("type") == "AFTER_METHOD"
        if media_expectation
          checks["capture_preserved_with_correct_MIME_filename_and_hash"] = downloaded.size == 1 && files.size == 1 &&
            downloaded.first.values_at("mime", "sha256", "bytes") == media_expectation.values_at("mime", "sha256", "bytes") &&
            files.first.values_at("name", "mime", "sha256", "bytes") == media_expectation.values_at("name", "mime", "sha256", "bytes")
        end
      end
      if row.fetch("label").include?("outline-display")
        descriptions = items.select { |item| item["hasStats"] == false }.map { |item| item["description"].to_s }
        markdown = snapshot.fetch("logs").map { |entry| entry["message"].to_s }
        expected = %w[TABLE_ONLY_AMBER TABLE_ONLY_BIRCH]
        checks["combined_Outline_table_placeholders_expanded_in_descriptions_and_logs"] =
          (descriptions + markdown).none? { |text| text.include?("<value>") } &&
          expected.all? { |value| descriptions.any? { |text| text.include?(value) } && markdown.any? { |text| text.include?(value) } }
      end
      { "pass" => checks.values.all?, "checks" => checks, "nodes" => items.length, "logs" => logs.length,
        "files" => downloaded.length, "receipt" => worker.fetch("receipt"),
        "retry_attempts" => starts.select { |entry| entry.dig("json", "name").start_with?("Scenario:") }.map do |entry|
          item = by_uuid.fetch(entry.fetch("response").fetch("id"))
          item.merge("wireRetry" => entry.dig("json", "retry"))
        end }
    end

    def run(token, root, support, row)
      directory = File.join(root, row.fetch("case"), row.fetch("label"))
      FileUtils.mkdir_p(File.join(directory, "artifacts"))
      source_support = row["supportPath"] || support
      support = File.join(directory, "runtime-support.rb")
      FileUtils.cp(source_support, support)
      support_sha = Digest::SHA256.file(support).hexdigest
      raise "Runtime support snapshot hash differs from manifest" if row["supportSha256"] && row["supportSha256"] != support_sha
      media_expectation = if row.fetch("case") == "TC10" && ENV["C12_AFTER_SCREENSHOT"]
                            Cucumber12Live.image_input!(ENV.fetch("C12_AFTER_SCREENSHOT"),
                                                       mime: ENV.fetch("C12_AFTER_SCREENSHOT_MIME"),
                                                       name: ENV.fetch("C12_AFTER_SCREENSHOT_NAME"))
                          end
      observer = Observer.new(directory)
      client = Client.new(token)
      baseline = JSON.parse(File.read(row.fetch("evidence")))
      name = "c12-independent-C-#{row.fetch('case')}-#{row.fetch('label')}-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(3)}"
      env = Runner.child_environment(token, observer, directory, async: false, launch_name: name)
      row.fetch("fixtureEnvironment").each do |key, value|
        raise "Unapproved fixture environment key" unless key.start_with?("INDEPENDENT_", "RP_SCENARIO_")
        env[key] = value
      end
      env.merge!("INDEPENDENT_CALLS" => File.join(directory, "calls.ndjson"), "INDEPENDENT_ARTIFACTS" => File.join(directory, "artifacts"),
                 "RP_RULE_SUITES" => "true", "RP_IDENTITY_ROOT" => row.fetch("directory"), "C12_LIVE_AFTERALL" => "false")
      env["INDEPENDENT_PNG_DIR"] = ENV["C12_PNG_DIR"] if row.fetch("label") == "ten-distinct-screenshots" && ENV["C12_PNG_DIR"]
      if media_expectation
        env.merge!("INDEPENDENT_AFTER_SCREENSHOT_PATH" => media_expectation.fetch("path"),
                   "INDEPENDENT_AFTER_SCREENSHOT_MIME" => media_expectation.fetch("mime"),
                   "INDEPENDENT_AFTER_SCREENSHOT_NAME" => media_expectation.fetch("name"))
      end
      args = ["--no-profile", "--backtrace", "--require", support, "--require", File.join(FIXTURES, "support/env.rb"),
              "--format", "progress", "--format", "ReportPortal::Cucumber::Formatter", "--out", File.join(directory, "rp.out"),
              "--format", "Cucumber12LiveAudit", "--out", File.join(directory, "audit.out"),
              "--format", "message", "--out", File.join(directory, "native.ndjson"), *row.fetch("options"), row.fetch("featurePath")]
      process = Runner.execute(env, [RUBY, "-e", "gem 'cucumber', '=12.0.1'; require 'reportportal_cucumber'; load Gem.bin_path('cucumber', 'cucumber', '12.0.1')", "--", *args], directory)
      wire = observer.records
      launch = wire.find { |entry| entry["method"] == "POST" && entry.fetch("path", "").end_with?("/launch") }
      raise "No launch; see preserved process evidence" unless launch
      uuid = launch.fetch("response").fetch("id")
      starts = Runner.item_starts(wire)
      snapshot = client.snapshot(uuid, starts.map { |entry| entry.fetch("response").fetch("id") }.uniq)
      worker = JSON.parse(File.read(File.join(directory, "worker-single.json")))
      result = audit(wire, snapshot, worker, process, baseline, row, media_expectation: media_expectation)
      result.merge!("case" => row.fetch("case"), "label" => row.fetch("label"), "launch_uuid" => uuid,
                    "launch_id" => snapshot.dig("launch", "id"), "expected_native_exit" => row.fetch("exit"), "native_exit" => process.fetch("exit"),
                    "source_fixture" => row, "support_sha256" => support_sha, "support_path" => support,
                    "source_support_path" => source_support, "package_sha256" => GEM_SHA,
                    "media_expectation" => media_expectation,
                    "media_fixture" => env.slice("INDEPENDENT_PNG_DIR", "INDEPENDENT_AFTER_SCREENSHOT_PATH", "INDEPENDENT_AFTER_SCREENSHOT_MIME", "INDEPENDENT_AFTER_SCREENSHOT_NAME"))
      Cucumber12Live.write(File.join(directory, "snapshot.json"), snapshot)
      Cucumber12Live.write(File.join(directory, "queries.json"), client.queries)
      Cucumber12Live.write(File.join(directory, "result.json"), result)
      puts JSON.generate(case: row.fetch("case"), label: row.fetch("label"), pass: result["pass"], launch_id: result["launch_id"], failed_gates: result.fetch("checks").reject { |_, value| value }.keys)
      result
    ensure
      observer&.close
    end

    def main
      Cucumber12Live.preflight!
      if ARGV.first == "--audit"
        directory = File.expand_path(ARGV.fetch(1))
        raise "Audit path outside owned evidence" unless directory.start_with?(File.join(ROOT, "tmp/cucumber12-independent/live/"))
        original = JSON.parse(File.read(File.join(directory, "result.json")))
        row = original.fetch("source_fixture")
        wire = JSON.parse(File.read(File.join(directory, "wire.json")))
        client = Client.new(Cucumber12Live.token)
        snapshot = client.snapshot(original.fetch("launch_uuid"), Runner.item_starts(wire).map { |entry| entry.fetch("response").fetch("id") }.uniq)
        result = audit(wire, snapshot, JSON.parse(File.read(File.join(directory, "worker-single.json"))),
                       JSON.parse(File.read(File.join(directory, "process.json"))), JSON.parse(File.read(row.fetch("evidence"))), row,
                       media_expectation: original["media_expectation"])
        result.merge!("launch_id" => snapshot.dig("launch", "id"), "read_only_semantic_reaudit" => true,
                      "original_result_preserved" => "result.json", "note" => "Original replay checked transport persistence; this adds the independent combined Outline display assertion.")
        Cucumber12Live.write(File.join(directory, "reaudit-result.json"), result)
        Cucumber12Live.write(File.join(directory, "reaudit-queries.json"), client.queries)
        puts JSON.generate(result.slice("pass", "launch_id", "checks"))
        return result["pass"] ? 0 : 1
      end
      manifest_path = File.expand_path(ARGV.fetch(0))
      manifest = JSON.parse(File.read(manifest_path))
      root = File.join(ROOT, "tmp/cucumber12-independent/live", "replay-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}")
      FileUtils.mkdir_p(File.join(root, "inputs"))
      support = File.join(root, "inputs/runtime-support.rb")
      FileUtils.cp(manifest.fetch("support"), support)
      Cucumber12Live.write(File.join(root, "inputs/manifest.json"), manifest)
      Cucumber12Live.write(File.join(root, "inputs/candidate.json"),
                           "package_sha256" => GEM_SHA, "sha_environment" => "C12_PACKAGE_SHA256",
                           "installed_gem_home" => SDK_HOME, "source_commit" => ENV["C12_SOURCE_COMMIT"],
                           "verified_installed_library_files" => 37)
      token = Cucumber12Live.token
      results = []
      manifest.fetch("runs").reject { |row| row.fetch("control") }.each do |row|
        next if ENV["C12_REPLAY_CASES"] && !ENV.fetch("C12_REPLAY_CASES").split(",").include?(row.fetch("case"))
        next if ENV["C12_REPLAY_LABELS"] && !ENV.fetch("C12_REPLAY_LABELS").split(",").include?(row.fetch("label"))
        results << run(token, root, support, row)
        Cucumber12Live.write(File.join(root, "summary.json"), results)
      end
      puts "Replay evidence: #{root}"
      results.all? { |result| result["pass"] } ? 0 : 1
    end
  end
end

exit Cucumber12Live::Replay.main if $PROGRAM_NAME == __FILE__
