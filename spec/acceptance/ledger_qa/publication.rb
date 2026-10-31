# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "time"

version, action = ARGV
abort "usage: publication.rb VERSION verify|guide" unless %w[2.0.1 1.3.2].include?(version) && %w[verify guide].include?(action)
root = "/Users/nick/Documents/crr-qa-#{version}"
assets = File.join(root, "docs/reviews/assets")
prefix = "presentation-ledger-#{version}"
groups = %w[live checks matrix]
manifests = groups.to_h do |group|
  path = File.join(assets, "#{prefix}-#{group}-raw.manifest.json")
  [group, JSON.parse(File.read(path))]
end
verification_path = File.join(assets, "#{prefix}-archive-verification.json")

if action == "verify"
  results = manifests.map do |group, manifest|
    archive = File.join(root, manifest.fetch("archive").fetch("path"))
    digest = Digest::SHA256.file(archive).hexdigest
    raise "Archive checksum differs" unless digest == manifest.dig("archive", "sha256")
    raise "Archive entry set was not checked" unless manifest.dig("archive", "entry_set_verified")
    checked = 0
    Open3.popen3("tar", "-xOJf", archive) do |input, output, error, process|
      input.close
      output.binmode
      error_reader = Thread.new { error.read }
      manifest.fetch("entries").each do |entry|
        remaining = entry.fetch("bytes")
        hash = Digest::SHA256.new
        while remaining.positive?
          buffer = output.read([remaining, 1024 * 1024].min)
          raise "Archive ended before #{entry['path']}" unless buffer && !buffer.empty?
          remaining -= buffer.bytesize
          hash.update(buffer)
        end
        raise "Restored bytes differ: #{entry['path']}" unless hash.hexdigest == entry.fetch("sha256")
        checked += 1
      end
      raise "Unindexed bytes in archive" if output.read(1)
      raise "Archive decompression failed" unless process.value.success?
      raise "Archive emitted unexpected warnings" unless error_reader.value.empty?
    end
    { group: group, archive: manifest["archive"], verified_file_count: checked,
      verified_uncompressed_bytes: manifest["uncompressed_bytes"], every_restored_file_sha256_matches: true }
  end
  File.write(verification_path, JSON.pretty_generate(schema: "qa-archive-restoration-proof/1", version: version,
    checked_at_utc: Time.now.utc.iso8601, method: "Stream actual decompressed entry bytes in manifest order, hash every file, reject truncation/extra bytes; no SDK checkout is extracted.",
    results: results) + "\n")
  puts JSON.generate(version: version, archives: results.length, files_verified: results.sum { |row| row[:verified_file_count] }, verdict: "PASS")
  exit
end

