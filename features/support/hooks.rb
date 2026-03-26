# frozen_string_literal: true

Before("@reportportal_live") do
  required = %w[RP_ENDPOINT RP_PROJECT RP_API_KEY]
  missing = required.select { |key| ENV[key].to_s.strip.empty? }
  raise "Missing ReportPortal env vars: #{missing.join(', ')}" unless missing.empty?
end

After("@stubbed") do
  %w[
    RP_ENDPOINT
    RP_PROJECT
    RP_API_KEY
    RP_LAUNCH
    RP_CLIENT_JOIN
    RP_BATCH_SIZE_LOGS
    RP_FLUSH_INTERVAL
    RP_HTTP_RETRY_ATTEMPTS
    RP_RERUN
    RP_RERUN_OF
  ].each { |key| ENV.delete(key) }
end

After do
  next if ENV["KEEP_VERIFICATION_ARTIFACTS"].to_s == "true"

  FileUtils.rm_rf(File.expand_path("../tmp/verification", __dir__))
end
