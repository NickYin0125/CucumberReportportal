# frozen_string_literal: true

require "reportportal_cucumber"

Given("the installed candidate reports locally") do
  AppLog.info("ISOLATED_CANDIDATE_NATIVE_OK", report: true, json: { candidate: true })
end
