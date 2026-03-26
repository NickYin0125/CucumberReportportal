# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../../spec", __dir__))

require "rspec/expectations"
require "reportportal_cucumber"
require "webmock/cucumber"

World(RSpec::Matchers)
World(ReportportalCucumber::Cucumber::World)

WebMock.disable_net_connect!(allow_localhost: true)

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
