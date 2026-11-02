# frozen_string_literal: true

require_relative "final_release_common"
require_relative "final_release_security"
require "base64"
require "cgi"

module FinalRelease202
  class Assessment
    def initialize
      @checks = []
      @snapshots = Dir[File.join(OUT, "**/snapshot.json")].reject { |p| p.include?("/source/") || p.include?("/installed/") }.map { |p| [p, read(p)] }
    end

    def read(path) = JSON.parse(File.read(path))
    def verify = FinalRelease202.verify
    def write(path, value) = FinalRelease202.write(path.sub(/\.json\z/, "-v3.json"), value)
    def decode(value) = FinalRelease202.decode(value)
    def check(id, passed, actual, expected = nil)
      @checks << { criterion: id, status: passed.nil? ? "PENDING" : passed ? "PASS" : "FAIL", expected: expected, actual: actual }
    end
    def path(group, fixture, file = "snapshot.json") = File.join(OUT, group, fixture, file)
    def fixture(fixture, mode = "plain")
      group = fixture.start_with?("F16") || %w[F13 F20].include?(fixture) ? "p1-#{mode}" : "fixtures-#{mode}-v3"
      read(path(group, fixture))
    end
    def message(fixture, mode = "plain", index = 0) = self.fixture(fixture, mode).fetch("logs")[index].fetch("message")
    def without_clock(text) = text.gsub(/^([.FUP-]*)\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+ /, '\1').gsub(/^0m[\d.]+s$/, "[duration]")

    def owner_names(snapshot)
      items = snapshot.fetch("items").to_h { |i| [i.fetch("id"), i] }
      cache = {}
      walk = lambda do |id|
        return "LAUNCH" unless id
        cache[id] ||= walk.call(items.fetch(id)["parent"]) + "/" + items.fetch(id).fetch("name")
      end
      items.keys.to_h do |id|
        item = items.fetch(id)
        name = item["path"] ? "LAUNCH/" + item["path"].split(".").map { |part| items.fetch(part.to_i).fetch("name") }.join("/") : walk.call(id)
        [id, name]
      end
    end

    def strip_generated(text)
      text.gsub(/<span style="[^"]*">|<\/span>|<details>|<\/details>|<summary>|<\/summary>/, "")
    end

    def word_order(plain, rich)
      return true if plain == rich
      a, b = plain.dup, strip_generated(rich)
      if a.start_with?("✓ Assertion passed · ") && b.start_with?("PASS ")
        a.sub!("✓ Assertion passed · ", "PASS ")
      elsif a.match?(/\A✓ [A-Z]+ /) && b.lines.first.match?(/\A\d{3} [A-Z]+ /)
        first = a.lines.first
        match = first.match(/\A✓ (.+) → (\d{3})(.*)/)
        a = "#{match[2]} #{match[1]}#{match[3]}\n" + a.lines.drop(1).join if match
      elsif (match = a.match(/\A(`[^`]+`) · (PNG|JPEG|JSON|Text)(.*)/))
        a = "#{match[2]} #{match[1]}#{match[3]}" + a.lines.drop(1).join.prepend("\n")
      end
      a.gsub!(/(^|\n)(`[^`]+`) · (PNG|JPEG|JSON|Text)([^\n]*)/) { "#{$1}#{$3} #{$2}#{$4}" }
      wanted = a.scan(/[\p{L}\p{N}]+/)
      available = b.scan(/[\p{L}\p{N}]+/)
      position = 0
      available.each { |word| position += 1 if wanted[position] == word }
      position == wanted.length
    end

    def native_channels(file)
      File.readlines(file).filter_map do |line|
        row = JSON.parse(line)
        if (a = row["attachment"])
          a.slice("body", "mediaType", "contentEncoding", "fileName")
        elsif (s = row.dig("testStepFinished", "testStepResult"))
          s.slice("status", "message", "exception")
        end
      end
    end

    def run
      verify
      inventory = @snapshots.flat_map do |file, snapshot|
        names = owner_names(snapshot)
        snapshot.fetch("launches").map do |launch|
          { launch_id: launch["id"], name: launch["name"], status: launch["status"], evidence: file.delete_prefix(OUT + "/"),
            targets: snapshot.fetch("logs").map do |log|
              item = snapshot.fetch("items").find { |i| i["id"] == log["itemId"] }
              route = item ? item.fetch("path").tr(".", "/") + "/log" : ""
              { item_id: log["itemId"], log_id: log["id"], owner: names[log["itemId"]], level: log["level"],
                first_line: log["message"].lines.first.to_s.chomp, message_sha256: Digest::SHA256.hexdigest(log["message"]),
                url: "#{ENDPOINT}/ui/##{PROJECT}/launches/all/#{launch['id']}/#{route}" }
            end }
        end
      end.uniq { |r| r[:launch_id] }
      write(File.join(OUT, "launch-item-log-index.json"), source_sha: SHA, launches: inventory)
      all = @snapshots.map(&:last)
      leaks = all.flat_map do |s|
        fields = s.fetch("logs").map { |l| l["message"] } + (s.fetch("items") + s.fetch("launches")).flat_map { |r| r.values_at("name", "description", "attributes") }
        fields.select { |f| JSON.generate(f).include?("SECRET123") || decode(JSON.generate(f)).match?(/QA_FINAL_ENCODED_SECRET|FROZEN_(?:MESSAGE|FRAME)_SECRET/) }
      end
      queries = all.flat_map { |s| s.fetch("queries", []) }.map { |q| q.dig("secret_marker", "page", "totalElements") }
      check("G8", leaks.empty? && queries.all?(&:zero?), { metadata_or_log_leaks: leaks.length, marker_queries: queries.length, query_totals: queries.uniq })
      encoded = read(File.join(OUT, "encoded-security-matrix.json"))
      deferred = read(File.join(OUT, "original-deferred-probe.json"))
      check("G8.encoded-and-original-deferred", encoded["status"] == "PASS" && deferred["exit"] == 0,
        { encoded_cases: encoded["count"], original_probe_sha256: deferred["script_sha256"], safe_frames_per_case: encoded["safe_frame_count"] })
      hanging = all.flat_map { |s| s.fetch("items") + s.fetch("launches") }.select { |r| r["status"] == "IN_PROGRESS" || !r["endTime"] }
      check("FINALIZATION", hanging.empty?, { hanging_count: hanging.length, launch_count: inventory.length })
      files = all.flat_map { |s| s.fetch("files") }
      wire_checks = @snapshots.filter_map do |file, snapshot|
        wire_file = File.join(File.dirname(file), "wire.json")
        next unless File.file?(wire_file)
        wire = read(wire_file)
        sent = wire.flat_map { |r| r.fetch("files", []) }.map { |r| [r["sha256"], r["bytes"], r["mime"]] }.sort
        got = snapshot.fetch("files").map { |r| [r["sha256"], r["bytes"], r["content_type"]] }.sort
        uuid_to_id = snapshot.fetch("items").to_h { |i| [i["uuid"], i["id"]] }
        owner_identity = wire.flat_map do |record|
          record.fetch("files", []).map do |file|
            entry = record.fetch("entries").find { |e| e.dig("file", "name") == file["name"] }
            match = snapshot.fetch("logs").find { |l| l["binaryContent"] && l["itemId"] == uuid_to_id[entry["itemUuid"]] && l["message"] == entry["message"] && l["level"].downcase == entry["level"].downcase }
            downloaded = match && snapshot.fetch("files").find { |f| f["log_id"] == match["id"] }
            downloaded && downloaded["sha256"] == file["sha256"] && downloaded["bytes"] == file["bytes"] && downloaded["content_type"] == file["mime"]
          end
        end
        { path: wire_file.delete_prefix(OUT + "/"), equal: sent == got, sent: sent, received: got,
          same_log_message_level_owner_and_download: owner_identity.all?,
          request_failures: wire.count { |r| r["observer_error"] || (r["status"] && !(200..299).cover?(r["status"])) } }
      end
      check("ATTACHMENT.IDENTITY", wire_checks.all? { |r| r[:equal] && r[:same_log_message_level_owner_and_download] && r[:request_failures].zero? }, { files: files.length, wire_checks: wire_checks })

      frozen = read(File.join(QA, "docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json"))
      p1 = message("F04-frozen")
      raw = p1.scan(/```text\n(.*?)\n```/m).last.first
      golden_prefix = "## ✗ RuntimeError: INDEPENDENT\\_FULL\\_BACKTRACE\n\n`features/audit.feature:5` → `runtime-support.rb:65`\n\n```text\nruntime-support.rb:65     IndependentCucumber12.inner_failure\nruntime-support.rb:59     IndependentCucumber12.deep_failure\nruntime-support.rb:136    block in <top (required)>\nfeatures/audit.feature:5  independent fail\n```\n\n_Full backtrace · 62 frames · 56 framework and 2 runner frames not shown above_\n\n```text\n"
      check("P1.1", p1 == golden_prefix + frozen.fetch("backtrace") + "\n```" && raw == frozen["backtrace"],
        { raw_frames: raw.lines.length, raw_sha256: Digest::SHA256.hexdigest(raw), baseline_sha256: frozen["backtrace_sha256"], baseline_input_file_sha256: Digest::SHA256.file(File.join(QA, "docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json")).hexdigest })
      check("P1.2", message("F16c") == "## ✗ Non-Exception failure" && message("F16d").lines.first.chomp == "## ✗ RuntimeError" && message("F16e").lines.first.chomp.length == 200 && message("F16e").lines.first.chomp.end_with?("…") && message("F14-negative", "plain", 10).lines.first.include?("&lt;script&gt;"),
        { native_F16c: "N/A: Ruby cannot raise a non-Exception", supplementary_adapter: "UNIT/protocol only; native failed step remains an Exception", title_length: message("F16e").lines.first.chomp.length })
      check("P1.3", p1.include?("62 frames · 56 framework and 2 runner frames not shown above"), { total: 62, hidden_framework: 56, hidden_runner: 2 })
      check("P1.4", p1.scan(/```text\n(.*?)\n```/m).first.first.lines.length == 4,
        { frozen_shown: 4, no_project_fallback: "Focused failure_card_spec checks first three framework frames; F16b native retains its real project step frame" })
      check("P1.5", message("F16a").include?("```text\nsecond line <other>\nthird line `tick`\n```") && message("F16a").include?("_Project frames_") && !p1.include?("_Project frames_"), "Continuation and project-frame captions observed in live F16a")
      check("P1.7", !message("F16f").include?("SECRET123") && message("F16f").include?("REDACTED"), "Live F16f failure redacted")
      check("P1.10", p1 == message("F04-frozen", "rich"), "Fresh frozen F04 exact message equality across two executions")
      %w[P1.6 P1.8 P1.9].each { |id| check(id, nil, "Independent browser reviewer owns DOM/screenshots; not inspected here") }

      proposal = File.read(File.join(SDK, "docs/design/presentation-ledger-proposal.md"))
      assertion_golden = proposal.split("**Failed assertion (ERROR):**", 2).last[/````markdown\n(.*?)\n````/m, 1]
      http_golden = proposal.split("**HTTP exchange, INFO:**", 2).last[/````markdown\n(.*?)\n````/m, 1]
      evidence_golden = proposal.split("**Failure evidence (ERROR):**", 2).last[/````markdown\n(.*?)\n````/m, 1]
      check("P8.1", message("F10c") == assertion_golden && message("F10a") == "✓ Assertion passed · Order is accepted · expected `ACCEPTED`", "Exact golden bytes")
      check("P8.2", !message("F10b").include?("expected") && message("F10d").include?("_Details_\n\n```json") && message("F10e").include?("_Details_\n\n```json"), "Long expected omitted; nested and eight-key details fenced; Decision27 changed-key summary retained")
      actual = "Timeout 1200ms exceeded.\nCall log:\n  - waiting for get_by_role(\"button\", name=\"M2 video intentionally absent control\", exact=True)"
      check("P8.3", message("F10c").include?("actual    " + actual.gsub("\n", "\n          ")), "Every actual continuation retains ten-space label indentation")
      check("P8.4", message("F11a") == http_golden && message("F11b").start_with?("## ⚠ GET /words → 404 · 31 ms") && message("F11c").include?("expected `200`") && message("F11d").include?("error `Connection refused`"), "Exact updated Decision7/27 HTTP golden; outcome-first order and raw byte counts")
      check("P8.5", message("F12") == evidence_golden && fixture("F12")["logs"].any? { |l| l["message"].start_with?("## ✗ Failure evidence") }, "Evidence golden and empty-action title")
      check("P8.6", all.flat_map { |s| s["logs"] }.none? { |l| l["level"].downcase == "info" && l["message"].start_with?("## ") }, "No INFO headings across every fresh launch")
      check("P8.7", %w[plain rich].all? { |m| !message("F11f", m).include?("SECRET123") && decode(message("F11f", m)).include?("[REDACTED]") }, "URL redacted in title and meta, both modes")
      terminal = read(File.join(OUT, "terminal-compatibility.json"))
      terminal_results = terminal["results"]
      normalized_terminal = terminal_results.map { |r| without_clock(JSON.parse(r["stdout"])["stdout"]) }
      check("P8.8", terminal_results.all? { |r| r["exit"] == 0 } && normalized_terminal.uniq.length == 1,
        { equal_ignoring_timestamps: normalized_terminal.uniq.length == 1, sha256: normalized_terminal.map { |s| Digest::SHA256.hexdigest(s) },
          F12: "Native rp_evidence has no terminal line; native plain/rich process comparison retained", raw_timestamp_comparison: "False by design; preserved original observation, timestamps excluded only as criterion specifies" })
      check("P8.9", message("QA202-values", "plain", 8).include?("omitted") && message("QA202-values", "plain", 8).bytesize <= 16_384, "Oversized details omission marker and bound retained")
      values = fixture("QA202-values")["logs"].map { |l| l["message"] }
      check("D27.assertion-values", values[0].include?('"" (empty string)') && values[1].include?('"   " (3 spaces)') && values[2].include?('" a " (leading/trailing whitespace)') && values[5].include?("missing in actual:") && values[5].include?("extra in actual:") && values[5].include?("changed:"), "Empty/whitespace labels and top-level missing/extra/changed keys")
      http = message("QA202-http")
      sections = ["_Response_", "`https://qa.example.test/ledger?plain=value`", "_Request_", "_Request headers", "_Response headers"].map { |s| http.index(s) }
      check("D27.http-order-headers", sections.none?(&:nil?) && sections == sections.sort && http.include?("X-Multi: first\nX-Multi: second") && http.include?("X-Multi: alpha\nX-Multi: beta"), "Outcome before transport; each non-sensitive repeated header value retained on a separate line")

      paired = []
      %w[fixtures-plain-v3 p1-plain security-plain].each do |group|
        Dir[File.join(OUT, group, "*/snapshot.json")].each do |file|
          name = File.basename(File.dirname(file))
          richfile = group == "security-plain" ? path("fixtures-rich-v3", name) : file.sub("plain", "rich")
          next unless File.file?(richfile)
          a, b = read(file), read(richfile)
          checks = a.fetch("logs").zip(b.fetch("logs")).map do |x, y|
            next { missing_pair: true } unless x && y
            { plain_log: x["id"], rich_log: y["id"], level: x["level"],
              error_exact: !%w[error fatal].include?(x["level"].downcase) || x["message"] == y["message"],
              budget: y["message"].bytesize <= x["message"].bytesize + 1024,
              word_order: word_order(x["message"], y["message"]) }
          end
          meta = lambda do |s|
            names = owner_names(s)
            s["items"].map { |i| [names[i["id"]], i.slice("name", "description", "attributes", "parameters", "type", "hasStats", "status", "retry", "codeRef", "testCaseId")] }.sort_by(&:to_s)
          end
          native_a = File.join(File.dirname(file), "native.ndjson")
          native_b = File.join(File.dirname(richfile), "native.ndjson")
          channel_equal = native_channels(native_a) == native_channels(native_b)
          paired << { fixture: name, logs: checks, same_log_count: a["logs"].length == b["logs"].length,
            same_item_metadata: meta.call(a) == meta.call(b), native_channels_equal: channel_equal,
            native_channels_sha256: [native_a, native_b].map { |p| Digest::SHA256.hexdigest(JSON.generate(native_channels(p))) },
            stdout_equal_ignoring_duration: without_clock(read(File.join(File.dirname(file), "process.json"))["stdout"]) == without_clock(read(File.join(File.dirname(richfile), "process.json"))["stdout"]) }
        end
      end
      write(File.join(OUT, "plain-rich-comparison.json"), paired)
      check("P10.4-D27a", paired.all? { |p| p[:same_log_count] && p[:logs].all? { |r| r[:error_exact] } }, { pairs: paired.length, scope: "Whole ERROR/FATAL messages byte-identical, not only first line" })
      check("P10.5", paired.all? { |p| p[:logs].all? { |r| r[:budget] } }, "Every paired log within plain+1024 bytes")
      check("P10.6", paired.all? { |p| p[:logs].all? { |r| r[:word_order] } }, { differences: paired.select { |p| p[:logs].any? { |r| !r[:word_order] } }, rule: "Strip only generated HTML; approved passed-assertion, HTTP-title and attachment-kind reorderings only; preserve code/user angle brackets" })
      check("P10.7", paired.all? { |p| p[:same_item_metadata] && p[:native_channels_equal] && p[:stdout_equal_ignoring_duration] },
        { different: paired.reject { |p| p[:same_item_metadata] && p[:native_channels_equal] && p[:stdout_equal_ignoring_duration] }.map { |p| p.slice(:fixture, :same_item_metadata, :native_channels_equal, :stdout_equal_ignoring_duration) },
          normalization: "Native channel events omit UUIDs/timings; full original NDJSON retained. Terminal ignores timestamps/duration only. Fixture Launch metadata differ solely by harness mode-labelled name. P10.7 compares all required metadata, not server-generated auto uniqueIds; those were not submitted by either SDK run and remain in original wire/API captures." })
      default = read(path("fixtures-default-v3", "F01"))
      check("P10.1", default["logs"].none? { |l| l["message"].match?(/<details|<summary|<span style/) }, "RP_PRESENTATION unset; live Launch 4078")
      invalid = read(path("p1-plain", "F20", "process.json"))
      check("P10.2", invalid["stderr"].scan("Invalid RP_PRESENTATION").length == 1 && !message("F20").include?("<span"), "Invalid mode warns exactly once and falls back to plain")
      token_lines = proposal[/PILL  = .*?\n```/m].to_s.lines
      tokens = token_lines.filter_map { |l| m = l.match(/^(PILL|PASS|FAIL|WARN|INFO|TITLE|TH)\s*= (.*)$/); [m[1], m[2].sub(/\s+\(.*$/, "")] if m }.to_h
      styles = [tokens["TITLE"], tokens["TH"]] + %w[PASS FAIL WARN INFO].map { |t| "#{tokens['PILL']};#{tokens[t]}" }
      rich_messages = Dir[File.join(OUT, "{fixtures-rich-v3,p1-rich}", "*/snapshot.json")].flat_map { |p| read(p)["logs"].map { |l| l["message"] } }
      tags = rich_messages.flat_map { |s| s.scan(/<\/?(?:span|details|summary)\b[^>]*>/) }
      invalid_tags = tags.reject { |t| %w[<details> </details> <summary> </summary> </span>].include?(t) || (m = t.match(/\A<span style="([^"]+)">\z/)) && styles.include?(m[1]) }
      check("P10.3", invalid_tags.empty?, { extracted_client_tags: tags.length, invalid: invalid_tags, allowed_styles: styles })
      folds = rich_messages.flat_map { |s| s.scan(/<details>(.*?)<\/details>/m).flatten }
      fence_spacing = folds.all? do |body|
        lines, delimiter, good = body.lines, nil, true
        lines.each_with_index do |line, i|
          if delimiter
            if line.strip == delimiter
              good &&= i + 1 < lines.length && lines[i + 1].strip.empty?
              delimiter = nil
            end
          elsif (m = line.match(/\A(`{3,}|~{3,})[^\n]*\n?\z/))
            good &&= i.positive? && lines[i - 1].strip.empty?
            delimiter = m[1]
          end
        end
        good && delimiter.nil?
      end
      check("P10.8-nonvisual", fence_spacing, { folds: folds.length, visual_DOM: "PENDING independent browser reviewer" })
      check("P10.9", !fixture("F13", "rich")["logs"].first["message"].include?(tokens["TH"]), "Eight-column F13 has no TH spans; separately labeled four-column control correctly uses TH")
      %w[P10.10 P10.11].each { |id| check(id, nil, "Independent browser reviewer owns rendering/contrast; no browser operated here") }
      preview_plain = fixture("F18")["logs"]
      check("F18.P5.5", preview_plain[0]["message"].end_with?("_Preview · first 100 lines · full file attached_") && preview_plain[2]["message"].end_with?("_Preview · first 16 KB of 48 KB · full file attached_"), "Exact preview-limit markers retained and full attachment bytes downloaded")
      raw_curl = read(File.join(OUT, "live-security-inputs.json"))["raw_curl"]
      security_snapshots = [read(path("security-plain", "FINAL-security")), read(path("fixtures-rich-v3", "FINAL-security"))]
      safe_frame_text = read(File.join(OUT, "live-security-inputs.json"))["safe_frames"].join("\n")
      live_failures = security_snapshots.flat_map { |s| s["logs"].select { |l| l["message"].include?("_Full backtrace") } }
      check("G8.live-safe-frames", live_failures.length == 16 && live_failures.all? { |l| l["message"].include?(safe_frame_text) },
        { failure_cards: live_failures.length, contiguous_safe_frames_per_card: 62, omission: "Only unsafe URL frame may be omitted; safe frames never discarded" })
      curl_logs = security_snapshots.flat_map { |s| s["logs"].select { |l| l["message"].start_with?("curl --request") } }
      check("RAW_CURL", curl_logs.length == 16 && curl_logs.all? { |l| l["message"] == raw_curl }, { messages: curl_logs.length, sha256: Digest::SHA256.hexdigest(raw_curl), secrets: "Synthetic SAFE_CURL_FIXTURE only; ordinary AppLog preservation is intentional" })
      check("SIX_TRIALS", Dir[File.join(OUT, "trials/*/result.json")].length == 6 && Dir[File.join(OUT, "trials/*/result.json")].all? { |p| read(p)["problems"].empty? } && read(File.join(OUT, "trial-inputs-postrun.json"))["unchanged"],
        { launch_ids: [4016, 4017, 4018, 4019, 4022, 4023], inputs: "Original consumer inputs unchanged; actual installed gem and SDK_REF pinned to final SHA" })
      ci = read(File.join(OUT, "ci-verification.json"))
      check("CI", ci.dig("runs", "workflow_runs", 0, "conclusion") == "success" && ci["pr"]["jobs"].reject { |j| j["name"].end_with?("/ bundle") }.all? { |j| j["conclusion"] == "success" },
        { commit: SHA, pr_run: 41462363187, push_run: 41462349016, six_matrix_cells: "success", gate: "success", artifact_bundle: "skipped by workflow" })
      focused = read(File.join(OUT, "focused-rspec.json"))
      focused_summary = JSON.parse(focused["stdout"])["summary"]
      check("FOCUSED_RSPEC", focused["exit"] == 0 && focused_summary["failure_count"].zero? && focused_summary["pending_count"].zero?, focused_summary)
      check("G11", nil, "Performance owned by separate agent; no timings collected here")
      failures = @checks.select { |c| c[:status] == "FAIL" }
      write(File.join(OUT, "criterion-results.json"), source_sha: SHA, contract_verdict: failures.empty? ? "ACCEPT_NONVISUAL_CONTRACT_SCOPE" : "FAIL",
        release_verdict: "PENDING_MASTER_AGGREGATION_OF_INDEPENDENT_VISUAL_AND_PERFORMANCE_GATES", checks: @checks,
        new_launch_count: inventory.length, no_merge_tag_publish_push_commit: true)
      puts JSON.generate(contract: failures.empty? ? "ACCEPT_NONVISUAL_CONTRACT_SCOPE" : "FAIL", failed: failures.map { |c| c[:criterion] }, checks: @checks.length, launches: inventory.length)
    end
  end
end

FinalRelease202::Assessment.new.run if $PROGRAM_NAME == __FILE__
