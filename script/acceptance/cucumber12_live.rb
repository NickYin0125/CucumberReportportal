# frozen_string_literal: true

require_relative "cucumber12_live_support"

module Cucumber12Live
  module Runner
    module_function

    def child_environment(token, observer, directory, async:, launch_name:, launch_uuid: nil)
      ENV.keys.grep(/\A(?:RP_|CUCUMBER_|BUNDLE_|BUNDLER_|RUBYOPT|RUBYLIB|TEST_ENV_NUMBER|PARALLEL_TEST)/).to_h { |key| [key, nil] }.merge(
        "GEM_HOME" => SDK_HOME, "GEM_PATH" => [SDK_HOME, CACHED_GEMS].join(File::PATH_SEPARATOR),
        "PATH" => [File.dirname(RUBY), File.join(CACHED_GEMS, "bin"), ENV.fetch("PATH")].join(File::PATH_SEPARATOR),
        "RP_ENDPOINT" => observer.endpoint, "RP_PROJECT" => PROJECT, "RP_API_KEY" => token,
        "RP_LAUNCH" => launch_name, "RP_LAUNCH_UUID" => launch_uuid, "RP_CLIENT_JOIN" => "false",
        "RP_REPORTING_ASYNC" => async.to_s, "RP_REQUIRE_COMPLETE_REPORTING" => (!async).to_s,
        "RP_FAIL_ON_REPORTING_ERROR" => "true", "RP_HTTP_RETRY_ATTEMPTS" => "1",
        "RP_EXIT_FLUSH_TIMEOUT_MS" => "5000", "RP_FLUSH_INTERVAL" => "0.1",
        "RP_BATCH_SIZE_LOGS" => "20", "RP_SPOOL_DIR" => File.join(directory, "spool"),
        "RP_IDENTITY_STRATEGY" => "stable_v1", "RP_IDENTITY_ROOT" => FIXTURES,
        "CUCUMBER_PUBLISH_ENABLED" => "false", "CUCUMBER_PUBLISH_QUIET" => "true", "NO_COLOR" => "1",
        "C12_LIVE_EVIDENCE" => directory,
        "C12_PACKAGE_SHA256" => GEM_SHA, "C12_EXPECTED_SHA256" => nil,
        "C12_LIVE_AFTERALL" => (!launch_uuid.nil? ? "false" : "true"), "C12_LIVE_FORCE_EXIT" => nil,
        "PARALLEL_TESTS_EXECUTABLE" => Shellwords.join([RUBY, "-e", "load Gem.bin_path('cucumber', 'cucumber', '12.0.1')", "--"])
      )
    end

    def execute(environment, command, directory)
      start = Cucumber12Live.now
      stdout = stderr = status = nil
      Open3.popen3(environment, *command, chdir: directory, pgroup: true) do |input, output, errors, process|
        input.close
        readers = [Thread.new { output.read }, Thread.new { errors.read }]
        begin
          Timeout.timeout(90) { status = process.value }
        rescue Timeout::Error
          Process.kill("KILL", -process.pid)
          raise "Live Cucumber exceeded 90 seconds"
        ensure
          stdout, stderr = readers.map(&:value)
        end
      end
      result = { "command" => command, "started" => start, "finished" => Cucumber12Live.now,
                 "exit" => status.exitstatus, "stdout" => stdout, "stderr" => stderr }
      Cucumber12Live.write(File.join(directory, "process.json"), result)
      result
    end

    def item_starts(wire)
      wire.select { |entry| entry["method"] == "POST" && entry.fetch("path", "").match?(%r{/item(?:/[^/]+)?$}) }
    end

    def gates(wire, snapshot, workers, process, expected_items:, expected_logs:, async:, parallel:)
      checks = {}
      starts = item_starts(wire)
      items = snapshot.fetch("items")
      by_uuid = items.to_h { |item| [item.fetch("uuid"), item] }
      expected_uuids = starts.map { |entry| entry.fetch("response").fetch("id") }
      logs = wire.flat_map { |entry| entry.fetch("entries", []) }
      persisted_logs = snapshot.fetch("logs")
      finishes = wire.select { |entry| entry["method"] == "PUT" && entry.fetch("path", "").match?(%r{/item/[^/]+$}) }
      checks["native_exit_0"] = process.fetch("exit") == 0
      checks["exact_item_count"] = items.length == expected_items && expected_uuids.uniq.length == expected_items
      checks["every_created_uuid_queried_including_hidden_retries"] = by_uuid.keys.sort == expected_uuids.sort
      checks["all_nodes_finished"] = items.all? { |item| item["status"] == "PASSED" && item["endTime"] }
      checks["launch_finished"] = snapshot.dig("launch", "status") == "PASSED" && !!snapshot.dig("launch", "endTime")
      checks["one_finish_per_item"] = finishes.length == expected_items && finishes.map { |entry| entry.fetch("path").split("/").last }.sort == expected_uuids.sort
      checks["actual_http_success"] = wire.all? { |entry| entry["status"] && (200..299).cover?(entry["status"]) }
      checks["exact_wire_and_persisted_log_counts"] = logs.length == expected_logs && persisted_logs.length == expected_logs
      checks["exact_persisted_log_ownership"] = logs.map do |entry|
        [entry["itemUuid"] ? by_uuid.fetch(entry.fetch("itemUuid")).fetch("id") : 0, entry.fetch("message")]
      end.sort == persisted_logs.map { |entry| [entry["itemId"] || 0, entry.fetch("message")] }.sort
      checks["schema_correct_parents_and_no_itemParentId"] = starts.all? do |entry|
        body = entry.fetch("json")
        item = by_uuid.fetch(entry.fetch("response").fetch("id"))
        parent_uuid = body["parentUuid"]
        !body.key?("itemParentId") && (parent_uuid ?
          entry.fetch("path").end_with?("/item/#{parent_uuid}") && item["parent"] == by_uuid.fetch(parent_uuid).fetch("id") :
          entry.fetch("path").end_with?("/item") && !item["parent"])
      end
      checks["scenario_STEP_true_and_action_STEP_false"] = items.all? do |item|
        if item.fetch("name").start_with?("Scenario:")
          item["type"] == "STEP" && item["hasStats"] == true
        elsif item.fetch("name").match?(/\A(?:Given|And) /)
          item["type"] == "STEP" && item["hasStats"] == false
        else
          true
        end
      end
      checks["finish_after_owner_logs_acknowledged"] = finishes.all? do |finish|
        uuid = finish.fetch("path").split("/").last
        wire.select { |entry| entry.fetch("entries", []).any? { |log| log["itemUuid"] == uuid } }
            .all? { |entry| entry.fetch("finished") <= finish.fetch("started") }
      end
      checks["children_finished_before_parent"] = starts.all? do |entry|
        parent = entry.fetch("json")["parentUuid"]
        next true unless parent
        uuid = entry.fetch("response").fetch("id")
        child_finish = finishes.find { |finish| finish.fetch("path").end_with?("/item/#{uuid}") }
        parent_finish = finishes.find { |finish| finish.fetch("path").end_with?("/item/#{parent}") }
        child_finish && parent_finish && child_finish.fetch("finished") <= parent_finish.fetch("started")
      end
      files = wire.flat_map { |entry| entry.fetch("files", []) }
      downloaded = snapshot.fetch("downloaded_files")
      file_logs = logs.select { |entry| entry["file"] }
      checks["exactly_ten_png_files_downloaded"] = files.length == 10 && downloaded.length == 10 && downloaded.all? { |file| file["mime"] == "image/png" }
      checks["each_png_exact_hash_and_owner"] = file_logs.length == 10 && file_logs.all? do |entry|
        file = files.find { |value| value.fetch("name") == entry.fetch("file").fetch("name") }
        persisted = downloaded.find do |value|
          value.fetch("itemId") == by_uuid.fetch(entry.fetch("itemUuid")).fetch("id") && value["message"] == entry["message"]
        end
        file && persisted && file["sha256"] == persisted["sha256"] && file["bytes"] == persisted["bytes"]
      end
      checks["exact_queue_accepted_settled"] = workers.sum { |worker| worker.dig("diagnostics", "counters", "accepted") } == expected_logs &&
        workers.sum { |worker| worker.dig("receipt", "settled") } == expected_logs
      checks["correct_acknowledgement_semantics"] = workers.all? do |worker|
        receipt = worker.fetch("receipt")
        accepted = worker.dig("diagnostics", "counters", "accepted")
        async ? receipt["accepted_awaiting_persistence"] == accepted && receipt["confirmed"] == 0 && !receipt["complete"] :
          receipt["confirmed"] == accepted && receipt["complete"]
      end
      checks["zero_unsettled_rejected_failed_or_background_exceptions"] = workers.all? do |worker|
        receipt = worker.fetch("receipt")
        %w[pending rejected failed ambiguous possible_duplicates spooled metadata_failures capture_close_timeouts].all? { |key| receipt[key] == 0 } &&
          worker.dig("diagnostics", "counters", "worker_failed") == 0 &&
          worker.dig("diagnostics", "current_records") == 0 && worker.dig("diagnostics", "closed") &&
          worker.fetch("reportportal_threads").none? { |thread| thread.fetch("alive") }
      end && !process.fetch("stderr").match?(/terminated with exception|report_on_exception|Exception in thread/)
      checks["installed_candidate_only"] = workers.all? do |worker|
        worker.fetch("sdk").start_with?(SDK_HOME + "/") && worker["cucumber"] == "12.0.1" &&
          worker.fetch("loaded_sdk_files").all? { |file| file.start_with?(SDK_HOME + "/") }
      end
      launch_writes = wire.select { |entry| entry.fetch("path", "").match?(%r{/launch(?:/[^/]+/finish)?$}) && entry["method"] != "GET" }
      checks["single_launch_lifecycle_owner"] = launch_writes.length == 2 && (!parallel || launch_writes.all? { |entry| entry["actor"] == "orchestrator" })
      if process["afterall_expected"]
        checks["owned_launch_finish_after_AfterAll_and_last_log_flush"] = workers.length == 1 && !!workers.first["afterall"] &&
          workers.first.fetch("events").select { |entry| entry["event"] == "run_hook_finished" }.all? { |entry| entry.fetch("at") <= launch_writes.last.fetch("started") } &&
          wire.select { |entry| entry.fetch("entries", []).any? { |log| log["message"] == "TC15 AFTERALL delayed final log" } }
              .then { |entries| entries.length == 1 && entries.first.fetch("finished") <= launch_writes.last.fetch("started") }
      end
      checks["parallel_four_distinct_processes"] = !parallel || (workers.length == 4 && workers.map { |worker| worker["pid"] }.uniq.length == 4 && workers.map { |worker| worker["worker"] }.sort == %w[1 2 3 4])
      checks["launch_finish_after_all_workers_exit"] = !parallel || launch_writes.last.fetch("started") >= process.fetch("finished")
      checks["hook_types_actually_supported"] = !parallel || items.select { |item| item["name"].include?("Hook:") }.map { |item| item["type"] }.uniq.sort == %w[AFTER_METHOD BEFORE_METHOD]
      last_action = finishes.select do |entry|
        by_uuid.fetch(entry.fetch("path").split("/").last).fetch("name").match?(/\A(?:Given|And) /)
      end.max_by { |entry| entry.fetch("finished") }
      tail_ms = (launch_writes.last.fetch("finished") - last_action.fetch("finished")) * 1000
      checks["reporting_tail_within_5000ms_flush_budget"] = tail_ms <= 5000
      { "checks" => checks, "pass" => checks.values.all?, "reporting_tail_ms" => tail_ms,
        "remote_item_count" => items.length, "remote_log_count" => persisted_logs.length,
        "remote_png_count" => downloaded.length, "local_receipts" => workers.map { |worker| worker.fetch("receipt") } }
    end

    def run_case(token, directory, async:, parallel:)
      FileUtils.mkdir_p(directory)
      observer = Observer.new(directory)
      client = Client.new(token)
      writer = Client.new(token, endpoint: observer.endpoint)
      name = "c12-independent-C-#{File.basename(directory)}-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(3)}"
      launch_uuid = nil
      if parallel
        launch_uuid = writer.call("POST", "/api/v1/#{PROJECT}/launch",
                                  "name" => name, "startTime" => (Time.now.to_f * 1000).to_i.to_s, "mode" => "DEFAULT",
                                  "attributes" => [{ "key" => "acceptance", "value" => "TC16-independent-C" }]).fetch("id")
      end
      environment = child_environment(token, observer, directory, async: async, launch_name: name, launch_uuid: launch_uuid)
      args = ["--no-profile", "--require", File.join(FIXTURES, "support/env.rb"), "--format", "progress",
              "--format", parallel ? "ReportPortal::Cucumber::ParallelFormatter" : "ReportPortal::Cucumber::Formatter",
              "--out", File.join(directory, "rp-$TEST_ENV_NUMBER.out"),
              "--format", "Cucumber12LiveAudit", "--out", File.join(directory, "audit-$TEST_ENV_NUMBER.out")]
      command = if parallel
                  [RUBY, "-e", "load Gem.bin_path('parallel_tests', 'parallel_cucumber', '5.6.0')", "--",
                   "-n", "4", "--first-is-1", "--group-by", "filesize", "--test-options", Shellwords.join(args), File.join(FIXTURES, "parallel")]
                else
                  [RUBY, "-e", "load Gem.bin_path('cucumber', 'cucumber', '12.0.1')", "--", *args, File.join(FIXTURES, "tc15.feature")]
                end
      process = execute(environment, command, directory)
      process["afterall_expected"] = !parallel
      Cucumber12Live.write(File.join(directory, "process.json"), process)
      workers = Dir.glob(File.join(directory, "worker-*.json")).map { |path| JSON.parse(File.read(path)) }
      if parallel
        writer.call("PUT", "/api/v1/#{PROJECT}/launch/#{launch_uuid}/finish",
                    "endTime" => (Time.now.to_f * 1000).to_i.to_s, "status" => process.fetch("exit").zero? ? "PASSED" : "FAILED")
      else
        launch_uuid = observer.records.find { |entry| entry["method"] == "POST" && entry["path"].end_with?("/launch") }.fetch("response").fetch("id")
      end
      wire = observer.records
      uuids = item_starts(wire).filter_map { |entry| entry.dig("response", "id") }.uniq
      snapshot = nil
      deadline = Cucumber12Live.now + 30
      loop do
        snapshot = client.snapshot(launch_uuid, uuids)
        break if snapshot.fetch("items").all? { |item| item["endTime"] } && snapshot.dig("launch", "endTime") && snapshot.fetch("logs").length == (parallel ? 38 : 61)
        break if Cucumber12Live.now >= deadline
        sleep 0.25
      end
      Cucumber12Live.write(File.join(directory, "snapshot.json"), snapshot)
      Cucumber12Live.write(File.join(directory, "queries.json"), client.queries)
      result = gates(wire, snapshot, workers, process, expected_items: parallel ? 36 : 52,
                     expected_logs: parallel ? 38 : 61, async: async, parallel: parallel)
      result.merge!("launch_uuid" => launch_uuid, "launch_name" => name,
                    "launch_id" => snapshot.dig("launch", "id"), "reporting_async" => async,
                    "ui_url" => "#{ENDPOINT}/ui/##{PROJECT}/launches/all/#{snapshot.dig('launch', 'id')}")
      result["expectation_mismatch"] = parallel ?
        "SDK autonomous distributed finish and lock cleanup are excluded; only CI orchestrator start/finish is supported." :
        "use_same_thread_for_reporting is not a supported SDK configuration. RP_REPORTING_ASYNC selects API v1/v2, not a caller-thread/background-thread switch."
      Cucumber12Live.write(File.join(directory, "result.json"), result)
      result
    ensure
      observer&.close
    end

    def main
      Cucumber12Live.preflight!
      artifact = File.join(SDK_HOME, "cache/reportportal-cucumber-ruby-2.0.0.gem")
      raise "Wrong installed candidate" unless Digest::SHA256.file(artifact).hexdigest == GEM_SHA
      if ARGV.first == "--audit"
        directory = File.expand_path(ARGV.fetch(1))
        raise "Audit path outside owned evidence" unless directory.start_with?(File.join(ROOT, "tmp/cucumber12-independent/live/"))
        wire = JSON.parse(File.read(File.join(directory, "wire.json")))
        launch_uuid = wire.find { |entry| entry["method"] == "POST" && entry["path"].end_with?("/launch") }.fetch("response").fetch("id")
        client = Client.new(Cucumber12Live.token)
        snapshot = client.snapshot(launch_uuid, item_starts(wire).map { |entry| entry.fetch("response").fetch("id") }.uniq)
        workers = Dir.glob(File.join(directory, "worker-*.json")).map { |path| JSON.parse(File.read(path)) }
        process = JSON.parse(File.read(File.join(directory, "process.json")))
        parallel = File.basename(directory).include?("TC16")
        result = gates(wire, snapshot, workers, process, expected_items: parallel ? 36 : 52,
                       expected_logs: parallel ? 38 : (process["afterall_expected"] ? 61 : 60), async: File.basename(directory).include?("v2"), parallel: parallel)
        result.merge!("launch_uuid" => launch_uuid, "launch_id" => snapshot.dig("launch", "id"), "read_only_reaudit" => true)
        Cucumber12Live.write(File.join(directory, "snapshot.json"), snapshot)
        Cucumber12Live.write(File.join(directory, "queries.json"), client.queries)
        Cucumber12Live.write(File.join(directory, "result.json"), result)
        puts JSON.generate(result)
        return result["pass"] ? 0 : 1
      end
      output = File.join(ROOT, "tmp/cucumber12-independent/live", "run-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}")
      FileUtils.mkdir_p(output)
      Cucumber12Live.write(File.join(output, "provenance.json"),
                           "gem_archive" => artifact, "sha256" => GEM_SHA, "installed_gem_home" => SDK_HOME,
                           "package_sha256" => GEM_SHA, "sha_environment" => "C12_PACKAGE_SHA256",
                           "cached_dependency_path" => CACHED_GEMS,
                           "source_commit" => ENV["C12_SOURCE_COMMIT"] || (GEM_SHA == BASELINE_GEM_SHA ? "e7dae2b2bc7559339a796d657a4e1219e7f6b0aa" : nil),
                           "unsupported_config_not_used" => "use_same_thread_for_reporting",
                           "modes" => { "RP_REPORTING_ASYNC=false" => "/api/v1", "RP_REPORTING_ASYNC=true" => "/api/v2" })
      token = Cucumber12Live.token
      results = {}
      [["TC15-v1", false, false], ["TC15-v2", true, false], ["TC16-4workers", false, true]].each do |label, async, parallel|
        next if ENV["C12_ONLY"] && !ENV.fetch("C12_ONLY").split(",").include?(label)
        results[label] = run_case(token, File.join(output, label), async: async, parallel: parallel)
        puts JSON.generate(label: label, pass: results[label]["pass"], launch: results[label]["launch_uuid"], failed_gates: results[label]["checks"].reject { |_, value| value }.keys)
      end
      Cucumber12Live.write(File.join(output, "summary.json"), results)
      puts "Evidence: #{output}"
      results.values.all? { |result| result["pass"] } ? 0 : 1
    end
  end
end

exit Cucumber12Live::Runner.main if $PROGRAM_NAME == __FILE__
