# frozen_string_literal: true

require_relative "final_wp5_driver"

pre_heads = { "2.0.1" => "d363c87a29dbaf7db1c02169ac3650d0cd3caa93", "1.3.2" => "7761384a682cbaac66e31a09a477342612c0debb" }
raw_input = "back\\slash"
LedgerFinalWP5::LINES.each do |version, config|
  qa = "/Users/nick/Documents/crr-qa-#{version}"
  directory = File.join(qa, "docs/reviews/assets", LedgerFinalWP5::STAMP, "backslash")
  output = File.join(directory, "comparison.json")
  raise "Never replace a prior comparison" if File.exist?(output)
  approval_file = File.join(qa, "docs/reviews/assets/wp5-final-20261101/owner-decision15.json")
  approval = File.file?(approval_file) ? JSON.parse(File.read(approval_file)) : nil
  comparisons = config[:cucumbers].map do |cucumber|
    captures = %w[baseline pre-wp1 final].to_h do |label|
      folder = File.join(directory, "c#{cucumber}-#{label}/F14-negative")
      snapshot_path = File.join(folder, "snapshot.json")
      next [label, { status: "BLOCKED", required_source: snapshot_path }] unless File.file?(snapshot_path)
      snapshot = JSON.parse(File.read(snapshot_path))
      error = snapshot.fetch("logs").select { |log| log["level"] == "error" }.sort_by { |log| [log["time"], log["id"]] }.fetch(3)
      native_path = File.join(folder, "native.ndjson")
      native = File.readlines(native_path).map { |line| JSON.parse(line) }.filter_map do |row|
        result = row.dig("testStepFinished", "testStepResult")
        next unless result
        result if result.dig("exception", "message") == raw_input || result["message"].to_s.lines.first.to_s.chomp == "#{raw_input} (RuntimeError)"
      end
      guard = JSON.parse(File.read(File.join(folder, "source-guard.json")))
      raise "Raw input not uniquely established" unless native.length == 1
      source_sha = { "baseline" => config[:base], "pre-wp1" => pre_heads.fetch(version), "final" => config[:sha] }.fetch(label)
      runtime = JSON.parse(File.read(File.join(folder, "runtime.json")))
      sdk = File.dirname(runtime.dig("activation", "sdk_gemspec"))
      mismatches = runtime.fetch("loaded_sdk_sha256_at_start").filter_map do |path, actual|
        relative = path.delete_prefix(sdk + "/")
        bytes, status = Open3.capture2("git", "-C", qa, "show", "#{source_sha}:#{relative}")
        relative unless status.success? && Digest::SHA256.hexdigest(bytes) == actual
      end
      native_result = native.first.reject { |key, _| key == "duration" }
      [label, { status: guard["passed"] && mismatches.empty? ? "CAPTURED" : "BLOCKED", runtime_sha: source_sha,
        launch_ids: snapshot.fetch("launches").map { |launch| launch["id"] }, item_id: error["itemId"], log_id: error["id"],
        raw_input: raw_input, raw_input_bytes: raw_input.bytes, raw_input_sha256: Digest::SHA256.hexdigest(raw_input),
        native_original_result: native_result, native_result_sha256: Digest::SHA256.hexdigest(JSON.generate(native_result)),
        rp_message: error["message"], rp_message_sha256: Digest::SHA256.hexdigest(error["message"]),
        source_guard: guard, loaded_source_mismatches: mismatches, snapshot_source: snapshot_path.delete_prefix(qa + "/"),
        native_source: native_path.delete_prefix(qa + "/"), native_source_sha256: Digest::SHA256.file(native_path).hexdigest }]
    end
    complete = captures.values.all? { |capture| capture[:status] == "CAPTURED" }
    native_equal = complete && captures.values.map { |capture| capture[:native_result_sha256] }.uniq.length == 1
    final_equals_pre = complete && captures["final"][:rp_message] == captures["pre-wp1"][:rp_message]
    final_equals_base = complete && captures["final"][:rp_message] == captures["baseline"][:rp_message]
    classification = if !complete then "BLOCKED: independent live comparison not complete"
                     elsif !native_equal then "BLOCKED: native error/backtrace inputs differ; not a controlled comparison"
                     elsif final_equals_pre && final_equals_base then "Pre-existing frozen-baseline fail-closed output/spec contradiction; NOT a WP1 runtime regression"
                     elsif final_equals_pre then "Already present before WP1; differs from frozen baseline (legacy planned redaction parity requires separate attribution); NOT a WP1 runtime regression"
                     else "Final runtime output differs from pre-WP1 for identical native input; investigate as a runtime regression" end
    permitted = approval && complete && native_equal && approval["raw_failure_input"] == raw_input && captures["final"][:rp_message] == approval["only_allowed_output"]
    { cucumber: cucumber, captures: captures, identical_native_error_and_backtrace: native_equal,
      final_equals_pre_wp1: final_equals_pre, final_equals_baseline: final_equals_base, classification: classification,
      criterion: "P1.2", verdict: permitted ? "N/A" : "BLOCKED",
      owner_waiver_status: approval ? "Decision15 received: only this exact input's title assertion; never a whole P1.2 PASS" : "No owner approval; do not infer a waiver from equivalence" }
  end
  source_blobs = [config[:base], pre_heads.fetch(version), config[:sha]].to_h do |sha|
    [sha, LedgerFinalWP5.git(qa, "rev-parse", "#{sha}:lib/reportportal_cucumber/automation/evidence_redactor.rb")]
  end
  LedgerFinalWP5.write(output, schema: "independent-native-backslash-comparison/1", checked_at_utc: Time.now.utc.iso8601,
    raw_input: raw_input, raw_input_sha256: Digest::SHA256.hexdigest(raw_input), redactor_git_blobs: source_blobs,
    note: "All three inputs and RP messages come from this QA's new Launches. Master/developer observations are not evidence. Equal redactor blobs are source context, not a criterion PASS or waiver.", comparisons: comparisons)
  puts JSON.generate(version: version, comparisons: comparisons.map { |row| row.slice(:cucumber, :classification, :verdict, :final_equals_pre_wp1, :final_equals_baseline) })
end
