# frozen_string_literal: true

require "json"
require "open3"
require "fileutils"
require "time"

out = "/private/tmp/rp-redaction-review-20261102"
dir = File.join(out, "performance-mode-verified")
abort "Never overwrite performance evidence" if File.exist?(dir)
FileUtils.mkdir_p(dir)
qa = "/Users/nick/Documents/crr-qa-2.0.2"
sources = { "baseline" => "/private/tmp/ledger-qa202-9bf3356/baseline", "before_fix" => "#{out}/before-fix", "fixed" => "#{out}/fixed-source" }
image = "sha256:316dd4f6b6de632d5ade7bdb78fc33f7e82db8a87785e93a8a2c8d81706d3fe7"
events = []
3.times do
  stats, error, status = Open3.capture3("docker", "stats", "--no-stream", "--format", "{{.Name}} {{.CPUPerc}}")
  raise error unless status.success?
  loadavg, status = Open3.capture2("sysctl", "-n", "vm.loadavg")
  raise "Cannot inspect host load" unless status.success?
  events << { utc: Time.now.utc.iso8601, container_stats: stats, host_loadavg: loadavg }
end
File.write(File.join(dir, "environment.json"), JSON.pretty_generate(
  scope: "Counterbalanced diagnostic only; no G11 receipt or quiet-window certification",
  image: image, dependency_volume: "ledger-qa202-9bf3356-dependencies", cpu_limit: 1, memory_limit: "2g",
  network: "none", warmup_per_frozen_case: 10, samples_per_frozen_case: 50, preflight: events,
  source_identity: { baseline: "3f20313c20b25071fbc49b31e1c6bc772bd599e4", before_fix: "f49dab28",
    fixed: JSON.parse(File.read(File.join(out, "fixed-source-manifest.json"))) }
) + "\n")
2.times do |round|
  %w[plain rich].each do |mode|
    order = round.zero? ? %w[baseline before_fix fixed] : %w[fixed before_fix baseline]
    order.each do |arm|
      args = ["docker", "run", "--rm", "--network", "none", "--cpus", "1", "--memory", "2g",
        "-v", "#{qa}:/qa:ro", "-v", "#{out}:/evidence", "-v", "#{sources.fetch(arm)}:/qa202-sdk:ro",
        "-v", "ledger-qa202-9bf3356-dependencies:/bundle:ro", "-e", "GEM_HOME=/bundle/ruby/3.4.0",
        "-e", "GEM_PATH=/bundle/ruby/3.4.0", "-e", "LEDGER_SDK_ROOT=/qa202-sdk", "-e", "LEDGER_CUCUMBER=12.0.1",
        "-e", "PERF_OUTPUT_DIR=/evidence/performance-mode-verified",
        image, "ruby", "/evidence/perf_child.rb", arm, mode, (round + 1).to_s]
      output, error, status = Open3.capture3(*args)
      File.write(File.join(dir, "#{arm}-#{mode}-#{round + 1}.log"), output + error)
      abort "Performance child failed: #{arm}/#{mode}: #{error}" unless status.success?
      puts output
      $stdout.flush
    end
  end
end
