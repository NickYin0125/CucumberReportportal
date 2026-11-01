# frozen_string_literal: true

require_relative "analyze"
require "cgi"
require "time"

module LedgerQALegibility
  PILL = "display:inline-block;padding:0 7px;border-radius:9px;font:600 10.5px/1.7 system-ui,-apple-system,Segoe UI,sans-serif;letter-spacing:.04em"
  TITLE = "font:600 13.5px/1.5 system-ui,-apple-system,Segoe UI,sans-serif;color:#2B2B2D"
  TH = "font:600 10.5px system-ui,-apple-system,Segoe UI,sans-serif;letter-spacing:.06em;text-transform:uppercase;color:#6B6B6D"
  STYLES = [TITLE, TH] + %w[color:#276E50;background:#E6F5EE color:#B23B3B;background:#FBEAEA color:#8A5A00;background:#FFF3D6 color:#0F6C7A;background:#E3F4F7].map { |tone| "#{PILL};#{tone}" }
  FENCE = /^(`{3,}|~{3,})[^\n]*\n.*?^\1(?=\r?$)/m
  INLINE = /(?<!`)(`+)(?!`)(.*?)(?<!`)\1(?!`)/m

  def self.protect_code(text)
    saved = []
    prefix = "\u0000QA_PROTECTED_"
    prefix += "_" while text.include?(prefix)
    protect = ->(value) { saved << value; "#{prefix}#{saved.length - 1}\u0000" }
    output = text.gsub(FENCE) { |value| protect.call(value) }
    output = output.gsub(INLINE) { |value| protect.call(value) }
    [output, saved, protect, /#{Regexp.escape(prefix)}(\d+)\u0000/]
  end

  def self.strip_generated(plain, rich, family: nil)
    output, saved, protect, marker = protect_code(rich)
    plain_outside = protect_code(plain).first
    # Whole original angle-bearing lines are caller data, even when they use
    # exactly the same tag/style vocabulary as the presentation renderer.
    originals = plain_outside.lines.map(&:chomp).select do |line|
      line.gsub(/<br>/, "").match?(/<[^>\n]+>/)
    end.uniq
    missing = []
    originals.each do |literal|
      if output.include?(literal)
        output = output.gsub(literal) { protect.call(literal) }
      else
        missing << literal
      end
    end
    annotations = []
    comparison = output.dup
    first = plain.lines.first.to_s.chomp
    status = if first.start_with?("## \u2717 Assertion failed") || (family == :evidence && first.start_with?("## \u2717 "))
               "FAIL"
             elsif (match = first.match(/\A## [\u26a0\u2717] [A-Z]+ .* \u2192 (\d{3}|unknown)(?: \u00b7.*)?\z/))
               match[1]
             end
    if status
      tone = if status == "FAIL" || status.to_i >= 500 then "color:#B23B3B;background:#FBEAEA"
             elsif status.to_i >= 400 then "color:#8A5A00;background:#FFF3D6"
             elsif status.to_i >= 200 && status.to_i < 300 then "color:#276E50;background:#E6F5EE"
             else "color:#0F6C7A;background:#E3F4F7" end
      pill = "<span style=\"#{PILL};#{tone}\">#{status}</span>"
      lines = comparison.lines
      metadata = lines.each_index.find { |index| index.positive? && !lines[index].strip.empty? }
      if metadata && lines.first.to_s.chomp == first && lines[metadata].start_with?(pill)
        lines[metadata] = lines[metadata].delete_prefix(pill)
        comparison = lines.join
        annotations << { rule: "P10 WARN/ERROR/failed-assertion/evidence optional leading meta status pill", text: status, physical_line: metadata + 1, exact_generated_markup: pill }
      end
    end
    fold = Regexp.new("<details><summary>([^<\\n]+)</summary>\\n\\n(" + marker.source + ")")
    comparison = comparison.gsub(fold) do |whole|
      match = Regexp.last_match
      summary, token = match[1], match[2]
      block = saved.fetch(token.match(marker)[1].to_i)
      count = block.lines[1...-1].length
      replacement = nil
      if block.match?(/\A(?:`{3,}|~{3,})/) && plain.include?(block)
        if summary == "Preview \u00b7 #{count} lines" && count > 20 && first.match?(/\A`+.*`+ \u00b7 (?:Text|JSON) \u00b7 /)
          replacement = ""
        elsif (body = summary.match(/\A(Request|Response) body \u00b7 (\d+) lines\z/)) && body[2].to_i == count && count > 12 && first.match?(/\A(?:\u2713|## [\u26a0\u2717]) [A-Z]+ .* \u2192 /) && plain.include?("_#{body[1]}_")
          replacement = ""
        elsif (doc = summary.match(/\A(Doc string \u00b7 [^\n]+?) \u00b7 (\d+) lines\z/)) && doc[2].to_i == count && count > 20 && first == "_#{doc[1]}_"
          replacement = doc[1]
        end
      end
      if replacement
        annotations << { rule: "P10 exact long-preview/body/DocString fold caption", text: summary, canonical_replacement: replacement,
          body_lines: count, unchanged_plain_fence_sha256: Digest::SHA256.hexdigest(block) }
        "<details><summary>#{replacement}</summary>\n\n#{token}"
      else
        whole
      end
    end
    strip_tags = lambda do |value|
      removed = []
      result = value.gsub(/<[^>\n]+>/) do |tag|
        allowed = %w[<details> </details> <summary> </summary> </span>].include?(tag) ||
          (tag.start_with?("<span style=\"") && STYLES.any? { |style| tag == "<span style=\"#{style}\">" })
        removed << tag if allowed
        allowed ? "" : tag
      end
      [result, removed, result.scan(/<[^>\n]+>/).reject { |tag| tag == "<br>" }]
    end
    literal, removed, fragments = strip_tags.call(output)
    normalized = strip_tags.call(comparison).first
    restore = ->(value) { value.gsub(marker) { saved.fetch(Regexp.last_match(1).to_i) } }
    { text: restore.call(literal), comparison_text: restore.call(normalized), approved_generated_annotations: annotations,
      removed_generated_tags: removed, missing_original_lines: missing, unexpected_unprotected_fragments: fragments }
  end

  def self.canonical(text, rich: false, raw: false)
    value = text.dup
    unless raw
      if rich
        value = value.gsub(/^(PNG|JPEG|Text|JSON) (`[^\n]+?`)(.*)$/) { "#{Regexp.last_match(2)} \u00b7 #{Regexp.last_match(1)}#{Regexp.last_match(3)}" }
        first, rest = value.split("\n", 2)
        if (match = first.to_s.match(/\A(\d{3}) ([A-Z]+) (.*?)(?: \u00b7 (.*))?\z/))
          first = "\u2713 #{match[2]} #{match[3]} \u2192 #{match[1]}" + (match[4] ? " \u00b7 #{match[4]}" : "")
          value = [first, rest].compact.join("\n")
        end
      else
        value = value.sub(/\A\u2713 Assertion passed \u00b7 /, "PASS ")
      end
    end
    CGI.unescapeHTML(value).scan(/[[:alnum:]]+/)
  end

  def self.code_records(text)
    fenced = text.scan(FENCE).length
    outside, saved = protect_code(text)
    { count: saved.length, fences: fenced, sha256_in_order: saved.map { |value| Digest::SHA256.hexdigest(value) } }
  end

  def self.compare(plain, rich, channel: :client, family: nil)
    raw = channel == :raw
    stripped = raw ? { text: rich, removed_generated_tags: [], missing_original_lines: [], unexpected_unprotected_fragments: [] } : strip_generated(plain, rich, family: family)
    expected = canonical(plain, raw: raw)
    actual = canonical(stripped[:comparison_text] || stripped[:text], rich: !raw, raw: raw)
    index = 0
    actual.each { |word| index += 1 if index < expected.length && word == expected[index] }
    code_equal = code_records(plain) == code_records(rich)
    passed = expected == actual && code_equal && stripped[:missing_original_lines].empty? &&
      stripped[:unexpected_unprotected_fragments].empty? && (!raw || plain == rich)
    { verdict: passed ? "PASS" : "FAIL", plain_words: expected, stripped_rich_words: actual,
      plain_words_matched_in_order: index, expected_word_count: expected.length, code_bytes_identical: code_equal,
      plain_code: code_records(plain), rich_code: code_records(rich), raw_bytes_identical: plain == rich,
      stripped_rich: stripped[:text], removed_generated_tags: stripped[:removed_generated_tags],
      exact_canonical_word_equality: expected == actual, approved_generated_annotations: stripped[:approved_generated_annotations] || [],
      missing_original_lines: stripped[:missing_original_lines], unexpected_unprotected_fragments: stripped[:unexpected_unprotected_fragments] }
  end

  def self.regressions
    span = ->(text) { "<span style=\"#{TITLE}\">#{text}</span>" }
    tail = "```text\nalpha:1:in `<top (required)>'\nbeta:2:in `<main>'\n```"
    pairs = [
      ["fenced Ruby labels", "_Trace_\n\n#{tail}", "<details><summary>Trace</summary>\n\n#{tail}\n\n</details>", :client, "PASS"],
      ["four-backtick fence with embedded triple fence and style token", "_Trace_\n\n````text\n```\n#{span.call('original')}\n````", "<details><summary>Trace</summary>\n\n````text\n```\n#{span.call('original')}\n````\n\n</details>", :client, "PASS"],
      ["tilde fence raw details", "_Trace_\n\n~~~text\n<details><summary>original</summary></details>\n~~~", "<details><summary>Trace</summary>\n\n~~~text\n<details><summary>original</summary></details>\n~~~\n\n</details>", :client, "PASS"],
      ["inline angle labels", "alpha `<top (required)>` beta `<main>`", span.call("alpha `<top (required)>` beta `<main>`"), :client, "PASS"],
      ["double-backtick inline with literal backtick and HTML", "alpha ``a` <details>literal</details>`` omega", span.call("alpha ``a` <details>literal</details>`` omega"), :client, "PASS"],
      ["raw caller details and summary", "<details><summary>USER alpha</summary>bravo</details>", "<details><summary>USER alpha</summary>bravo</details>", :raw, "PASS"],
      ["raw caller exact client style", span.call("USER alpha bravo"), span.call("USER alpha bravo"), :raw, "PASS"],
      ["raw caller arbitrary angles", "USER <other> <b>alpha</b> <script>bravo</script>", "USER <other> <b>alpha</b> <script>bravo</script>", :raw, "PASS"],
      ["original caller markup within client card", "Header\n<details><summary>USER alpha</summary>bravo</details>", "#{span.call('Header')}\n<details><summary>USER alpha</summary>bravo</details>", :client, "PASS"],
      ["original caller client-style span within card", "Header\n#{span.call('USER alpha bravo')}", "#{span.call('Header')}\n#{span.call('USER alpha bravo')}", :client, "PASS"],
      ["only generated title removed", "alpha bravo charlie", span.call("alpha bravo charlie"), :client, "PASS"],
      ["approved HTTP status position", "\u2713 POST /api/orders \u2192 201 \u00b7 84 ms", "201 #{span.call('POST /api/orders')} \u00b7 84 ms", :client, "PASS"],
      ["approved assertion PASS label", "\u2713 Assertion passed \u00b7 Order is accepted", "PASS #{span.call('Order is accepted')}", :client, "PASS"],
      ["raw caller assertion-looking text not canonicalized", "\u2713 Assertion passed \u00b7 USER alpha", "\u2713 Assertion passed \u00b7 USER alpha", :raw, "PASS"],
      ["negative fenced label removed", tail, tail.sub("<top (required)>", ""), :client, "FAIL"],
      ["negative fenced word reorder", tail, tail.sub("top (required)", "required (top)"), :client, "FAIL"],
      ["negative inline angle loss", "alpha `<top (required)>`", span.call("alpha `top (required)`"), :client, "FAIL"],
      ["negative raw caller tags removed", "<details><summary>USER alpha</summary>bravo</details>", "USER alpha bravo", :raw, "FAIL"],
      ["negative raw caller style tag removed", span.call("USER alpha bravo"), "USER alpha bravo", :raw, "FAIL"],
      ["negative raw caller word reorder", "USER alpha bravo charlie", "USER alpha charlie bravo", :raw, "FAIL"],
      ["negative raw caller angle loss", "USER <other> alpha", "USER other alpha", :raw, "FAIL"],
      ["negative raw caller added generated-looking wrapper", "USER alpha", span.call("USER alpha"), :raw, "FAIL"],
      ["negative unauthorized word removal", "alpha bravo charlie", span.call("alpha charlie"), :client, "FAIL"],
      ["negative unauthorized word reorder", "alpha bravo charlie", span.call("alpha charlie bravo"), :client, "FAIL"],
      ["negative arbitrary inserted word", "alpha bravo charlie", span.call("alpha UNAUTHORIZED bravo charlie"), :client, "FAIL"],
      ["negative HTTP method change", "\u2713 POST /api/orders \u2192 201 \u00b7 84 ms", "201 #{span.call('GET /api/orders')} \u00b7 84 ms", :client, "FAIL"],
      ["negative unsupported style is not stripped", "alpha bravo", '<span style="color:red">alpha bravo</span>', :client, "FAIL"],
      ["negative arbitrary client tag is not stripped", "alpha bravo", '<script>alpha bravo</script>', :client, "FAIL"],
      ["negative caller markup loss within card", "Header\n<details>USER alpha</details>", "#{span.call('Header')}\nUSER alpha", :client, "FAIL"]
    ]
    %w[PNG JPEG Text JSON].each do |kind|
      pairs << ["approved #{kind} caption position", "`fixture.dat` \u00b7 #{kind} \u00b7 12 B", "#{kind} `fixture.dat` \u00b7 12 B", :client, "PASS"]
    end
    preview = "```text\n" + (1..25).map { |i| "line #{i}" }.join("\n") + "\n```"
    preview_plain = "`fixture.txt` \u00b7 Text \u00b7 100 B\n\n#{preview}"
    preview_rich = "Text `fixture.txt` \u00b7 100 B\n\n<details><summary>Preview \u00b7 25 lines</summary>\n\n#{preview}\n\n</details>"
    pairs << ["documented preview annotation exactly validated", preview_plain, preview_rich, :client, "PASS"]
    pairs << ["negative wrong preview line count", preview_plain, preview_rich.sub("25 lines", "24 lines"), :client, "FAIL"]
    pairs << ["negative inserted summary word", preview_plain, preview_rich.sub("Preview \u00b7", "Preview UNAUTHORIZED \u00b7"), :client, "FAIL"]
    failed = "## \u2717 Assertion failed \u00b7 alpha bravo\n\n#{preview}"
    fail_pill = "<span style=\"#{PILL};color:#B23B3B;background:#FBEAEA\">FAIL</span>"
    pairs << ["documented failed assertion meta pill", failed, failed.sub("\n\n", "\n\n#{fail_pill}\n\n"), :client, "PASS"]
    pairs << ["negative extra word beside allowed status pill", failed, failed.sub("\n\n", "\n\n#{fail_pill} UNAUTHORIZED\n\n"), :client, "FAIL"]
    evidence = "## \u2717 Arbitrary authored failure title\n\n`RuntimeError`\n\n#{preview}"
    pairs << ["documented typed evidence meta pill", evidence, evidence.sub("`RuntimeError`", "#{fail_pill} `RuntimeError`"), :client, "PASS", :evidence]
    pairs << ["negative typed evidence inserted word", evidence, evidence.sub("`RuntimeError`", "#{fail_pill} UNAUTHORIZED `RuntimeError`"), :client, "FAIL", :evidence]
    pairs << ["negative caller evidence-looking wrapper remains raw", evidence, evidence.sub("`RuntimeError`", "#{fail_pill} `RuntimeError`"), :raw, "FAIL", :evidence]
    pairs.map do |name, plain, rich, channel, expected, family|
      result = compare(plain, rich, channel: channel, family: family)
      { criterion: "P10.6", check: name, method: "U", inputs: { plain: plain, rich: rich, channel: channel, typed_client_family: family },
        expected: expected, actual: result[:verdict], verdict: result[:verdict] == expected ? "PASS" : "FAIL", diagnostics: result }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  %w[2.0.1 1.3.2].each do |version|
    root = "/Users/nick/Documents/crr-qa-#{version}"
    assets = File.join(root, "docs/reviews/assets")
    study = LedgerQAAnalysis::Study.new(root, "20261031T072147Z")
    checks = LedgerQALegibility.regressions
    fixtures = []
    stamps = %w[20261031T072147Z 20261031T173014Z 20261031T174824Z 20261031T180948Z]
    paths = stamps.flat_map { |stamp| Dir[File.join(assets, "ledger-qa-live/#{stamp}-*/**/snapshot.json")] }.select { |path| path.match?(/-plain-[12]\//) }.sort
    paths.each do |plain_path|
      rich_path = plain_path.sub("-plain-", "-rich-")
      raise "Missing paired rich capture" unless File.file?(rich_path)
      read = lambda do |path|
        value = JSON.parse(File.read(path)).merge("_directory" => File.dirname(path))
        launch = value.fetch("launches", []).first&.fetch("id")
        retry_path = File.join(assets, "ledger-qa-retry-read-20261031T180948Z/launch-#{launch}.json")
        if path.include?("20261031T180948Z") && File.file?(retry_path)
          proof = JSON.parse(File.read(retry_path))
          raise "Retry proof changed" unless proof["verdict"] == "PASS" && proof["source_snapshot_sha256"] == Digest::SHA256.file(path).hexdigest
          items = proof["validations"].to_h { |row| [row["direct_item"]["id"], row["direct_item"]] }
          value["items"] = value.fetch("items").map { |item| items.fetch(item["id"], item) }
        end
        value
      end
      plain, rich = read.call(plain_path), read.call(rich_path)
      grouping = lambda do |snapshot|
        owners = study.paths(snapshot)
        snapshot.fetch("logs", []).group_by { |log| [owners.fetch(log["itemId"], "Launch"), log["level"]] }.transform_values do |rows|
          rows.sort_by do |log|
            text = log["message"]
            stripped = LedgerQALegibility.strip_generated("", text)[:text]
            LedgerQALegibility.canonical(stripped, rich: snapshot.equal?(rich)).join(" ")
          end
        end
      end
      left, right = grouping.call(plain), grouping.call(rich)
      raise "Owner/count mismatch before pairing" unless left.transform_values(&:length) == right.transform_values(&:length)
      fixtures << { plain: plain_path.delete_prefix(root + "/"), rich: rich_path.delete_prefix(root + "/"), log_count: plain.fetch("logs", []).length }
      left.each do |owner, rows|
        rows.zip(right.fetch(owner)).each do |a, b|
          channel = a["message"] == b["message"] ? :raw : :client
          family = File.basename(File.dirname(plain_path)) == "F12" ? :evidence : nil
          result = LedgerQALegibility.compare(a["message"], b["message"], channel: channel, family: family)
          checks << { criterion: "P10.6", check: "Decision 9 complete paired log #{a['id']} / #{b['id']}", method: "L",
            inputs: { plain_source: plain_path.delete_prefix(root + "/"), rich_source: rich_path.delete_prefix(root + "/"),
              plain_source_sha256: Digest::SHA256.file(plain_path).hexdigest, rich_source_sha256: Digest::SHA256.file(rich_path).hexdigest,
              normalized_owner_and_level: owner, channel: channel, typed_client_family: family, classification: channel == :raw ? "Exact unchanged bytes; do not strip or canonicalize caller markup" : "Changed presentation; preserve all original angle-bearing lines/code before exact client-tag stripping" },
            expected: result[:plain_words], actual: result[:stripped_rich_words], verdict: result[:verdict],
            evidence: { source: rich_path.delete_prefix(root + "/"), launch_ids: rich["launches"].map { |item| item["id"] }, item_ids: [b["itemId"]].compact, log_ids: [a["id"], b["id"]] },
            code_bytes_identical: result[:code_bytes_identical], plain_code: result[:plain_code], rich_code: result[:rich_code],
            exact_canonical_word_equality: result[:exact_canonical_word_equality], approved_generated_annotations: result[:approved_generated_annotations],
            removed_generated_tags: result[:removed_generated_tags], missing_original_lines: result[:missing_original_lines], unexpected_fragments: result[:unexpected_unprotected_fragments] }
        end
      end
    end
    frozen = JSON.parse(File.read(File.join(assets, "ledger-qa-frozen-input/launch-76-f04.json")))
    tail = frozen.fetch("backtrace")
    tail = tail.join("\n") if tail.is_a?(Array)
    raise "Frozen frame/hash guard failed" unless tail.lines.length == 62 && Digest::SHA256.hexdigest(tail) == "3fd9692c6e95a2e7e1868111ad41fd5f2584f95098c67d18ccc9756d66eca75d" && Digest::SHA256.hexdigest(frozen.fetch("raw_message")) == "331098890b9e0de4fba85f173d62a129bdceb139538a9da5e8f929f8f32ea610"
    %w[plain rich].each do |mode|
      [1, 2].each do |repeat|
        path = File.join(assets, "ledger-qa-live/20261031T072147Z-supplement-#{mode}-#{repeat}/F04-frozen/snapshot.json")
        snapshot = JSON.parse(File.read(path))
        log = snapshot.fetch("logs").find { |row| row["level"] == "error" }
        found = log.fetch("message").include?("\n#{tail}\n")
        checks << { criterion: "P10.6", check: "Separate byte-level frozen F04 62-frame guard #{mode}/#{repeat}", method: "L",
          inputs: { source: "docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json", expected_tail_sha256: frozen["backtrace_sha256"], raw_source_sha256: frozen["raw_sha256"] },
          expected: { all_62_frame_bytes_unchanged: true }, actual: { all_62_frame_bytes_unchanged: found }, verdict: found ? "PASS" : "FAIL",
          evidence: { source: path.delete_prefix(root + "/"), launch_ids: snapshot["launches"].map { |row| row["id"] }, item_ids: [log["itemId"]], log_ids: [log["id"]] } }
      end
    end
    output = { schema: "decision9-client-generated-only-legibility/1", version: version, checked_at_utc: Time.now.utc.iso8601,
      method: "Independent QA parser, no SDK formatter calls. Fenced/inline bytes and original angle-bearing lines protected; exact normative Tier2 vocabulary only. Unchanged/raw caller bytes are never stripped. EXACT canonical word equality after Decision2 kind/PASS/HTTP positions and separately recorded P10 meta-status/fold-caption annotations derived from card context and unchanged body line counts. No arbitrary inserted words. All complete plain/rich capture pairs and repeats are checked.",
      regression_count: LedgerQALegibility.regressions.length, paired_fixture_count: fixtures.length, fixtures: fixtures, checks: checks,
      checker_source_sha256: Digest::SHA256.file(__FILE__).hexdigest,
      verdict: checks.all? { |row| row[:verdict] == "PASS" } ? "PASS" : "FAIL" }
    path = File.join(assets, "ledger-qa-p106-decision9-#{version}.json")
    File.write(path, JSON.pretty_generate(output) + "\n")
    puts JSON.generate(version: version, verdict: output[:verdict], checks: checks.length, regressions: output[:regression_count], paired_fixtures: fixtures.length,
      failures: checks.reject { |row| row[:verdict] == "PASS" }.map { |row| row[:check] })
  end
end
