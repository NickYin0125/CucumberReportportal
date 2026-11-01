# frozen_string_literal: true

require_relative "adjudicate"
require_relative "p106_clarified"

module LedgerQAAnalysis
  class WP5Study < FinalStudy
    FINAL_HEADS = { "2.0.1" => "06f498cf9fb05352a831fdafc9583b40dced9899", "1.3.2" => "1e136e89eb21276330e5fc9f1769fe9521a83cb9" }.freeze
    TARGETS = ((1..12).map { |n| "G#{n}" } + (1..10).map { |n| "P1.#{n}" } +
      (1..8).map { |n| "P5.#{n}" } + (1..9).map { |n| "P8.#{n}" } +
      (1..11).map { |n| "P10.#{n}" } + (1..8).map { |n| "V#{n}" }).freeze

    attr_reader :cucumber

    def initialize(root, stamp, cucumber)
      super(root, "#{stamp}-c#{cucumber}")
      @wp5_stamp, @cucumber = stamp, cucumber
    end

    def file(path)
      return File.join("/Users/nick/Documents/crr-#{version}", path) if path.start_with?("docs/design/")
      super
    end

    def run(mode, repeat = 1)
      result = Study.instance_method(:run).bind_call(self, mode, repeat)
      suffix = mode == "baseline" ? "baseline" : "#{mode}-#{repeat}"
      return result if mode == "default-batch1"
      %w[supplement framework authored].each { |kind| result.merge!(load_set("#{@stamp}-#{kind}-#{suffix}")) }
      result
    end

    def all_candidates
      Dir[File.join(root, "docs/reviews/assets/ledger-qa-live/#{@stamp}-*/**/snapshot.json")].reject { |p| p.match?(/-baseline\//) }.sort.map do |path|
        JSON.parse(File.read(path)).merge("_directory" => File.dirname(path))
      end
    end

    def check(id, label, expected, actual, snapshot: nil, passed: expected == actual, method: "L", inputs: nil, note: nil)
      return unless TARGETS.include?(id)
      super
      entry = checks.last
      entry[:runtime_sha] = FINAL_HEADS.fetch(version)
      entry[:cucumber] = cucumber
      entry[:inputs] ||= { fixture_capture: entry.dig(:evidence, :source), comparison: label }
      selected = snapshot && logs(snapshot)
      if selected
        if id == "G1"
          entry[:evidence][:log_ids] = []
          return
        end
        explicit = inputs.is_a?(Hash) && (inputs[:rich_log_id] || inputs[:log_id])
        selected = selected.select { |log| log["id"] == explicit } if explicit
        if id.start_with?("P1.")
          selected = selected.select { |log| log["level"] == "error" }
        elsif %w[G3 P5.1 P5.2 P5.3 P5.4 P5.5 P5.6 P5.7].include?(id)
          selected = selected.select { |log| log["binaryContent"] } unless label.include?("prefix")
        elsif id == "P8.6"
          selected = selected.select { |log| log["level"] == "info" }
        end
        if label =~ /log (\d+)/
          selected = selected.select { |log| log["id"] == Regexp.last_match(1).to_i } if logs(snapshot).any? { |log| log["id"] == Regexp.last_match(1).to_i }
        end
        entry[:evidence][:log_ids] = selected.map { |log| log["id"] }
        entry[:evidence][:item_ids] = selected.map { |log| log["itemId"] }.compact.uniq unless selected.empty?
      end
    end

    def blocked(id, reason, inputs: nil)
      return unless TARGETS.include?(id)
      super
      checks.last[:runtime_sha] = FINAL_HEADS.fetch(version)
      checks.last[:cucumber] = cucumber
    end

    def proposal_golden(section, index = 0)
      super
    end

    def coverage
      suffixes = %w[plain-1 plain-2 rich-1 rich-2 baseline default-batch1] +
        %w[supplement framework authored].flat_map { |kind| %w[plain-1 plain-2 rich-1 rich-2 baseline].map { |s| "#{kind}-#{s}" } }
      suffixes.concat(%w[parallel-plain-1 parallel-plain-2 parallel-rich-1 parallel-rich-2 parallel-baseline]) if version == "2.0.1"
      missing = suffixes.reject do |suffix|
        dir = File.join(root, "docs/reviews/assets/ledger-qa-live/#{@stamp}-#{suffix}")
        File.file?(File.join(dir, suffix.start_with?("parallel") ? "result.json" : "summary.json"))
      end
      missing
    end

    def bind_runtime_captures
      expected = {}
      proofs = Dir[File.join(root, "docs/reviews/assets/ledger-qa-live/#{@stamp}-*/**/runtime.json")].sort.map do |path|
        runtime = JSON.parse(File.read(path))
        sdk = File.dirname(runtime.dig("activation", "sdk_gemspec").to_s)
        baseline = sdk.include?("qa-baseline-")
        sha = baseline ? BASES.fetch(version) : FINAL_HEADS.fetch(version)
        hashes = runtime.fetch("loaded_sdk_sha256_at_start")
        mismatches = hashes.filter_map do |absolute, actual|
          relative = absolute.delete_prefix(sdk + "/")
          wanted = expected[[sha, relative]] ||= begin
            bytes, status = Open3.capture2("git", "-C", root, "show", "#{sha}:#{relative}")
            raise "Runtime revision member missing" unless status.success?
            Digest::SHA256.hexdigest(bytes)
          end
          { path: relative, expected: wanted, actual: actual } unless wanted == actual
        end
        { source: path.delete_prefix(root + "/"), sha: sha, source_root: sdk, loaded_file_count: hashes.length,
          source_unchanged_during_fixture: !runtime["sdk_source_changed_during_fixture"], mismatches: mismatches }
      end
      valid = !proofs.empty? && proofs.all? { |proof| proof[:loaded_file_count].positive? && proof[:mismatches].empty? && proof[:source_unchanged_during_fixture] }
      check("V1", "Every actual loaded SDK byte hash matches the exact final/baseline Git revision, not the QA branch", true, valid,
        method: "U", inputs: proofs)
      valid
    end

    def frame_checks(plain)
      plain.each do |fixture, snapshot|
        runtime_path = File.join(snapshot["_directory"], "runtime.json")
        runtime = File.file?(runtime_path) ? JSON.parse(File.read(runtime_path)) : {}
        ruby = runtime.fetch("ruby", "3.4")
        ruby = ruby[/\d+\.\d+/] || "3.4"
        stdlib = "/usr/local/lib/ruby/#{ruby}.0/"
        logs(snapshot).select { |log| log["level"] == "error" && log["message"].include?("_Full backtrace") }.each do |log|
          text = log.fetch("message")
          tail = text.split("```text\n").last.sub(/\n```\z/, "")
          frames = tail.lines.map(&:chomp)
          framework = frames.select { |line| line.include?("/gems/") || line.start_with?(stdlib) }
          runner = frames.select { |line| line.start_with?("-e:", "<internal:") }
          projects = frames - framework - runner
          feature = projects.find { |line| line.match?(/\.feature:\d+/) }
          shown_count = projects.empty? ? [framework.length, 3].min : [(projects - [feature]).length, 8].min + (feature ? 1 : 0)
          shown = text.include?("_Project frames_") ? text[/_Project frames_\n\n```text\n(.*?)\n```/m, 1] : text[/```text\n(.*?)\n```/m, 1]
          hidden = { framework: framework.length - (projects.empty? ? shown_count : 0), runner: runner.length,
            project: projects.length - (projects.empty? ? 0 : shown_count) }.filter_map { |kind, count| "#{count} #{kind}" if count.positive? }
          caption = "#{frames.length} #{frames.length == 1 ? 'frame' : 'frames'}"
          unless hidden.empty?
            kinds = hidden.length == 3 ? "#{hidden[0]}, #{hidden[1]} and #{hidden[2]}" : hidden.join(" and ")
            hidden_count = frames.length - shown_count
            caption += " \u00b7 #{kinds} #{hidden_count == 1 ? 'frame' : 'frames'} not shown above"
          end
          check("P1.3", "#{fixture}: count every raw-tail frame and hidden kind (Decision 11 conjunction)", caption,
            text[/_Full backtrace \u00b7 ([^\n]+)_/, 1], snapshot: snapshot, inputs: { log_id: log["id"], frames: frames, stdlib_prefix: stdlib })
          check("P1.4", "#{fixture}: displayed project/framework count and feature-last rule", shown_count, shown.to_s.lines.length,
            snapshot: snapshot, inputs: { log_id: log["id"], project_frames: projects, framework_frames: framework, feature: feature })
          locations = shown.to_s.lines.map { |line| line.split(/\s{2,}/).first.to_s.strip }
          check("P1.4", "#{fixture}: each displayed location satisfies owner-approved 40-character cap", [],
            locations.select { |location| location.length > 40 }, snapshot: snapshot, inputs: { log_id: log["id"], locations: locations })
        end
      end
    end

    def supplemental_current(plain, rich, baseline)
      frozen = read("docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json")
      tail = frozen.fetch("backtrace")
      tail = tail.join("\n") if tail.is_a?(Array)
      golden = proposal_golden("P1")
      golden = golden[0...golden.rindex("```text\n")] + "```text\n#{tail}\n```"
      check("P1.1", "Recovered original F04 input retains its verified 62-frame SHA256", [62, "3fd9692c6e95a2e7e1868111ad41fd5f2584f95098c67d18ccc9756d66eca75d"],
        [tail.lines.length, Digest::SHA256.hexdigest(tail)], method: "U", inputs: frozen.slice("source_launch_id", "source_item_id", "source_log_id", "raw_sha256"))
      %w[plain rich].each do |mode|
        [1, 2].each do |repeat|
          set = run(mode, repeat)
          snapshot = set.fetch("F04-frozen")
          log = logs(snapshot).find { |l| l["level"] == "error" }
          check("P1.1", "F04 frozen plain/#{repeat}: exact corrected proposal golden", golden, log["message"], snapshot: snapshot) if mode == "plain"
          old = logs(baseline.fetch("F04-frozen")).find { |l| l["level"] == "error" }
          check("P1.1", "F04 frozen #{mode}/#{repeat}: all baseline lines 2-63 remain byte-identical", old["message"].split("\n", 2).last,
            log["message"].split("```text\n").last.sub(/\n```\z/, "").sub(/\n\n<\/details>\z/, "").sub(/\n```\z/, ""),
            snapshot: snapshot, inputs: refs(baseline.fetch("F04-frozen")))
          adapted = set.fetch("F16c-adapted")
          check("P1.2", "Explicit non-Exception event input: message-only title, not a natural Ruby raise", "## \u2717 Non-Exception failure",
            logs(adapted).find { |l| l["level"] == "error" }["message"].lines.first.chomp, snapshot: adapted)
          shape = set.fetch("F16b-framework-replay")
          check("P1.4", "Explicit framework-only input: first three framework frames, in input order",
            "first.rb:11   Framework.one\nsecond.rb:22  Framework.two\nthird.rb:33   Framework.three",
            logs(shape).find { |l| l["level"] == "error" }["message"][/```text\n(.*?)\n```/m, 1], snapshot: shape)
        end
      end
      f17, batch = plain.fetch("F17"), run("default-batch1").fetch("F17")
      names = submitted_attachments(f17).map { |part| part["name"] }
      check("P5.6", "F17: batch size 1 and default emit identical owner-local filenames", names, submitted_attachments(batch).map { |part| part["name"] }, snapshot: f17, inputs: refs(batch))
      check("P5.6", "F17: first/second PNG and unnamed After JPEG use specified names", true,
        %w[then-the-order-is-confirmed.png then-the-order-is-confirmed-1.png after-hook.jpg].all? { |name| names.include?(name) }, snapshot: f17)
      progressive = logs(f17).find { |l| l["message"].include?("confirmed-2.jpg") }
      check("P5.2", "F17: SOF2 JPEG caption dimensions match 2 x 2 input", true,
        progressive && progressive["message"].include?("JPEG \u00b7 2 \u00d7 2 \u00b7 586 B"), snapshot: f17)
      negative = plain.fetch("F08-negative")
      message = logs(negative).find { |l| l["message"].include?("png-plain_base64.png") }&.fetch("message")
      check("P5.2", "F08 plain_base64 negative: PNG kind, no decoded dimensions", true,
        message && message.start_with?("`png-plain_base64.png` \u00b7 PNG \u00b7 ") && !message.include?("\u00d7"), snapshot: negative)
      oversized = logs(plain.fetch("F18")).find { |l| l["message"].start_with?("`oversized.json`") }
      preview = oversized && oversized["message"][/```json\n(.*?)\n```/m, 1]
      check("P5.5", "F18 oversized JSON: bounded original preview, not pretty-printed", true,
        preview && !preview.include?("\n  \"") && preview.bytesize <= 16_500, snapshot: plain.fetch("F18"))
      check("P8.4", "F11a: exact corrected INFO HTTP golden with ordered headers and 55/51 B", proposal_golden("P8", 2),
        logs(plain.fetch("F11a")).first["message"], snapshot: plain.fetch("F11a"))
      check("P8.5", "F12: exact full evidence-card golden", proposal_golden("P8", 1),
        logs(plain.fetch("F12")).find { |l| l["level"] == "error" }["message"], snapshot: plain.fetch("F12"))
      text = logs(plain.fetch("F10d")).first["message"]
      check("P8.2", "F10d: expected/actual scalar-object Ledger JSON strings", true,
        text.include?('expected  { "currency": "USD", "notional": 5000000 }') && text.include?('actual    { "currency": "USD", "notional": 4000000 }'), snapshot: plain.fetch("F10d"))
      derived_check("P5.7", "Owned API downloads match baseline count, MIME, filenames and SHA256", from: ["G3"], method: "C")
      defaults = run("default-batch1")
      defaults.each do |fixture, s|
        check("P10.1", "#{fixture}: unset presentation adds no Tier 2 tags", [], logs(s).flat_map { |l| l["message"].scan(/<details|<summary|<span style/) }, snapshot: s)
      end
      f20 = plain.fetch("F20")
      process = JSON.parse(File.read(File.join(f20["_directory"], "process.json")))
      check("P10.2", "F20 fancy: exactly one presentation warning", 1, process["stderr"].lines.grep(/presentation/i).length, snapshot: f20, method: "U")
      check("P10.2", "F20 fancy: resulting log uses plain mode", [], logs(f20).flat_map { |l| l["message"].scan(/<details|<summary|<span style/) }, snapshot: f20)
      all_candidates.each do |s|
        %w[Attachment: Failure\ evidence:].each do |prefix|
          id = prefix.start_with?("Attachment") ? "P5.3" : "P5.4"
          check(id, "#{File.basename(s['_directory'])}: no generated legacy #{prefix} prefix", [], logs(s).select { |l| l["message"].start_with?(prefix) }.map { |l| l["id"] }, snapshot: s)
        end
      end
    end

    def escaping_titles
      values = ["<other>", "<b>x</b>", "a | b", "back\\slash", "*star*", "_under_", "`tick`", "&amp;", "# heading", "1. item",
        "x<script>alert(1)</script>", "emoji \u{1F7E2}", "CJK \u4e2d\u6587", "first\nsecond"]
      [1, 2].each do |repeat|
        snapshot = run("plain", repeat)["F14-negative"]
        next unless snapshot
        errors = logs(snapshot).select { |log| log["level"] == "error" }
        check("P1.2", "F14 plain/#{repeat}: all fourteen literal exception inputs have error observations", values.length, errors.length, snapshot: snapshot)
        values.zip(errors).each_with_index do |(value, log), index|
          next unless log
          text = "RuntimeError: #{value.lines.first.to_s.chomp}"
          escaped = text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub(/[\\`*_\[\]|~]/) { |char| "\\#{char}" }
          check("P1.2", "F14 plain/#{repeat} input #{index}: independently escaped exception title", "## \u2717 #{escaped}", log["message"].lines.first.to_s.chomp,
            snapshot: snapshot, inputs: { log_id: log["id"], gherkin_value: value, source: "acceptance F14 literal matrix; support.rb raises indexed value unchanged" })
        end
      end
    end

    def paired_outputs
      pairs = all_candidates.select { |s| s["_directory"].match?(/-plain-[12]\//) }
      pairs.each do |plain|
        rich_path = plain["_directory"].sub("-plain-", "-rich-")
        next unless File.file?(File.join(rich_path, "snapshot.json"))
        rich = JSON.parse(File.read(File.join(rich_path, "snapshot.json"))).merge("_directory" => rich_path)
        group = lambda do |s|
          locations = paths(s)
          logs(s).group_by { |l| [locations.fetch(l["itemId"], "Launch"), l["level"]] }.transform_values do |rows|
            rows.sort_by { |l| LedgerQALegibility.canonical(LedgerQALegibility.strip_generated("", l["message"])[:text], rich: s.equal?(rich)).join(" ") }
          end
        end
        left, right = group.call(plain), group.call(rich)
        check("P10.6", "Paired log ownership and level counts", left.transform_values(&:length), right.transform_values(&:length), snapshot: rich, inputs: refs(plain))
        left.each do |owner, rows|
          rows.zip(right.fetch(owner, [])).each do |a, b|
            next unless b
            result = LedgerQALegibility.compare(a["message"], b["message"], channel: a["message"] == b["message"] ? :raw : :client,
              family: File.basename(plain["_directory"]) == "F12" ? :evidence : nil)
            check("P10.6", "Exact canonical words and code bytes for paired logs #{a['id']}/#{b['id']} (Decisions 2/9)", result[:plain_words], result[:stripped_rich_words],
              passed: result[:verdict] == "PASS", snapshot: rich, inputs: { plain_log_id: a["id"], rich_log_id: b["id"], result: result })
            checks.last[:evidence][:log_ids] = [a["id"], b["id"]]
          end
        end
        native_pairs = Dir[File.join(plain["_directory"], "**/native.ndjson")].sort
        native_pairs.each do |ndplain|
          ndrich = ndplain.sub("-plain-", "-rich-")
          next unless File.file?(ndrich)
          left_native, right_native = [ndplain, ndrich].map { |path| normalized_native(path) }
          check("G12", "Native NDJSON plain/rich equality after generated-ID/clock normalization", left_native, right_native, snapshot: rich, method: "U", inputs: [ndplain, ndrich])
          htmls = [ndplain, ndrich].map { |path| path.sub("native.ndjson", "native.html") }
          if htmls.all? { |path| File.file?(path) }
            models = htmls.map do |path|
              html = File.read(path)
              block = html[/window\.CUCUMBER_MESSAGES = (\[.*?\]);\s*<\/script>/m, 1]
              raise "Missing native HTML envelope block" unless block
              [html.sub(block, "<NATIVE_ENVELOPES>"), JSON.parse(block.gsub(/(?<!\\)((?:\\\\)*)\\x3C/) { "#{Regexp.last_match(1)}<" })]
            end
            html_models = models.map { |model| normalize_envelopes(model[1]) }
            check("G12", "Native HTML template bytes and embedded envelope models equal plain/rich and source NDJSON", true,
              models[0][0] == models[1][0] && html_models[0] == html_models[1] && html_models == [left_native, right_native],
              snapshot: rich, method: "U", inputs: htmls)
          else
            blocked("G12", "Native parallel HTML reports require official formatter postprocessing", inputs: htmls)
          end
          check("G12", "Native rich Cucumber envelopes contain no Tier 2 tokens", [], JSON.generate(right_native).scan(/<details|<summary|<span style/), snapshot: rich, method: "U")
        end
        stdout_paths = Dir[File.join(plain["_directory"], "**/process.json")].sort
        stdout_paths.each do |a|
          b = a.sub("-plain-", "-rich-")
          next unless File.file?(b)
          normalized = [a, b].map { |path| terminal_business(JSON.parse(File.read(path)).fetch("stdout")) }
          check("P10.7", "Plain/rich terminal business bytes unchanged (full traces retained)", normalized[0], normalized[1], snapshot: rich, method: "U", inputs: [a, b])
        end
      end
    end

    def terminal_business(text)
      text.gsub(/\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?/, "<timestamp>").sub(/\n\d+ scenarios? \([^\n]*\).*\z/m, "")
    end

    def normalize_envelopes(rows)
      ids = {}
      rewrite = lambda do |value|
        case value
        when Hash
          value.to_h { |key, child| [key, %w[timestamp duration start finish].include?(key) ? "<runtime-clock>" : rewrite.call(child)] }
        when Array then value.map { |child| rewrite.call(child) }
        when String
          value.gsub(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i) { |id| ids[id] ||= "<generated-id-#{ids.length}>" }
        else value
        end
      end
      rewrite.call(rows)
    end

    def terminal_baseline(plain, rich, baseline)
      %w[plain rich].each do |mode|
        [1, 2].each do |repeat|
          run(mode, repeat).each do |fixture, s|
            next unless fixture.match?(/\AF(?:10|11|12)/) && baseline[fixture]
            old_path = File.join(baseline[fixture]["_directory"], "process.json")
            new_path = File.join(s["_directory"], "process.json")
            old, current = [old_path, new_path].map { |path| JSON.parse(File.read(path)).fetch("stdout") }
            check("P8.8", "#{fixture} #{mode}/#{repeat}: baseline native/logger stdout bytes, excluding only Cucumber summary/stopwatch",
              terminal_business(old), terminal_business(current), snapshot: s, method: "U", inputs: { baseline: old_path, current: new_path,
                full_timestamp_only_equal: old.gsub(/\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?/, "<timestamp>") == current.gsub(/\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?/, "<timestamp>") })
          end
        end
      end
    end

    def execute_live
      escaping_titles
      missing = coverage
      unless missing.empty?
        (TARGETS - %w[G9 G10 G11 P8.9] - TARGETS.grep(/^V/)).each { |id| blocked(id, "Fresh required capture set incomplete: #{missing.join(', ')}") }
        return checks
      end
      unless bind_runtime_captures
        TARGETS.each { |id| blocked(id, "Loaded runtime bytes do not establish the required final-head execution; do not score candidate behaviour") }
        return checks
      end
      plain, rich, baseline = run("plain"), run("rich"), run("baseline")
      contract_checks(plain, rich, baseline)
      global_checks(plain, rich, baseline)
      Study.instance_method(:feature_checks).bind_call(self, plain, rich, baseline)
      supplemental_current(plain, rich, baseline)
      frame_checks(plain)
      closed_vocabulary(plain, rich)
      paired_outputs
      terminal_baseline(plain, rich, baseline)
      %w[P1.6 P1.8 P1.9 P5.8 P10.8 P10.10 P10.11].each do |id|
        blocked(id, "Fresh final-head visual/DOM protocol has not been captured and independently judged")
      end
      checks
    rescue KeyError => error
      TARGETS.each { |id| blocked(id, "Required fixture field is missing: #{error.key.inspect}; retained captures cannot establish this criterion") }
      checks
    end
  end
end

if $PROGRAM_NAME == __FILE__
  stamp = ENV.fetch("QA_WP5_STAMP", "wp5-final-20261101")
  { "2.0.1" => ["12.0.1"], "1.3.2" => ["9.2.1", "10.2.0"] }.each do |version, cucumbers|
    root = "/Users/nick/Documents/crr-qa-#{version}"
    checks = cucumbers.flat_map { |cucumber| LedgerQAAnalysis::WP5Study.new(root, stamp, cucumber).execute_live }
    output = File.join(root, "docs/reviews/assets", stamp, "live-checks.json")
    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(schema: "wp5-final-head-live-analysis/1", runtime_sha: LedgerQAAnalysis::WP5Study::FINAL_HEADS.fetch(version), checked_at_utc: Time.now.utc.iso8601, checks: checks) + "\n")
    puts JSON.generate(version: version, checks: checks.length, verdicts: checks.group_by { |c| c[:verdict] }.transform_values(&:length),
      failures: checks.select { |c| c[:verdict] == "FAIL" }.map { |c| [c[:criterion], c[:check], c[:evidence]] })
  end
end
