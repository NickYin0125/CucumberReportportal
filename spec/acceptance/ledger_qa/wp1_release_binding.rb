# frozen_string_literal: true

require "json"
require "open3"
require "digest"
require "fileutils"
require "rbconfig"
require "rubygems/package"
require "stringio"
require "time"
require "zlib"

module WP1ReleaseBinding
  QA_ROOT = File.expand_path("../../..", __dir__)
  SDK_ROOT = File.expand_path("../crr-2.0.1", QA_ROOT)
  OUTPUT = File.join(QA_ROOT, "docs/reviews/assets/wp1-release-20261101")
  TESTED = "3f20313c20b25071fbc49b31e1c6bc772bd599e4"
  PREVIOUS = "173c6038b417e86aeb4f268649ce4c81aa30888e"
  CANDIDATE = "c0ba73368e089d58212e3ebb25ca6abce9eb8c6f"
  PRIOR_PROOF = "docs/reviews/assets/wp5-ci-final-20261101/docs-only-final-binding-r2.json"
  OLD_HEADER = "## 2.0.1 - Unreleased"
  NEW_HEADER = "## 2.0.1 - 2026-11-01"
  ENVIRONMENT = { "RP_API_KEY" => nil, "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil }.freeze

  def self.exact_date_change?(before, after)
    before.lines.count { |line| line.chomp == OLD_HEADER } == 1 &&
      after == before.sub(OLD_HEADER, NEW_HEADER)
  end

  def self.fingerprint(lines, &choose)
    selected = lines.select { |line| choose.call(line.split("\t", 2).last.chomp) }.sort
    { count: selected.length, git_path_mode_blob_sha256: Digest::SHA256.hexdigest(selected.join) }
  end

  def self.prior_document_scope(path)
    path != "docs/design/presentation-ledger-owner-decisions.md"
  end

  def self.safe_member?(path)
    !path.empty? && !path.start_with?("/") && !path.include?("\0") &&
      path.split("/", -1).none? { |part| ["", ".", ".."].include?(part) }
  end

  def self.exact_membership?(actual, expected)
    actual.uniq.length == actual.length && expected.uniq.length == expected.length && actual.sort == expected.sort
  end

  def self.blob_id(bytes, format = "sha1")
    digest = { "sha1" => Digest::SHA1, "sha256" => Digest::SHA256 }.fetch(format)
    digest.hexdigest("blob #{bytes.bytesize}\0".b + bytes.b)
  end

  def self.self_test
    count = 0
    assert = lambda do |condition, label|
      count += 1
      raise "Self-test failed: #{label}" unless condition
    end
    before = "# Changelog\n\n#{OLD_HEADER}\n\nbody unchanged\n"
    after = before.sub(OLD_HEADER, NEW_HEADER)
    assert.call(exact_date_change?(before, after), "only approved date replacement")
    assert.call(!exact_date_change?(before, after + "extra\n"), "reject body addition")
    assert.call(!exact_date_change?(before, after.sub("2026-11-01", "2026-11-02")), "reject another date")
    assert.call(!exact_date_change?(before, after.sub("body unchanged", "changed")), "reject body edit")
    assert.call(!exact_date_change?(before + "#{OLD_HEADER}\n", after + "#{OLD_HEADER}\n"), "reject duplicate section")
    assert.call(!exact_date_change?(before, after.sub("body", " body")), "reject whitespace change")
    row = "100644 blob #{'a' * 40}\tlib/test.rb\n"
    select_lib = ->(path) { path.start_with?("lib/") }
    expected = fingerprint([row], &select_lib)
    assert.call(expected == fingerprint([row], &select_lib), "equal path/mode/blob tuple")
    assert.call(expected != fingerprint([row.sub("100644", "100755")], &select_lib), "mode change detected")
    assert.call(expected != fingerprint([row.sub('a' * 40, 'b' * 40)], &select_lib), "blob change detected")
    assert.call(expected != fingerprint([row.sub("test.rb", "other.rb")], &select_lib), "path change detected")
    assert.call(expected != fingerprint([], &select_lib), "missing file detected")
    assert.call(expected == fingerprint([row, "100644 blob #{'c' * 40}\tCHANGELOG.md\n"], &select_lib), "category filtering")
    assert.call(prior_document_scope("CHANGELOG.md"), "prior binding includes the previously unchanged changelog")
    assert.call(!prior_document_scope("docs/design/presentation-ledger-owner-decisions.md"), "prior binding excludes only its approved owner document")
    assert.call(safe_member?("lib/test.rb"), "safe member")
    %w[/absolute ../escape lib/../escape lib//empty lib/./dot].each do |path|
      assert.call(!safe_member?(path), "reject unsafe member #{path}")
    end
    assert.call(exact_membership?(%w[b a], %w[a b]), "member order is not membership")
    assert.call(!exact_membership?(%w[a a], %w[a]), "reject duplicate member")
    assert.call(!exact_membership?(%w[a], %w[a b]), "reject missing member")
    assert.call(!exact_membership?(%w[a b], %w[a]), "reject extra member")
    assert.call(blob_id("") == "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391", "Git empty blob vector")
    assert.call(blob_id("same") != blob_id("different"), "payload byte change detected")
    { verdict: "PASS", assertions: count, scope: "Helper-only positive/negative tests; no SDK behavior certification" }
  end

  def self.git(*args)
    out, _err, status = Open3.capture3(ENVIRONMENT, "git", "-C", SDK_ROOT, *args)
    raise "Git observation failed: #{args.first}" unless status.success?
    out
  end

  def self.write_new(path, data)
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
      file.write(JSON.pretty_generate(data) + "\n")
    end
  end

  def self.verify
    proof_path = File.join(OUTPUT, "binding-r2.json")
    raise "Refusing to overwrite prior WP1 proof" if File.exist?(proof_path)
    FileUtils.mkdir_p(OUTPUT)
    proof = { schema: "wp1-release-date-only-binding/1", checked_at_utc: Time.now.utc.iso8601,
      version: "2.0.1", previous_candidate_head: PREVIOUS, candidate_head: CANDIDATE,
      actually_tested_runtime_head: TESTED, verdict: "FAIL",
      scope: "Bounded WP1 CHANGELOG-date and local-package equivalence only; not new WP5 certification, redaction verification, CI signoff or release authorization",
      protected_branch_or_tag_mutation: false, feature_worktree_mutation: false, network_publication: false }
    begin
      proof[:helper_self_test] = self_test
      failed_attempt = File.join(OUTPUT, "binding.json")
      if File.file?(failed_attempt)
        proof[:retained_helper_attempt] = { source: failed_attempt.delete_prefix(QA_ROOT + "/"), sha256: Digest::SHA256.file(failed_attempt).hexdigest,
          explanation: "First helper rejected the comparison to the prior document-scope hash: the prior scope includes CHANGELOG, while WP1 permits its one-line date change. This revision verifies that original scope for tested/previous heads and the explicit new scope for all three heads; original failure is unchanged." }
      end
      raise "Unexpected feature HEAD" unless git("rev-parse", "HEAD").strip == CANDIDATE
      raise "Unexpected candidate parent" unless git("rev-parse", "#{CANDIDATE}^").strip == PREVIOUS
      status_before = git("status", "--porcelain", "--untracked-files=no")
      prior_path = File.join(QA_ROOT, PRIOR_PROOF)
      prior = JSON.parse(File.read(prior_path))
      raise "Prior binding does not match inputs" unless prior["verdict"] == "PASS" &&
        prior["tested_runtime_head"] == TESTED && prior["candidate_feature_head"] == PREVIOUS
      proof[:prior_binding] = { source: PRIOR_PROOF, sha256: Digest::SHA256.file(prior_path).hexdigest,
        claim_limit: "Immutable historical equivalence input, not a new SDK execution" }
      paths = git("diff", "--no-renames", "--name-only", PREVIOUS, CANDIDATE).lines.map(&:chomp)
      before = git("show", "#{PREVIOUS}:CHANGELOG.md")
      after = git("show", "#{CANDIDATE}:CHANGELOG.md")
      proof[:date_only_delta] = { changed_paths: paths, diff_stat: git("diff", "--stat", PREVIOUS, CANDIDATE),
        patch: git("diff", "--no-ext-diff", "--no-textconv", PREVIOUS, CANDIDATE, "--", "CHANGELOG.md"),
        before_sha256: Digest::SHA256.hexdigest(before), after_sha256: Digest::SHA256.hexdigest(after),
        exact_one_line_date_replacement: exact_date_change?(before, after) }
      raise "Candidate changes more than the approved date" unless paths == ["CHANGELOG.md"] && exact_date_change?(before, after)
      git("merge-base", "--is-ancestor", TESTED, CANDIDATE)
      trees = [TESTED, PREVIOUS, CANDIDATE].to_h { |sha| [sha, git("ls-tree", "-r", "--full-tree", sha).lines] }
      categories = {
        "runtime_lib" => ->(path) { path.start_with?("lib/") },
        "tests_and_features" => ->(path) { path.start_with?("spec/", "features/") },
        "gemspec_gemfile_lock" => ->(path) { %w[Gemfile Gemfile.lock].include?(path) || path.end_with?(".gemspec") },
        "helm_and_workflows" => ->(path) { path.start_with?("helm/", ".github/workflows/") },
        "every_non_approved_document_path" => ->(path) { !%w[CHANGELOG.md docs/design/presentation-ledger-owner-decisions.md].include?(path) }
      }
      proof[:fingerprints] = categories.to_h do |name, choose|
        sides = trees.transform_values { |rows| fingerprint(rows, &choose) }
        old = prior.fetch("fingerprints").fetch(name)
        prior_sides = trees.slice(TESTED, PREVIOUS).transform_values do |rows|
          name == "every_non_approved_document_path" ? fingerprint(rows) { |path| prior_document_scope(path) } : fingerprint(rows, &choose)
        end
        matches_prior = [TESTED, PREVIOUS].all? do |sha|
          prior_sides[sha][:count] == old.fetch("counts").fetch(sha) &&
            prior_sides[sha][:git_path_mode_blob_sha256] == old.fetch("path_mode_blob_sha256").fetch(sha)
        end
        [name, { sources: sides, unchanged: sides.values.uniq.length == 1, prior_scope_sources: prior_sides, matches_prior_binding: matches_prior }]
      end
      proof[:fingerprint_document_scopes] = { prior: "Exclude only owner-decisions.md, matching the immutable R2 scope for TESTED/PREVIOUS", wp1: "Exclude owner-decisions.md and CHANGELOG.md; exact date-only and every-non-CHANGELOG checks separately constrain the new delta" }
      raise "Runtime/source fingerprints differ" unless proof[:fingerprints].values.all? { |row| row[:unchanged] && row[:matches_prior_binding] }
      proof[:previous_to_candidate_non_changelog] = trees.slice(PREVIOUS, CANDIDATE).transform_values do |rows|
        fingerprint(rows) { |path| path != "CHANGELOG.md" }
      end
      raise "Non-CHANGELOG tuple changed" unless proof[:previous_to_candidate_non_changelog].values.uniq.length == 1

      work = File.join(OUTPUT, "local-only-r2")
      raise "Refusing to overwrite package scratch" if File.exist?(work)
      source = File.join(work, "source")
      home = File.join(work, "empty-home")
      FileUtils.mkdir_p([source, home])
      archive = File.join(work, "source.tar")
      git("archive", "--format=tar", "--output", archive, CANDIDATE)
      _out, _err, extracted = Open3.capture3(ENVIRONMENT, "tar", "-xf", archive, "-C", source)
      raise "Candidate archive extraction failed" unless extracted.success?
      filename = "reportportal-cucumber-ruby-2.0.1.gem"
      package_path = File.join(work, filename)
      gem_cli = File.join(RbConfig::CONFIG.fetch("bindir"), "gem")
      stdout, stderr, build = Open3.capture3(ENVIRONMENT.merge("HOME" => home), RbConfig.ruby, gem_cli,
        "build", "reportportal-cucumber-ruby.gemspec", "--output", package_path, chdir: source)
      proof[:build] = { ruby: RUBY_DESCRIPTION, rubygems: Gem::VERSION, exit: build.exitstatus,
        stdout: stdout, stderr: stderr, source_git_archive_sha: CANDIDATE, empty_home: true, network_operations: false }
      raise "Fresh local gem build failed" unless build.success?
      package = Gem::Package.new(package_path)
      package.verify
      format = git("rev-parse", "--show-object-format").strip
      candidate_entries = git("ls-tree", "-rz", "--full-tree", CANDIDATE).split("\0").to_h do |record|
        meta, path = record.split("\t", 2)
        mode, type, oid = meta.split
        [path, { mode: mode, type: type, oid: oid }]
      end
      members = []
      Gem::Package::TarReader.new(File.open(package_path, "rb")) do |outer|
        outer.each do |entry|
          next unless entry.full_name == "data.tar.gz"
          Zlib::GzipReader.wrap(StringIO.new(entry.read)) do |gzip|
            Gem::Package::TarReader.new(gzip) do |payload|
              payload.each do |member|
                path = member.full_name
                raise "Unsafe package member" unless member.file? && safe_member?(path)
                bytes = member.read
                candidate_entry = candidate_entries.fetch(path)
                members << { path: path, bytes: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes),
                  candidate_git_mode: candidate_entry[:mode], candidate_git_blob: candidate_entry[:oid],
                  package_mode: member.header.mode, exact_candidate_git_blob: candidate_entry[:type] == "blob" && blob_id(bytes, format) == candidate_entry[:oid] }
              end
            end
          end
        end
      end
      prior_members = prior.fetch("package").fetch("exact_candidate_members")
      old_payload = prior_members.reject { |m| m["path"] == "CHANGELOG.md" }.map { |m| m.values_at("path", "bytes", "sha256") }.sort
      new_payload = members.reject { |m| m[:path] == "CHANGELOG.md" }.map { |m| m.values_at(:path, :bytes, :sha256) }.sort
      changelog = members.find { |m| m[:path] == "CHANGELOG.md" }
      package_checks = { correct_name_and_version: package.spec.name == "reportportal-cucumber-ruby" && package.spec.version.to_s == "2.0.1",
        exact_spec_membership: exact_membership?(members.map { |m| m[:path] }, package.spec.files),
        same_membership_as_previous_package: exact_membership?(members.map { |m| m[:path] }, prior_members.map { |m| m["path"] }),
        every_member_matches_candidate_git_blob: members.all? { |m| m[:exact_candidate_git_blob] },
        non_changelog_payload_unchanged: old_payload == new_payload,
        released_changelog_packaged_exactly: changelog && changelog[:sha256] == Digest::SHA256.hexdigest(after),
        packaged_runtime_file_count_complete: members.count { |m| m[:path].start_with?("lib/") } == proof[:fingerprints]["runtime_lib"][:sources][CANDIDATE][:count] }
      proof[:package] = { filename: filename, bytes: File.size(package_path), sha256: Digest::SHA256.file(package_path).hexdigest,
        rubygems_verify: true, spec_name: package.spec.name, spec_version: package.spec.version.to_s,
        checks: package_checks, members: members, local_artifact: package_path.delete_prefix(QA_ROOT + "/"),
        local_only_artifacts_not_for_commit: [work.delete_prefix(QA_ROOT + "/")], published: false }
      raise "Fresh package membership/content mismatch" unless package_checks.values.all?
      raise "Feature HEAD changed during proof" unless git("rev-parse", "HEAD").strip == CANDIDATE
      raise "Feature tracked worktree changed during proof" unless git("status", "--porcelain", "--untracked-files=no") == status_before
      raise "Prior immutable proof changed" unless Digest::SHA256.file(prior_path).hexdigest == proof[:prior_binding][:sha256]
      proof[:helper_sha256] = Digest::SHA256.file(__FILE__).hexdigest
      proof[:verdict] = "PASS"
    rescue StandardError => error
      proof[:failure] = { error_class: error.class.name, message: error.message }
    ensure
      write_new(proof_path, proof)
    end
    puts JSON.generate(verdict: proof[:verdict], candidate: CANDIDATE, tested_runtime: TESTED,
      helper_assertions: proof.dig(:helper_self_test, :assertions), package_members: proof.dig(:package, :members)&.length,
      proof: proof_path, scope: "WP1 date-only binding; no new WP5/redaction certification")
    proof[:verdict] == "PASS" ? 0 : 1
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ["--self-test"]
    puts JSON.generate(WP1ReleaseBinding.self_test)
  elsif ARGV.empty?
    exit WP1ReleaseBinding.verify
  else
    abort "Use no arguments for fresh WP1 proof, or --self-test for helper-only tests"
  end
end
