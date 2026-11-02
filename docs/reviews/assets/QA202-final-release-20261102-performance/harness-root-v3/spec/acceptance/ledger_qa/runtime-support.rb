# frozen_string_literal: true
# Frozen P1 fixture: line positions 59, 65 and 136 are acceptance inputs.

require "reportportal_cucumber"
World(ReportportalCucumber::Cucumber::World)

module IndependentCucumber12

















































  def self.deep_failure

    inner_failure
  end


  def self.inner_failure

    raise "INDEPENDENT_FULL_BACKTRACE"
  end
end


After do |scenario|
  attach(File.binread(ENV.fetch("LEDGER_JPEG")), "image/jpeg", "after-failure.jpg") if scenario.failed?
end






























































Given("independent fail") do
  IndependentCucumber12.deep_failure
end

Then("independent follower stays skipped") { raise "QA skipped follower executed" }
