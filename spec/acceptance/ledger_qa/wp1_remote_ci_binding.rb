# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "time"

module Wp1RemoteCiBinding
  ROOT = File.expand_path("../../..", __dir__)
  DIRECTORY = "docs/reviews/assets/wp1-release-20261101"
  INPUT = "#{DIRECTORY}/remote-ci-input-r3.json"
  OUTPUT = "#{DIRECTORY}/remote-ci-r3.json"
  HELPER = "spec/acceptance/ledger_qa/wp1_remote_ci_binding.rb"
  HEAD = "2ad45b29cbf0eb3b491979ffc60553ee9a414aed"
  REPOSITORY = "NickYin0125/CucumberReportportal"
  EVENTS = { 41_306_545_170 => "pull_request", 41_306_540_562 => "push" }.freeze
  RUN_FIELDS = %w[conclusion created_at event head_branch head_sha html_url id path status updated_at].freeze
  JOB_FIELDS = %w[completed_at conclusion head_sha html_url id name started_at status].freeze
  TESTS = [
    "test / test (Ruby 3.3)", "test / test (Ruby 3.4)",
    "test / legacy (Ruby 3.1, Cucumber 9)", "test / legacy (Ruby 3.1, Cucumber 10)",
    "test / legacy (Ruby 3.3, Cucumber 9)", "test / legacy (Ruby 3.3, Cucumber 10)"
  ].freeze
  EXPECTED_JOBS = (TESTS + ["test / gate", "test / bundle"]).freeze
  WORKFLOWS = %w[.github/workflows/ci.yml .github/workflows/validate.yml].freeze

  module_function

  def relative_file(path)
    File.join(ROOT, path)
  end

  def git(*arguments)
    stdout, stderr, status = Open3.capture3("git", "-C", ROOT, *arguments)
    raise "Git source lookup failed: #{stderr.strip}" unless status.success?

    stdout
  end

  def workflow_sources
    WORKFLOWS.to_h { |path| [path, git("show", "#{HEAD}:#{path}")] }
  end

  def check(rows, id, expected, actual)
    rows << { "id" => id, "expected" => expected, "actual" => actual,
              "verdict" => expected == actual ? "PASS" : "FAIL" }
  end

  def checks_for(input, observation, workflows)
    rows = []
    records = observation.fetch("records")
    check(rows, "master-input-head", HEAD, input.fetch("candidate_head"))
    check(rows, "master-run-membership", EVENTS.keys.sort, input.fetch("records").map { |r| r.fetch("run").fetch("id") }.sort)
    check(rows, "independent-run-membership", EVENTS.keys.sort, records.map { |r| r.fetch("run").fetch("id") }.sort)
    EVENTS.each do |id, event|
      record = records.find { |r| r.fetch("run").fetch("id") == id }
      master = input.fetch("records").find { |r| r.fetch("run").fetch("id") == id }
      next unless record && master

      run = record.fetch("run")
      jobs = record.fetch("jobs")
      prefix = "run-#{id}"
      expected = { "id" => id, "head_sha" => HEAD, "event" => event, "status" => "completed",
                   "conclusion" => "success", "run_attempt" => 1,
                   "head_branch" => "codex/presentation-ledger-2.0.1", "path" => ".github/workflows/ci.yml",
                   "html_url" => "https://github.com/#{REPOSITORY}/actions/runs/#{id}" }
      check(rows, "#{prefix}-identity-event-status", expected, run.slice(*expected.keys))
      check(rows, "#{prefix}-master-run-schema", RUN_FIELDS.sort, master.fetch("run").keys.sort)
      check(rows, "#{prefix}-master-run-corroborated", master.fetch("run"), run.slice(*RUN_FIELDS))
      check(rows, "#{prefix}-complete-jobs-page", [8, 8], [record.fetch("jobs_total_count"), jobs.length])
      check(rows, "#{prefix}-exact-job-membership", EXPECTED_JOBS.sort, jobs.map { |job| job.fetch("name") }.sort)
      check(rows, "#{prefix}-unique-job-ids", jobs.length, jobs.map { |job| job.fetch("id") }.uniq.length)
      expected_binding = jobs.map { |job| [job.fetch("id"), id, HEAD, 1] }
      actual_binding = jobs.map { |job| job.values_at("id", "run_id", "head_sha", "run_attempt") }
      check(rows, "#{prefix}-job-head-run-attempt-binding", expected_binding, actual_binding)
      expected_status = jobs.map { |job| [job.fetch("id"), "completed", job.fetch("name") == "test / bundle" ? "skipped" : "success"] }
      check(rows, "#{prefix}-tests-gate-success-bundle-skip", expected_status, jobs.map { |job| job.values_at("id", "status", "conclusion") })
      check(rows, "#{prefix}-master-job-schemas", [JOB_FIELDS.sort], master.fetch("jobs").map { |job| job.keys.sort }.uniq)
      # Preserve complete rows and multiplicity; only enumeration order is irrelevant here.
      check(rows, "#{prefix}-master-jobs-corroborated", master.fetch("jobs").sort_by { |job| job.fetch("id") },
            jobs.map { |job| job.slice(*JOB_FIELDS) }.sort_by { |job| job.fetch("id") })
      check(rows, "#{prefix}-jobs-endpoint", "https://api.github.com/repos/#{REPOSITORY}/actions/runs/#{id}/jobs?per_page=100", record.fetch("jobs_api_url"))
    end
    ci = workflows.fetch(WORKFLOWS[0])
    validation = workflows.fetch(WORKFLOWS[1])
    check(rows, "ci-calls-validation-without-release-override", true,
          ci.end_with?("jobs:\n  test:\n    uses: ./.github/workflows/validate.yml\n") && !ci.match?(/^\s+with:/))
    check(rows, "release-input-default-false", true,
          validation.include?("      release:\n        type: boolean\n        default: false\n"))
    check(rows, "gate-requires-both-test-families-success", true,
          validation.include?('test "$CURRENT_RESULT" = success') && validation.include?('test "$LEGACY_RESULT" = success'))
    check(rows, "bundle-requires-release-push-tag", true,
          validation.include?("  bundle:\n    needs: gate\n    if: inputs.release && github.event_name == 'push' && github.ref_type == 'tag'\n"))
    rows
  end

  def validate_observation_shape!(observation)
    raise "Unexpected observation fields" unless observation.keys.sort == %w[collector records]

    observation.fetch("records").each do |record|
      raise "Unexpected record fields" unless record.keys.sort == %w[jobs jobs_api_url jobs_total_count run]
      raise "Unexpected run fields" unless record.fetch("run").keys.sort == (RUN_FIELDS + ["run_attempt"]).sort

      record.fetch("jobs").each do |job|
        raise "Unexpected job fields" unless job.keys.sort == (JOB_FIELDS + %w[run_id run_attempt]).sort
      end
    end
  end

  def build(observation, observed_at)
    validate_observation_shape!(observation)
    input = JSON.parse(File.binread(relative_file(INPUT)))
    workflows = workflow_sources
    checks = checks_for(input, observation, workflows)
    bindings = workflows.map do |path, contents|
      mode, type, blob, listed_path = git("ls-tree", HEAD, "--", path).split
      raise "Unexpected workflow tree entry" unless type == "blob" && listed_path == path

      { "path" => path, "mode" => mode, "git_blob" => blob,
        "sha256" => Digest::SHA256.hexdigest(contents), "bytes" => contents.bytesize }
    end
    references = [INPUT, HELPER, "#{DIRECTORY}/binding-r3.json"].map do |path|
      { "path" => path, "sha256" => Digest::SHA256.file(relative_file(path)).hexdigest }
    end
    {
      "schema" => "wp1-remote-ci-metadata-proof/1", "observed_at_utc" => observed_at,
      "repository" => REPOSITORY, "candidate_head" => HEAD,
      "scope" => "API-bound run/job status only; not raw test-log or example-count verification, WP5 certification, redaction acceptance, or release authorization.",
      "not_examined" => ["Remote raw test logs and example counts", "New full-suite, matrix, RP or redaction execution", "Publication outside these two CI runs"],
      "credential_handling" => "Authorized read-only GitHub connector; no credential files, headers, tokens or authentication responses retained.",
      "references" => references, "workflow_bindings" => bindings,
      "workflow_policy" => { "release_default" => false, "ci_override" => false,
                             "bundle_condition" => "inputs.release && github.event_name == 'push' && github.ref_type == 'tag'",
                             "interpretation" => "The observed bundle skip is expected; neither run supplies release=true. No publication or release authorization is inferred." },
      "collection_history" => input.fetch("prior_fetch_attempt"),
      "independent_api_observation" => observation, "checks" => checks,
      "verdict" => checks.all? { |row| row.fetch("verdict") == "PASS" } ? "PASS" : "FAIL"
    }
  end

  def verify
    proof = JSON.parse(File.binread(relative_file(OUTPUT)))
    expected = build(proof.fetch("independent_api_observation"), proof.fetch("observed_at_utc"))
    raise "Stored proof differs from recomputed proof" unless proof == expected
    raise "One or more metadata checks failed" unless proof.fetch("verdict") == "PASS"

    puts "PASS: #{proof.fetch('checks').length} metadata checks; no remote raw-example-count claim"
  end

  def self_test
    proof = JSON.parse(File.binread(relative_file(OUTPUT)))
    original_input = JSON.parse(File.binread(relative_file(INPUT)))
    original_observation = proof.fetch("independent_api_observation")
    original_workflows = workflow_sources
    mutations = {
      "wrong master head" => ->(i, _, _) { i["candidate_head"] = "0" * 40 },
      "wrong run head" => ->(_, o, _) { o["records"][0]["run"]["head_sha"] = "0" * 40 },
      "wrong event" => ->(_, o, _) { o["records"][0]["run"]["event"] = "workflow_dispatch" },
      "wrong run attempt" => ->(_, o, _) { o["records"][0]["run"]["run_attempt"] = 2 },
      "incomplete page" => ->(_, o, _) { o["records"][0]["jobs_total_count"] = 9 },
      "missing job" => ->(_, o, _) { o["records"][0]["jobs"].pop },
      "duplicate job" => ->(_, o, _) { o["records"][0]["jobs"][-1] = o["records"][0]["jobs"][0].dup },
      "wrong job head" => ->(_, o, _) { o["records"][0]["jobs"][0]["head_sha"] = "0" * 40 },
      "wrong job run" => ->(_, o, _) { o["records"][0]["jobs"][0]["run_id"] = 1 },
      "skipped test" => ->(_, o, _) { o["records"][0]["jobs"][0]["conclusion"] = "skipped" },
      "failed gate" => ->(_, o, _) { o["records"][0]["jobs"].find { |j| j["name"] == "test / gate" }["conclusion"] = "failure" },
      "bundle unexpectedly ran" => ->(_, o, _) { o["records"][0]["jobs"].find { |j| j["name"] == "test / bundle" }["conclusion"] = "success" },
      "inconsistent Master job" => ->(i, _, _) { i["records"][0]["jobs"][0]["completed_at"] = "changed" },
      "release defaults true" => ->(_, _, w) { w[WORKFLOWS[1]] = w[WORKFLOWS[1]].sub("default: false", "default: true") },
      "release override" => ->(_, _, w) { w[WORKFLOWS[0]] += "    with:\n      release: true\n" },
      "weakened gate" => ->(_, _, w) { w[WORKFLOWS[1]] = w[WORKFLOWS[1]].sub('test "$LEGACY_RESULT" = success', "true") },
      "weakened bundle guard" => ->(_, _, w) { w[WORKFLOWS[1]] = w[WORKFLOWS[1]].sub("if: inputs.release &&", "if: true ||") }
    }
    raise "Positive control failed" unless checks_for(original_input, original_observation, original_workflows).all? { |row| row["verdict"] == "PASS" }

    mutations.each do |name, mutation|
      input, observation, workflows = Marshal.load(Marshal.dump([original_input, original_observation, original_workflows]))
      mutation.call(input, observation, workflows)
      raise "Negative control accepted: #{name}" unless checks_for(input, observation, workflows).any? { |row| row["verdict"] == "FAIL" }
    end
    puts "PASS: #{mutations.length + 1} validator controls (one positive, #{mutations.length} negative)"
  end

  def main(arguments)
    case arguments
    when ["--capture"]
      proof = build(JSON.parse($stdin.read), Time.now.utc.iso8601)
      File.open(relative_file(OUTPUT), File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.write(JSON.pretty_generate(proof) + "\n")
      end
      verify
    when ["--verify"] then verify
    when ["--self-test"] then self_test
    else raise ArgumentError, "Usage: ruby #{HELPER} --capture|--verify|--self-test"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    Wp1RemoteCiBinding.main(ARGV)
  rescue StandardError => error
    warn "FAIL: #{error.class}: #{error.message}"
    exit 1
  end
end
