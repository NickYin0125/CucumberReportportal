# frozen_string_literal: true

require "digest"
require "base64"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "securerandom"
require "time"
require_relative "png_fixture"

APPROVAL = "M4_LIVE_D_APPROVED"
abort "Refusing live traffic without Master approval (#{APPROVAL}=1)" unless ENV[APPROVAL] == "1"

required = %w[RP_ENDPOINT RP_PROJECT M4_LIVE_EVIDENCE_DIR M4_SPOOL_CLI]
missing = required.select { |key| ENV[key].to_s.empty? }
abort "Missing required private environment settings: #{missing.join(', ')}" unless missing.empty?
abort "This acceptance runner targets the existing localhost RP only" unless ENV.fetch("RP_ENDPOINT") == "http://localhost"
require_relative "auth"
ENV["RP_API_KEY"] = M4DeliveryAuth.bearer(ENV.fetch("RP_ENDPOINT"))

root = File.expand_path("../..", __dir__)
evidence_root = File.expand_path(ENV.fetch("M4_LIVE_EVIDENCE_DIR"))
FileUtils.mkdir_p(evidence_root, mode: 0o700)
File.chmod(0o700, evidence_root)
run_dir = File.join(evidence_root, "run-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{Process.pid}")
Dir.mkdir(run_dir, 0o700)
spool_dir = File.join(run_dir, "spool")
FileUtils.mkdir_p(spool_dir, mode: 0o700)

require "reportportal_cucumber"
require "reportportal_cucumber/service/payload_builder"
require "reportportal_cucumber/service/spool_store"
require "reportportal_cucumber/service/spool_replay"

config = ReportportalCucumber::Config.load(
  overrides: { spool_dir: spool_dir, retry_attempts: 1, join: false, open_timeout: 3, read_timeout: 5, write_timeout: 5 }
)
api = ReportportalCucumber::ReportPortal::API.new(config: config)
launch_name = "M4 delivery acceptance #{Time.now.utc.iso8601} #{SecureRandom.hex(3)}"
launch_uuid = SecureRandom.uuid
item_uuid = SecureRandom.uuid
launch_created = false
open_items = []
receipt_path = File.join(run_dir, "receipt.json")

def private_write(path, content)
  safe_content = content.to_s.gsub(ENV.fetch("RP_API_KEY"), "[REDACTED]")
  File.open(path, "wb", 0o600) { |file| file.write(safe_content) }
  File.chmod(0o600, path)
end

def cli_call(cli, args, cwd:, run_dir:, label:)
  audit_path = File.join(run_dir, "#{label}.http.json")
  env = { "M4_HTTP_AUDIT_PATH" => audit_path }
  stdout, stderr, status = Open3.capture3(env, "perl", "-e", "alarm 30; exec @ARGV", RbConfig.ruby,
                                       "-Ilib", File.join(cwd, "examples/m4_delivery_acceptance/cli_probe.rb"), cli, *args, chdir: cwd)
  private_write(File.join(run_dir, "#{label}.stdout"), stdout)
  private_write(File.join(run_dir, "#{label}.stderr"), stderr)
  { exit_status: status.exitstatus, stdout: stdout, stderr: stderr,
    requests: JSON.parse(File.read(audit_path)) }
end

