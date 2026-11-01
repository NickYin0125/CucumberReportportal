# frozen_string_literal: true

require "json"
require "open3"
require "digest"
require "fileutils"
require "rubygems/package"
require "zlib"
require "stringio"
require_relative "final_wp5_context"

version = ENV.fetch("QA_DOC_VERSION", "1.3.2")
tested = LedgerWP5Context.heads.fetch(version)
candidate = { "2.0.1" => "173c6038b417e86aeb4f268649ce4c81aa30888e", "1.3.2" => "01db2e42d70fc7ec2179198992fc00c1c55825bc" }.fetch(version)
sdk = "/Users/nick/Documents/crr-#{version}"
root = "/Users/nick/Documents/crr-qa-#{version}"
directory = File.join(root, "docs/reviews/assets", LedgerWP5Context.stamp)
output = File.join(directory, "docs-only-final-binding-r2.json")
raise "Do not overwrite binding" if File.exist?(output)
git = lambda do |*args|
  out, err, status = Open3.capture3({ "RP_API_KEY" => nil }, "git", "-C", sdk, *args)
  raise "Git observation failed: #{err}" unless status.success?
  out
end
raise "Unexpected candidate" unless git.call("rev-parse", "HEAD").strip == candidate
parent = git.call("rev-parse", "#{candidate}^").strip
changed = git.call("diff", "--name-only", tested, candidate).lines.map(&:strip)
approved = ["docs/design/presentation-ledger-owner-decisions.md"]
approved.unshift("CHANGELOG.md") if version == "1.3.2"
git.call("merge-base", "--is-ancestor", tested, candidate)
trees = [tested, candidate].to_h { |sha| [sha, git.call("ls-tree", "-r", "--full-tree", sha).lines] }
categories = {
  runtime_lib: ->(p) { p.start_with?("lib/") },
  tests_and_features: ->(p) { p.start_with?("spec/", "features/") },
  gemspec_gemfile_lock: ->(p) { %w[Gemfile Gemfile.lock].include?(p) || p.end_with?(".gemspec") },
  helm_and_workflows: ->(p) { p.start_with?("helm/", ".github/workflows/") },
  every_non_approved_document_path: ->(p) { !approved.include?(p) }
}
fingerprints = categories.to_h do |name, choose|
  sides = trees.transform_values { |rows| rows.select { |r| choose.call(r.split("\t", 2).last.chomp) }.sort }
  [name, { counts: sides.transform_values(&:length), path_mode_blob_sha256: sides.transform_values { |rows| Digest::SHA256.hexdigest(rows.join) }, unchanged: sides[tested] == sides[candidate] }]
end
raise "Not a strict docs-only descendant" unless changed.sort == approved.sort && fingerprints.values.all? { |row| row[:unchanged] }
work = File.join(directory, "docs-binding-package-#{candidate[0, 8]}-local")
raise "Preserve previous scratch" if File.exist?(work)
FileUtils.mkdir_p(File.join(work, "source"))
archive = File.join(work, "source.tar")
git.call("archive", "--format=tar", "--output", archive, candidate)
raise "Archive extraction failed" unless system("tar", "-xf", archive, "-C", File.join(work, "source"))
gem_path = File.join(work, "reportportal-cucumber-ruby-#{version}.gem")
stdout, stderr, build = Open3.capture3({ "RP_API_KEY" => nil, "RUBYOPT" => nil, "BUNDLE_GEMFILE" => nil },
  "/opt/homebrew/opt/ruby/bin/gem", "build", "reportportal-cucumber-ruby.gemspec", "--output", gem_path, chdir: File.join(work, "source"))
raise "Local package build failed" unless build.success?
package = Gem::Package.new(gem_path)
package.verify
members = []
Gem::Package::TarReader.new(File.open(gem_path, "rb")) do |outer|
  outer.each do |entry|
    next unless entry.full_name == "data.tar.gz"
    Zlib::GzipReader.wrap(StringIO.new(entry.read)) do |gzip|
      Gem::Package::TarReader.new(gzip) do |data|
        data.each do |member|
          raise "Unsafe member" unless member.file? && !member.full_name.start_with?("/") && !member.full_name.split("/").include?("..")
          bytes = member.read
          expected = File.binread(File.join(work, "source", member.full_name))
          members << { path: member.full_name, bytes: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes), exact_candidate_bytes: bytes == expected }
        end
      end
    end
  end
end
changelog = git.call("show", "#{candidate}:CHANGELOG.md")
matrix = (version == "1.3.2" ? %w[M1 M2 M3 M4] : %w[M5 M6]).map do |cell|
  path = File.join(directory, "matrix/#{cell}/result.json")
  value = JSON.parse(File.read(path))
  { cell: cell, source: path, sha256: Digest::SHA256.file(path).hexdigest, tested_source_sha: value["source_head"],
    status: value["status"], rspec: value["rspec"], cucumber: value["cucumber"] }
end
decisions = git.call("show", "#{candidate}:docs/design/presentation-ledger-owner-decisions.md")
counts_in_changelog = version != "1.3.2" || (changelog.include?(tested) && changelog.match?(/1,?419/) && changelog.match?(/1,?403/))
passed = matrix.all? { |row| row[:tested_source_sha] == tested && row[:status] == "PASS" } &&
  members.all? { |row| row[:exact_candidate_bytes] } && members.map { |row| row[:path] }.sort == package.spec.files.sort &&
  members.any? { |row| row[:path] == "CHANGELOG.md" } && package.spec.version.to_s == version && counts_in_changelog &&
  decisions.include?("允许补充平铺回放（推荐）") && decisions.include?("接受这项窄范围调整， 继续")
result = { schema: "wp5-changelog-only-candidate-binding/1", tested_runtime_head: tested, candidate_feature_head: candidate,
  parent: parent, changed_paths: changed, fingerprints: fingerprints, original_matrix: matrix,
  candidate_changelog: changelog, candidate_changelog_sha256: Digest::SHA256.hexdigest(changelog),
  package: { filename: File.basename(gem_path), bytes: File.size(gem_path), sha256: Digest::SHA256.file(gem_path).hexdigest,
    verified: true, version: package.spec.version.to_s, build_stdout: stdout, build_stderr: stderr, build_exit: build.exitstatus,
    exact_candidate_members: members, artifact_local_only: true, publication: false },
  owner_decision17_document_sha256: Digest::SHA256.hexdigest(decisions), counts_in_changelog: counts_in_changelog,
  verdict: passed ? "PASS" : "FAIL",
  qa_helper_correction: "Earlier bcc1915-only helper result is retained unchanged: literal digit search incorrectly rejected human comma-formatted 1,419/1,403. Original numeric matrix assertions and product evidence are unchanged.",
  claim_limit: "Only approved candidate documentation and package bytes are newly verified. All live, matrix, fault and performance executions retain the tested runtime SHA above, not the candidate doc head. No release authorization." }
File.write(output, JSON.pretty_generate(result) + "\n")
puts JSON.generate(path: output, verdict: result[:verdict], candidate: candidate, tested: tested, members: members.length)
