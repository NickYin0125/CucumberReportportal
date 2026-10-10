# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "securerandom"
require "time"
require "uri"

EXAMPLE_DIR = __dir__
ROOT_DIR = File.expand_path("../..", EXAMPLE_DIR)
EVIDENCE_DIR = ENV.fetch("M2_EVIDENCE_DIR", File.join(ROOT_DIR, "tmp", "m2-typewords-live"))
ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://localhost")
PROJECT = ENV.fetch("RP_PROJECT", "superadmin_personal")
LAUNCH = ENV.fetch("RP_LAUNCH", "typewords-m2-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}-#{SecureRandom.hex(3)}")
TOKEN_TEXT = ENV.fetch("RP_API_KEY", "").strip
CANARY = "M2_CANARY_PRIVATE_TEXT_7391"
FEATURE = "features/typewords_acceptance.feature"
EXPECTED_FAILED_STEP = "I deliberately wait for a missing locator and report browser evidence"
FileUtils.mkdir_p(EVIDENCE_DIR)

def fetch_token
  return TOKEN_TEXT unless TOKEN_TEXT.empty?

  uri = URI.join("#{ENDPOINT}/", "uat/sso/oauth/token")
  request = Net::HTTP::Post.new(uri)
  request.basic_auth("ui", "uiman")
  request["Content-Type"] = "application/x-www-form-urlencoded"
  request.body = URI.encode_www_form(
    grant_type: "password",
    username: ENV.fetch("RP_USERNAME", "superadmin"),
    password: ENV.fetch("RP_PASSWORD", "erebus")
  )
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
  raise "ReportPortal login failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body).fetch("access_token")
end

def api_get(path, token)
  uri = URI.join("#{ENDPOINT}/", path)
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{token}"
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    response = http.request(request)
    raise "ReportPortal API returned HTTP #{response.code} for #{uri.path}" unless response.is_a?(Net::HTTPSuccess)

    response
  end
end

def api_json(path, token)
  response = api_get(path, token)
  [JSON.parse(response.body), response.body]
end

def find_launch(token)
  if (existing_id = ENV["RP_EXISTING_LAUNCH_ID"])
    response, = api_json("api/v1/#{PROJECT}/launch?page.page=1&page.size=100&page.sort=startTime,DESC", token)
    launch = response.fetch("content", []).find { |candidate| candidate["id"].to_s == existing_id.to_s }
    return launch if launch && launch["statistics"]

    raise "Existing ReportPortal launch #{existing_id} was not found or is unfinished"
  end

  40.times do
    query = URI.encode_www_form(
      "page.page" => 1,
      "page.size" => 20,
      "page.sort" => "startTime,DESC",
      "filter.cnt.name" => LAUNCH
    )
    response, = api_json("api/v1/#{PROJECT}/launch?#{query}", token)
    launch = response.fetch("content", []).find { |candidate| candidate["name"] == LAUNCH }
    return launch if launch && launch["statistics"]

    sleep 1
  end
  raise "Finished ReportPortal launch was not found by name"
end

def log_text(record)
  message = record["message"]
  message.is_a?(Hash) ? message["text"].to_s : message.to_s
end

def scrub(value)
  text = value.to_s.gsub(CANARY, "[REDACTED]")
  text.gsub(/(?i)(authorization|api[_-]?key|access[_-]?token|password)(\s*[:=]\s*)[^\s,;]+/, '\1\2[REDACTED]')
end

def version(command)
  output, status = Open3.capture2(
    { "BUNDLE_GEMFILE" => File.join(EXAMPLE_DIR, "Gemfile") },
    *command,
    chdir: EXAMPLE_DIR
  )
  raise "Could not determine version with #{command.join(' ')}" unless status.success? && !output.strip.empty?

  output.strip
end

