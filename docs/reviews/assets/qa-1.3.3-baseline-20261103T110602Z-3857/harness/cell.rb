# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "time"

OUT = "/evidence"
SOURCE = "/tmp/qa-1x-source"
RUNTIME = "/tmp/qa-1x-runtime"
FileUtils.mkdir_p([OUT, RUNTIME])
result = { phase: ENV.fetch("QA_PHASE"), sha: ENV.fetch("QA_SHA"), scope: ENV.fetch("QA_SCOPE"), commands: [] }
result[:harness_sha256] = Dir["/qa/*"].select { |path| File.file?(path) }.sort.to_h do |path|
  [File.basename(path), Digest::SHA256.file(path).hexdigest]
end

def run(result, label, *argv, required: true, chdir: SOURCE)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  status = nil
  File.open(File.join(OUT, "#{label}.log"), "w") do |log|
    Open3.popen2e(*argv, chdir: chdir) do |input, output, process|
      input.close
      IO.copy_stream(output, log)
      status = process.value
    end
  end
  result[:commands] << { label: label, argv: argv, exit: status.exitstatus,
    seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - start }
  raise "#{label} failed; inspect #{label}.log" if required && !status.success?
  status.success?
end

def fingerprint(root)
  Dir[File.join(root, "lib/**/*.rb")].sort.to_h do |path|
    [path.delete_prefix(root + "/"), Digest::SHA256.file(path).hexdigest]
  end
end

