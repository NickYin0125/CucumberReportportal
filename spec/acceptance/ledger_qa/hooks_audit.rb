# frozen_string_literal: true

require_relative "analyze"

module LedgerQAAnalysis
  class HookStudy < Study
    def paths(snapshot, hooks: true)
      @native_names ||= {}
      directory = snapshot.fetch("_directory")
      input = File.join(directory, "inputs.ndjson")
      descriptors = File.file?(input) ? File.readlines(input).map { |line| JSON.parse(line) }.select { |row| row["kind"] == "native_hook_descriptor" } : []
      mapping = descriptors.to_h { |row| [row.fetch("generic_text"), row.fetch("native_name")] }
      if mapping.empty? && File.file?(File.join(directory, "native.ndjson"))
        native = File.readlines(File.join(directory, "native.ndjson")).filter_map { |line| JSON.parse(line)["hook"] }
        if native.length == 1 && !native.first["name"].to_s.empty? && snapshot["items"].count { |item| item["type"] == "BEFORE_METHOD" } == 1
          mapping["Before hook"] = native.first["name"]
        end
      end
      snapshot.fetch("items").each do |item|
        plain = Study.instance_method(:hook_name).bind_call(self, item)
        mapping.each do |generic, name|
          desired = "#{generic} \u00b7 #{name}"
          @native_names[item["id"]] = desired if [generic, desired].include?(plain)
        end
      end
      super
    end

    def hook_name(item)
      @native_names&.fetch(item["id"], nil) || super
    end
  end
end

stamp = ARGV.fetch(0, "20261031T180948Z")
def snapshot(path)
  value = JSON.parse(File.read(File.join(path, "snapshot.json"))).merge("_directory" => path)
  root = path[/\A(\/Users\/nick\/Documents\/crr-qa-(?:2\.0\.1|1\.3\.2))/ , 1]
  if root && path.include?("20261031T180948Z")
    id = value.fetch("launches").first.fetch("id")
    supplement = "#{root}/docs/reviews/assets/ledger-qa-retry-read-20261031T180948Z/launch-#{id}.json"
    if File.file?(supplement)
      proof = JSON.parse(File.read(supplement))
      raise "Unverified retry expansion" unless proof["verdict"] == "PASS" && proof["source_snapshot_sha256"] == Digest::SHA256.file(File.join(path, "snapshot.json")).hexdigest
      direct = proof.fetch("validations").to_h { |row| [row.fetch("direct_item").fetch("id"), row.fetch("direct_item")] }
      value["items"] = value.fetch("items").map { |item| direct.fetch(item.fetch("id"), item) }
      value["_retry_read_supplement"] = supplement
    end
  end
  value
end

