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
allowed = %w[.rb .md .json .log .txt .lock .resolved .ndjson .png .jpg .jpeg .feature .sh .yml .yaml .stdout .stderr]
named = %w[Dockerfile Gemfile .gitignore STOP_AFTER_CURRENT_CELL]
final_sha = "68e81d3697965305438be4fa27aa98aeb4baf726"
baseline_sha = "19174a5ecaf1aa9fb65480f0a21d74ed65c89a8d"
classify = lambda do |relative|
  case relative
  when %r{ui/4088-(argument-escaping\.json|supported-argument-escaping\.jpg|rich-response-first\.jpg)\z}
    ["partial UI snapshot retained; superseded by complete argument DOM and HTTP-card-top evidence", [final_sha]]
  when /candidate-20261103T113932Z-e485/, /live-20261103T115435Z-8112/, /adversarial-bench-/, /frozen3-scope-review/, /final-(source-proof|gate-audit)/
    ["final frozen candidate evidence; consult each artifact for execution kind", [final_sha]]
  when /paired-bench-20261103T120527Z-df3d/
    ["matched normal CPU measurements; not an automatic pass or network SLA", [baseline_sha, final_sha]]
  when /candidate-20261103T110859Z-2a3d/
    ["rejected Freeze 1; security finding and missing-jq environment failures retained", ["b470799d3086a627f521a5755c50f6609064e3cb"]]
  when /candidate-20261103T111945Z-269e/, /frozen2-scope-review/
    ["superseded Freeze 2; SDK standalone-spec isolation defect and partial runs retained", ["1a8db4fd4cdc59985ef49d71d254ba21997aeef1"]]
  when /baseline-20261103T110602Z-3857/, /depth-baseline-1\.3\.2/
    ["canonical targeted baseline control; expected failures are not full-suite failures", [baseline_sha]]
  when /depth-reference-2\.0\.2/
    ["released 2.x shared risk; not final 1.x acceptance", ["29ce2a4b5d8ca6b8119de97a7e3ae967bc66ddef"]]
  when %r{\Aqa/}, /maintenance-1\.3\.3-.*\.md\z/, /\.gitignore\z/
    ["methodology or report; not itself a runtime execution", []]
  else
    ["retained setup, diagnostic or provisional evidence; not final acceptance", []]
  end
end
files = []
roots.uniq.select { |path| File.exist?(path) }.each do |base|
  Find.find(base) do |path|
    if File.directory?(path)
      name = File.basename(path)
      # Full RSpec JSON/logs retain outcomes; generated SDK fault scratch is local state.
      Find.prune if name == "source" || name.end_with?("-source") || %w[.git gems cache node_modules vendor faults].include?(name)
      next
    end
    next if path == out || File.symlink?(path) || !File.file?(path)
    next unless allowed.include?(File.extname(path)) || named.include?(File.basename(path))

    files << path
  end
end
entries = files.uniq.sort.map do |path|
  relative = path.delete_prefix(root + "/")
  raise "Runner state leaked into curated inventory" if relative.split("/").any? { |part| part == "source" || part.end_with?("-source") || %w[.git gems cache].include?(part) }
  classification, source_shas = classify.call(relative)
  { path: relative, bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest,
    classification: classification, associated_source_shas: source_shas,
    owner: relative.end_with?("maintenance-1.3.3-manager-review.md") ? "manager; content not used as execution evidence" : "independent QA" }
end
File.write(out, JSON.pretty_generate(created_at: Time.now.utc.iso8601, accepted_candidate_identity: final_sha,
  historical_evidence_warning: "Associated source identities and classifications are per entry; retained failures are not represented as final-candidate executions",
  source_clones_and_packages: "Local runner state only, excluded; generated SDK fault scratch also excluded while full outcome/failure JSON and logs remain curated",
  actual_commits_or_publication_by_qa: false, files: entries, total_bytes: entries.sum { |entry| entry.fetch(:bytes) }) + "\n")
puts JSON.generate(manifest: out, files: entries.length, bytes: entries.sum { |entry| entry.fetch(:bytes) })
