# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"

root = File.expand_path("..", __dir__)
old = File.expand_path("../rp-trial-2.0.1", root)
paths = %w[features/independent features/tester_api features/tester_ui].flat_map do |directory|
  Dir.glob(File.join(old, directory, "**", "*")).select { |path| File.file?(path) }
end
paths.concat(%w[independent_api_steps.rb independent_ui_steps.rb].map do |name|
  File.join(old, "features/step_definitions", name)
end)
records = paths.sort.map do |path|
  relative = path.delete_prefix("#{old}/")
  original = Digest::SHA256.file(path).hexdigest
  current = Digest::SHA256.file(File.join(root, relative)).hexdigest
  {path: relative, original_sha256: original, current_sha256: current, identical: original == current}
end
abort "Independent input drift" unless records.all? { |row| row[:identical] }
abort "Unexpected package.json" if File.exist?(File.join(root, "package.json"))
old_runner = File.read(File.join(old, "bin/run-trial"))
new_runner = File.read(File.join(root, "bin/run-trial"))
expected_runner = old_runner.gsub("2.0.1", "2.0.2")
  .sub("4f6ee672a48af71b59554ecb569c07086f2e749b", "9bf3356cff350d8e2ba11bad1c33aa89881ac456")
  .sub("# PR #5 head, same tree as QA-tested 173c603", "# PR #8 head")
abort "Unexpected trial driver edit" unless new_runner == expected_runner
result = {head: "9bf3356cff350d8e2ba11bad1c33aa89881ac456", independent_sources: records,
          runner_version_and_ref_only: true, package_json_present: false}
File.write(File.join(__dir__, "master-input-audit.json"), JSON.pretty_generate(result) + "\n")
puts "Independent sources identical: #{records.length}; runner changes limited; no package.json."
