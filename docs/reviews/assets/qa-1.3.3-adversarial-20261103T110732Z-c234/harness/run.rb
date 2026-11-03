# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "securerandom"
require "time"

options = { phase: "baseline", scope: "targeted", cells: "M4",
  source: "/private/tmp/ledger-release-verification-20261101-rQL8pk/source-1.3.2" }
OptionParser.new do |parser|
  parser.on("--phase VALUE") { |value| options[:phase] = value }
  parser.on("--scope VALUE") { |value| options[:scope] = value }
  parser.on("--cells VALUE") { |value| options[:cells] = value }
  parser.on("--source PATH") { |value| options[:source] = File.expand_path(value) }
  parser.on("--frozen-sha SHA") { |value| options[:sha] = value }
  parser.on("--out PATH") { |value| options[:out] = File.expand_path(value) }
  parser.on("--setup-bench") { options[:bench] = true }
end.parse!
abort "phase must be baseline or candidate" unless %w[baseline candidate].include?(options[:phase])
abort "scope must be targeted or full" unless %w[targeted full].include?(options[:scope])
baseline = "19174a5ecaf1aa9fb65480f0a21d74ed65c89a8d"
abort "Candidate runs require master's explicit full frozen SHA" if options[:phase] == "candidate" && !options[:sha].to_s.match?(/\A[0-9a-f]{40}\z/)
options[:sha] ||= baseline
abort "Baseline must be frozen v1.3.2" if options[:phase] == "baseline" && options[:sha] != baseline
cells = { "M1" => ["3.1", "9.2.1"], "M2" => ["3.1", "10.2.0"], "M3" => ["3.3", "9.2.1"], "M4" => ["3.3", "10.2.0"] }
selected = options[:cells].split(",").uniq
abort "Unknown cells" unless selected.any? && (selected - cells.keys).empty?
root = File.expand_path("../..", __dir__)
out = options[:out] || File.join(root, "docs/reviews/assets/qa-1.3.3-#{options[:phase]}-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(2)}")
abort "Fresh output required" if File.exist?(out)
FileUtils.mkdir_p(out)
harness = File.join(out, "harness")
FileUtils.cp_r(__dir__, harness)
File.write(File.join(out, "harness-provenance.json"), JSON.pretty_generate(
  Dir[File.join(harness, "*")].select { |path| File.file?(path) }.sort.to_h { |path| [File.basename(path), Digest::SHA256.file(path).hexdigest] }) + "\n")
images = {
  "3.1" => "sha256:7849744f16559a7fc88547a7f6f0b55ea853ee8130b002ff67f59c73c643656c",
  "3.3" => "sha256:ce3b866e0d22c71ec576f9de6d6860be38a73b445df80ae1e0318f08a988848d"
}
chart_cache = "/private/tmp/ledger-final-matrix-20261031T063546Z-62ce39/M6-ruby34-cucumber12/source/helm/reportportal-rich-experience/charts"
results = []
puts "QA_EVIDENCE=#{out}"
$stdout.sync = true
selected.each do |id|
  ruby, cucumber = cells.fetch(id)
  cell = File.join(out, id)
  snapshot = File.join(cell, "source")
  evidence = File.join(cell, "evidence")
  FileUtils.mkdir_p(evidence)
  abort "Clone failed" unless system("git", "clone", "--quiet", "--no-hardlinks", options[:source], snapshot)
  abort "Frozen checkout failed" unless system("git", "-C", snapshot, "checkout", "--quiet", "--detach", options[:sha])
  argv = ["/usr/local/bin/docker", "run", "--rm", "--name", "qa1x-#{id.downcase}-#{SecureRandom.hex(3)}", "--cpus", "2", "--memory", "3g",
    "-v", "#{snapshot}:/source:ro", "-v", "#{evidence}:/evidence", "-v", "#{harness}:/qa:ro",
    "-v", "/private/tmp/ledger-matrix-bundles/ruby#{ruby.delete('.')}:/bundle:ro",
    "-v", "/private/tmp/ledger-pinned-tools/linux-arm64:/tools:ro", "-v", "#{chart_cache}:/charts:ro",
    "-e", "QA_PHASE=#{options[:phase]}", "-e", "QA_SCOPE=#{options[:scope]}", "-e", "QA_SHA=#{options[:sha]}",
    "-e", "QA_CUCUMBER=#{cucumber}", "-e", "QA_RUBY=#{ruby}", "-e", "QA_SETUP_BENCH=#{options[:bench] ? 1 : 0}", images.fetch(ruby), "ruby", "/qa/cell.rb"]
  File.write(File.join(evidence, "container-command.json"), JSON.pretty_generate(argv) + "\n")
  puts "Starting #{options[:phase]} #{id}, Ruby #{ruby}, Cucumber #{cucumber}, SHA #{options[:sha]}"
  success = system(*argv, out: File.join(evidence, "container.log"), err: [:child, :out])
  path = File.join(evidence, "result.json")
  result = File.file?(path) ? JSON.parse(File.read(path)) : { "status" => "ERROR", "error" => "No result" }
  result.merge!("cell" => id, "container_success" => success, "image" => images.fetch(ruby), "evidence" => evidence)
  results << result
  File.write(File.join(out, "matrix.json"), JSON.pretty_generate(options: options, cells: results) + "\n")
  puts JSON.generate(result.slice("cell", "status", "targeted", "rspec_full", "cucumber_offline_full", "error"))
end
exit(results.all? { |result| result["container_success"] } ? 0 : 1)
