# frozen_string_literal: true

require_relative "legacy_3778"

# Offline assertions only: no SDK execution, network, or new fixture generation.
root = P1Legacy3778::ROOT
assets = File.join(root, "docs/reviews/assets/1x-p1-20261101")
head = "df072ba0e6f603e66ba87e0b29c75fcc334a8e43"
read = ->(path) { JSON.parse(File.read(path)) }
sha = ->(path) { Digest::SHA256.file(path).hexdigest }
checks = []
check = lambda do |criterion, name, expected, actual, snapshot = nil, log = nil, inputs = {}|
  checks << { id: "P1FINAL-%04d" % (checks.length + 1), criterion: criterion, name: name,
    expected: expected, actual: actual, verdict: expected == actual ? "PASS" : "FAIL",
    launch_ids: snapshot ? snapshot.fetch("launches").map { |l| l.fetch("id") } : [],
    item_ids: log ? [log.fetch("itemId")] : [], log_ids: log ? [log.fetch("id")] : [], inputs: inputs }
end
decode = ->(text) { CGI.unescapeHTML(text).gsub(/\\([\\\x60*_\[\]|~])/, '\1') }
inline = ->(text) { text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub(/[\\`*_\[\]|~]/) { |c| "\\#{c}" } }
payload = lambda do |text, klass|
  blocks = P1Legacy3778.text_fences(text)
  full = text[/_Full message_\n\n(?<fence>`{3,}|~{3,})text\n(?<body>.*?)\n\k<fence>/m, "body"]
  title = decode.call(text.lines.first.chomp).delete_prefix("## \u2717 ")
  title = title == klass ? "" : title.delete_prefix("#{klass}: ") if klass
  message = full || title
  message += "\n#{blocks.first}" if !full && text.include?("_Project frames_")
  [message, blocks.length >= 2 ? blocks.last : ""]
end

files = Dir[File.join(assets, "fresh-{master,replay}-get-01/launch-*.json")].sort
files += Dir[File.join(assets, "f16-c10-plain-*-01/*/snapshot.json")].sort
snapshots = files.map { |p| read.call(p).merge("_observation" => p) }
check.call("G8", "Exactly the authorized 30 candidate Launches", (3807..3836).to_a,
  snapshots.flat_map { |s| s.fetch("launches").map { |l| l.fetch("id") } }.sort)
by_id = snapshots.to_h { |s| [s.fetch("launches").first.fetch("id"), s] }
inputs3778 = read.call(File.join(assets, "launch-3778-inputs.json"))
check.call("G8", "Immutable original-input file", "e13f5e4c02cfab1679628abafc7b9dda1682f5bd8480c793c6597a266609cdf7",
  sha.call(File.join(assets, "launch-3778-inputs.json")))
check.call("G8", "3778 baseline is actual v1.3.1", P1Legacy3778::BASE_SHA, inputs3778.fetch("baseline_sha"))
inputs3778.fetch("source_files").each_value do |binding|
  path = binding.fetch("path")
  bytes, status = Open3.capture2("git", "-C", root, "show", "#{inputs3778.fetch('capture_qa_commit')}:#{path}")
  check.call("G8", "Historical baseline capture remains committed and unchanged", [true, binding.fetch("sha256")],
    [status.success?, Digest::SHA256.hexdigest(bytes.b)], nil, nil, path: path, working_sha256: sha.call(File.join(root, path)))
end
baseline_runtime = read.call(File.join(root, P1Legacy3778::SAVED, "runtime.json"))
baseline_root = File.dirname(baseline_runtime.fetch("activation").fetch("sdk_gemspec"))
baseline_mismatches = baseline_runtime.fetch("loaded_sdk_sha256_at_start").map do |path, digest|
  relative = path.delete_prefix(baseline_root + "/")
  bytes, status = Open3.capture2("git", "-C", root, "show", "#{P1Legacy3778::BASE_SHA}:#{relative}")
  relative unless status.success? && Digest::SHA256.hexdigest(bytes.b) == digest
end.compact
check.call("G8", "All 33 actual v1.3.1 loaded files bind Launch 3778 to 4ca2f77", [33, []],
  [baseline_runtime.fetch("loaded_sdk_sha256_at_start").length, baseline_mismatches])
frozen = read.call(File.join(root, "docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json"))
frozen_tail = frozen.fetch("backtrace")
frozen_tail = frozen_tail.join("\n") if frozen_tail.is_a?(Array)
check.call("P1.1", "Original frozen F04 is still the complete 62-frame input",
  [62, "3fd9692c6e95a2e7e1868111ad41fd5f2584f95098c67d18ccc9756d66eca75d"],
  [frozen_tail.lines.length, Digest::SHA256.hexdigest(frozen_tail)], nil, nil,
  frozen.slice("source_launch_id", "source_item_id", "source_log_id", "source_api_verified"))
proposal = File.read(File.join(root, "docs/design/presentation-ledger-proposal.md"))
golden = proposal[/### P1 .*?````markdown\n(.*?)\n````/m, 1]
golden = golden[0...golden.rindex("```text\n")] + "```text\n#{frozen_tail}\n```"
expected_sdk = {}
sources = []

snapshots.each do |snapshot|
  id = snapshot.fetch("launches").first.fetch("id")
  observed = snapshot.fetch("_observation")
  if snapshot["source_capture"]
    original = snapshot.fetch("source_capture")
    suffix = original.split("simplified-1x-20261101-master-01/", 2).last
    portable = File.join(assets, "developer-live", suffix)
    original = portable if File.file?(portable)
    check.call("G8", "Fresh independent GET matches its bound source capture", snapshot.fetch("source_capture_sha256"), sha.call(original), snapshot)
    check.call("G8", "Fresh independent GET has complete item/log sets and final SHA", [true, head],
      [snapshot.fetch("item_and_log_sets_match_capture"), snapshot.fetch("final_runtime_sha")], snapshot)
  else
    original = observed
    check.call("G8", "F16 runner saved authenticated live readback", "live_readback", snapshot.fetch("persistence"), snapshot)
  end
  directory = File.dirname(original)
  runtime = read.call(File.join(directory, "runtime.json"))
  source_root = File.dirname(runtime.fetch("activation").fetch("sdk_gemspec"))
  hashes = runtime.fetch("loaded_sdk_sha256_at_start")
  mismatches = hashes.map do |path, digest|
    relative = path.delete_prefix(source_root + "/")
    expected_sdk[relative] ||= begin
      bytes, status = Open3.capture2("git", "-C", root, "show", "#{head}:#{relative}")
      raise "Missing final source #{relative}" unless status.success?
      Digest::SHA256.hexdigest(bytes.b)
    end
    relative unless digest == expected_sdk.fetch(relative)
  end.compact
  guard = read.call(File.join(directory, "source-guard.json"))
  check.call("G8", "Actual loaded SDK bytes match the frozen final runtime", [true, false, []],
    [guard.fetch("passed"), runtime.fetch("sdk_source_changed_during_fixture"), mismatches], snapshot,
    nil, loaded_files: hashes.length, runtime: runtime.fetch("ruby"), cucumber: runtime.fetch("cucumber"))
  sources << { launch_id: id, observation: observed.delete_prefix(root + "/"), sha256: sha.call(observed),
    capture: original.delete_prefix(root + "/"), capture_sha256: sha.call(original),
    runtime: File.join(directory, "runtime.json").delete_prefix(root + "/"), runtime_sha256: sha.call(File.join(directory, "runtime.json")),
    dependencies: %w[native.json native.ndjson inputs.ndjson source-guard.json fixture.json result.json process.json].map do |name|
      path = File.join(directory, name)
      { path: path.delete_prefix(root + "/"), sha256: sha.call(path) }
    end }
  errors = snapshot.fetch("logs").select { |l| l.fetch("level").downcase == "error" }
  native = read.call(File.join(directory, "native.json")).flat_map { |f| f.fetch("elements", []) }
    .flat_map { |e| e.fetch("steps", []) }.select { |s| s.dig("result", "status") == "failed" }
  exceptions = File.readlines(File.join(directory, "native.ndjson")).map { |line| JSON.parse(line) }
    .map { |e| e.dig("testStepFinished", "testStepResult", "exception") }.compact
  check.call("G8", "One persisted ERROR per intentional native failure", native.length, errors.length, snapshot)
  errors = P1Legacy3778.error_logs(snapshot).map(&:last) if errors.length == 14
  errors.each_with_index do |log, index|
    text = log.fetch("message")
    blocks = P1Legacy3778.text_fences(text)
    if (3827..3830).cover?(id)
      row = inputs3778.fetch("rows").fetch(index)
      expected_message, expected_tail, klass = row.fetch("message"), row.fetch("frames").join("\n"), "RuntimeError"
      outcome = P1Legacy3778.content_check(row, log)
      check.call("G8", "3778 original message plus every frame byte", true, outcome.fetch(:raw_failure_equal), snapshot, log, outcome)
    elsif [3811, 3816, 3821, 3826].include?(id)
      expected_message, expected_tail, klass = frozen.fetch("error_message"), frozen_tail, "RuntimeError"
      check.call("P1.1", "Frozen F04 all 62 tail lines are byte-identical", frozen_tail, blocks.last, snapshot, log)
      check.call("P1.1", "Plain frozen F04 equals the complete proposal golden", golden, text, snapshot, log) if [3811, 3821].include?(id)
    elsif id == 3835
      adapter = File.readlines(File.join(directory, "inputs.ndjson")).map { |line| JSON.parse(line) }.find { |e| e["kind"] == "non_exception_event_adapter" }
      fields = adapter.fetch("fields").fetch("result")
      expected_message, expected_tail, klass = fields.fetch("message"), fields.fetch("backtrace").join("\n"), nil
    elsif id == 3836
      adapter = File.readlines(File.join(directory, "inputs.ndjson")).map { |line| JSON.parse(line) }
        .find { |e| e["kind"] == "controlled_framework_only_event_input" }
      expected_message, expected_tail, klass = adapter.fetch("message"), adapter.fetch("backtrace").join("\n"), adapter.fetch("error_class")
    else
      exception = exceptions.fetch(index)
      expected_message, klass = exception.fetch("message"), exception.fetch("type")
      prefix = "#{expected_message} (#{klass})\n"
      raw = native.fetch(index).fetch("result").fetch("error_message")
      raise "Unrecoverable native message/frame split at Launch #{id}" unless raw.start_with?(prefix)
      expected_tail = raw.delete_prefix(prefix)
    end
    actual_message, actual_tail = payload.call(text, klass)
    check.call(id == 3834 ? "P1.7" : "G8", "Original failure message and complete native/replayed tail, without normalization",
      [expected_message, expected_tail], [actual_message, actual_tail], snapshot, log,
      source: directory.delete_prefix(root + "/"), original_class: klass,
      expected_sha256: Digest::SHA256.hexdigest([expected_message, expected_tail].reject(&:empty?).join("\n")),
      actual_sha256: Digest::SHA256.hexdigest([actual_message, actual_tail].reject(&:empty?).join("\n")))
    unless id == 3833
      title = klass ? [klass, expected_message.lines.first.to_s.chomp].reject(&:empty?).join(": ") : expected_message
      check.call("P1.2", "Literal escaped failure title", "## \u2717 #{inline.call(title)}", text.lines.first.chomp, snapshot, log)
    end
    next if expected_tail.empty?
    frames = expected_tail.split("\n")
    stdlib = "/usr/local/lib/ruby/#{runtime.fetch('ruby')[/\d+\.\d+/]}.0/"
    framework = frames.select { |f| f.include?("/gems/") || f.start_with?(stdlib) }
    runner = frames.select { |f| f.start_with?("-e:", "<internal:") }
    project = frames - framework - runner
    feature = project.find { |f| f.match?(/\.feature:\d+/) }
    shown = project.empty? ? framework.first(3) : (project - [feature]).first(8) + [feature].compact
    hidden = { framework: framework.length - (project.empty? ? shown.length : 0), runner: runner.length,
      project: project.length - (project.empty? ? 0 : shown.length) }.select { |_, n| n.positive? }
    kinds = hidden.map { |kind, n| "#{n} #{kind}" }
    words = kinds.length == 3 ? "#{kinds[0]}, #{kinds[1]} and #{kinds[2]}" : kinds.join(" and ")
    caption = "Full backtrace \u00b7 #{frames.length} #{frames.length == 1 ? 'frame' : 'frames'}"
    caption += " \u00b7 #{words} #{frames.length - shown.length == 1 ? 'frame' : 'frames'} not shown above" unless hidden.empty?
    actual_caption = text[/_(Full backtrace[^\n]+)_/, 1] || CGI.unescapeHTML(text[/<summary[^>]*>(.*?)<\/summary>/m, 1].to_s.gsub(/<[^>]+>/, ""))
    check.call("P1.3", "Count every original frame and hidden class", caption, actual_caption, snapshot, log,
      total: frames.length, framework: framework.length, runner: runner.length, project: project.length)
    displayed = blocks.fetch(text.include?("_Project frames_") ? 1 : 0).split("\n")
    methods = shown.map { |f| f[/:in ['`](.*?)['"]\z/, 1].to_s }
    check.call("P1.4", "Shown count, original method order, feature last, location cap", [shown.length, methods, true, true],
      [displayed.length, displayed.map { |line| line.split(/\s{2,}/, 2)[1].to_s },
       !feature || displayed.last.split(/\s{2,}/, 2).first.match?(/\.feature:\d+/),
       displayed.all? { |line| line.split(/\s{2,}/, 2).first.length <= 40 }], snapshot, log,
      original_shown_frames: shown)
  end
end

error_at = ->(id) { by_id.fetch(id).fetch("logs").find { |l| l["level"].downcase == "error" } }
check.call("P1.2", "Non-Exception fallback title", "## \u2717 Non-Exception failure", error_at.call(3835)["message"].lines.first.chomp, by_id[3835], error_at.call(3835))
check.call("P1.2", "Empty exception message title", "## \u2717 RuntimeError", error_at.call(3832)["message"].lines.first.chomp, by_id[3832], error_at.call(3832))
long = error_at.call(3833)
check.call("P1.2", "Long title is exactly 200 characters and ends in ellipsis", [200, true],
  [long["message"].lines.first.chomp.length, long["message"].lines.first.chomp.end_with?("\u2026")], by_id[3833], long)
check.call("P1.4", "Framework-only branch shows precisely its first three frames",
  "first.rb:11   Framework.one\nsecond.rb:22  Framework.two\nthird.rb:33   Framework.three",
  P1Legacy3778.text_fences(error_at.call(3836)["message"]).first, by_id[3836], error_at.call(3836))
multi = error_at.call(3831)
check.call("P1.5", "F16a raw continuation immediately precedes Project frames", true,
  multi["message"].include?("```text\nsecond line <other>\nthird line `tick`\n```\n\n_Project frames_"), by_id[3831], multi)
check.call("P1.5", "F16a continuation follows the meta line", true,
  multi["message"].match?(/\n\n`[^\n]+`\n\n```text\nsecond line <other>/), by_id[3831], multi)
[3811, 3821, 3832, 3833, 3834, 3836].each do |id|
  check.call("P1.5", "No Project frames caption without continuation", false, error_at.call(id)["message"].include?("_Project frames_"), by_id[id], error_at.call(id))
end
[[3811, 3821], [3816, 3826]].each do |first, second|
  prefix = ->(id) { error_at.call(id)["message"].split(/_Full backtrace|<details\b/, 2).first }
  check.call("P1.10", "Separate C9/C10 frozen-input runs have identical pre-tail text", prefix.call(first), prefix.call(second), by_id[second], error_at.call(second),
    comparison_launch_id: first, comparison_log_id: error_at.call(first)["id"], boundary: "Same frozen input and presentation mode; distinct native Cucumber stacks are not compared")
end
ui = read.call(File.join(assets, "screenshots/ui-observations.json"))
ui.each do |observation|
  check.call(observation.fetch("criterion"), "Independent CUA UI/DOM observation", "PASS", observation.fetch("verdict"),
    by_id.fetch(observation.fetch("launch_id")), { "id" => observation.fetch("log_id"), "itemId" => observation.fetch("item_id") }, observation)
end
log_hits = snapshots.flat_map { |s| s.fetch("logs").select { |l| JSON.generate(l).include?("SECRET123") }.map { |l| l.fetch("id") } }
other_hits = snapshots.flat_map { |s| (s.fetch("items") + s.fetch("launches")).select { |v| JSON.generate(v).include?("SECRET123") }.map { |v| v.fetch("id") } }
check.call("G8", "Only D19's exact original synthetic F16f content contains the marker", [[20013], []], [log_hits.sort, other_hits.sort], by_id[3834], error_at.call(3834),
  policy: "D19 raw legacy failure content, not a zero-hit redaction gate")
criteria = (["G8"] + (1..10).map { |n| "P1.#{n}" }).map do |id|
  selected = checks.select { |c| c[:criterion] == id }
  { id: id, verdict: selected.empty? ? "BLOCKED" : selected.all? { |c| c[:verdict] == "PASS" } ? "PASS" : "FAIL", check_ids: selected.map { |c| c[:id] } }
end
result = { schema: "independent-1x-p1-acceptance/1", scope: "1.x P1.1-P1.10/G8 only; D19 governs raw failure content",
  candidate_sha: head, baseline_sha: P1Legacy3778::BASE_SHA, baseline_launch_id: 3778,
  baseline_observation: "Reused committed historical GET with immutable input provenance; not a newly fetched baseline",
  verdict: criteria.all? { |c| c[:verdict] == "PASS" } ? "PASS" : "NOT_ACCEPTED",
  release_authorized: false, criteria: criteria, checks: checks, sources: sources,
  helper_tests: { command: "ruby spec/acceptance/ledger_qa/p1_1x/legacy_3778_test.rb", runs: 4, assertions: 6, failures: 0, errors: 0, skips: 0, seed: 47972 },
  retained_diagnostics: [
    { observation: "Initial Stack trace h2 locator found no heading element", resolution: "RP displays raw Markdown in Stack trace; first-line text and S02 were verified instead", evidence: "screenshots/ui-observations.json" },
    { observation: "Earlier pre-Cucumber F04 expected_backtrace was not byte-equal to final event backtrace", launches: [3808, 3813, 3818, 3823],
      pre_cucumber_frame_counts: [57, 57, 58, 58], final_native_frame_counts: [59, 59, 60, 60],
      resolution: "Do not equate different event stages. Final native JSON message/frame splits match the complete ERROR tails exactly; no normalization was applied" }
  ],
  exclusions: ["G11", "V criteria", "2.x", "historical corpus reconstruction", "matrix execution or certification", "release authorization"],
  historical_evidence: "docs/reviews/assets/presentation-ledger-1.3.2-acceptance.json is unchanged historical scope",
  scorer_sha256: Digest::SHA256.file(__FILE__).hexdigest }
File.write(File.join(assets, "scoped-acceptance.json"), JSON.pretty_generate(result) + "\n")
puts JSON.pretty_generate(verdict: result[:verdict], criteria: criteria.map { |c| c.slice(:id, :verdict) },
  checks: checks.length, failures: checks.reject { |c| c[:verdict] == "PASS" }.map { |c| c.slice(:id, :criterion, :name, :expected, :actual, :launch_ids) })
exit(result[:verdict] == "PASS" ? 0 : 1)
