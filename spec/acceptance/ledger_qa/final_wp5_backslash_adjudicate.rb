# frozen_string_literal: true

require "json"
require "digest"
require "time"
require_relative "final_wp5_context"

%w[2.0.1 1.3.2].each do |version|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  stamp = LedgerWP5Context.stamp
  directory = File.join(root, "docs/reviews/assets", stamp, "backslash")
  original = File.join(directory, "comparison.json")
  approval_path = File.join(root, "docs/reviews/assets/wp5-final-20261101/owner-decision15.json")
  comparison = JSON.parse(File.read(original))
  output = File.join(directory, "comparison-decision15.json")
  raise "Never replace a prior owner adjudication" if File.exist?(output)
  approval = JSON.parse(File.read(approval_path))
  cases = comparison.fetch("comparisons").map do |row|
    final = row.fetch("captures").fetch("final")
    permitted = approval["decision"] == 15 && approval["raw_failure_input"] == comparison["raw_input"] &&
      final["raw_input_bytes"] == approval["raw_input_bytes"] && row["identical_native_error_and_backtrace"] &&
      row["captures"].values.all? { |capture| capture["status"] == "CAPTURED" } &&
      final["rp_message"] == approval["only_allowed_output"]
    { cucumber: row["cucumber"], classification: row["classification"], verdict: permitted ? "N/A" : "BLOCKED",
      decision: 15, owner_exact_answer: approval["owner_exact_answer"], scope: "Only this exact F14 failure input's title assertion; not a whole-criterion P1.2 PASS",
      final_launch_ids: final["launch_ids"], final_item_id: final["item_id"], final_log_id: final["log_id"], runtime_sha: final["runtime_sha"] }
  end
  record = { schema: "independent-backslash-decision15-adjudication/1", recorded_at_utc: Time.now.utc.iso8601,
    source_comparison: original.delete_prefix(root + "/"), source_comparison_sha256: Digest::SHA256.file(original).hexdigest,
    original_comparison_preserved: true, approval_source: approval_path.delete_prefix(root + "/"),
    note: "This separate adjudication applies only the explicit Decision15 approval without changing any native input, RP observation, golden or original comparison file. Earlier attempts' stale approval-pending metadata remains historical, not relabelled.", cases: cases }
  File.write(output, JSON.pretty_generate(record) + "\n")
  puts JSON.generate(version: version, cases: cases)
end
