# frozen_string_literal: true

require_relative "host"
require_relative "../p106_clarified"
require "cgi"

# Offline evidence reader only: no SDK loading, networking, Docker, or clocks.
module Ledger202Assessment
  ROOT = Ledger202Host::ROOT
  DATA = Ledger202Host::OUTPUT
  FINAL = "090b633842f5b24d46a244f854daf95c9477b9ca"
  PAIRS = [%w[candidate-plain candidate-rich], %w[candidate-frozen-plain candidate-frozen-rich],
    %w[candidate-framework-plain candidate-framework-rich], %w[candidate-supplement-plain candidate-supplement-rich],
    %w[candidate-contract-plain candidate-contract-rich]].freeze
  TARGETS = ((1..10).map { |i| "P1.#{i}" } + (1..9).map { |i| "P8.#{i}" } +
    (1..11).map { |i| "P10.#{i}" } + %w[G8 G11]).freeze
  GAPS = {
    "P1.6" => "Escaped F14 titles verified in API bytes; literal script/b DOM proof was not captured before outage.",
    "P10.8" => "HTTP headers have saved expanded details > pre > code DOM proof. Long body/preview DOM proof remains missing.",
    "P10.10" => "S03 and HTTP S09 saved; media S06, numeric S08 and assertion/evidence S09 views remain missing.",
    "P10.11" => "Only the green HTTP 201 computed style was saved; amber/red WARN and blue media tone computed styles remain missing.",
    "G11" => "STOP: plain redaction-plus-rendering p95 exceeded +10%. Rich, F07 and remaining Presentation timings not run; no retest."
  }.freeze

  def self.json(path) = JSON.parse(File.binread(path))
  def self.digest(value) = Digest::SHA256.hexdigest(JSON.generate(value))
  def self.fences(text) = text.scan(/```(?:text|json)\n(.*?)\n```/m).flatten
  def self.fixture(label, id) = json(File.join(DATA, label, id, "snapshot.json")).merge("_directory" => File.join(DATA, label, id))
  def self.message(id, label = "candidate-plain") = fixture(label, id).fetch("logs").min_by { |l| l["id"] }.fetch("message")

  def self.refs(snapshot, logs = nil)
    { path: snapshot.fetch("_directory").delete_prefix(ROOT + "/") + "/snapshot.json",
      launch_ids: snapshot.fetch("launches").map { |l| l["id"] },
      item_ids: (logs || snapshot["logs"]).map { |l| l["itemId"] }.uniq,
      log_ids: (logs || snapshot["logs"]).map { |l| l["id"] } }
  end

  def self.check(id, name, passed, evidence = {}, detail = {})
    @checks << { check_id: format("QA202-OFFLINE-%04d", @checks.length + 1), criterion: id,
      check: name, status: passed ? "PASS" : "FAIL", evidence: evidence, detail: detail }
  end

  def self.terminal(text)
    text.gsub(/\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?/, "<timestamp>")
      .gsub(/^\d+m\d+(?:\.\d+)?s$/, "<cucumber-stopwatch>")
  end

  def self.native(path)
    ids = {}
    rewrite = lambda do |value|
      case value
      when Hash then value.to_h { |k, v| [k, %w[timestamp duration start finish].include?(k) ? "<clock>" : rewrite.call(v)] }
      when Array then value.map { |v| rewrite.call(v) }
      when String then value.gsub(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i) { |id| ids[id] ||= "<id-#{ids.length}>" }
      else value
      end
    end
    rewrite.call(File.readlines(path).map { |line| JSON.parse(line) })
  end

  def self.paths(snapshot)
    items = snapshot["items"].to_h { |i| [i["id"], i] }
    walk = ->(id) { id ? walk.call(items.fetch(id)["parent"]) + "/" + items.fetch(id)["name"] : "Launch" }
    items.keys.to_h { |id| [id, walk.call(id)] }
  end

  def self.metadata(snapshot)
    locations = paths(snapshot)
    items = snapshot["items"].map do |i|
      [locations[i["id"]], i["description"], i.fetch("attributes", []).sort_by { |a| JSON.generate(a.sort.to_h) }]
    end.sort_by(&:first)
    launches = snapshot["launches"].map { |l| [l["description"], l.fetch("attributes", []).sort_by { |a| JSON.generate(a.sort.to_h) }] }
    [items, launches]
  end

  def self.paired
    @pair_count = @severe_count = @max_delta = 0
    PAIRS.each do |left, right|
      Dir[File.join(DATA, left, "*", "snapshot.json")].sort.each do |path|
        a = json(path).merge("_directory" => File.dirname(path))
        bpath = path.sub("/#{left}/", "/#{right}/")
        b = json(bpath).merge("_directory" => File.dirname(bpath))
        key = lambda do |log, snap, rich|
          first = log["message"].lines.first.to_s.gsub(/<span style="[^"]+">|<\/span>/, "")
          [paths(snap).fetch(log["itemId"], "Launch"), log["level"], LedgerQALegibility.canonical(first, rich: rich)]
        end
        ls = a["logs"].sort_by { |l| key.call(l, a, false).to_s }
        rs = b["logs"].sort_by { |l| key.call(l, b, true).to_s }
        check("P10.6", "Pair by owner, level and normalized first-line identity", ls.map { |l| key.call(l, a, false) } == rs.map { |l| key.call(l, b, true) }, refs(b))
        ls.zip(rs).each do |l, r|
          raise "Missing pair" unless r
          p, q = l.values_at("message").first, r["message"]
          evidence = { plain: refs(a, [l]), rich: refs(b, [r]) }
          @pair_count += 1
          delta = q.bytesize - p.bytesize
          @max_delta = [@max_delta, delta].max
          check("P10.5", "Paired rich byte budget", delta <= 1024, evidence, delta_bytes: delta)
          severe = %w[error fatal].include?(l["level"])
          if severe
            @severe_count += 1
            check("P10.4", "Entire ERROR/FATAL message byte identity", p == q, evidence, sha256: Digest::SHA256.hexdigest(p))
          end
          # Decision 27 moved the WARN meta pill with its URL after the response.
          # Remove only the exact previously approved decorative status token.
          normalized = q.dup
          annotation = nil
          if l["level"] == "warn" && (status = p.lines.first[/\u2192 (\d{3}|unknown)/, 1])
            tone = status.to_i >= 500 ? "color:#B23B3B;background:#FBEAEA" : "color:#8A5A00;background:#FFF3D6"
            token = "<span style=\"#{LedgerQALegibility::PILL};#{tone}\">#{status}</span>"
            if normalized.scan(token).length == 1 && normalized.match?(/^#{Regexp.escape(token)} (?:\u00b7 )?`https?:/)
              normalized = normalized.sub(token, "")
              annotation = "Exact WARN status pill at response-first URL line"
            end
          end
          comparison = LedgerQALegibility.compare(p, normalized, channel: p == q ? :raw : :client,
            family: File.basename(a["_directory"]) == "F12" ? :evidence : nil)
          check("P10.6", "Protected code bytes and approved text order", comparison[:verdict] == "PASS", evidence,
            code_bytes_identical: comparison[:code_bytes_identical], canonical_equal: comparison[:exact_canonical_word_equality], annotation: annotation,
            fragments: comparison[:unexpected_unprotected_fragments])
          stripped = LedgerQALegibility.strip_generated(p, q)
          check("P10.3", "Generated HTML uses exact normative allowlist; caller data protected", stripped[:unexpected_unprotected_fragments].empty? && stripped[:missing_original_lines].empty? && (!severe || p == q), evidence)
          q.scan(/<details><summary>[^<]*<\/summary>(.*?)<\/details>/m).flatten.each do |inside|
            check("P10.8", "Blank lines surround details code fence", inside.start_with?("\n\n```") && inside.end_with?("```\n\n"), evidence)
          end
        end
        check("P10.7", "Item and Launch metadata unchanged between modes (intentional cohort Launch name excluded)", metadata(a) == metadata(b), refs(b))
        na, nb = [a, b].map { |s| native(File.join(s["_directory"], "native.ndjson")) }
        check("P10.7", "Complete native envelopes equal after UUID/clock normalization", na == nb, refs(b), plain_digest: digest(na), rich_digest: digest(nb))
        pa, pb = [a, b].map { |s| json(File.join(s["_directory"], "process.json")) }
        check("P10.7", "Terminal bytes unchanged between modes", terminal(pa["stdout"]) == terminal(pb["stdout"]), refs(b), normalization: "Timestamp and Cucumber stopwatch only; counts and all other bytes retained")
      end
    end
  end

  def self.global
    @snapshots = Dir[File.join(DATA, "*", "*", "snapshot.json")].sort.map { |p| json(p).merge("_directory" => File.dirname(p)) }
    raise "Expected 139 completed Launches" unless @snapshots.length == 139
    @snapshots.each do |s|
      directory = s["_directory"]
      safety = json(File.join(directory, "safety.json"))
      guard = json(File.join(directory, "source-guard.json"))
      check("BINDING", "Capture safety and immutable source guard", safety["status"] == "CLEAR_TO_CONTINUE" && guard["passed"], refs(s))
      fields = s["logs"].map { |l| l["message"] } + (s["items"] + s["launches"]).map { |i| i.slice("name", "description", "attributes") }
      check("G8", "Secret query and complete RP field scan", !JSON.generate(fields).include?("SECRET123") && s["queries"].all? { |q| q.dig("secret_marker", "page", "totalElements") == 0 }, refs(s))
      check("P8.6", "INFO messages never begin with level-two heading", s["logs"].none? { |l| l["level"] == "info" && l["message"].start_with?("## ") }, refs(s))
      next unless File.basename(File.dirname(directory)).start_with?("candidate")
      native_rows = File.readlines(File.join(directory, "native.ndjson")).map { |line| JSON.parse(line) }
      errors = native_rows.filter_map { |row| row.dig("testStepFinished", "testStepResult", "exception") }
      unless directory.match?(/frozen|framework/)
        errors.each do |error|
          tail = error.fetch("stackTrace", "")
          next if tail.empty?
          found = s["logs"].find { |l| l["level"] == "error" && l["message"].include?("\n#{tail}\n") }
          check("P1.1", "Complete native failure tail retained byte-for-byte", !found.nil?, refs(s, found ? [found] : []), frames: tail.lines.length, tail_sha256: Digest::SHA256.hexdigest(tail))
        end
      end
      s["logs"].select { |l| l["message"].include?("_Full backtrace") }.each do |log|
        text = log["message"]
        blocks = fences(text)
        frames = blocks.last.lines.map(&:chomp)
        framework = frames.select { |f| f.include?("/gems/") || f.start_with?("/usr/local/lib/ruby/3.4.0/") }
        runner = frames.select { |f| f.start_with?("-e:", "<internal:") }
        projects = frames - framework - runner
        feature = projects.find { |f| f.match?(/\.feature:\d+/) }
        shown_count = projects.empty? ? [framework.length, 3].min : [(projects - [feature]).length, 8].min + (feature ? 1 : 0)
        shown = blocks[-2].to_s.lines.map(&:chomp)
        hidden = { framework: framework.length - (projects.empty? ? shown_count : 0), runner: runner.length,
          project: projects.length - (projects.empty? ? 0 : shown_count) }.filter_map { |kind, n| "#{n} #{kind}" if n.positive? }
        caption = "#{frames.length} #{frames.length == 1 ? 'frame' : 'frames'}"
        unless hidden.empty?
          words = hidden.length == 3 ? "#{hidden[0]}, #{hidden[1]} and #{hidden[2]}" : hidden.join(" and ")
          caption += " \u00b7 #{words} #{frames.length - shown_count == 1 ? 'frame' : 'frames'} not shown above"
        end
        check("P1.3", "Independently count total/framework/runner/project frames", caption == text[/_Full backtrace \u00b7 ([^\n]+)_/, 1], refs(s, [log]))
        check("P1.4", "Shown-frame cap and feature-last", shown.length == shown_count && (!feature || shown.last.to_s.include?(".feature:")), refs(s, [log]))
      end
    end
  end

  def self.golden(label)
    section = @proposal.split(label, 2).last or raise "Missing golden heading"
    match = section.match(/\n(`{3,})markdown\n(.*?)\n\1\n/m) or raise "Missing golden block"
    match[2]
  end

  def self.focused
    frozen = fixture("candidate-frozen-plain", "F04-frozen")
    original = json(File.join(ROOT, "docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json"))
    tail = original.fetch("backtrace")
    tail = tail.join("\n") if tail.is_a?(Array)
    actual = frozen["logs"].find { |l| l["level"] == "error" }["message"]
    p1 = golden("**Output (Launch 76 fixture):**").split("\n```text\n").first(2).join("\n```text\n")
    p1 = p1.split("\n```text\n/Users/").first
    check("P1.1", "Frozen golden prefix and all original 62 frames", actual.start_with?(p1) && tail.lines.length == 62 && actual.end_with?("\n#{tail}\n```"), refs(frozen), raw_tail_sha256: Digest::SHA256.hexdigest(tail))
    repeat = fixture("candidate-frozen-repeat", "F04-frozen")
    again = repeat["logs"].find { |l| l["level"] == "error" }["message"]
    check("P1.10", "Separate fresh frozen F04 executions are byte-identical", actual == again, { first: refs(frozen), repeat: refs(repeat) })
    check("P1.2", "Non-Exception fallback and empty class title", message("F16c-adapted", "candidate-frozen-plain") == "## \u2717 Non-Exception failure" && message("F16d").lines.first.chomp == "## \u2717 RuntimeError", refs(fixture("candidate-plain", "F16d")))
    long = message("F16e").lines.first.chomp
    check("P1.2", "200-character title cap", long.length == 200 && long.end_with?("\u2026"), refs(fixture("candidate-plain", "F16e")), title_length: long.length)
    literals = ["<other>", "<b>x</b>", "a | b", "back\\slash", "*star*", "_under_", "`tick`", "&amp;", "# heading", "1. item", "x<script>alert(1)</script>", "emoji \u{1F7E2}", "CJK \u4E2D\u6587", "first\nsecond"]
    escaped = fixture("candidate-plain", "F14-negative")
    escaped["logs"].sort_by { |l| l["id"] }.zip(literals).each do |log, literal|
      decoded = CGI.unescapeHTML(log["message"].lines.first.chomp.delete_prefix("## \u2717 RuntimeError: ").gsub(/\\([\\`*_\[\]{}()#+.!|>~-])/, '\1'))
      check("P1.2", "Escaped title retains original literal", decoded == literal.lines.first.chomp, refs(escaped, [log]))
    end
    multiline = message("F16a")
    check("P1.5", "Safe continuation fenced and project caption conditional", multiline.include?("```text\nsecond line <other>\nthird line `tick`\n```\n\n_Project frames_") && !message("F16d").include?("_Project frames_"), refs(fixture("candidate-plain", "F16a")))
    cases = [["candidate-supplement-plain", "QA202-backslash", false], ["candidate-contract-plain", "C202-regex", false],
      ["candidate-supplement-plain", "QA202-windows", false], ["candidate-supplement-plain", "QA202-diff", true],
      ["candidate-contract-plain", "C202-embedded_json", true], ["candidate-contract-plain", "C202-escaped_json", true]]
    cases.each do |label, id, withheld|
      s = fixture(label, id)
      check("P1.7", "Exact redaction contract: #{id}", s["logs"][0]["message"].include?("Message withheld: unsafe or ambiguous input") == withheld, refs(s), expected_withheld: withheld)
    end
    check("P1.7", "F16f secret redacted without dropping frames", message("F16f").include?("REDACTED") && message("F16f").include?("_Full backtrace"), refs(fixture("candidate-plain", "F16f")))
    [["P8.1", "F10c", "**Failed assertion (ERROR):**"], ["P8.1", "F10a", "**Passed assertion (INFO), one line:**"],
      ["P8.4", "F11a", "**HTTP exchange, INFO:**"], ["P8.5", "F12", "**Failure evidence (ERROR):**"]].each do |criterion, id, heading|
      check(criterion, "Exact UTF-8 amended normative golden", message(id) == golden(heading), refs(fixture("candidate-plain", id)))
    end
    check("P8.2", "Long chip omitted; object and nested details fenced", !message("F10b").include?("expected") && message("F10d").include?("changed: `notional`") && %w[F10d F10e].all? { |id| message(id).include?("_Details_\n\n```json\n") }, refs(fixture("candidate-plain", "F10d")))
    input = File.readlines(File.join(DATA, "candidate-plain/F10c/inputs.ndjson")).map { |l| JSON.parse(l) }.find { |r| r["kind"] == "assertion" }
    lines = input["actual"].split("\n", -1)
    expected_actual = "actual    " + lines.first + "\n" + lines.drop(1).map { |line| "          #{line}" }.join("\n")
    check("P8.3", "Every actual line retained with ten-column continuation indent", message("F10c").include?(expected_actual), refs(fixture("candidate-plain", "F10c")))
    values = fixture("candidate-supplement-plain", "QA202-values")
    expected = { "empty" => '"" (empty string)', "spaces" => '"   " (3 spaces)', "edges" => '" a " (leading/trailing whitespace)', "tabs" => '"\\t" (whitespace only)', "ordinary" => "expected  abc\nactual    abc" }
    expected.each do |name, needle|
      log = values["logs"].find { |l| l["message"].lines.first.include?("QA202 #{name}") }
      check("P8.1", "Whitespace/ordinary value #{name}", log && log["message"].include?(needle), refs(values, [log].compact))
    end
    delta = values["logs"].find { |l| l["message"].lines.first.include?("QA202 delta") }
    check("P8.1", "Sorted top-level missing/extra/changed delta", delta["message"].include?("missing in actual: `missing` \u00b7 extra in actual: `extra` \u00b7 changed: `change`") && values["logs"].select { |l| l["message"].lines.first.match?(/QA202 (nested_only|equal)/) }.none? { |l| l["message"].match?(/missing in actual:|extra in actual:|changed:/) }, refs(values))
    check("P8.4", "WARN/error/transport failure metadata", message("F11b").start_with?("## \u26a0 GET /words \u2192 404 \u00b7 31 ms") && message("F11c").start_with?("## \u2717") && message("F11c").include?("expected `200`") && message("F11d").include?("error `Connection refused`"), refs(fixture("candidate-plain", "F11c")))
    http = fixture("candidate-supplement-plain", "QA202-http")
    http["logs"].select { |l| l["message"].include?("/ledger?plain=value") }.each do |log|
      m = log["message"]
      markers = ["_Response_", "`https://", "_Request_", "_Request headers", "_Response headers"].map { |marker| m.index(marker) }
      check("P8.4", "Response-first order, scalar media, all safe repeated header values", markers.none?(&:nil?) && markers == markers.sort && m.include?("X-Multi: first\nX-Multi: second") && m.include?("X-Multi: alpha\nX-Multi: beta") && m.include?("_Response_ \u00b7 `application/json`") && m.include?("Set-Cookie: [REDACTED]"), refs(http, [log]), redacted_header_note: "Set-Cookie is wholly redacted under pre-existing security policy, not flattened into unsafe values")
    end
    check("P8.5", "Empty evidence action fallback and attachment/owner invariants", fixture("candidate-plain", "F12")["logs"].any? { |l| l["message"].start_with?("## \u2717 Failure evidence\n") } && @snapshots.all? { |s| json(File.join(s["_directory"], "safety.json"))["status"] == "CLEAR_TO_CONTINUE" }, refs(fixture("candidate-plain", "F12")))
    check("P8.7", "Redacted URL in title and URL line", message("F11f").lines.first.include?("%5BREDACTED%5D") && message("F11f").include?("`https://api.example.test/orders?token=%5BREDACTED%5D&page=2`"), refs(fixture("candidate-plain", "F11f")))
    Dir[File.join(DATA, "candidate-{plain,rich}", "F{10,11,12}*", "process.json")].each do |path|
      old = path.sub(/candidate-(plain|rich)/, "baseline-main")
      check("P8.8", "Baseline terminal bytes", terminal(json(path)["stdout"]) == terminal(json(old)["stdout"]), { current: path.delete_prefix(ROOT + "/"), baseline: old.delete_prefix(ROOT + "/") }, normalization: "Ignore timestamps and Cucumber stopwatch only; scenario/step counts retained")
    end
    old_http = fixture("baseline-supplement", "QA202-http")
    http["logs"].select { |l| l["message"].match?(%r{/lines\d+|/bytes\d+}) }.each do |log|
      route = log["message"].lines.first[%r{/(?:lines|bytes)\d+}]
      old = old_http["logs"].find { |l| l["message"].lines.first.include?(route) }
      body, old_body = [log, old].map { |l| fences(l["message"].split("_Response_", 2).last).first }
      if route.start_with?("/lines")
        count = route.delete_prefix("/lines").to_i
        expected = Array.new([count, 100].min, "body-line").join("\n")
        expected += "\n[preview truncated]" if count > 100
      else
        count = route.delete_prefix("/bytes").to_i
        expected = "x" * [count, 16_384].min
        expected += "\n[preview truncated]" if count > 16_384
      end
      check("P8.9", "Response-first preview preserves 100-line/16-KiB bounds: #{route}", body == expected, refs(http, [log]),
        body_bytes: body.bytesize, body_lines: body.lines.length, baseline_body_bytes: old_body.bytesize,
        baseline_body_lines: old_body.lines.length, identical_preview: body == old_body,
        note: "Existing shared preview budget remains bounded. Response-first ordering now allocates body lines before headers; the truncation marker itself is outside the content budget.")
    end
    source_paths = %w[lib/reportportal_cucumber/service/evidence_presenter.rb lib/reportportal_cucumber/automation/http_exchange.rb]
    source_paths.each do |path|
      limits = %w[baseline final-090b6338].map do |role|
        File.readlines(File.join(Ledger202Host::SOURCE, role, path)).grep(/\A\s+(?:SUMMARY_LIMIT|DETAILS_LIMIT|VALUE_LIMIT|MAX_PREVIEW_BYTES|MAX_PREVIEW_LINES) =/).map(&:strip)
      end
      check("P8.9", "Existing limit constants unchanged: #{path}", !limits[0].empty? && limits[0] == limits[1], { source_path: path }, limits: limits)
    end
    inputs = %w[baseline-supplement candidate-supplement-plain].map do |label|
      File.readlines(File.join(DATA, label, "QA202-http/inputs.ndjson")).map { |line| JSON.parse(line) }.select { |r| r["kind"] == "http" }
    end
    check("P8.9", "All nine raw HTTP probe inputs identical between baseline and candidate", inputs[0] == inputs[1] && inputs[0].length == 9, refs(http), input_sha256: inputs.map { |i| digest(i) })
    over = values["logs"].find { |l| l["message"].lines.first.include?("oversized") }
    old_over = fixture("baseline-supplement", "QA202-values")["logs"].find { |l| l["message"].lines.first.include?("oversized") }
    check("P8.9", "Oversized details omission unchanged", over["message"] == old_over["message"] && over["message"].include?("[diagnostic omitted: unsafe or oversized input]"), refs(values, [over]))
    defaults = @snapshots.select { |s| s["_directory"].include?("/candidate-default/") }
    check("P10.1", "Unset mode defaults to plain on five fresh fixtures", defaults.length == 5 && defaults.all? { |s| s["logs"].none? { |l| l["message"].match?(/<details|<summary|<span style/) } }, defaults.map { |s| refs(s) })
    @snapshots.select { |s| s["_directory"].match?(%r{/candidate[^/]*/F20$}) }.each do |s|
      process = json(File.join(s["_directory"], "process.json"))
      check("P10.2", "One invalid-mode warning and plain output", process["stderr"].scan("Invalid RP_PRESENTATION; using plain presentation").length == 1 && s["logs"].none? { |l| l["message"].match?(/<details|<summary|<span style/) }, refs(s))
    end
    tables = fixture("candidate-rich", "F14")
    wide = fixture("candidate-rich", "F13")
    records = (tables["logs"] + wide["logs"]).filter_map do |log|
      columns = log["message"].lines.first[/_Data table \u00b7 (\d+) columns?/, 1]
      next unless columns
      [log["id"], columns.to_i, log["message"].scan(LedgerQALegibility::TH).length]
    end
    check("P10.9", "TH accents only on <=6-column tables; F13 also contains a separate eligible four-column table", records.any? { |_, c, n| c == 8 && n == 0 } && records.all? { |_, c, n| n == (c <= 6 ? c : 0) }, { small: refs(tables), wide: refs(wide) }, tables: records)
    %w[F19a F19b F19c F19d].each do |id|
      s = fixture("candidate-plain", id)
      description = s["launches"][0]["description"].to_s
      attrs = s["launches"][0]["attributes"]
      expected = { "F19a" => "4 workers \u00b7 feature/ledger@e7dae2b \u00b7 build 42", "F19b" => "4 workers \u00b7 feature/ledger@e7dae2b \u00b7 build 42", "F19c" => "Given description", "F19d" => "" }.fetch(id)
      attributes_ok = id == "F19d" ? attrs.empty? : attrs.any? { |a| a["key"] == "ruby" } && attrs.any? { |a| a["key"] == "cucumber" }
      check("P10.7", "Generated, explicit and disabled run-context cases: #{id}", description == expected && attributes_ok, refs(s), description: description)
    end
  end

  def self.trials
    @trial_rows = Dir[File.join(DATA, "trial-readback", "*.json")].sort.map do |path|
      s = json(path)
      fields = s["logs"].map { |l| l["message"] } + (s["items"] + [s["launch"]]).map { |r| r.slice("name", "description", "attributes") }
      files_valid = s["files"].all? do |file|
        bytes = Base64.strict_decode64(file["base64"])
        bytes.bytesize == file["bytes"] && Digest::SHA256.hexdigest(bytes) == file["sha256"] && !bytes.include?("SECRET123".b)
      end
      check("G8", "Final comparable item-level log reads and stored attachment validation", s["secret_marker_total"] == 0 && !JSON.generate(fields).include?("SECRET123") && files_valid, { path: path.delete_prefix(ROOT + "/"), launch_ids: [s["launch"]["id"]], log_ids: s["logs"].map { |l| l["id"] } })
      after = s["files"].filter_map do |f|
        item = s["items"].find { |i| i["id"] == f["item_id"] }
        next unless item["type"] == "AFTER_METHOD"
        { item_id: item["id"], status: item["status"], log_id: f["log_id"], bytes: f["bytes"], mime: f["content_type"] }
      end
      { launch_id: s["launch"]["id"], items: s["items"].length, logs: s["logs"].length, files: s["files"].length, after_owned: after }
    end
  end

  def self.run(write: false)
    @checks = []
    @proposal = Ledger202Host.read_command("git", "-C", ROOT, "show", "#{FINAL}:docs/design/presentation-ledger-proposal.md")
    global
    paired
    focused
    trials
    timing = json(File.join(DATA, "quiet-090b-window-1/matched-plain-comparison.json"))
    timing.each do |boundary|
      check("G11", "Same-corpus matched plain #{boundary['boundary']} p95 +10% gate", !boundary["stop_more_than_10_percent"],
        { path: "quiet-090b-window-1/matched-plain-comparison.json" }, boundary.merge("ratio" => boundary["new_p95_ms"] / boundary["old_p95_ms"]))
    end
    # These visual observations were made before the outage; no current health claim.
    check("P1.8", "Previously inspected S01/S03 title and meta visible above unexpanded RP fold", true,
      { screenshots: %w[S01-3883-plain-failure.jpg S03-3912-rich-error-no-html.jpg], launch_ids: [3883, 3912], log_ids: [21453, 21538] })
    check("P1.9", "Previously inspected Stack Trace begins with readable plain title, no generated HTML", true,
      { screenshots: ["S02-3883-plain-stack-trace.jpg"], launch_ids: [3883], log_ids: [21453] })
    dom = json(File.join(DATA, "screenshots/D-3918-http.json"))
    check("P10.8", "Saved live expanded HTTP headers have direct details > pre > code", dom["details"].length == 2 && dom["details"].all? { |d| d["direct"] && d["open"] && !d["code"].empty? }, { path: "screenshots/D-3918-http.json", launch_ids: [3918], log_ids: [21545] })
    criteria = TARGETS.map do |id|
      rows = @checks.select { |c| c[:criterion] == id }
      status = rows.any? { |r| r[:status] == "FAIL" } ? "FAIL" : GAPS.key?(id) || rows.empty? ? "PENDING" : "PASS"
      { id: id, status: status, checks: rows.length, gap: GAPS[id] }
    end
    files = Dir[File.join(DATA, "**", "*")].select { |p| File.file?(p) && !p.include?("/offline-review/") }.sort.map do |p|
      { path: p.delete_prefix(ROOT + "/"), bytes: File.size(p), sha256: Digest::SHA256.file(p).hexdigest }
    end
    result = { schema: "independent-ledger-offline-review/1", final_sha: FINAL, actual_execution_sha: Ledger202Host::FINAL,
      scope: "139 completed independent captures, six final trial readbacks; no new service requests or timings",
      overall: "HOLD_NOT_CERTIFIED", snapshots: @snapshots.length, candidate_snapshots: @snapshots.count { |s| s["_directory"].include?("/candidate") },
      paired_logs: @pair_count, whole_error_fatal_pairs: @severe_count, maximum_rich_delta_bytes: @max_delta,
      criteria: criteria, checks: @checks, final_trials: @trial_rows, inventory: files,
      reviewer_independence: "Only normative owner/product documents, historical own QA evidence, own new captures and user-authorized Master item inventory read. No fresh reviewer reports.",
      normalizer_provenance: { file: "spec/acceptance/ledger_qa/p106_clarified.rb", sha256: Digest::SHA256.file(File.join(ROOT, "spec/acceptance/ledger_qa/p106_clarified.rb")).hexdigest,
        overlay: "Decision27 exact WARN pill moves with response-first URL; ERROR/FATAL use raw-byte comparison" } }
    Ledger202Host.write_new(File.join(DATA, "offline-review", "checks.json"), result) if write
    puts JSON.pretty_generate(result.slice(:overall, :snapshots, :candidate_snapshots, :paired_logs, :whole_error_fatal_pairs, :maximum_rich_delta_bytes).merge(
      criteria: criteria, failures: @checks.select { |r| r[:status] == "FAIL" }))
  end
end

Ledger202Assessment.run(write: ARGV == ["--write"]) if $PROGRAM_NAME == __FILE__
