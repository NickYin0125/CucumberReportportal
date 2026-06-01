# frozen_string_literal: true

require "json"
require "fileutils"
require "net/http"
require "rspec/core/rake_task"
require "time"
require "uri"

RSpec::Core::RakeTask.new(:spec)

namespace :rp do
  desc "Run live Cucumber regression against ReportPortal with real-time logs"
  task :regression do
    endpoint = ENV.fetch("RP_ENDPOINT", "http://localhost")
    project = ENV.fetch("RP_PROJECT", "superadmin_personal")
    launch = ENV.fetch("RP_LAUNCH", "rp-live-regression-#{Time.now.utc.strftime('%Y%m%d%H%M%S')}")
    api_key = ENV["RP_API_KEY"].to_s.strip
    api_key = fetch_reportportal_token(endpoint) if api_key.empty?

    env = {
      "CUCUMBER_PUBLISH_QUIET" => "true",
      "KEEP_VERIFICATION_ARTIFACTS" => ENV.fetch("KEEP_VERIFICATION_ARTIFACTS", "true"),
      "RP_ENDPOINT" => endpoint,
      "RP_PROJECT" => project,
      "RP_API_KEY" => api_key,
      "RP_LAUNCH" => launch,
      "RP_LAUNCH_DESCRIPTION" => ENV.fetch(
        "RP_LAUNCH_DESCRIPTION",
        "One-click live regression for ReportPortal logger UX verification"
      ),
      "RP_ATTRIBUTES" => ENV.fetch(
        "RP_ATTRIBUTES",
        "suite:live-regression,component:cucumber-ruby,mode:interactive"
      ),
      "RP_CLIENT_JOIN" => ENV.fetch("RP_CLIENT_JOIN", "false"),
      "RP_BATCH_SIZE_LOGS" => ENV.fetch("RP_BATCH_SIZE_LOGS", "1"),
      "RP_FLUSH_INTERVAL" => ENV.fetch("RP_FLUSH_INTERVAL", "0.2"),
      "RP_HTTP_READ_TIMEOUT" => ENV.fetch("RP_HTTP_READ_TIMEOUT", "60"),
      "RP_HTTP_WRITE_TIMEOUT" => ENV.fetch("RP_HTTP_WRITE_TIMEOUT", "60"),
      "RP_HTTP_RETRY_ATTEMPTS" => ENV.fetch("RP_HTTP_RETRY_ATTEMPTS", "3"),
      "RP_CONSOLE_MIRROR" => ENV.fetch("RP_CONSOLE_MIRROR", "false"),
      "RP_VIDEO_UPLOAD_MODE" => ENV.fetch("RP_VIDEO_UPLOAD_MODE", "minio_markdown"),
      "RP_MINIO_ENDPOINT" => ENV.fetch("RP_MINIO_ENDPOINT", endpoint),
      "RP_MINIO_PUBLIC_BASE_URL" => ENV.fetch("RP_MINIO_PUBLIC_BASE_URL", endpoint),
      "RP_MINIO_BUCKET" => ENV.fetch("RP_MINIO_BUCKET", "automation-videos"),
      "RP_MINIO_ACCESS_KEY_ID" => ENV.fetch("RP_MINIO_ACCESS_KEY_ID", "rpuser"),
      "RP_MINIO_SECRET_ACCESS_KEY" => ENV.fetch("RP_MINIO_SECRET_ACCESS_KEY", "miniopassword"),
      "RP_MINIO_REGION" => ENV.fetch("RP_MINIO_REGION", "us-east-1")
    }

    puts "ReportPortal live regression launch: #{launch}"
    puts "ReportPortal endpoint: #{endpoint}"
    puts "ReportPortal project: #{project}"
    puts "Log batching: RP_BATCH_SIZE_LOGS=#{env['RP_BATCH_SIZE_LOGS']} RP_FLUSH_INTERVAL=#{env['RP_FLUSH_INTERVAL']}"
    puts "Console mirror: RP_CONSOLE_MIRROR=#{env['RP_CONSOLE_MIRROR']}"

    FileUtils.mkdir_p("tmp")
    formatter_out = File.join("tmp", "reportportal-regression-#{launch}.log")

    success = system(
      env,
      "bundle",
      "exec",
      "cucumber",
      "-P",
      "features/deep_water",
      "--format",
      "ReportPortal::Cucumber::Formatter",
      "--out",
      formatter_out,
      "--format",
      "pretty"
    )

    launch_payload = wait_for_launch(endpoint: endpoint, project: project, token: api_key, launch_name: launch)
    stats = launch_payload.fetch("statistics").fetch("executions")
    expected = { "total" => 7, "passed" => 6, "failed" => 1 }

    unless expected.all? { |key, value| stats[key] == value }
      abort "Unexpected ReportPortal stats for #{launch}: #{stats.inspect}, expected #{expected.inspect}"
    end

    puts "ReportPortal launch verified: id=#{launch_payload['id']} uuid=#{launch_payload['uuid']}"
    puts "Expected intentional Cucumber failure observed and verified in ReportPortal." unless success
    puts "Open: #{endpoint}/ui/##{project}/launches/all/#{launch_payload['id']}"
  end
end

task default: :spec

def fetch_reportportal_token(endpoint)
  username = ENV.fetch("RP_USERNAME", "superadmin")
  password = ENV.fetch("RP_PASSWORD", "erebus")
  uri = URI.join("#{endpoint}/", "uat/sso/oauth/token")
  request = Net::HTTP::Post.new(uri)
  request.basic_auth("ui", "uiman")
  request["Content-Type"] = "application/x-www-form-urlencoded"
  request.body = URI.encode_www_form(
    "grant_type" => "password",
    "username" => username,
    "password" => password
  )

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
  abort "Unable to fetch ReportPortal token: HTTP #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body).fetch("access_token")
end

def wait_for_launch(endpoint:, project:, token:, launch_name:, attempts: 30)
  attempts.times do
    launch = find_launch(endpoint: endpoint, project: project, token: token, launch_name: launch_name)
    return launch if launch && launch["statistics"]

    sleep 1
  end

  abort "ReportPortal launch was not found or not finished: #{launch_name}"
end

def find_launch(endpoint:, project:, token:, launch_name:)
  uri = URI.join("#{endpoint}/", "api/v1/#{project}/launch")
  uri.query = URI.encode_www_form(
    "page.page" => "1",
    "page.size" => "5",
    "page.sort" => "startTime,DESC",
    "filter.cnt.name" => launch_name
  )
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{token}"

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
  abort "Unable to query ReportPortal launch: HTTP #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body).fetch("content").find { |launch| launch["name"] == launch_name }
end
