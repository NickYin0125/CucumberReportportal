# frozen_string_literal: true

require_relative "final_wp5_driver"

raise "Prepare only the exact final CI attempt" unless LedgerFinalWP5::STAMP == "wp5-ci-final-20261101"
LedgerFinalWP5::LINES.each do |version, config|
  qa = "/Users/nick/Documents/crr-qa-#{version}"
  sdk = LedgerFinalWP5.guard(version)
  directory = File.join(qa, "docs/reviews/assets", LedgerFinalWP5::STAMP)
  audit = JSON.parse(File.read(File.join(directory, "decision16-independent-audit.json")))
  raise "Decision16 exact diff not verified" unless audit["verdict"] == "PASS" && audit["runtime_sha"] == config.fetch(:sha)
  files = {
    "source-freeze.json" => { schema: "independent-final-source-freeze/1", runtime_sha: config.fetch(:sha),
      baseline_sha: config.fetch(:base), runtime_lib_tree: LedgerFinalWP5.git(sdk, "rev-parse", "#{config.fetch(:sha)}:lib"),
      prior_runtime_sha: audit.fetch("previous_sha"), final_stamp: LedgerFinalWP5::STAMP,
      same_g11_method_sha256: Digest::SHA256.file(File.join(__dir__, "performance_support.rb")).hexdigest,
      historical_attempt: "wp5-final-rerun-20261101 is preserved, not final-head evidence", diagnostic_observers_in_matrix: false },
    "owner-decision16.json" => { decision: 16, criterion: "V6", received_date: "2026-11-01",
      owner_exact_question: audit.fetch("owner_exact_question"), owner_exact_answer: audit.fetch("owner_exact_answer"),
      authorized_exception: "Only bounded test/CI diagnostics audited in decision16-independent-audit.json. No Helm/runtime/budget/existing-assertion change; no G10 waiver.",
      audit_status: "EXACT_NEW_HEAD_DIFF_VERIFIED", runtime_sha: config.fetch(:sha),
      source: "Direct owner authorization, independently matched to the exact committed owner-decisions document" },
    "certification-state.json" => { status: "PENDING_FRESH_FINAL_HEAD_VERIFICATION", requires_new_frozen_heads: false,
      reason: "Exact final test/CI heads are frozen. Fresh live, independent six-cell matrix, quiet unchanged G11 measurement and authenticated UI/DOM/S01-S12 proof must finish before acceptance.",
      ui_status: "BLOCKED_OWNER_SIGN_IN_REQUIRED", ui_observed_tab: "148298200", credentials_entered_by_qa: false,
      qa_commit_or_push_authorized: false }
  }
  files.each do |name, value|
    output = File.join(directory, name)
    raise "Never replace a prior source/authorization observation" if File.exist?(output)
    LedgerFinalWP5.write(output, value)
  end
  puts JSON.generate(version: version, runtime_sha: config.fetch(:sha), prepared: true)
end
