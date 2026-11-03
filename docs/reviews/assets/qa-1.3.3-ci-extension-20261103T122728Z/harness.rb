# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "time"
require "yaml"

def write_json(path, value)
  File.write(path, JSON.pretty_generate(value) + "\n")
end

def hashes(root, paths)
  paths.sort.to_h { |path| [path, Digest::SHA256.file(File.join(root, path)).hexdigest] }
end

if ARGV.delete("--package-child")
  require "rubygems/package"
  label = ENV.fetch("QA_LABEL")
  source = "/#{label}"
  output = "/evidence"
  Dir.chdir(source) do
    specification = Gem::Specification.load("reportportal-cucumber-ruby.gemspec")
    raise "Wrong package SDK" unless specification.version.to_s == "1.3.3"
    original = hashes(source, specification.files)
    archive = File.join(output, "#{label}.gem")
    Gem::Package.build(specification, false, false, archive)
    package = Gem::Package.new(archive)
    extracted = File.join(output, "#{label}-package-source")
    package.extract_files(extracted)
    packaged = hashes(extracted, package.contents)
    raise "Package payload differs from declared files" unless original == packaged
    write_json(File.join(output, "package-#{label}.json"),
      label: label, ruby: RUBY_DESCRIPTION, rubygems: Gem::VERSION,
      source_date_epoch: ENV.fetch("SOURCE_DATE_EPOCH"),
      gemspec_sha256: Digest::SHA256.file("reportportal-cucumber-ruby.gemspec").hexdigest,
      declared_files: original, packaged_files: packaged,
      package_metadata_yaml: package.spec.to_yaml,
      package_metadata_sha256: Digest::SHA256.hexdigest(package.spec.to_yaml),
      archive_sha256: Digest::SHA256.file(archive).hexdigest,
      lib_sha256: hashes(source, Dir["lib/**/*.rb"]),
      package_verified: true)
  end
  exit
end

if ARGV.delete("--narrow-child")
  require "/qa/preflight"
  output = "/evidence"
  source = "/candidate"
  runtime = "/tmp/qa-ci-runtime"
  FileUtils.mkdir_p(runtime)
  ENV["PATH"] = "/tools:#{ENV.fetch('PATH')}"
  ENV["HELM_BIN"] = "/tools/helm"
  tools = QA1xPreflight.tools(expected_ruby: ENV.fetch("QA_RUBY"))
  write_json(File.join(output, "tool-preflight.json"), tools)
  FileUtils.cp_r("/bundle", "/tmp/qa-ci-bundle")
  gemfile = File.join(runtime, "Gemfile")
  File.write(gemfile, "eval_gemfile \"/candidate/Gemfile\"\ngem \"cucumber\", \"= #{ENV.fetch('QA_CUCUMBER')}\"\ngem \"cucumber-cucumber-expressions\", \">= 17\", \"< 19\"\ngem \"diff-lcs\", \"< 2\"\n")
  ENV["BUNDLE_GEMFILE"] = gemfile
  ENV["BUNDLE_PATH"] = "/tmp/qa-ci-bundle"
  ENV["BUNDLE_IGNORE_CONFIG"] = "1"
  ENV["BUNDLE_FROZEN"] = "false"
  ENV["BUNDLE_SILENCE_ROOT_WARNING"] = "1"
  commands = []
  run = lambda do |label, *argv|
    commands << { label: label, argv: argv }
    raise "#{label} failed" unless system(*argv, chdir: source, out: File.join(output, "#{label}.log"), err: [:child, :out])
  end
  run.call("bundle-install", "bundle", "_2.6.6_", "install", "--local")
  FileUtils.cp(gemfile, File.join(output, "Gemfile.resolved"))
  FileUtils.cp(gemfile + ".lock", File.join(output, "Gemfile.resolved.lock"))
  run.call("runtime", "bundle", "_2.6.6_", "exec", "ruby", "-rjson", "-e",
    'require "reportportal_cucumber"; puts JSON.generate(ruby: RUBY_DESCRIPTION, sdk: ReportportalCucumber::VERSION, gems: Gem.loaded_specs.sort.to_h.transform_values { |s| s.version.to_s })')
  run.call("workflow-regression", "bundle", "_2.6.6_", "exec", "rspec", "spec/release/workflows_spec.rb",
    "--format", "documentation", "--format", "json", "--out", File.join(output, "workflow-regression.json"))
  summary = JSON.parse(File.read(File.join(output, "workflow-regression.json"))).fetch("summary")
  raise "Unexpected narrow result" unless summary.fetch("example_count") == 15 &&
    %w[failure_count pending_count errors_outside_of_examples_count].all? { |key| summary.fetch(key).zero? }
  write_json(File.join(output, "result.json"), status: "PASS", kind: "whole workflow spec file only; not full SDK matrix",
    summary: summary, runtime: JSON.parse(File.read(File.join(output, "runtime.log"))), commands: commands)
  exit