%w[2.0.1 1.3.2].each do |version|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  study = LedgerQAAnalysis::HookStudy.new(root, stamp)
  checks = []
  record = lambda do |id, label, expected, actual, current, passed = nil, note = nil|
    passed = expected == actual if passed.nil?
    checks << { criterion: id, check: label, inputs: current["_directory"].delete_prefix(root + "/"), expected: expected, actual: actual,
      evidence: study.refs(current), verdict: passed ? "PASS" : "FAIL", note: note }
  end
  runtimes = version == "1.3.2" ? %w[9.2.1 10.2.0] : ["12.0.1"]
  runtimes.each do |cucumber|
    prefix = "#{root}/docs/reviews/assets/ledger-qa-live/#{stamp}-hooks-#{cucumber}"
    baseline = %w[native retry].to_h { |kind| [kind, snapshot("#{prefix}-baseline/F15-hooks-#{kind}")] }
    %w[plain rich].each do |mode|
      2.times do |index|
        repeat = index + 1
        %w[native retry fault].each do |kind|
          current = snapshot("#{prefix}-#{mode}-#{repeat}/F15-hooks-#{kind}")
          directory = current.fetch("_directory")
          inputs = File.readlines(File.join(directory, "inputs.ndjson")).map { |line| JSON.parse(line) }
          process = JSON.parse(File.read(File.join(directory, "process.json")))
          guard = JSON.parse(File.read(File.join(directory, "source-guard.json")))
          record.call("G1", "#{cucumber}/#{mode}/#{repeat}/#{kind} loaded-source guard", true, guard["passed"], current)
          record.call("P6.1", "#{cucumber}/#{mode}/#{repeat}/#{kind} native process complete without timeout", [0, false, nil], process.values_at("exit", "timed_out", "signal"), current)
          wanted = ["Before hook \u00b7 Open browser", "AfterStep hook \u00b7 Inspect step", "After hook \u00b7 Close browser"]
          wanted[0] = "Before Hook: Before hook" if kind == "fault"
          wanted *= 2 if kind == "retry"
          hook_items = current["items"].select { |item| %w[BEFORE_METHOD AFTER_METHOD].include?(item["type"]) }
          record.call(kind == "fault" ? "G9" : "P6.1", "#{cucumber}/#{mode}/#{repeat}/#{kind} exact hook display names", wanted.sort, hook_items.map { |item| item["name"] }.sort, current,
            wanted.sort == hook_items.map { |item| item["name"] }.sort, kind == "fault" ? "Controlled getter fault must restore exact original Before Hook: Before hook baseline label, not Tier 1." : "Ordinary native named hooks, not an event replay.")
          completion = inputs.select { |row| row["kind"] == "hook_metadata_after_complete_native_run" }
          record.call("P6.1", "#{cucumber}/#{mode}/#{repeat}/#{kind} metadata cleared at actual native completion", true,
            !completion.empty? && completion.all? { |row| row["entries"] == 0 && row["cache_present"] && row["finalized"] }, current)
          descriptor = inputs.select { |row| row["kind"] == "native_hook_descriptor" }.map { |row| row.values_at("generic_text", "native_name") }.sort
          record.call("P6.1", "#{cucumber}/#{mode}/#{repeat}/#{kind} native hook descriptor names independently recorded", [["Before hook", "Open browser"], ["After hook", "Close browser"], ["AfterStep hook", "Inspect step"]].sort, descriptor, current)
          record.call("G9", "#{cucumber}/#{mode}/#{repeat}/#{kind} warning count", kind == "fault" ? 1 : 0,
            process["stderr"].scan("ReportPortal presentation failed; using baseline format").length, current)
          if kind != "fault"
            old = baseline.fetch(kind)
            record.call("G1", "#{cucumber}/#{mode}/#{repeat}/#{kind} full baseline Item contract with native-name normalization", study.contract(old), study.contract(current), current)
            record.call("G2", "#{cucumber}/#{mode}/#{repeat}/#{kind} per-owner baseline levels/counts", study.log_counts(old), study.log_counts(current), current)
            record.call("G3", "#{cucumber}/#{mode}/#{repeat}/#{kind} attachment owner/name/MIME/bytes/hash contract", study.attachment_owners(old), study.attachment_owners(current), current)
          end
          if kind == "retry"
            cases = current["items"].select { |item| item["hasStats"] && item["parent"] && item["type"] == "STEP" }.sort_by { |item| item["id"] }
            record.call("P6.1", "#{cucumber}/#{mode}/#{repeat} real retry preserves failed then passed attempts", %w[FAILED PASSED], cases.map { |item| item["status"] }, current)
            after = cases.map do |scenario|
              hook = hook_items.find { |item| item["parent"] == scenario["id"] && item["name"] == "AfterStep hook \u00b7 Inspect step" }
              [hook && hook["status"], hook && current["logs"].count { |log| log["itemId"] == hook["id"] }]
            end
            record.call("P6.1", "#{cucumber}/#{mode}/#{repeat} first AfterStep skipped/no log, successful retry logged", [["SKIPPED", 0], ["PASSED", 1]], after, current)
            record.call("P6.1", "#{cucumber}/#{mode}/#{repeat} exactly two actual business attempts", [1, 2], inputs.select { |row| row["kind"] == "native_business_attempt" }.map { |row| row["attempt"] }, current)
          end
          if repeat == 2
            first = snapshot("#{prefix}-#{mode}-1/F15-hooks-#{kind}")
            record.call("G4", "#{cucumber}/#{mode}/#{kind} exact messages/descriptions/names repeat", [study.messages(first), study.metadata(first)], [study.messages(current), study.metadata(current)], current)
          end
        end
      end
    end
    # All previously failing before-only F15 names and unchanged companion
    # messages/After-hook files are checked independently of new fixture shapes.
    %w[plain rich].each do |mode|
      2.times do |index|
        directory = "#{prefix}-companions-#{mode}-#{index + 1}"
        current = snapshot("#{directory}/F15-named")
        record.call("P6.1", "#{cucumber}/#{mode}/#{index + 1} original F15 named regression", ["Before hook \u00b7 Open browser"],
          current["items"].select { |item| item["type"] == "BEFORE_METHOD" }.map { |item| item["name"] }, current)
        unless cucumber == "9.2.1"
          %w[F04 F15 F15-named F15-negative].each do |fixture|
            old = snapshot("#{root}/docs/reviews/assets/ledger-qa-live/20261031T072147Z-#{mode}-#{index + 1}/#{fixture}")
            fresh = snapshot("#{directory}/#{fixture}")
            record.call("G1", "#{cucumber}/#{mode}/#{index + 1}/#{fixture} other native wire contract unchanged by hook fix", study.contract(old), study.contract(fresh), fresh)
            record.call("G2", "#{cucumber}/#{mode}/#{index + 1}/#{fixture} other log owner/level/message bytes unchanged", study.messages(old), study.messages(fresh), fresh)
            record.call("G3", "#{cucumber}/#{mode}/#{index + 1}/#{fixture} exact owned filename/MIME/bytes/SHA unchanged", study.attachment_owners(old), study.attachment_owners(fresh), fresh)
          end
        end
      end
    end
  end
  if version == "2.0.1"
    %w[plain rich].each do |mode|
      2.times do |index|
        old_path = "#{root}/docs/reviews/assets/ledger-qa-live/20261031T072147Z-parallel-#{mode}-#{index + 1}"
        new_path = "#{root}/docs/reviews/assets/ledger-qa-live/#{stamp}-hooks-12.0.1-parallel-#{mode}-#{index + 1}"
        old, current = [old_path, new_path].map { |path| snapshot(path) }
        record.call("G1", "F06 four native workers #{mode}/#{index + 1} Item contract unchanged", study.contract(old), study.contract(current), current)
        record.call("G2", "F06 #{mode}/#{index + 1} per-owner messages unchanged", study.messages(old), study.messages(current), current)
        record.call("G3", "F06 #{mode}/#{index + 1} attachments cannot swap equal-sized Step owners", study.attachment_owners(old), study.attachment_owners(current), current)
      end
    end
  end
  output = "#{root}/docs/reviews/assets/ledger-qa-hooks-audit-#{version}.json"
  File.write(output, JSON.pretty_generate(checks) + "\n")
  puts JSON.generate(version: version, checks: checks.length, failures: checks.select { |row| row[:verdict] == "FAIL" }.map { |row| [row[:criterion], row[:check], row[:evidence][:launch_ids]] })
end
