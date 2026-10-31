# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"
require "open3"
require "time"

version, group, action = ARGV
abort "usage: archive_evidence.rb VERSION live|checks|matrix plan|build" unless %w[2.0.1 1.3.2].include?(version) && %w[live checks matrix].include?(group) && %w[plan build].include?(action)
root = "/Users/nick/Documents/crr-qa-#{version}"
assets = File.join(root, "docs/reviews/assets")
prefix = File.join(assets, "presentation-ledger-#{version}-#{group}-raw")
paths = []
if group == "matrix"
  Dir[File.join(assets, "ledger-qa-runs/*/*")].select { |path| File.directory?(path) }.sort.each do |cell|
    if cell.include?("/final-hooks-20261101/") && !File.file?(File.join(cell, "result.json"))
      abort "Final cell still active; do not archive inconsistent outputs" if action == "build"
    end
    %w[result.json source-provenance.json].each { |name| path = File.join(cell, name); paths << path if File.file?(path) }
    evidence = File.join(cell, "source/docs/reviews/assets/qa-cell-evidence")
    paths.concat(Dir.glob(File.join(evidence, "**/*"), File::FNM_DOTMATCH)) if File.directory?(evidence)
    # Exact scratch dependency inputs are evidence, not a copied SDK tree.
    dependencies = File.join(cell, "dependency-inputs")
    %w[Gemfile Gemfile.lock].each do |name|
      source = File.join(cell, "source", name)
      next unless File.file?(source)
      FileUtils.mkdir_p(dependencies)
      target = File.join(dependencies, "#{name}.txt")
      FileUtils.cp(source, target) unless File.file?(target)
      raise "Scratch dependency input changed" unless Digest::SHA256.file(source).hexdigest == Digest::SHA256.file(target).hexdigest
      paths << target
    end
  end
else
  folders = group == "live" ? %w[ledger-qa-live] : %w[ledger-qa-offline ledger-qa-faults ledger-qa-performance ledger-qa-environment ledger-qa-supplied-history]
  folders.each { |folder| paths.concat(Dir.glob(File.join(assets, folder, "**/*"), File::FNM_DOTMATCH)) }
  paths.concat(Dir[File.join(assets, "presentation-ledger-#{version}/*.jpg")]) if group == "checks"
end
rejected = []
paths = paths.uniq.select do |path|
  next false unless File.file?(path)
  relative = path.delete_prefix(root + "/")
  forbidden = relative.split("/").any? { |part| %w[.git .bundle .cache docker-config vendor cache caches node_modules].include?(part) } ||
    path.match?(/\.(?:gem|tgz|tar\.gz|tar\.xz|zip)\z/i) || File.basename(path).start_with?("._") || File.basename(path) == ".DS_Store" || File.symlink?(path)
  rejected << relative if forbidden
  !forbidden
end.sort
raise "Archive selection escaped allowed evidence roots" unless paths.all? { |path| path.start_with?(assets + "/") }
if group == "matrix"
  raise "SDK mirror entered matrix selection" unless paths.all? do |path|
    path.match?(%r{/ledger-qa-runs/[^/]+/[^/]+/(?:result\.json|source-provenance\.json|dependency-inputs/[^/]+|source/docs/reviews/assets/qa-cell-evidence/.*)\z})
  end
end
entries = paths.map do |path|
  { path: path.delete_prefix(root + "/"), bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest }
end
list = prefix + ".files.txt"
File.write(list, entries.map { |entry| entry[:path] }.join("\n") + "\n")
manifest = { schema: "lossless-qa-evidence-archive/1", version: version, group: group,
  prepared_at_utc: Time.now.utc.iso8601, file_count: entries.length, uncompressed_bytes: entries.sum { |entry| entry[:bytes] },
  excludes: "SDK mirror trees/nested .git, caches, Docker config, package archives/binaries, symlinks and runtime working copies are not published.",
  retained: "Full original JSON/stdout/native reports, runtime/source provenance, submitted wire, API receipts/readback, controlled inputs, and labelled failed/invalid results. All entry bytes are SHA256-indexed.",
  rejected_files: rejected.sort, entries: entries }
if action == "build"
  archive = prefix + ".tar.xz"
  raise "Refusing to overwrite an immutable evidence archive" if File.exist?(archive)
  stdout, stderr, status = Open3.capture3({ "COPYFILE_DISABLE" => "1" }, "nice", "-n", "15", "tar", "--no-xattrs", "--no-acls", "--no-fflags",
    "-cJf", archive, "-C", root, "--no-recursion", "-T", list)
  manifest[:archive] = { path: archive.delete_prefix(root + "/"), exit: status.exitstatus, stdout: stdout, stderr: stderr,
    bytes: File.file?(archive) && File.size(archive), sha256: File.file?(archive) && Digest::SHA256.file(archive).hexdigest }
  File.write(prefix + ".manifest.json", JSON.pretty_generate(manifest) + "\n")
  raise "Archive creation failed; partial output preserved" unless status.success?
  names, error, result = Open3.capture3("tar", "-tJf", archive)
  raise "Archive listing failed" unless result.success?
  actual = names.lines.map(&:chomp).reject { |name| name.start_with?("PaxHeader/") }
  raise "Archive entry set differs from manifest" unless actual.sort == entries.map { |entry| entry[:path] }.sort
  manifest[:archive][:entry_set_verified] = true
end
File.write(prefix + ".manifest.json", JSON.pretty_generate(manifest) + "\n")
puts JSON.generate(version: version, group: group, action: action, files: entries.length,
  raw_bytes: manifest[:uncompressed_bytes], archive: manifest[:archive]&.slice(:path, :bytes, :sha256, :entry_set_verified))
