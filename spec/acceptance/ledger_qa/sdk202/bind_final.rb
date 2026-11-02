# frozen_string_literal: true

require_relative "host"

final = "2d037abd0bc52551db5ceacebd2e7fc6892f8b1c"
paths = %w[lib examples reportportal-cucumber-ruby.gemspec Gemfile Gemfile.lock]
diff = Ledger202Host.read_command("git", "-C", Ledger202Host::ROOT, "diff", "--name-only", Ledger202Host::FINAL, final)
allowed = %w[.github/workflows/validate.yml script/release/README.md script/release/spec/dependency_isolation_spec.rb]
raise "Follow-up exceeded documented scope" unless diff.lines.map(&:chomp).sort == allowed.sort
unchanged = Ledger202Host.read_command("git", "-C", Ledger202Host::ROOT, "diff", "--name-only", Ledger202Host::FINAL, final, "--", *paths)
raise "Runtime/sample bytes changed" unless unchanged.empty?
destination = File.join(Ledger202Host::SOURCE, "final-2d037abd")
raise "Final snapshot already exists" if File.exist?(destination)
FileUtils.mkdir_p(destination)
archive, _, status = Open3.capture3("git", "-C", Ledger202Host::ROOT, "archive", final, *paths)
raise "Final snapshot archive failed" unless status.success?
_, _, status = Open3.capture3("tar", "-xf", "-", "-C", destination, stdin_data: archive)
raise "Final snapshot staging failed" unless status.success?
members = Ledger202Host.read_command("git", "-C", Ledger202Host::ROOT, "ls-tree", "-r", final, "--", *paths).lines.map do |line|
  info, path = line.chomp.split("\t", 2)
  blob = info.split.last
  bytes = File.binread(File.join(destination, path))
  raise "Final member mismatch" unless Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0".b + bytes) == blob
  { path: path, blob: blob, sha256: Digest::SHA256.hexdigest(bytes) }
end
Ledger202Host.write_new(File.join(Ledger202Host::OUTPUT, "final-head-binding.json"),
  final_sha: final, actually_executed_sha: Ledger202Host::FINAL, unchanged_runtime_paths: paths,
  changed_paths: diff.lines.map(&:chomp), runtime_diff: unchanged, final_immutable_snapshot: destination,
  members: members, status: "EXACT_BYTE_BINDING_NOT_A_NEW_EXECUTION", performance: "HOLD")
puts JSON.generate(final_sha: final, changed_paths: diff.lines.map(&:chomp), verified_members: members.length, performance: "HOLD")
