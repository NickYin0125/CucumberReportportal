# frozen_string_literal: true

require "json"
require "digest"
require_relative "analyze"

stamp = ARGV.fetch(0, "20261031T072147Z")
repair = ARGV[1]
%w[2.0.1 1.3.2].each do |version|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  base = File.join(root, "docs/reviews/assets/ledger-qa-live/#{stamp}")
  observations = []
  study = LedgerQAAnalysis::Study.new(root, stamp)
  Dir["#{base}-baseline/F{10,11,12}*/process.json"].sort.each do |old_path|
    fixture = File.basename(File.dirname(old_path))
    baseline = JSON.parse(File.read(old_path))
    (repair ? %w[plain-1 plain-2 rich-1 rich-2] : %w[plain-1 rich-1]).each do |mode|
      capture = repair ? File.join(root, "docs/reviews/assets/ledger-qa-live/#{repair}-terminal-repair-#{mode}") : "#{base}-#{mode}"
      path = "#{capture}/#{fixture}/process.json"
      next unless File.file?(path)
      current = JSON.parse(File.read(path))
      # Preserve the strict timestamp-only comparison. Separately identify
      # semantic output differences so native stopwatch noise is not a defect.
      without_timestamps = lambda { |text| text.gsub(/\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?/, "<timestamp>") }
      business = lambda { |text| without_timestamps.call(text).sub(/\n\d+ scenarios? \([^\n]*\).*\z/m, "") }
      expected = business.call(baseline.fetch("stdout"))
      actual = business.call(current.fetch("stdout"))
      old_snapshot = JSON.parse(File.read(File.join(File.dirname(old_path), "snapshot.json")))
      snapshot = JSON.parse(File.read(File.join(File.dirname(path), "snapshot.json")))
      snapshot["_directory"] = File.dirname(path)
      old_snapshot["_directory"] = File.dirname(old_path)
      guards = [old_path, path].map { |p| JSON.parse(File.read(File.join(File.dirname(p), "source-guard.json"))) }
      prior_path = "#{base}-#{mode}/#{fixture}/snapshot.json"
      prior = File.file?(prior_path) ? JSON.parse(File.read(prior_path)).merge("_directory" => File.dirname(prior_path)) : nil
      native_paths = [old_path, path].map { |p| File.join(File.dirname(p), "native.ndjson") }
      native_equal = native_paths.all? { |p| File.file?(p) } && study.normalized_native(native_paths[0]) == study.normalized_native(native_paths[1])
      rp_equal = prior && study.messages(prior) == study.messages(snapshot)
      observations << { criterion: "P8.8", fixture: fixture, mode: mode, method: "U",
        inputs: { baseline_process: old_path.delete_prefix(root + "/"), candidate_process: path.delete_prefix(root + "/"), source_guards: guards },
        baseline_launch_ids: old_snapshot.fetch("launches").map { |l| l["id"] },
        launch_ids: snapshot.fetch("launches").map { |l| l["id"] },
        item_ids: snapshot.fetch("items").map { |i| i["id"] }, log_ids: snapshot.fetch("logs").map { |l| l["id"] },
        expected: expected, actual: actual,
        timestamp_only_equal: without_timestamps.call(baseline.fetch("stdout")) == without_timestamps.call(current.fetch("stdout")),
        baseline_stdout_sha256: Digest::SHA256.hexdigest(baseline.fetch("stdout")),
        actual_stdout_sha256: Digest::SHA256.hexdigest(current.fetch("stdout")),
        native_ndjson_equal: native_equal, rp_payload_owner_messages_unchanged: rp_equal,
        prior_rp_snapshot: repair && prior_path.delete_prefix(root + "/"),
        rp_message_sha256: study.messages(snapshot).map { |owner, level, message| [owner, level, Digest::SHA256.hexdigest(message)] },
        verdict: expected == actual && guards.all? { |g| g["passed"] } ? "PASS" : "FAIL",
        note: "Business output compared after timestamp removal and excluding only Cucumber's final scenario/step/stopwatch summary; full original stdout retained in process files." }
    end
  end
  destination = File.join(root, "docs/reviews/assets/ledger-qa-terminal-audit-#{repair || stamp}.json")
  File.write(destination, JSON.pretty_generate(observations) + "\n")
  puts JSON.generate(version: version, checks: observations.length,
    native_failures: observations.count { |r| !r[:native_ndjson_equal] },
    rp_payload_changes: repair && observations.count { |r| !r[:rp_payload_owner_messages_unchanged] },
    semantic_failures: observations.select { |r| r[:verdict] == "FAIL" }.map { |r| [r[:fixture], r[:mode], r[:launch_ids]] })
end
