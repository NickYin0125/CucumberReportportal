# frozen_string_literal: true

require "json"
require "reportportal_cucumber"
require "cucumber"

sdk = Gem.loaded_specs.fetch("reportportal-cucumber-ruby")
puts JSON.generate(
  version: ReportportalCucumber::VERSION,
  gem_root: sdk.full_gem_path,
  cucumber: Gem.loaded_specs.fetch("cucumber").version.to_s,
  cucumber_expressions: Gem.loaded_specs.fetch("cucumber-cucumber-expressions").version.to_s,
  dependencies: sdk.runtime_dependencies.map(&:name).sort,
  loaded_gems: Gem.loaded_specs.keys.sort,
  sdk_files: $LOADED_FEATURES.select { |path| path.include?("reportportal_cucumber") }
)
