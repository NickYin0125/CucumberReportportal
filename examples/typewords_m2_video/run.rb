# frozen_string_literal: true

require "base64"
require "cgi"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "securerandom"
require "time"
require "uri"
require "aws-sdk-s3"

module TypewordsVideoRun
  EXAMPLE = __dir__
  ROOT = File.expand_path("../..", EXAMPLE)
  RESULTS = ENV.fetch("M2_VIDEO_RESULTS_DIR", File.join(ROOT, "tmp", "m2-typewords-video"))
  ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://localhost").delete_suffix("/")
  PROJECT = ENV.fetch("RP_PROJECT", "superadmin_personal")
  CANARY = "M2_VIDEO_PRIVATE_TEXT_5197"
  FEATURE = "features/live_video.feature"
  MISSING_STEP = "I click an intentionally absent Typewords control"

  module_function

  def clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def write_json(name, value)
    File.write(File.join(RESULTS, name), JSON.pretty_generate(value))
  end

  def command_output(*command)
    output, status = Open3.capture2e({ "BUNDLE_GEMFILE" => File.join(EXAMPLE, "Gemfile") }, *command, chdir: EXAMPLE)
    raise "Command failed: #{command.first}" unless status.success? && !output.strip.empty?

    output.strip
  end

  def response_for(url, token: nil, range: nil)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}" if token
    request["Range"] = range if range
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 60) { |http| http.request(request) }
  end

  def api(path, token)
    response = response_for("#{ENDPOINT}/api/v1/#{PROJECT}/#{path}", token: token)
    raise "RP read API failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def token
    provided = ENV["RP_API_KEY"].to_s.strip
    return provided unless provided.empty?

    uri = URI("#{ENDPOINT}/uat/sso/oauth/token")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth("ui", "uiman")
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request.body = URI.encode_www_form(grant_type: "password", username: ENV.fetch("RP_USERNAME", "superadmin"), password: ENV.fetch("RP_PASSWORD", "erebus"))
    response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
    raise "RP token request failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("access_token")
  end

  def minio_credentials
    if ENV["RP_MINIO_ACCESS_KEY_ID"] && ENV["RP_MINIO_SECRET_ACCESS_KEY"]
      return [ENV.fetch("RP_MINIO_ACCESS_KEY_ID"), ENV.fetch("RP_MINIO_SECRET_ACCESS_KEY")]
    end

    raw, status = Open3.capture2("kubectl", "--context", "docker-desktop", "-n", "reportportal", "get", "secret", "reportportal-video-bucket", "-o", "json")
    raise "Could not read existing Kubernetes video-bucket credentials" unless status.success?

    data = JSON.parse(raw).fetch("data")
    [Base64.strict_decode64(data.fetch("access-key")), Base64.strict_decode64(data.fetch("secret-key"))]
  end

  def preflight(credentials, cli)
    raise "Expected existing Docker Desktop Kubernetes context" unless command_output("kubectl", "config", "current-context") == "docker-desktop"
    endpoint = ENV.fetch("RP_MINIO_ENDPOINT", ENDPOINT)
    client = Aws::S3::Client.new(endpoint: endpoint, region: "us-east-1", force_path_style: true,
                                access_key_id: credentials[0], secret_access_key: credentials[1])
    status = client.head_bucket(bucket: "automation-videos").context.http_response.status_code
    raise "Existing MinIO bucket is unreachable" unless status == 200

    package = File.expand_path("../playwright-core/package.json", File.dirname(cli))
    versions = {
      ruby: command_output("ruby", "--version"),
      cucumber: command_output("bundle", "exec", "cucumber", "--version"),
      playwright_ruby: command_output("bundle", "exec", "ruby", "-e", 'require "playwright"; puts Gem.loaded_specs.fetch("playwright-ruby-client").version'),
      playwright_node: command_output("node", "-p", "require(#{package.to_json}).version"),
      ffmpeg: command_output("ffmpeg", "-version").lines.first.strip,
      ffprobe: command_output("ffprobe", "-version").lines.first.strip
    }
    raise "Unexpected Playwright Ruby/Node pair" unless versions[:playwright_ruby] == "1.62.0" && versions[:playwright_node] == "1.62.1"

    versions
  end

  def finished_launch(name, token)
    30.times do
      query = URI.encode_www_form("filter.cnt.name" => name, "page.page" => 1, "page.size" => 50, "page.sort" => "startTime,DESC")
      launch = api("launch?#{query}", token).fetch("content", []).find { |entry| entry["name"] == name }
      return launch if launch && launch["statistics"] && launch["status"] != "IN_PROGRESS"

      sleep 0.5
    end
    raise "Completed RP launch was not found"
  end

  def item_link(launch_id, item_ids)
    (["#{ENDPOINT}/ui/##{PROJECT}/launches/all/#{launch_id}"] + item_ids.map(&:to_s)).join("/")
  end

  def mp4_faststart?(path)
    positions = {}
    File.open(path, "rb") do |file|
      until file.eof?
        offset = file.pos
        header = file.read(8)
        break if !header || header.bytesize < 8

        size, type = header.unpack("Na4")
        header_size = 8
        if size == 1
          size = file.read(8).unpack1("Q>")
          header_size = 16
        end
        break if size < header_size

        positions[type] = offset
        file.seek(size - header_size, IO::SEEK_CUR)
      end
    end
    positions["moov"] && positions["mdat"] && positions["moov"] < positions["mdat"]
  end

  def main
    FileUtils.mkdir_p(RESULTS)
    rp_token = token
    observation_path = File.join(RESULTS, "run-observation.json")
    native_json_path = File.join(RESULTS, "cucumber.json")
    html_path = File.join(RESULTS, "cucumber-report.html")
    terminal_path = File.join(RESULTS, "terminal.log")
    formatter_path = File.join(RESULTS, "reportportal-formatter.log")
    known_sensitive = [rp_token, ENV.fetch("RP_PASSWORD", "erebus"), CANARY].compact.reject(&:empty?)

    if ENV["RP_EXISTING_LAUNCH_ID"]
      observation = JSON.parse(File.read(observation_path))
      raise "Saved observation does not match requested launch" unless observation["launch_id"].to_s == ENV.fetch("RP_EXISTING_LAUNCH_ID") && observation["child_exit_status"].is_a?(Integer)
      name = observation.fetch("launch_name")
      versions = observation.fetch("versions")
      raw_terminal = File.read(terminal_path)
    else
      credentials = minio_credentials
      known_sensitive.concat(credentials)
      cli = ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH", "/tmp/m2-typewords-live/node/node_modules/.bin/playwright-core")
      versions = preflight(credentials, cli)
      name = ENV.fetch("RP_LAUNCH", "typewords-m2-video-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}-#{SecureRandom.hex(3)}")
      env = {
        "BUNDLE_GEMFILE" => File.join(EXAMPLE, "Gemfile"), "CUCUMBER_PUBLISH_QUIET" => "true",
        "M2_VIDEO_RESULTS_DIR" => RESULTS, "TYPEWORDS_URL" => ENV.fetch("TYPEWORDS_URL", "http://localhost:5567/words"),
        "PLAYWRIGHT_CLI_EXECUTABLE_PATH" => cli,
        "PLAYWRIGHT_BROWSERS_PATH" => ENV.fetch("PLAYWRIGHT_BROWSERS_PATH", "/tmp/m2-typewords-live/browsers"),
        "RP_ENDPOINT" => ENDPOINT, "RP_PROJECT" => PROJECT, "RP_API_KEY" => rp_token, "RP_LAUNCH" => name,
        "RP_LAUNCH_DESCRIPTION" => "Real Playwright viewport recording finalized by the framework and published in After-hook manual node",
        "RP_CLIENT_JOIN" => "false", "RP_CONSOLE_MIRROR" => "false", "RP_BATCH_SIZE_LOGS" => "1", "RP_FLUSH_INTERVAL" => "0.1",
        "RP_VIDEO_UPLOAD_MODE" => "minio_markdown", "RP_MINIO_ENDPOINT" => ENV.fetch("RP_MINIO_ENDPOINT", ENDPOINT),
        "RP_MINIO_PUBLIC_BASE_URL" => ENDPOINT, "RP_MINIO_BUCKET" => "automation-videos",
        "RP_MINIO_ACCESS_KEY_ID" => credentials[0], "RP_MINIO_SECRET_ACCESS_KEY" => credentials[1], "RP_MINIO_REGION" => "us-east-1",
        "RP_SPOOL_DIR" => File.join(RESULTS, "spool"), "RP_EXIT_FLUSH_TIMEOUT_MS" => "30000"
      }
      command = ["bundle", "exec", "cucumber", FEATURE, "--require", "features", "--format", "pretty",
                 "--format", "json", "--out", native_json_path, "--format", "html", "--out", html_path,
                 "--format", "ReportPortal::Cucumber::Formatter", "--out", formatter_path]
      puts "Starting real recording launch #{name}"
      started = clock
      status = nil
      raw_terminal = +""
      Open3.popen2e(env, *command, chdir: EXAMPLE) do |input, output, waiter|
        input.close
        raw_terminal = output.read
        status = waiter.value.exitstatus
      end
      observation = { launch_name: name, child_exit_status: status, child_elapsed_ms: ((clock - started) * 1_000).round(3),
                      observed_at_utc: Time.now.utc.iso8601, command: command, versions: versions,
                      playwright_cli: cli, playwright_browsers: env.fetch("PLAYWRIGHT_BROWSERS_PATH") }
      write_json("run-observation.json", observation)
      secret_leaked = known_sensitive.any? { |value| raw_terminal.include?(value) }
      safe_terminal = known_sensitive.reduce(raw_terminal) { |text, value| text.gsub(value, "[REDACTED]") }
      File.write(terminal_path, safe_terminal)
      raise "Sensitive text detected in raw terminal output" if secret_leaked
      observation = JSON.parse(File.read(observation_path))
    end

    raise "Cucumber failed before generating native result files" unless File.file?(native_json_path) && File.file?(html_path)
    native = JSON.parse(File.read(native_json_path))
    scenarios = native.flat_map { |feature| feature.fetch("elements", []).select { |entry| entry["type"] == "scenario" } }
    steps = scenarios.flat_map { |scenario| scenario.fetch("steps", []) }
    hooks = scenarios.flat_map { |scenario| %w[before after].flat_map { |key| scenario.fetch(key, []) } }
    failed_steps = steps.select { |step| step.dig("result", "status") == "failed" }
    profile = scenarios.length == 1 && steps.length == 2 && steps.first.dig("result", "status") == "passed" &&
              failed_steps.length == 1 && failed_steps.first["name"] == MISSING_STEP &&
              hooks.length == 1 && hooks.all? { |hook| hook.dig("result", "status") == "passed" } && observation.fetch("child_exit_status") == 1

    launch = finished_launch(name, rp_token)
    if ENV["RP_EXISTING_LAUNCH_ID"]
      raise "Saved observation UUID differs from live launch" unless observation["launch_uuid"] == launch.fetch("uuid")
    else
      observation.merge!("launch_id" => launch.fetch("id"), "launch_uuid" => launch.fetch("uuid"))
      write_json("run-observation.json", observation)
    end
    launch_url = item_link(launch.fetch("id"), [])
    puts "Launch ready: #{launch_url} UUID=#{launch.fetch('uuid')}"
    query = URI.encode_www_form("filter.eq.launchId" => launch.fetch("id"), "page.page" => 1, "page.size" => 500)
    items = api("item?#{query}", rp_token).fetch("content")
    logs = items.to_h do |item|
      query = URI.encode_www_form("filter.eq.item" => item.fetch("id"), "page.page" => 1, "page.size" => 200)
      [item.fetch("id"), api("log?#{query}", rp_token).fetch("content", [])]
    end
    suite = items.find { |item| item["type"] == "SUITE" && item["hasStats"] == true }
    scenario = items.find { |item| item["type"] == "STEP" && item["hasStats"] == true }
    failed = items.find { |item| item["name"].to_s.include?(MISSING_STEP) }
    manual = items.find { |item| item["name"] == "Finalize and publish testcase recording" }
    hook = manual && items.find { |item| item["id"] == manual["parent"] }
    raise "Expected RP recording nodes missing" unless suite && scenario && failed && manual && hook

    video_records = logs.flat_map { |owner, records| records.filter_map { |record| [owner, record] if record["message"].to_s.include?("<video ") } }
    raise "Expected exactly one finalized-recording Markdown log" unless video_records.length == 1
    video_owner, video_log = video_records.first
    source_url = CGI.unescapeHTML(video_log.fetch("message").match(/<source src="([^"]+)"/).captures.first)
    uri = URI(source_url)
    same_origin = [uri.scheme, uri.host, uri.port] == [URI(ENDPOINT).scheme, URI(ENDPOINT).host, URI(ENDPOINT).port]
    raise "Video public URL is not the same-origin bucket route" unless same_origin && uri.path.start_with?("/automation-videos/videos/") && uri.path.scan("automation-videos").length == 1

    downloaded = response_for(source_url)
    downloaded_path = File.join(RESULTS, "downloaded-recording.mp4")
    File.binwrite(downloaded_path, downloaded.body)
    range = response_for(source_url, range: "bytes=0-1023")
    downloaded_probe_raw = command_output("ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", downloaded_path)
    File.write(File.join(RESULTS, "downloaded-ffprobe.json"), downloaded_probe_raw)
    lifecycle = JSON.parse(File.read(File.join(RESULTS, "video-lifecycle.json")))
    native_exception = failed_steps.first&.dig("result", "error_message").to_s
    all_logs = logs.values.flatten
    privacy_text = [raw_terminal, File.read(native_json_path), File.read(html_path), items.to_json, all_logs.to_json,
                    File.file?(formatter_path) ? File.read(formatter_path) : ""].join("\n")
    privacy_pass = known_sensitive.none? { |value| privacy_text.include?(value) }
    original = JSON.parse(File.read(File.join(RESULTS, "original-failure.json")))
    failed_evidence = JSON.parse(File.read(File.join(RESULTS, "failed-step-evidence.json")))
    stats = launch.fetch("statistics").fetch("executions")
    original_preserved = lifecycle["same_original_exception_in_after"] && original["object_id"] == lifecycle["after_hook_exception_object_id"] &&
                         native_exception.include?("Playwright::TimeoutError") && native_exception.include?(original.fetch("error_message").lines.first.strip)
    validations = {
      exact_native_profile_and_observed_exit: profile,
      original_playwright_exception_preserved: original_preserved,
      scenario_parent_is_stats_suite: scenario["parent"] == suite["id"] && suite["hasStats"] == true,
      failed_action_parent_is_scenario: failed["parent"] == scenario["id"] && failed["hasStats"] == false && failed["status"] == "FAILED",
      after_hook_type_and_parent: hook["type"] == "AFTER_METHOD" && hook["parent"] == scenario["id"] && hook["hasStats"] == false && hook["status"] == "PASSED",
      manual_parent_is_after_hook: manual["type"] == "STEP" && manual["hasStats"] == false && manual["parent"] == hook["id"] && manual["status"] == "PASSED",
      exact_one_failed_scenario_statistics: stats["total"] == 1 && stats["failed"] == 1 && stats["passed"].to_i == 0,
      recording_enabled_before_real_navigation: lifecycle.fetch("events").first.fetch("name") == "recording_context_created_before_navigation",
      finalized_before_manual_publication: lifecycle["context_closed_before_publication"] && lifecycle["video_attach_called_after_finalization"],
      real_navigation_paths_observed: lifecycle.fetch("ui_observations").map { |state| state["path"] } == ["/words", "/dict-list", "/words"],
      original_webm_preserved: File.file?(lifecycle.dig("source", "path")) && lifecycle.dig("source", "sha256") == Digest::SHA256.file(lifecycle.fetch("official_saved_copy")).hexdigest,
      old_failed_target_rejected_new_manual_valid: lifecycle["closed_failed_target_accepted"] == false && lifecycle["open_manual_target_accepted"] == true && failed_evidence["accepted"] == true,
      one_video_log_owned_by_manual_node: video_owner == manual["id"] && video_records.length == 1,
      no_native_video_binary_attachment: all_logs.none? { |record| record.dig("binaryContent", "contentType").to_s.start_with?("video/") } && !video_log["binaryContent"],
      rejected_old_target_not_misrouted: all_logs.none? { |record| record["message"].to_s.include?("Rejected closed failed-step video publication probe") },
      anonymous_get_video_mp4: downloaded.code == "200" && downloaded["content-type"].to_s.split(";").first == "video/mp4",
      anonymous_range_exact_bytes: range.code == "206" && range["content-range"] == "bytes 0-1023/#{downloaded.body.bytesize}" && range.body == downloaded.body.byteslice(0, 1024),
      downloaded_mp4_exact_sha256: Digest::SHA256.file(downloaded_path).hexdigest == lifecycle.dig("mp4", "sha256"),
      h264_yuv420p_faststart: lifecycle.dig("mp4", "codec") == "h264" && lifecycle.dig("mp4", "pixel_format") == "yuv420p" && mp4_faststart?(lifecycle.dig("mp4", "path")),
      several_seconds_recorded: lifecycle.dig("source", "duration_seconds") >= 7.0 && lifecycle.dig("mp4", "duration_seconds") >= 7.0,
      generated_reports_contain_no_sensitive_values: privacy_pass
    }
    manifest = {
      observed_at_utc: Time.now.utc.iso8601, versions: versions, observation: observation,
      launch: { name: name, id: launch["id"], uuid: launch["uuid"], url: launch_url, statistics: stats },
      nodes: { suite: suite, scenario: scenario, failed_action: failed, after_hook: hook, publishing_manual: manual },
      video_log: { id: video_log["id"], owner_id: video_owner, owner_uuid: manual["uuid"], api_url: "#{ENDPOINT}/api/v1/#{PROJECT}/log/#{video_log['id']}",
                   item_ui_url: item_link(launch["id"], [suite["id"], scenario["id"]]), url: source_url, binary_content: video_log["binaryContent"] },
      lifecycle: lifecycle, native_steps: steps, native_hooks: hooks,
      timing: lifecycle.fetch("timings").merge("child_process_total_ms" => observation.fetch("child_elapsed_ms"),
                                               "native_after_hook_ms" => hooks.first.dig("result", "duration").to_f / 1_000_000),
      timing_scope: "Total After-hook timing includes acceptance-only ffprobe, hashing, and target probes. It is not incremental overhead against a no-video baseline and does not certify 100-case throughput.",
      http: { get_status: downloaded.code, content_type: downloaded["content-type"], downloaded_bytes: File.size(downloaded_path),
              sha256: Digest::SHA256.file(downloaded_path).hexdigest, range_status: range.code, content_range: range["content-range"] },
      master_playback_verdict: "pending", acceptance_validations: validations
    }
    write_json("result-manifest.json", manifest)
    puts "Recording uploaded: item=#{manual['id']} video_log=#{video_log['id']} duration=#{lifecycle.dig('mp4', 'duration_seconds')}s URL=#{source_url}"
    puts "Observed timing ms: #{manifest.fetch(:timing).to_json}"
    failures = validations.reject { |_name, passed| passed }
    raise "Video acceptance checks failed: #{failures.keys.join(', ')}" unless failures.empty?

    puts "Machine/API recording checks passed; master RP playback review pending."
  end
end

TypewordsVideoRun.main
