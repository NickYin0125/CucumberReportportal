# frozen_string_literal: true

require "tmpdir"
require "webmock/rspec"

require "reportportal_cucumber"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }

  config.before do
    WebMock.disable_net_connect!(allow_localhost: true)
    ReportportalCucumber.current_runtime = nil
  end

  config.after do
    WebMock.reset!
  end
end
