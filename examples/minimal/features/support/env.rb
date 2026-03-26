# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __dir__))

require "reportportal_cucumber"

World(ReportportalCucumber::Cucumber::World) if respond_to?(:World)
