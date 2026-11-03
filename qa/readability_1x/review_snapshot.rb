# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "optparse"
require "yaml"

options = { source: "/Users/nick/Documents/crr-1.3.3" }
OptionParser.new do |parser|
  parser.on("--frozen-sha SHA") { |value| options[:sha] = value }
  parser.on("--source PATH") { |value| options[:source] = File.expand_path(value) }
  parser.on("--out PATH") { |value| options[:out] = File.expand_path(value) }
end.parse!
abort "Exact frozen SHA and output path required" unless options[:sha].to_s.match?(/\A[0-9a-f]{40}\z/) && options[:out]

def git(source, *argv)
  stdout, stderr, status = Open3.capture3("git", "-C", source, *argv)
  raise "Review Git command failed: #{stderr}" unless status.success?

  stdout
end

base = "19174a5ecaf1aa9fb65480f0a21d74ed65c89a8d"
sha = options.fetch(:sha)
source = options.fetch(:source)
raise "Review source HEAD differs" unless git(source, "rev-parse", "HEAD").strip == sha
raise "Review source has tracked changes" unless git(source, "status", "--porcelain", "--untracked-files=no").empty?
paths = git(source, "ls-tree", "-r", "--name-only", sha, "lib").lines(chomp: true)
libraries = paths.to_h do |path|
  baseline = Digest::SHA256.hexdigest(git(source, "show", "#{base}:#{path}"))
  candidate = Digest::SHA256.hexdigest(git(source, "show", "#{sha}:#{path}"))
  [path, { baseline_sha256: baseline, candidate_sha256: candidate, unchanged: baseline == candidate }]
end
allowed_runtime = %w[
  lib/reportportal_cucumber/automation/evidence_redactor.rb
  lib/reportportal_cucumber/automation/http_exchange.rb
  lib/reportportal_cucumber/presentation/accent.rb
  lib/reportportal_cucumber/presentation/attachment_caption.rb
  lib/reportportal_cucumber/presentation/failure_card.rb
  lib/reportportal_cucumber/presentation/run_context.rb
  lib/reportportal_cucumber/service/evidence_presenter.rb
  lib/reportportal_cucumber/service/payload_builder.rb
  lib/reportportal_cucumber/version.rb
]
changed = libraries.reject { |_path, entry| entry.fetch(:unchanged) }.keys
raise "Unexpected runtime backport scope: #{changed - allowed_runtime}" unless (changed - allowed_runtime).empty?
protected_paths = %w[
  lib/reportportal_cucumber/cucumber/formatter.rb
  lib/reportportal_cucumber/cucumber/native_lifecycle.rb
  lib/reportportal_cucumber/automation/failure_redactor.rb
  lib/reportportal_cucumber/automation/app_log.rb
  lib/reportportal_cucumber/automation/report_context.rb
  lib/reportportal_cucumber/runtime/context.rb
  lib/reportportal_cucumber/runtime/log_buffer.rb
  lib/reportportal_cucumber/runtime/join.rb
  lib/reportportal_cucumber/service/queue_processor.rb
  lib/reportportal_cucumber/service/spool_store.rb
]
raise "Protected 1.x runtime changed" unless protected_paths.all? { |path| libraries.fetch(path).fetch(:unchanged) }
workflow = YAML.safe_load(git(source, "show", "#{sha}:.github/workflows/validate.yml"), aliases: true)
matrix = workflow.dig("jobs", "test", "strategy", "matrix")
raise "Actual CI matrix differs" unless matrix == { "ruby" => %w[3.1 3.3], "cucumber" => %w[9.2.1 10.2.0] }
chart = YAML.safe_load(git(source, "show", "#{sha}:helm/reportportal-rich-experience/Chart.yaml"), aliases: true)
raise "Helm version changed" unless chart.fetch("version") == "1.3.1"
File.write(options.fetch(:out), JSON.pretty_generate(
  source: source, baseline: base, frozen_sha: sha, tracked_source_clean: true,
  changed_runtime_paths: changed, protected_runtime_paths: protected_paths, library_hashes: libraries,
  actual_ci_matrix: matrix, helm_version: chart.fetch("version"),
  review_scope_status: "PASS; behavioral acceptance still requires all runtime/live/package/performance gates",
  no_sdk_implementation_edits: true) + "\n")
puts JSON.generate(frozen_sha: sha, runtime_files: libraries.length, changed_runtime_files: changed.length,
  protected_runtime_files_unchanged: protected_paths.length, status: "SCOPE_REVIEW_PASS")
