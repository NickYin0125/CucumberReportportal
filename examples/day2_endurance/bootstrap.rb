# frozen_string_literal: true

require "reportportal_cucumber"
require "rspec/expectations"
require_relative "support"

World(RSpec::Matchers)
World(ReportportalCucumber::Cucumber::World)

module Day2Endurance
  class Formatter < ReportportalCucumber::Cucumber::Formatter
    def initialize(*arguments)
      super
      Day2Endurance.formatter = self
    end
  end
end

Around("@duration") do |_scenario, block|
  AppLog.with_logger(Automation::CucumberLogger.new(world: self)) { block.call }
ensure
  AppLog.clear!
end
