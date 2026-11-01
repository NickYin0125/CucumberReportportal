# frozen_string_literal: true

require "json"
require "base64"
require "digest"
require_relative "final_wp5_context"

stamp = LedgerWP5Context.stamp
head = LedgerWP5Context.heads.fetch("1.3.2")
root = "/Users/nick/Documents/crr-qa-1.3.2"
name = "Scenario: Five parameters force description fallback"
rows = %w[baseline plain-1 rich-1 plain-2 rich-2].map do |group|
  folder = File.join(root, "docs/reviews/assets/ledger-qa-live/#{stamp}-c10.2.0-#{group}/F14")
  wire = JSON.parse(File.read(File.join(folder, "wire.json")))
  request = wire.find { |row| row["method"] == "POST" && row.dig("json", "name") == name }
  raise "Missing original item request" unless request
  bytes = Base64.strict_decode64(request.fetch("body_base64"))
  raise "Captured request hash mismatch" unless Digest::SHA256.hexdigest(bytes) == request.fetch("request_sha256")
  array_bytes = bytes[/"parameters":(\[[^\]]*\])/m, 1]
  raise "Missing exact parameter array" unless array_bytes
  snapshot = JSON.parse(File.read(File.join(folder, "snapshot.json")))
  item = snapshot.fetch("items").find { |row| row["name"] == name }
  raise "Item not found" unless item
  {
    group: group, runtime_sha: group == "baseline" ? "4ca2f770e0a84e83688f165ba04b4db8ef855cf9" : head,
    source_snapshot: File.join(folder, "snapshot.json"), source_wire: File.join(folder, "wire.json"),
    launch_id: snapshot.fetch("launches").first.fetch("id"), item_id: item.fetch("id"), log_ids: [],
    request_sha256: request.fetch("request_sha256"), wire_array_bytes: array_bytes,
    wire_array_sha256: Digest::SHA256.hexdigest(array_bytes), wire_parameters: request.dig("json", "parameters"),
    api_parameters: item.fetch("parameters")
  }
end
baseline = rows.first
checks = rows.drop(1).map do |row|
  # Sort collection entries without discarding duplicate entries or any entry keys.
  multiset = ->(entries) { entries.map { |entry| JSON.generate(entry.sort.to_h) }.sort }
  actual = [row[:wire_array_bytes] == baseline[:wire_array_bytes],
    multiset.call(row[:api_parameters]) == multiset.call(baseline[:api_parameters])]
  { criterion: "G1", check: "F14 #{row[:group]}: exact ordered client array bytes plus complete persisted parameter multiset",
    method: "C", runtime_sha: head, cucumber: "10.2.0", expected: [true, true], actual: actual,
    verdict: actual == [true, true] ? "PASS" : "FAIL", inputs: { baseline: baseline, candidate: row },
    evidence: { source: [baseline[:source_wire], row[:source_wire], baseline[:source_snapshot], row[:source_snapshot]],
      launch_ids: [baseline[:launch_id], row[:launch_id]], item_ids: [baseline[:item_id], row[:item_id]], log_ids: [] } }
end
result = { schema: "f14-ordered-wire-vs-api-investigation/1", runtime_sha: head, rows: rows, checks: checks,
  conclusion: "All five original client arrays are byte-identical and ordered a,b,c,d,e. The baseline API alone returns e,a,b,c,d. Raw API observations are retained; no wire-order normalization, runtime repair or acceptance exception is applied." }
path = File.join(root, "docs/reviews/assets/#{stamp}/f14-parameter-order-investigation.json")
raise "Preserve earlier investigation" if File.exist?(path)
File.write(path, JSON.pretty_generate(result) + "\n")
puts JSON.generate(path: path, checks: checks.length, failures: checks.count { |row| row[:verdict] == "FAIL" },
  launches: rows.map { |row| row[:launch_id] }, wire_array_sha256: baseline[:wire_array_sha256])
