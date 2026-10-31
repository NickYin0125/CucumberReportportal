# frozen_string_literal: true

require_relative "cucumber12_live"

module Cucumber12Live
  module OwnershipProbes
    module_function

    def run(token, directory, external:)
      FileUtils.mkdir_p(directory)
      observer = Observer.new(directory)
      writer = Client.new(token, endpoint: observer.endpoint)
      client = Client.new(token)
      name = "c12-independent-C-#{external ? 'external-one-worker' : 'at-exit'}-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(3)}"
      uuid = if external
               writer.call("POST", "/api/v1/#{PROJECT}/launch", "name" => name,
                           "startTime" => (Time.now.to_f * 1000).to_i.to_s, "mode" => "DEFAULT").fetch("id")
             end
      env = Runner.child_environment(token, observer, directory, async: false, launch_name: name, launch_uuid: uuid)
      env.merge!("C12_LIVE_AFTERALL" => "false", "C12_LIVE_FORCE_EXIT" => (!external).to_s)
      args = ["--no-profile", "--require", File.join(FIXTURES, "support/env.rb"), "--format", "progress",
              "--format", "ReportPortal::Cucumber::Formatter", "--out", File.join(directory, "rp.out"),
              "--format", "Cucumber12LiveAudit", "--out", File.join(directory, "audit.out"), File.join(FIXTURES, "fallback.feature")]
      process = Runner.execute(env, [RUBY, "-e", "load Gem.bin_path('cucumber', 'cucumber', '12.0.1')", "--", *args], directory)
      wire_before = observer.records
      uuid ||= wire_before.find { |entry| entry["method"] == "POST" && entry.fetch("path").end_with?("/launch") }.fetch("response").fetch("id")
      before = client.get("launch/uuid/#{uuid}")
      if external
        writer.call("PUT", "/api/v1/#{PROJECT}/launch/#{uuid}/finish",
                    "endTime" => (Time.now.to_f * 1000).to_i.to_s, "status" => "PASSED")
      end
      wire = observer.records
      snapshot = client.snapshot(uuid, Runner.item_starts(wire).map { |entry| entry.fetch("response").fetch("id") }.uniq)
      worker = JSON.parse(File.read(File.join(directory, "worker-single.json")))
      expected_png_sha = ENV["C12_PNG_DIR"] ? Digest::SHA256.file(File.join(ENV.fetch("C12_PNG_DIR"), "screenshot-01.png")).hexdigest : PNG_SHA
      launch_writes_before = wire_before.select { |entry| entry.fetch("path", "").match?(%r{/launch(?:/[^/]+/finish)?$}) && entry["method"] != "GET" }
      checks = {
        "native_exit_preserved" => process["exit"] == (external ? 0 : 7),
        "all_three_nodes_queried_and_finished" => snapshot.fetch("items").size == 3 && snapshot.fetch("items").all? { |item| item["endTime"] && item["status"] != "IN_PROGRESS" },
        "final_launch_closed_correctly" => snapshot.dig("launch", "status") == (external ? "PASSED" : "INTERRUPTED") && !!snapshot.dig("launch", "endTime"),
        "ownership_before_orchestrator_finish" => external ? before["status"] == "IN_PROGRESS" && launch_writes_before.length == 1 && launch_writes_before.first["actor"] == "orchestrator" : before["status"] == "INTERRUPTED" && launch_writes_before.length == 2,
        "two_logs_persisted" => snapshot.fetch("logs").size == 2 && worker.dig("receipt", "confirmed") == 2,
        "zero_pending_and_closed_worker" => worker.dig("receipt", "pending") == 0 && worker.dig("receipt", "complete") && worker.dig("diagnostics", "closed") && !worker.dig("diagnostics", "worker_alive"),
        "fallback_without_native_run_finished" => external || worker.fetch("events").none? { |event| event["event"] == "run_finished" },
        "bounded_under_5000ms" => (process.fetch("finished") - process.fetch("started")) * 1000 <= 5000,
        "one_png_downloaded_exactly" => snapshot.fetch("downloaded_files").size == 1 && snapshot.fetch("downloaded_files").first["sha256"] == expected_png_sha,
        "no_reporting_http_or_thread_errors" => wire.all? { |entry| entry["status"] && (200..299).cover?(entry["status"]) } && worker.dig("diagnostics", "counters", "worker_failed") == 0 && !process.fetch("stderr").match?(/terminated with exception|report_on_exception/)
      }
      result = { "pass" => checks.values.all?, "checks" => checks, "launch_uuid" => uuid,
                 "launch_id" => snapshot.dig("launch", "id"), "native_exit" => process["exit"], "package_sha256" => GEM_SHA,
                 "receipt" => worker["receipt"], "seconds" => process.fetch("finished") - process.fetch("started"),
                 "note" => external ? "Even one ordinary Formatter worker must not finish an explicitly supplied launch UUID." :
                   "External observer exits after first step-finished event. Native run-finished/AfterAll are not reached; SDK at_exit closes the owned launch INTERRUPTED, not PASSED." }
      Cucumber12Live.write(File.join(directory, "before-orchestrator-finish.json"), before)
      Cucumber12Live.write(File.join(directory, "snapshot.json"), snapshot)
      Cucumber12Live.write(File.join(directory, "queries.json"), client.queries)
      Cucumber12Live.write(File.join(directory, "result.json"), result)
      puts JSON.generate(result)
      result
    ensure
      observer&.close
    end
  end
end

if $PROGRAM_NAME == __FILE__
  Cucumber12Live.preflight!
  root = File.join(Cucumber12Live::ROOT, "tmp/cucumber12-independent/live", "ownership-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}")
  token = Cucumber12Live.token
  results = [false, true].map do |external|
    Cucumber12Live::OwnershipProbes.run(token, File.join(root, external ? "external-one-worker" : "at-exit"), external: external)
  end
  Cucumber12Live.write(File.join(root, "summary.json"), results)
  exit(results.all? { |result| result["pass"] } ? 0 : 1)
end
