# frozen_string_literal: true

require "json"
require "yaml"
require "open3"
require "digest"
require "fileutils"
require "time"
require_relative "final_wp5_context"

previous = LedgerWP5Context::HEADS.fetch("wp5-final-rerun-20261101")
stamp = LedgerWP5Context.stamp
raise "Decision16 audit is for the exact new CI heads only" unless stamp == "wp5-ci-final-20261101"
LedgerWP5Context.heads.each do |version, head|
  qa = "/Users/nick/Documents/crr-qa-#{version}"
  repository = "/Users/nick/Documents/crr-#{version}"
  output = File.join(qa, "docs/reviews/assets", stamp, "decision16-independent-audit.json")
  raise "Never replace a prior CI audit" if File.exist?(output)
  git = lambda do |*args|
    stdout, stderr, result = Open3.capture3("git", "-C", repository, *args)
    raise "Read-only Git audit failed: #{stderr}" unless result.success?
    stdout
  end
  old = previous.fetch(version)
  names = git.call("diff", "--name-status", old, head).lines.map { |line| line.chomp.split("\t") }
  workflow = ".github/workflows/validate.yml"
  decisions = "docs/design/presentation-ledger-owner-decisions.md"
  additions = %w[spec/release/rspec_fault_observability_spec.rb spec/reportportal_cucumber/service/spool_deadline_semantics_spec.rb]
  expected_names = [["M", workflow], ["M", decisions]] + additions.map { |path| ["A", path] }
  protected_diff = git.call("diff", "--name-only", old, head, "--", "lib", "Gemfile", "Gemfile.lock", "reportportal-cucumber-ruby.gemspec", "helm")
  old_workflow, new_workflow = [old, head].map { |sha| git.call("show", "#{sha}:#{workflow}") }
  before, after = [old_workflow, new_workflow].map { |bytes| YAML.safe_load(bytes) }
  raw_after = Marshal.load(Marshal.dump(after))
  diagnostic_steps = []
  after.fetch("jobs").each do |job, definition|
    steps = definition.fetch("steps", [])
    steps.reject! do |step|
      selected = ["Prepare synthetic RSpec fault diagnostics", "Retain synthetic RSpec fault diagnostics"].include?(step["name"])
      diagnostic_steps << { job: job, step: step } if selected
      selected
    end
    steps.each do |step|
      next unless job == "test" && step.fetch("run", "") == "bundle exec rspec"
      environment = step.fetch("env", {})
      environment.delete("DAY2_LOCAL_CAPTURE")
      environment.delete("M4_D_EVIDENCE_DIR")
      step.delete("env") if environment.empty?
    end
  end
  capture_scopes = diagnostic_steps.all? do |entry|
    job, step = entry.values_at(:job, :step)
    next false unless %w[test legacy].include?(job)
    if step["name"].start_with?("Retain")
      base = job == "legacy" ? "legacy-rspec-fault-diagnostics" : "rspec-fault-diagnostics"
      step["if"] == "always()" && step["uses"] == "actions/upload-artifact@v6" &&
        step.dig("with", "path") == "${{ runner.temp }}/#{base}/" && step.dig("with", "retention-days") == 7 &&
        !step.key?("continue-on-error")
    else
      step.fetch("run").include?("umask 077") && !step.fetch("run").match?(/RP_EXIT_FLUSH|SPEC_OPTS|RSPEC_OPTS|RUBYOPT|credentials|\|\|\s*true/)
    end
  end
  expected_jobs = before.fetch("jobs").key?("legacy") ? %w[legacy test] : ["test"]
  actual_jobs = diagnostic_steps.group_by { |entry| entry.fetch(:job) }.transform_values { |rows| rows.map { |row| row.dig(:step, "name") }.sort }
  expected_job_steps = expected_jobs.to_h { |job| [job, ["Prepare synthetic RSpec fault diagnostics", "Retain synthetic RSpec fault diagnostics"].sort] }
  docs = git.call("show", "#{head}:#{decisions}")
  question = "远端 CI 的未改动 1.3.1 基线出现 SIGINT/Spool 和超时失败。是否允许把这些既有 CI 稳定性问题纳入独立排查，必要时另作修复提交？保持全部断言，不推受保护分支、不合并或发布。"
  answer = "允许独立排查与必要修复（推荐）"
  checks = {
    exact_changed_file_allowlist: names.sort == expected_names.sort,
    runtime_dependencies_and_helm_unchanged: protected_diff.empty?,
    no_existing_spec_modified: names.select { |_, path| path.start_with?("spec/") }.all? { |status, path| status == "A" && additions.include?(path) },
    existing_workflow_semantics_identical_after_removing_only_allowed_capture_additions: before == after,
    only_expected_diagnostic_steps_added: actual_jobs == expected_job_steps,
    bounded_synthetic_capture_scopes: capture_scopes,
    exact_owner_question_and_answer_recorded_at_new_head: docs.include?(question) && docs.include?(answer)
  }
  data = { schema: "decision16-independent-exact-diff-audit/1", assessed_at_utc: Time.now.utc.iso8601, version: version,
    previous_sha: old, runtime_sha: head, owner_exact_question: question, owner_exact_answer: answer,
    changed_files: names, protected_path_diff: protected_diff, workflow_diff: git.call("diff", old, head, "--", workflow),
    workflow_before_sha256: Digest::SHA256.hexdigest(old_workflow), workflow_after_sha256: Digest::SHA256.hexdigest(new_workflow),
    diagnostic_steps: diagnostic_steps, current_suite_step_environment: raw_after.dig("jobs", "test", "steps").to_a.select { |step| step.fetch("run", "") == "bundle exec rspec" }.map { |step| step["env"] },
    checks: checks, verdict: checks.values.all? ? "PASS" : "FAIL",
    claim_limit: "V6's owner-approved bounded CI exception only. Not a G10 waiver, runner-cause conclusion, product repair, or overall acceptance." }
  FileUtils.mkdir_p(File.dirname(output))
  File.write(output, JSON.pretty_generate(data) + "\n")
  puts JSON.generate(version: version, verdict: data[:verdict], checks: checks)
end
