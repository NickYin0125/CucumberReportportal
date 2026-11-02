# frozen_string_literal: true

require "json"
require "digest"

root = File.expand_path("../../../..", __dir__)
prefix = File.join(root, "docs/reviews/assets/QA202-final-release-20261102-performance")
name = ARGV.fetch(0, "owned-files.json")
raise "Owned inventory filename required" unless name.match?(/\Aowned-files(?:-[a-zA-Z0-9_-]+)?\.json\z/)
output = File.join(prefix, name)
files = Dir.glob(File.join(__dir__, "release_perf_*.rb")) +
  [File.join(root, "docs/reviews/2026-11-02-final-release-performance.md")] +
  Dir.glob(File.join(prefix, "**/*"), File::FNM_DOTMATCH).select { |p| File.file?(p) }
files = (files + [output]).uniq.sort
record = { "purpose" => "Exact owned files for Master-only serialized scan/staging; no commit or push performed",
  "files" => files, "count" => files.length }
File.open(output, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(JSON.pretty_generate(record) + "\n") }
puts JSON.generate(file_inventory: output, count: files.length, sha256: Digest::SHA256.file(output).hexdigest)
