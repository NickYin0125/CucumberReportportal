# frozen_string_literal: true

require_relative "host"

# Read existing samples only. This does not load the SDK or take timings.
window = File.join(Ledger202Host::OUTPUT, "quiet-090b-window-1")
corpus_path = File.join(Ledger202Host::ROOT, "docs/reviews/assets/ledger-2.0.2-preparation/failure-corpus.json")
corpus = JSON.parse(File.read(corpus_path))
arms = %w[baseline candidate].to_h do |role|
  path = File.join(window, "matched-#{role}-plain.json")
  [role, JSON.parse(File.read(path))]
end
raise "Corpus differs" unless arms.values.all? { |a| a["corpus_sha256"] == corpus["corpus_sha256"] }
rows = corpus.fetch("cases").each_with_index.map do |row, index|
  boundaries = %w[renderer_only redaction_plus_rendering].to_h do |boundary|
    values = arms.transform_values do |arm|
      all = arm.fetch("samples_ms").fetch(boundary)
      raise "Incomplete original samples" unless all.length == 1050
      samples = all.slice(index * 50, 50)
      { p95_ms: samples.sort[47], median_ms: (samples.sort[24] + samples.sort[25]) / 2.0,
        samples_sha256: Digest::SHA256.hexdigest(JSON.generate(samples)) }
    end
    values["candidate_baseline_p95_ratio"] = values["candidate"][:p95_ms] / values["baseline"][:p95_ms]
    [boundary, values]
  end
  { index_zero_based: index, fixture: row["fixture"], input_id: row["input_id"], exception_class: row["class"],
    message_bytes: row["message"].bytesize, frame_count: row["frames"].length, boundaries: boundaries }
end
destination = File.join(Ledger202Host::OUTPUT, "offline-review")
Ledger202Host.write_new(File.join(destination, "per-input-performance.json"),
  method: "Postprocessing the original 50-sample contiguous slices; no new execution; diagnostic ranking is not a causal profile or a replacement gate",
  corpus_sha256: corpus["corpus_sha256"], cases: rows)
archive = File.join(destination, "window1-harness")
raise "Harness archive exists" if File.exist?(archive)
FileUtils.mkdir_p(archive)
manifest = %w[benchmark.rb benchmark_child.rb quiet.rb].map do |name|
  source = File.join(__dir__, name)
  target = File.join(archive, name)
  FileUtils.cp(source, target)
  raise "Harness archive copy differs" unless File.binread(source) == File.binread(target)
  { source: source, retained_copy: target, sha256: Digest::SHA256.file(target).hexdigest }
end
Ledger202Host.write_new(File.join(destination, "handoff-manifest.json"),
  harness: manifest, original_window_unchanged: true, corpus_file_sha256: Digest::SHA256.file(corpus_path).hexdigest,
  original_checks_sha256: Digest::SHA256.file(File.join(destination, "checks.json")).hexdigest,
  same_activated_dependencies: arms["baseline"].fetch("activation").fetch("gems") == arms["candidate"].fetch("activation").fetch("gems"))
puts JSON.generate(cases: rows.length, new_timings: 0, original_window_writes: 0, retained_harness_files: manifest.length)
