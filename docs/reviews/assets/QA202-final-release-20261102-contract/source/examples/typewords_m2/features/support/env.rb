# frozen_string_literal: true

require "fileutils"
require "json"
require "uri"
require "playwright"
require "reportportal_cucumber"

M2_EVIDENCE_DIR = ENV.fetch("M2_EVIDENCE_DIR")
FileUtils.mkdir_p(M2_EVIDENCE_DIR)

module TypewordsM2World
  def page
    @typewords_page
  end

  def dismiss_first_tour
    return unless page.get_by_role("dialog").count.positive?

    page.get_by_role("button", name: "Close Tour").click
  end
end
World(ReportportalCucumber::Cucumber::World, TypewordsM2World)

Around do |_scenario, block|
  Playwright.create(playwright_cli_executable_path: ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH")) do |playwright|
    browser = nil
    context = nil
    failure = nil
    begin
      browser = playwright.chromium.launch
      context = browser.new_context
      @typewords_page = context.new_page
      @m2_console_messages = []
      @typewords_page.on("console", ->(message) { @m2_console_messages << "#{message.type}: #{message.text}" })
      @typewords_page.goto(ENV.fetch("TYPEWORDS_URL"), waitUntil: "domcontentloaded")
      @typewords_page.wait_for_load_state(state: "networkidle", timeout: 15_000)
      AppLog.with_logger(Automation::CucumberLogger.new(world: self)) do
        block.call
      end
    rescue Exception => error
      failure = error
      raise
    ensure
      [context, browser].each do |resource|
        next unless resource

        begin
          resource.close
        rescue StandardError
          raise unless failure
        end
      end
    end
  end
end

After do |scenario|
  next unless @m2_failure_target

  @m2_late_evidence_result = rp_evidence(
    action: "Late After-hook evidence probe",
    error: RuntimeError.new("late evidence probe"),
    details: "This probe must be rejected because the failed Gherkin step is closed.",
    target: @m2_failure_target
  )
  File.write(
    File.join(M2_EVIDENCE_DIR, "late-evidence.json"),
    JSON.pretty_generate(scenario: scenario.name, accepted: @m2_late_evidence_result)
  )
end
