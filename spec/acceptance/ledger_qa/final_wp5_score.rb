# frozen_string_literal: true

require_relative "final_wp5_analyze"

stamp = ENV.fetch("QA_WP5_STAMP", "wp5-final-20261101")
heads = LedgerQAAnalysis::WP5Study::FINAL_HEADS
heads.each do |version, head|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  directory = File.join(root, "docs/reviews/assets", stamp)
  live_path = File.join(directory, "live-checks.json")
  checks = File.file?(live_path) ? JSON.parse(File.read(live_path)).fetch("checks") : []
  add = lambda do |id, label, expected, actual, source, passed = nil, inputs = {}|
    passed = expected == actual if passed.nil?
    checks << { criterion: id, check: label, method: "U", runtime_sha: head,
      inputs: inputs, expected: expected, actual: actual, verdict: passed ? "PASS" : "FAIL",
      evidence: { source: source, launch_ids: [], item_ids: [], log_ids: [] } }.transform_keys(&:to_s)
  end
  block = lambda do |id, reason, source|
    checks << { "criterion" => id, "check" => reason, "method" => "U", "runtime_sha" => head,
      "inputs" => { "required_source" => source }, "expected" => "Required final-head proof", "actual" => nil,
      "verdict" => "BLOCKED", "evidence" => { "source" => source, "launch_ids" => [], "item_ids" => [], "log_ids" => [] } }
  end
  cells = version == "1.3.2" ? %w[M1 M2 M3 M4] : %w[M5 M6]
  cells.each do |cell|
    files = Dir[File.join(root, "docs/reviews/assets/wp5-final-20261101*/matrix/#{cell}/**/result.json")].select { |path| path.end_with?("/matrix/#{cell}/result.json", "/qa-cell-evidence/result.json") }
    path = files.sort.last
    unless path
      block.call("G10", "#{cell}: final-head complete suite/offline Cucumber has not finished", "#{stamp}/matrix/#{cell}")
      block.call("P8.9", "#{cell}: final-head omission/bounds spec evidence unavailable", "#{stamp}/matrix/#{cell}")
      next
    end
    result = JSON.parse(File.read(path))
    add.call("G10", "#{cell}: exact final runtime full suite plus offline Cucumber, no failures/pending", [head, "PASS", 0, 0],
      [result["source_head"], result["status"], result.dig("rspec", "failure_count"), result.dig("rspec", "pending_count")], path, nil,
      result)
    checks.last["verdict"] = checks.last["expected"] == checks.last["actual"] ? "PASS" : "FAIL"
    spec = Dir[File.join(root, "docs/reviews/assets/wp5-final-20261101*/matrix/#{cell}/source/docs/reviews/assets/qa-cell-evidence/rspec.json")].sort.last
    examples = spec && JSON.parse(File.read(spec)).fetch("examples")
    bounds = examples.to_a.select { |row| row["full_description"].match?(/omission marker.*bounds|existing size limits and omission marker|existing public bounds/) }
    add.call("P8.9", "#{cell}: unchanged omission marker and public bounds verified by product and independent specs", "At least 2 matching examples, all passed",
      bounds.map { |row| row.slice("full_description", "status", "file_path", "line_number") }, spec,
      bounds.length >= 2 && bounds.all? { |row| row["status"] == "passed" })
  end

  cucumbers = version == "1.3.2" ? %w[9.2.1 10.2.0] : ["12.0.1"]
  cucumbers.each do |cucumber|
    prefix = File.join(directory, "probes/c#{cucumber}")
    completed = Dir[File.join(prefix, "fault-*/summary.json")]
    if completed.length != 24
      block.call("G9", "Cucumber #{cucumber}: 24 public-entry fault captures not complete (#{completed.length}/24)", prefix)
      next
    end
    completed.sort.each do |summary|
      folder = File.dirname(summary)
      process_path = Dir[File.join(folder, "*/process.json")].first
      process = JSON.parse(File.read(process_path))
      fixture = File.basename(File.dirname(process_path))
      fallback_file = "#{folder}-fallback.ndjson"
      fallback = File.file?(fallback_file) ? File.readlines(fallback_file).map { |line| JSON.parse(line) } : []
      guard = JSON.parse(File.read(File.join(File.dirname(process_path), "source-guard.json")))
      actual = [process["exit"], process["stderr"].scan("QA_FAULT_INVOKED").length,
        process["stderr"].scan("ReportPortal presentation failed; using baseline format").length,
        !fallback.empty? && fallback.all? { |row| row["byte_equal"] }, guard["passed"], guard["expected_source"]]
      add.call("G9", "Cucumber #{cucumber} #{File.basename(folder)}: baseline fallback bytes, one warning, unchanged native result",
        [fixture == "F04" ? 1 : 0, 1, 1, true, true, "/Users/nick/Documents/crr-#{version}"], actual,
        process_path, actual == [fixture == "F04" ? 1 : 0, 1, 1, true, true, "/Users/nick/Documents/crr-#{version}"],
        { fallback_source: fallback_file, fallback_records: fallback })
    end
  end

  perf_stamp = ENV.fetch("QA_WP5_PERF_STAMP", "wp5-final-20261101-quiet")
  cucumbers.each do |cucumber|
    perf = File.join(root, "docs/reviews/assets", perf_stamp, "probes/c#{cucumber}")
    timings = %w[baseline plain rich].to_h do |mode|
      samples = Dir[File.join(perf, "wall-*-#{mode}/F07/process.json")].sort.map { |path| JSON.parse(File.read(path)).fetch("seconds") }
      [mode, { samples_s: samples, median_s: samples.length == 3 ? samples.sort[1] : nil }]
    end
    micro = Hash.new { |hash, key| hash[key] = [] }
    errors = []
    micro_files = Dir[File.join(perf, "{micro,parallel-micro}-*/**/presentation-timings.json")].sort
    micro_files.each do |path|
      data = JSON.parse(File.read(path))
      data.fetch("samples").each { |name, samples| micro[name].concat(samples) }
      errors << { path: path, errors: data["replay_errors"] } unless data.fetch("replay_errors", {}).empty?
    end
    if timings.values.any? { |row| row[:median_s].nil? } || micro_files.empty? || !File.file?(File.join(perf, "micro-rich/summary.json"))
      block.call("G11", "Cucumber #{cucumber}: uncontended F01-F18 performance rerun pending; early contended attempt is NOT acceptance proof", perf)
    else
      summary = micro.transform_values { |samples| { count: samples.length, p95_ms: samples.sort[(samples.length * 0.95).ceil - 1] } }
      pass = %w[plain rich].all? { |mode| timings[mode][:median_s] <= timings["baseline"][:median_s] * 1.10 } && summary.values.all? { |row| row[:p95_ms] < 2 } && errors.empty?
      add.call("G11", "Cucumber #{cucumber}: unchanged F01-F18 wrapper-free replay, 10 warmups/50 samples; F07 medians of three",
        { wall_ratio_max: 1.10, every_entry_p95_ms: "< 2", replay_errors: [] },
        { wall: timings, micro: summary, replay_errors: errors }, perf, pass,
        { timing_observer_sha256: Digest::SHA256.file(File.join(root, "spec/acceptance/ledger_qa/performance_support.rb")).hexdigest,
          unchanged_measurement: "Same actual-input F01-F18 corpus, including F06 only on 2.x; no new cached-only benchmark substituted" })
    end
  end

  repository = File.join(directory, "repository/before.json")
  if File.file?(repository)
    data = JSON.parse(File.read(repository))
    records = data.fetch("records")
    record = ->(id) { records.find { |row| row["criterion"] == id } }
    files = data.fetch("files")
    add.call("V1", "Final source version constant and freshly built package version", [version, version, head],
      [files["lib/reportportal_cucumber/version.rb"][/VERSION\s*=\s*["']([^"']+)/, 1], data.dig("package", "version"), data["runtime_sha"]], repository)
    changes = record.call("V2")["stdout"].lines.grep(/\A[+-](?![+-])/).map(&:strip)
    add.call("V2", "Frozen-baseline lock diff contains only the gem's own PATH version", ["-    reportportal-cucumber-ruby (#{version == '1.3.2' ? '1.3.1' : '2.0.0'})", "+    reportportal-cucumber-ruby (#{version})"], changes, repository)
    add.call("V3", "Fresh gem build from final feature tree, locally verified and never published", ["reportportal-cucumber-ruby-#{version}.gem", version, true, head],
      data.fetch("package").values_at("filename", "version", "verified", "source_sha"), repository)
    changelog = files.fetch("CHANGELOG.md")
    add.call("V4", "CHANGELOG begins with new patch release and owner SemVer rationale", true,
      changelog[/^## .*/].to_s.include?(version) && changelog.match?(/patch.*owner|owner.*patch/i), repository)
    if version == "2.0.1"
      add.call("V4", "Decision 6: published 2.0.0 history remains byte-identical below new section",
        data.fetch("official_200_changelog").split(/^## 2\.0\.0\b/, 2).last, changelog.split(/^## 2\.0\.0\b/, 2).last, repository)
    end
    add.call("V5", "Both switches and Presentation section documented at final SHA", [true, true, true],
      [files["docs/configuration.md"].include?("RP_PRESENTATION"), files["docs/configuration.md"].include?("RP_RUN_CONTEXT"), files["docs/advanced-reporting.md"].match?(/^#+ .*Presentation/i)], repository)
    add.call("V6", "No Helm/workflow changes against frozen baseline", "", record.call("V6")["stdout"], repository)
    if version == "1.3.2"
      add.call("V6", "Legacy chart remains 1.3.1/app 26.0.7", true,
        files["helm/reportportal-rich-experience/Chart.yaml"].match?(/^version: 1\.3\.1$/) && files["helm/reportportal-rich-experience/Chart.yaml"].match?(/^appVersion: ["']?26\.0\.7["']?$/), repository)
    end
    add.call("V7", "Protected heads still equal original independent observations", data["protected_heads_expected"], data["protected_heads_actual"], repository)
    add.call("V7", "Decision 10 historical CI tag names equal fresh remote names (not historical tag-SHA proof)", data["decision10_historical_tag_names"], data["current_tag_names"], repository)
    after = File.join(directory, "repository/after.json")
    if File.file?(after)
      final = JSON.parse(File.read(after))
      add.call("V7", "WP5 before/after complete remote ref observations unchanged", record.call("V7")["stdout"], final["records"].find { |r| r["criterion"] == "V7" }["stdout"], after)
    else
      block.call("V7", "WP5 exit remote observation not yet recorded", after)
    end
    history = record.call("V8")["stdout"]
    stages = [/docs\(design\).*proposal/, /MarkdownText/, /failure card/i, /hook names and step.argument/i, /attachment captions/i,
      /Outline.*assertion/i, /(?:run context|run.context)/i, /(?:accent|Tier 2)/i, /prepare Ledger SDK/i]
    positions = stages.map { |pattern| history.lines.index { |line| line.match?(pattern) } }
    add.call("V8", "C0-C8 semantic implementation order, P10 isolated stage retained", true, positions.none?(&:nil?) && positions == positions.sort, repository, positions.none?(&:nil?) && positions == positions.sort,
      { stages: stages.map(&:source), positions: positions, history: history })
  else
    (1..8).each { |n| block.call("V#{n}", "Final-head repository evidence unavailable", repository) }
  end
  checks = checks.map { |row| JSON.parse(JSON.generate(row)) }
  output = File.join(directory, "checks.json")
  FileUtils.mkdir_p(directory)
  File.write(output, JSON.pretty_generate(schema: "wp5-final-head-checks/1", checked_at_utc: Time.now.utc.iso8601, runtime_sha: head, checks: checks) + "\n")
  puts JSON.generate(version: version, counts: checks.group_by { |row| row["verdict"] }.transform_values(&:length),
    failures: checks.select { |row| row["verdict"] == "FAIL" }.map { |row| [row["criterion"], row["check"], row["evidence"]] })
end
