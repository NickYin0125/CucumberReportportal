# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"
require "time"

source = "/private/tmp/ledger-final-matrix-20261031T063546Z-62ce39/M4-ruby33-cucumber10/evidence"
root = "/Users/nick/Documents/crr-qa-1.3.2"
target = File.join(root, "docs/reviews/assets/ledger-qa-supplied-history/master-prefixed-M4")
FileUtils.mkdir_p(target)
names = %w[rspec.json rspec.log cucumber.json cucumber.log runtime.log source-head.log result.json]
entries = names.map do |name|
  original = File.join(source, name)
  copy = File.join(target, name)
  FileUtils.cp(original, copy) unless File.exist?(copy)
  digest = Digest::SHA256.file(original).hexdigest
  raise "Supplied history copy differs" unless Digest::SHA256.file(copy).hexdigest == digest
  { original: original, retained: copy.delete_prefix(root + "/"), bytes: File.size(copy), sha256: digest }
end
rspec = JSON.parse(File.read(File.join(target, "rspec.json")))
failures = rspec.fetch("examples").reject { |example| example["status"] == "passed" }
record = { provenance: "Master-supplied pre-fix matrix, NOT an independent final-candidate run",
  observed_at_utc: Time.now.utc.iso8601, source_directory: source, files: entries,
  summary: rspec["summary"], failures: failures,
  verdict_use: "Historical wall-clock failure only; no baseline-flake conclusion, no relaxed bound, no final-head PASS inferred." }
File.write(File.join(target, "provenance.json"), JSON.pretty_generate(record) + "\n")
puts JSON.generate(files: entries.length, summary: rspec["summary"], nonpassing_examples: failures.length)
