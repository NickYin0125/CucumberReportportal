# frozen_string_literal: true

require "json"
require "digest"
require "time"
require "open3"

root = File.expand_path(__dir__)
checks = {}
check = lambda do |name, condition|
  raise "Offline validation failed: #{name}" unless condition
  checks[name] = true
end
read_json = ->(name) { JSON.parse(File.read(File.join(root, name))) }
result = read_json.call("result.json")
index = read_json.call("api-evidence-index.json").fetch("index")
check.call("eight_original_findings", result.fetch("findings").map { |f| f["id"] } == (1..8).map { |n| format("UI-F%02d", n) })
check.call("disposition_counts", result.fetch("findings").map { |f| f["status"] }.tally == {"fixed" => 6, "not_fixed" => 2})
followup = read_json.call("ui-f07-doc-followup.json")
check.call("UI_F07_reviewed_document_hash", Digest::SHA256.file(followup.fetch("file")).hexdigest == followup.fetch("reviewed_sha256"))
check.call("UI_F07_finding_hash_agreement", result.fetch("findings").find { |f| f["id"] == "UI-F07" }.fetch("reviewed_file_sha256") == followup.fetch("reviewed_sha256"))
followup.fetch("criteria").each { |criterion| check.call("UI_F07_#{criterion.fetch('id')}", criterion.fetch("satisfied")) }
check.call("95_saved_per_item_log_sets", index.size == 95 && Dir.glob(File.join(root, "logs-item-*.json")).size == 95)

logs = index.flat_map do |entry|
  records = read_json.call("logs-item-#{entry.fetch('item')}.json")
  check.call("item_#{entry['item']}_log_ownership", records.all? { |log| log["itemId"] == entry["item"] })
  check.call("item_#{entry['item']}_index_agreement", records.map { |l| l.slice("id", "level", "itemId", "binaryContent") } == entry.fetch("logs"))
  records
end
check.call("unique_saved_log_ids", logs.map { |l| l["id"] }.uniq.size == logs.size)
result.fetch("findings").each do |finding|
  check.call("#{finding['id']}_log_references", Array(finding["logs"]).all? { |id| logs.any? { |l| l["id"] == id } })
  check.call("#{finding['id']}_binary_references", Array(finding["binaries"]).all? { |id| logs.any? { |l| l.dig("binaryContent", "id").to_s == id.to_s } })
end
expected_launches = {3847 => [2,1,1], 3848 => [2,1,1], 3849 => [16,14,2], 3850 => [10,8,2], 3851 => [16,14,2], 3852 => [10,8,2]}
expected_launches.each do |id, counts|
  launch = read_json.call("launch-#{id}.json")
  check.call("launch_#{id}_saved_totals", launch["id"] == id && launch.dig("statistics", "executions").values_at("total", "passed", "failed") == counts)
end

shots = Dir.glob(File.join(root, "*.jpg")).sort
images = shots.map do |path|
  bytes = File.binread(path)
  check.call("#{File.basename(path)}_jpeg_markers", bytes.start_with?("\xff\xd8".b) && bytes.end_with?("\xff\xd9".b))
  dimensions, error, status = Open3.capture3("/usr/bin/sips", "-g", "pixelWidth", "-g", "pixelHeight", path)
  width = dimensions[/pixelWidth:\s*(\d+)/, 1].to_i
  height = dimensions[/pixelHeight:\s*(\d+)/, 1].to_i
  check.call("#{File.basename(path)}_image_readable", status.success? && error.empty? && width.positive? && height.positive?)
  unless File.basename(path) == "ui-tester-launch.jpg"
    stem = path.sub(/\.jpg\z/, "")
    provenance = JSON.parse(File.read("#{stem}.json"))
    check.call("#{File.basename(path)}_provenance", provenance["runtimeSha"] == result["source_head_supplied_by_master"] && File.size("#{stem}.txt").positive?)
  end
  {file: File.basename(path), width: width, height: height, sha256: Digest::SHA256.hexdigest(bytes)}
end

artifacts = read_json.call("artifact-verification.json")
artifacts.fetch("runs").each do |run|
  run.fetch("local_pngs").each do |png|
    check.call("local_png_#{File.basename(png.fetch('path'))}_unchanged", Digest::SHA256.file(png.fetch("path")).hexdigest == png.fetch("sha256"))
  end
  check.call("launch_#{run['launch']}_native_failure_png_omitted", run.fetch("native_pngs").none? { |p| p.fetch("hook") })
  check.call("launch_#{run['launch']}_original_exceptions_present", run.fetch("failures").all? { |f| !f.dig("result", "exception", "type").to_s.empty? && !f.dig("result", "exception", "message").to_s.empty? && !f.dig("result", "exception", "stackTrace").to_s.empty? })
end
check.call("copied_original_tester_inputs_unchanged", artifacts.fetch("original_tester_inputs").all? { |f| f.fetch("identical") && f["original_sha256"] == f["copied_sha256"] })
check.call("saved_plain_rich_error_comparison_passed", artifacts.fetch("error_presentation_comparison").all? { |c| c.fetch("byte_identical_messages") && !c.fetch("added_html_tags_present") })

refs = File.read(File.join(root, "ui-review.md")).scan(/\]\((\/[^)]+)\)/).flatten.uniq.map { |p| p.sub(/:\d+(?::\d+)?\z/, "") }
generated = %w[validation.json output-manifest.json].map { |name| File.join(root, name) }
check.call("report_existing_local_references", (refs - generated).all? { |p| File.file?(p) })
Dir.glob(File.join(root, "*.json")).reject { |p| generated.include?(p) }.each { |p| JSON.parse(File.read(p)) }

validation = {
  completed_at: Time.now.utc.iso8601,
  mode: "offline_only",
  network_or_browser_actions: 0,
  live_evidence_source_head: result["source_head_supplied_by_master"],
  final_source_head_supplied_by_master: result["final_source_head_supplied_by_master"],
  equivalence_basis: result.dig("final_head_equivalence", "basis"),
  service_health_certified: false,
  pending: ["Master health clearance; any post-restart service verification is outside this completed usability re-review"],
  report_local_reference_count: refs.size,
  screenshot_count: images.size,
  fresh_at_original_capture_ui_item_log_sets: index.size,
  saved_log_count: logs.size,
  dispositions: result["counts"],
  checks_passed: checks.size,
  checks: checks,
  screenshots: images
}
File.write(File.join(root, "validation.json"), JSON.pretty_generate(validation) + "\n")
files = Dir.glob(File.join(root, "*")).select { |p| File.file?(p) && File.basename(p) != "output-manifest.json" }.sort.map do |path|
  {path: path, bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest}
end
File.write(File.join(root, "output-manifest.json"), JSON.pretty_generate(files) + "\n")
raise "Missing final local reference" unless refs.all? { |p| File.file?(p) }
raise "Manifest mismatch" unless files.all? { |f| File.size(f[:path]) == f[:bytes] && Digest::SHA256.file(f[:path]).hexdigest == f[:sha256] }
puts JSON.generate(completed_at: validation[:completed_at], mode: "offline_only", screenshots: images.size, item_log_sets: index.size, saved_logs: logs.size, report_local_references: refs.size, checks_passed: checks.size, manifest_files: files.size, service_health_certified: false)
