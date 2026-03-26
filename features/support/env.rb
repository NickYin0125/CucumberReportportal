# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../../spec", __dir__))

require "rspec/expectations"
require "reportportal_cucumber"
require "webmock/cucumber"

World(RSpec::Matchers)

After do
  %w[
    RP_ENDPOINT
    RP_PROJECT
    RP_API_KEY
    RP_LAUNCH
    RP_CLIENT_JOIN
    RP_BATCH_SIZE_LOGS
    RP_FLUSH_INTERVAL
    RP_HTTP_RETRY_ATTEMPTS
  ].each { |key| ENV.delete(key) }
end
