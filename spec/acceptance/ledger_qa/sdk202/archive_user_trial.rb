# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

root = File.expand_path("../../../..", __dir__)
source = "/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2"
destination = File.join(root, "docs/reviews/assets/readability-2.0.2-user-trial")
abort "Refusing to overwrite an evidence archive" if File.exist?(destination)
token = ENV.fetch("RP_API_KEY")
abort "Missing scan credential" if token.empty?
sources = %w[reports artifacts].flat_map do |name|
  Dir.glob(File.join(source, name, "**", "*"), File::FNM_DOTMATCH).reject { |path| File.directory?(path) }
end
sources.each do |path|
  abort "Symlink is not an evidence file" if File.symlink?(path)
  abort "Credential detected; evidence archive stopped" if File.binread(path).include?(token.b)
end
manifest = sources.sort.map do |path|
  relative = path.delete_prefix(source + "/")
  target = File.join(destination, relative)
  FileUtils.mkdir_p(File.dirname(target))
  FileUtils.cp(path, target)
  hash = Digest::SHA256.file(path).hexdigest
  abort "Evidence copy changed" unless Digest::SHA256.file(target).hexdigest == hash
  { path: relative, bytes: File.size(path), sha256: hash }
end
File.write(File.join(destination, "manifest.json"), JSON.pretty_generate(
  source: source, source_runtime_sha: "9bf3356cff350d8e2ba11bad1c33aa89881ac456",
  note: "Exact copies; original absolute report links/provenance are retained. No claim of a new execution at the performance-fix head.",
  files: manifest
) + "\n")
puts JSON.generate(files: manifest.length, bytes: manifest.sum { |entry| entry[:bytes] },
                   credential_scan: "PASS", copy_hashes: "IDENTICAL")
