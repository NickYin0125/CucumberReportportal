# frozen_string_literal: true

require "fileutils"
require "json"
require "optparse"
require "securerandom"
require "time"

options = { source: "/Users/nick/Documents/crr-1.3.3", iterations: 1000 }
OptionParser.new do |parser|
  parser.on("--frozen-sha SHA") { |value| options[:sha] = value }
  parser.on("--source PATH") { |value| options[:source] = File.expand_path(value) }
  parser.on("--out PATH") { |value| options[:out] = File.expand_path(value) }
  parser.on("--iterations N", Integer) { |value| options[:iterations] = value }
  parser.on("--resource-slot-confirmed") { options[:slot] = true }
end.parse!
abort "First coordinate the benchmark resource slot with master" unless options[:slot]
abort "Explicit frozen full SHA required" unless options[:sha].to_s.match?(/\A[0-9a-f]{40}\z/)
abort "Expected 100..10000 iterations" unless (100..10_000).cover?(options[:iterations])
out = options[:out] || File.expand_path("../../docs/reviews/assets/qa-1.3.3-paired-bench-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(2)}", __dir__)
abort "Fresh output required" if File.exist?(out)
FileUtils.mkdir_p(out)
sources = {
  "baseline" => ["/private/tmp/ledger-release-verification-20261101-rQL8pk/source-1.3.2", "19174a5ecaf1aa9fb65480f0a21d74ed65c89a8d"],
  "candidate" => [options[:source], options[:sha]]
}.to_h do |label, (source, sha)|
  snapshot = File.join(out, label + "-source")
  abort "Clone failed" unless system("git", "clone", "--quiet", "--no-hardlinks", source, snapshot)
  abort "Checkout failed" unless system("git", "-C", snapshot, "checkout", "--quiet", "--detach", sha)
  [label, snapshot]
end
image = JSON.parse(File.read(File.join(__dir__, "environment/images.json"))).fetch("3.3").fetch("image")
records = []
3.times do |replicate|
  order = replicate.odd? ? %w[candidate baseline] : %w[baseline candidate]
  order.each do |label|
    name = "#{replicate + 1}-#{label}"
    path = File.join(out, name + ".json")
    argv = ["/usr/local/bin/docker", "run", "--rm", "--network", "none", "--cpus", "1", "--memory", "2g",
      "-v", "#{sources.fetch(label)}:/source:ro", "-v", "#{__dir__}:/qa:ro", "-v", "#{out}:/evidence",
      "-v", "/private/tmp/ledger-matrix-bundles/ruby33:/bundle:ro", "-e", "GEM_PATH=/bundle/ruby/3.3.0",
      "-e", "QA_SOURCE=/source", "-e", "QA_CUCUMBER=10.2.0", "-e", "QA_BENCH_LABEL=#{name}",
      "-e", "QA_BENCH_ITERATIONS=#{options[:iterations]}", "-e", "QA_BENCH_OUT=/evidence/#{name}.json",
      image, "ruby", "/qa/bench.rb"]
    File.write(File.join(out, name + "-command.json"), JSON.pretty_generate(argv) + "\n")
    abort "Benchmark failed" unless system(*argv, out: File.join(out, name + ".log"), err: [:child, :out])
    records << JSON.parse(File.read(path)).merge("replicate" => replicate + 1, "line" => label)
  end
end
signatures = records.map { |record| [record.fetch("ruby"), record.fetch("gems")] }.uniq
abort "Unmatched runtime/dependencies" unless signatures.length == 1
comparison = records.first.fetch("results").keys.to_h do |name|
  values = %w[baseline candidate].to_h do |line|
    medians = records.select { |record| record.fetch("line") == line }.map { |record| record.fetch("results").fetch(name).fetch("median_ms") }.sort
    [line, medians[1]]
  end
  [name, values.merge("candidate_over_baseline" => values.fetch("candidate") / values.fetch("baseline"))]
end
File.write(File.join(out, "comparison.json"), JSON.pretty_generate(frozen_sha: options[:sha], image: image,
  matched_runtime_dependencies: true, diagnostic_not_automatic_acceptance: true,
  excludes_unsafe_legacy_fast_paths: true, comparisons: comparison) + "\n")
puts "QA_PAIRED_BENCH_EVIDENCE=#{out}"
