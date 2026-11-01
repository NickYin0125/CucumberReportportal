# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "time"

out = ENV.fetch("QA_OUT")
FileUtils.mkdir_p(out)
seed, local = "/seedbundle", "/bundle"
raise "New container-local cache required" if File.exist?(local)
started = Time.now.utc.iso8601
FileUtils.mkdir_p(local)
FileUtils.cp_r(Dir.children(seed).map { |name| File.join(seed, name) }, local, preserve: true)
manifest = lambda do |root|
  Dir.glob(File.join(root, "**/*"), File::FNM_DOTMATCH).sort.filter_map do |path|
    next if [".", ".."].include?(File.basename(path)) || File.directory?(path)
    relative = path.delete_prefix(root + "/")
    [relative, File.symlink?(path) ? ["symlink", File.readlink(path)] : ["file", File.size(path), Digest::SHA256.file(path).hexdigest]]
  end
end
source_files, local_files = manifest.call(seed), manifest.call(local)
proof = { schema: "qa-container-local-dependency-copy/1", started_at_utc: started, completed_at_utc: Time.now.utc.iso8601,
  source: seed, destination: local, file_count: source_files.length, exact_file_manifest_equal: source_files == local_files,
  source_manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(source_files)),
  copied_manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(local_files)),
  note: "Operational staging only, not acceptance or performance proof. Same cached bytes, Ruby/Cucumber pin, final source and tests; no persistent dependency file changed." }
File.write(File.join(out, "cache-stage.json"), JSON.pretty_generate(proof) + "\n")
raise "Cached dependency copy changed bytes" unless proof[:exact_file_manifest_equal]
load File.join(__dir__, "matrix.rb")
