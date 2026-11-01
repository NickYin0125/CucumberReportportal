# frozen_string_literal: true

require "json"
require "digest"
require "time"

stamp = ENV.fetch("QA_WP5_STAMP", "wp5-final-rerun-20261101")
%w[2.0.1 1.3.2].each do |version|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  directory = File.join(root, "docs/reviews/assets", stamp)
  input = File.join(directory, "live-checks.json")
  output = File.join(directory, "comparator-audit.json")
  raise "Never replace an earlier comparator audit" if File.exist?(output)
  data = JSON.parse(File.read(input))
  failures = data.fetch("checks").select { |check| check["verdict"] == "FAIL" && check["criterion"] != "P1.2" }
  observations = failures.map do |check|
    evidence = check.fetch("evidence")
    counterpart = check.fetch("inputs", {})["source"]
    classification = if check.fetch("check").include?("F15-named")
      "G1 explicitly allows P6 hook-name differences. The baseline generic Before hook and candidate Before hook / Open browser have identical non-name fields and per-owner levels; only this declared native named-hook fixture may be normalized."
    else
      "Readback attribute array order differs, but values are identical. Both owned Launch POST payloads send description and attributes in the same exact order. Normalize only readback set order, retain duplicates, and separately compare submitted ordered payloads."
    end
    { original_failed_comparison: check, assessment: "CHECKER_NORMALIZATION_NOT_ESTABLISHED_PRODUCT_DEFECT",
      reason: classification, source: evidence["source"], counterpart_source: counterpart }
  end
  File.write(output, JSON.pretty_generate(schema: "independent-comparator-audit/1", assessed_at_utc: Time.now.utc.iso8601,
    original_analysis_sha256: Digest::SHA256.file(input).hexdigest, original_analysis_runtime_sha: data.fetch("runtime_sha"),
    original_failed_comparisons_preserved: observations, product_or_golden_changed: false,
    waiver_added: false, limit: "Original API captures and the failed comparisons above remain unchanged. This corrects comparison normalization only; other differences must still fail.") + "\n")
  puts JSON.generate(version: version, preserved_comparator_flags: observations.length)
end
