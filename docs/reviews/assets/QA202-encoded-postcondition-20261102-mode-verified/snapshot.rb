# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "open3"

root = "/Users/nick/Documents/crr-2.0.2"
out = "/private/tmp/rp-redaction-review-20261102"
dest = File.join(out, "fixed-source")
abort "Snapshot already exists" if File.exist?(dest)
FileUtils.mkdir_p(dest)
bytes, status = Open3.capture2("git", "-C", root, "archive", "HEAD")
abort "Archive failed" unless status.success?
_, error, status = Open3.capture3("tar", "-xf", "-", "-C", dest, stdin_data: bytes)
abort error unless status.success?
changed, status = Open3.capture2("git", "-C", root, "diff", "--name-only", "HEAD")
abort "Diff failed" unless status.success?
files = changed.lines.map(&:strip) + ["spec/reportportal_cucumber/automation/evidence_redactor_encoded_safety_spec.rb"]
files.each { |p| FileUtils.cp(File.join(root, p), File.join(dest, p)) }
FileUtils.cp_r(File.join(root, "helm/reportportal-rich-experience/charts"), File.join(dest, "helm/reportportal-rich-experience"))
manifest = Dir.glob(File.join(dest, "{lib,spec,script}/**/*")).select { |p| File.file?(p) }.sort.map do |p|
  [p.delete_prefix(dest + "/"), Digest::SHA256.file(p).hexdigest]
end
File.write(File.join(out, "fixed-source-manifest.json"), JSON.pretty_generate(
  base_commit: Open3.capture2("git", "-C", root, "rev-parse", "HEAD").first.strip,
  working_tree_patch: true, changed_paths: files, files: manifest,
  manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(manifest))
) + "\n")
