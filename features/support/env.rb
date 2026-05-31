# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../../spec", __dir__))

require "rspec/expectations"
require "reportportal_cucumber"
require "webmock/cucumber"

World(RSpec::Matchers)
World(ReportportalCucumber::Cucumber::World)

WebMock.disable_net_connect!(allow_localhost: true)
