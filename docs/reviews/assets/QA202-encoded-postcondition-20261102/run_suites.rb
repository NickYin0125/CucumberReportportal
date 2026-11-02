# frozen_string_literal: true

require "fileutils"
require "open3"
require "json"

%w[HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy].each { |key| ENV.delete(key) }
ENV["PATH"] = "/tools:#{ENV.fetch('PATH')}"
ENV["HELM_BIN"] = "/tools/helm"
ENV["DOCKER_CONFIG"] = "/tmp/review-docker"
FileUtils.mkdir_p("/tmp/review-docker/cli-plugins")
FileUtils.ln_sf("/tools/docker-compose", "/tmp/review-docker/cli-plugins/docker-compose")
cell = ENV.fetch("REVIEW_CELL", "ruby33")
directory = "/evidence/#{cell}"
FileUtils.mkdir_p(directory)
ENV["CUCUMBER_PUBLISH_QUIET"] = "true"
ENV["LANG"] = "C.UTF-8"
ENV["BUNDLE_IGNORE_CONFIG"] = "true"
ENV["BUNDLE_FROZEN"] = "true"
ENV["BUNDLE_PATH"] = "/bundle"
ENV["BUNDLE_SILENCE_ROOT_WARNING"] = "true"
abort "Cannot trust isolated test snapshot" unless system("git", "config", "--global", "--add", "safe.directory", "/work")

result = { ruby: RUBY_DESCRIPTION, source_manifest: JSON.parse(File.read("/evidence/fixed-source-manifest.json"))["manifest_sha256"], commands: [] }
{
  "rspec" => ["bundle", "exec", "rspec", "--format", "progress", "--format", "json", "--out", "#{directory}/rspec.json"],
  "cucumber" => ["bundle", "exec", "cucumber"],
  "release" => ["bundle", "exec", "rspec", "script/release/spec"]
}.each do |label, argv|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  status = nil
  File.open("#{directory}/#{label}.log", "w") do |file|
    Open3.popen2e(*argv, chdir: "/work") do |input, output, worker|
      input.close
      IO.copy_stream(output, file)
      status = worker.value
    end
  end
  result[:commands] << { label: label, argv: argv, exit: status.exitstatus, seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started }
  puts "#{label}: #{status.exitstatus}"
  $stdout.flush
end
File.write("#{directory}/result.json", JSON.pretty_generate(result) + "\n")
exit(result[:commands].all? { |c| c[:exit].zero? } ? 0 : 1)
