# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "time"

EVIDENCE = File.expand_path(ENV.fetch("M3C_LIVE_EVIDENCE"))
SDK = File.expand_path("../../../tmp/m2m3-regression-20261009/live/sdk", __dir__)
CANDIDATE = "/tmp/m2m3-regression-20261009-candidate"

def inventory(root, subdir)
  Dir.glob(File.join(root, subdir, "**", "*"), File::FNM_DOTMATCH).select { |path| File.file?(path) }
    .sort.to_h { |path| [path.delete_prefix("#{root}/"), Digest::SHA256.file(path).hexdigest] }
end

def main
  summary = JSON.parse(File.read(File.join(EVIDENCE, "run-summary.json")))
  verification = JSON.parse(File.read(File.join(EVIDENCE, "api-verification.json")))
  items = JSON.parse(File.read(File.join(EVIDENCE, "items-api.json")))
  feature_repo = JSON.parse(File.read(File.join(EVIDENCE, "fixture-repo.json")))
  sdk_lib = inventory(SDK, "lib")
  candidate_lib = inventory(CANDIDATE, "lib")
  sdk_spec = inventory(SDK, "spec")
  candidate_spec = inventory(CANDIDATE, "spec")
  sdk_digest = Digest::SHA256.file(File.join(SDK, "lib/reportportal_cucumber.rb")).hexdigest
  candidate_digest = Digest::SHA256.file(File.join(CANDIDATE, "lib/reportportal_cucumber.rb")).hexdigest
  bundle_env = { "BUNDLE_GEMFILE" => ENV.fetch("M3C_LIVE_GEMFILE") }
  command = ["bundle", "exec", "ruby", "-e", 'require "cucumber"; require "reportportal_cucumber"; puts "cucumber=#{Cucumber::VERSION}"; puts "sdk_version=#{ReportportalCucumber::VERSION}"; puts "sdk_source=#{ReportPortal::Cucumber::Formatter.instance_method(:initialize).source_location&.first}"; puts "bundler=#{Bundler::VERSION}"']
  runtime_out, runtime_status = Open3.capture2(bundle_env, *command, chdir: File.join(__dir__, "..", "m3b"))
  raise "Bundled runtime probe failed" unless runtime_status.success?
  failures = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false && item["status"] == "FAILED" }
  scenarios = items.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
  output_files = %w[run-summary.json handoff.json items-api.json cucumber.json cucumber.stdout.log formatter.log api-verification.json fixture-repo.json reference-server-ready.json].map do |name|
    { path: File.join(EVIDENCE, name), exists: File.file?(File.join(EVIDENCE, name)), sha256: File.file?(File.join(EVIDENCE, name)) ? Digest::SHA256.file(File.join(EVIDENCE, name)).hexdigest : nil }
  end
  serialized = output_files.select { |entry| entry[:exists] }.map { |entry| File.read(entry.fetch(:path)) }.join("\n")
  secrets = [ENV["RP_API_KEY"], ENV.fetch("RP_PASSWORD", "erebus")].compact.reject(&:empty?)
  checks = {
    candidate_and_live_sdk_lib_byte_equal: sdk_lib == candidate_lib,
    candidate_and_live_sdk_spec_byte_equal: sdk_spec == candidate_spec,
    entrypoint_hash_matches_candidate: sdk_digest == candidate_digest,
    child_exit_is_expected_intentional_failure: summary.fetch("cucumber_exit_status") == 1,
    launch_failed_only_for_expected_one_case: summary.fetch("launch_status") == "FAILED" && summary.fetch("observed_counts") == { "suite_count" => 2, "scenario_count" => 5, "passed_count" => 4, "failed_count" => 1 },
    api_oracle_22_checks_pass: verification.fetch("passed") && verification.fetch("checks").length == 22,
    native_types_and_statuses_match_literal_expectation: scenarios.length == 5 && scenarios.count { |item| item["status"] == "PASSED" } == 4 && scenarios.count { |item| item["status"] == "FAILED" } == 1 && failures.length == 1,
    item_ids_are_integers_and_uuids_unique: items.all? { |item| item["id"].is_a?(Integer) && item["uuid"].to_s.match?(/\A[0-9a-f-]{36}\z/) } && items.map { |item| item["uuid"] }.uniq.length == items.length,
    retry_and_case_hashes_recorded: scenarios.all? { |item| item.key?("testCaseHash") && item.key?("testCaseId") },
    synthetic_source_commit_is_clean_and_fixed: begin
      head, head_status = Open3.capture2("git", "-C", File.join(EVIDENCE, "sandbox"), "rev-parse", "HEAD")
      worktree, worktree_status = Open3.capture2("git", "-C", File.join(EVIDENCE, "sandbox"), "status", "--porcelain")
      head_status.success? && worktree_status.success? && head.strip == feature_repo.fetch("commit") && worktree.empty?
    end,
    output_receipts_contain_no_known_secret_values: secrets.none? { |secret| serialized.include?(secret) }
  }
  receipt = {
    classification: "M3C live execution provenance reconciliation; local ReportPortal launch and synthetic loopback references",
    generated_at_utc: Time.now.utc.iso8601, endpoint: ENV.fetch("RP_ENDPOINT", "http://localhost"), project: ENV.fetch("RP_PROJECT", "superadmin_personal"),
    launch: summary.slice("launch_name", "launch_id", "launch_uuid", "launch_status", "launch_url", "launch_end_time", "launch_statistics", "cucumber_exit_status", "cucumber_version"),
    runtime: { ruby: RbConfig.ruby, ruby_version: RUBY_VERSION, bundled_probe: runtime_out.lines.map(&:strip),
               sdk_path: SDK, sdk_entrypoint_sha256: sdk_digest, candidate_path: CANDIDATE,
               candidate_entrypoint_sha256: candidate_digest, cucumber_gemfile: ENV.fetch("M3C_LIVE_GEMFILE") },
    topology: { suites: items.select { |item| item["type"] == "SUITE" }.map { |item| item.slice("id", "uuid", "name", "status", "testCaseHash") },
                scenarios: scenarios.map { |item| item.slice("id", "uuid", "name", "type", "hasStats", "status", "parent", "testCaseId", "testCaseHash", "codeRef") },
                failed_actions: failures.map { |item| item.slice("id", "uuid", "name", "type", "status", "parent", "testCaseHash") },
                raw_api_id_class: items.first.fetch("id").class.name },
    synthetic_fixture: { repository: File.join(EVIDENCE, "sandbox"), commit: feature_repo.fetch("commit"),
                         allowed_files: feature_repo.fetch("files"), reference_server: JSON.parse(File.read(File.join(EVIDENCE, "reference-server-ready.json"))) },
    api_verification_path: File.join(EVIDENCE, "api-verification.json"),
    output_files: output_files,
    reconciliation_output_path: File.join(EVIDENCE, "execution-reconciliation.json"),
    checks: checks, passed: checks.values.all?,
    ui_boundary: "This API/live-reference receipt does not assert Master physical GUI acceptance; synthetic Source, run-record and TMS pages are not external CI or TMS integrations."
  }
  File.write(File.join(EVIDENCE, "execution-reconciliation.json"), JSON.pretty_generate(receipt) + "\n")
  puts "launch_id=#{summary.fetch('launch_id')} runtime=#{runtime_out.lines.map(&:strip).join('|')} checks=#{checks.values.count(true)}/#{checks.length}"
  abort "M3C execution reconciliation failed" unless receipt.fetch(:passed)
end

main
