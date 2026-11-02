# frozen_string_literal: true

require "json"
require "digest"
require "time"
require "open3"

ROOT = File.expand_path(__dir__)
STAGE = ARGV.fetch(0)
raise "Expected before or after" unless %w[before after].include?(STAGE)
EDITABLE = %w[api-review.md recheck-checklist.md].freeze

def read_json(name)
  JSON.parse(File.read(File.join(ROOT, name)))
end

def records(name)
  pages = read_json(name)
  content = pages.flat_map { |page| page.fetch("content") }
  raise "Incomplete saved pagination: #{name}" unless content.size == pages.first.fetch("page").fetch("totalElements")
  content
end

manifest = read_json("evidence-sha256.json")
changed = []
manifest.fetch("files").each do |entry|
  path = entry.fetch("path")
  raise "Manifest escapes own review folder" unless path.start_with?(ROOT + "/")
  raise "Missing saved file: #{File.basename(path)}" unless File.file?(path)
  changed << File.basename(path) unless Digest::SHA256.file(path).hexdigest == entry.fetch("sha256")
end
unexpected = STAGE == "before" ? changed : changed - EDITABLE
raise "Unexpected saved-file changes: #{unexpected.join(', ')}" unless unexpected.empty?

verification = read_json("verification.json")
log_index = {}
launches = verification.fetch("launches").map do |expected|
  id = expected.fetch("id")
  items = records("items-#{id}.json")
  ids = items.map { |item| item.fetch("id") }
  raise "Duplicate saved item" unless ids.uniq.size == ids.size
  raise "Wrong item count" unless items.size == expected.fetch("item_count")
  count = 0
  items.each do |item|
    raise "Missing parent" if item["parent"] && !ids.include?(item["parent"])
    records("logs-#{item.fetch('id')}.json").each do |log|
      raise "Log assigned to wrong item" unless log.fetch("itemId") == item.fetch("id")
      raise "Duplicate saved log" if log_index.key?(log.fetch("id"))
      log_index[log.fetch("id")] = log
      count += 1
    end
  end
  raise "Wrong log count" unless count == expected.fetch("log_count")
  {id: id, items: items.size, logs: count}
end

critical = {21110 => 31695, 21111 => 31695, 21302 => 31845, 21303 => 31845,
            21120 => 31700, 21121 => 31700, 21312 => 31850, 21313 => 31850,
            20959 => 31587, 20960 => 31587, 20961 => 31587,
            21012 => 31626, 21211 => 31779, 20968 => 31595, 21178 => 31758,
            21129 => 31710, 21130 => 31711}
critical.each { |log_id, item_id| raise "Critical reference mismatch" unless log_index.fetch(log_id).fetch("itemId") == item_id }
verification.fetch("exact_plain_rich_error_comparisons").each do |pair|
  a = log_index.fetch(pair.fetch("plain_log")).fetch("message")
  b = log_index.fetch(pair.fetch("rich_log")).fetch("message")
  raise "ERROR message comparison changed" unless a.b == b.b && Digest::SHA256.hexdigest(a) == pair.fetch("plain_sha256")
end

captures = read_json("ui-captures.json")
captures.each do |capture|
  %w[jpg ax.txt].each do |suffix|
    raise "Missing indexed UI evidence" unless File.file?(File.join(ROOT, "#{capture.fetch('name')}.#{suffix}"))
  end
end
images = Dir.glob(File.join(ROOT, "*.jpg")).sort
dimensions, _stderr, status = Open3.capture3("/usr/bin/sips", "-g", "pixelWidth", "-g", "pixelHeight", *images)
raise "Image metadata inspection failed" unless status.success?
widths = dimensions.scan(/pixelWidth: (\d+)/).flatten.map(&:to_i)
heights = dimensions.scan(/pixelHeight: (\d+)/).flatten.map(&:to_i)
raise "Unexpected image dimensions" unless widths.size == images.size && heights.size == images.size && widths.uniq == [1504] && heights.uniq == [710]

report = File.read(File.join(ROOT, "api-review.md"))
links = report.scan(/\]\((\/[^)]+)\)/).flatten.map { |path| path.sub(/:\d+(?::\d+)?$/, "") }
own_links = links.select { |path| path.start_with?(ROOT + "/") }
target = STAGE == "before" ? "offline-baseline-validation.json" : "offline-validation.json"
target_path = File.join(ROOT, target)
own_links.each { |path| raise "Missing own-folder report reference" unless path == target_path || File.file?(path) }

receipt = {
  validated_at: Time.now.utc.iso8601, stage: STAGE, offline_only: true,
  network_calls: 0, browser_actions: 0, new_captures: 0, test_executions: 0,
  baseline_manifest_sha256: Digest::SHA256.file(File.join(ROOT, "evidence-sha256.json")).hexdigest,
  baseline_files_checked: manifest.fetch("files").size, changed_baseline_files: changed,
  unexpected_changes: unexpected, launches: launches, total_logs: log_index.size,
  critical_log_item_references_checked: critical.size, exact_error_pairs_checked: 4,
  indexed_captures_checked: captures.size, screenshot_files_checked: images.size,
  screenshot_dimensions: [1504, 710],
  unindexed_overview_images: images.map { |path| File.basename(path) } - captures.map { |capture| "#{capture.fetch('name')}.jpg" },
  own_folder_report_links_checked: own_links.size,
  external_source_links: "Not reopened in this offline completion; prior source excerpts retained in verification.json",
  live_evidence_head: "9bf3356cff350d8e2ba11bad1c33aa89881ac456",
  final_source_head: "d1725d3ab9e796c008fe9e80a11ea0ce29bde762",
  head_equivalence: "Master attests runtime/examples/Gemfile/gemspec identical; changes limited to CI and one integration assertion. Not independently inspected or rerun.",
  pending: ["Native HTML visual check remains unverified under the earlier browser policy block", "No current RP health/recovery verification; live access requires Master clearance"],
  conclusions: "Prior usability dispositions unchanged; outage neither assessed nor certified",
  report_sha256: Digest::SHA256.file(File.join(ROOT, "api-review.md")).hexdigest,
  checklist_sha256: Digest::SHA256.file(File.join(ROOT, "recheck-checklist.md")).hexdigest
}
if STAGE == "after"
  baseline = read_json("offline-baseline-validation.json")
  raise "Pre-edit baseline did not match" unless baseline.fetch("changed_baseline_files").empty?
  receipt[:pre_edit_validation_sha256] = Digest::SHA256.file(File.join(ROOT, "offline-baseline-validation.json")).hexdigest
end
File.write(target_path, JSON.pretty_generate(receipt))
own_links.each { |path| raise "Missing final report reference" unless File.file?(path) }
puts JSON.generate(receipt.reject { |key, _| %i[head_equivalence pending].include?(key) })
