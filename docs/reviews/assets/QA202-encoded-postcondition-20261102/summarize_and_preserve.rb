# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"
require "open3"
require "rubygems/package"
require "stringio"

root = "/private/tmp/rp-redaction-review-20261102"
repo = "/Users/nick/Documents/crr-2.0.2"
destination = "/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-encoded-postcondition-20261102"
abort "Evidence already exists" if File.exist?(destination)
runs = Dir["#{root}/performance/*-*.json"].map { |path| JSON.parse(File.read(path)) }
raise "Expected 12 complete runs" unless runs.size == 12

def source_digest(repo, commit)
  files = []
  bytes, status = Open3.capture2("git", "-C", repo, "archive", commit, "lib", binmode: true)
  raise "Archive failed" unless status.success?
  Gem::Package::TarReader.new(StringIO.new(bytes)) do |tar|
    tar.each { |entry| files << [entry.full_name, Digest::SHA256.hexdigest(entry.read)] if entry.file? }
  end
  Digest::SHA256.hexdigest(JSON.generate(files.sort))
end

expected = {
  "baseline" => source_digest(repo, "3f20313c20b25071fbc49b31e1c6bc772bd599e4"),
  "before_fix" => source_digest(repo, "f49dab28dfb10b039026e61d0bd3e9a030bf7dba"),
  "fixed" => Digest::SHA256.hexdigest(JSON.generate(JSON.parse(File.read("#{root}/fixed-source-manifest.json"))
    .fetch("files").select { |path, _| path.start_with?("lib/") }))
}
runs.each do |run|
  raise "Source mismatch" unless run.fetch("source_manifest_sha256") == expected.fetch(run.fetch("arm"))
  raise "Wrong sample count" unless run.dig("results", "redaction_plus_rendering", "summary", "n") == 1050
end

comparisons = %w[plain rich].product(%w[1 2]).map do |mode, round|
  selected = runs.select { |r| r["mode"] == mode && r["round"] == round }.to_h { |r| [r.fetch("arm"), r] }
  metrics = %w[renderer_only redaction_plus_rendering].to_h do |metric|
    p95 = selected.transform_values { |r| r.dig("results", metric, "summary", "p95_ms") }
    [metric, { p95_ms: p95, fixed_vs_baseline_percent: (p95["fixed"] / p95["baseline"] - 1) * 100,
      fixed_vs_before_fix_percent: (p95["fixed"] / p95["before_fix"] - 1) * 100 }]
  end
  { mode: mode, round: round, metrics: metrics }
end

ranges = runs.select { |r| r["arm"] == "fixed" }.group_by { |r| r["mode"] }.transform_values do |group|
  group.first.fetch("results").keys.to_h do |metric|
    p95 = group.map { |r| r.dig("results", metric, "summary", "p95_ms") }
    [metric, { p95_ms_range: p95.minmax, allocations_per_call: group.map { |r| r.dig("results", metric, "allocations_per_call") } }]
  end
end
summary = { certification: "NOT_G11_CERTIFICATION", source_hashes_verified: expected,
  comparisons: comparisons, fixed_ranges: ranges }
File.write("#{root}/performance-summary.json", JSON.pretty_generate(summary) + "\n")

FileUtils.mkdir_p(destination)
Dir.children(root).sort.each do |name|
  path = File.join(root, name)
  next unless File.file?(path)
  FileUtils.cp(path, File.join(destination, name))
end
%w[performance ruby33 ruby33-complete].each { |name| FileUtils.cp_r("#{root}/#{name}", destination) }
%w[lib/reportportal_cucumber/automation/evidence_redactor.rb
   spec/reportportal_cucumber/automation/evidence_redactor_encoded_safety_spec.rb
   spec/reportportal_cucumber/automation/cucumber_logger_spec.rb].each do |name|
  target = File.join(destination, "patched-files", name)
  FileUtils.mkdir_p(File.dirname(target))
  FileUtils.cp(File.join(repo, name), target)
end
patch, status = Open3.capture2("git", "-C", repo, "diff", "--binary", "HEAD", "--", "lib", "spec", "CHANGELOG.md")
raise "Cannot record patch" unless status.success?
File.write(File.join(destination, "working-tree.patch"), patch)
files = Dir.glob("#{destination}/**/*").select { |path| File.file?(path) }.sort.to_h do |path|
  [path.delete_prefix(destination + "/"), Digest::SHA256.file(path).hexdigest]
end
File.write(File.join(destination, "SHA256.json"), JSON.pretty_generate(files) + "\n")
puts JSON.pretty_generate(summary)
puts "Evidence: #{destination}"
