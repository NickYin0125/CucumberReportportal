# frozen_string_literal: true

require_relative "final_wp5_analyze"
require_relative "final_wp5_id_ranges"

stamp = LedgerWP5Context.stamp
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
value_summary = lambda do |value|
  text = JSON.generate(value)
  text.length <= 150 ? text : "#{value.class} with #{value.respond_to?(:length) ? value.length : 1} entries; SHA256 #{Digest::SHA256.hexdigest(text)[0, 16]} (full value in JSON)"
end
heads.each do |version, head|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  assets = File.join(root, "docs/reviews/assets")
  path = File.join(assets, "presentation-ledger-#{version}-acceptance.json")
  data = JSON.parse(File.read(path))
  raw = JSON.parse(File.read(File.join(assets, stamp, "checks.json")))
  approval_path = File.join(assets, "wp5-final-20261101", "owner-decision15.json")
  approval = File.file?(approval_path) ? JSON.parse(File.read(approval_path)) : nil
  ci_approval_path = File.join(assets, stamp, "owner-decision16.json")
  ci_approval = File.file?(ci_approval_path) ? JSON.parse(File.read(ci_approval_path)) : nil
  state_path = File.join(assets, stamp, "certification-state.json")
  state = File.file?(state_path) ? JSON.parse(File.read(state_path)) : nil
  parameter_path = File.join(assets, stamp, "f14-parameter-order-investigation.json")
  parameter_proof = File.file?(parameter_path) ? JSON.parse(File.read(parameter_path)) : nil
  parameter_approval_path = File.join(assets, stamp, "owner-decision18.json")
  parameter_approval = File.file?(parameter_approval_path) ? JSON.parse(File.read(parameter_approval_path)) : nil
  if parameter_approval
    raise "Decision18 scope mismatch" unless parameter_approval["decision"] == 18 && parameter_approval["cucumber"] == "10.2.0" &&
      parameter_approval["fixture"] == "F14" && parameter_approval["owner_exact_answer"] == "接受这项窄范围调整， 继续" &&
      parameter_approval["duplicate_multiplicity_retained"] == true && parameter_approval["ordered_post_bytes_still_strict"] == true
  end
  binding_path = File.join(assets, stamp, "docs-only-final-binding-r2.json")
  binding = File.file?(binding_path) ? JSON.parse(File.read(binding_path)) : nil
  raise "Candidate binding failed" if binding && (binding["verdict"] != "PASS" || binding["tested_runtime_head"] != head)
  candidate = binding ? binding.fetch("candidate_feature_head") : head
  api_order_observation = lambda do |check|
    next false unless parameter_proof && parameter_proof["runtime_sha"] == head &&
      parameter_proof.fetch("checks").all? { |c| c["verdict"] == "PASS" } &&
      check["criterion"] == "G1" && check["cucumber"] == "10.2.0" && check["check"].match?(/\AF14 (plain|rich) item tree\z/)
    normalize = lambda do |items|
      items.map do |item|
        params = item["parameters"]
        params.is_a?(Array) ? item.merge("parameters" => params.map { |entry| JSON.generate(entry.sort.to_h) }.sort) : item
      end
    end
    check["expected"] != check["actual"] && normalize.call(check["expected"]) == normalize.call(check["actual"])
  end
  exception = lambda do |check|
    api_order_observation.call(check) || (approval && approval["decision"] == 15 && approval["criterion"] == "P1.2" &&
      check["criterion"] == "P1.2" && check["check"].include?("F14") &&
      check.dig("inputs", "gherkin_value") == approval["raw_failure_input"] &&
      check["actual"] == approval["only_allowed_output"])
  end
  qa_head = Open3.capture2("git", "-C", root, "rev-parse", "HEAD").first.strip
  if !data.key?("wp5_prior_criterion_states")
    data["wp5_prior_criterion_states"] = { qa_commit: qa_head, runtime_sha: data["tested_runtime_head"], candidate_sha: data["candidate_head"],
      report_date: data["report_date"], status: data["status"], criteria: Marshal.load(Marshal.dump(data.fetch("criteria"))) }
  end
  checkpoint_key = "committed_in_progress_wp5_objects"
  original_bytes, original_status = Open3.capture2("git", "-C", root, "show", "#{qa_head}:docs/reviews/assets/presentation-ledger-#{version}-acceptance.json")
  raise "Original QA checkpoint unavailable" unless original_status.success?
  original_data = JSON.parse(original_bytes)
  original_wp5 = original_data.fetch("checks").reject { |check| check["check_id"].to_s.start_with?("Q") }
  unless data["wp5_prior_criterion_states"].key?(checkpoint_key)
    current_by_id = data.fetch("checks").to_h { |check| [check["check_id"], check] }
    reused = original_wp5.select { |check| current_by_id[check["check_id"]] != check }.map { |check| check["check_id"] }
    data["wp5_prior_criterion_states"][checkpoint_key] = { "qa_commit" => qa_head, "original_acceptance_sha256" => Digest::SHA256.hexdigest(original_bytes),
      "checks" => original_wp5, "earlier_draft_reused_ids" => reused,
      "scope" => "Verbatim committed in-progress WP5 objects retained inline in their original checkpoint namespace; an earlier draft reused some main-list IDs as jobs finished. Current raw checks, verdicts, inputs and IDs are not changed by this additive preservation. All Q objects already remain unchanged in the main list." }
  end
  repair_key = "draft_history_id_repair"
  unless data["wp5_prior_criterion_states"].key?(repair_key)
    current_by_id = data.fetch("checks").to_h { |check| [check["check_id"], check] }
    originals = original_data.fetch("checks").to_h { |check| [check["check_id"], check] }
    variants = original_wp5.filter_map do |original|
      draft = current_by_id[original["check_id"]]
      next if draft == original
      raise "Historical draft disappeared" unless draft
      id = "DRAFT-HISTORY-#{original.fetch('check_id')}"
      raise "Draft history ID collision" if current_by_id.key?(id)
      draft.merge("check_id" => id, "draft_history_provenance" => { "original_reused_id" => original.fetch("check_id"), "original_qa_checkpoint" => qa_head,
        "raw_draft_object" => draft, "scope" => "Later in-progress draft observation retained in a new namespace; original committed object restored at its original ID. No input, expected/actual value or verdict is discarded or changed." })
    end
    mapping = variants.to_h { |check| [check.dig("draft_history_provenance", "original_reused_id"), check.fetch("check_id")] }
    data["checks"].map! { |check| originals.fetch(check["check_id"], check) }
    data["checks"].concat(variants)
    data.fetch("superseded_wp5_attempts", []).each do |attempt|
      next unless attempt.dig("finalization", "stamp") == "wp5-final-20261101"
      attempt.fetch("criteria").each do |criterion|
        criterion["check_ids"] = criterion.fetch("check_ids").map do |id|
          variant = variants.find { |check| check.dig("draft_history_provenance", "original_reused_id") == id && check["criterion"] == criterion["id"] }
          variant ? variant.fetch("check_id") : id
        end
      end
    end
    data["wp5_prior_criterion_states"][repair_key] = { "original_qa_checkpoint" => qa_head, "original_to_draft_ids" => mapping,
      "master_before_repair_witness" => version == "1.3.2" ? "docs/reviews/assets/#{stamp}/master-history-before-repair.json" : nil,
      "scope" => "Original committed Q and WP5 objects remain verbatim at original IDs; full differing draft payloads remain inline under unique mapped IDs, including original raw objects; superseded draft criterion links follow their matching variant." }
  end
  preserved_by_id = data.fetch("checks").to_h { |check| [check["check_id"], check] }
  raise "Committed historical check object changed" unless original_data.fetch("checks").all? { |check| preserved_by_id[check["check_id"]] == check }
  if data.key?("candidate_runtime_binding")
    data["wp5_prior_criterion_states"]["candidate_runtime_binding"] ||= data["candidate_runtime_binding"]
  end
  data["final_matrix_stamp"] = stamp
  # Preserve the entire pre-repair WP5 attempt; it is not final-head proof.
  prefix = { "wp5-final-20261101" => "WP5-", "wp5-final-rerun-20261101" => "WP5R1-" }.fetch(stamp) { "WP5-#{Digest::SHA256.hexdigest(stamp)[0, 10]}-" }
  if data.dig("wp5_finalization", "stamp") && data.dig("wp5_finalization", "stamp") != stamp
    data["superseded_wp5_attempts"] ||= []
    previous = data.fetch("wp5_finalization")
    data["superseded_wp5_attempts"] << { "finalization" => previous, "status" => data["status"], "criteria" => Marshal.load(Marshal.dump(data["criteria"])) } unless data["superseded_wp5_attempts"].any? { |attempt| attempt.dig("finalization", "stamp") == previous["stamp"] }
  end
  data["checks"].reject! { |row| row["check_id"].to_s.start_with?(prefix) }
  fresh = raw.fetch("checks").each_with_index.map { |row, index| row.merge("check_id" => format("#{prefix}%05d", index + 1)) }
  data["checks"].concat(fresh)
  by_id = data["checks"].to_h { |row| [row["check_id"], row] }
  data.fetch("criteria").each do |row|
    id = row.fetch("id")
    selected = targets.include?(id) ? fresh.select { |check| check["criterion"] == id } : row.fetch("check_ids").map { |cid| by_id.fetch(cid) }
    if targets.include?(id)
      row["check_ids"] = selected.map { |check| check["check_id"] }
      verdicts = selected.map { |check| exception.call(check) ? "N/A" : check["verdict"] }
      row["verdict"] = if selected.empty? || verdicts.include?("BLOCKED") then "BLOCKED"
                       elsif verdicts.include?("FAIL") then "FAIL"
                       elsif verdicts.all? { |verdict| %w[PASS N/A].include?(verdict) } then "PASS"
                       else "BLOCKED" end
      row["verdict"] = "FAIL" if verdicts.include?("FAIL")
      if id == "P1.2" && !approval && selected.any? { |check| check["verdict"] == "FAIL" && check["check"].include?("F14") }
        row["verdict"] = "BLOCKED"
        row["adjudication"] = "Owner has not approved the narrowly scoped F14 backslash/fail-closed exception. Master explicitly instructed BLOCKED/not PASS; raw comparison failures remain unchanged."
      end
      if id == "P1.2" && approval
        row.delete("adjudication")
        row["approved_exceptions"] = { "decision" => 15, "owner_exact_answer" => approval["owner_exact_answer"], "raw_input" => approval["raw_failure_input"],
          "only_allowed_output" => approval["only_allowed_output"], "source" => approval_path.delete_prefix(root + "/"),
          "observation_check_ids" => selected.select { |check| exception.call(check) }.map { |check| check["check_id"] },
          "claim_limit" => "N/A only for this input's title assertion. Original FAIL comparisons remain byte-for-byte observations; all other title assertions must pass." }
      end
      if id == "G1" && parameter_proof && selected.any? { |check| api_order_observation.call(check) } && !parameter_approval
        row["verdict"] = "BLOCKED"
        row["adjudication"] = "Exact wire bytes are unchanged, but request/response DTOs are Lists despite Set persistence; API parameter-order exception needs explicit owner approval. No unordered response contract is claimed."
      end
      row.delete("adjudication") if id == "G1" && parameter_approval
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
    failures = selected.select { |check| check["verdict"] == "FAIL" && !exception.call(check) }
    blocked = selected.select { |check| check["verdict"] == "BLOCKED" }
    comparison = selected.find { |check| check["verdict"] == "FAIL" && !exception.call(check) } || selected.find { |check| check["verdict"] == "BLOCKED" } || selected.find { |check| !exception.call(check) }
    outcome = if !failures.empty? then "#{failures.length} failed comparison(s): #{failures.map { |c| c['check'] }.uniq.join('; ')}"
              elsif !blocked.empty? then "Required proof missing: #{blocked.map { |c| c['check'] }.uniq.join('; ')}"
              elsif comparison then "#{selected.count { |check| !exception.call(check) }} checks agree; #{selected.count { |check| exception.call(check) }} explicitly scoped exception/diagnostic observations retained; representative comparison: #{comparison['check']}"
              else "No required proof exists" end
    launches = launch_ids.empty? ? "Launch N/A (#{selected.map { |c| c['method'] }.compact.uniq.join('/')}; no live proof claimed)" : "Launches #{LedgerQAIdRanges.checked(launch_ids)}"
    comparison_values = comparison ? "#{comparison['check']}: expected #{value_summary.call(comparison['expected'])}, actual #{value_summary.call(comparison['actual'])}" : "Required comparison has no fresh observation"
    row["current_note"] = "Compared #{comparison_values}; #{selected.length} criterion-specific checks (#{row['verdict']}); #{launches}; runtime SHA #{runtime}."
    if id == "P1.2" && approval
      row["current_note"] = "Compared all escaped exception titles, with only F14 back\\slash full omission excepted by Decision15; #{launches}; runtime SHA #{runtime}."
    end
    if id == "G11"
      selected.select { |check| check.dig("actual", "wall") }.each do |check|
        wall = check.fetch("actual").fetch("wall")
        baseline_median = wall.fetch("baseline").fetch("median_s")
        ratios = %w[plain rich].map { |mode| "#{mode} median #{format('%.6f', wall.fetch(mode).fetch('median_s'))} s, #{format('%+.4f', (wall.fetch(mode).fetch('median_s') / baseline_median - 1) * 100)}%" }
        failure_card = check.fetch("actual").fetch("micro")["FailureCard.format"]
        row["current_note"] = "Compared F07 median-of-three wall time against baseline +10% and every F01-F18 Presentation p95 against <2 ms; " if check == selected.first
        row["current_note"] += "#{check['check'][/Cucumber [\d.]+/]} baseline #{format('%.6f', baseline_median)} s, #{ratios.join(', ')}, FailureCard p95 #{format('%.9f', failure_card.fetch('p95_ms'))} ms (#{failure_card.fetch('count')} samples); "
      end
      row["current_note"] += "#{launches}; runtime SHA #{runtime}."
    end
    if id == "G1" && parameter_proof
      row["api_order_diagnostic"] = { source: parameter_path.delete_prefix(root + "/"), raw_observation_check_ids: selected.select { |c| api_order_observation.call(c) }.map { |c| c["check_id"] },
        protocol_review: "docs/reviews/assets/#{stamp}/parameter-order-protocol-review.json", decision: parameter_approval,
        scope: "Only owner-approved C10/F14 GET order is compared as complete multisets; response DTO remains List, not contractually unordered. All five original ordered wire arrays remain byte-identical. Every key/duplicate and original FAIL object is preserved; no client wire order is normalized." }
      row["current_note"] = "Compared baseline F14 API order e,a,b,c,d against candidate a,b,c,d,e and five byte-identical ordered client arrays, with G1 BLOCKED pending owner API-order adjudication; #{launches}; runtime SHA #{runtime}." unless parameter_approval
      row["current_note"] = "Compared C10/F14 GET parameters as full multisets only under Decision18, all original ordered POST arrays byte-for-byte and every other item field strictly, retaining raw API-order FAILs; #{launches}; runtime SHA #{runtime}." if parameter_approval
    end
    row["current_note"] = "Historical-only, not a new execution: #{row['current_note']}" unless targets.include?(id)
  end
  musts = data["criteria"].select { |row| row["level"] == "MUST" }
  screenshot_file = File.join(assets, stamp, "screenshots.json")
  shots = File.file?(screenshot_file) ? JSON.parse(File.read(screenshot_file)) : []
  cohorts = version == "2.0.1" ? ["12.0.1"] : %w[9.2.1 10.2.0]
  missing_shots = cohorts.flat_map do |cucumber|
    (1..12).filter_map do |number|
      group = format("S%02d", number)
      found = shots.any? do |shot|
        file = shot["path"] && File.join(root, shot["path"])
        shot["cucumber"] == cucumber && shot["runtime_sha"] == head && shot["slug"].start_with?(group) &&
          shot["verdict"] == "PASS" && shot["path"].include?("/#{group}-#{stamp}-") &&
          shot["source_snapshot"].to_s.include?("/ledger-qa-live/#{stamp}-") &&
          file && File.file?(file) && File.binread(file, 8) == "\x89PNG\r\n\x1a\n".b
      end
      "Cucumber #{cucumber} #{group}" unless found
    end
  end
  data["final_exit"] = { "missing_fresh_screenshot_groups" => missing_shots, "verdict" => missing_shots.empty? ? "PASS" : "BLOCKED" }
  status = if musts.any? { |row| row["verdict"] == "FAIL" } then "REJECT"
           elsif musts.any? { |row| !%w[PASS N/A].include?(row["verdict"]) } then "BLOCKED"
           else "ACCEPT" end
  status = "BLOCKED" if status == "ACCEPT" && state && state["requires_new_frozen_heads"]
  status = "BLOCKED" if status == "ACCEPT" && !missing_shots.empty?
  data.merge!("status" => status, "candidate_head" => candidate, "tested_runtime_head" => head, "qa_branch" => "qa/presentation-ledger-#{version}",
    "report_date" => "2026-11-01 Asia/Shanghai", "signoff" => status == "ACCEPT" ? "QA_ACCEPTANCE_ONLY_NOT_RELEASE_AUTHORIZATION" : "NOT_SIGNED",
    "wp5_finalization" => { "stamp" => stamp, "runtime_sha" => head, "qa_parent_commit" => qa_head, "updated_at_utc" => Time.now.utc.iso8601,
      "authorized_criteria" => targets, "new_evidence" => "docs/reviews/assets/#{stamp}/checks.json",
      "history" => "Original Q check objects and prior criterion states remain unchanged; WP5 uses only new WP5 records. No old Launch has been modified or relabelled.",
      "performance" => "SHOULD p95 <2 ms retained, same F01-F18 actual-input replay; early contended attempt excluded.",
      "publication" => "No push, protected-branch update, merge, tag or publication authorized or performed." })
  data["candidate_runtime_binding"] = binding_path.delete_prefix(root + "/") if binding
  data["wp5_finalization"]["initial_preparation_observation"] = state if state
  data["wp5_finalization"]["certification_state"] = { "status" => status, "fresh_screenshot_groups_missing" => missing_shots,
    "candidate_head" => candidate, "actually_tested_runtime_head" => head,
    "claim_limit" => "QA acceptance only; no merge, tag, release, registry upload or QA push is authorized." }
  data["wp5_finalization"]["decision16"] = ci_approval if ci_approval
  File.write(path, JSON.generate(data) + "\n")

  lines = ["# Ledger presentation acceptance - #{version}", "",
    "Verdict: #{status}. Date: 2026-11-01 (Asia/Shanghai). Tester: Independent Ledger QA. Branch: `qa/presentation-ledger-#{version}`. Candidate feature head: `#{candidate}`. Actually tested runtime head: `#{head}`. Baseline: `#{data['baseline_head']}`. RP UI 5.15.6 / server 26.0.7.", "",
    "WP5 re-scores only G1-G12, P1.1-P1.10, P5.1-P5.8, P8.1-P8.9, P10.1-P10.11 and V1-V8 at the final runtime head. Other criterion states are explicitly historical, not new final-head executions. Every original Q check is preserved in the evidence JSON and prior report commits. Developer Launches are not acceptance evidence. No new waiver is inferred.", "",
    "## Runs", "| Run | Ruby | Cucumber | Mode | RSpec (examples/failures/pending) | Cucumber (scenarios/steps) | Launch IDs |", "| --- | --- | --- | --- | --- | --- | --- |"]
  if binding
    lines.insert(4, "Documentation-only binding: [exact path/mode/blob fingerprints and fresh package member proof](assets/#{stamp}/docs-only-final-binding-r2.json) pass. Only the approved documentation delta is newly verified; matrix/live/fault/performance runs retain their original tested SHAs. No release authorization.", "")
  end
  (version == "1.3.2" ? %w[M1 M2 M3 M4] : %w[M5 M6]).each do |cell|
    result_path = Dir[File.join(assets, "#{stamp}/matrix/#{cell}/**/result.json")].select { |p| p.end_with?("/matrix/#{cell}/result.json", "/qa-cell-evidence/result.json") }.max_by { |p| File.mtime(p) }
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
    anchor = "#{row['id'].downcase.tr('.', '-')}-id-ranges"
    evidence = "[#{row['check_ids'].length} checks](assets/presentation-ledger-#{version}-acceptance.json); [all #{row['evidence_log_ids'].length} log / #{row['evidence_item_ids'].length} item IDs](##{anchor})"
    lines << "| #{row['id']} | #{row['level']} | #{row['verdict']} | #{evidence} | #{escape.call(row['current_note'])} |"
  end
  lines += ["", "## Defects", approval ? "Decision15 explicitly excepts only the named F14 backslash failure title while retaining complete fail-closed omission. Original title-comparison mismatches remain in the evidence; no golden/redaction change or broader exception is applied." : "The F14 backslash/P1.2 title mismatch is an unwaived specification/redaction conflict under independent investigation, not an asserted new WP1 runtime regression. P1.2 remains BLOCKED pending the owner's explicit answer; neither golden nor original observation is changed.", "",
    "| # | Severity | Criterion | Fixture | Expected | Actual | Evidence |", "| --- | --- | --- | --- | --- | --- | --- |"]
  failures = fresh.select { |check| check["verdict"] == "FAIL" && !exception.call(check) }
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
  lines += ["", "Retained earlier failures are not waived: the independent Ruby 3.1 focused run observed 0.1342089579993626 s against the unchanged <0.12 s assertion, without the handle_error diagnostic observer. Its original result and command provenance remain in `docs/reviews/assets/wp5-final-20261101/spec-repair-ruby31-focused.json` and `.provenance.json` on the 1.x QA branch. The original RSpec keyword-wrapper failures remain in their original matrix evidence. Fresh all-six-cell evidence is required for G10.", "",
    "Original remote CI attempt-1 failures (2x SIGINT spooled=0 and frozen 1.3.1 SIGINT/HTTP-400 receipt failures) remain separately recorded in `docs/reviews/assets/#{stamp}/ci-attempt1-independent-review.json`. Unchanged attempt-2 success does not establish their cause or waive an assertion. Independent classification: the legacy failures predate Ledger; budget/scheduling sensitivity is a supported explanation, not proof of runner-only causation or a demonstrated repaired SDK defect."]
  lines += ["", "Evidence-integrity findings, separate from SDK defects: the independent publication review found three S2 packaging gaps (quiet G11 root omitted, historical raw references not selected, and portable reproduction setup missing). The bounded curator/reproduction-guide correction passed 35 synthetic assertions and Master review; original findings remain in the publication-audit sidecar. Final selection and secret/size/path audit remain a publication gate, not an SDK waiver.", "",
    "QA harness observations are retained separately: an initial package-binding helper rejected comma-formatted counts despite identical package/runtime bytes; its failed result remains on 1.x. Console replay attempt 1 performed only GET and stopped because list severity `error` differs from direct GET `ERROR`; identical 10,492-byte messages were independently hash-verified before attempt 2. Only severity casing is canonicalized, not message content."]
  lines += ["", "Historical-index repair preserves every committed Q and WP5 object at its original ID; 17 later in-progress legacy variants are retained inline under unique `DRAFT-HISTORY-*` IDs with full original draft objects and explicit mappings. The Master before-repair witness is unchanged. No old failure, input, expected/actual value or verdict is discarded.", "",
    "The fixture-only containment test correction additionally passes 37 unchanged-security assertions with a QA-local TMPDIR; the earlier host failure and separate unchanged-test container pass remain retained. Production curator source is unchanged by that fixture correction."]
  lines += ["", "## Screenshots", "Historical screenshots remain at their original Launches/runtime and are not relabelled final. Fresh final-head captures and DOM observations are indexed separately below."]
  if File.file?(screenshot_file)
    JSON.parse(File.read(screenshot_file)).each { |shot| lines << "- #{shot['slug']}: Launch #{shot['launch_id']}; item #{shot['item_id']}; log #{Array(shot['log_ids']).join(', ')}; #{shot['verdict']}; [image](#{shot['path'].delete_prefix('docs/reviews/')})." }
  else
    lines << "Fresh S01-S12 set: BLOCKED until final-run criteria analysis and visual protocol are complete. No screenshot PASS is claimed."
  end
  lines << "Fresh exit proof missing: #{missing_shots.join('; ')}." unless missing_shots.empty?
  lines += ["", "## Exact ID Ranges", "Every range below is inclusive and round-trip checked; gaps and singletons are preserved, and the complete uncompressed arrays remain in the evidence JSON."]
  data["criteria"].each do |row|
    anchor = "#{row['id'].downcase.tr('.', '-')}-id-ranges"
    lines += ["", "<a id=\"#{anchor}\"></a>", "<details>", "<summary>#{row['id']}: #{row['evidence_launch_ids'].length} Launch, #{row['evidence_item_ids'].length} item, #{row['evidence_log_ids'].length} log IDs</summary>", "",
      "Launches: #{LedgerQAIdRanges.checked(row['evidence_launch_ids'])}", "", "Items: #{LedgerQAIdRanges.checked(row['evidence_item_ids'])}", "",
      "Logs: #{LedgerQAIdRanges.checked(row['evidence_log_ids'])}", "", "</details>"]
  end
  lines += ["", "## Waivers", "Only the explicit owner Decisions 1-18 and recorded clarifications apply within their named scopes; no broader waiver is inferred. The source below is quoted without changing historical evidence.", ""]
  if approval
    lines[-2] = "Owner Decisions 1-18 and recorded clarifications apply only within their explicit scopes; Decision15's title-only exception and Decisions16-18 are detailed below."
    lines += ["Decision15, received 2026-11-01: F14 `back\\slash` failure title only; retain the exact complete fail-closed omission. All other title/escaping checks remain strict.", "",
      "> #{approval['owner_exact_answer']}", "", "The following supplied Decisions 1-14 are quoted from the original final-runtime documents. Decision15's product-doc append and docs-only binding are separate follow-up evidence.", ""]
  end
  if ci_approval
    lines += ["Decision16, received 2026-11-01: only bounded, independently reviewed test/CI diagnostics are authorized; Helm, runtime budgets and existing assertions remain protected. V6 still needs an exact new-head diff audit, and G10 is not waived.", "",
      "> Question: #{ci_approval['owner_exact_question']}", "> Owner answer: #{ci_approval['owner_exact_answer']}", ""]
  end
  lines += ["Decision17: the owner explicitly approved an exact-byte F04 flat replay in new independent QA Launches solely for Console rendering. Original runtime logs and topology remain unchanged. S12 source/replay mappings and active Console screenshots are labelled renderer-only; this is not a replacement runtime or wire-contract run.", "",
    "> Owner answer: 允许补充平铺回放（推荐）", ""]
  if parameter_approval
    lines += ["Decision18: [pinned protocol review](assets/#{stamp}/parameter-order-protocol-review.json) records Set persistence but List request/response DTOs; no unordered API contract is inferred. Only C10/F14 GET parameter order uses a complete multiset, retaining duplicate multiplicity and raw FAILs; ordered POST bytes and every other field remain strict.", "",
      "> Owner answer: #{parameter_approval['owner_exact_answer']}", ""]
  end
  decisions, decision_status = Open3.capture2("git", "-C", root, "show", "#{candidate}:docs/design/presentation-ledger-owner-decisions.md")
  raise "Exact runtime decision document unavailable" unless decision_status.success?
  lines.concat(decisions.lines.map { |line| line.strip.empty? ? ">" : "> #{line.rstrip}" })
  File.write(File.join(root, "docs/reviews/2026-11-01-presentation-ledger-#{version}-acceptance.md"), lines.join("\n") + "\n")
  puts JSON.generate(version: version, status: status, fresh_checks: fresh.length, blocked_criteria: data["criteria"].select { |r| r["verdict"] == "BLOCKED" }.map { |r| r["id"] }, failures: failures.length)
end