end

source = "/Users/nick/Documents/crr-1.3.3"
root = File.expand_path("../..", __dir__)
base = "68e81d3697965305438be4fa27aa98aeb4baf726"
candidate = "69aaedecd10a3ac01d7ad90b96e2db1b60343344"
out = ARGV.fetch(0) { File.join(root, "docs/reviews/assets/qa-1.3.3-ci-extension-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}") }
abort "Fresh absolute evidence path required" if !out.start_with?(root + "/") || File.exist?(out)
git = lambda do |*argv|
  stdout, stderr, status = Open3.capture3("git", "-C", source, *argv)
  raise stderr unless status.success?
  stdout
end
raise "Wrong CI source HEAD" unless git.call("rev-parse", "HEAD").strip == candidate
raise "SDK source not clean" unless git.call("status", "--porcelain").empty?
changed = git.call("diff", "--name-only", base, candidate).lines(chomp: true)
raise "Changes exceed CI-only scope" unless changed.sort == %w[.github/workflows/validate.yml spec/release/workflows_spec.rb].sort
historical_report = File.join(root, "docs/reviews/2026-11-03-maintenance-1.3.3-final-acceptance.md")
historical_sha = Digest::SHA256.file(historical_report).hexdigest
FileUtils.mkdir_p(out)
FileUtils.cp(__FILE__, File.join(out, "harness.rb"))
File.write(File.join(out, "reviewed-diff.txt"), git.call("diff", base, candidate))
%w[baseline candidate].zip([base, candidate]).each do |label, sha|
  destination = File.join(out, label + "-source")
  FileUtils.mkdir_p(destination)
  statuses = Open3.pipeline(["git", "-C", source, "archive", sha], ["tar", "-xf", "-", "-C", destination])
  raise "Frozen source export failed" unless statuses.all?(&:success?)
end

# Execute the real pre-setup shell and manifest generator without installing gems.
ordering = %w[baseline candidate].map do |label|
  require "tmpdir"
  exported = File.join(out, label + "-source")
  workflow = YAML.load_file(File.join(exported, ".github/workflows/validate.yml"))
  steps = workflow.dig("jobs", "test", "steps")
  isolation = steps.find { |step| step["name"] == "Isolate matrix dependencies before Ruby setup" }
  resolution = steps.find { |step| step["name"] == "Resolve the exact matrix runtime without changing source" }
  Dir.mktmpdir("qa-ci-order-") do |temporary|
    environment_file = File.join(temporary, "github-env")
    env = { "PATH" => "#{File.dirname(RbConfig.ruby)}:/usr/bin:/bin", "HOME" => temporary,
      "RUNNER_TEMP" => temporary, "GITHUB_ENV" => environment_file, "GITHUB_WORKSPACE" => exported,
      "CUCUMBER_VERSION" => "9.2.1" }
    stdout, stderr, status = Open3.capture3(env, "/bin/bash", "-e", "-o", "pipefail", "-c", isolation.fetch("run"), chdir: exported, unsetenv_others: true)
    raise "Isolation shell failed: #{stdout} #{stderr}" unless status.success?
    published = File.readlines(environment_file, chomp: true).to_h { |line| line.split("=", 2) }
    selected = published.fetch("BUNDLE_GEMFILE", File.join(exported, "Gemfile"))
    exists = File.file?(selected)
    if label == "baseline"
      raise "Old failure control unexpectedly safe" if exists
    else
      raise "New setup sees nonexistent Gemfile" unless exists && !published.key?("BUNDLE_GEMFILE")
      generator = resolution.fetch("run").split("bundle install --jobs 4", 2).first
      stdout, stderr, status = Open3.capture3(env, "/bin/bash", "-e", "-o", "pipefail", "-c", generator, chdir: exported, unsetenv_others: true)
      raise "Generator failed: #{stdout} #{stderr}" unless status.success?
      after = File.readlines(environment_file, chomp: true).to_h { |line| line.split("=", 2) }
      raise "Manifest published before existence" unless File.file?(after.fetch("BUNDLE_GEMFILE"))
    end
    { label: label, setup_selected_path: selected, existed_at_setup: exists,
      old_error_control: exists ? nil : "Error: $BUNDLE_GEMFILE is set to #{selected} but does not exist",
      private_manifest_published_only_after_creation: label == "candidate" }
  end
