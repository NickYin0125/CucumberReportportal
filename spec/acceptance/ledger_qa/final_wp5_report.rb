# frozen_string_literal: true

require_relative "final_wp5_analyze"

stamp = ENV.fetch("QA_WP5_STAMP", "wp5-final-20261101")
heads = LedgerQAAnalysis::WP5Study::FINAL_HEADS
targets = LedgerQAAnalysis::WP5Study::TARGETS
collect_ids = lambda do |value, key|
  case value
  when Hash
    value.flat_map do |name, child|
      if ["#{key}_id", "#{key}_ids"].include?(name.to_s)
        Array(child).select { |id| id.is_a?(Integer) }
      else
        collect_ids.call(child, key)
      end
    end
  when Array then value.flat_map { |child| collect_ids.call(child, key) }
  else []
  end.uniq.sort
end
escape = ->(text) { text.to_s.gsub("\n", " ").gsub("|", "\\|") }
heads.each do |version, head|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  assets = File.join(root, "docs/reviews/assets")
  path = File.join(assets, "presentation-ledger-#{version}-acceptance.json")
  data = JSON.parse(File.read(path))
  raw = JSON.parse(File.read(File.join(assets, stamp, "checks.json")))
  qa_head = Open3.capture2("git", "-C", root, "rev-parse", "HEAD").first.strip
  if !data.key?("wp5_prior_criterion_states")
    data["wp5_prior_criterion_states"] = { qa_commit: qa_head, runtime_sha: data["tested_runtime_head"], candidate_sha: data["candidate_head"],
      report_date: data["report_date"], status: data["status"], criteria: Marshal.load(Marshal.dump(data.fetch("criteria"))) }
  end
  if data.key?("candidate_runtime_binding")
    data["wp5_prior_criterion_states"]["candidate_runtime_binding"] = data.delete("candidate_runtime_binding")
  end
  data["final_matrix_stamp"] = stamp
  # Original Q records are immutable. New captures have a separate namespace.
  data["checks"].reject! { |row| row["check_id"].to_s.start_with?("WP5-") }
  fresh = raw.fetch("checks").each_with_index.map { |row, index| row.merge("check_id" => format("WP5-%05d", index + 1)) }
  data["checks"].concat(fresh)
  by_id = data["checks"].to_h { |row| [row["check_id"], row] }
  data.fetch("criteria").each do |row|
    id = row.fetch("id")
    selected = targets.include?(id) ? fresh.select { |check| check["criterion"] == id } : row.fetch("check_ids").map { |cid| by_id.fetch(cid) }
    if targets.include?(id)
      row["check_ids"] = selected.map { |check| check["check_id"] }
      verdicts = selected.map { |check| check["verdict"] }
      row["verdict"] = if selected.empty? || verdicts.include?("BLOCKED") then "BLOCKED"
                       elsif verdicts.include?("FAIL") then "FAIL"
                       elsif verdicts.all? { |verdict| %w[PASS N/A].include?(verdict) } then "PASS"
                       else "BLOCKED" end
      row["verdict"] = "FAIL" if verdicts.include?("FAIL")
      runtime = head
    else
      runtime = data["wp5_prior_criterion_states"]["runtime_sha"]
    end
    launch_ids = collect_ids.call(selected.map { |c| c.slice("evidence", "inputs", "actual") }, "launch")
    log_ids = collect_ids.call(selected.map { |c| c.slice("evidence", "inputs", "actual") }, "log")
    item_ids = collect_ids.call(selected.map { |c| c.slice("evidence", "inputs", "actual") }, "item")
    log_ids = [] if %w[G1 P2.4 P4.1 P4.2 P4.3 P4.4 P6.1 P6.2 P6.4 P7.3 P9.1 P9.2 P9.3 P9.4 P9.5].include?(id) || id.start_with?("V")
    row["evidence_launch_ids"] = launch_ids
    row["evidence_log_ids"] = log_ids
    row["evidence_item_ids"] = item_ids
    row["assessment_runtime_sha"] = runtime
    row["assessment_scope"] = targets.include?(id) ? "WP5 final runtime, fresh captures only" : "Historical scope retained unchanged; not re-scored by WP5 authorization"
    failures = selected.select { |check| check["verdict"] == "FAIL" }
    blocked = selected.select { |check| check["verdict"] == "BLOCKED" }
    comparison = selected.find { |check| check["verdict"] == "FAIL" } || selected.find { |check| check["verdict"] == "BLOCKED" } || selected.first
    outcome = if !failures.empty? then "#{failures.length} failed comparison(s): #{failures.map { |c| c['check'] }.uniq.join('; ')}"
              elsif !blocked.empty? then "Required proof missing: #{blocked.map { |c| c['check'] }.uniq.join('; ')}"
              elsif comparison then "#{selected.length} checks agree; representative comparison: #{comparison['check']}"
              else "No required proof exists" end
    launches = launch_ids.empty? ? "Launch N/A (#{selected.map { |c| c['method'] }.compact.uniq.join('/')}; no live proof claimed)" : "Launches #{launch_ids.join(', ')}"
    row["current_note"] = "#{id} compares #{row['requirement']}; #{outcome}. Comparison #{launches}; assessed candidate runtime SHA #{runtime}; individual sources distinguish candidate and frozen-baseline Launches."
    row["current_note"] = "Historical-only, not a new execution: #{row['current_note']}" unless targets.include?(id)
  end
  musts = data["criteria"].select { |row| row["level"] == "MUST" }
  status = if musts.any? { |row| row["verdict"] == "FAIL" } then "REJECT"
           elsif musts.any? { |row| !%w[PASS N/A].include?(row["verdict"]) } then "BLOCKED"
           else "ACCEPT" end
  data.merge!("status" => status, "candidate_head" => head, "tested_runtime_head" => head, "qa_branch" => "qa/presentation-ledger-#{version}",
    "report_date" => "2026-11-01 Asia/Shanghai", "signoff" => status == "ACCEPT" ? "QA_ACCEPTANCE_ONLY_NOT_RELEASE_AUTHORIZATION" : "NOT_SIGNED",
    "wp5_finalization" => { "stamp" => stamp, "runtime_sha" => head, "qa_parent_commit" => qa_head, "updated_at_utc" => Time.now.utc.iso8601,
      "authorized_criteria" => targets, "new_evidence" => "docs/reviews/assets/#{stamp}/checks.json",
      "history" => "Original Q check objects and prior criterion states remain unchanged; WP5 uses only new WP5 records. No old Launch has been modified or relabelled.",
      "performance" => "SHOULD p95 <2 ms retained, same F01-F18 actual-input replay; early contended attempt excluded.",
      "publication" => "No push, protected-branch update, merge, tag or publication authorized or performed." })
  File.write(path, JSON.pretty_generate(data) + "\n")

  lines = ["# Ledger presentation acceptance - #{version}", "",
    "Verdict: #{status}. Date: 2026-11-01 (Asia/Shanghai). Tester: Independent Ledger QA. Branch: `qa/presentation-ledger-#{version}`. Final runtime head: `#{head}`. Baseline: `#{data['baseline_head']}`. RP UI 5.15.6 / server 26.0.7.", "",
    "WP5 re-scores only G1-G12, P1.1-P1.10, P5.1-P5.8, P8.1-P8.9, P10.1-P10.11 and V1-V8 at the final runtime head. Other criterion states are explicitly historical, not new final-head executions. Every original Q check is preserved in the evidence JSON and prior report commits. Developer Launches are not acceptance evidence. No new waiver is inferred.", "",
    "## Runs", "| Run | Ruby | Cucumber | Mode | RSpec (examples/failures/pending) | Cucumber (scenarios/steps) | Launch IDs |", "| --- | --- | --- | --- | --- | --- | --- |"]
  (version == "1.3.2" ? %w[M1 M2 M3 M4] : %w[M5 M6]).each do |cell|
    result_path = Dir[File.join(assets, "wp5-final-20261101*/matrix/#{cell}/**/result.json")].select { |p| p.end_with?("/matrix/#{cell}/result.json", "/qa-cell-evidence/result.json") }.sort.last
    result = result_path && JSON.parse(File.read(result_path))
    if result
      lines << "| #{cell} | #{result.dig('runtime', 'ruby')} | #{result.dig('runtime', 'cucumber')} | offline plain | #{result.fetch('rspec', {}).values_at('example_count', 'failure_count', 'pending_count').join('/')} | #{result.fetch('cucumber', {}).values_at('scenarios', 'steps').join('/')} | Offline; #{result['status']} |"
    else
      lines << "| #{cell} | Required final runtime | Required pinned version | offline plain | BLOCKED: not finished | Pending | None claimed |"
    end
  end
  Dir[File.join(assets, "ledger-qa-live/#{stamp}-*/provenance.json")].sort.each do |provenance|
    value = JSON.parse(File.read(provenance))
    dir = File.dirname(provenance)
    ids = Dir[File.join(dir, "*/snapshot.json")].flat_map { |p| JSON.parse(File.read(p)).fetch("launches", []).map { |l| l["id"] } }.uniq.sort
    runtime = value.fetch("runtime")
    lines << "| #{File.basename(dir)} | #{runtime['ruby']} | #{runtime['cucumber']} | #{File.basename(dir).include?('rich') ? 'rich' : 'plain/default/baseline as named'} | Not a suite replacement | Fresh fixture outputs retained | #{ids.join(', ')} |"
  end
  lines += ["", "The early contended timing attempt is retained but is not G11 acceptance proof. Native compound syntax is N/A on legacy only under Decision 4; explicit separate companions remain required. F06 is N/A on 1.x. Decision 8 applies only to the six named legacy NUL-preview files, not to other log/attachment losses.", "",
    "## Results by criterion", "| ID | Level | Verdict (PASS/FAIL/N/A/BLOCKED) | Evidence (log/item IDs, file, screenshot) | Note |", "| --- | --- | --- | --- | --- |"]
  data["criteria"].each do |row|
    evidence = "[#{row['check_ids'].length} checks](assets/presentation-ledger-#{version}-acceptance.json); logs #{row['evidence_log_ids'].empty? ? 'N/A' : row['evidence_log_ids'].join(', ')}; items #{row['evidence_item_ids'].empty? ? 'N/A' : row['evidence_item_ids'].join(', ')}"
    lines << "| #{row['id']} | #{row['level']} | #{row['verdict']} | #{evidence} | #{escape.call(row['current_note'])} |"
  end
  lines += ["", "## Defects", "| # | Severity | Criterion | Fixture | Expected | Actual | Evidence |", "| --- | --- | --- | --- | --- | --- | --- |"]
  failures = fresh.select { |check| check["verdict"] == "FAIL" }
  severity = lambda do |id|
    return "S3" if %w[G11 P1.10 P10.11].include?(id)
    %w[G1 G2 G3 G7 G8 G9 P1.7 P8.7 P10.7].include?(id) ? "S1" : "S2"
  end
  failures.sort_by { |check| [severity.call(check["criterion"]), check["criterion"], check["check"]] }.each_with_index do |check, index|
    expected = JSON.generate(check["expected"])
    actual = JSON.generate(check["actual"])
    lines << "| WP5-D#{format('%03d', index + 1)} | #{severity.call(check['criterion'])} | #{check['criterion']} | #{escape.call(check['check'])} | #{escape.call(expected[0, 180])} | #{escape.call(actual[0, 180])}; full values in JSON | #{check['check_id']} |"
  end
  lines << "No demonstrated fresh product failure so far; BLOCKED criteria are missing proof, not PASS." if failures.empty?
  lines += ["", "## Screenshots", "Historical screenshots remain at their original Launches/runtime and are not relabelled final. Fresh final-head captures and DOM observations are indexed separately below."]
  screenshot_file = File.join(assets, stamp, "screenshots.json")
  if File.file?(screenshot_file)
    JSON.parse(File.read(screenshot_file)).each { |shot| lines << "- #{shot['slug']}: Launch #{shot['launch_id']}; item #{shot['item_id']}; log #{Array(shot['log_ids']).join(', ')}; #{shot['verdict']}; [image](#{shot['path'].delete_prefix('docs/reviews/')})." }
  else
    lines << "Fresh S01-S12 set: BLOCKED until final-run criteria analysis and visual protocol are complete. No screenshot PASS is claimed."
  end
  lines += ["", "## Waivers", "Only the supplied owner Decisions 1-14 and recorded clarifications apply. No additional waiver is requested or applied by this report. The source below is quoted without changing historical evidence.", ""]
  decisions = File.read(File.join("/Users/nick/Documents/crr-#{version}", "docs/design/presentation-ledger-owner-decisions.md"))
  lines.concat(decisions.lines.map { |line| line.strip.empty? ? ">" : "> #{line.rstrip}" })
  File.write(File.join(root, "docs/reviews/2026-11-01-presentation-ledger-#{version}-acceptance.md"), lines.join("\n") + "\n")
  puts JSON.generate(version: version, status: status, fresh_checks: fresh.length, blocked_criteria: data["criteria"].select { |r| r["verdict"] == "BLOCKED" }.map { |r| r["id"] }, failures: failures.length)
end
