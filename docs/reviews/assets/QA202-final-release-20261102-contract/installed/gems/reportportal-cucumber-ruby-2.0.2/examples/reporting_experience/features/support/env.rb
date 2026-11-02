# frozen_string_literal: true

require "reportportal_cucumber"

Around do |_scenario, run|
  AppLog.with_logger(Automation::CucumberLogger.new(world: self)) do
    run.call
  end
end
