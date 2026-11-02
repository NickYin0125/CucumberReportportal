# frozen_string_literal: true

require_relative "final_release_fixtures"

FinalRelease202.authenticate
path = File.join(FinalRelease202::OUT, "fixtures-plain-v2/F04/wire.json")
records = JSON.parse(File.read(path))
wire = LedgerQA::Wire.new(project: FinalRelease202::PROJECT, upstream: FinalRelease202::ENDPOINT)
launches = records.select { |r| r["method"] == "POST" && r["path"].end_with?("/launch") && r["status"] == 201 }.map { |r| r.dig("response", "id") }
items = records.select { |r| r["method"] == "POST" && r["path"].match?(%r{/item(?:/[^/]+)?$}) && r["status"] == 201 }.to_h do |r|
  [r.fetch("response").fetch("id"), r.fetch("json").fetch("launchUuid")]
end
wire.instance_variable_set(:@launches, launches)
wire.instance_variable_set(:@items, items)
snapshot = wire.snapshot
FinalRelease202.write(File.join(FinalRelease202::OUT, "readback-recovery/4021/snapshot.json"), snapshot)
FinalRelease202.write(File.join(FinalRelease202::OUT, "readback-recovery/4021/recovery.json"),
  original_wire: path, wire_sha256: Digest::SHA256.file(path).hexdigest, method: "GET-only reconstruction from captured owned UUIDs; no rerun or old-launch mutation",
  safety: Ledger202Live.safety(JSON.parse(JSON.generate(snapshot)), records), source_sha: FinalRelease202::SHA)
puts JSON.generate(recovered: snapshot[:launches].map { |r| r["id"] }, item_count: snapshot[:items].length)
wire.close
