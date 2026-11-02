# frozen_string_literal: true

require_relative "host"
require "time"

root = Ledger202Host::ROOT
old = Ledger202Host::OUTPUT
current = File.join(root, "docs/reviews/assets/QA202-50b6d4d-20261102")
target = File.join(current, "ledger-freeze-manifest.json")
raise "Handoff already frozen" if File.exist?(target)
checks_path = File.join(old, "offline-review/checks.json")
checks_sha = "19bc83706a044baaa383f40ed3b90595d4fe029074276aee9302ffcbf7d4aa25"
raise "Historical check ledger changed" unless Digest::SHA256.file(checks_path).hexdigest == checks_sha
checks = JSON.parse(File.read(checks_path))
first_window = checks.fetch("inventory").select { |f| f["path"].include?("/quiet-090b-window-1/") }
raise "Original timing evidence changed" unless first_window.all? { |f| Digest::SHA256.file(File.join(root, f["path"])).hexdigest == f["sha256"] }
roots = [old, current, File.join(root, "docs/reviews/assets/ledger-2.0.2-preparation"),
  File.join(root, "docs/reviews/assets/qa-frozen-working"), __dir__]
files = roots.flat_map { |dir| Dir[File.join(dir, "**", "*")] }.select { |path| File.file?(path) }
files.concat(Dir[File.join(root, "features/presentation_ledger/qa_runtime/{QA202,C202}-*.feature")])
%w[2026-11-02-ledger-2.0.2-preparation.md 2026-11-02-ledger-2.0.2-acceptance.md
   2026-11-02-ledger-performance-developer-handoff.md 2026-11-02-ledger-final-blocked-addendum.md].each do |name|
  files << File.join(root, "docs/reviews", name)
end
manifest = files.uniq.sort.map do |path|
  { path: path.delete_prefix(root + "/"), bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest }
end
Ledger202Host.write_new(target,
  status: "FROZEN_FOR_MASTER_SCAN_COMMIT_PUSH", frozen_at_utc: Time.now.utc.iso8601,
  scope: "Ledger-owned new QA evidence, harness and explicit user-supplied standalone probe/logs only; no copied usability reviews read",
  historical_criteria: { PASS: 27, PENDING: 4, FAIL: 1 }, original_checks_sha256: checks_sha,
  original_timing_files_verified_unchanged: first_window.length,
  focused_window_2: "PREPARATION_BLOCKED_NOT_RUN", independent_security_probe_exit: 1,
  overall_G8: "BLOCKED", release: "NOT_ACCEPTED", later_test_only_commit: "NOT_YET_BOUND",
  new_live_launches_since_090b: [], commits_or_push_by_assessor: false, files: manifest)
puts JSON.generate(status: "FROZEN", files: manifest.length, bytes: manifest.sum { |f| f[:bytes] },
  manifest_sha256: Digest::SHA256.file(target).hexdigest, original_timing_files_unchanged: first_window.length)
