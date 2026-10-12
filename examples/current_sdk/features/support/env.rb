# frozen_string_literal: true

# Must precede formatter initialization, including direct `bundle exec cucumber`.
ENV["RP_ENABLED"] ||= "false"
ENV["RP_CLIENT_JOIN"] ||= "false"
ENV["RP_CONSOLE_MIRROR"] ||= "false"
ENV["RP_CONFIG"] ||= File.expand_path("../../config/reportportal.yml", __dir__)
ENV["REPORT_DIR"] ||= "artifacts/offline"
ENV["CUCUMBER_PUBLISH_ENABLED"] = "false"
ENV["CUCUMBER_PUBLISH_QUIET"] = "true"

require "fileutils"
require "shellwords"
require "playwright"
require "reportportal_cucumber"
require_relative "../../helpers/fixture_server"
require_relative "../../helpers/api_client"
require_relative "../../helpers/world"

FileUtils.mkdir_p(ENV.fetch("REPORT_DIR"))
World(ReportportalCucumber::Cucumber::World, CurrentSDK::World)
CurrentSDK::FIXTURE = CurrentSDK::FixtureServer.new

BeforeAll { CurrentSDK::FIXTURE.start }

Around do |scenario, block|
  logger = Automation::CucumberLogger.new(world: self, color: ENV["NO_COLOR"].to_s.empty?)
  AppLog.with_logger(logger) do
    if scenario.source_tag_names.include?("@ui")
      cli = ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH", File.expand_path("node_modules/.bin/playwright-core"))
      Playwright.create(playwright_cli_executable_path: Shellwords.escape(cli)) do |playwright|
        begin
          @browser = playwright.chromium.launch(headless: true)
          @context = @browser.new_context(viewport: {width: 1100, height: 740})
          @page = @context.new_page
          @page.set_default_timeout(5000)
          @page.set_default_navigation_timeout(10000)
          block.call
        ensure
          close_ui(scenario)
        end
      end
    else
      block.call
    end
  end
end

After { |scenario| capture_failure(scenario) }

AfterAll do
  begin
    raise "Scenario logger leaked" if AppLog.active?
  ensure
    CurrentSDK::FIXTURE.stop
    AppLog.clear!
  end
end
