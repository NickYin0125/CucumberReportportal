# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "time"

FEATURES = {
  "2.0.1" => ["ecf8c5aade5b6982f96083cb21c758db56b81b3f", "e906fada5971cb0e5713006506eaad9be52021e6", "3f525343f84bea32e7c11e4a32522facce3f070d", %w[M5 M6]],
  "1.3.2" => ["c27510547ace0d4baaf964a0575e5bec4344e11a", "168932ef55ac3166d70f6ecc91f8c860ff628166", "df328a37fbe7c66d5ce9330dd99e6c9a467b0ded", %w[M1 M2 M3 M4]]
}.freeze
DOCS = %w[docs/design/presentation-ledger-acceptance.md docs/design/presentation-ledger-proposal.md].freeze
PROTECTED = { "refs/heads/main" => "75cb090a7852c56285010af17cde9ad55df1284b", "refs/heads/maintenance/1.x" => "4ca2f770e0a84e83688f165ba04b4db8ef855cf9", "refs/heads/codex/cucumber-12" => "f2e68f112ad28604f4395710f10f595246f6dc00" }.freeze

def command(root, *args)
  output, error, status = Open3.capture3(*args, chdir: root)
  raise "Read-only verification command failed: #{args.first}" unless status.success?
  { argv: args, stdout: output, stderr: error, exit: status.exitstatus }
end