begin
  actual_launch = api.start_launch(
    name: launch_name, start_time: Time.now, description: "M4 live delivery acceptance",
    attributes: [{ key: "m4", value: "delivery-acceptance" }], mode: "DEFAULT",
    rerun: false, rerun_of: nil, uuid: launch_uuid
  )
  launch_uuid = actual_launch
  launch_created = true
  started = Time.now
  feature_uuid = api.start_item(name: "Feature: M4 controlled replay", start_time: started, type: "SUITE",
                               launch_uuid: launch_uuid, has_stats: true, uuid: SecureRandom.uuid)
  open_items << feature_uuid
  scenario_uuid = api.start_item(name: "Scenario: Original replay attempt 1", start_time: started + 0.001, type: "STEP",
                                launch_uuid: launch_uuid, parent_uuid: feature_uuid, has_stats: true,
                                unique_id: "m4-replay-attempt-1", uuid: SecureRandom.uuid)
  open_items << scenario_uuid
  item_uuid = api.start_item(name: "Replay original action evidence", start_time: started + 0.002, type: "STEP",
                            launch_uuid: launch_uuid, parent_uuid: scenario_uuid, has_stats: false,
                            unique_id: "m4-replay-action-attempt-1", uuid: item_uuid)
  open_items << item_uuid

  join_sync = File.join(run_dir, "join.json")
  private_write(join_sync, JSON.generate(
    launchUuid: launch_uuid, launchName: launch_name, project: config.project,
    endpoint: config.endpoint, pid: Process.pid, writtenAt: Time.now.utc.iso8601
  ))
  join_lock = File.join(run_dir, "join.lock")

  cucumber_env = ENV.keys.grep(/\A(?:RP_|CUCUMBER_)/).to_h { |key| [key, nil] }.merge(
    "RP_ENDPOINT" => config.endpoint, "RP_PROJECT" => config.project, "RP_API_KEY" => config.api_key,
    "RP_LAUNCH" => launch_name,
    "RP_CLIENT_JOIN" => "true",
    "RP_CLIENT_JOIN_SYNC_FILE_NAME" => join_sync,
    "RP_CLIENT_JOIN_LOCK_FILE_NAME" => join_lock,
    "RP_FLUSH_INTERVAL" => "0.1",
    "RP_HTTP_RETRY_ATTEMPTS" => "1",
    "RP_EXIT_FLUSH_TIMEOUT_MS" => "5000",
    "RP_FAIL_ON_REPORTING_ERROR" => "false",
    "RP_SPOOL_DIR" => spool_dir, "RP_REPORTING_ASYNC" => "false", "RP_BATCH_SIZE_LOGS" => "1",
    "RP_HTTP_READ_TIMEOUT" => "5", "RP_HTTP_WRITE_TIMEOUT" => "5", "RP_HTTP_OPEN_TIMEOUT" => "3",
    "M4_HTTP_AUDIT_PATH" => File.join(run_dir, "cucumber.http.json")
  )
  cucumber = ["bundle", "exec", "cucumber", "--no-profile", "--publish-quiet", "--require",
              "features/support/env.rb", "--require",
              "examples/m4_delivery_acceptance/features/steps/delivery_steps.rb",
              "--require", "examples/m4_delivery_acceptance/http_audit.rb",
              "--format", "progress", "--out", File.join(run_dir, "progress.txt"),
              "--format", "json", "--out", File.join(run_dir, "cucumber.json"),
              "--format", "ReportPortal::Cucumber::Formatter", "--out", File.join(run_dir, "formatter.log"),
              "examples/m4_delivery_acceptance/features/delivery.feature"]
  out, err, cucumber_status = Open3.capture3(cucumber_env, "perl", "-e", "alarm 90; exec @ARGV", *cucumber, chdir: root)
  private_write(File.join(run_dir, "cucumber.stdout"), out)
  private_write(File.join(run_dir, "cucumber.stderr"), err)
  abort "Cucumber did not produce the deliberate scenario failure (exit #{cucumber_status.exitstatus})" unless cucumber_status.exitstatus == 1
  abort "Cucumber output omitted deliberate business failure" unless File.read(File.join(run_dir, "progress.txt")).include?("Deliberate M4 acceptance failure")
  results = JSON.parse(File.read(File.join(run_dir, "cucumber.json")))
  scenarios = results.flat_map { |feature| Array(feature["elements"]) }.select { |element| element["type"] == "scenario" }
  abort "Cucumber did not execute exactly the two acceptance scenarios" unless scenarios.length == 2
  statuses = scenarios.flat_map { |scenario| Array(scenario["steps"]) }.map { |step| step.dig("result", "status") }
  abort "Cucumber JSON did not prove both passing and failing scenarios" unless statuses.include?("passed") && statuses.include?("failed")

  png = M4DeliveryPNG.bytes
  records = [
    { launch_uuid: launch_uuid, item_uuid: item_uuid, timestamp: Time.now.utc,
      message: JSON.generate("source" => "controlled replay", "scenario" => launch_name), level: :info },
    { launch_uuid: launch_uuid, item_uuid: item_uuid, timestamp: Time.now.utc,
      message: "M4 replay screenshot", level: :info,
      attachment: { name: "m4-replay.png", mime: "image/png", bytes: png } }
  ]
  payload = ReportportalCucumber::Service::PayloadBuilder.build_log_batch(records)
  store = ReportportalCucumber::Service::SpoolStore.new(config: config)
  transaction_id = store.persist(entries: payload.fetch(:entries), files: payload.fetch(:files),
                                 outcome: :ambiguous, diagnostics: { "source" => "m4-live-acceptance" })

  cli = File.expand_path(ENV.fetch("M4_SPOOL_CLI"), root)
  replay = cli_call(cli, ["--spool-dir", spool_dir, "--transaction", transaction_id,
                          "--execute", "--allow-duplicates", "--timeout", "20"],
                    cwd: root, run_dir: run_dir, label: "replay-open")
  abort "Open-target replay did not complete: #{replay[:exit_status]}" unless replay[:exit_status].zero?
  replay_summary = JSON.parse(replay.fetch(:stdout))
  abort "Open-target replay did not confirm both per-entry acknowledgements" unless replay_summary.fetch("confirmed") == 2 && !replay_summary.fetch("retained")

  open_items.reverse_each do |uuid|
    api.finish_item(item_uuid: uuid, launch_uuid: launch_uuid, end_time: Time.now, status: "PASSED")
  end
  open_items.clear
  api.finish_launch(launch_uuid: launch_uuid, end_time: Time.now, status: "FAILED")
  launch_created = false

  checkpoint_before = store.load_transaction(id: transaction_id).fetch(:checkpoint)
  completed_resume = cli_call(cli, ["--spool-dir", spool_dir, "--transaction", transaction_id,
                                   "--execute", "--timeout", "20"],
                             cwd: root, run_dir: run_dir, label: "replay-completed")
  abort "Completed resume contacted HTTP or failed" unless completed_resume[:exit_status].zero? && completed_resume[:requests].empty?
  closed_id = store.persist(entries: payload.fetch(:entries), files: payload.fetch(:files),
                            outcome: :failed, diagnostics: { "source" => "closed-original-target-probe" })
  closed_before = store.load_transaction(id: closed_id).fetch(:checkpoint)
  closed = cli_call(cli, ["--spool-dir", spool_dir, "--transaction", closed_id,
                          "--execute", "--allow-duplicates", "--timeout", "20"],
                    cwd: root, run_dir: run_dir, label: "replay-closed")
  abort "Closed-target replay unexpectedly succeeded" unless closed[:exit_status] == 2
  abort "Closed-target refusal was not explicit" unless closed[:stderr].include?("Original target is not open")
  checkpoint_after = store.load_transaction(id: transaction_id).fetch(:checkpoint)
  abort "Closed-target replay changed the durable checkpoint" unless checkpoint_before == checkpoint_after
  abort "Closed probe changed checkpoint or sent a POST" unless closed_before == store.load_transaction(id: closed_id).fetch(:checkpoint) &&
                                                              closed[:requests].none? { |request| request["method"].start_with?("post") }

  receipt = {
    "launch_name" => launch_name, "launch_uuid" => launch_uuid, "item_uuid" => item_uuid,
    "controlled_feature_uuid" => feature_uuid, "controlled_scenario_uuid" => scenario_uuid,
    "attempt" => 1, "launch_status" => "FAILED", "expected_statistics" => { "total" => 3, "passed" => 2, "failed" => 1 },
    "feature_exit_status" => cucumber_status.exitstatus,
    "feature_scenario_statuses" => statuses,
    "feature_failure_preserved" => true,
    "transaction_id" => transaction_id,
    "replay_open_exit_status" => replay[:exit_status],
    "replay_open_summary" => replay_summary,
    "replay_closed_exit_status" => closed[:exit_status],
    "completed_resume_exit_status" => completed_resume[:exit_status], "completed_resume_no_http" => true,
    "closed_transaction_id" => closed_id, "replay_requests" => replay[:requests],
    "replay_closed_refused_without_checkpoint_change" => true,
    "attachment" => { "name" => "m4-replay.png", "bytes" => png.bytesize,
                       "sha256" => Digest::SHA256.hexdigest(png) },
    "acknowledged_ids" => checkpoint_after.fetch("states").map { |entry| entry.fetch("id") },
    "evidence_directory" => run_dir
  }
  private_write(receipt_path, JSON.pretty_generate(receipt) + "\n")
  private_write(File.join(evidence_root, "latest.json"), JSON.generate("receipt" => receipt_path) + "\n")
  puts "m4_live_run=COMPLETE receipt=#{receipt_path} feature_exit=1 replay_confirmed=#{replay_summary.fetch('confirmed')}"
rescue StandardError => error
  warn "M4 live acceptance failed: #{error.class}; private evidence=#{run_dir}"
  raise
ensure
  open_items.reverse_each { |uuid| api.finish_item(item_uuid: uuid, launch_uuid: launch_uuid, end_time: Time.now, status: "FAILED") rescue nil }
  if launch_created
    api.finish_launch(launch_uuid: launch_uuid, end_time: Time.now, status: "FAILED") rescue nil
  end
end
