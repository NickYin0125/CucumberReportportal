# frozen_string_literal: true

require "json"
require "open3"
require "time"
require "digest"

%w[2.0.1 1.3.2].each do |version|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  assets = File.join(root, "docs/reviews/assets")
  evidence_path = File.join(assets, "presentation-ledger-#{version}-acceptance.json")
  data = JSON.parse(File.read(evidence_path))
  by_id = data.fetch("checks").to_h { |check| [check["check_id"], check] }
  data.fetch("criteria").each { |row| row["checks"] ||= row.fetch("check_ids").map { |id| by_id.fetch(id) } }
  head = Open3.capture2("git", "-C", root, "rev-parse", "HEAD").first.strip
  branch = Open3.capture2("git", "-C", root, "branch", "--show-current").first.strip
  baseline = version == "1.3.2" ? "4ca2f770e0a84e83688f165ba04b4db8ef855cf9" : "79e5e9cfde4be6d29ca2293e549460c6c71fe87a"
  cells = version == "1.3.2" ? %w[M1 M2 M3 M4] : %w[M5 M6]
  matrix = cells.to_h do |cell|
    path = File.join(assets, "ledger-qa-runs/final-hooks-20261101/#{cell}/result.json")
    [cell, File.file?(path) ? JSON.parse(File.read(path)) : nil]
  end
  final_complete = matrix.values.all? { |result| result && result["status"] == "PASS" }
  data["status"] = final_complete ? "BLOCKED_OWNER_DECISIONS_PENDING" : "DRAFT_FINAL_MATRIX_RUNNING"
  data["candidate_head"] = head
  data["baseline_head"] = baseline
  data["qa_branch"] = branch
  data["report_date"] = "2026-11-01 Asia/Shanghai"
  data["signoff"] = "NOT_SIGNED"
  data["capture_dates"] = "Actual UTC capture stamps are preserved; do not relabel October 31 runs as November 1 runs."
  data["final_matrix_stamp"] = "final-hooks-20261101"
  data["normalization"] = [
    "Item graph resolved recursively: duplicate IDs, missing non-root parents and cycles are rejected.",
    "UUIDs/clocks normalized only as documented. Server auto uniqueId normalized only with wire proof client omitted it.",
    "Attachment proof includes normalized owner path + filename + MIME + bytes + SHA256, joined via logId -> itemId and captured wire.",
    "Only Decision 8 six 1.x missing baseline attachments use baseline submitted wire plus complete candidate API download. Unchanged raw-NUL user-log loss is not marked recovered.",
    "Terminal comparisons retain raw stdout and strict timestamp-only result; semantic comparison additionally excludes Cucumber's generated final scenario/step/stopwatch footer.",
    "F04 frozen 62-frame input is historical input replay, not current natural stack generation. Non-Exception/no-project/getter-fault controls are explicitly adapted inputs."
  ]
  data["criteria"].find { |row| row["id"] == "G10" }["verdict"] = "BLOCKED" unless final_complete
  p6 = data["criteria"].find { |row| row["id"] == "P6.1" }
  p6["current_note"] = p6["verdict"] == "PASS" ? "Resolved D03: C9/C10/C12 native Before/After/AfterStep names, real retry, fault fallback and final cache cleanup independently verified in both modes twice. Original failures remain in the historical ledger." : "Native/API retest passes; final-head full-suite evidence is still being completed. Original failures are retained separately."
  data["criteria"].find { |row| row["id"] == "V7" }["current_note"] = "Authentic complete pre-task public CI tag fetch-list and unchanged protected refs retained. Original full ls-remote before snapshot is unavailable; owner approval of alternative evidence is pending."

  perf_root = File.join(assets, "ledger-qa-performance/final-hooks")
  perf = { source: "docs/reviews/assets/ledger-qa-performance/final-hooks", wall: {}, micro: {}, replay_errors: [] }
  %w[baseline plain rich].each do |mode|
    samples = Dir[File.join(perf_root, "wall-*-#{mode}/F07/process.json")].sort.map { |path| JSON.parse(File.read(path)).fetch("seconds") }
    perf[:wall][mode] = { samples_s: samples, median_s: samples.length == 3 ? samples.sort[1] : nil }
  end
  grouped = Hash.new { |hash, key| hash[key] = [] }
  Dir[File.join(perf_root, "{micro,parallel-micro}-*/**/presentation-timings.json")].each do |path|
    result = JSON.parse(File.read(path))
    result.fetch("samples").each { |name, samples| grouped[name].concat(samples) }
    perf[:replay_errors] << { source: path.delete_prefix(root + "/"), errors: result["replay_errors"] } unless result.fetch("replay_errors", {}).empty?
  end
  grouped.each { |name, samples| perf[:micro][name] = { count: samples.length, p95_ms: samples.sort[(samples.length * 0.95).ceil - 1] } unless samples.empty? }
  base_wall = perf[:wall].dig("baseline", :median_s)
  walls_pass = base_wall && %w[plain rich].all? { |mode| value = perf[:wall].dig(mode, :median_s); value && value <= base_wall * 1.10 }
  micro_pass = !perf[:micro].empty? && perf[:micro].values.all? { |row| row[:p95_ms] < 2 }
  perf[:verdict] = walls_pass && micro_pass && perf[:replay_errors].empty? ? "PASS" : "FAIL"
  perf_path = File.join(assets, "ledger-qa-performance-#{version}.json")
  File.write(perf_path, JSON.pretty_generate(perf) + "\n")
  g11 = data["criteria"].find { |row| row["id"] == "G11" }
  g11["verdict"] = perf[:verdict]
  g11["checks"] = [{ criterion: "G11", check: "Median of three F07 wall runs and wrapper-free actual-input micro replay", method: "U",
    inputs: perf[:source], expected: { wall: "<= baseline median * 1.10", each_p95_ms: "< 2" }, actual: perf,
    evidence: { source: "docs/reviews/assets/ledger-qa-performance-#{version}.json", launch_ids: [], item_ids: [], log_ids: [] }, verdict: perf[:verdict],
    note: "Final ecf/c275 heads. Inclusive instrumented samples are retained separately but are not the p95 acceptance measurement. Replay removes all QA wrappers, warms each actual in-memory input 10 times and measures 50 calls/input. No environment values serialized." }]
  data["checks"].concat(g11["checks"])
  source_digests = {}
  (data["checks"] + data["criteria"].flat_map { |row| row["checks"] }).each do |check|
    next unless check["inputs"].nil? && check["evidence"]
    source = check.dig("evidence", "source")
    source_path = source.is_a?(String) && (source.start_with?("/") ? source : File.join(root, source))
    check["inputs"] = { "captured_source" => source, "selection" => check["check"],
      "source_sha256" => source_path && File.file?(source_path) ? (source_digests[source_path] ||= Digest::SHA256.file(source_path).hexdigest) : nil,
      "source_ids" => check["evidence"].slice("launch_ids", "item_ids", "log_ids") }
  end
  data["input_reference_note"] = "captured_source plus selection identifies the exact retained raw inputs; SHA256 and native IDs disambiguate them. Controlled argument values are also recorded inline where supplied. No raw input is reconstructed from candidate output."
  File.write(evidence_path, JSON.pretty_generate(data) + "\n")

  lines = ["# Ledger presentation acceptance \u2014 #{version}", "",
    "Verdict: BLOCKED. Date: 2026-11-01 (Asia/Shanghai). Tester: Independent Ledger QA. Branch: `#{branch}`. Candidate head: `#{head}`. Baseline: `#{baseline}`. RP UI 5.15.6 / server 26.0.7.", "",
    "#{final_complete ? 'Final technical evidence is complete' : 'Draft: final matrix is still running'}; this is NOT ACCEPT. P10.6 and V7 require explicit owner decisions; neither is waived or PASS. Actual October 31 capture stamps remain unchanged. Underlying product suites contain 1345 examples on 1.x and 1402 on 2.x; the independent QA property file adds 16, giving 1361/1418 total examples. Actual per-cell counts below are authoritative.", "",
    "## Runs", "| Run | Ruby | Cucumber | Mode | RSpec (examples/failures/pending) | Cucumber (scenarios/steps) | Launch IDs |",
    "| --- | --- | --- | --- | --- | --- | --- |"]
  matrix.each do |cell, result|
    if result
      runtime = result.fetch("runtime")
      rspec = result.fetch("rspec")
      cucumber = result.fetch("cucumber")
      json_path = File.join(assets, "ledger-qa-runs/final-hooks-20261101/#{cell}/source/docs/reviews/assets/qa-cell-evidence/rspec.json")
      examples = JSON.parse(File.read(json_path)).fetch("examples")
      qa = examples.count { |example| example.fetch("file_path").include?("ledger_qa/properties.rb") }
      product = rspec.fetch("example_count") - qa
      lines << "| #{cell}, final-hooks-20261101 | #{runtime['ruby']} | #{runtime['cucumber']} | offline plain; live plain/rich separately | #{rspec.values_at('example_count', 'failure_count', 'pending_count').join('/')} (#{product} product + #{qa} QA) | #{cucumber.values_at('scenarios', 'steps').join('/')} | Offline stub; see live evidence |"
    else
      lines << "| #{cell}, final-hooks-20261101 | Required matrix cell | Pinned in source provenance | Required scope unchanged | RUNNING / pending | Pending | Offline stub |"
    end
  end
  %w[20261031T072147Z 20261031T173014Z 20261031T174824Z 20261031T180948Z].each do |stamp|
    snapshots = Dir[File.join(assets, "ledger-qa-live/#{stamp}-*/**/snapshot.json")]
    ids = snapshots.flat_map { |path| JSON.parse(File.read(path)).fetch("launches", []).map { |l| l["id"] } }.uniq.sort
    lines << "| #{stamp}, independent live captures | Recorded per source probe | #{version == '1.3.2' ? '9/10 as indexed' : '12.0.1'} | baseline/plain/rich as indexed | Not a replacement for full suites | Native JSON retained | #{ids.join(', ')} |"
  end
  lines += ["", "Superseded six-cell `final-fixed-20261031` and `final-p88-20261101` runs are retained with full outputs, not reused as final-head suite proof. Original `20261031T065500Z` baseline captures are UNUSABLE: Cucumber loaded candidate source from the current directory. Corrected baseline captures assert loaded-source provenance. Earlier infrastructure/recorder failures and the stopped superseded terminal-repair matrix are preserved, not hidden.", "",
    "Native Cucumber compound syntax is N/A on 1.x only under Decision 4, with parser rejection and separate companions. F06 is N/A on 1.x. Global-hook Item names are N/A under Decision 5; lifecycle/error/log closure remains checked. No broader fixture or criterion waiver is inferred.", "",
    "## Results by criterion", "| ID | Level | Verdict (PASS/FAIL/N/A/BLOCKED) | Evidence (log/item IDs, file, screenshot) | Note |", "| --- | --- | --- | --- | --- |"]
  data.fetch("criteria").each do |row|
    samples = row.fetch("checks").flat_map { |c| Array(c.dig("evidence", "log_ids")) }.uniq.first(6)
    items = row.fetch("checks").flat_map { |c| Array(c.dig("evidence", "item_ids")) }.uniq.first(4)
    evidence = "[Complete checks](assets/presentation-ledger-#{version}-acceptance.json), #{row['checks'].length} checks"
    evidence += "; logs #{samples.join(',')}" unless samples.empty?
    evidence += "; items #{items.join(',')}" unless items.empty?
    note = row["current_note"] || row["checks"].select { |c| c["verdict"] == "BLOCKED" }.map { |c| c["check"] }.uniq.join("; ")
    note = "All recorded subchecks pass; see exact inputs/expected/actual and source references." if note.to_s.empty? && row["verdict"] == "PASS"
    note = "SHOULD timing target not met; nonblocking, no threshold relaxed." if row["id"] == "G11" && row["verdict"] == "FAIL"
    lines << "| #{row['id']} | #{row['level']} | #{row['verdict']} | #{evidence} | #{note.to_s.gsub('|', '\\|')} |"
  end
  lines += ["", "## Defects", "| # | Severity | Criterion | Fixture | Expected | Actual | Evidence |", "| --- | --- | --- | --- | --- | --- | --- |",
    "| D01 | S2, resolved | P2.1 | F14 | Literal table punctuation | Original star/underscore/backtick delimiters disappeared. Repaired DOM checks retain all 14 literals. | Original and repaired S04; complete DOM JSON |",
    "| D02 | S2, resolved | P8.8 | ALL F10/F11, F12 control | Baseline native/terminal body | Tier 1 presentation leaked into terminal/native body. Fresh 48 comparisons per line pass after repair; RP payload hashes/owners unchanged. | terminal-audit-20261031T173014Z.json; original failing process files retained |",
    "| D03 | S2, resolved by final native/API retest | P6.1 | F15-named | Preserve declared native hook names | Original native Hook.name existed but RP lost it. Final 178 checks on 2.x and 284 on 1.x pass, including all three kinds, real retry, fault fallback and actual-completion cache cleanup. | Historical ledger; hooks-audit JSON; final S07 |",
    "| D04 | S3, open | G11 | F01-F18 corpus | Every formatter p95 below 2 ms | FailureCard.format p95 #{perf[:micro].dig('FailureCard.format', :p95_ms)&.round(3)} ms in wrapper-free replay (2,100 calls). Wall medians remain within +10%; full samples/runtime retained. | ledger-qa-performance-#{version}.json |",
    "| D05 | S3, cosmetic | Outside P4.3 | F02 | Compact Examples metadata | Examples metadata wraps at 1100px. Key/value chips each have one physical line; P4.3 passes. | S05 and chip getClientRects proof |", "",
    "P10.6 is a specification-algorithm conflict, not permission to alter frozen backtrace bytes or raw user logs. The literal prescribed regex deletes three `top` words from Ruby `<top (required)>` code labels. The proposed code-aware comparison passes, but owner approval is pending. V7 retains authentic public pre-task CI fetch-list evidence, not a fabricated original remote before snapshot.", "",
    "On 1.x, six baseline NUL-preview attachment losses use only the exact Decision 8 exception: baseline accepted wire plus complete candidate per-item download, with matching owner/name/MIME/bytes/hash. The unchanged raw-NUL native user log is absent from both versions. HTTP 201 is submission acceptance, not persistence proof; the read API gives no server rejection reason. The old baseline F16f SECRET123 probe hit is not a candidate G8 failure.", "",
    "The final GET audit initially omitted 15 first-attempt Scenarios because the normal API item page nests them in the latest Scenario's retries array. Original mismatches are retained. The separate immutable supplement discovers those actual nested IDs, directly reads each attempt, verifies UUID/real parent/closed status/Suite-to-Launch lineage and per-item filters, and proves the expanded item/log sets equal the snapshots. This is an explicit query-model correction, not a topology or persistence waiver.", "",
    "The supplied pre-fix Master M4 wall-clock assertion failure (0.817765 s versus <0.5 s under concurrent load) is not erased or labelled proven baseline flakiness. Its helper includes bootstrap/business work; separate timing instrumentation records actual finalization while retaining every original assertion. All six final isolated cells pass unchanged bounds. No timeout increase or timing waiver was used.", "",
    "Evidence checkout/extraction and path mapping: [artifact guide](assets/presentation-ledger-#{version}-evidence.md). Raw captures are losslessly archived with per-file SHA256 manifests; SDK mirrors, caches and temporary package binaries are excluded.", "",
    "## Screenshots"]
  shots = JSON.parse(File.read(File.join(assets, "ledger-qa-screenshots-#{version}.json")))
  shots.each do |shot|
    absolute_png = shot["png"].start_with?("/") ? shot["png"] : File.join(root, shot["png"])
    relative = absolute_png.delete_prefix(File.join(root, "docs/reviews/") )
    lines << "- [#{shot['slug']}](#{relative}), #{shot['mode']}; Launch #{shot['launch_ids'].join(',')}; context Item #{shot['context_item_id'] || 'N/A Launch list'}; #{shot['visual_verdict']}."
  end
  lines += ["", "S12 is genuine native Console via ordinary Log Message search, not Markdown-off. Pagination was already ON and not changed; Console/search/Markdown state was restored. Historical empty-scope blocked shots remain labelled historical and are not exit evidence. S03 was re-captured using a fixed 1100 x 780 viewport clip; metadata records the actual method. Native download filenames are proved by real UI clicks and separately statted/hashed files, not headers alone.", "", "## Waivers", "Only the owner-confirmed Decisions below apply. Master review/QA-artifact archival instructions are not user waivers. P10.6/V7 pending questions are not approvals.", ""]
  decisions = File.read(File.join(root, "docs/design/presentation-ledger-acceptance.md")).split(/^## Decisions\s*$/, 2).last
  lines.concat(decisions.to_s.lines.map { |line| line.chomp.empty? ? ">" : "> #{line.chomp}" })
  report = File.join(root, "docs/reviews/2026-11-01-presentation-ledger-#{version}-acceptance.md")
  File.write(report, lines.join("\n") + "\n")
  # Criteria index the one full check table instead of duplicating megabytes
  # of native envelopes and exact expected/actual strings in every row.
  ids = {}
  unique = []
  data.fetch("checks").each do |check|
    check.delete("check_id")
    key = Digest::SHA256.hexdigest(JSON.generate(check))
    unless ids.key?(key)
      ids[key] = format("Q%05d", unique.length + 1)
      unique << check.merge("check_id" => ids[key])
    end
  end
  data.fetch("criteria").each do |row|
    row["check_ids"] = row.delete("checks").map do |check|
      copy = check.reject { |key, _| key == "check_id" }
      key = Digest::SHA256.hexdigest(JSON.generate(copy))
      unless ids[key]
        ids[key] = format("Q%05d", unique.length + 1)
        unique << copy.merge("check_id" => ids[key])
      end
      ids.fetch(key)
    end
  end
  data["schema"] = "independent-ledger-acceptance/2-check-index"
  data["checks"] = unique
  data["check_index_note"] = "Every check's full inputs, expected/actual values, verdict and source/Launch/item/log references occur once in checks. Criteria reference them through check_ids; no assertion values were discarded."
  File.write(evidence_path, JSON.pretty_generate(data) + "\n")
  puts JSON.generate(version: version, report: report, verdict: "BLOCKED", criteria: data["criteria"].length,
    current_fail: data["criteria"].select { |r| r["verdict"] == "FAIL" }.map { |r| r["id"] },
    current_blocked: data["criteria"].select { |r| r["verdict"] == "BLOCKED" }.map { |r| r["id"] })
end
