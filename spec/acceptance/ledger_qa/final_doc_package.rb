# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "fileutils"
require "tmpdir"
require "rubygems/package"
require "zlib"
require "stringio"
require "time"

%w[2.0.1 1.3.2].each do |version|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  assets = File.join(root, "docs/reviews/assets")
  binding = JSON.parse(File.read(File.join(assets, "ledger-qa-doc-only-binding-#{version}.json")))
  raise "Doc/runtime binding failed" unless binding["verdict"] == "PASS"
  candidate = binding.fetch("candidate_feature_head")
  work = Dir.mktmpdir("qa-doc-head-package-", assets)
  source = File.join(work, "source")
  FileUtils.mkdir_p(source)
  tar = File.join(work, "source.tar")
  _, error, status = Open3.capture3("git", "archive", "--format=tar", "--output", tar, candidate, chdir: root)
  raise "Git archive failed" unless status.success?
  _, error, status = Open3.capture3("tar", "-xf", tar, "-C", source)
  raise "Source extraction failed" unless status.success?
  gemspecs = Dir[File.join(source, "*.gemspec")]
  raise "Expected one gemspec" unless gemspecs.length == 1
  home = File.join(work, "empty-home")
  FileUtils.mkdir_p(home)
  filename = "reportportal-cucumber-ruby-#{version}.gem"
  gem_path = File.join(work, filename)
  env = { "HOME" => home, "RP_API_KEY" => nil, "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil }
  stdout, stderr, result = Open3.capture3(env, "/opt/homebrew/opt/ruby/bin/gem", "build", File.basename(gemspecs.first), "--output", gem_path, chdir: source)
  raise "Temporary gem build failed" unless result.success?
  package = Gem::Package.new(gem_path)
  package.verify
  members = []
  Gem::Package::TarReader.new(File.open(gem_path, "rb")) do |outer|
    outer.each do |entry|
      next unless entry.full_name == "data.tar.gz"
      Zlib::GzipReader.wrap(StringIO.new(entry.read)) do |gzip|
        Gem::Package::TarReader.new(gzip) do |data|
          data.each do |file|
            raise "Unsafe package member" if file.full_name.start_with?("/") || file.full_name.split("/").include?("..") || !file.file?
            members << { path: file.full_name, bytes: file.header.size, sha256: Digest::SHA256.hexdigest(file.read) }
          end
        end
      end
    end
  end
  docs = %w[docs/design/presentation-ledger-acceptance.md docs/design/presentation-ledger-proposal.md].map do |path|
    expected, err, status = Open3.capture3("git", "show", "#{candidate}:#{path}", chdir: root)
    raise "Candidate document missing" unless status.success?
    actual = members.find { |member| member[:path] == path }
    { path: path, expected_sha256: Digest::SHA256.hexdigest(expected), packaged_sha256: actual && actual[:sha256], byte_identical: actual && Digest::SHA256.hexdigest(expected) == actual[:sha256] }
  end
  sdk_members = members.select { |member| member[:path].start_with?("lib/") }
  lib_equal = sdk_members.all? { |member| Digest::SHA256.file(File.join(root, member[:path])).hexdigest == member[:sha256] }
  packaged_paths = members.map { |member| member[:path] }.sort
  expected_files = package.spec.files.sort
  spec_equal = packaged_paths == expected_files
  shipping_assets = %w[docs/reviews/assets/reportportal-26.0.5-table.png docs/reviews/assets/reportportal-26.0.5-video.png].map do |path|
    original, _, original_status = Open3.capture3("git", "show", "#{binding['tested_runtime_head']}:#{path}", chdir: root)
    raise "Pre-existing shipping asset is not in tested tree" unless original_status.success?
    member = members.find { |entry| entry[:path] == path }
    { path: path, original_tested_commit: binding["tested_runtime_head"], original_sha256: Digest::SHA256.hexdigest(original),
      packaged_sha256: member && member[:sha256], unchanged: member && Digest::SHA256.hexdigest(original) == member[:sha256] }
  end
  shipping_paths = shipping_assets.select { |row| row[:unchanged] }.map { |row| row[:path] }
  clean = shipping_assets.all? { |row| row[:unchanged] } && packaged_paths.none? do |path|
    (path.start_with?("docs/reviews/") && !shipping_paths.include?(path)) || path.start_with?("spec/acceptance/ledger_qa/") || path.end_with?(".gem", ".tgz")
  end
  record = { schema: "final-doc-head-gem-package-proof/1", version: version, checked_at_utc: Time.now.utc.iso8601,
    candidate_feature_head: candidate, tested_runtime_head: binding["tested_runtime_head"], git_archive_source: candidate,
    build: { command: ["gem", "build", File.basename(gemspecs.first), "--output", filename], exit: result.exitstatus, stdout: stdout, stderr: stderr, source: "Exact feature Git tree, not QA branch working tree", temporary_work: work.delete_prefix(root + "/"), network_publication: false, helm_invoked: false },
    package: { filename: filename, bytes: File.size(gem_path), sha256: Digest::SHA256.file(gem_path).hexdigest,
      local_untracked_file: gem_path.delete_prefix(root + "/"), rubygems_verify: true, spec_name: package.spec.name, spec_version: package.spec.version.to_s },
    expected_spec_files: expected_files, actual_members: members, member_paths_exactly_match_spec_files: spec_equal,
    approved_design_docs: docs, packaged_runtime_lib_sha256_matches_tested_source: lib_equal, no_qa_evidence_or_package_binaries_in_gem: clean,
    explicitly_allowed_unchanged_shipping_review_assets: shipping_assets,
    verdict: spec_equal && lib_equal && clean && docs.all? { |row| row[:byte_identical] } && package.spec.version.to_s == version ? "PASS" : "FAIL",
    note: "Fresh standalone package verification is required because docs/design is packaged. Old pre-decision package proof is retained. Temporary .gem/source mirror is not staged, committed, uploaded or published; no Helm build." }
  output = File.join(assets, "ledger-qa-final-doc-package-#{version}.json")
  if File.file?(output) && JSON.parse(File.read(output))["verdict"] == "FAIL"
    first_attempt = File.join(assets, "ledger-qa-package-harness-attempt1-#{version}.json")
    FileUtils.cp(output, first_attempt) unless File.exist?(first_attempt)
    record[:earlier_harness_attempt] = { source: first_attempt.delete_prefix(root + "/"),
      explanation: "First QA helper incorrectly rejected every docs/reviews path, including two unchanged SDK-shipped PNGs. Exact original byte proof above replaces that over-broad QA-only hygiene check. No SDK packaging change or criterion waiver." }
  end
  File.write(output, JSON.pretty_generate(record) + "\n")
  puts JSON.generate(version: version, verdict: record[:verdict], package: record[:package].slice(:filename, :bytes, :sha256), members: members.length, docs_exact: docs.all? { |row| row[:byte_identical] })
end