begin
  ENV.keys.grep(/\ARP_/).each { |key| ENV.delete(key) }
  ENV["CUCUMBER_PUBLISH_QUIET"] = "true"
  ENV["CUCUMBER_PUBLISH_ENABLED"] = "false"
  ENV["NO_COLOR"] = "1"
  FileUtils.cp_r("/source", SOURCE)
  before = fingerprint("/source")
  raise "Library staging differs" unless before == fingerprint(SOURCE)
  result[:lib_sha256] = before
  result[:original_gemfile_lock_sha256] = Digest::SHA256.file(File.join(SOURCE, "Gemfile.lock")).hexdigest
  # The dependency manifest is outside both SDK checkouts and their lockfiles.
  gemfile = File.join(RUNTIME, "Gemfile")
  File.write(gemfile, <<~GEMFILE)
    eval_gemfile #{File.join(SOURCE, "Gemfile").inspect}
    gem "cucumber", "= #{ENV.fetch('QA_CUCUMBER')}"
    gem "cucumber-cucumber-expressions", ">= 17", "< 19"
    gem "diff-lcs", "< 2"
  GEMFILE
  FileUtils.cp_r("/bundle", "/tmp/qa-1x-bundle")
  ENV["BUNDLE_GEMFILE"] = gemfile
  ENV["BUNDLE_PATH"] = "/tmp/qa-1x-bundle"
  ENV["BUNDLE_IGNORE_CONFIG"] = "1"
  ENV["BUNDLE_FROZEN"] = "false"
  ENV["BUNDLE_SILENCE_ROOT_WARNING"] = "1"
  ENV["BUNDLE_JOBS"] = "1"
  run(result, "git-safe", "git", "config", "--global", "--add", "safe.directory", SOURCE)
  run(result, "source-head", "git", "rev-parse", "HEAD")
  raise "Wrong source HEAD" unless File.read(File.join(OUT, "source-head.log")).strip == result.fetch(:sha)
  if Gem::Specification.find_all_by_name("bundler", "= 2.6.6").empty?
    run(result, "bundler-install", "gem", "install", "bundler", "-v", "2.6.6", "--no-document")
  end
  run(result, "bundle-install", "bundle", "_2.6.6_", "install", "--local")
  FileUtils.cp(gemfile, File.join(OUT, "Gemfile.resolved"))
  FileUtils.cp(gemfile + ".lock", File.join(OUT, "Gemfile.resolved.lock"))
  run(result, "runtime", "bundle", "_2.6.6_", "exec", "ruby", "-e",
    "require 'json'; require 'reportportal_cucumber'; puts JSON.generate(ruby: RUBY_DESCRIPTION, sdk: ReportportalCucumber::VERSION, gems: Gem.loaded_specs.sort.to_h.transform_values { |s| s.version.to_s })")
  result[:runtime] = JSON.parse(File.read(File.join(OUT, "runtime.log")))
  expected_sdk = result.fetch(:phase) == "baseline" ? "1.3.2" : "1.3.3"
  raise "Wrong SDK version" unless result.dig(:runtime, "sdk") == expected_sdk
  raise "Wrong Ruby runtime" unless RUBY_VERSION.start_with?(ENV.fetch("QA_RUBY") + ".")
  raise "Wrong Cucumber runtime" unless result.dig(:runtime, "gems", "cucumber") == ENV.fetch("QA_CUCUMBER")
  raise "Wrong expressions runtime" unless Gem::Version.new(result.dig(:runtime, "gems", "cucumber-cucumber-expressions")) < Gem::Version.new("19")
  ENV["QA_SOURCE"] = SOURCE
  target = run(result, "targeted", "bundle", "_2.6.6_", "exec", "rspec", "/qa/targeted_spec.rb",
    "--format", "documentation", "--format", "json", "--out", File.join(OUT, "targeted.json"), required: false)
  result[:targeted] = JSON.parse(File.read(File.join(OUT, "targeted.json"))).fetch("summary")
  if ENV["QA_SETUP_BENCH"] == "1"
    ENV["QA_BENCH_OUT"] = File.join(OUT, "setup-bench.json")
    ENV["QA_BENCH_LABEL"] = "#{result.fetch(:phase)}-setup-diagnostic"
    ENV["QA_BENCH_ITERATIONS"] = "100"
    run(result, "setup-bench", "bundle", "_2.6.6_", "exec", "ruby", "/qa/bench.rb")
  end
  if result.fetch(:scope) == "full"
    ENV["PATH"] = "/tools:#{ENV.fetch('PATH')}"
    ENV["HELM_BIN"] = "/tools/helm"
    manifest = JSON.parse(File.read("/tools/manifest.json"))
    %w[helm docker docker-compose].each do |name|
      raise "Changed #{name} tool" unless Digest::SHA256.file("/tools/#{name}").hexdigest == manifest.fetch(name).fetch("sha256")
    end
    result[:tools] = manifest
    ENV["DOCKER_CONFIG"] = "/tmp/qa-docker-config"
    FileUtils.mkdir_p("/tmp/qa-docker-config/cli-plugins")
    FileUtils.ln_s("/tools/docker-compose", "/tmp/qa-docker-config/cli-plugins/docker-compose")
    FileUtils.mkdir_p(File.join(SOURCE, "helm/reportportal-rich-experience/charts"))
    FileUtils.cp_r(Dir["/charts/*"], File.join(SOURCE, "helm/reportportal-rich-experience/charts"))
    ENV["DAY2_LOCAL_CAPTURE"] = File.join(OUT, "faults/day2")
    ENV["M4_D_EVIDENCE_DIR"] = File.join(OUT, "faults/m4d")
    FileUtils.mkdir_p([ENV["DAY2_LOCAL_CAPTURE"], ENV["M4_D_EVIDENCE_DIR"]])
    rspec = run(result, "rspec-full", "bundle", "_2.6.6_", "exec", "rspec", "--format", "progress", "--format", "json", "--out", File.join(OUT, "rspec-full.json"), required: false)
    cucumber = run(result, "cucumber-offline-full", "bundle", "_2.6.6_", "exec", "cucumber", "--format", "progress", "--format", "json", "--out", File.join(OUT, "cucumber-offline-full.json"), required: false)
    result[:rspec_full] = JSON.parse(File.read(File.join(OUT, "rspec-full.json"))).fetch("summary")
    elements = JSON.parse(File.read(File.join(OUT, "cucumber-offline-full.json"))).flat_map { |feature| feature.fetch("elements", []) }
    scenarios = elements.select { |entry| entry["type"] == "scenario" }
    steps = elements.flat_map { |entry| entry.fetch("steps", []) }
    result[:cucumber_offline_full] = { scenarios: scenarios.length, steps: steps.length,
      statuses: steps.group_by { |step| step.dig("result", "status") }.transform_values(&:length) }
    raise "Empty full suite" unless result.dig(:rspec_full, "example_count") >= 889 && scenarios.length.positive?
    result[:full_success] = rspec && cucumber && result.dig(:rspec_full, "pending_count").zero?
  end
  raise "Original lock was changed" unless result.fetch(:original_gemfile_lock_sha256) == Digest::SHA256.file(File.join(SOURCE, "Gemfile.lock")).hexdigest
  raise "Library changed during tests" unless before == fingerprint(SOURCE) && before == fingerprint("/source")
  result[:status] = target && result.fetch(:full_success, true) ? "PASS" : "FAIL"
  result[:baseline_observation_only] = result.fetch(:phase) == "baseline"
rescue StandardError => error
  result[:status] = "ERROR"
  result[:error] = "#{error.class}: #{error.message}"
ensure
  File.write(File.join(OUT, "result.json"), JSON.pretty_generate(result) + "\n")
  puts JSON.generate(result.reject { |key, _| %i[lib_sha256 commands tools].include?(key) })
end
exit(result[:status] == "PASS" || (result[:phase] == "baseline" && result[:status] == "FAIL") ? 0 : 1)
