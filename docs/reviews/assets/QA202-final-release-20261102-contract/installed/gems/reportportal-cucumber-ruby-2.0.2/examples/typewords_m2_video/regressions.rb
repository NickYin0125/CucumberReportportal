# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "time"

root = File.expand_path("../..", __dir__)
results = ENV.fetch("M2_VIDEO_RESULTS_DIR", File.join(root, "tmp", "m2-typewords-video"))
FileUtils.mkdir_p(results)
checks = {}
{
  "rspec" => ["bundle", "exec", "rspec"],
  "cucumber" => ["bundle", "exec", "cucumber"],
  "diff-check" => ["git", "diff", "--check"]
}.each do |name, command|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  output, status = Open3.capture2e({ "BUNDLE_GEMFILE" => File.join(root, "Gemfile") }, *command, chdir: root)
  File.write(File.join(results, "#{name}.log"), output)
  checks[name] = {
    command: command, exit_status: status.exitstatus,
    elapsed_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1_000).round(3),
    output_file: "#{name}.log"
  }
  puts "#{name}: exit #{status.exitstatus}"
  puts output.lines.last(5).join unless output.empty?
end
File.write(File.join(results, "regression-results.json"), JSON.pretty_generate(observed_at_utc: Time.now.utc.iso8601, checks: checks))
raise "Repository regression failed" unless checks.values.all? { |check| check[:exit_status] == 0 }
