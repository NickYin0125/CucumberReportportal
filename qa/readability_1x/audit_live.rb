# frozen_string_literal: true

require "digest"
require "json"
require "optparse"
require "time"

options = {}
OptionParser.new do |parser|
  parser.on("--evidence PATH") { |value| options[:evidence] = File.expand_path(value) }
  parser.on("--frozen-sha SHA") { |value| options[:sha] = value }
end.parse!
abort "Explicit evidence directory and frozen full SHA required" unless options[:evidence] && options[:sha].to_s.match?(/\A[0-9a-f]{40}\z/)

root = options.fetch(:evidence)
load_json = ->(path) { JSON.parse(File.read(File.join(root, path))) }
check = ->(condition, message) { raise message unless condition }
full_files = {
  "qa-340-lines.txt" => (1..340).map { |line| "QA line #{line} <script>qa_text</script>" }.join("\n"),
  "qa-48k.txt" => "x" * (48 * 1024),
  "qa-25-lines.json" => JSON.pretty_generate((1..25).to_h { |number| ["key#{number}", number] })
}
names = []
cells = %w[cucumber9.2.1-plain cucumber9.2.1-rich cucumber10.2.0-plain cucumber10.2.0-rich].map do |cell|
  result = load_json.call("#{cell}/result.json")
  check.call(result.fetch("sha") == options[:sha], "Wrong frozen source: #{cell}")
  snapshot = load_json.call("#{cell}/rp-snapshot.json")
  items = snapshot.fetch("items").to_h { |item| [item.fetch("id"), item] }
  logs = snapshot.fetch("logs")
  pngs = %w[first second].map do |label|
    expected = load_json.call("#{cell}/expected-#{label}.json")
    name = expected.fetch("name")
    names << name
    check.call(name.match?(/\Aqa-after-#{label}-[a-f0-9]{16}\.png\z/), "Unexpected QA fixture PNG name")
    matches = logs.select { |log| log.fetch("message").include?(name) }
    check.call(matches.length == 1, "Duplicate/missing PNG RP entry: #{cell}/#{label}")
    log = matches.first
    owner = items.fetch(log.fetch("itemId"))
    parent = items.fetch(owner.fetch("parent"))
    check.call(owner.fetch("type") == "AFTER_METHOD" && owner.fetch("status") == "PASSED", "After ownership/status changed")
    check.call(parent.fetch("name") == "Scenario: Raw failure with After evidence #{label}" && parent.fetch("status") == "FAILED", "PNG attached to wrong failed scenario")
    check.call(owner.fetch("launchId") == result.fetch("launch_id"), "Cross-launch attachment owner")
    check.call(log.fetch("binaryContent").fetch("contentType") == "image/png", "Wrong attachment MIME")
    check.call(Digest::SHA256.file(File.join(root, cell, name)).hexdigest == expected.fetch("sha256"), "PNG download bytes changed")
    raw = logs.select do |entry|
      entry.fetch("message").include?(expected.fetch("original_message")) &&
        entry.fetch("message").include?(expected.fetch("original_frames").join("\n"))
    end
    check.call(raw.length == 1 && items.fetch(raw.first.fetch("itemId")).fetch("parent") == parent.fetch("id"), "Raw failure content/frames/ownership changed")
    { case: label, name: name, log_id: log.fetch("id"), binary_id: log.fetch("binaryContent").fetch("id"),
      owner_id: owner.fetch("id"), owner_status: owner.fetch("status"), scenario_id: parent.fetch("id"),
      raw_failure_log_id: raw.first.fetch("id"), raw_frames: expected.fetch("original_frames").length,
      png_sha256: expected.fetch("sha256") }
  end
  previews = load_json.call("#{cell}/f18-previews.json").map do |preview|
    bytes = full_files.fetch(preview.fetch("name"))
    downloaded = preview.fetch("downloaded")
    check.call(downloaded.fetch("bytes") == bytes.bytesize && downloaded.fetch("sha256") == Digest::SHA256.hexdigest(bytes), "F18 full download differs from original fixture bytes")
    { name: preview.fetch("name"), log_id: preview.fetch("log_id"), bytes: bytes.bytesize,
      sha256: downloaded.fetch("sha256"), original_bytes_verified: true }
  end
  dom = load_json.call("ui/#{result.fetch('launch_id')}-main-complete.json")
  check.call(dom.fetch("sourceSha") == options[:sha] && dom.fetch("responseFirst") && dom.fetch("repeatedHeaders") &&
    dom.fetch("docLiteral") && dom.fetch("tableLiteral") && dom.fetch("secretAbsent") &&
    dom.fetch("unsafeNodes").zero? && dom.fetch("errorDecoration").zero?, "Incomplete browser DOM acceptance")
  check.call(dom.fetch("previews").map { |preview| preview.fetch("codeLines") } == [100, 1, 27], "F18 preview lines changed")
  check.call(dom.fetch("previews")[1].fetch("codeCharacters") == 16_384, "F18 byte preview changed")
  { cell: cell, launch_id: result.fetch("launch_id"), pngs: pngs, f18: previews, dom_verified: true }
end
check.call(names.uniq.length == 8, "PNG names are not unique across four launches")
report = { frozen_sha: options[:sha], created_at: Time.now.utc.iso8601, status: "PASS",
  method: "Read-only audit of independently captured RP API responses, downloaded PNGs, F18 download hashes and actual CUA DOM; no new launch writes",
  unique_png_names: names.length, cells: cells }
path = File.join(root, "live-final-audit.json")
File.write(path, JSON.pretty_generate(report) + "\n")
puts JSON.generate(status: report[:status], launch_ids: cells.map { |cell| cell.fetch(:launch_id) }, unique_png_names: names.length, evidence: path)
