# frozen_string_literal: true

require_relative "cucumber12_live"

module Cucumber12Live
  module Previews
    module_function

    def run(token, root, nul:, plain: false)
      label = plain ? "native-nul-log" : (nul ? "nul-repro" : "visible-preview-control")
      directory = File.join(root, label)
      FileUtils.mkdir_p(directory)
      observer = Observer.new(directory)
      client = Client.new(token)
      env = Runner.child_environment(token, observer, directory, async: false,
                                     launch_name: "c12-independent-C-#{label}-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(3)}")
      env["C12_LIVE_AFTERALL"] = "false"
      feature = File.join(FIXTURES, plain ? "nul-log.feature" : (nul ? "nul.feature" : "previews.feature"))
      args = ["--no-profile", "--require", File.join(FIXTURES, "support/env.rb"), "--format", "progress",
              "--format", "ReportPortal::Cucumber::Formatter", "--out", File.join(directory, "rp.out"),
              "--format", "Cucumber12LiveAudit", "--out", File.join(directory, "audit.out"), feature]
      process = Runner.execute(env, [RUBY, "-e", "load Gem.bin_path('cucumber', 'cucumber', '12.0.1')", "--", *args], directory)
      wire = observer.records
      uuid = wire.find { |entry| entry["method"] == "POST" && entry.fetch("path").end_with?("/launch") }.fetch("response").fetch("id")
      sleep 2 if nul || plain
      snapshot = client.snapshot(uuid, Runner.item_starts(wire).map { |entry| entry.fetch("response").fetch("id") })
      worker = JSON.parse(File.read(File.join(directory, "worker-single.json")))
      logs = wire.flat_map { |entry| entry.fetch("entries", []) }
      files = wire.flat_map { |entry| entry.fetch("files", []) }
      downloaded = snapshot.fetch("downloaded_files")
      gates = {
        "exact_fixture_counts" => logs.length == (nul || plain ? 1 : 3) && files.length == (plain ? 0 : (nul ? 1 : 3)),
        "all_nodes_and_launch_finished" => snapshot.fetch("items").length == 3 && snapshot.fetch("items").all? { |item| item["endTime"] && item["status"] == "PASSED" } && snapshot.dig("launch", "status") == "PASSED",
        "all_records_persisted" => snapshot.fetch("logs").length == logs.length,
        "all_media_exact_downloaded_bytes" => files.map { |file| file.values_at("sha256", "bytes") }.sort == downloaded.map { |file| file.values_at("sha256", "bytes") }.sort,
        "zero_local_failures_and_correct_receipt" => process["exit"] == 0 && worker.dig("receipt", "complete") && worker.dig("receipt", "confirmed") == logs.length && worker.dig("receipt", "pending") == 0 && worker.dig("diagnostics", "counters", "worker_failed") == 0
      }
      if nul || plain
        gates["display_NUL_escaped_without_raw_NUL"] = logs.length == 1 && logs.first.fetch("message").include?('\\u0000') && !logs.first.fetch("message").include?("\0")
      end
      if nul
        original = "minimal\0NUL payload\n".b
        gates["original_NUL_attachment_bytes_unchanged"] = files.length == 1 &&
          files.first["sha256"] == Digest::SHA256.hexdigest(original) && files.first["bytes"] == original.bytesize
      end
      result = { "pass" => gates.values.all?, "label" => label, "checks" => gates,
                 "launch_uuid" => uuid, "launch_id" => snapshot.dig("launch", "id"),
                 "accepted" => logs.length, "persisted" => snapshot.fetch("logs").length, "package_sha256" => GEM_SHA,
                 "receipt" => worker.fetch("receipt"), "expected_NUL_failure_reproduced" => nul && logs.length == 1 && snapshot.fetch("logs").empty? }
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
  root = File.join(Cucumber12Live::ROOT, "tmp/cucumber12-independent/live", "previews-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}")
  token = Cucumber12Live.token
  results = [false, true].map { |nul| Cucumber12Live::Previews.run(token, root, nul: nul) }
  results << Cucumber12Live::Previews.run(token, root, nul: false, plain: true)
  Cucumber12Live.write(File.join(root, "summary.json"), results)
  exit(results.all? { |result| result["pass"] } ? 0 : 1)
end
