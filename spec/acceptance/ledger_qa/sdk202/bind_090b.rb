# frozen_string_literal: true

require_relative "host"

module Ledger202FinalBinding
  FINAL = "090b633842f5b24d46a244f854daf95c9477b9ca"
  PREVIOUS = "d1725d3ab9e796c008fe9e80a11ea0ce29bde762"
  PATHS = %w[lib examples reportportal-cucumber-ruby.gemspec Gemfile Gemfile.lock].freeze
  DOC = "examples/current_sdk/README.md"
  ALLOWED = %w[.github/workflows/validate.yml examples/current_sdk/README.md script/release/README.md
    script/release/spec/dependency_isolation_spec.rb spec/packaging/readability_docs_spec.rb
    spec/reportportal_cucumber/cucumber/reporting_experience_integration_spec.rb].freeze

  def self.tree(sha)
    Ledger202Host.read_command("git", "-C", Ledger202Host::ROOT, "ls-tree", "-r", sha, "--", *PATHS).lines.to_h do |line|
      info, path = line.chomp.split("\t", 2)
      [path, info.split.last]
    end
  end

  def self.run
    changed = Ledger202Host.read_command("git", "-C", Ledger202Host::ROOT, "diff", "--name-only", Ledger202Host::FINAL, FINAL).lines.map(&:chomp)
    raise "Unexpected follow-up scope" unless changed.sort == ALLOWED.sort
    trees = [Ledger202Host::FINAL, PREVIOUS, FINAL].to_h { |sha| [sha, tree(sha)] }
    runtime = trees.transform_values { |members| members.reject { |path, _| path == DOC } }
    raise "Runtime or sample code changed" unless runtime.values.uniq.length == 1
    destination = File.join(Ledger202Host::SOURCE, "final-090b6338")
    raise "Snapshot exists" if File.exist?(destination)
    FileUtils.mkdir_p(destination)
    archive, _, status = Open3.capture3("git", "-C", Ledger202Host::ROOT, "archive", FINAL, *PATHS)
    raise "Archive failed" unless status.success?
    _, _, status = Open3.capture3("tar", "-xf", "-", "-C", destination, stdin_data: archive)
    raise "Staging failed" unless status.success?
    members = trees.fetch(FINAL).map do |path, blob|
      bytes = File.binread(File.join(destination, path))
      raise "Staged member differs" unless Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0".b + bytes) == blob
      { path: path, sha256: Digest::SHA256.hexdigest(bytes), blobs: trees.transform_values { |t| t.fetch(path) },
        byte_identical_all_three_heads: trees.values.map { |t| t.fetch(path) }.uniq.length == 1 }
    end
    result = { final_sha: FINAL, previous_sha: PREVIOUS, actually_executed_sha: Ledger202Host::FINAL,
      status: "EXACT_RUNTIME_BYTE_BINDING_NOT_A_NEW_EXECUTION", changed_paths: changed,
      runtime_paths: PATHS, explicit_document_only_exception: DOC, files: members,
      runtime_member_count: runtime.values.first.length, final_immutable_snapshot: destination,
      performance: "NOT_RUN_WAITING_FOR_MASTER_QUIET_WINDOW" }
    Ledger202Host.write_new(File.join(Ledger202Host::OUTPUT, "final-090b-binding.json"), result)
    puts JSON.generate(result.slice(:final_sha, :status, :runtime_member_count, :performance))
  end
end

Ledger202FinalBinding.run if $PROGRAM_NAME == __FILE__
