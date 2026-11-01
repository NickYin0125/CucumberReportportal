# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "rbconfig"

selected = ARGV[ARGV.index("--sdk-root") + 1]
output = ARGV[ARGV.index("--output") + 1]
root_map = { ENV.fetch("QA_FINAL_SDK_ROOT") => ["/qa-seed/final", ENV.fetch("QA_FINAL_SOURCE_SHA")],
  ENV.fetch("QA_BASELINE_SDK_ROOT") => ["/qa-seed/baseline", ENV.fetch("QA_BASELINE_SOURCE_SHA")] }
proof = { dependency_volume: ENV.fetch("QA_DEPENDENCY_VOLUME"), sdk_root: selected, source_copy: "Not needed for QA-owned historical archive" }
if (source = root_map[selected])
  seed, sha = source
  raise "Fresh local SDK files required" if File.exist?(File.join(selected, "lib")) || File.exist?(File.join(selected, "reportportal-cucumber-ruby.gemspec"))
  FileUtils.mkdir_p(selected)
  FileUtils.cp_r(File.join(seed, "lib"), selected)
  FileUtils.cp(File.join(seed, "reportportal-cucumber-ruby.gemspec"), selected)
  paths = Dir[File.join(seed, "lib/**/*")].select { |path| File.file?(path) } + [File.join(seed, "reportportal-cucumber-ruby.gemspec")]
  hashes = paths.to_h { |path| [path.delete_prefix(seed + "/"), Digest::SHA256.file(path).hexdigest] }
  mismatches = hashes.keys.select { |path| Digest::SHA256.file(File.join(selected, path)).hexdigest != hashes[path] }
  raise "SDK byte copy mismatch" unless mismatches.empty?
  proof.merge!(source_revision_sha: sha, source_seed: seed, copied_files: hashes.length,
    source_manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(hashes)), mismatches: mismatches)
end
FileUtils.mkdir_p(File.dirname(output))
File.write(output + "-stage.json", JSON.pretty_generate(proof) + "\n")
exec(RbConfig.ruby, *ARGV)