FEATURES.each do |version, (tested, candidate, checkpoint, cells)|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  assets = File.join(root, "docs/reviews/assets")
  old_path = "docs/reviews/assets/presentation-ledger-#{version}-acceptance.json"
  old_bytes = command(root, "git", "show", "#{checkpoint}:#{old_path}")[:stdout]
  old_data = JSON.parse(old_bytes)
  selected = old_data.fetch("criteria").select { |row| %w[P10.6 V7].include?(row["id"]) }
  ids = selected.flat_map { |row| row["check_ids"] }
  history = { schema: "owner-decision-closure-history/1", original_qa_checkpoint: checkpoint,
    original_acceptance_path: old_path, original_acceptance_git_blob: command(root, "git", "rev-parse", "#{checkpoint}:#{old_path}")[:stdout].strip,
    original_acceptance_sha256: Digest::SHA256.hexdigest(old_bytes), original_status: old_data["status"],
    note: "Original BLOCKED rows/checks are retained unchanged here and in the published QA checkpoint commit. Later owner approval is new evidence, not retroactive PASS.",
    criteria: selected, checks: old_data.fetch("checks").select { |row| ids.include?(row["check_id"]) } }
  history_path = File.join(assets, "ledger-qa-owner-closure-history-#{version}.json")
  File.write(history_path, JSON.pretty_generate(history) + "\n") unless File.file?(history_path)

  diff = command(root, "git", "diff", "--name-only", tested, candidate)
  parent = command(root, "git", "rev-parse", "#{candidate}^")[:stdout].strip
  tree_records = [tested, candidate].to_h do |sha|
    [sha, command(root, "git", "ls-tree", "-r", "--full-tree", sha)[:stdout].lines]
  end
  categories = { "runtime" => ->(path) { path.start_with?("lib/") }, "product_tests" => ->(path) { path.start_with?("spec/", "features/") },
    "dependencies" => ->(path) { %w[Gemfile Gemfile.lock].include?(path) || path.end_with?(".gemspec") },
    "workflows_and_helm" => ->(path) { path.start_with?(".github/workflows/", "helm/", "charts/") },
    "all_non_design_docs_paths" => ->(path) { !DOCS.include?(path) } }
  fingerprints = categories.to_h do |name, choose|
    sides = tree_records.transform_values { |lines| lines.select { |line| choose.call(line.split("\t", 2).last.chomp) }.sort }
    [name, { file_counts: sides.transform_values(&:length), git_path_mode_blob_sha256: sides.transform_values { |lines| Digest::SHA256.hexdigest(lines.join) }, unchanged: sides[tested] == sides[candidate] }]
  end
  doc_checks = DOCS.to_h do |path|
    expected = command(root, "git", "show", "#{candidate}:#{path}")[:stdout]
    actual = File.binread(File.join(root, path))
    text = actual.dup.force_encoding(Encoding::UTF_8)
    [path, { candidate_blob: command(root, "git", "rev-parse", "#{candidate}:#{path}")[:stdout].strip,
      sha256: Digest::SHA256.hexdigest(actual), byte_identical_to_candidate: expected.b == actual,
      decision9: text.include?("Owner answer: 按此澄清规则，保留原始内容（推荐）"), decision10: text.include?("Owner answer: 接受历史 CI 记录作为替代证据（推荐）") }]
  end
  matrix = cells.map do |cell|
    prefix = File.join(assets, "ledger-qa-runs/final-hooks-20261101/#{cell}")
    result = JSON.parse(File.read(File.join(prefix, "result.json")))
    provenance = JSON.parse(File.read(File.join(prefix, "source-provenance.json")))
    hashes = provenance.fetch("source_lib_sha256")
    lib_exact = hashes.all? { |path, sha| Digest::SHA256.file(File.join(root, path)).hexdigest == sha }
    { cell: cell, original_result: "docs/reviews/assets/ledger-qa-runs/final-hooks-20261101/#{cell}/result.json",
      source_head: result["source_head"], provenance_source_head: provenance["source_head"], expected_tested_head: tested,
      status: result["status"], rspec: result["rspec"], cucumber: result["cucumber"],
      original_lib_file_count: hashes.length, all_original_lib_sha256_match_working_source: lib_exact,
      result_sha256: Digest::SHA256.file(File.join(prefix, "result.json")).hexdigest,
      provenance_sha256: Digest::SHA256.file(File.join(prefix, "source-provenance.json")).hexdigest }
  end
  archives = %w[live checks matrix].map do |group|
    path = "docs/reviews/assets/presentation-ledger-#{version}-#{group}-raw.tar.xz"
    manifest = JSON.parse(File.read(File.join(assets, "presentation-ledger-#{version}-#{group}-raw.manifest.json")))
    current = Digest::SHA256.file(File.join(root, path)).hexdigest
    { path: path, original_manifest_sha256: manifest.dig("archive", "sha256"), current_sha256: current,
      git_blob_unchanged_from_published_checkpoint: command(root, "git", "hash-object", path)[:stdout].strip == command(root, "git", "rev-parse", "#{checkpoint}:#{path}")[:stdout].strip,
      unchanged: current == manifest.dig("archive", "sha256") }
  end
  binding_pass = parent == tested && diff[:stdout].lines.map(&:chomp).sort == DOCS.sort && fingerprints.values.all? { |row| row[:unchanged] } &&
    doc_checks.values.all? { |row| row[:byte_identical_to_candidate] && row[:decision9] && row[:decision10] } &&
    matrix.all? { |row| row[:source_head] == tested && row[:provenance_source_head] == tested && row[:status] == "PASS" && row[:all_original_lib_sha256_match_working_source] } && archives.all? { |row| row[:unchanged] && row[:git_blob_unchanged_from_published_checkpoint] }
  binding = { schema: "doc-only-candidate-runtime-binding/1", version: version, checked_at_utc: Time.now.utc.iso8601,
    tested_runtime_head: tested, candidate_feature_head: candidate, actual_qa_checkpoint_head: checkpoint, candidate_parent: parent,
    changed_paths: diff, fingerprints: fingerprints, approved_document_copies: doc_checks, matrix: matrix, immutable_archives: archives,
    verdict: binding_pass ? "PASS" : "FAIL",
    note: "Full suites actually ran ecf/c275, not the new feature doc head or QA checkpoint. Git path/mode/blob fingerprints prove identical runtime/product tests/dependencies/workflows/Helm; new design docs are exact copies. Package contents are refreshed separately because docs are packaged." }
  File.write(File.join(assets, "ledger-qa-doc-only-binding-#{version}.json"), JSON.pretty_generate(binding) + "\n")

  remote = command(root, "git", "ls-remote", "https://github.com/NickYin0125/CucumberReportportal.git", *PROTECTED.keys, "refs/tags/*")
  refs = remote[:stdout].lines.to_h { |line| sha, ref = line.split; [ref, sha] }
  tag_names = refs.keys.grep(%r{\Arefs/tags/}).reject { |name| name.end_with?("^{}") }.map { |name| name.delete_prefix("refs/tags/") }.sort
  ci_path = File.join(assets, "ledger-qa-v7-decision10-ci-refresh.json")
  ci = JSON.parse(File.read(ci_path))
  original_ci = JSON.parse(File.read(File.join(assets, "ledger-qa-v7-public-ci-before.json")))
  c0 = command(root, "git", "show", "--no-patch", "--format=%H%x09%cI", "9ea7f1f226380d4907b6157abb41b72bd86d5b56")[:stdout].strip
  c0_time = Time.iso8601(c0.split("\t").last)
  complete_fetch = ci.fetch("initialized_empty_repo").length == 1 && ci.fetch("fetch_section").any? { |line| line.include?("+refs/tags/*:refs/tags/*") }
  rows = [
    { check: "Authentic successful empty-checkout all-tag fetch completed before C0", expected: true,
      actual: complete_fetch && ci.dig("run", "conclusion") == "success" && Time.iso8601(ci.dig("run", "updated_at")) < c0_time },
    { check: "Historical CI tag NAMES equal original independent public CI extraction", expected: original_ci.fetch("tag_names").sort, actual: ci.fetch("tag_names").sort },
    { check: "Fresh current remote tag NAMES equal approved historical CI name-list", expected: ci.fetch("tag_names").sort, actual: tag_names },
    { check: "Fresh protected head SHAs equal task-start observations", expected: PROTECTED, actual: refs.slice(*PROTECTED.keys) }
  ]
  rows.each { |row| row[:verdict] = row[:expected] == row[:actual] ? "PASS" : "FAIL" }
  proof = { schema: "decision10-alternative-before-tag-proof/1", version: version, checked_at_utc: Time.now.utc.iso8601,
    inputs: { ci_source: "docs/reviews/assets/ledger-qa-v7-decision10-ci-refresh.json", ci_source_sha256: Digest::SHA256.file(ci_path).hexdigest,
      original_ci_source: "docs/reviews/assets/ledger-qa-v7-public-ci-before.json", c0_commit_and_time: c0 },
    read_only_current_ls_remote: remote, current_tag_names: tag_names,
    current_tag_objects_for_observation_only: refs.select { |name, _| name.start_with?("refs/tags/") },
    historical_tag_object_sha_proof: false, no_tag_mutation_performed: true, owner_decision: 10, checks: rows,
    claim_limit: "PASS is approved historical/current tag NAME-list comparison plus protected branch SHA comparison. No historical tag object SHAs were supplied by CI; no object-SHA equality or original ls-remote before snapshot is claimed.",
    verdict: rows.all? { |row| row[:verdict] == "PASS" } ? "PASS" : "FAIL" }
  File.write(File.join(assets, "ledger-qa-v7-decision10-#{version}.json"), JSON.pretty_generate(proof) + "\n")
  puts JSON.generate(version: version, doc_only_runtime_binding: binding[:verdict], historical_tag_names_and_current_refs: proof[:verdict], historical_tag_object_sha_proof: false)
end