verification = JSON.parse(File.read(verification_path))
raise "Incomplete restoration verification" unless verification.fetch("results").length == 3 && verification["results"].all? { |row| row["every_restored_file_sha256_matches"] }
data = JSON.parse(File.read(File.join(assets, "#{prefix}-acceptance.json")))
raise "Not all criteria adjudicated" unless data.fetch("criteria").length == 84
raise "Pending decisions were silently changed" unless data["criteria"].select { |row| row["verdict"] == "BLOCKED" }.map { |row| row["id"] }.sort == %w[P10.6 V7]
raise "Evidence has an input gap" unless data.fetch("checks").all? { |check| !check["inputs"].nil? }
report_path = File.join(root, "docs/reviews/2026-11-01-#{prefix}-acceptance.md")
decisions = File.read(File.join(root, "docs/design/presentation-ledger-acceptance.md")).split(/^## Decisions\s*$/, 2).last
quoted_decisions = decisions.lines.map { |line| line.chomp.empty? ? ">" : "> #{line.chomp}" }.join("\n")
raise "Owner decisions were not retained verbatim" unless File.read(report_path).include?(quoted_decisions)

rows = manifests.map do |group, manifest|
  archive = manifest.fetch("archive")
  "| #{group} | [archive](#{File.basename(archive['path'])}) | [SHA256 manifest](#{prefix}-#{group}-raw.manifest.json) | #{manifest['file_count']} | #{manifest['uncompressed_bytes']} | #{archive['bytes']} |"
end
guide = <<~MD
  # Ledger #{version} Evidence Guide

  Final sign-off date: 2026-11-01 Asia/Shanghai. Status: **BLOCKED**, not ACCEPT.
  [Acceptance report](../2026-11-01-#{prefix}-acceptance.md) and [84-criterion check index](#{prefix}-acceptance.json).
  All eight owner Decisions are reproduced verbatim in the report. P10.6 and V7 remain unanswered, not waived.

  ## Contents
  Reports, indexed exact expected/actual checks, all S01-S12 PNGs, UI/DOM/download provenance and QA harness are plain files.
  Raw outputs are losslessly compressed, not discarded. Each manifest lists every original path, byte count and SHA256.
  [Restoration proof](#{prefix}-archive-verification.json) hashes the actual decompressed bytes of every archived file.

  | Group | Download | Index | Files | Raw bytes | Compressed bytes |
  | --- | --- | --- | --- | --- | --- |
  #{rows.join("\n")}

  `live` retains wire requests, HTTP receipts, per-item API/download snapshots and fresh readbacks, native NDJSON/HTML and stdout for every independent run, including original invalid baseline captures.
  `checks` retains offline/fault/performance outputs and original browser JPEG capture bytes; any environment logs and supplied historical failure records are labelled separately.
  `matrix` retains full RSpec/Cucumber JSON/stdout, runtime/source provenance and exact scratch dependency text inputs for all completed, failed, invalid or superseded cells.
  The long `source/docs/reviews/assets/qa-cell-evidence` prefix in matrix archives is an artifact path only: no copied SDK source tree is included.
  SDK mirrors, nested `.git`, caches, Docker config, runtime working copies and temporary gem/chart/package binaries are excluded. Local untracked originals remain available; exclusions are not hidden product changes.

  ## Restore
  From a fresh checkout of this QA branch, run these commands at its repository root:

  ```sh
  tar -xJf docs/reviews/assets/#{prefix}-live-raw.tar.xz -C .
  tar -xJf docs/reviews/assets/#{prefix}-checks-raw.tar.xz -C .
  tar -xJf docs/reviews/assets/#{prefix}-matrix-raw.tar.xz -C .
  ```

  Entry paths are repository-relative. Report/screenshot links resolve directly; raw source references resolve after extraction.
  Original absolute locations in historical provenance are not rewritten. Map `/Users/nick/Documents/crr-qa-#{version}/` to the checkout root when resolving such artifact paths. Frozen stack frames, authored strings and original process arguments are **data**, not links; preserve those bytes unchanged.
  Baseline/SDK source locations refer to the recorded Git commits, not omitted evidence. Inspect them from the repository history without treating copied source caches as deliverables.

  To repeat the lossless archive validation without extraction:

  ```sh
  /opt/homebrew/opt/ruby/bin/ruby spec/acceptance/ledger_qa/publication.rb #{version} verify
  ```

  This machine's helper uses the recorded QA root; on another machine, change only that helper's root mapping, not payloads or test expectations.
  In the acceptance JSON, each criterion's `check_ids` indexes the full top-level `checks` table. `inputs.captured_source` plus `selection`, SHA256 and native IDs points to exact retained raw input records. No expected/actual assertion values were removed by indexing.

  ## Provenance And Limitations
  Candidate: `#{data['candidate_head']}`. Baseline: `#{data['baseline_head']}`. The final six-cell stamp is `final-hooks-20261101`; product counts are 1345/1402 plus 16 QA properties per cell, not a selected subset.
  Earlier `final-fixed-20261031` and `final-p88-20261101` matrices are superseded, not final-head proof. Early setup/recorder failures and the interrupted terminal-repair cell are retained without product-failure or PASS claims.
  Baselines from `20261031T065500Z` are **UNUSABLE** because they loaded candidate source from Cucumber's current-directory load path. Corrected `20261031T072147Z` captures include loaded-source guards.
  F04 uses an API-verified historical 62-frame input replay (Launch 76/item 1365/log 1118), not a naturally generated current stack. No-project, non-Exception and metadata-getter fault shapes are explicitly controlled inputs. Current native stacks are retained separately.
  The original final-hook GET audit's 15 retry item mismatches remain intact. Separate direct retry readback verifies API-nested attempt IDs, true parents/UUIDs/lineage, closed states and exact expanded item/log sets; this is not a topology waiver.
  Decision 8 applies only to the six named 1.x NUL-preview attachment baseline losses, using submitted baseline wire and complete candidate download. The unchanged native raw-NUL user-log persistence limitation remains explicit. The baseline F16f SECRET123 probe hit is not a candidate secret leak.
  Genuine Console screenshots use ordinary native message search, not Markdown-off. UI download proof uses the real saved filename/bytes, not response headers alone. Master's review/archival instructions are not owner waivers.
  G11 remains an open S3 SHOULD timing failure; cosmetic Examples metadata wrapping is also S3, while each required key/value chip is one physical line. P2.1/P8.8/P6.1 original S2 evidence and repaired retests are both preserved.
  Historical live runners are retained as reviewed commands, including explicitly invalid/superseded versions. Do not blindly re-execute them: they intentionally pin the tested SDK heads, require secure Master-only environment injection, and create new Launches. No credentials are committed.
MD
guide_path = File.join(assets, "#{prefix}-evidence.md")
File.write(guide_path, guide)

plain = [report_path, guide_path, verification_path]
plain.concat(Dir[File.join(root, "spec/acceptance/ledger_qa/*")].select { |path| File.file?(path) })
plain << File.join(root, "features/presentation_ledger/f04_frozen.feature")
plain.concat(Dir[File.join(assets, "ledger-qa-*.json")].reject { |path| File.basename(path).start_with?("ledger-qa-checkpoint") })
plain.concat(Dir[File.join(assets, "ledger-qa-frozen-input/*.json")])
plain.concat(Dir[File.join(assets, "ledger-qa-retry-read-*/*.json")])
plain.concat(Dir[File.join(assets, "run-ledger-qa-*.sh")])
plain.concat(Dir[File.join(assets, "#{prefix}/*.png")])
plain.concat(Dir[File.join(assets, "#{prefix}/downloads/*.png")])
plain.concat(Dir[File.join(assets, "#{prefix}-acceptance.json")])
groups.each do |group|
  %w[files.txt manifest.json tar.xz].each { |suffix| plain << File.join(assets, "#{prefix}-#{group}-raw.#{suffix}") }
end
plain = plain.uniq.sort
raise "Selected path is missing" unless plain.all? { |path| File.file?(path) }
selected = plain.map { |path| path.delete_prefix(root + "/") }
archived = manifests.values.flat_map { |manifest| manifest.fetch("entries").map { |entry| entry.fetch("path") } }
available = (selected + archived).to_h { |path| [path, true] }
unresolved = []
data["checks"].each do |check|
  Array(check.dig("evidence", "source")).each do |source|
    next unless source.is_a?(String) && source.include?("docs/reviews/assets/")
    relative = source.delete_prefix(root + "/")
    unresolved << relative unless available[relative]
  end
end
shots = JSON.parse(File.read(File.join(assets, "ledger-qa-screenshots-#{version}.json")))
shots.each do |shot|
  %w[png source_jpg source_snapshot].each { |key| unresolved << shot[key] unless available[shot[key]] }
  raise "PNG bytes changed" unless Digest::SHA256.file(File.join(root, shot["png"])).hexdigest == shot["png_sha256"]
end
raise "Unresolved published evidence: #{unresolved.uniq.first(10).inspect}" unless unresolved.empty?
[report_path, guide_path].each do |path|
  File.read(path).scan(/\]\(([^)]+)\)/).flatten.each do |link|
    next if link.match?(%r{\A(?:https?://|#)})
    target = File.expand_path(link.split("#").first, File.dirname(path))
    raise "Unresolved document link: #{link}" unless File.file?(target)
  end
end
index_path = File.join(assets, "#{prefix}-publication-manifest.json")
list_path = File.join(assets, "#{prefix}-stage.files.txt")
index = { schema: "qa-publication-selection/1", version: version, verdict: "BLOCKED", checked_at_utc: Time.now.utc.iso8601,
  criteria: data["criteria"].group_by { |row| row["verdict"] }.transform_values(&:length),
  pending_owner: %w[P10.6 V7], owner_decisions_sha256: Digest::SHA256.hexdigest(decisions),
  linked_artifacts_available_after_extraction: true, source_mirrors_or_caches_selected: false,
  note: "This index and the stage path list are self-describing, not recursively SHA-indexed. Raw entries have separate full SHA manifests. Scratch originals and generated working copies remain local/untracked.",
  files: plain.map { |path| { path: path.delete_prefix(root + "/"), bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest } } }
File.write(index_path, JSON.pretty_generate(index) + "\n")
selected.concat([index_path, list_path].map { |path| path.delete_prefix(root + "/") }).sort!
File.write(list_path, selected.join("\n") + "\n")
puts JSON.generate(version: version, selected_files: selected.length, selected_bytes: selected.sum { |path| File.size(File.join(root, path)) },
  largest: plain.sort_by { |path| -File.size(path) }.first(5).map { |path| [path.delete_prefix(root + "/"), File.size(path)] }, unresolved_links: unresolved.length)
