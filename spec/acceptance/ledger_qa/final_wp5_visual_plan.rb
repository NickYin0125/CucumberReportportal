# frozen_string_literal: true

require_relative "final_wp5_analyze"

stamp = LedgerWP5Context.stamp
LedgerQAAnalysis::WP5Study::FINAL_HEADS.each do |version, sha|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  rows = []
  (version == "2.0.1" ? ["12.0.1"] : %w[9.2.1 10.2.0]).each do |cucumber|
    study = LedgerQAAnalysis::WP5Study.new(root, stamp, cucumber)
    sets = %w[plain rich].to_h { |mode| [mode, study.run(mode)] }
    add = lambda do |shot, fixture, mode, criteria, view, only_logs = nil|
      actual_fixture = fixture
      if version == "1.3.2"
        actual_fixture = "F03-legacy-separate" if fixture == "F03"
        actual_fixture = "F02-description-only-golden" if fixture == "F02-golden"
      end
      snapshot = sets.fetch(mode)[actual_fixture]
      unless snapshot
        rows << { shot: shot, fixture: fixture, mode: mode, cucumber: cucumber, verdict: "BLOCKED_CAPTURE_PENDING", criteria: criteria }
        next
      end
      selected = study.logs(snapshot)
      selected = selected.select { |log| only_logs.call(log) } if only_logs
      launch = snapshot.fetch("launches").first
      suite = snapshot.fetch("items").find { |item| item["type"] == "SUITE" }
      scenario = snapshot.fetch("items").find { |item| item["type"] == "STEP" && item["hasStats"] }
      context = view == "suite-list" ? suite : scenario
      path = context && context.fetch("path").tr(".", "/")
      url = "http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/#{launch.fetch('id')}"
      url += "/#{path}#{view == 'suite-list' ? '' : '/log'}" if path && view != "launch-list"
      slug = "#{shot}-#{stamp}-c#{cucumber}-#{actual_fixture.downcase}-#{mode}-#{view}"
      rows << { shot: shot, slug: slug, line: version, runtime_sha: sha, cucumber: cucumber, fixture: fixture,
        actual_fixture: actual_fixture, fixture_scope: actual_fixture == fixture ? "Native fixture" : "Explicit companion; native compound syntax remains N/A under Decision4, never claimed supported",
        mode: mode, criteria: criteria, view: view, launch_id: launch.fetch("id"), item_id: context && context["id"],
        log_ids: selected.map { |log| log.fetch("id") }, url: url, viewport: { width: 1100, height: 780 },
        source_snapshot: study.refs(snapshot).fetch(:source), verdict: "PENDING_UI_OBSERVATION",
        planned_path: "docs/reviews/assets/presentation-ledger-#{version}/#{slug}.png",
        claim_limit: "A target plan is not a screenshot or DOM observation. No visual PASS is inferred from API data." }
    end
    errors = ->(log) { log["level"] == "error" }
    add.call("S01", "F04-frozen", "plain", ["P1.8"], "outer-fold-untouched", errors)
    add.call("S02", "F04-frozen", "plain", ["P1.9"], "stack-trace", errors)
    add.call("S03", "F04-frozen", "rich", %w[P10.8 P10.10], "both-folds-expanded", errors)
    %w[F03 F14].each { |fixture| add.call("S04", fixture, "plain", ["P2.1"], "escaped-table") }
    add.call("S05", "F02-golden", "plain", ["P4.3"], "suite-list")
    %w[plain rich].each do |mode|
      add.call("S06", "F01", mode, mode == "rich" ? %w[P5.8 P10.10] : ["P5.8"], "captions-preview-download")
      add.call("S08", "F13", mode, %w[P7.5 P10.9], "numeric-table")
      %w[F10a F10c F11a F11b F11c F12].each do |fixture|
        add.call("S09", fixture, mode, mode == "rich" ? ["P10.10"] : ["P8"], "cards-expanded")
      end
    end
    add.call("S07", "F15", "plain", ["P6.4"], "hook-rows")
    add.call("S10", "F19a", "plain", ["P9.5"], "launch-list")
    %w[F01 F04-frozen F10a F11a].each do |fixture|
      add.call("S11", fixture, "plain", ["P3.4"], "markdown-off-then-restored")
      add.call("S12", fixture, "plain", ["P3.4"], "console")
    end
    add.call("D01", "F14-negative", "plain", ["P1.6"], "literal-title-no-script-or-bold", errors)
    %w[F10a F10c F11a F11b].each { |fixture| add.call("D02", fixture, "rich", ["P10.11"], "computed-pill-contrast") }
  end
  output = File.join(root, "docs/reviews/assets", stamp, "screenshot-plan.json")
  File.write(output, JSON.pretty_generate(schema: "wp5-visual-target-plan/1", runtime_sha: sha, rows: rows) + "\n")
  puts JSON.generate(version: version, planned: rows.length, verdicts: rows.group_by { |row| row[:verdict] }.transform_values(&:length))
end
