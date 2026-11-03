# frozen_string_literal: true

require "digest"
require "find"
require "json"
require "open3"
require "time"

root = File.expand_path("../..", __dir__)
out = File.expand_path(ARGV.fetch(0))
abort "Owned CI extension directory required" unless out.start_with?(File.join(root, "docs/reviews/assets/qa-1.3.3-ci-extension-")) && File.directory?(out)
report = File.join(root, "docs/reviews/2026-11-03-maintenance-1.3.3-ci-extension.md")
index = File.join(out, "ci-extension-manifest.json")
historical_paths = %w[
  docs/reviews/2026-11-03-maintenance-1.3.3-final-acceptance.md
  docs/reviews/assets/qa-1.3.3-curated-manifest.json
]
historical = historical_paths.to_h do |path|
  bytes, error, status = Open3.capture3("git", "-C", root, "show", "1b74b3d:#{path}")
  raise error unless status.success?
  expected = Digest::SHA256.hexdigest(bytes)
  raise "Historical accepted evidence changed: #{path}" unless Digest::SHA256.file(File.join(root, path)).hexdigest == expected
  [path, expected]
end
qa_commit, error, status = Open3.capture3("git", "-C", root, "rev-parse", "1b74b3d")
raise error unless status.success?
paths = [report, *%w[ci_extension.rb ci_receipts.rb ci_inventory.rb].map { |name| File.join(__dir__, name) }]
Find.find(out) do |path|
  if File.directory?(path)
    Find.prune if File.basename(path).end_with?("-source") || %w[.git gems cache node_modules vendor].include?(File.basename(path))
    next
  end
  next if path == index || File.symlink?(path)
  next unless %w[.rb .json .log .lock .resolved .txt .md].include?(File.extname(path)) || File.basename(path) == "Gemfile"
  paths << path
end
entries = paths.uniq.sort.map do |path|
  raise "Missing curated file #{path}" unless File.file?(path)
  { path: path.delete_prefix(root + "/"), bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest }
end
File.write(index, JSON.pretty_generate(created_at: Time.now.utc.iso8601,
  accepted_qa_commit_unchanged: qa_commit.strip,
  accepted_runtime_sha: "68e81d3697965305438be4fa27aa98aeb4baf726",
  ci_extension_sha: "69aaedecd10a3ac01d7ad90b96e2db1b60343344",
  historical_report_and_manifest_sha256_unchanged: historical,
  exclusions: "source exports/extracted packages, .gem archives, Git stores, dependencies and caches; no old accepted file is restaged",
  manifest_itself: index.delete_prefix(root + "/"), files: entries,
  total_bytes: entries.sum { |entry| entry.fetch(:bytes) }, no_commit_or_push_by_qa: true) + "\n")
puts JSON.generate(index: index, files: entries.length, bytes: entries.sum { |entry| entry.fetch(:bytes) })