def scenario_results(cucumber_json)
  cucumber_json.flat_map do |feature|
    feature.fetch("elements", []).select { |element| element["type"] == "scenario" }.map do |scenario|
      steps = scenario.fetch("steps", [])
      failed_steps = steps.select { |step| step.dig("result", "status") == "failed" }
      hooks = %w[before after].flat_map { |hook_key| scenario.fetch(hook_key, []) }
      failed_hooks = hooks.select { |hook| hook.dig("result", "status") == "failed" }
      statuses = steps.map { |step| step.dig("result", "status") }
      status = if failed_steps.any?
                 "failed"
               elsif failed_hooks.any?
                 "failed"
               elsif statuses.all? { |step_status| step_status == "passed" }
                 "passed"
               else
                 "incomplete"
               end
      {
        name: scenario.fetch("name"),
        status: status,
        hooks: hooks.map { |hook| { status: hook.dig("result", "status"), exception: hook.dig("result", "error_message") } },
        steps: steps.map do |step|
          {
            keyword: step["keyword"],
            name: step["name"],
            status: step.dig("result", "status"),
            exception: step.dig("result", "error_message")
          }
        end
      }
    end
  end
end

def item_ref(item)
  item["id"].to_s
end

def parent_item(item, item_by_id)
  parent = item["parent"]
  return nil if parent.nil?

  item_by_id[parent.to_s] || item_by_id.values.find { |candidate| candidate["uuid"] == parent.to_s }
end

def descendant_of?(item, ancestor, item_by_id)
  seen = {}
  current = item
  while current
    return true if current["id"].to_s == ancestor["id"].to_s
    break if seen[current["id"].to_s]

    seen[current["id"].to_s] = true
    current = parent_item(current, item_by_id)
  end
  false
end

def scenario_ancestor(item, item_by_id)
  seen = {}
  current = item
  while current
    return current if current["type"] == "STEP" && current["hasStats"] == true
    break if seen[current["id"].to_s]

    seen[current["id"].to_s] = true
    current = parent_item(current, item_by_id)
  end
  nil
end

