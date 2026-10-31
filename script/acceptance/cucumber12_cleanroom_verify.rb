#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "shellwords"
require "time"
require_relative "cucumber12_cleanroom_config"

module Cucumber12CleanroomVerify
  ROOT = File.expand_path("../..", __dir__)
  EXPECTED = {
    "tc17-ruby33" => ["3.3", "2.0.0", "12.0.1"],
    "tc17-ruby34" => ["3.4", "2.0.0", "12.0.1"],
    "tc18-ruby31" => ["3.1", "1.3.1", "9.2.1"],
    "tc18-ruby33" => ["3.3", "2.0.0", "12.0.1"]
  }.freeze

  module_function

  def assert(condition, message)
    raise message unless condition
  end

  def read(path)
    JSON.parse(File.read(path))
  end

  def json_lines(path)
    File.readlines(path).map { |line| JSON.parse(line) }
  end

  def verify(summary_path, config: Cucumber12Cleanroom::Config.new, write: false)
    summary = read(summary_path)
    directory = File.dirname(File.expand_path(summary_path))
    assert(summary["schema_version"] == 2, "Baseline/old-schema evidence is read-only; do not rewrite it")
    if write
      %w[verification.json report.md].each do |name|
        assert(!File.exist?(File.join(directory, name)), "Evidence already sealed: #{name}; use --check-only")
      end
    end
    hashes = config.hashes
    manifest = config.manifest
    assert(summary.fetch("candidate_kind") == config.candidate_kind, "Wrong baseline/candidate label for supplied hash")
    assert(summary.fetch("packages").transform_values { |package| package.fetch("sha256") } == hashes, "Summary/configured package hash mismatch")
    if config.expected_source_head
      assert(summary.fetch("source_head") == config.expected_source_head, "Wrong source revision")
    end
    assert(summary.fetch("cases").map { |item| item.fetch("case") }.sort == EXPECTED.keys.sort, "Missing/duplicate cases")
    assert(summary.values_at("TC17", "TC18") == %w[PASS PASS], "A test case failed")
    assert(!summary.key?("error"), "Runner failed")
    assert(summary.fetch("remaining_owned_resources").empty? && summary.fetch("remaining_owned_networks").empty?, "Owned resources remain")
    assert(summary.fetch("cleanup").size == 6 && summary.fetch("cleanup").all? { |entry| entry.fetch("exit").zero? }, "Incomplete cleanup")
    assert(summary.fetch("package_hashes_after") == hashes, "Source packages changed")
    audit_count = 0
    commands = {}
    summary.fetch("cases").each do |item|
      label = item.fetch("case")
      minor, sdk, cucumber = EXPECTED.fetch(label)
      file_count = manifest.fetch(sdk).fetch(:payload_files)
      evidence = File.join(directory, label, "evidence")
      assert(item.fetch("status") == "PASS" && item.fetch("container_exit") == "0", "#{label}: container failed")
      before = read(File.join(evidence, "before-install.json"))
      patch = before.fetch("ruby")[/\Aruby (\d+\.\d+\.\d+)/, 1]
      assert(patch && patch.start_with?(minor + "."), "#{label}: wrong Ruby series")
      assert(before.fetch("private_gem_home_contents").empty? && before.fetch("work_files").empty?, "#{label}: inherited gems/work files")
      assert(before.fetch("gem_paths") == ["/clean/gems"], "#{label}: inherited gem paths")
      assert((before.fetch("environment").keys & %w[RUBYOPT RUBYLIB BUNDLE_GEMFILE]).empty?, "#{label}: inherited load/bundle settings")
      assert(before.fetch("installed_gems").none? { |spec| %w[cucumber reportportal-cucumber-ruby].include?(spec.fetch("name")) }, "#{label}: SDK or Cucumber preinstalled")
      gem_inputs = before.fetch("inputs").keys.grep(/\.gem\z/)
      assert(gem_inputs == (label.start_with?("tc17") ? ["reportportal-cucumber-ruby-2.0.0.gem"] : []), "#{label}: unexpected package/cache inputs")
      if label.start_with?("tc17")
        assert(before.fetch("inputs").fetch("reportportal-cucumber-ruby-2.0.0.gem") == hashes.fetch(sdk), "#{label}: wrong staged candidate hash")
      end
      container = read(File.join(evidence, "container-after.json"))
      assert(container.fetch("Image") == summary.fetch("images").fetch(item.fetch("image")).fetch("Id"), "#{label}: wrong image")
      assert(container.fetch("State").fetch("ExitCode").zero?, "#{label}: container exit")
      mounts = container.fetch("Mounts")
      assert(mounts.size == 2 && mounts.all? { |mount| mount.fetch("Type") == "bind" }, "#{label}: volume/project/cache mount")
      assert(mounts.find { |mount| mount.fetch("Destination") == "/inputs" }.fetch("RW") == false, "#{label}: writable inputs")
      %w[installed-audit cli-pass-audit cli-fail-audit].each do |name|
        audit = read(File.join(evidence, "#{name}.json"))
        assert(audit.fetch("errors").empty?, "#{label}/#{name}: audit errors")
        image = summary.fetch("images").fetch(item.fetch("image"))
        machine = { "arm64" => "aarch64", "amd64" => "x86_64" }.fetch(image.fetch("Architecture"))
        assert(audit.fetch("ruby_version") == patch && audit.fetch("ruby") == before.fetch("ruby") &&
               audit.fetch("ruby_platform").match?(/\A#{machine}-linux(?:\z|-)/), "#{label}/#{name}: wrong runtime")
        assert(audit.dig("sdk", "version") == sdk && audit.dig("cucumber", "version") == cucumber, "#{label}/#{name}: wrong SDK/Cucumber")
        assert(audit.fetch("sdk_archive_sha256") == hashes.fetch(sdk), "#{label}/#{name}: wrong installed archive")
        payload = audit.fetch("payload_sha256")
        assert(payload.size == file_count && payload.values.all? { |hash| hash.fetch("packaged") && hash.fetch("packaged") == hash.fetch("installed") } &&
               Digest::SHA256.hexdigest(payload.keys.sort.join("\n")) == manifest.fetch(sdk).fetch(:payload_paths_sha256), "#{label}/#{name}: payload mismatch")
        entrypoints = audit.fetch("entrypoint_checks")
        assert(entrypoints.keys.sort == manifest.fetch(sdk).fetch(:required_entrypoints).sort, "#{label}/#{name}: missing entrypoint checks")
        entrypoints.each do |relative, check|
          assert(check.values_at("declared", "regular_file", "within_gem").all? && check.fetch("sha256") &&
                 check.fetch("sha256") == payload.fetch(relative).fetch("installed"), "#{label}/#{name}: invalid required installed entrypoint #{relative}")
        end
        assert(!audit.fetch("sdk_loaded_files").empty? && audit.fetch("sdk_loaded_files").all? { |path| path.start_with?("/clean/gems/gems/reportportal-cucumber-ruby-#{sdk}/") }, "#{label}/#{name}: source load")
        assert(audit.fetch("dependency_checks").all? { |dep| dep.fetch("satisfied") }, "#{label}/#{name}: dependency mismatch")
        assert(%w[base64 logger].all? { |gem| audit.dig("standard_gems", gem, "activated") }, "#{label}/#{name}: standard gems not activated")
        audit_count += 1
      end
      commands[label] = json_lines(File.join(evidence, "commands.jsonl"))
      assert(commands.fetch(label).all? { |entry| entry.fetch("exit") == entry.fetch("expected") }, "#{label}: command exit mismatch")
      required_commands = {
        "installed-audit" => "/inputs/cucumber12_cleanroom_audit.rb",
        "cli-pass" => "features/pass.feature", "cli-fail" => "features/fail.feature",
        "spool-help" => "reportportal-spool"
      }
      required_commands.each do |command, argument|
        assert(File.file?(File.join(evidence, "#{command}.stdout")), "#{label}: missing #{command} stdout")
        expected_exit = command == "cli-fail" ? 1 : 0
        assert(commands.fetch(label).any? { |entry| entry.fetch("argv").include?(argument) && entry.fetch("exit") == expected_exit }, "#{label}: missing/wrong exit #{command}")
      end
      Dir[File.join(evidence, "*.stderr")].each do |path|
        assert(!File.read(path).match?(/cannot load such file|LoadError|Gem::MissingSpec|Gem::LoadError/), "#{label}: missing gem/load error in #{path}")
      end
      next unless label.start_with?("tc18")

      gemfile = File.read(File.join(evidence, "Gemfile"))
      lock = File.read(File.join(evidence, "Gemfile.lock"))
      assert(gemfile.scan(/^\s*gem /).size == 2 && gemfile.include?("gem \"reportportal-cucumber-ruby\"\n"), "#{label}: SDK not unpinned/two-gem consumer")
      assert(!lock.match?(/^(?:PATH|GIT)$/) && lock.include?("remote: http://candidate-index:8808/"), "#{label}: wrong SDK source")
      assert(lock.include?("reportportal-cucumber-ruby (#{sdk})") && lock.include?("cucumber (#{cucumber})"), "#{label}: wrong resolved versions")
      assert(commands.fetch(label).any? { |entry| entry.fetch("argv") == ["bundle", "_2.6.9_", "update"] }, "#{label}: no real bundle update")
    end
    index = read(File.join(directory, "registry/evidence/index-manifest.json"))
    assert(index.fetch("packages").map { |package| package.fetch("version") }.sort == hashes.keys.sort, "Private index did not offer both releases")
    requests = json_lines(File.join(directory, "registry/evidence/requests.jsonl"))
    downloads = requests.select { |request| request.fetch("target").start_with?("/gems/") && request.fetch("status") == 200 }
    hashes.each do |version, hash|
      assert(index.fetch("files").fetch("gems/reportportal-cucumber-ruby-#{version}.gem").fetch("sha256") == hash, "Wrong private index archive")
      assert(downloads.any? { |request| request.fetch("target") == "/gems/reportportal-cucumber-ruby-#{version}.gem" && request.fetch("sha256") == hash }, "No exact private-index download of #{version}")
    end
    prior = summary.fetch("resources_before").lines.map { |line| JSON.parse(line) }
    later = summary.fetch("resources_after").lines.map { |line| JSON.parse(line) }
    protected = prior.select { |container| container.fetch("Names").match?(/\A(?:reportportal-2607-|rp2607-control-plane\z)/) }
    protected.each do |original|
      same = later.find { |container| container.fetch("ID") == original.fetch("ID") }
      assert(same && same.values_at("Names", "Image", "State") == original.values_at("Names", "Image", "State"), "Existing ReportPortal/kind container identity/state changed")
    end
    result = { status: "PASS", verified_at: Time.now.utc.iso8601, verifier_sha256: Digest::SHA256.file(__FILE__).hexdigest,
               audits_checked: audit_count, private_index_downloads: downloads, existing_rp_kind_containers_checked: protected.size,
               package_sha256: hashes, candidate_kind: config.candidate_kind,
               TC17: "PASS", TC18: "PASS", scope: summary.fetch("notice") }
    unless write
      puts JSON.pretty_generate(result.merge(check_only: true))
      return result
    end
    report = ["# Independent Consumer Tester B", "", "**TC17 PASS; TC18 PASS.** These checks do not certify the separate Outline fallback or NUL-preview fixes.", "",
              "Archive label: `#{config.candidate_kind}` (hash-based; a non-baseline hash alone does not certify corrected behavior).", "",
              summary.fetch("notice"), "", "Source: `codex/cucumber-12` at `#{summary.fetch('source_head')}`.", "",
              "| Case | Actual Ruby | Cucumber | SDK | Result |", "| --- | --- | --- | --- | --- |"]
    summary.fetch("cases").each { |item| report << "| #{item.fetch('case')} | #{item.fetch('ruby')} | #{item.fetch('cucumber')} | #{item.fetch('sdk')} | PASS |" }
    report.concat(["", "## Package SHA-256", ""])
    hashes.each { |version, hash| report << "- SDK #{version}: `#{hash}`" }
    report.concat(["", "## Exact Commands", "", "From the repository root:", "", "```sh",
                   "export CLEANROOM_CANDIDATE_ARCHIVE=#{Shellwords.escape(config.packages.fetch('2.0.0').fetch(:path))}",
                   "export CLEANROOM_CANDIDATE_SHA256=#{hashes.fetch('2.0.0')}", "ruby script/acceptance/cucumber12_cleanroom.rb",
                   "ruby script/acceptance/cucumber12_cleanroom_verify.rb #{summary_path.delete_prefix(ROOT + '/')}", "```", "",
                   "The outer Docker invocations, immutable image IDs, cleared environment and isolated mounts are in [commands.jsonl](commands.jsonl).",
                   "Each consumer separately installed OS native-extension build tools; no standard/test gems were manually bootstrapped."])
    commands.each do |label, entries|
      report.concat(["", "### #{label}", "", "```sh"])
      entries.select { |entry| %w[gem bundle cucumber reportportal-spool].include?(entry.fetch("argv").first) && entry.fetch("argv")[1] != "environment" && entry.fetch("argv")[1] != "list" }.each { |entry| report << entry.fetch("command") }
      report.concat(["```", "", "Exact exits/timing: [#{label}/evidence/commands.jsonl](#{label}/evidence/commands.jsonl)."])
    end
    report.concat(["", "## Image Provenance", ""])
    summary.fetch("images").each { |tag, image| report << "- `#{tag}`: image `#{image.fetch('Id')}`; registry `#{image.fetch('RepoDigests').join(', ')}`." }
    report.concat(["", "## Verified Evidence", "",
                   "All #{audit_count} installed/actual-CLI audits passed. Every candidate SDK audit checked #{manifest.fetch('2.0.0').fetch(:payload_files)} payload files; the legacy SDK checked #{manifest.fetch('1.3.1').fetch(:payload_files)}. Required installed entrypoints, load paths, activated/runtime dependencies and installed gemspecs were audited. Both real Cucumber success/failure CLI cases and the installed spool executable ran in every consumer.", "",
                   "Five owned containers and one owned network were removed after evidence capture. No gem volumes/caches or installed gem layers were retained. #{protected.size} pre-existing ReportPortal/kind container identities and states were unchanged. Original package hashes were unchanged. No commit, push, tag or publication was performed.", "",
                   "## Blind Spots", "",
                   "- Only the exact Linux architectures and Ruby patches recorded in the audits were executed; lockfile platform entries do not expand coverage.",
                   "- Public dependencies resolved live; the repository lock/cache was never used. Future dependency releases can change results.",
                   "- RP_ENABLED=false: no live ReportPortal, kind, storage or delivery certification, and no RP data modifications.",
                   "- Mutex_m was unused by the selected SDK/Cucumber paths; no claim that arbitrary consumer code can require an unused undeclared gem.",
                   "- Fresh no-lock two-gem selection with bundle update, not existing-application lockfile migration.",
                   "- Private candidate index resolution, NOT SDK publication or public-registry SDK selection.",
                   "- Only the specified CLI paths were exercised; this is not the entire SDK regression suite.",
                   "- Official base images remain in Docker's image store; disposable installed gem layers were removed.", ""])
    File.open(File.join(directory, "report.md"), "wx", 0o444) { |file| file.write(report.join("\n")) }
    File.open(File.join(directory, "verification.json"), "wx", 0o444) { |file| file.write(JSON.pretty_generate(result) + "\n") }
    puts JSON.pretty_generate(result)
    puts "Report: #{File.join(directory, 'report.md')}"
    result
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    config = Cucumber12Cleanroom::Config.new
    check_only = ARGV.delete("--check-only")
    raise ArgumentError, "Usage: ruby #{$PROGRAM_NAME} [--check-only] [summary.json]" if ARGV.size > 1
    path = ARGV.first
    unless path
      latest = Cucumber12CleanroomVerify.read(File.join(Cucumber12CleanroomVerify::ROOT, "tmp/cucumber12-independent/cleanroom", config.latest_pointer))
      path = latest.fetch("summary")
    end
    Cucumber12CleanroomVerify.verify(File.expand_path(path), config: config, write: !check_only)
  rescue ArgumentError, RuntimeError, SystemCallError, KeyError, JSON::ParserError => error
    warn "Verification refused: #{error.message}"
    exit 2
  end
end
