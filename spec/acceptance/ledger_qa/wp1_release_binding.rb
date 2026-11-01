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
  DATE_ONLY = "c0ba73368e089d58212e3ebb25ca6abce9eb8c6f"
  CANDIDATE = "2ad45b29cbf0eb3b491979ffc60553ee9a414aed"
  DATE_SPEC = "spec/packaging/presentation_docs_spec.rb"
  AUTHORIZED_PATHS = ["CHANGELOG.md", DATE_SPEC].freeze
  OWNER_ANSWER = "允许仅测试的兼容修复并更新证明（推荐）"
  PRIOR_PROOF = "docs/reviews/assets/wp5-ci-final-20261101/docs-only-final-binding-r2.json"
  OLD_HEADER = "## 2.0.1 - Unreleased"
  NEW_HEADER = "## 2.0.1 - 2026-11-01"
  ENVIRONMENT = { "RP_API_KEY" => nil, "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil }.freeze
  DATE_VALIDATOR = <<~'SOURCE'.lines.map { |line| line == "\n" ? line : "  #{line}" }.join.freeze
    def release_heading_valid?(text)
      match = text.match(/\A# Changelog\n\n## #{Regexp.escape(version)} - (Unreleased|\d{4}-\d{2}-\d{2})\n/)
      return false unless match

      match[1] == "Unreleased" || Date.iso8601(match[1]).iso8601 == match[1]
    rescue Date::Error
      false
    end

  SOURCE
  DATE_CASES = <<~'SOURCE'.lines.map { |line| line == "\n" ? line : "  #{line}" }.join.freeze
    ["Unreleased", "2026-11-01", "2028-02-29"].each do |date|
      it "accepts the release heading date #{date}" do
        expect(release_heading_valid?("# Changelog\n\n## #{version} - #{date}\n")).to be(true)
      end
    end

    ["2026-02-29", "2026-02-30", "2026-13-01", "2026-1-01", "2026-11-01 trailing", ""].each do |date|
      it "rejects the invalid release heading date #{date.inspect}" do
        expect(release_heading_valid?("# Changelog\n\n## #{version} - #{date}\n")).to be(false)
      end
    end

  SOURCE
  OLD_EXPECTATION = <<~'SOURCE'.lines.map { |line| "  #{line}" }.join.freeze
    it "prepends an Unreleased section with the owner's exact patch rationale" do
      expect(changelog).to start_with("# Changelog\n\n## #{version} - Unreleased\n")
  SOURCE
  NEW_EXPECTATION = <<~'SOURCE'.lines.map { |line| "  #{line}" }.join.freeze
    it "prepends an Unreleased or valid dated section with the owner's exact patch rationale" do
      expect(release_heading_valid?(changelog)).to be(true)
  SOURCE

  def self.exact_spec_change?(before, after)
    normalized = after.dup
    [["require \"rspec\"\nrequire \"date\"\n", "require \"rspec\"\n"],
     [DATE_VALIDATOR, ""], [DATE_CASES, ""], [NEW_EXPECTATION, OLD_EXPECTATION]].each do |added, original|
      return false unless normalized.scan(Regexp.new(Regexp.escape(added))).length == 1
      normalized = normalized.sub(added, original)
    end
    normalized == before
  end

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
    old_spec = "require \"rspec\"\n" + OLD_EXPECTATION + "    rationale_stays_strict\n  end\n"
    new_spec = "require \"rspec\"\nrequire \"date\"\n" + DATE_VALIDATOR + NEW_EXPECTATION + "    rationale_stays_strict\n  end\n" + DATE_CASES
    assert.call(exact_spec_change?(old_spec, new_spec), "only exact approved spec edits")
    assert.call(!exact_spec_change?(old_spec, new_spec.sub("rationale_stays_strict", "weakened")), "reject unrelated assertion change")
    assert.call(!exact_spec_change?(old_spec, new_spec.sub("2026-02-30", "2026-02-28")), "reject altered negative corpus")
    assert.call(!exact_spec_change?(old_spec, new_spec.sub("2028-02-29", "2028-03-01")), "reject altered positive corpus")
    assert.call(!exact_spec_change?(old_spec, new_spec.sub("Date.iso8601(match[1]).iso8601 == match[1]", "true")), "reject calendar-check weakening")
    assert.call(!exact_spec_change?(old_spec, new_spec + "extra_assertion\n"), "reject any additional spec change")
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
    proof_path = File.join(OUTPUT, "binding-r3.json")
    raise "Refusing to overwrite prior WP1 proof" if File.exist?(proof_path)
    FileUtils.mkdir_p(OUTPUT)
    proof = { schema: "wp1-release-date-and-test-compatibility-binding/1", checked_at_utc: Time.now.utc.iso8601,
      version: "2.0.1", previous_candidate_head: PREVIOUS, candidate_head: CANDIDATE,
      actually_tested_runtime_head: TESTED, verdict: "FAIL",
      scope: "Bounded owner-approved WP1 date plus named date-spec compatibility and local-package binding; not full-suite, remote-CI, WP5, redaction or release certification",
      authorization: { owner_exact_answer: OWNER_ANSWER, only_new_allowed_paths: AUTHORIZED_PATHS },
      protected_branch_or_tag_mutation: false, feature_worktree_mutation: false, network_publication: false }
    begin
      proof[:helper_self_test] = self_test
      failed_attempt = File.join(OUTPUT, "binding.json")
      if File.file?(failed_attempt)
        proof[:retained_helper_attempt] = { source: failed_attempt.delete_prefix(QA_ROOT + "/"), sha256: Digest::SHA256.file(failed_attempt).hexdigest,
          explanation: "First helper rejected the comparison to the prior document-scope hash: the prior scope includes CHANGELOG, while WP1 permits its one-line date change. This revision verifies that original scope for tested/previous heads and the explicit new scope for all three heads; original failure is unchanged." }
      end
      raise "Unexpected feature HEAD" unless git("rev-parse", "HEAD").strip == CANDIDATE
      raise "Unexpected candidate parent" unless git("rev-parse", "#{CANDIDATE}^").strip == DATE_ONLY && git("rev-parse", "#{DATE_ONLY}^").strip == PREVIOUS
      status_before = git("status", "--porcelain", "--untracked-files=no")
      prior_path = File.join(QA_ROOT, PRIOR_PROOF)
      prior = JSON.parse(File.read(prior_path))
      raise "Prior binding does not match inputs" unless prior["verdict"] == "PASS" &&
        prior["tested_runtime_head"] == TESTED && prior["candidate_feature_head"] == PREVIOUS
      proof[:prior_binding] = { source: PRIOR_PROOF, sha256: Digest::SHA256.file(prior_path).hexdigest,
        claim_limit: "Immutable historical equivalence input, not a new SDK execution" }
      date_proof_path = File.join(OUTPUT, "binding-r2.json")
      date_proof = JSON.parse(File.read(date_proof_path))
      raise "Date-only predecessor proof mismatch" unless date_proof["verdict"] == "PASS" && date_proof["candidate_head"] == DATE_ONLY && date_proof["actually_tested_runtime_head"] == TESTED
      proof[:prior_date_only_binding] = { source: date_proof_path.delete_prefix(QA_ROOT + "/"), sha256: Digest::SHA256.file(date_proof_path).hexdigest }
      paths = git("diff", "--no-renames", "--name-only", PREVIOUS, CANDIDATE).lines.map(&:chomp)
      before = git("show", "#{PREVIOUS}:CHANGELOG.md")
      after = git("show", "#{CANDIDATE}:CHANGELOG.md")
      proof[:authorized_delta] = { changed_paths: paths, diff_stat: git("diff", "--stat", PREVIOUS, CANDIDATE),
        patch: git("diff", "--no-ext-diff", "--no-textconv", PREVIOUS, CANDIDATE, "--", "CHANGELOG.md"),
        before_sha256: Digest::SHA256.hexdigest(before), after_sha256: Digest::SHA256.hexdigest(after),
        exact_one_line_date_replacement: exact_date_change?(before, after) }
      spec_before = git("show", "#{PREVIOUS}:#{DATE_SPEC}")
      spec_after = git("show", "#{CANDIDATE}:#{DATE_SPEC}")
      proof[:authorized_test_change] = { path: DATE_SPEC, before_source: spec_before, after_source: spec_after,
        before_sha256: Digest::SHA256.hexdigest(spec_before), after_sha256: Digest::SHA256.hexdigest(spec_after),
        exact_approved_reverse_transform_restores_original: exact_spec_change?(spec_before, spec_after),
        patch: git("diff", "--no-ext-diff", "--no-textconv", PREVIOUS, CANDIDATE, "--", DATE_SPEC),
        all_test_paths_changed_since_tested_runtime: git("diff", "--no-renames", "--name-only", TESTED, CANDIDATE, "--", "spec", "features").lines.map(&:chomp),
        positive_cases: ["Unreleased", "2026-11-01", "2028-02-29"],
        negative_cases: ["2026-02-29", "2026-02-30", "2026-13-01", "2026-1-01", "2026-11-01 trailing", ""] }
      raise "Unapproved two-path delta" unless paths.sort == AUTHORIZED_PATHS.sort && exact_date_change?(before, after) &&
        exact_spec_change?(spec_before, spec_after) && proof[:authorized_test_change][:all_test_paths_changed_since_tested_runtime] == [DATE_SPEC]
      git("merge-base", "--is-ancestor", TESTED, CANDIDATE)
      trees = [TESTED, PREVIOUS, CANDIDATE].to_h { |sha| [sha, git("ls-tree", "-r", "--full-tree", sha).lines] }
      categories = {
        "runtime_lib" => ->(path) { path.start_with?("lib/") },
        "tests_and_features" => ->(path) { path.start_with?("spec/", "features/") && path != DATE_SPEC },
        "gemspec_gemfile_lock" => ->(path) { %w[Gemfile Gemfile.lock].include?(path) || path.end_with?(".gemspec") },
        "helm_and_workflows" => ->(path) { path.start_with?("helm/", ".github/workflows/") },
        "every_non_approved_document_path" => ->(path) { ![*AUTHORIZED_PATHS, "docs/design/presentation-ledger-owner-decisions.md"].include?(path) }
      }
      proof[:fingerprints] = categories.to_h do |name, choose|
        sides = trees.transform_values { |rows| fingerprint(rows, &choose) }
        old = prior.fetch("fingerprints").fetch(name)
        prior_sides = trees.slice(TESTED, PREVIOUS).transform_values do |rows|
          case name
          when "every_non_approved_document_path" then fingerprint(rows) { |path| prior_document_scope(path) }
          when "tests_and_features" then fingerprint(rows) { |path| path.start_with?("spec/", "features/") }
          else fingerprint(rows, &choose)
          end
        end
        matches_prior = [TESTED, PREVIOUS].all? do |sha|
          prior_sides[sha][:count] == old.fetch("counts").fetch(sha) &&
            prior_sides[sha][:git_path_mode_blob_sha256] == old.fetch("path_mode_blob_sha256").fetch(sha)
        end
        [name, { sources: sides, unchanged: sides.values.uniq.length == 1, prior_scope_sources: prior_sides, matches_prior_binding: matches_prior }]
      end
      proof[:fingerprint_scopes] = { prior: "Original WP5 R2 categories, including all tests and CHANGELOG, exclude only the previously approved owner-decisions document",
        wp1_r3: "Only CHANGELOG and the named date spec are newly excluded; exact reverse-transform and full test-path diff constrain those exceptions; the prior owner-decisions delta remains separately bound",
        tests_and_features_effective_exclusion: DATE_SPEC }
      raise "Runtime/source fingerprints differ" unless proof[:fingerprints].values.all? { |row| row[:unchanged] && row[:matches_prior_binding] }
      proof[:previous_to_candidate_outside_authorized_paths] = trees.slice(PREVIOUS, CANDIDATE).transform_values do |rows|
        fingerprint(rows) { |path| !AUTHORIZED_PATHS.include?(path) }
      end
      raise "Tuple outside approved two-path scope changed" unless proof[:previous_to_candidate_outside_authorized_paths].values.uniq.length == 1

      work = File.join(OUTPUT, "local-only-r3")
      raise "Refusing to overwrite package scratch" if File.exist?(work)
      source = File.join(work, "source")
      home = File.join(work, "empty-home")
      FileUtils.mkdir_p([source, home])
      archive = File.join(work, "source.tar")
      git("archive", "--format=tar", "--output", archive, CANDIDATE)
      _out, _err, extracted = Open3.capture3(ENVIRONMENT, "tar", "-xf", archive, "-C", source)
      raise "Candidate archive extraction failed" unless extracted.success?
      focused_path = File.join(OUTPUT, "focused-r3.json")
      raise "Refusing to overwrite focused evidence" if File.exist?(focused_path)
      focused_command = [RbConfig.ruby, Gem.bin_path("rspec-core", "rspec"), DATE_SPEC, "--format", "json", "--out", focused_path]
      focused_stdout, focused_stderr, focused_status = Open3.capture3(ENVIRONMENT.merge("HOME" => home), *focused_command, chdir: source)
      focused = File.file?(focused_path) ? JSON.parse(File.read(focused_path)) : {}
      proof[:focused_date_spec] = { command: focused_command, ruby: RUBY_DESCRIPTION,
        rspec_core: Gem::Specification.find_by_name("rspec-core").version.to_s, exit: focused_status.exitstatus,
        stdout: focused_stdout, stderr: focused_stderr, summary: focused["summary"], source_head: CANDIDATE,
        raw_result: focused_path.delete_prefix(QA_ROOT + "/"), raw_result_sha256: File.file?(focused_path) ? Digest::SHA256.file(focused_path).hexdigest : nil,
        full_suite_executed: false }
      raise "Focused 27-example date-spec verification failed" unless focused_status.success? && focused.fetch("summary").values_at("example_count", "failure_count", "pending_count") == [27, 0, 0] &&
        focused.fetch("examples").length == 27 && focused.fetch("examples").all? { |example| example["status"] == "passed" }
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
        payload_identical_to_date_only_binding: members.map { |m| m.values_at(:path, :bytes, :sha256) }.sort == date_proof.fetch("package").fetch("members").map { |m| m.values_at("path", "bytes", "sha256") }.sort,
        authorized_date_spec_not_packaged: members.none? { |m| m[:path] == DATE_SPEC },
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
      raise "Date-only predecessor proof changed" unless Digest::SHA256.file(date_proof_path).hexdigest == proof[:prior_date_only_binding][:sha256]
      proof[:helper_sha256] = Digest::SHA256.file(__FILE__).hexdigest
      proof[:verdict] = "PASS"
    rescue StandardError => error
      proof[:failure] = { error_class: error.class.name, message: error.message }
    ensure
      write_new(proof_path, proof)
    end
    puts JSON.generate(verdict: proof[:verdict], candidate: CANDIDATE, tested_runtime: TESTED,
      helper_assertions: proof.dig(:helper_self_test, :assertions), package_members: proof.dig(:package, :members)&.length,
      focused_specs: proof.dig(:focused_date_spec, :summary), proof: proof_path,
      scope: "WP1 authorized date/test compatibility binding only; full suite, remote CI and redaction remain separate")
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
