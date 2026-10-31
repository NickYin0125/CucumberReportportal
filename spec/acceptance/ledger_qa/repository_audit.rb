# frozen_string_literal: true

require "json"
require "open3"
require "digest"
require "fileutils"
require "time"

root = File.expand_path("../../..", __dir__)
version = root.end_with?("1.3.2") ? "1.3.2" : "2.0.1"
baseline = version == "1.3.2" ? "4ca2f770e0a84e83688f165ba04b4db8ef855cf9" : "79e5e9cfde4be6d29ca2293e549460c6c71fe87a"
out = File.join(root, "docs/reviews/assets/ledger-qa-repository-#{version}.json")
records = []
command = lambda do |id, *args|
  stdout, stderr, status = Open3.capture3(*args, chdir: root)
  record = { criterion: id, command: args, exit: status.exitstatus, stdout: stdout, stderr: stderr }
  records << record
  File.write(out, JSON.pretty_generate(schema: "independent-repository-audit/1", captured_at_utc: Time.now.utc.iso8601,
    head: `git -C #{root} rev-parse HEAD`.strip, baseline: baseline, records: records) + "\n")
  raise "Repository audit command failed" unless status.success?
  stdout
end

command.call("V2", "git", "diff", baseline, "HEAD", "--", "Gemfile.lock")
command.call("V6", "git", "diff", "--stat", baseline, "HEAD", "--", "helm/", ".github/workflows/")
command.call("V8", "git", "log", "--reverse", "--format=%H %s", "#{baseline}..HEAD")
command.call("V4", "git", "diff", baseline, "HEAD", "--", "CHANGELOG.md")
command.call("V5", "git", "diff", baseline, "HEAD", "--", "docs/configuration.md", "docs/advanced-reporting.md")
command.call("V7", "git", "ls-remote", "https://github.com/NickYin0125/CucumberReportportal.git",
  "refs/heads/main", "refs/heads/maintenance/1.x", "refs/heads/codex/cucumber-12", "refs/tags/*")
package = File.join(root, "docs/reviews/assets/ledger-qa-packaging", "reportportal-cucumber-ruby-#{version}.gem")
FileUtils.mkdir_p(File.dirname(package))
command.call("V3", "/opt/homebrew/opt/ruby/bin/gem", "build", "reportportal-cucumber-ruby.gemspec", "--output", package)
data = JSON.parse(File.read(out))
data["package"] = { "filename" => File.basename(package), "bytes" => File.size(package), "sha256" => Digest::SHA256.file(package).hexdigest,
  "note" => "Local build only. Temporary gem is not staged, published or uploaded." }
data["protected_heads_observed_at_task_start"] = {
  "refs/heads/main" => "75cb090a7852c56285010af17cde9ad55df1284b",
  "refs/heads/maintenance/1.x" => "4ca2f770e0a84e83688f165ba04b4db8ef855cf9",
  "refs/heads/codex/cucumber-12" => "f2e68f112ad28604f4395710f10f595246f6dc00" }
data["initial_remote_tags_artifact"] = nil
data["initial_remote_tags_note"] = "The initial remote tag listing was observed in tool output but no complete machine-readable before artifact is retained here. Do not infer whole-task V7 PASS from the exit snapshot alone."
File.write(out, JSON.pretty_generate(data) + "\n")
puts JSON.generate(version: version, recorded_commands: records.length, package: data["package"])
