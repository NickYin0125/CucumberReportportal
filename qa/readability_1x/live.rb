# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "optparse"
require "securerandom"
require "time"

options = { source: "/Users/nick/Documents/crr-1.3.3" }
OptionParser.new do |parser|
  parser.on("--source PATH") { |value| options[:source] = File.expand_path(value) }
  parser.on("--frozen-sha SHA") { |value| options[:sha] = value }
  parser.on("--authorize-live-writes") { options[:authorized] = true }
  parser.on("--out PATH") { |value| options[:out] = File.expand_path(value) }
end.parse!
abort "Explicit live-write authorization and frozen full SHA required" unless options[:authorized] && options[:sha].to_s.match?(/\A[0-9a-f]{40}\z/)
abort "Only the authorized endpoint/project are allowed" unless ENV.fetch("RP_ENDPOINT") == "http://rp-2607.localhost:18080" && ENV.fetch("RP_PROJECT") == "superadmin_personal"
abort "Use the in-memory token runner" if ENV.fetch("RP_API_KEY", "").empty?
out = options[:out] || File.expand_path("../../docs/reviews/assets/qa-1.3.3-live-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(2)}", __dir__)
abort "Fresh output required" if File.exist?(out)
FileUtils.mkdir_p(out)
harness = File.join(out, "harness")
FileUtils.cp_r(__dir__, harness)
File.write(File.join(out, "harness-provenance.json"), JSON.pretty_generate(
  Dir[File.join(harness, "**/*")].select { |path| File.file?(path) }.sort.to_h { |path| [path.delete_prefix(harness + "/"), Digest::SHA256.file(path).hexdigest] }) + "\n")
FileUtils.mkdir_p(File.join(out, "ui"))
snapshot = File.join(out, "source")
abort "Clone failed" unless system("git", "clone", "--quiet", "--no-hardlinks", options[:source], snapshot)
abort "Checkout failed" unless system("git", "-C", snapshot, "checkout", "--quiet", "--detach", options[:sha])
results = []
image = JSON.parse(File.read(File.join(__dir__, "environment/images.json"))).fetch("3.3").fetch("image")
%w[9.2.1 10.2.0].each do |cucumber|
  %w[plain rich].each do |mode|
    cell = File.join(out, "cucumber#{cucumber}-#{mode}")
    FileUtils.mkdir_p(cell)
    argv = ["/usr/local/bin/docker", "run", "--rm", "--cpus", "1", "--memory", "2g",
      "--add-host", "rp-2607.localhost:host-gateway", "-v", "#{snapshot}:/source:ro", "-v", "#{harness}:/qa:ro",
      "-v", "#{cell}:/evidence", "-v", "/private/tmp/ledger-matrix-bundles/ruby33:/bundle:ro",
      "-e", "RP_API_KEY", "-e", "RP_ENDPOINT", "-e", "RP_PROJECT", "-e", "QA_SHA=#{options[:sha]}",
      "-e", "QA_CUCUMBER=#{cucumber}", "-e", "QA_MODE=#{mode}",
      image, "ruby", "/qa/live_cell.rb"]
    File.write(File.join(cell, "container-command.json"), JSON.pretty_generate(argv) + "\n")
    puts "Starting fresh final live Cucumber #{cucumber} #{mode}"
    $stdout.flush
    success = system(*argv)
    path = File.join(cell, "result.json")
    result = File.file?(path) ? JSON.parse(File.read(path)) : { "status" => "ERROR", "error" => "No result" }
    result.merge!("cucumber" => cucumber, "mode" => mode, "container_success" => success, "image" => image)
    results << result
    File.write(File.join(out, "live-summary.json"), JSON.pretty_generate(sha: options[:sha], results: results) + "\n")
    abort "Live gate failed; retained owned evidence at #{cell}. No duplicate launch retry." unless success
  end
end
puts "QA_LIVE_EVIDENCE=#{out}"
