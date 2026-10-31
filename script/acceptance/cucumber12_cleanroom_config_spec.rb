#!/usr/bin/env ruby
# frozen_string_literal: true

# Host-only harness tests. Synthetic gem metadata is never installed or executed.
require "fileutils"
require "open3"
require "rbconfig"
require "stringio"
require "tmpdir"
require_relative "cucumber12_cleanroom"
require_relative "cucumber12_cleanroom_payload"
require_relative "cucumber12_cleanroom_verify"

module CleanroomHostTests
  module_function

  def check(name)
    yield
    @passed = (@passed || 0) + 1
    puts "PASS #{name}"
  end

  def assert(condition, message = "assertion failed")
    raise message unless condition
  end

  def refuses(pattern)
    begin
      yield
    rescue ArgumentError, RuntimeError, SystemCallError => error
      assert(error.message.match?(pattern), "Unexpected rejection: #{error.message}")
      return
    end
    raise "Expected refusal: #{pattern}"
  end

  def gem_archive(directory, name: "reportportal-cucumber-ruby", version: "2.0.0", changed_dependency: false, omit_entrypoint: nil)
    original = $stdout
    files = Cucumber12CleanroomAudit::REQUIRED_ENTRYPOINTS - Array(omit_entrypoint)
    files.each do |relative|
      path = File.join(directory, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "# Synthetic host-only fixture: #{relative}\n")
    end
    spec = Gem::Specification.new do |gem|
      gem.name = name
      gem.version = version
      gem.authors = ["Harness self-test"]
      gem.summary = "Synthetic metadata fixture, never a release candidate"
      gem.license = "MIT"
      gem.homepage = "https://example.invalid"
      gem.required_ruby_version = ">= 3.3"
      gem.files = files
      gem.bindir = "exe"
      gem.executables = ["reportportal-spool"]
      Cucumber12Cleanroom::Config::RUNTIME_CONTRACT.each do |dependency, requirements|
        gem.add_runtime_dependency(dependency, *(changed_dependency && dependency == "logger" ? [">= 99"] : requirements.split(", ")))
      end
    end
    $stdout = StringIO.new
    Dir.chdir(directory) { Gem::Package.build(spec, true) }
    File.join(directory, "#{name}-#{version}.gem")
  ensure
    $stdout = original
  end

  def tree_digest(directory)
    files = Dir[File.join(directory, "**/*")].select { |path| File.file?(path) }.sort
    Digest::SHA256.hexdigest(files.map { |path| path.delete_prefix(directory + "/") + "\0" + Digest::SHA256.file(path).hexdigest }.join("\n"))
  end

  def run
    root = Cucumber12Cleanroom::ROOT
    baseline = File.join(root, "tmp/cucumber12-independent/cleanroom/20261031T030934Z-17bff3")
    before = tree_digest(baseline) if File.directory?(baseline)
    Dir.mktmpdir("cucumber12-host-only-") do |scratch|
      legacy = File.join(scratch, Cucumber12Cleanroom::Config::LEGACY_PATH)
      FileUtils.mkdir_p(File.dirname(legacy))
      FileUtils.cp(File.join(root, Cucumber12Cleanroom::Config::LEGACY_PATH), legacy)
      candidate = gem_archive(scratch)
      renamed = File.join(scratch, "postfix candidate arbitrary-name.gem")
      FileUtils.mv(candidate, renamed)
      env = { "CLEANROOM_CANDIDATE_ARCHIVE" => renamed, "CLEANROOM_CANDIDATE_SHA256" => Digest::SHA256.file(renamed).hexdigest }
      config = Cucumber12Cleanroom::Config.new(env, root: scratch)
      check("explicit candidate path/hash accepted; fixed legacy preserved") do
        assert(config.hashes.fetch("1.3.1") == Cucumber12Cleanroom::Config::LEGACY_SHA)
        assert(config.manifest.fetch("2.0.0").fetch(:path) == File.realpath(renamed))
        assert(config.candidate_kind == "candidate" && config.latest_pointer == "latest-postfix.json")
        legacy_files = config.manifest.fetch("1.3.1").fetch(:required_entrypoints)
        assert(!legacy_files.include?("lib/reportportal_cucumber/cucumber/parallel_formatter.rb"))
      end
      check("missing/partial input fails closed") do
        [{}, env.reject { |key, _| key.end_with?("ARCHIVE") }, env.reject { |key, _| key.end_with?("SHA256") }].each do |bad|
          refuses(/Set BOTH/) { Cucumber12Cleanroom::Config.new(bad, root: scratch) }
        end
      end
      check("malformed/uppercase/mismatched hashes rejected") do
        ["A" * 64, "0" * 63, env.fetch("CLEANROOM_CANDIDATE_SHA256") + "\n", "f" * 64].each do |sha|
          refuses(/exactly 64|SHA-256 mismatch/) { Cucumber12Cleanroom::Config.new(env.merge("CLEANROOM_CANDIDATE_SHA256" => sha), root: scratch) }
        end
      end
      check("baseline hash requires matching bytes, not a global blacklist") do
        refuses(/SHA-256 mismatch/) { Cucumber12Cleanroom::Config.new(env.merge("CLEANROOM_CANDIDATE_SHA256" => Cucumber12Cleanroom::Config::BASELINE_SHA), root: scratch) }
      end
      baseline_archive = File.join(baseline, "tc17-ruby33/inputs/reportportal-cucumber-ruby-2.0.0.gem")
      if File.file?(baseline_archive)
        check("explicit baseline metadata accepted for future reproduction, never executed") do
          baseline_env = env.merge("CLEANROOM_CANDIDATE_ARCHIVE" => baseline_archive,
                                   "CLEANROOM_CANDIDATE_SHA256" => Cucumber12Cleanroom::Config::BASELINE_SHA)
          reproduction = Cucumber12Cleanroom::Config.new(baseline_env, root: scratch)
          assert(reproduction.candidate_kind == "baseline")
          assert(reproduction.latest_pointer == "latest-baseline-reproduction.json")
          assert(reproduction.hashes.fetch("2.0.0") == Cucumber12Cleanroom::Config::BASELINE_SHA)
        end
      end
      check("wrong package identity/version/runtime contract rejected") do
        [{ name: "not-the-sdk" }, { version: "2.0.1" }, { changed_dependency: true }].each do |options|
          path = gem_archive(scratch, **options)
          bad = env.merge("CLEANROOM_CANDIDATE_ARCHIVE" => path, "CLEANROOM_CANDIDATE_SHA256" => Digest::SHA256.file(path).hexdigest)
          refuses(/identity|contract changed/) { Cucumber12Cleanroom::Config.new(bad, root: scratch) }
        end
      end
      check("archive must declare required entrypoints without a fixed payload count") do
        path = gem_archive(scratch, omit_entrypoint: "lib/reportportal_cucumber.rb")
        bad = env.merge("CLEANROOM_CANDIDATE_ARCHIVE" => path, "CLEANROOM_CANDIDATE_SHA256" => Digest::SHA256.file(path).hexdigest)
        refuses(/Required SDK entrypoints absent/) { Cucumber12Cleanroom::Config.new(bad, root: scratch) }
        assert(config.manifest.fetch("2.0.0").fetch(:payload_files) == Cucumber12CleanroomAudit::REQUIRED_ENTRYPOINTS.size)
      end
      check("installed entrypoints must exist, be declared and resolve inside the gem") do
        installed = File.join(scratch, "installed-fixture")
        required = Cucumber12CleanroomAudit::REQUIRED_ENTRYPOINTS
        required.each do |relative|
          path = File.join(installed, relative)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, "host-only installed fixture\n")
        end
        checks = Cucumber12CleanroomAudit.entrypoint_checks(installed, declared_files: required)
        assert(checks.values.all? { |check| check.values_at(:declared, :regular_file, :within_gem).all? && check[:sha256] })
        core = File.join(installed, required.first)
        File.unlink(core)
        missing = Cucumber12CleanroomAudit.entrypoint_checks(installed, declared_files: required).fetch(required.first)
        assert(!missing[:regular_file] && !missing[:within_gem] && missing[:sha256].nil?)
        File.symlink(legacy, core)
        escaped = Cucumber12CleanroomAudit.entrypoint_checks(installed, declared_files: required).fetch(required.first)
        assert(escaped[:regular_file] && !escaped[:within_gem] && escaped[:sha256].nil?)
        undeclared = Cucumber12CleanroomAudit.entrypoint_checks(installed, declared_files: []).fetch(required.last)
        assert(!undeclared[:declared])
      end
      check("legacy cannot be replaced or overridden") do
        original = File.binread(legacy)
        begin
          File.binwrite(legacy, "invalid legacy fixture")
          refuses(/SHA-256 mismatch/) { Cucumber12Cleanroom::Config.new(env, root: scratch) }
        ensure
          File.binwrite(legacy, original)
        end
      end
      runner = Cucumber12Cleanroom::Runner.allocate
      runner.instance_variable_set(:@config, config)
      runner.instance_variable_set(:@directory, File.join(scratch, "staging"))
      check("arbitrary basename canonicalized and staging hash checked") do
        input, = runner.stage("consumer", versions: ["2.0.0"])
        path = File.join(input, config.filename("2.0.0"))
        assert(File.file?(path) && Digest::SHA256.file(path).hexdigest == env.fetch("CLEANROOM_CANDIDATE_SHA256"))
        assert((File.stat(path).mode & 0o222).zero?)
        assert(Cucumber12CleanroomPayload.verify_input_packages!(input).fetch(File.basename(path)) == env.fetch("CLEANROOM_CANDIDATE_SHA256"))
      end
      check("registry stages and validates BOTH exact package versions") do
        input, = runner.stage("registry", versions: %w[2.0.0 1.3.1])
        staged = Cucumber12CleanroomPayload.verify_input_packages!(input)
        assert(staged.size == 2)
        config.hashes.each { |version, sha| assert(staged.fetch(config.filename(version)) == sha) }
        candidate_copy = File.join(input, config.filename("2.0.0"))
        File.chmod(0o600, candidate_copy)
        File.binwrite(candidate_copy, "corrupt staged fixture")
        refuses(/SHA-256 mismatch/) { Cucumber12CleanroomPayload.verify_input_packages!(input) }
      end
      check("source replacement between preflight/staging rejected") do
        original = File.binread(renamed)
        begin
          File.binwrite(renamed, original + "changed")
          refuses(/SHA-256 mismatch/) { runner.stage("raced", versions: ["2.0.0"]) }
        ensure
          File.binwrite(renamed, original)
        end
      end
      check("baseline verifier cannot rewrite old evidence") do
        path = File.join(scratch, "old-summary.json")
        File.write(path, JSON.generate(source_head: "old"))
        refuses(/read-only/) { Cucumber12CleanroomVerify.verify(path, config: config, write: true) }
        assert(!File.exist?(File.join(scratch, "verification.json")))
      end
      check("sealed reports cannot be overwritten") do
        path = File.join(scratch, "summary.json")
        File.write(path, JSON.generate(schema_version: 2))
        report = File.join(scratch, "report.md")
        File.write(report, "immutable fixture")
        refuses(/already sealed/) { Cucumber12CleanroomVerify.verify(path, config: config, write: true) }
        assert(File.read(report) == "immutable fixture")
      end
      check("private HTTP path traversal, NUL and symlink escapes rejected") do
        registry = File.join(scratch, "registry")
        FileUtils.mkdir_p(registry)
        File.write(File.join(registry, "with+plus.gem"), "fixture")
        File.symlink(renamed, File.join(registry, "escape.gem"))
        assert(Cucumber12CleanroomPayload.registry_path("/with+plus.gem?x=1", registry) == File.realpath(File.join(registry, "with+plus.gem")))
        ["/../#{File.basename(renamed)}", "/%2e%2e/#{File.basename(renamed)}", "/%00", "/escape.gem", "/absent"].each do |target|
          assert(Cucumber12CleanroomPayload.registry_path(target, registry).nil?)
        end
      end
      check("preflight runs without Docker; missing config exits before evidence creation") do
        program = File.join(root, "script/acceptance/cucumber12_cleanroom.rb")
        evidence_before = Dir[File.join(Cucumber12Cleanroom::EVIDENCE, "*")].sort
        child_env = env.merge("PATH" => "/no-docker", "HOME" => scratch)
        stdout, stderr, status = Open3.capture3(child_env, RbConfig.ruby, program, "--preflight", unsetenv_others: true)
        assert(status.success?, stderr)
        assert(JSON.parse(stdout).fetch("scope").include?("HOST PREFLIGHT ONLY"))
        _, stderr, status = Open3.capture3({ "PATH" => "/no-docker" }, RbConfig.ruby, program, unsetenv_others: true)
        assert(status.exitstatus == 2 && stderr.include?("Set BOTH"), stderr)
        assert(Dir[File.join(Cucumber12Cleanroom::EVIDENCE, "*")].sort == evidence_before)
      end
    end
    check("accepted baseline tree unchanged byte-for-byte") { assert(before == tree_digest(baseline)) } if before
    puts "#{@passed} host-only harness checks passed. No containers, installs or TC17/18 rerun."
  end
end

CleanroomHostTests.run if $PROGRAM_NAME == __FILE__
