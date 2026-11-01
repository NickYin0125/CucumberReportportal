# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "fileutils"
require_relative "final_wp5_context"

stamp = LedgerWP5Context.stamp
central = File.join("/Users/nick/Documents/crr-qa-2.0.1/docs/reviews/assets", stamp)
captures = File.readlines(File.join(central, "ui-captures.ndjson")).map { |line| JSON.parse(line) }
judgments = File.readlines(File.join(central, "ui-judgments.ndjson")).map { |line| JSON.parse(line) }.to_h { |row| [row.fetch("slug"), row] }
LedgerWP5Context.heads.each do |version, head|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  shots = captures.select { |entry| entry.fetch("line") == version }.map do |entry|
    raise "Wrong screenshot runtime" unless entry["runtime_sha"] == head
    source = File.join(root, entry.fetch("source_snapshot"))
    snapshot = JSON.parse(File.read(source))
    raise "Screenshot is not from this attempt's owned Launch" unless source.include?("/ledger-qa-live/#{stamp}-") &&
      snapshot.fetch("launches").any? { |launch| launch["id"] == entry["launch_id"] } &&
      (entry["log_ids"] - snapshot.fetch("logs").map { |log| log["id"] }).empty?
    jpg = entry.fetch("source_jpg")
    png = jpg.sub(/\.jpg\z/, ".png")
    unless File.file?(png)
      stdout, stderr, result = Open3.capture3("/usr/bin/sips", "-s", "format", "png", jpg, "--out", png)
      raise "Screenshot format conversion failed: #{stdout} #{stderr}" unless result.success?
    end
    header = File.binread(png, 24)
    dimensions = header.byteslice(16, 8).unpack("NN")
    raise "Screenshot viewport differs" unless header.start_with?("\x89PNG\r\n\x1a\n".b) && dimensions == [1100, 780]
    judgment = judgments[entry.fetch("slug")]
    entry.merge("path" => png.delete_prefix(root + "/"), "source_jpg" => jpg.delete_prefix(root + "/"),
      "png_sha256" => Digest::SHA256.file(png).hexdigest, "jpg_sha256" => Digest::SHA256.file(jpg).hexdigest,
      "png_dimensions" => dimensions, "verdict" => judgment ? judgment.fetch("verdict") : "BLOCKED",
      "independent_judgment" => judgment,
      "conversion" => "Original browser JPEG retained; format conversion only, with no resizing, crop, annotation or pixel editing.")
  end
  File.write(File.join(root, "docs/reviews/assets", stamp, "screenshots.json"), JSON.pretty_generate(shots) + "\n")
  puts JSON.generate(version: version, screenshots: shots.length, verdicts: shots.group_by { |shot| shot["verdict"] }.transform_values(&:length))
end
