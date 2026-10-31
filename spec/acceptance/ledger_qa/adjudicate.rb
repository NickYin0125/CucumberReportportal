# frozen_string_literal: true

require_relative "analyze"
require "cgi"
require "time"

module LedgerQAAnalysis
  class FinalStudy < Study
    HEADS = { "2.0.1" => "ecf8c5aade5b6982f96083cb21c758db56b81b3f", "1.3.2" => "c27510547ace0d4baaf964a0575e5bec4344e11a" }.freeze
    BASES = { "2.0.1" => "79e5e9cfde4be6d29ca2293e549460c6c71fe87a", "1.3.2" => "4ca2f770e0a84e83688f165ba04b4db8ef855cf9" }.freeze
    REPAIR = "20261031T173014Z"
    MATRIX = "final-hooks-20261101"
    HOOKS = "20261031T180948Z"

    def file(path)
      File.join(root, path)
    end

    def load_set(suffix)
      Dir[file("docs/reviews/assets/ledger-qa-live/#{suffix}/*/snapshot.json")].sort.to_h do |path|
        [File.basename(File.dirname(path)), JSON.parse(File.read(path)).merge("_directory" => File.dirname(path))]
      end
    end

    def paths(snapshot, hooks: true)
      @canonical_hook_names ||= {}
      path = File.join(snapshot.fetch("_directory"), "native.ndjson")
      if hooks && File.file?(path)
        native = File.readlines(path).filter_map { |line| JSON.parse(line)["hook"] }
        { "BEFORE_TEST_CASE" => ["BEFORE_METHOD", "Before hook"], "AFTER_TEST_CASE" => ["AFTER_METHOD", "After hook"] }.each do |kind, (type, label)|
          definitions = native.select { |hook| hook["type"] == kind }
          items = snapshot.fetch("items").select { |item| item["type"] == type }
          next unless definitions.length == 1 && items.length == 1 && !definitions.first["name"].to_s.empty?
          wanted = "#{label} \u00b7 #{definitions.first['name']}"
          current = super_hook_name(items.first)
          @canonical_hook_names[items.first["id"]] = wanted if [label, wanted].include?(current)
        end
      end
      super
    end

    def super_hook_name(item)
      Study.instance_method(:hook_name).bind_call(self, item)
    end

    def hook_name(item)
      @canonical_hook_names&.fetch(item["id"], nil) || super
    end

    def run(mode, repeat = 1)
      result = super.merge(%w[plain rich].include?(mode) ? load_set("#{REPAIR}-terminal-repair-#{mode}-#{repeat}") : {})
      if %w[plain rich].include?(mode)
        cucumber = version == "1.3.2" ? "10.2.0" : "12.0.1"
        result.merge!(load_set("#{HOOKS}-hooks-#{cucumber}-companions-#{mode}-#{repeat}"))
        parallel = file("docs/reviews/assets/ledger-qa-live/#{HOOKS}-hooks-12.0.1-parallel-#{mode}-#{repeat}/snapshot.json")
        result["F06"] = JSON.parse(File.read(parallel)).merge("_directory" => File.dirname(parallel)) if version == "2.0.1" && File.file?(parallel)
      end
      result
    end

    def all_candidates
      @all_candidates ||= [@stamp, REPAIR, "20261031T174824Z", HOOKS].flat_map do |stamp|
        Dir[file("docs/reviews/assets/ledger-qa-live/#{stamp}-*/**/snapshot.json")].reject { |path| path.match?(/-baseline(?:-|\/)/) }.map do |path|
          JSON.parse(File.read(path)).merge("_directory" => File.dirname(path))
        end
      end
    end

    def wire_entries(snapshot)
      records = JSON.parse(File.read(File.join(snapshot.fetch("_directory"), "wire.json")))
      records.flat_map { |request| Array(request["entries"] || (request["json"].is_a?(Array) ? request["json"] : [])) }
    end

    def evidence_file(id, label, path, expected, actual, passed: expected == actual, note: nil, inputs: nil, method: "U")
      check(id, label, expected, actual, passed: passed, note: note, method: method, inputs: inputs)
      checks.last[:evidence][:source] = path
    end

    def unit(id, pattern, minimum: 1)
      found = []
      cells = version == "1.3.2" ? %w[M1 M2 M3 M4] : %w[M5 M6]
      cells.each do |cell|
        relative = "docs/reviews/assets/ledger-qa-runs/#{MATRIX}/#{cell}/source/docs/reviews/assets/qa-cell-evidence/rspec.json"
        next unless File.file?(file(relative))
        begin
          rows = read(relative).fetch("examples").select { |example| example.fetch("full_description").match?(pattern) }
        rescue JSON::ParserError
          blocked(id, "#{cell} full-suite JSON is still being written")
          next
        end
        found.concat(rows)
        evidence_file(id, "#{cell} focused assertion evidence from the FULL suite", relative,
          "At least #{minimum} matching examples, all passed", rows.map { |r| r.slice("full_description", "status", "file_path", "line_number") },
          passed: rows.length >= minimum && rows.all? { |r| r["status"] == "passed" })
      end
      blocked(id, "No final-head full-suite evidence yet for #{pattern.inspect}") if found.empty?
    end

    def derived_check(id, label, from:, method:)
      parents = checks.select { |entry| from.include?(entry[:criterion]) }
      raise "Derived check has no input checks" if parents.empty?
      sources = parents.flat_map { |entry| Array(entry.dig(:evidence, :source)) }.compact.uniq
      evidence_file(id, label, sources, 0, parents.count { |entry| entry[:verdict] != "PASS" },
        inputs: { derives_from_criteria: from, source_check_count: parents.length }, method: method)
      %i[launch_ids item_ids log_ids].each do |key|
        checks.last[:evidence][key] = parents.flat_map { |entry| Array(entry.dig(:evidence, key)) }.uniq
      end
    end

    def contract_checks(plain, rich, baseline)
      ordinary = version == "1.3.2" ? baseline.reject { |id, _| %w[F08 F09].include?(id) } : baseline
      super(plain, rich, ordinary)
      return unless version == "1.3.2"
      permitted = { "F08" => %w[text-file.txt text-path.txt text-binread.txt text-binary.txt text-encoded.txt], "F09" => ["nul-repro.txt"] }
      permitted.each do |fixture, allowed|
        old = baseline.fetch(fixture)
        submitted = submitted_attachments(old)
        missing = submitted.select { |part| part["message"].include?("\0") }
        check("G3", "Decision 8 #{fixture}: exact historical NUL preview loss set", allowed.sort, missing.map { |part| part["name"] }.sort,
          snapshot: old, inputs: { decision: 8, old_api_files: old["files"].length, old_submitted_files: submitted.length },
          note: "Historical loss is retained, not relabelled as API persistence. Only these six files across F08/F09 use baseline submitted wire as their oracle.")
        locations = paths(old)
        by_uuid = old.fetch("items").to_h { |item| [item["uuid"], item] }
        expected_counts = locations.values.to_h { |owner| [owner, []] }
        wire_entries(old).each do |entry|
          next unless entry["itemUuid"]
          # The unchanged native raw-NUL user log never persists in either SDK.
          next if !entry["file"] && entry["message"].include?("\0")
          owner = locations.fetch(by_uuid.fetch(entry["itemUuid"]).fetch("id"))
          expected_counts.fetch(owner) << entry["level"]
        end
        receipts = JSON.parse(File.read(File.join(old["_directory"], "wire.json"))).select { |request| request["entries"] }
        check("G2", "Decision 8 #{fixture}: baseline upload receipts are accepted, not persistence proof", true,
          receipts.all? { |request| request["status"] == 201 && request.dig("response", "responses").to_a.all? { |r| r["id"] } }, snapshot: old,
          inputs: receipts.map { |r| r.slice("status", "response", "request_sha256") })
        [plain, rich].each_with_index do |runs, index|
          current = runs.fetch(fixture)
          label = %w[plain rich][index]
          check("G1", "#{fixture} #{label} item contract unchanged", contract(old), contract(current), snapshot: current, method: "C", inputs: refs(old))
          check("G2", "Decision 8 #{fixture} #{label}: full readback, excluding only unchanged native-NUL loss", expected_counts.transform_values(&:sort), log_counts(current).transform_values(&:sort), snapshot: current, method: "C", inputs: refs(old))
          expected_files = submitted.map { |part| part.values_at("owner", "name", "mime", "bytes", "sha256") }.sort
          check("G3", "Decision 8 #{fixture} #{label}: wire baseline -> complete owned API download", expected_files, attachment_owners(current), snapshot: current, method: "C", inputs: refs(old))
          check("P5.7", "Decision 8 #{fixture} #{label}: every submitted attachment has exact downloaded bytes", submitted.length, current["files"].length, snapshot: current, method: "C")
        end
      end
    end

    def proposal_golden(section, index = 0)
      proposal = File.read(file("docs/design/presentation-ledger-proposal.md"))
      body = proposal.split(/^### #{Regexp.escape(section)} \u00b7 /, 2).last.to_s.split(/^### /, 2).first
      body.scan(/````markdown\n(.*?)\n````/m).fetch(index).first
    end

    def supplemental_checks
      frozen = read("docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json")
      backtrace = frozen.fetch("backtrace")
      tail = backtrace.is_a?(Array) ? backtrace.join("\n") : backtrace
      golden = proposal_golden("P1")
      golden = golden[0...golden.rindex("```text\n")] + "```text\n#{tail}\n```"
      evidence_file("P1.1", "Owner-retained recovered F04 input hash and 62 actual frames", "docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json",
        [true, 62, "3fd9692c6e95a2e7e1868111ad41fd5f2584f95098c67d18ccc9756d66eca75d"],
        [frozen["source_api_verified"], tail.lines.length, Digest::SHA256.hexdigest(tail)],
        inputs: frozen.slice("source_launch_id", "source_item_id", "source_log_id", "raw_bytes", "raw_sha256"),
        note: "Frozen original input replay, not a claim about the current native call stack. The original natural F04 observations remain separate.")
      %w[plain rich].each do |mode|
        2.times do |repeat|
          set = load_set("#{@stamp}-supplement-#{mode}-#{repeat + 1}")
          s = set.fetch("F04-frozen")
          error = logs(s).find { |log| log["level"] == "error" }
          if mode == "plain"
            check("P1.1", "Frozen F04 #{mode}/#{repeat + 1} exact Decision 7 golden + all 62 original lines", golden, error.fetch("message"), snapshot: s)
            baseline = load_set("#{@stamp}-supplement-baseline").fetch("F04-frozen")
            check("P1.1", "Frozen F04 tail equals baseline message lines 2-63", logs(baseline).find { |l| l["level"] == "error" }["message"].split("\n", 2).last,
              error["message"].split("```text\n").last.sub(/\n```\z/, ""), snapshot: s, inputs: refs(baseline))
          end
          check("P1.3", "Frozen F04 real total/framework/runner caption counts", true,
            error["message"].include?("62 frames \u00b7 56 framework and 2 runner frames not shown above"), snapshot: s,
            inputs: { total: 62, framework: tail.lines.count { |l| l.include?("/gems/") }, runner: tail.lines.count { |l| l.start_with?("-e:", "<internal:") } })
          adapted = set.fetch("F16c-adapted")
          check("P1.2", "Controlled non-Exception input has message-only title", "## \u2717 Non-Exception failure",
            logs(adapted).find { |l| l["level"] == "error" }["message"].lines.first.chomp, snapshot: adapted,
            note: "Explicit error-field event adaptation; not a claim that Ruby can naturally raise a Struct.")
          shape = load_set("#{REPAIR}-framework-replay-#{mode}-#{repeat + 1}").fetch("F16b-framework-replay")
          text = logs(shape).find { |l| l["level"] == "error" }.fetch("message")
          expected = "first.rb:11   Framework.one\nsecond.rb:22  Framework.two\nthird.rb:33   Framework.three"
          check("P1.4", "Controlled zero-project input shows exactly its first three framework frames", expected, text[/```text\n(.*?)\n```/m, 1], snapshot: shape,
            inputs: { source: "spec/acceptance/ledger_qa/framework_shape_support.rb", framework: 4, runner: 2, project: 0 },
            note: "Controlled formatter/event input, not natural JSON.parse; original native F16b includes a step-definition frame and is insufficient for this branch.")
          check("P1.3", "Controlled zero-project tail has all six input frames and exact hidden counts", true,
            text.include?("6 frames \u00b7 1 framework and 2 runner frames not shown above"), snapshot: shape)
          check("G2", "Controlled input yields exactly one ERROR log", 1, logs(shape).count { |l| l["level"] == "error" }, snapshot: shape)
          f02 = set[version == "1.3.2" ? "F02-description-only-golden" : "F02-golden"]
          ["TABLE_ONLY_AMBER", "TABLE_ONLY_BIRCH"].each_with_index do |value, n|
            item = f02.fetch("items").find { |i| i["hasStats"] && i.fetch("parameters", []).any? { |p| p["value"] == value } }
            expected = "`value` = `#{value}` \u00b7 _Examples: Table-only substitution \u00b7 line #{12 + n}_"
            check("P4.1", "F02 #{mode}/#{repeat + 1} exact #{value} description", expected, item && item["description"], snapshot: f02)
          end
        end
      end
    end

    def extended_features(plain, rich, baseline)
      p7 = proposal_golden("P7")
      id = version == "1.3.2" ? "F03-legacy-separate" : "F03"
      s = plain.fetch(id)
      %w[AMBER BIRCH].each do |value|
        expected = p7.gsub("AMBER", value)
        actual = logs(s).select { |l| l["message"].include?("TABLE_ONLY_#{value}") }.map { |l| l["message"] }
        if version == "1.3.2"
          table, doc = expected.split("\n\n_Doc string", 2)
          check("P7.1", "#{value} separated companion exact table content, both argument orders (Decision 4)", [table, table], actual, snapshot: s,
            note: "Only native same-step compound syntax is N/A on 1.x; parser rejection is retained. This is not relabelled native compound execution.")
          check("P7.1", "Separated constant DocString content for all four scenarios", 4, logs(s).count { |l| l["message"] == "_Doc string#{doc}" }, snapshot: s)
        else
          check("P7.1", "#{value} native doc-first/table-first steps each equal exact P7 golden", [expected, expected], actual, snapshot: s)
        end
      end
      f14 = plain.fetch("F14")
      rows = f14["items"].select { |i| i["hasStats"] && i["parent"] }
      fallback = rows.select do |i|
        params = i.fetch("parameters", [])
        params.length > 4 || params.any? { |p| p["value"].length > 40 || p["value"].include?("\n") }
      end
      check("P4.2", "All three Outline fallback shapes exercised", 3, fallback.length, snapshot: f14)
      fallback.each do |item|
        description = item.fetch("description")
        check("P4.2", "#{item['name']} escaped table and Examples location", true,
          description.start_with?("Examples") && description.match?(/line \d+/) && description.include?("\n\n|") && !description.include?("first\nsecond"), snapshot: f14,
          inputs: item.slice("id", "parameters", "codeRef"))
      end
      f17 = plain.fetch("F17")
      names = submitted_attachments(f17).map { |part| part["name"] }
      batch = run("default-batch1").fetch("F17")
      check("P5.6", "Unnamed filenames are stable across smallest/default batching", names, submitted_attachments(batch).map { |part| part["name"] }, snapshot: f17, inputs: refs(batch))
      check("P5.6", "Required owner-local first/second PNG and After-hook JPEG names", true,
        %w[then-the-order-is-confirmed.png then-the-order-is-confirmed-1.png after-hook.jpg].all? { |name| names.include?(name) }, snapshot: f17)
      progressive = logs(f17).find { |l| l["message"].include?("confirmed-2.jpg") }
      check("P5.2", "Progressive SOF2 JPEG has input dimensions 2 x 2", true, progressive && progressive["message"].include?("JPEG \u00b7 2 \u00d7 2 \u00b7 586 B"), snapshot: f17)
      f08 = plain.fetch("F08-negative")
      negative = logs(f08).find { |l| l["message"].include?("png-plain_base64.png") }
      check("P5.2", "plain_base64 PNG negative control keeps kind without inferred dimensions", true,
        negative && negative["message"].start_with?("`png-plain_base64.png` \u00b7 PNG \u00b7 ") && !negative["message"].include?("\u00d7"), snapshot: f08)
      f18 = plain.fetch("F18")
      oversized = logs(f18).find { |l| l["message"].start_with?("`oversized.json`") }
      preview = oversized && oversized["message"][/```json\n(.*?)\n```/m, 1]
      check("P5.5", "Oversized JSON is bounded original text, not pretty-printed", true,
        preview && !preview.include?("\n  \"") && preview.bytesize <= 16_500, snapshot: f18)
      captions = logs(f18).map { |l| l["message"].lines.first.chomp }
      %w[JSON text/markdown].each do |type|
        check("P7.4", "Declared/detected #{type} DocString caption", true, captions.include?("_Doc string \u00b7 #{type}_"), snapshot: f18)
      end
      check("P7.4", "Unspecified DocString caption", true, captions.include?("_Doc string_"), snapshot: f18)
      check("P7.4", "Declared, detected, and long JSON DocStrings exercised", 3, captions.count("_Doc string \u00b7 JSON_"), snapshot: f18)
      expected_http = proposal_golden("P8", 2)
      check("P8.4", "F11a exact owner-corrected INFO golden, including all headers and 55/51 B", expected_http,
        logs(plain.fetch("F11a")).first["message"], snapshot: plain.fetch("F11a"))
      all_candidates.each do |snapshot|
        logs(snapshot).each do |log|
          check("P5.3", "No generated legacy Attachment prefix (log #{log['id']})", false, log["message"].start_with?("Attachment:"), snapshot: snapshot)
          check("P5.4", "No generated legacy Failure evidence prefix (log #{log['id']})", false, log["message"].start_with?("Failure evidence:"), snapshot: snapshot)
        end
      end
      # Raw user-log oracle comes from the baseline's observed wire, not from
      # the candidate renderer or a reconstructed candidate message.
      baseline.each do |fixture, old|
        current = plain[fixture]
        next unless current
        inputs_path = File.join(old["_directory"], "inputs.ndjson")
        next unless File.file?(inputs_path)
        input = File.readlines(inputs_path).map { |line| JSON.parse(line) }
        raw = input.filter_map do |entry|
          entry["value"] if entry["kind"] == "literal"
        end + input.select { |entry| entry["kind"] == "native_log" }.map { |entry| entry["message"] }
        old_messages = wire_entries(old).map { |entry| entry["message"] }
        new_messages = wire_entries(current).map { |entry| entry["message"] }
        raw.each do |message|
          next unless old_messages.include?(message)
          check("P3.3", "#{fixture} raw authored user log is byte-identical", old_messages.count(message), new_messages.count(message), snapshot: current,
            inputs: { baseline: refs(old), original_utf8: message }, method: "C")
        end
      end
    end

    def closed_vocabulary(plain, rich)
      proposal = File.read(file("docs/design/presentation-ledger-proposal.md"))
      pill = proposal[/^PILL\s*= (.*)$/, 1]
      allowed_styles = %w[PASS FAIL WARN INFO].map { |tone| "#{pill};#{proposal[/^#{tone}\s*= (.*?)\s+\(/, 1]}" }
      allowed_styles.concat(%w[TITLE TH].map { |key| proposal[/^#{key}\s*= (.*)$/, 1] })
      rich.each do |fixture, r|
        p = plain.fetch(fixture)
        plain_text = logs(p).map { |l| l["message"] }.join("\n")
        logs(r).each do |log|
          tags = log["message"].scan(/<\/?[a-zA-Z][^>]*>/)
          invalid = tags.reject { |tag| %w[<details> </details> <summary> </summary> </span>].include?(tag) ||
            (tag.start_with?("<span style=\"") && allowed_styles.include?(tag[/\A<span style="([^"]+)">\z/, 1])) || plain_text.include?(tag) }
          check("P10.3", "#{fixture} log #{log['id']} exact tag/style vocabulary", [], invalid, snapshot: r, inputs: { allowed_styles: allowed_styles })
          log["message"].scan(/<details>.*?<\/details>/m).each do |details|
            fence_lines = details.lines.each_index.select { |i| details.lines[i].start_with?("```") }
            valid = fence_lines.each_with_index.all? do |line, n|
              n.even? ? details.lines[line - 1] == "\n" : details.lines[line + 1] == "\n"
            end
            check("P10.8", "#{fixture} log #{log['id']} fence blank lines in details", true, valid, snapshot: r)
          end
        end
      end
    end

    def audit_reads
      [@stamp, REPAIR, "20261031T174824Z", HOOKS].each do |stamp|
        path = "docs/reviews/assets/ledger-qa-read-api-audit-#{stamp}.json"
        unless File.file?(file(path))
          blocked("G5", "Missing completed per-item read API audit #{stamp}")
          blocked("G8", "Missing completed per-item read API audit #{stamp}")
          next
        end
        read(path).reject { |row| row.fetch("audit_file").match?(/-baseline(?:-|\/)/) }.each do |row|
          complete = row["items_complete"]
          supplemental = nil
          if stamp == HOOKS && !complete
            supplemental = "docs/reviews/assets/ledger-qa-retry-read-#{HOOKS}/launch-#{row.fetch('launch_id')}.json"
            if File.file?(file(supplemental))
              proof = read(supplemental)
              source = JSON.parse(File.read(row.fetch("audit_file")))
              complete = proof["verdict"] == "PASS" && proof["original_audit_sha256"] == Digest::SHA256.file(row.fetch("audit_file")).hexdigest &&
                proof["source_snapshot_sha256"] == source["snapshot_sha256"] && proof["expanded_item_ids"] == proof["expected_snapshot_item_ids"] &&
                proof["expanded_log_ids"] == proof["expected_snapshot_log_ids"] && proof["validations"].all? { |entry| entry["verdict"] == "PASS" }
            end
          end
          evidence_file("G5", "Launch #{row['launch_id']} full nested prefix search and ID-complete fresh readback", path,
            [true, true, 0], [complete, row["logs_complete"], row["prefix_hits"]], method: "L", inputs: { original: row, immutable_retry_supplement: supplemental },
            note: supplemental && "Original mismatch retained. Actual embedded retries + direct verified GET expand the API's latest-attempt grouping, without changing parentage or waiving identity checks.")
          evidence_file("G8", "Launch #{row['launch_id']} full nested secret search and metadata scan", path,
            [true, true, 0, false], [complete, row["logs_complete"], row["secret_hits"], row["metadata_secret"]], method: "L", inputs: { original: row, immutable_retry_supplement: supplemental })
        end
      end
    end

    def gaps_checks
      base = load_set("20261031T174824Z-contract-gaps-baseline").fetch("F14-authored-logs")
      %w[plain rich].each do |mode|
        set = load_set("20261031T174824Z-contract-gaps-#{mode}")
        raw = set.fetch("F14-authored-logs")
        check("P3.3", "Direct rp_log and AppLog.info: all eight authored byte strings equal the independent baseline", messages(base), messages(raw), snapshot: raw, method: "C", inputs: refs(base))
        check("G1", "Authored user logger item tree equals baseline", contract(base), contract(raw), snapshot: raw, method: "C", inputs: refs(base))
        check("G2", "Authored user logger per-owner levels/counts equal baseline", log_counts(base), log_counts(raw), snapshot: raw, method: "C", inputs: refs(base))
        context = set.fetch("F19-missing-parts")
        probe = JSON.parse(File.read(File.join(File.dirname(context["_directory"]), "probe.json")))
        runtime = JSON.parse(probe.fetch("stdout"))
        launch = context.fetch("launches").first
        check("P9.4", "#{mode} enabled context omits all absent optional parts", "Cucumber #{runtime['cucumber']} \u00b7 Ruby #{runtime['ruby_version']}", launch["description"], snapshot: context)
        attrs = [["sdk", version], ["cucumber", runtime["cucumber"]], ["ruby", runtime["ruby_version"]]].sort
        check("P9.2", "#{mode} only present SDK/Cucumber/Ruby attributes emitted", attrs, launch["attributes"].map { |a| a.values_at("key", "value") }.sort, snapshot: context)
      end
      sets = [run("plain"), run("rich")]
      sets += %w[plain rich].map { |mode| load_set("#{HOOKS}-hooks-9.2.1-companions-#{mode}-1") } if version == "1.3.2"
      sets.each do |set|
        unnamed = set.fetch("F15")
        names = unnamed["items"].select { |i| %w[BEFORE_METHOD AFTER_METHOD].include?(i["type"]) }.map { |i| i["name"] }.sort
        check("P6.1", "Native F15 unnamed Before/AfterStep/After names", ["Before hook", "AfterStep hook", "After hook"].sort, names, snapshot: unnamed)
        named = set.fetch("F15-named")
        native = File.readlines(File.join(named["_directory"], "native.ndjson")).filter_map { |line| JSON.parse(line)["hook"] }
        declared = native.select { |hook| hook["type"] == "BEFORE_TEST_CASE" || (hook["type"].nil? && native.length == 1) }.map { |hook| hook["name"] }
        check("P6.1", "Native supported Before name is present in Cucumber messages", ["Open browser"], declared, snapshot: named, inputs: native)
        actual = named["items"].select { |i| i["type"] == "BEFORE_METHOD" }.map { |i| i["name"] }
        check("P6.1", "Native supported Before name survives into RP Item display", ["Before hook \u00b7 Open browser"], actual, snapshot: named,
          inputs: { native_hook_definitions: native }, note: "Final repaired native input; original failure remains in the separate historical defect ledger.")
      end
    end

    def visual_checks
      path = "docs/reviews/assets/ledger-qa-dom-#{version}.json"
      dom = read(path)
      dom.fetch("P1_6_repaired").fetch("values").each do |row|
        expected = row["titles"].first["textContent"].include?("script") ? "\u2717 RuntimeError: x<script>alert(1)</script>" : "\u2717 RuntimeError: <b>x</b>"
        evidence_file("P1.6", "Literal exception title and no injected script/b elements", path, [expected, 0, 0],
          row.fetch("titles").first.values_at("textContent", "scriptCount", "bCount"), method: "D", inputs: row)
      end
      values = dom.fetch("F14_repaired").fetch("values")
      evidence_file("P2.1", "Every escaping matrix cell independently inspected", path, 14, values.length, method: "D")
      values.each do |row|
        expected = row.fetch("expected")
        actual = row.fetch("cells").first
        rendered = expected.include?("\n") ? actual["innerText"] : actual["textContent"]
        evidence_file("P2.1", "Rendered F14 literal #{expected.inspect}", path, expected.strip, rendered.strip, method: "D", inputs: row,
          note: "For the explicit newline case, innerText plus BR count proves a real line break; textContent alone does not insert LF for a BR (Decision 1).")
      end
      dom.fetch("F03_repaired").each do |row|
        evidence_file("P2.1", "Rendered F03 literal row", path, row["expected"], row.fetch("cells").last["textContent"].strip, method: "D", inputs: row)
      end
      chips = dom.fetch("F02_repaired_list").fetch("chip_lineboxes")
      evidence_file("P4.3", "Value/key chips each occupy one physical text line at 1100px", path, true,
        chips.length == 4 && chips.all? { |chip| chip["textRects"].length == 1 } &&
        chips.each_slice(2).all? { |left, right| left["textRects"].first["top"] == right["textRects"].first["top"] }, method: "D",
        inputs: chips, note: "Examples metadata wraps; the literal chip criterion passes. Preserve wrapping as S3 cosmetic, not an S2 or waiver.")
      dom.fetch("F13_repaired_alignment").each do |row|
        table = row.fetch("table")
        evidence_file("P7.5", "#{row['mode']} numeric columns computed right alignment", path, true,
          table["rows"].all? { |cells| cells[1..4].all? { |cell| cell["align"].end_with?("right") } }, method: "D", inputs: row)
        evidence_file("P10.9", "#{row['mode']} eight-column DOM has no styled TH span", path, 0, table["headerSpans"], method: "D", inputs: row)
      end
      detail = dom.fetch("F04_repaired_rich")
      evidence_file("P10.8", "Native rich fold contains direct PRE > CODE and is actually open", path, true,
        detail["details"].all? { |row| row["open"] && row["directPreCode"] == 1 }, method: "D", inputs: detail)
      dom.fetch("all_fold_families").each do |family|
        evidence_file("P10.8", "#{family['fixture']} every distinct folded content family has native direct PRE > CODE", path, true,
          !family["details"].empty? && family["details"].all? { |row| row["preCode"] == 1 && row["codeLengths"].all?(&:positive?) }, method: "D", inputs: family)
      end
      consoles = dom.fetch("console_verified_search")
      evidence_file("P3.4", "Actual native Console observed for all four required families", path, %w[F01 F04 F10a F11a], consoles.map { |row| row["fixture"].sub("-frozen", "") }.sort, method: "D")
      consoles.each do |row|
        evidence_file("P3.4", "#{row['fixture']} true Console, matching original messages, settings restored", path, true,
          row["console_class"].include?("active") && row["console_rows"] > 0 && row["message_exact_suffix"] &&
          row["search_restored"] == "" && row["markdown_restored_class"].include?("active") && !row["pagination_changed"], method: "D", inputs: row)
      end
      dom.fetch("markdown_off_restored").each do |row|
        evidence_file("P3.4", "#{row['fixture']} raw Markdown view is legible and restored", path, true,
          !row["off"].include?("active") && row["restored"].include?("active") && !row["raw_display"].empty?, method: "D", inputs: row)
      end
      styles = dom.fetch("cards_repaired_styles").flat_map { |row| row.fetch("pills") }
      styles += dom.fetch("F01_rich_computed_style").fetch("values").select { |row| row["style"].to_s.include?("border-radius:9px") }
      lum = lambda do |rgb|
        components = rgb.scan(/[\d.]+/).first(3).map { |n| n.to_f / 255 }
        components = components.map { |n| n <= 0.04045 ? n / 12.92 : ((n + 0.055) / 1.055)**2.4 }
        components.zip([0.2126, 0.7152, 0.0722]).sum { |n, weight| n * weight }
      end
      tones = styles.uniq { |row| row.values_at("color", "background") }
      evidence_file("P10.11", "Computed pill colors cover all four tones", path, 4, tones.length, method: "D")
      tones.each do |style|
        a, b = [lum.call(style["color"]), lum.call(style["background"])].sort
        ratio = (b + 0.05) / (a + 0.05)
        evidence_file("P10.11", "#{style['text']} computed WCAG contrast", path, ">= 4.5:1", ratio, passed: ratio >= 4.5, method: "D", inputs: style)
      end
      download = "docs/reviews/assets/ledger-qa-download-file-#{version}.json"
      data = read(download)
      evidence_file("P5.8", "Real native Download produced exact filename and bytes on disk", download,
        ["visible-fixture.png", 5421, "e0670cf624674df9a2485177d68ca12d3dc501db2249e05c325a999c22db2bc0"],
        data.values_at("original_filename", "bytes", "sha256"), method: "V", inputs: data,
        note: "Actual UI click plus independently statted/hashed generated artifact. API headers are not substituted. Master archival instruction, not an owner waiver.")
      screenshots = "docs/reviews/assets/ledger-qa-screenshots-#{version}.json"
      shots = read(screenshots).reject { |shot| shot["slug"].include?("scope-blocked") }
      mapping = { "P1.8" => "S01", "P1.9" => "S02", "P4.3" => "S05", "P5.8" => "S06",
        "P6.4" => "S07", "P7.5" => "S08", "P9.5" => "S10", "P3.4" => "S12", "P10.10" => "S03" }
      mapping.each do |id, prefix|
        matching = shots.select { |shot| shot["slug"].start_with?(prefix) }
        evidence_file(id, "Judged native #{prefix} screenshots", screenshots, "At least one retained native image, all judged PASS", matching.map { |s| s.slice("slug", "visual_verdict", "png", "url", "launch_ids", "item_ids", "log_ids", "capture_method") },
          passed: !matching.empty? && matching.all? { |shot| shot["visual_verdict"].start_with?("PASS") && File.file?(shot["png"]) }, method: "V")
      end
    end

    def remaining_live(plain, rich, baseline)
      %w[plain rich].each do |mode|
        run(mode).each do |fixture, snapshot|
          logs(snapshot).each do |log|
            check("G7", "#{mode} #{fixture} exhaustive forbidden vocabulary", [], log["message"].scan(/<style|url\(|position:| class=| id=|<img|<svg|javascript:|\son[a-z]+=/i), snapshot: snapshot)
          end
        end
      end
      derived_check("P3.1", "Complete nested read API evidence covers no-prefix rule", from: %w[G5 G7], method: "L")
      f14 = plain.fetch("F14")
      raw = logs(f14).map { |l| l["message"] }
      %w[&lt;other&gt; &lt;b&gt;x&lt;/b&gt; &amp;amp;].each do |entity|
        check("P2.2", "Data outside code has entity #{entity}", true, raw.any? { |text| text.start_with?("_Data table") && text.include?(entity) }, snapshot: f14)
      end
      check("P2.2", "Data inside code spans retains raw angle brackets and ampersand", true,
        f14["items"].any? { |item| item["description"].to_s.include?("`<other>`") } && f14["items"].any? { |item| item["description"].to_s.include?("`&amp;`") }, snapshot: f14)
      derived_check("P5.7", "All exact G3 owner/name/MIME/hash comparisons passed", from: ["G3"], method: "C")
      f12 = plain.fetch("F12")
      check("P8.5", "Exact full evidence card golden", proposal_golden("P8", 1), logs(f12).find { |l| l["level"] == "error" }["message"], snapshot: f12)
      f10d = plain.fetch("F10d")
      check("P8.2", "F10d expected/actual are scalar-object Ledger JSON", true,
        logs(f10d).first["message"].include?('expected  { "currency": "USD", "notional": 5000000 }') &&
        logs(f10d).first["message"].include?('actual    { "currency": "USD", "notional": 4000000 }'), snapshot: f10d)
      default = run("default-batch1")
      default.each do |fixture, snapshot|
        check("P10.1", "Unset mode #{fixture} adds no Tier 2 tags", [], logs(snapshot).flat_map { |log| log["message"].scan(/<details|<summary|<span style/) }, snapshot: snapshot)
      end
      f20 = plain.fetch("F20")
      process = JSON.parse(File.read(File.join(f20["_directory"], "process.json")))
      warning_lines = process["stderr"].lines.grep(/presentation/i)
      check("P10.2", "Invalid RP_PRESENTATION gives exactly one nonreflective warning", 1, warning_lines.length, snapshot: f20, method: "U", inputs: warning_lines)
      check("P10.2", "Invalid mode still sends plain messages", [], logs(f20).flat_map { |log| log["message"].scan(/<details|<summary|<span style/) }, snapshot: f20)
      plain.each do |fixture, snapshot|
        probe = JSON.parse(File.read(File.join(File.dirname(snapshot["_directory"]), "probe.json"))) rescue nil
        runtime = probe && JSON.parse(probe["stdout"])
        stdlib = runtime && "/usr/local/lib/ruby/#{runtime['ruby_version'].split('.')[0, 2].join('.')}.0/"
        logs(snapshot).select { |log| log["message"].include?("_Full backtrace") }.each do |log|
          text = log["message"]
          raw = text.split("```text\n").last.sub(/\n```\z/, "")
          frames = raw.lines.map(&:chomp)
          framework = frames.select { |frame| frame.include?("/gems/") || (stdlib && frame.start_with?(stdlib)) }
          runner = frames.select { |frame| frame.start_with?("-e:", "<internal:") }
          projects = frames - framework - runner
          feature = projects.find { |frame| frame.match?(/\.feature:\d+/) }
          shown = text.include?("_Project frames_") ? text[/_Project frames_\n\n```text\n(.*?)\n```/m, 1] : text[/```text\n(.*?)\n```/m, 1]
          shown_lines = shown.to_s.lines
          expected_count = projects.empty? ? [framework.length, 3].min : [(projects - [feature]).length, 8].min + (feature ? 1 : 0)
          check("P1.4", "#{fixture} native shown-frame count obeys eight-project/three-framework cap", expected_count, shown_lines.length, snapshot: snapshot, inputs: { log_id: log["id"], projects: projects.length, framework: framework.length, runner: runner.length })
          hidden_framework = framework.length - (projects.empty? ? expected_count : 0)
          caption = text[/_Full backtrace \u00b7 ([^\n]+)_/, 1]
          expected_caption = "#{frames.length} frames \u00b7 #{hidden_framework} framework and #{runner.length} runner frames not shown above"
          check("P1.3", "#{fixture} native caption equals independently classified raw tail", expected_caption, caption, snapshot: snapshot, inputs: { log_id: log["id"], stdlib_prefix: stdlib })
        end
      end
      # The literal mandated strip regex destroys fenced Ruby evidence. Keep
      # this blocked until the owner resolves the already-recorded contradiction.
      blocked("P10.6", "Literal strip-tags removes <top (required)> and <main> inside byte-frozen F04 fences; owner clarification pending",
        inputs: "docs/reviews/assets/ledger-qa-p106-strip-conflict-#{version}.json")
    end

    def legibility_checks(plain, rich)
      # Provisional implementation of the pending owner clarification. Literal
      # raw-code bytes survive; only client vocabulary is removed, not user tags.
      strip = lambda do |text|
        saved = []
        protect = lambda { |value| saved << value; "\u0001#{saved.length - 1}\u0002" }
        output = text.gsub(/^(`{3,})[^\n]*\n.*?^\1(?=\n|\z)/m) { |value| protect.call(value) }
        output = output.gsub(/(`+)(?!`)[^\n]*?\1(?!`)/) { |value| protect.call(value) }
        output = output.gsub(/<\/?(?:details|summary)>|<span style="[^"]+">|<\/span>/, "")
        output.gsub(/\u0001(\d+)\u0002/) { saved.fetch(Regexp.last_match(1).to_i) }
      end
      canonical = lambda do |text, is_rich|
        value = is_rich ? strip.call(text) : text
        if is_rich
          value = value.gsub(/^(PNG|JPEG|Text|JSON) (`[^\n]+?`)(.*)$/) { "#{Regexp.last_match(2)} \u00b7 #{Regexp.last_match(1)}#{Regexp.last_match(3)}" }
          first, rest = value.split("\n", 2)
          if (match = first.match(/\A(\d{3}) ([A-Z]+) (.*?)(?: \u00b7 (.*))?\z/))
            first = "\u2713 #{match[2]} #{match[3]} \u2192 #{match[1]}" + (match[4] ? " \u00b7 #{match[4]}" : "")
            value = [first, rest].compact.join("\n")
          end
        else
          value = value.sub(/\A\u2713 Assertion passed \u00b7 /, "PASS ")
        end
        CGI.unescapeHTML(value).scan(/[[:alnum:]]+/)
      end
      rich.each do |fixture, r|
        p = plain.fetch(fixture)
        group = lambda do |snapshot, accented|
          owner = paths(snapshot)
          logs(snapshot).group_by { |log| [owner.fetch(log["itemId"], "Launch"), log["level"]] }
            .transform_values { |rows| rows.sort_by { |log| canonical.call(log["message"].lines.first, accented).join(" ") } }
        end
        left, right = group.call(p, false), group.call(r, true)
        check("P10.7", "#{fixture} mode log ownership/counts before semantic pairing", left.transform_values(&:length), right.transform_values(&:length), snapshot: r, inputs: refs(p), method: "C")
        left.each do |key, rows|
          rows.zip(right.fetch(key, [])).each do |a, b|
            next unless b
            words = canonical.call(a["message"], false)
            actual = canonical.call(b["message"], true)
            index = 0
            actual.each { |word| index += 1 if index < words.length && word == words[index] }
            check("P10.6", "Provisional code-aware legibility #{fixture} log #{b['id']}", words, actual,
              passed: index == words.length, snapshot: r, inputs: { plain_log: a["id"], rich_log: b["id"], allowed_changes: "Decision 2 kind/PASS/HTTP status positions only" },
              note: "Not final criterion PASS: literal strip-tags contradiction remains BLOCKED pending owner decision.")
          end
        end
      end
    end

    def repository_checks
      path = "docs/reviews/assets/ledger-qa-repository-#{version}.json"
      data = read(path)
      rows = data.fetch("records")
      record = ->(id) { rows.find { |row| row["criterion"] == id } }
      version_file = File.read(file("lib/reportportal_cucumber/version.rb"))
      evidence_file("V1", "Loaded SDK and version constant", path, version, version_file[/VERSION\s*=\s*["']([^"']+)/, 1], inputs: data.slice("head", "baseline"))
      changes = record.call("V2")["stdout"].lines.select { |line| line.match?(/\A[+-](?![+-])/) }.map(&:strip)
      previous = version == "1.3.2" ? "1.3.1" : "2.0.0"
      evidence_file("V2", "Lockfile diff changes only own PATH version", path,
        ["-    reportportal-cucumber-ruby (#{previous})", "+    reportportal-cucumber-ruby (#{version})"], changes)
      evidence_file("V3", "Independent local gem build exact output filename", path, "reportportal-cucumber-ruby-#{version}.gem", data.dig("package", "filename"), inputs: data["package"])
      evidence_file("V6", "No Helm/workflow delta from baseline", path, "", record.call("V6")["stdout"])
      chart = File.read(file("helm/reportportal-rich-experience/Chart.yaml"))
      evidence_file("V6", "Chart/app versions remain independent", path, true, chart.match?(/^version: 1\.3\.1$/) && chart.match?(/^appVersion: ["']?26\.0\.7["']?$/)) if version == "1.3.2"
      changelog = File.read(file("CHANGELOG.md"))
      evidence_file("V4", "New release section and explicit patch SemVer rationale", path, true,
        changelog.include?("## #{version}") && changelog.match?(/patch.*owner|owner.*patch/i))
      if version == "2.0.1"
        target = Open3.capture2("git", "-C", root, "show", "f2e68f112ad28604f4395710f10f595246f6dc00:CHANGELOG.md").first
        old_section = target.split(/^## 2\.0\.0\b/, 2).last
        evidence_file("V4", "Decision 6 preserves officially published 2.0.0 history exactly", path, old_section, changelog.split(/^## 2\.0\.0\b/, 2).last,
          note: "Owner-approved target sync supersedes the obsolete Unreleased draft requirement.")
      end
      config = File.read(file("docs/configuration.md"))
      advanced = File.read(file("docs/advanced-reporting.md"))
      evidence_file("V5", "Documented switches and Presentation section", path, [true, true, true],
        [config.include?("RP_PRESENTATION"), config.include?("RP_RUN_CONTEXT"), advanced.match?(/^#+ .*Presentation/i)])
      refs = record.call("V7")["stdout"].lines.map(&:split).to_h { |sha, name| [name, sha] }
      initial = data.fetch("protected_heads_observed_at_task_start")
      evidence_file("V7", "All three protected heads equal independent initial observation", path, initial, refs.slice(*initial.keys))
      blocked("V7", "Complete initial remote tag-list artifact needs recovery; current exit-only listing does not prove no tags were created", inputs: path) unless data["initial_remote_tags_artifact"]
      history = record.call("V8")["stdout"]
      sequence = [/docs\(design\).*proposal/, /MarkdownText/, /failure card/i, /hook names and step.argument/i,
        /attachment captions/i, /Outline.*assertion/i, /(?:run context|run.context)/i, /(?:accent|Tier 2)/i, /prepare Ledger SDK/i]
      positions = sequence.map { |pattern| history.lines.index { |line| line.match?(pattern) } }
      evidence_file("V8", "C0-C8 semantic stages occur in order and P10 has its own commit", path, true,
        positions.none?(&:nil?) && positions == positions.sort, inputs: { semantic_stages: sequence.map(&:source), positions: positions, history: history },
        note: "Maps named implementation stages, not literal C labels in commit subjects; approved target merge and subsequent defect fixes are retained.")
    end

    def matrix_and_faults
      cells = version == "1.3.2" ? %w[M1 M2 M3 M4] : %w[M5 M6]
      cells.each do |cell|
        path = "docs/reviews/assets/ledger-qa-runs/#{MATRIX}/#{cell}/result.json"
        if File.file?(file(path))
          result = read(path)
          evidence_file("G10", "#{cell} complete full suite and offline Cucumber", path, "PASS", result["status"], inputs: result)
        else
          blocked("G10", "#{cell} final-head full run still incomplete")
        end
      end
      fault_file = "docs/reviews/assets/ledger-qa-faults/final-hooks/fault-results.json"
      faults = read(fault_file)
      evidence_file("G9", "Each public Presentation entry forced to raise", fault_file, 24, faults.length)
      faults.each do |row|
        expected_exit = row["fixture"] == "F04" ? 1 : 0
        actual = [row["harness_exit"], row["child_exit"], row["fault_invocations"], row["warning_count"], !row["fallback_capture"].empty?, row["fallback_capture"].all? { |entry| entry["byte_equal"] }]
        evidence_file("G9", "#{row['entry']}: baseline bytes, exactly one warning, unchanged native exit", fault_file,
          [0, expected_exit, 1, 1, true, true], actual, inputs: row)
      end
      unit("P2.3", /Independent.*(?:html|inline|cell|code|fence)/i, minimum: 5)
      unit("P1.4", /(?:at most eight|first three framework|project frames|eight project)/i)
      unit("P7.2", /specified numeric negative controls/)
      unit("P7.3", /(?:description|argument)/)
      unit("P8.9", /(?:omission marker|oversized details|details.*bounds|details.*bounded|bounded.*details)/i)
      unit("P9.4", /uses only present parts/)
      unit("P6.1", /(?:class.hook|BeforeAll|AfterAll)/)
      unit("P10.2", /(?:invalid.*presentation|presentation.*invalid|unknown presentation|fancy)/i)
    end

    def terminal_checks
      path = "docs/reviews/assets/ledger-qa-terminal-audit-#{REPAIR}.json"
      records = read(path)
      evidence_file("P8.8", "ALL F10/F11/F12, both modes, two repeats captured at final head", path, 48, records.length)
      records.each do |record|
        evidence_file("P8.8", "#{record['fixture']} #{record['mode']} exact native business stdout baseline", path,
          record["expected"], record["actual"], inputs: record["inputs"], note: record["note"])
        evidence_file("G12", "#{record['fixture']} #{record['mode']} fresh native NDJSON equals baseline", path, true, record["native_ndjson_equal"], inputs: record.slice("launch_ids", "item_ids", "log_ids"))
        evidence_file("P10.10", "#{record['fixture']} #{record['mode']} prior visual RP payload remains byte-identical on same owner", path, true, record["rp_payload_owner_messages_unchanged"], inputs: record.slice("prior_rp_snapshot", "rp_message_sha256", "launch_ids"))
      end
    end

    def final_hook_and_native_evidence
      hook_path = "docs/reviews/assets/ledger-qa-hooks-audit-#{version}.json"
      read(hook_path).each do |row|
        value = row.transform_keys(&:to_sym)
        value[:method] = %w[G1 G2 G3].include?(row["criterion"]) ? "C" : (row["criterion"] == "G9" ? "U+L" : "L")
        value[:evidence]["audit_source"] = hook_path
        checks << value
      end
      native_path = "docs/reviews/assets/ledger-qa-native-output-#{version}.json"
      read(native_path).each do |row|
        %w[G12 P10.7].each do |id|
          evidence_file(id, "Native NDJSON and complete official HTML data/template equality", native_path,
            [true, true, true, []], row.values_at("ndjson_equal", "html_models_equal", "html_matches_original_ndjson", "native_tier2_hits"), inputs: row)
        end
      end
      retry_path = "docs/reviews/assets/ledger-qa-retry-reconciliation-#{version}.json"
      read(retry_path).each do |row|
        evidence_file("G1", "Retry Launch #{row['launch']}: actual nested attempts directly verified and expanded, no reparenting", retry_path,
          ["PASS", true, true], row.values_at("verdict", "expanded_exact", "logs_exact"), inputs: row, method: "C",
          note: "Original 15 item-list identity mismatches remain retained. Direct GET metadata, UUIDs, actual parent/Suite-Launch lineage, closed statuses and per-item scans prove the missing attempt is grouped under retries, not lost.")
      end
    end

    def execute
      plain, rich, baseline = run("plain"), run("rich"), run("baseline")
      contract_checks(plain, rich, baseline)
      global_checks(plain, rich, baseline)
      feature_checks(plain, rich, baseline)
      supplemental_checks
      extended_features(plain, rich, baseline)
      closed_vocabulary(plain, rich)
      audit_reads
      matrix_and_faults
      terminal_checks
      gaps_checks
      final_hook_and_native_evidence
      visual_checks
      remaining_live(plain, rich, baseline)
      legibility_checks(plain, rich)
      repository_checks
      @complete.merge(checks.map { |row| row[:criterion] })
      write_result
    end
  end
end

if $PROGRAM_NAME == __FILE__
  LedgerQAAnalysis::FinalStudy.new(File.expand_path("../../..", __dir__), "20261031T072147Z").execute
end
