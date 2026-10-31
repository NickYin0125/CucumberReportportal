# frozen_string_literal: true

require "json"
require "digest"
require "time"

%w[2.0.1 1.3.2].each do |version|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  path = File.join(root, "docs/reviews/assets/ledger-qa-screenshots-#{version}.json")
  rows = JSON.parse(File.read(path))
  rows.each do |row|
    row["mode"] = row["source_snapshot"].include?("-rich-") ? "rich" : "plain"
    row["context_item_id"] = row["url"][/\/(\d+)(?:\/log)?(?:\?|\z)/, 1]&.to_i
    row["judged_on"] = "2026-11-01 Asia/Shanghai"
    absolute = ->(value) { value.start_with?("/") ? value : File.join(root, value) }
    row["capture_date_utc"] = File.mtime(absolute.call(row["source_jpg"])).utc.iso8601(6)
    row["png_sha256"] = Digest::SHA256.file(absolute.call(row["png"])).hexdigest
    row["png_dimensions"] = File.binread(absolute.call(row["png"]), 24).byteslice(16, 8).unpack("NN")
    %w[source_snapshot source_jpg png].each { |key| row[key] = row[key].delete_prefix(root + "/") }
    row["visual_verdict"] = row["slug"].include?("scope-blocked") ? "HISTORICAL_BLOCKED_NOT_EXIT_EVIDENCE" : "PASS"
    if row["slug"].start_with?("S09")
      fixture = row["slug"].split("-")[1]
      row["criteria"] = { "f10a" => ["P8.1", "P8.6"], "f10c" => ["P8.1", "P8.3"],
        "f11a" => ["P8.4", "P8.6"], "f11b" => ["P8.4"], "f11c" => ["P8.4"], "f12" => ["P8.5"] }.fetch(fixture)
      row["criteria"] << "P10.10" if row["mode"] == "rich"
      row["note"] = "Action step expanded and card header/meta visible. Some long bodies retain RP's default outer fold; fold expansion and content are separately evidenced in S03."
    end
    if row["slug"] == "S06-download-gallery"
      row["visual_verdict"] = "PASS_DOWNLOAD_CONTROL_ONLY"
      row["note"] = "Native gallery Download control visible; image itself was still loading in this capture. Do not use as preview proof; S06-preview-modal separately proves the loaded image. Timestamped click and actual saved file evidence are retained."
    end
    if row["slug"] == "S10-launch-context-chips"
      row["context_item_id"] = nil
      row["item_scope_note"] = "Launch list, not an Item detail view"
    end
  end
  File.write(path, JSON.pretty_generate(rows) + "\n")
  puts JSON.generate(version: version, screenshots: rows.length, required_groups: rows.map { |row| row["slug"][0, 3] }.uniq.sort)
end
