# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "shellwords"
require "tmpdir"

# A detached source export avoids checking out or mutating the shared worktree.
if $PROGRAM_NAME == __FILE__
  root = File.expand_path("../..", __dir__)
  baseline = "4ca2f770e0a84e83688f165ba04b4db8ef855cf9"
  output = File.expand_path(ARGV.fetch(0))
  FileUtils.mkdir_p(output)
  Dir.mktmpdir("rp-cucumber12-baseline-") do |source|
    archive, error, status = Open3.capture3("git", "archive", baseline, chdir: root)
    abort error unless status.success?
    _, error, status = Open3.capture3("tar", "-x", "-C", source, stdin_data: archive)
    abort error unless status.success?
    chart_cache = File.join(root, "helm/reportportal-rich-experience/charts")
    FileUtils.cp_r(chart_cache, File.join(source, "helm/reportportal-rich-experience")) if File.directory?(chart_cache)
    coverage = File.join(source, "spec/support/cucumber12_coverage.rb")
    FileUtils.cp(File.join(root, "spec/support/cucumber12_coverage.rb"), coverage)
    environment = {
      "BUNDLE_GEMFILE" => File.join(source, "Gemfile"),
      "BUNDLE_IGNORE_CONFIG" => "1", "BUNDLE_FROZEN" => "1",
      "BUNDLE_PATH" => ENV["RP_QA_BASELINE_BUNDLE_PATH"],
      "RP_QA_SOURCE_ROOT" => source, "RP_QA_COVERAGE_DIR" => File.join(output, "coverage"),
      "RUBYOPT" => [ENV["RUBYOPT"], "-r#{coverage}"].compact.join(" ")
    }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    stdout, stderr, status = Open3.capture3(environment, RbConfig.ruby, "-S", "bundle", "exec", "rspec",
                                         "--format", "json", "--out", File.join(output, "rspec.json"), chdir: source)
    File.write(File.join(output, "execution.json"), JSON.pretty_generate(
      source_head: baseline,
      exit: status.exitstatus, seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
      stdout: stdout, stderr: stderr
    ) + "\n")
    puts "Baseline exit=#{status.exitstatus}; evidence=#{output}"
    exit status.exitstatus
  end
end
