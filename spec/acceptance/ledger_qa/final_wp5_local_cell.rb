# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "open3"

source = "/qa/source"
local_out = File.join(source, "docs/reviews/assets/qa-cell-evidence")
export = ENV.fetch("QA_EXPORT")
begin
  FileUtils.mkdir_p(source)
  FileUtils.cp_r(Dir.children("/qa-seed/source").map { |name| File.join("/qa-seed/source", name) }, source, preserve: true)
  FileUtils.mkdir_p("/bundle")
  FileUtils.cp_r(Dir.children("/qa-seed/bundle").map { |name| File.join("/qa-seed/bundle", name) }, "/bundle", preserve: true)
  manifest = lambda do |root, pattern|
    Dir.glob(File.join(root, pattern), File::FNM_DOTMATCH).sort.select { |path| File.file?(path) }.to_h { |path| [path.delete_prefix(root + "/"), Digest::SHA256.file(path).hexdigest] }
  end
  sdk_seed = manifest.call("/qa-seed/source", "lib/**/*.rb")
  sdk_local = manifest.call(source, "lib/**/*.rb")
  tests_seed = manifest.call("/qa-seed/source", "{spec,script}/**/*.rb")
  tests_local = manifest.call(source, "{spec,script}/**/*.rb")
  deps_seed = manifest.call("/qa-seed/bundle", "**/*")
  deps_local = manifest.call("/bundle", "**/*")
  head, status = Open3.capture2("git", "-C", source, "rev-parse", "HEAD")
  raise "Local source or dependency fingerprint mismatch" unless status.success? && head.strip == ENV.fetch("QA_HEAD") && sdk_seed == sdk_local && tests_seed == tests_local && deps_seed == deps_local
  FileUtils.mkdir_p(local_out)
  proof = { runtime_sha: head.strip, source_lib_files: sdk_local.length, source_lib_equal: true,
    dependency_files: deps_local.length, dependency_bytes_equal: true, diagnostic_observers_requested: false,
    test_and_script_files: tests_local.length, tests_and_scripts_equal: true,
    test_source_manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(tests_local)),
    source_manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(sdk_local)), dependency_manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(deps_local)) }
  File.write(File.join(local_out, "local-storage-proof.json"), JSON.pretty_generate(proof) + "\n")
  chart = File.join(source, "helm/reportportal-rich-experience/charts")
  FileUtils.mkdir_p(chart)
  FileUtils.cp_r(Dir["/qa-seed/charts/*"], chart)
  ENV["QA_OUT"] = local_out
  ENV["QA_NO_DIAGNOSTIC_OBSERVER"] = "1"
  load File.join(source, "spec/acceptance/ledger_qa/matrix.rb")
  proof[:source_lib_after_equal] = manifest.call(source, "lib/**/*.rb") == sdk_seed
  proof[:tests_and_scripts_after_equal] = manifest.call(source, "{spec,script}/**/*.rb") == tests_seed
  File.write(File.join(local_out, "local-storage-proof.json"), JSON.pretty_generate(proof) + "\n")
  raise "Test execution changed pinned source bytes" unless proof[:source_lib_after_equal] && proof[:tests_and_scripts_after_equal]
ensure
  FileUtils.mkdir_p(export)
  FileUtils.cp_r(Dir.children(local_out).map { |name| File.join(local_out, name) }, export) if File.directory?(local_out)
end