end
write_json(File.join(out, "ordering-probe.json"), ordering)

images = JSON.parse(File.read(File.join(__dir__, "environment/images.json")))
epoch = git.call("show", "-s", "--format=%ct", base).strip
docker = lambda do |label, image, arguments, mounts = []|
  argv = ["/usr/local/bin/docker", "run", "--rm", "--network", "none", "--cpus", "1", "--memory", "3g",
    "-v", "#{__dir__}:/qa:ro", *mounts, *arguments, image]
  yield_argv = argv + ["ruby", "/qa/ci_extension.rb"]
  yield_argv
end
%w[baseline candidate].each do |label|
  argv = docker.call(label, images.fetch("3.3").fetch("image"), ["-e", "QA_LABEL=#{label}", "-e", "SOURCE_DATE_EPOCH=#{epoch}"],
    ["-v", "#{out}/#{label}-source:/#{label}:ro", "-v", "#{out}:/evidence"])
  argv << "--package-child"
  write_json(File.join(out, "package-#{label}-command.json"), argv)
  raise "Package proof failed" unless system(*argv, out: File.join(out, "package-#{label}.log"), err: [:child, :out])
end
baseline = JSON.parse(File.read(File.join(out, "package-baseline.json")))
ci = JSON.parse(File.read(File.join(out, "package-candidate.json")))
identity_keys = %w[gemspec_sha256 declared_files packaged_files package_metadata_yaml package_metadata_sha256 archive_sha256 lib_sha256]
raise "Delivered package inputs differ" unless identity_keys.all? { |key| baseline.fetch(key) == ci.fetch(key) }
accepted = JSON.parse(File.read(File.join(root, "docs/reviews/assets/qa-1.3.3-final-source-proof.json")))
accepted_hashes = accepted.fetch("library_hashes").to_h { |path, value| [path, value.fetch("candidate_sha256")] }
raise "Historical accepted library inventory differs" unless ci.fetch("lib_sha256") == accepted_hashes

%w[3.1 3.3].zip(%w[9.2.1 10.2.0]).each do |ruby, cucumber|
  evidence = File.join(out, "ruby-#{ruby}")
  FileUtils.mkdir_p(evidence)
  argv = docker.call(ruby, images.fetch(ruby).fetch("image"), ["-e", "QA_RUBY=#{ruby}", "-e", "QA_CUCUMBER=#{cucumber}"],
    ["-v", "#{out}/candidate-source:/candidate:ro", "-v", "#{evidence}:/evidence",
     "-v", "/private/tmp/ledger-matrix-bundles/ruby#{ruby.delete('.')}:/bundle:ro",
     "-v", "/private/tmp/ledger-pinned-tools/linux-arm64:/tools:ro"])
  argv << "--narrow-child"
  write_json(File.join(evidence, "container-command.json"), argv)
  raise "Narrow workflow regression failed" unless system(*argv, out: File.join(evidence, "container.log"), err: [:child, :out])
end
raise "Historical report changed" unless Digest::SHA256.file(historical_report).hexdigest == historical_sha
raise "SDK changed during review" unless git.call("status", "--porcelain").empty? && git.call("rev-parse", "HEAD").strip == candidate
write_json(File.join(out, "local-extension.json"), accepted_runtime_sha: base, ci_sha: candidate,
  changed_paths: changed, historical_report_sha256_before_after: historical_sha,
  historical_report_unchanged: true, sdk_clean_before_after: true,
  declared_package_files: ci.fetch("declared_files").length, library_files: ci.fetch("lib_sha256").length,
  byte_identity_keys: identity_keys, deterministic_archive_sha256: ci.fetch("archive_sha256"),
  deterministic_epoch: epoch, deterministic_comparison_not_original_live_archive_hash: true,
  narrow_workflow_examples: { "3.1" => 15, "3.3" => 15 }, status: "LOCAL_CI_EXTENSION_PASS_REMOTE_PENDING",
  runtime_live_performance_replayed: false, no_sdk_edits_or_commits: true)
puts "QA_CI_EXTENSION_EVIDENCE=#{out}"