def main
  token = fetch_token
  formatter_path = File.join(EVIDENCE_DIR, "reportportal-formatter.log")
  terminal_path = File.join(EVIDENCE_DIR, "terminal.log")
  json_path = File.join(EVIDENCE_DIR, "cucumber.json")
  report_path = File.join(EVIDENCE_DIR, "cucumber-report.html")
  puts "Starting verified Typewords M2 launch #{LAUNCH} in #{PROJECT}"

  env = {
    "BUNDLE_GEMFILE" => File.join(EXAMPLE_DIR, "Gemfile"),
    "CUCUMBER_PUBLISH_QUIET" => "true",
    "M2_EVIDENCE_DIR" => EVIDENCE_DIR,
    "TYPEWORDS_URL" => ENV.fetch("TYPEWORDS_URL", "http://localhost:5567/words"),
    "PLAYWRIGHT_CLI_EXECUTABLE_PATH" => "/tmp/m2-typewords-live/node/node_modules/.bin/playwright-core",
    "PLAYWRIGHT_BROWSERS_PATH" => "/tmp/m2-typewords-live/browsers",
    "RP_ENDPOINT" => ENDPOINT,
    "RP_PROJECT" => PROJECT,
    "RP_API_KEY" => token,
    "RP_LAUNCH" => LAUNCH,
    "RP_LAUNCH_DESCRIPTION" => "Live Typewords UI acceptance for M2 evidence and attribution",
    "RP_ATTRIBUTES" => "suite:typewords-m2,component:typewords,mode:live-playwright-cucumber",
    "RP_BATCH_SIZE_LOGS" => "1",
    "RP_FLUSH_INTERVAL" => "0.2",
    "RP_HTTP_READ_TIMEOUT" => "60",
    "RP_HTTP_WRITE_TIMEOUT" => "60",
    "RP_HTTP_RETRY_ATTEMPTS" => "3",
    "RP_CLIENT_JOIN" => "false",
    "RP_CONSOLE_MIRROR" => "false"
  }
  command = [
    "bundle", "exec", "cucumber", FEATURE,
    "--require", "features",
    "--format", "pretty",
    "--format", "json", "--out", json_path,
    "--format", "html", "--out", report_path,
    "--format", "ReportPortal::Cucumber::Formatter", "--out", formatter_path
  ]
  raw_terminal = +""
  process_status = nil
  observation_path = File.join(EVIDENCE_DIR, "run-observation.json")
  if ENV["RP_EXISTING_LAUNCH_ID"]
    raw_terminal = File.file?(terminal_path) ? File.read(terminal_path) : ""
    observation = JSON.parse(File.read(observation_path))
    raise "No observed child exit status matches requested launch name" unless observation["launch_name"] == LAUNCH && observation["child_exit_status"].is_a?(Integer)

    process_status = observation.fetch("child_exit_status")
  else
    Dir.chdir(EXAMPLE_DIR) do
      Open3.popen2e(env, *command) do |_stdin, stream, wait_thread|
        raw_terminal = stream.read
        process_status = wait_thread.value.exitstatus
      end
    end
    observation = {
      launch_name: LAUNCH,
      child_exit_status: process_status,
      child_exit_observed_at_utc: Time.now.utc.iso8601
    }
    File.write(observation_path, JSON.pretty_generate(observation))
    File.write(terminal_path, raw_terminal)
  end

  raw_json = File.read(json_path)
  raw_html = File.read(report_path)
  raw_formatter = File.file?(formatter_path) ? File.read(formatter_path) : ""
  cucumber_json = JSON.parse(raw_json)
  scenarios = scenario_results(cucumber_json)
  steps = scenarios.flat_map { |scenario| scenario.fetch(:steps) }
  failed_steps = steps.select { |step| step[:status] == "failed" }
  failed_hooks = scenarios.flat_map { |scenario| scenario.fetch(:hooks) }.select { |hook| hook[:status] == "failed" }
  step_count = steps.length
  scenario_counts = scenarios.map { |scenario| scenario[:status] }.tally
  intended_failure = failed_steps.length == 1 && failed_steps.first[:name] == EXPECTED_FAILED_STEP
  native_expectations_met = scenarios.length == 3 && step_count == 6 && failed_hooks.empty? &&
                            scenario_counts == { "passed" => 2, "failed" => 1 } &&
                            intended_failure && process_status == 1

  launch = find_launch(token)
  if ENV["RP_EXISTING_LAUNCH_ID"]
    observation = JSON.parse(File.read(observation_path))
    raise "Observed Cucumber run is bound to a different RP launch" unless observation["launch_id"].to_s == launch.fetch("id").to_s && observation["launch_uuid"] == launch.fetch("uuid")
  else
    observation = JSON.parse(File.read(observation_path))
    observation["launch_id"] = launch.fetch("id")
    observation["launch_uuid"] = launch.fetch("uuid")
    File.write(observation_path, JSON.pretty_generate(observation))
  end
  launch_url = "#{ENDPOINT}/ui/##{PROJECT}/launches/all/#{launch.fetch('id')}"
  puts "ReportPortal launch ready: #{launch.fetch('name')} id=#{launch.fetch('id')} uuid=#{launch.fetch('uuid')} URL=#{launch_url}"

  items_query = URI.encode_www_form(
    "filter.eq.launchId" => launch.fetch("id"),
    "page.page" => 1,
    "page.size" => 500,
    "page.sort" => "startTime,ASC"
  )
  item_response, raw_items_response = api_json("api/v1/#{PROJECT}/item?#{items_query}", token)
  items = item_response.fetch("content", [])
  item_by_id = items.to_h { |item| [item_ref(item), item] }
  action_items = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
  scenario_items = items.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
  suite_items = items.select { |item| item["type"] == "SUITE" && item["hasStats"] == true }
  failed_item = action_items.find { |item| item["name"].to_s.include?("deliberately wait for a missing locator") }
  manual_item = action_items.find { |item| item["name"].to_s == "M2 manual grouping" }
  raise "Failed Gherkin action item was not returned by ReportPortal" unless failed_item
  raise "Manual rp_step item was not returned by ReportPortal" unless manual_item

  raw_api_log_bodies = []
  logs_by_uuid = {}
  items.each do |item|
    query = URI.encode_www_form("filter.eq.item" => item.fetch("id"), "page.page" => 1, "page.size" => 200)
    response, raw_body = api_json("api/v1/#{PROJECT}/log?#{query}", token)
    raw_api_log_bodies << raw_body
    logs_by_uuid[item.fetch("uuid")] = response.fetch("content", [])
  end
  all_rp_text = ([raw_items_response] + raw_api_log_bodies).join("\n")
  canary_checks = {
    terminal_absent: !raw_terminal.include?(CANARY),
    cucumber_json_absent: !raw_json.include?(CANARY),
    cucumber_html_absent: !raw_html.include?(CANARY),
    formatter_absent: !raw_formatter.include?(CANARY),
    reportportal_api_absent: !all_rp_text.include?(CANARY)
  }
  canary_absent = canary_checks.values.all?

  failure_logs = logs_by_uuid.fetch(failed_item.fetch("uuid"))
  manual_logs = logs_by_uuid.fetch(manual_item.fetch("uuid"))
  manual_log_text = manual_logs.map { |record| log_text(record) }
  evidence_logs = failure_logs.select do |record|
    record.to_json.include?("Wait for intentionally absent Typewords control") ||
      record.to_json.include?("typewords-missing-locator.png")
  end
  evidence_error_logs = failure_logs.select do |record|
    record["level"].to_s.upcase == "ERROR" &&
      log_text(record).include?("Wait for intentionally absent Typewords control")
  end
  error_summary = evidence_error_logs.length == 1
  manual_assertion_present = manual_log_text.any? { |message| message.include?("Typewords navigation is available") }
  evidence_owner_uuids = items.filter_map do |item|
    item.fetch("uuid") if logs_by_uuid.fetch(item.fetch("uuid")).any? do |record|
      record.to_json.include?("Wait for intentionally absent Typewords control") ||
        record.to_json.include?("typewords-missing-locator.png")
    end
  end
  no_evidence_misrouting = evidence_owner_uuids == [failed_item.fetch("uuid")]

  scenario_names = [
    "Word-study navigation and learning view respond to interaction",
    "Manual grouping and structured passing assertion are reported",
    "Missing locator reports caller-owned evidence and preserves the Playwright error"
  ]
  failed_parent = parent_item(failed_item, item_by_id)
  manual_parent = parent_item(manual_item, item_by_id)
  failed_scenario = scenario_ancestor(failed_item, item_by_id)
  manual_action_scenario = scenario_ancestor(manual_parent, item_by_id) if manual_parent
  manual_scenario = scenario_ancestor(manual_item, item_by_id)
  failed_parent_topology_valid = failed_scenario && failed_parent && failed_parent["id"].to_s == failed_scenario["id"].to_s
  manual_parent_action_valid = manual_item["hasStats"] == false && manual_parent &&
                               manual_parent["type"] == "STEP" && manual_parent["hasStats"] == false &&
                               manual_parent["name"].to_s.include?("I report a manual diagnostic group")
  manual_parent_topology_valid = manual_parent_action_valid && manual_scenario &&
                                 manual_action_scenario &&
                                 manual_action_scenario["id"].to_s == manual_scenario["id"].to_s &&
                                 scenario_items.any? { |item| item["id"].to_s == manual_scenario["id"].to_s }
  failed_scenario_name_valid = failed_scenario && failed_scenario["name"].to_s.include?(scenario_names.last)
  manual_scenario_name_valid = manual_scenario && manual_scenario["name"].to_s.include?(scenario_names[1])
  suite_item = suite_items.find { |item| item["name"].to_s.include?("Typewords M2 live browser acceptance") }
  suite_present = !suite_item.nil?
  scenario_items_present = scenario_names.all? do |name|
    scenario_items.any? { |item| item["name"].to_s.include?(name) }
  end
  scenario_items_for_suite = scenario_items.select do |item|
    parent = parent_item(item, item_by_id)
    scenario_names.any? { |name| item["name"].to_s.include?(name) } &&
      parent && suite_item && parent["id"].to_s == suite_item["id"].to_s
  end
  suite_scenario_topology_valid = suite_item && suite_item["hasStats"] == true && scenario_items_for_suite.length == 3
  rp_stats = launch.fetch("statistics", {})
  execution_stats = rp_stats["executions"].is_a?(Hash) ? rp_stats["executions"] : rp_stats
  rp_stats_match = execution_stats["total"].to_i == 3 && execution_stats["passed"].to_i == 2 && execution_stats["failed"].to_i == 1

  screenshot_path = File.join(EVIDENCE_DIR, "missing-locator.png")
  local_png = File.binread(screenshot_path)
  attachment_log = failure_logs.find do |record|
    record.dig("binaryContent", "id") &&
      (record.to_json.include?("typewords-missing-locator.png") || record.to_json.include?("missing-locator.png"))
  end
  attachment = nil
  if attachment_log
    attachment_id = attachment_log.dig("binaryContent", "id")
    raise "Evidence log did not include a ReportPortal attachment id" unless attachment_id

    response = api_get("api/v1/data/#{PROJECT}/#{attachment_id}", token)
    remote_png = response.body
    attachment = {
      log_id: attachment_log.fetch("id"),
      attachment_id: attachment_id,
      local_bytes: local_png.bytesize,
      remote_bytes: remote_png.bytesize,
      local_sha256: Digest::SHA256.hexdigest(local_png),
      remote_sha256: Digest::SHA256.hexdigest(remote_png),
      exact_byte_match: remote_png == local_png,
      png_signature_valid: remote_png.start_with?("\x89PNG\r\n\x1a\n".b)
    }
  end

  late = JSON.parse(File.read(File.join(EVIDENCE_DIR, "late-evidence.json")))
  failure_local = JSON.parse(File.read(File.join(EVIDENCE_DIR, "failure-evidence.json")))
  failed_json_exception = failed_steps.first && failed_steps.first[:exception].to_s
  original_exception_preserved = failure_local["original_error_class"] == "Playwright::TimeoutError" &&
                                 failed_json_exception.to_s.include?("Playwright::TimeoutError") &&
                                 failed_json_exception.to_s.include?(failure_local["original_error_message"].to_s.lines.first.to_s.strip)
  feature_url = "#{ENDPOINT}/ui/##{PROJECT}/launches/all/#{launch.fetch('id')}"
  manifest = {
    generated_at_utc: Time.now.utc.iso8601,
    versions: {
      ruby: version(["ruby", "--version"]),
      cucumber: version(["bundle", "exec", "cucumber", "--version"]),
      playwright_ruby_client: version(["bundle", "exec", "ruby", "-e", 'require "playwright"; puts Gem.loaded_specs.fetch("playwright-ruby-client").version']),
      playwright_node: version(["node", "-p", 'require("/tmp/m2-typewords-live/node/node_modules/playwright-core/package.json").version'])
    },
    command: command,
    launch: {
      name: launch.fetch("name"), id: launch.fetch("id"), uuid: launch.fetch("uuid"),
      url: feature_url, statistics: launch["statistics"]
    },
    native_cucumber: {
      process_exit_status: process_status,
      process_exit_status_source: "captured child process exit status in run-observation.json",
      total_scenarios: scenarios.length,
      total_steps: step_count,
      scenario_status_counts: scenario_counts,
      expected_profile_matched: native_expectations_met,
      scenarios: scenarios
    },
    reportportal_topology: {
      suite_found: suite_present,
      scenario_nodes_found: scenario_items_present,
      scenario_node_count: scenario_items.length,
      action_node_count: action_items.length,
      scenarios_directly_parented_by_stats_suite: scenario_items_for_suite.length,
      suite_scenario_topology_valid: !!suite_scenario_topology_valid,
      reportportal_execution_statistics: execution_stats,
      reportportal_execution_statistics_match: rp_stats_match,
      failed_action: {
        id: failed_item["id"], uuid: failed_item["uuid"], name: failed_item["name"],
      status: failed_item["status"], parent_id: failed_item["parent"],
      hasStats: failed_item["hasStats"], parent_is_stats_scenario: !!failed_parent_topology_valid,
      parent_scenario_name: failed_scenario && failed_scenario["name"]
      },
      manual_group: {
      id: manual_item["id"], uuid: manual_item["uuid"], name: manual_item["name"],
        status: manual_item["status"], parent_id: manual_item["parent"],
        hasStats: manual_item["hasStats"],
        direct_parent_action_name: manual_parent && manual_parent["name"],
        direct_parent_is_non_stats_action: !!manual_parent_action_valid,
        stats_scenario_ancestor_id: manual_scenario && manual_scenario["id"],
        stats_scenario_ancestor_name: manual_scenario && manual_scenario["name"],
        parent_action_has_stats_scenario_ancestor: !!manual_parent_topology_valid,
        assertion_log_ids: manual_logs.select { |record| log_text(record).include?("Typewords navigation is available") }.map { |record| record["id"] }
      }
    },
    failure_evidence: {
      original_exception_class: failure_local["original_error_class"],
      original_exception_object_id: failure_local["original_exception_object_id"],
      exception_matches_native_cucumber_failure: original_exception_preserved,
      target_captured_while_open: failure_local["target_captured_while_open"],
      rp_evidence_queued_while_open: failure_local["evidence_queued"],
      late_after_hook_evidence_accepted: late.fetch("accepted"),
      error_summary_on_failed_action: error_summary,
      error_summary_log_ids: evidence_error_logs.map { |record| record["id"] },
      evidence_log_ids_on_failed_action: evidence_logs.map { |record| record["id"] },
      evidence_owner_uuids: evidence_owner_uuids,
      no_evidence_misrouting: no_evidence_misrouting
    },
    privacy_checks: canary_checks,
    attachment: attachment,
    local_results: {
      screenshot: "missing-locator.png",
      terminal_log: File.basename(terminal_path),
      formatter_log: File.basename(formatter_path),
      cucumber_json: File.basename(json_path),
      html_report: File.basename(report_path)
    }
  }

  [terminal_path, formatter_path, json_path, report_path].each do |path|
    File.write(path, scrub(File.read(path))) unless canary_absent
  end
  File.write(terminal_path, scrub(raw_terminal))
  File.write(File.join(EVIDENCE_DIR, "result-manifest.json"), JSON.pretty_generate(manifest))
  $stdout.print(scrub(raw_terminal))
  puts "Launch UI: #{feature_url}"
  puts "Failed action UUID: #{failed_item.fetch('uuid')}"
  puts "Failed action log IDs: #{evidence_logs.map { |record| record['id'] }.join(',')}"

  validations = {
    exact_native_cucumber_result: native_expectations_met,
    suite_and_scenario_topology: suite_present && scenario_items_present && scenario_items.length == 3,
    reportportal_execution_statistics_match: rp_stats_match,
    action_parent_topology: failed_parent_topology_valid && manual_parent_topology_valid,
    failed_action_parent_is_expected_scenario: !!failed_scenario_name_valid,
    manual_group_parent_scenario_is_expected: !!manual_scenario_name_valid,
    manual_group_parent_is_gherkin_action: manual_parent_action_valid,
    three_scenarios_directly_parented_by_stats_suite: !!suite_scenario_topology_valid,
    manual_assertion_logged_on_manual_group: manual_assertion_present,
    one_error_summary_on_failed_action: error_summary,
    evidence_logs_owned_only_by_failed_action: no_evidence_misrouting,
    target_captured_open_and_evidence_queued: failure_local["target_captured_while_open"] && failure_local["evidence_queued"],
    original_playwright_exception_preserved: original_exception_preserved,
    late_closed_target_rejected: late.fetch("accepted") == false,
    canary_redacted_everywhere: canary_absent,
    png_exact_bytes_attached_to_failed_action: attachment && attachment[:exact_byte_match] && attachment[:png_signature_valid]
  }
  manifest[:acceptance_validations] = validations
  File.write(File.join(EVIDENCE_DIR, "result-manifest.json"), JSON.pretty_generate(manifest))
  failures = validations.select { |_name, passed| !passed }
  raise "Live acceptance validation failed: #{failures.keys.join(', ')}" unless failures.empty?
end

main
