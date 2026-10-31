# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "fileutils"
require "set"

module LedgerQAAnalysis
  class Study
    attr_reader :root, :version, :checks
    def initialize(root, stamp)
      @root, @stamp = root, stamp
      @version = root.end_with?("1.3.2") ? "1.3.2" : "2.0.1"
      @checks = []
      @complete = Set.new
    end

    def read(relative)
      JSON.parse(File.read(File.join(root, relative)))
    end

    def run(mode, repeat = 1)
      suffix = %w[baseline default-batch1].include?(mode) ? mode : "#{mode}-#{repeat}"
      Dir[File.join(root, "docs/reviews/assets/ledger-qa-live/#{@stamp}-#{suffix}/*/snapshot.json")].sort.filter_map do |path|
        if mode == "baseline"
          guard_path = File.join(File.dirname(path), "source-guard.json")
          next unless File.file?(guard_path) && JSON.parse(File.read(guard_path))["passed"]
        end
        value = JSON.parse(File.read(path))
        value["_directory"] = File.dirname(path)
        [File.basename(File.dirname(path)), value]
      end.to_h
      .tap do |fixtures|
        parallel = File.join(root, "docs/reviews/assets/ledger-qa-live/#{@stamp}-parallel-#{suffix}/snapshot.json")
        if File.file?(parallel)
          value = JSON.parse(File.read(parallel))
          value["_directory"] = File.dirname(parallel)
          fixtures["F06"] = value
        end
      end
    end

    def refs(snapshot)
      return { launch_ids: [], item_ids: [], log_ids: [] } unless snapshot
      { launch_ids: snapshot.fetch("launches", []).map { |l| l["id"] },
        item_ids: snapshot.fetch("items", []).map { |i| i["id"] },
        log_ids: snapshot.fetch("logs", []).map { |l| l["id"] },
        source: snapshot["_directory"].delete_prefix(root + "/") + "/snapshot.json" }
    end

    def check(id, label, expected, actual, snapshot: nil, passed: expected == actual, method: "L", inputs: nil, note: nil)
      checks << { criterion: id, check: label, method: method, inputs: inputs, expected: expected, actual: actual,
                  verdict: passed ? "PASS" : "FAIL", evidence: refs(snapshot), note: note }
    end

    def blocked(id, reason, inputs: nil)
      checks << { criterion: id, check: reason, method: nil, inputs: inputs, expected: "Required acceptance evidence", actual: nil,
                  verdict: "BLOCKED", evidence: refs(nil), note: reason }
    end

    def logs(snapshot)
      snapshot.fetch("logs", []).sort_by { |l| [l.fetch("time"), l.fetch("id")] }
    end

    def hook_name(item)
      name = item.fetch("name")
      return name unless %w[BEFORE_METHOD AFTER_METHOD BEFORE_CLASS AFTER_CLASS].include?(item["type"])
      match = name.match(/\A(Before Hook|After Hook|Before All Hook|After All Hook|Hook): (.*)\z/m)
      return name unless match
      prefix, base = match.captures
      label = if base.match?(/\Aafter\s*step\s*hook\z/i) then "AfterStep hook"
              elsif item["type"] == "BEFORE_CLASS" then "BeforeAll hook"
              elsif item["type"] == "AFTER_CLASS" then "AfterAll hook"
              elsif prefix == "Before Hook" then "Before hook"
              elsif prefix == "After Hook" then "After hook"
              else "Hook" end
      unnamed = base.match?(/\A\s*(before|after|after\s*step|before\s*all|after\s*all|around)?\s*hook\s*\z/i)
      unnamed ? label : "#{label} \u00b7 #{base}"
    end

    def paths(snapshot, hooks: true)
      items = snapshot.fetch("items", [])
      by_id = items.to_h { |item| [item.fetch("id"), item] }
      raise "Duplicate item IDs in captured tree" unless by_id.length == items.length
      memo, siblings, segments, visiting = {}, Hash.new(0), {}, Set.new
      items.each do |item|
        name = hooks ? hook_name(item) : item["name"]
        # codeRef disambiguates identical Outline display names without erasing
        # the codeRef itself from the comparison.
        name = "#{name} [#{item['codeRef']}]" if item["hasStats"] && item["codeRef"]
        key = [item["parent"], name]
        ordinal = siblings[key]
        siblings[key] += 1
        segments[item["id"]] = "#{name}##{ordinal}"
      end
      resolve = lambda do |id|
        return memo[id] if memo.key?(id)
        raise "Cycle in captured item tree" if visiting.include?(id)
        item = by_id.fetch(id)
        parent_id = item["parent"]
        raise "Captured non-root item has a missing parent" if parent_id && !by_id.key?(parent_id)
        visiting.add(id)
        parent = resolve.call(parent_id) if parent_id
        memo[id] = [parent, segments.fetch(id)].compact.join(" / ")
        visiting.delete(id)
        memo[id]
      end
      items.each { |item| resolve.call(item.fetch("id")) }
      memo
    end

    def submitted_attachments(snapshot)
      locations = paths(snapshot)
      items = snapshot.fetch("items").to_h { |item| [item["uuid"], item] }
      JSON.parse(File.read(File.join(snapshot["_directory"], "wire.json"))).flat_map do |request|
        next [] unless request["method"] == "POST" && request["path"].end_with?("/log")
        entries = request["entries"] || request["json"]
        Array(entries).filter_map do |entry|
          next unless entry["file"]
          parts = request.fetch("files", []).select { |file| file["name"] == entry.dig("file", "name") }
          raise "Unresolvable multipart filename" unless parts.length == 1
          owner = items[entry["itemUuid"]]
          raise "Wire attachment has an unknown owning item" if entry["itemUuid"] && !owner
          part = parts.first
          { "owner" => owner ? locations.fetch(owner["id"]) : "Launch", "item_id" => owner && owner["id"],
            "name" => part["name"], "mime" => part["mime"], "bytes" => part["bytes"], "sha256" => part["sha256"],
            "message" => entry["message"], "level" => entry["level"], "http_status" => request["status"] }
        end
      end
    end

    def attachment_owners(snapshot, names: true)
      locations = paths(snapshot)
      submitted = submitted_attachments(snapshot)
      log_by_id = snapshot.fetch("logs").to_h { |log| [log["id"], log] }
      snapshot.fetch("files", []).map do |file|
        log = log_by_id.fetch(file.fetch("log_id"))
        raise "Readback attachment/log owner mismatch" unless file["item_id"] == log["itemId"]
        owner = locations.fetch(log["itemId"], "Launch")
        candidates = submitted.select do |entry|
          entry["owner"] == owner && entry["message"] == log["message"] && entry["level"] == log["level"] &&
            entry["mime"] == file["content_type"] && entry["bytes"] == file["bytes"] && entry["sha256"] == file["sha256"]
        end
        signatures = candidates.map { |entry| entry.values_at("name", "mime", "bytes", "sha256") }.uniq
        raise "Ambiguous or absent attachment wire/readback join" unless signatures.length == 1
        [owner, names ? signatures.first.first : "<unnamed filename change allowed by P5>", file["content_type"], file["bytes"], file["sha256"]]
      end.sort
    end

    def contract(snapshot)
      locations = paths(snapshot)
      fields = %w[type hasStats status retry testCaseId uniqueId codeRef parameters attributes]
      records = JSON.parse(File.read(File.join(snapshot["_directory"], "wire.json")))
      posted = records.select { |r| r["method"] == "POST" && r["path"].match?(%r{/item(?:/[^/]+)?$}) }
        .to_h { |r| [r.dig("response", "id"), r["json"]] }
      snapshot.fetch("items", []).map do |item|
        entry = { "path" => locations[item["id"]], "parent_path" => locations[item["parent"]], "name" => hook_name(item) }
          .merge(fields.to_h { |f| [f, item[f]] })
        body = posted[item["uuid"]]
        if item["uniqueId"].to_s.start_with?("auto:") && body && !body.key?("uniqueId")
          entry["uniqueId"] = "<server-generated UUID-derived auto identity; client omission unchanged>"
        end
        entry
      end.sort_by { |i| i["path"] }
    end

    def log_counts(snapshot)
      locations = paths(snapshot)
      snapshot.fetch("items", []).to_h { |i| [locations[i["id"]], logs(snapshot).select { |l| l["itemId"] == i["id"] }.map { |l| l["level"] }] }
    end

    def messages(snapshot)
      locations = paths(snapshot)
      logs(snapshot).map { |l| [locations[l["itemId"]] || "Launch", l["level"], l["message"]] }.sort
    end

    def metadata(snapshot)
      locations = paths(snapshot)
      snapshot.fetch("items", []).map { |i| [locations[i["id"]], i["name"], i["description"]] }.sort_by(&:first)
    end

    def normalized_native(path)
      data = File.readlines(path).map { |l| JSON.parse(l) }
      ids = {}
      rewrite = lambda do |value|
        case value
        when Hash
          value.to_h do |k, v|
            [k, %w[timestamp duration start finish].include?(k) ? "<runtime-clock>" : rewrite.call(v)]
          end
        when Array then value.map { |v| rewrite.call(v) }
        when String
          value.gsub(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i) { |id| ids[id] ||= "<generated-id-#{ids.length}>" }
        else value
        end
      end
      rewrite.call(data)
    end

    def contract_checks(plain, rich, baseline)
      %w[plain rich].zip([plain, rich]).each do |mode, runs|
        baseline.each do |fixture, old|
          next unless (current = runs[fixture])
          next if fixture.start_with?("F19") && fixture != "F19d"
          [old, current].each do |tree|
            check("G1", "#{fixture} recursive parent graph is complete and acyclic", tree.fetch("items").length,
              paths(tree).length, snapshot: tree, method: "C",
              note: "Every non-root parent must exist; recursive resolution rejects cycles and does not assume parent-before-child retrieval order.")
          end
          check("G1", "#{fixture} #{mode} item tree", contract(old), contract(current), snapshot: current, method: "C", inputs: refs(old))
          check("G2", "#{fixture} #{mode} per-item levels/counts", log_counts(old), log_counts(current), snapshot: current, method: "C", inputs: refs(old))
          expected = old.fetch("files", []).map { |f| f.values_at("content_type", "bytes", "sha256") }.sort
          actual = current.fetch("files", []).map { |f| f.values_at("content_type", "bytes", "sha256") }.sort
          check("G3", "#{fixture} #{mode} downloaded attachment bytes/MIME/count", expected, actual, snapshot: current, method: "C", inputs: refs(old))
          check("G3", "#{fixture} #{mode} attachment owner path + filename + MIME + bytes + SHA256",
            attachment_owners(old, names: fixture != "F17"), attachment_owners(current, names: fixture != "F17"),
            snapshot: current, method: "C", inputs: refs(old),
            note: "Downloaded file logId -> log.itemId -> recursively normalized owner; filename joined to captured wire by the same owner/message/level/MIME/size/hash. Detects swaps between equally populated Steps.")
          old_wire = JSON.parse(File.read(File.join(old["_directory"], "wire.json")))
          new_wire = JSON.parse(File.read(File.join(current["_directory"], "wire.json")))
          expected_names = old_wire.flat_map { |w| w.fetch("files", []).map { |f| f["name"] } }.sort
          actual_names = new_wire.flat_map { |w| w.fetch("files", []).map { |f| f["name"] } }.sort
          check("G3", "#{fixture} #{mode} explicit attachment filenames", expected_names, actual_names, snapshot: current, method: "C") unless fixture == "F17"
          names = ->(s) { s["items"].reject { |i| %w[BEFORE_METHOD AFTER_METHOD BEFORE_CLASS AFTER_CLASS].include?(i["type"]) }.map { |i| [paths(s)[i["id"]], i["name"]] }.sort }
          check("P2.4", "#{fixture} #{mode} raw non-hook names", names.call(old), names.call(current), snapshot: current, method: "C")
          scenarios = ->(s) { s["items"].select { |i| i["hasStats"] && i["type"] == "STEP" }.map { |i| i.values_at("codeRef", "name", "parameters") }.sort_by { |v| v[0].to_s } }
          check("P4.4", "#{fixture} #{mode} raw scenario names/parameters", scenarios.call(old), scenarios.call(current), snapshot: current, method: "C")
          hooks = ->(s) { s["items"].select { |i| %w[BEFORE_METHOD AFTER_METHOD BEFORE_CLASS AFTER_CLASS].include?(i["type"]) }.map { |i| [paths(s)[i["id"]], i["type"]] }.sort }
          check("P6.2", "#{fixture} #{mode} hook types", hooks.call(old), hooks.call(current), snapshot: current, method: "C")
        end
      end
      %w[plain rich].each do |mode|
        first, second = run(mode), run(mode, 2)
        first.each do |fixture, observed|
          next unless fixture.match?(/\AF(?:0[1-9]|1[0-8])/) && second[fixture]
          check("G4", "#{fixture} #{mode} messages and metadata repeat", [messages(observed), metadata(observed)], [messages(second[fixture]), metadata(second[fixture])], snapshot: observed, inputs: refs(second[fixture]))
        end
      end
      plain.each do |fixture, p|
        next unless (r = rich[fixture])
        check("P10.7", "#{fixture} unchanged item metadata plain/rich", metadata(p), metadata(r), snapshot: r, method: "C", inputs: refs(p))
        pm = p.fetch("launches").map { |l| l.values_at("description", "attributes") }
        rm = r.fetch("launches").map { |l| l.values_at("description", "attributes") }
        check("P10.7", "#{fixture} unchanged Launch metadata plain/rich", pm, rm, snapshot: r, method: "C")
        pl, rl = logs(p), logs(r)
        pl.zip(rl).each_with_index do |(left, right), index|
          next unless right
          check("P10.4", "#{fixture} ERROR #{index} first line", left["message"].lines.first, right["message"].lines.first, snapshot: r, inputs: { plain_log_id: left["id"], rich_log_id: right["id"] }) if left["level"] == "error"
          check("P10.5", "#{fixture} log #{index} rich byte budget", "<= #{left['message'].bytesize + 1024} bytes", right["message"].bytesize, passed: right["message"].bytesize <= left["message"].bytesize + 1024, snapshot: r, inputs: { plain_log_id: left["id"], rich_log_id: right["id"] })
        end
        ndp, ndr = [p, r].map { |s| File.join(s["_directory"], "native.ndjson") }
        if File.file?(ndp) && File.file?(ndr)
          left, right = normalized_native(ndp), normalized_native(ndr)
          check("G12", "#{fixture} native NDJSON diff (generated IDs and clocks normalized)", left, right, method: "U", snapshot: r, inputs: [ndp, ndr])
          check("G12", "#{fixture} native HTML has no Tier 2 token", [], File.read(File.join(r["_directory"], "native.html")).scan(/<details|<summary|<span style/), method: "U", snapshot: r)
        end
      end
    end

    def global_checks(plain, rich, baseline)
      (plain.to_a + rich.to_a + run("default-batch1").to_a).each do |fixture, snapshot|
        snapshot.fetch("queries", []).each do |query|
          check("G5", "#{fixture} API forbidden-prefix filter", 0, query.dig("forbidden_prefix", "page", "totalElements"), snapshot: snapshot)
          check("G8", "#{fixture} API secret-marker filter", 0, query.dig("secret_marker", "page", "totalElements"), snapshot: snapshot)
        end
        check("G7", "#{fixture} forbidden-token scan", [], logs(snapshot).filter_map do |l|
          hits = l["message"].scan(/<style|url\(|position:| class=| id=|<img|<svg|javascript:|\son[a-z]+=/i)
          { log_id: l["id"], hits: hits } unless hits.empty?
        end, snapshot: snapshot)
        texts = snapshot.fetch("items").map { |i| i.slice("name", "description", "attributes") } + snapshot.fetch("launches").map { |l| l.slice("description", "attributes") }
        check("G8", "#{fixture} complete nested-message secret-marker scan", [], logs(snapshot).select { |l| l["message"].include?("SECRET123") }.map { |l| l.slice("id", "itemId", "message") }, snapshot: snapshot)
        check("G5", "#{fixture} complete nested-message forbidden-prefix scan", [], logs(snapshot).select { |l| l["message"].include?("!!!MARKDOWN_MODE!!!") }.map { |l| l.slice("id", "itemId") }, snapshot: snapshot)
        check("G8", "#{fixture} metadata secret-marker scan", false, JSON.generate(texts).include?("SECRET123"), snapshot: snapshot)
        check("P8.6", "#{fixture} INFO headings", [], logs(snapshot).select { |l| l["level"] == "info" && l["message"].start_with?("## ") }.map { |l| l["id"] }, snapshot: snapshot)
      end
      plain.each do |fixture, snapshot|
        old = baseline[fixture]
        next unless old
        old_text = old ? logs(old).map { |l| l["message"] }.join("\n") : ""
        hits = logs(snapshot).flat_map do |l|
          l["message"].scan(/<\/?[a-zA-Z][^>]*>/).map do |tag|
            { log_id: l["id"], token: tag, classification: tag == "<br>" ? "owner-approved client line break" : (old_text.include?(tag) ? "baseline-existing literal input" : "NEW") }
          end
        end
        check("G6", "#{fixture} every plain HTML hit classified", [], hits.select { |h| h[:classification] == "NEW" }, snapshot: snapshot, inputs: hits)
      end
    end

    def feature_checks(plain, rich, baseline)
      return if plain.empty?
      fetch = ->(fixture) { logs(plain.fetch(fixture)) }
      if (s = plain["F01"])
        messages = logs(s).map { |l| l["message"] }
        golden = ["`visible-fixture.png` \u00b7 PNG \u00b7 640 \u00d7 360 \u00b7 5.3 KB",
                  "`visible-fixture.txt` \u00b7 Text \u00b7 2 lines \u00b7 71 B\n\n```text\nVisible synthetic plain-text acceptance fixture.\nSecond line retained.\n```",
                  "`visible-fixture.json` \u00b7 JSON \u00b7 75 B\n\n```json\n{\n  \"source\": \"independent acceptance\",\n  \"synthetic\": true,\n  \"values\": [1, true, null]\n}\n```"]
        check("P5.1", "F01 exact three caption/preview goldens", golden, messages, snapshot: s)
      end
      if (s = plain["F04"])
        error = logs(s).find { |l| l["level"] == "error" }
        caption = logs(s).find { |l| l["binaryContent"] }
        check("P5.2", "F04 exact JPEG caption", "`after-failure.jpg` \u00b7 JPEG \u00b7 754 \u00d7 790 \u00b7 36 KB", caption && caption["message"], snapshot: s)
        owner = s["items"].find { |i| i["id"] == caption&.fetch("itemId") }
        check("P6.3", "F04 JPEG belongs to After hook", ["AFTER_METHOD", "After hook"], owner && owner.values_at("type", "name"), snapshot: s, method: "C")
        if error
          tail = error["message"].split(/_Full backtrace[^\n]*_\n\n/).last.to_s.sub(/\A```text\n/, "").sub(/\n```\z/, "")
          if (old = baseline["F04"])
            old_error = logs(old).find { |l| l["level"] == "error" }
            check("P1.1", "F04 raw baseline tail preserved", old_error["message"].split("\n", 2).last, tail, snapshot: s, inputs: refs(old))
          end
          count = error["message"][/Full backtrace \u00b7 (\d+) frames/, 1].to_i
          check("P1.3", "F04 tail frame total", tail.lines.length, count, snapshot: s)
        end
        if (again = run("plain", 2)["F04"])
          first = ->(x) { logs(x).find { |l| l["level"] == "error" }["message"].split("_Full backtrace").first }
          check("P1.10", "F04 stable card before tail caption", first.call(s), first.call(again), snapshot: s)
        end
      end
      { "F16d" => "## \u2717 RuntimeError" }.each do |fixture, golden|
        next unless (s = plain[fixture])
        check("P1.2", "#{fixture} empty message title", golden, logs(s).find { |l| l["level"] == "error" }["message"].lines.first.chomp, snapshot: s)
      end
      if (s = plain["F16e"])
        title = logs(s).find { |l| l["level"] == "error" }["message"].lines.first.chomp
        check("P1.2", "F16e title bound and ellipsis", [200, true], [title.length, title.end_with?("\u2026")], snapshot: s)
      end
      if (s = plain["F16a"])
        text = logs(s).find { |l| l["level"] == "error" }["message"]
        check("P1.5", "F16a continuation fenced before labelled project frames", true, text.include?("```text\nsecond line <other>\nthird line `tick`\n```\n\n_Project frames_"), snapshot: s)
        check("P3.2", "F16a raw continuation fence", true, text.include?("```text\nsecond line <other>\nthird line `tick`\n```"), snapshot: s)
      end
      if (s = plain["F16f"])
        check("P1.7", "F16f redacted error", false, logs(s).any? { |l| l["message"].include?("SECRET123") }, snapshot: s)
      end
      if (s = plain["F13"])
        check("P7.2", "F13 eight-column alignment golden", true, logs(s).any? { |l| l["message"].include?("| --- | --: | --: | --: | --: | --- | --- | --- |") }, snapshot: s)
        if (r = rich["F13"])
          first_table = logs(r).find { |l| l["message"].include?("| account |") }
          check("P10.9", "F13 eight-column table has no TH span", false, first_table && first_table["message"].include?("text-transform:uppercase"), snapshot: r)
        end
      end
      if (s = plain["F07"])
        actions = s["items"].select { |i| i["type"] == "STEP" && !i["hasStats"] }
        check("P7.3", "F07 all fifty argument-free steps omit descriptions", [50, []], [actions.length, actions.filter_map { |i| i["description"] unless i["description"].to_s.empty? }], snapshot: s)
      end
      if (s = plain["F10a"])
        check("P8.1", "F10a exact passed assertion", ["\u2713 Assertion passed \u00b7 Order is accepted \u00b7 expected `ACCEPTED`"], logs(s).map { |l| l["message"] }, snapshot: s)
      end
      if (s = plain["F10c"])
        message = logs(s).first["message"]
        golden = "## \u2717 Assertion failed \u00b7 Intentionally absent Typewords control can be clicked\n\n```text\nexpected  click succeeds\nactual    Timeout 1200ms exceeded.\n          Call log:\n            - waiting for get_by_role(\"button\", name=\"M2 video intentionally absent control\", exact=True)\n```\n\n_Details_ `api_key` = `[REDACTED]` \u00b7 `recording` = `Playwright viewport recording is still active`"
        check("P8.1", "F10c exact failed assertion golden", golden, message, snapshot: s)
        check("P8.3", "F10c multiline actual continuation", true, message.include?("actual    Timeout 1200ms exceeded.\n          Call log:\n            - waiting"), snapshot: s)
      end
      if (s = plain["F10b"])
        check("P8.2", "F10b long expected omitted from chip", false, logs(s).first["message"].include?("expected `"), snapshot: s)
      end
      %w[F10d F10e].each do |fixture|
        next unless (s = plain[fixture])
        check("P8.2", "#{fixture} non-inline details use JSON fence", true, logs(s).first["message"].include?("_Details_\n\n```json\n"), snapshot: s)
      end
      { "F11b" => "## \u26a0 GET /words \u2192 404 \u00b7 31 ms", "F11c" => "## \u2717 GET /words \u2192 500 \u00b7 31 ms" }.each do |fixture, golden|
        next unless (s = plain[fixture])
        check("P8.4", "#{fixture} HTTP title", golden, logs(s).first["message"].lines.first.chomp, snapshot: s)
      end
      if (s = plain["F11c"])
        check("P8.4", "F11c expected-status meta", true, logs(s).first["message"].include?("expected `200`"), snapshot: s)
      end
      if (s = plain["F11d"])
        check("P8.4", "F11d connection-error meta", true, logs(s).first["message"].include?("error `Connection refused`"), snapshot: s)
      end
      if (s = plain["F11f"])
        text = logs(s).first["message"]
        check("P8.7", "F11f secret removed from title and URL chip", [false, true], [text.include?("SECRET123"), text.include?("[REDACTED]") || text.include?("%5BREDACTED%5D")], snapshot: s)
      end
      if (s = plain["F12"])
        artifacts = logs(s).select { |l| l["binaryContent"] && !l["message"].start_with?("Caller") }
        check("P5.4", "F12 failure-evidence suffix", true, artifacts.all? { |l| l["message"].lines.first.chomp.end_with?(" \u00b7 failure evidence") }, snapshot: s)
        caller = logs(s).find { |l| l["message"].start_with?("Caller") }
        check("P5.3", "F12 caller message precedes meta line", true, caller && caller["message"].start_with?("Caller **Markdown** stays authored\n\n`caller-message.png`"), snapshot: s)
        check("P8.5", "F12 empty action card title", true, logs(s).any? { |l| l["message"].start_with?("## \u2717 Failure evidence\n") }, snapshot: s)
        check("P3.2", "F12 raw evidence message fenced", true, logs(s).first["message"].include?("```text\nTimeout 1200ms exceeded.\nCall log:"), snapshot: s)
      end
      if (s = plain["F18"])
        messages = logs(s).map { |l| l["message"] }
        check("P5.5", "F18 line truncation caption", true, messages.any? { |m| m.end_with?("_Preview \u00b7 first 100 lines \u00b7 full file attached_") }, snapshot: s)
        check("P5.5", "F18 byte truncation caption", true, messages.any? { |m| m.end_with?("_Preview \u00b7 first 16 KB of 48 KB \u00b7 full file attached_") }, snapshot: s)
      end
      context_checks(plain)
    end

    def context_checks(plain)
      %w[a b c d].each do |letter|
        next unless (s = plain["F19#{letter}"])
        launch = s["launches"].first
        if letter == "d"
          check("P9.1", "F19d no generated context", ["", []], launch.values_at("description", "attributes"), snapshot: s)
        else
          probe = JSON.parse(File.read(File.join(File.dirname(s["_directory"]), "probe.json")))
          runtime = JSON.parse(probe["stdout"])
          attrs = { "sdk" => letter == "b" ? "custom" : version, "cucumber" => runtime["cucumber"], "ruby" => runtime["ruby_version"], "git.branch" => "feature/ledger", "git.sha" => "e7dae2b", "ci.build" => "42" }
          attrs["workers"] = "4" if version == "2.0.1"
          check(letter == "b" ? "P9.3" : "P9.2", "F19#{letter} exact context attributes", attrs.sort, launch["attributes"].map { |a| a.values_at("key", "value") }.sort, snapshot: s)
          expected_description = "Cucumber #{runtime['cucumber']} \u00b7 Ruby #{runtime['ruby_version']} \u00b7 " + (version == "2.0.1" ? "4 workers \u00b7 " : "") + "feature/ledger@e7dae2b"
          expected_description = "Given description" if letter == "c"
          check("P9.4", "F19#{letter} context description", expected_description, launch["description"], snapshot: s)
        end
      end
    end

    def execute
      plain, rich, baseline = run("plain"), run("rich"), run("baseline")
      contract_checks(plain, rich, baseline)
      global_checks(plain, rich, baseline)
      feature_checks(plain, rich, baseline)
      write_result
    end

    def write_result
      criteria = File.readlines(File.join(root, "docs/design/presentation-ledger-acceptance.md")).filter_map do |line|
        match = line.match(/^\| ((?:G|V)\d+|P\d+\.\d+) \| (MUST|SHOULD) \| (.+?) \|/)
        next unless match
        id, level, requirement = match.captures
        observations = checks.select { |c| c[:criterion] == id }
        verdict = if observations.empty? then "BLOCKED"
                  elsif observations.any? { |c| c[:verdict] == "FAIL" } then "FAIL"
                  elsif observations.any? { |c| c[:verdict] == "BLOCKED" } then "BLOCKED"
                  elsif @complete.include?(id) then "PASS"
                  else "BLOCKED" end
        { id: id, level: level, requirement: requirement, verdict: verdict, checks: observations }
      end
      File.write(File.join(root, "docs/reviews/assets/presentation-ledger-#{version}-acceptance.json"), JSON.pretty_generate(
        schema: "independent-ledger-acceptance/1", status: "IN_PROGRESS_NOT_A_RELEASE_VERDICT", version: version,
        tester: "Independent Ledger QA", run_stamp: @stamp, criteria: criteria, checks: checks) + "\n")
      puts JSON.generate(version: version, observed_checks: checks.length, failures: checks.select { |c| c[:verdict] == "FAIL" }.map { |c| [c[:criterion], c[:check]] })
    end
  end
end

if $PROGRAM_NAME == __FILE__
  LedgerQAAnalysis::Study.new(File.expand_path("../../..", __dir__), ARGV.fetch(0)).execute
end
