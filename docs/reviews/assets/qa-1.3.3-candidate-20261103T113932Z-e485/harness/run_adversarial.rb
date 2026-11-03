# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "optparse"
require "securerandom"
require "time"

options = {}
OptionParser.new do |parser|
  parser.on("--source PATH") { |value| options[:source] = File.expand_path(value) }
  parser.on("--label VALUE") { |value| options[:label] = value }
end.parse!
abort "Explicit source and provenance label required" unless options[:source] && options[:label]
root = File.expand_path("../..", __dir__)
out = File.join(root, "docs/reviews/assets/qa-1.3.3-adversarial-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(2)}")
FileUtils.mkdir_p(out)
snapshot = File.join(out, "source")
FileUtils.mkdir_p(snapshot)
FileUtils.cp_r(File.join(options[:source], "lib"), snapshot)
harness = File.join(out, "harness")
FileUtils.cp_r(__dir__, harness)
libraries = Dir[File.join(snapshot, "lib/**/*.rb")].sort.to_h { |path| [path.delete_prefix(snapshot + "/"), Digest::SHA256.file(path).hexdigest] }
File.write(File.join(out, "provenance.json"), JSON.pretty_generate(options.merge(library_sha256: libraries,
  provisional_source_snapshot_not_frozen_acceptance: true,
  harness_sha256: Dir[File.join(harness, "*.rb")].sort.to_h { |path| [File.basename(path), Digest::SHA256.file(path).hexdigest] })) + "\n")
argv = ["/usr/local/bin/docker", "run", "--rm", "--network", "none", "--cpus", "1", "--memory", "1g",
  "-v", "#{snapshot}:/source:ro", "-v", "#{harness}:/qa:ro", "-v", "#{out}:/evidence", "-v", "/private/tmp/ledger-matrix-bundles/ruby33:/bundle:ro",
  "-e", "GEM_PATH=/bundle/ruby/3.3.0", "-e", "QA_SOURCE=/source", "-e", "QA_CUCUMBER=10.2.0",
  "local/rp-redaction-review-ruby33:20261102", "ruby", "-rrspec/core", "-e",
  "exit RSpec::Core::Runner.run(ARGV)", "--", "/qa/targeted_spec.rb", "/qa/adversarial_spec.rb", "--format", "documentation", "--format", "json", "--out", "/evidence/probes.json"]
File.write(File.join(out, "container-command.json"), JSON.pretty_generate(argv) + "\n")
success = system(*argv, out: File.join(out, "probes.log"), err: [:child, :out])
data = JSON.parse(File.read(File.join(out, "probes.json")))
puts JSON.generate(evidence: out, label: options[:label], summary: data.fetch("summary"), provisional_only: true)
exit(success ? 0 : 1)
