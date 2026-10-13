#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "open3"
require "fileutils"
require "json"
require "time"
require "rbconfig"
require "securerandom"
require "tmpdir"
require_relative "source_manifest"

root = File.expand_path("../..", __dir__)
base = ENV.fetch("DAY2_EVIDENCE_DIR", File.join(Dir.tmpdir, "reportportal-day2-faults"))
directory = File.join(base, "local-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}-#{SecureRandom.hex(3)}")
FileUtils.mkdir_p(directory, mode: 0o700)
before = Day2Faults::SourceManifest.capture
args = [RbConfig.ruby, "-rbundler/setup", "-Ilib", "-Ispec", "-rrspec/core", "-e",
        "exit RSpec::Core::Runner.run(ARGV)", "--", "spec/day2/fault_proxy_spec.rb", "spec/day2/fault_process_spec.rb",
        "spec/day2/fault_live_gate_spec.rb", "spec/day2/fault_live_validation_spec.rb",
        "--format", "documentation", "--format", "json", "--out", File.join(directory, "rspec.json")]
env = ENV.keys.grep(/\A(?:RP_|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|http_proxy|https_proxy|all_proxy)/).to_h { |key| [key, nil] }
env["DAY2_LOCAL_CAPTURE"] = directory
stdout, stderr, status = Open3.capture3(env, *args, chdir: root)
source = Day2Faults::SourceManifest.record(directory: directory, before: before)
File.open(File.join(directory, "stdout.log"), "wb", 0o600) { |file| file.write(stdout) }
File.open(File.join(directory, "stderr.log"), "wb", 0o600) { |file| file.write(stderr) }
puts stdout
warn stderr unless stderr.empty?
puts "Sanitized local evidence: #{directory}"
exit(source.fetch(:unchanged_during_run) ? (status.exitstatus || 1) : 1)
