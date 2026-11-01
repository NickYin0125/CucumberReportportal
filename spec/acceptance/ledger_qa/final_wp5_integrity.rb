# frozen_string_literal: true

require "json"
require "open3"
require "digest"
require_relative "final_wp5_context"
require_relative "final_wp5_id_ranges"

LedgerWP5Context.heads.each do |version, tested|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  assets = File.join(root, "docs/reviews/assets")
  path = File.join(assets, "presentation-ledger-#{version}-acceptance.json")
  data = JSON.parse(File.read(path))
  original_bytes, status = Open3.capture2("git", "-C", root, "show", "HEAD:docs/reviews/assets/presentation-ledger-#{version}-acceptance.json")
  raise "Original checkpoint unreadable" unless status.success?
  original = JSON.parse(original_bytes)
  checks = data.fetch("checks")
  by_id = checks.to_h { |check| [check.fetch("check_id"), check] }
  raise "Duplicate IDs" unless checks.length == by_id.length
  raise "Old Q or WP5 object changed" unless original.fetch("checks").all? { |check| by_id[check.fetch("check_id")] == check }
  mapping = data.dig("wp5_prior_criterion_states", "draft_history_id_repair", "original_to_draft_ids")
  witness = File.join(assets, LedgerWP5Context.stamp, "master-history-before-repair.json")
  variants_verified = 0
  if File.file?(witness)
    JSON.parse(File.read(witness)).fetch("changed").each do |row|
      draft = row.fetch("draft_variant")
      alias_id = mapping.fetch(draft.fetch("check_id"))
      preserved = by_id.fetch(alias_id)
      raise "Raw draft object changed" unless preserved.dig("draft_history_provenance", "raw_draft_object") == draft
      raise "Draft values changed" unless preserved.reject { |key, _| %w[check_id draft_history_provenance].include?(key) } == draft.reject { |key, _| key == "check_id" }
      variants_verified += 1
    end
  end
  visit = lambda do |value|
    case value
    when Hash
      value.each do |key, child|
        raise "Unresolved criterion check ID" if key == "check_ids" && child.any? { |id| !by_id.key?(id) }
        visit.call(child)
      end
    when Array then value.each { |child| visit.call(child) }
    end
  end
  visit.call(data)
  report = File.read(File.join(root, "docs/reviews/2026-11-01-presentation-ledger-#{version}-acceptance.md"))
  round_trips = 0
  data.fetch("criteria").each do |row|
    anchor = "#{row['id'].downcase.tr('.', '-')}-id-ranges"
    body = report.split("<a id=\"#{anchor}\"></a>", 2).last&.split("</details>", 2)&.first
    raise "ID appendix missing" unless body
    { "Launches" => "evidence_launch_ids", "Items" => "evidence_item_ids", "Logs" => "evidence_log_ids" }.each do |label, key|
      text = body.lines.find { |line| line.start_with?("#{label}: ") }&.delete_prefix("#{label}: ")&.strip
      raise "Rendered ID membership differs" unless text && LedgerQAIdRanges.decode(text) == row.fetch(key).sort
      round_trips += 1
    end
    raise "Runtime omitted from note" unless row.fetch("current_note").include?(row.fetch("assessment_runtime_sha"))
  end
  raise "Oversized evidence JSON" unless File.size(path) < 100 * 1024 * 1024
  raise "Fresh exit missing" unless data.dig("final_exit", "verdict") == "PASS"
  result = { scope: "Independent final evidence-index and Markdown membership integrity; no product rerun", verdict: "PASS",
    original_committed_checks_preserved: original.fetch("checks").length, original_q_preserved: original.fetch("checks").count { |check| check["check_id"].start_with?("Q") },
    draft_variants_verified_against_master_before_witness: variants_verified, unique_check_ids: checks.length,
    rendered_id_range_round_trips: round_trips, all_historical_and_current_criterion_refs_resolve: true,
    acceptance_json_bytes: File.size(path), acceptance_json_sha256: Digest::SHA256.file(path).hexdigest,
    report_sha256: Digest::SHA256.hexdigest(report), actual_tested_runtime: tested, candidate: data.fetch("candidate_head"),
    status: data.fetch("status"), final_screenshot_groups_missing: data.dig("final_exit", "missing_fresh_screenshot_groups") }
  output = File.join(assets, LedgerWP5Context.stamp, "independent-final-integrity.json")
  raise "Preserve prior integrity proof" if File.exist?(output)
  File.write(output, JSON.pretty_generate(result) + "\n")
  puts JSON.generate(result)
end
