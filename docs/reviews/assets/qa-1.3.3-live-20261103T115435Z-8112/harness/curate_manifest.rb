# frozen_string_literal: true

require "digest"
require "find"
require "json"
require "time"

root = File.expand_path("../..", __dir__)
out = File.join(root, "docs/reviews/assets/qa-1.3.3-curated-manifest.json")
roots = [File.join(root, "qa/readability_1x"), *Dir[File.join(root, "docs/reviews/assets/qa-1.3.3-*")],
  File.join(root, ".gitignore"),
  File.join(root, "docs/reviews/2026-11-03-maintenance-1.3.3-independent-acceptance.md"),
  File.join(root, "docs/reviews/2026-11-03-maintenance-1.3.3-final-acceptance.md"),
  File.join(root, "docs/reviews/2026-11-03-maintenance-1.3.3-manager-review.md")]
allowed = %w[.rb .md .json .log .txt .lock .resolved .ndjson .png .jpg .jpeg]
files = []
roots.uniq.select { |path| File.exist?(path) }.each do |base|
  Find.find(base) do |path|
    if File.directory?(path)
      name = File.basename(path)
      Find.prune if name == "source" || name.end_with?("-source") || %w[.git gems cache node_modules vendor].include?(name)
      next
    end
    next if path == out || File.symlink?(path) || !File.file?(path)
    next unless allowed.include?(File.extname(path)) || %w[Dockerfile .gitignore].include?(File.basename(path))

    files << path
  end
end
entries = files.uniq.sort.map do |path|
  relative = path.delete_prefix(root + "/")
  raise "Runner state leaked into curated inventory" if relative.split("/").any? { |part| part == "source" || part.end_with?("-source") || %w[.git gems cache].include?(part) }
  { path: relative, bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest,
    owner: relative.end_with?("maintenance-1.3.3-manager-review.md") ? "manager; content not used as execution evidence" : "independent QA" }
end
File.write(out, JSON.pretty_generate(created_at: Time.now.utc.iso8601, frozen_sha: "68e81d3697965305438be4fa27aa98aeb4baf726",
  source_clones_and_packages: "Local runner state only, excluded",
  actual_commits_or_publication_by_qa: false, files: entries, total_bytes: entries.sum { |entry| entry.fetch(:bytes) }) + "\n")
puts JSON.generate(manifest: out, files: entries.length, bytes: entries.sum { |entry| entry.fetch(:bytes) })
