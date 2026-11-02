# frozen_string_literal: true

require "securerandom"

module CurrentSDK
  module World
    def api
      @api ||= ApiClient.new(FIXTURE.url)
    end

    def check_equal(name, expected, actual)
      passed = expected == actual
      AppLog.assertion(name: name, expected: expected, actual: actual, passed: passed)
      @failed_check = name unless passed
      raise "#{name}: expected #{expected.inspect}, got #{actual.inspect}" unless passed
    end

    def ui_action(name)
      AppLog.info("UI action: #{name}", report: true)
      result = yield
      @last_passed_ui_action = name
      result
    rescue StandardError => error
      @failed_check ||= name
      @ui_failure = error
      raise # Preserve the original Playwright exception and backtrace.
    end

    def capture_failure(scenario)
      return unless scenario.failed? && @page

      error = scenario.exception || @ui_failure
      checkpoint = @failed_check || "UI scenario failure"
      screenshot = screenshot_path(scenario.name, checkpoint)
      @page.screenshot(path: screenshot, fullPage: true, timeout: 5000)
      redactor = Automation::EvidenceRedactor.new
      caption = ["Failure evidence: #{redactor.redact_text(scenario.name)} - #{redactor.redact_text(checkpoint)}",
                 "Last browser action (passed): #{redactor.redact_text(@last_passed_ui_action || 'none')}",
                 "#{error.class}: #{redactor.redact_text(error.message)}",
                 "Captured by the framework After hook, not the closed failed step."].join("\n\n")
      # The owner-approved RP-only route keeps one captioned PNG on the open
      # After hook. Native reports retain the original failure, not the PNG.
      AppLog.error(caption.lines.first.chomp, file: screenshot, report: false)
      rp_attach(screenshot, name: File.basename(screenshot), mime: "image/png",
                 message: caption, level: :error)
    rescue StandardError => reporting_error
      AppLog.warn("Failure evidence unavailable: #{reporting_error.class}")
      # Evidence failure must not replace the original business exception.
    end

    def close_ui(scenario)
      errors = []
      [@page, @context, @browser].compact.each do |resource|
        resource.close
      rescue StandardError => error
        errors << error
        AppLog.warn("UI cleanup failed: #{error.class}")
      end
      raise errors.first if !errors.empty? && !scenario.failed? && $!.nil?
    ensure
      @page = @context = @browser = nil
    end

    def optional_live_snapshot
      return unless ENV["TYPEWORDS_SCREENSHOT"] == "true"

      screenshot = screenshot_path(@scenario_name || "Typewords", "title-check")
      @page.screenshot(path: screenshot, fullPage: true, timeout: 5000)
      AppLog.info("Opt-in Typewords screenshot", file: screenshot, report: true)
    end

    private

    def screenshot_path(scenario_name, checkpoint)
      redactor = Automation::EvidenceRedactor.new
      parts = [[scenario_name, "scenario", 72], [checkpoint, "checkpoint", 48]].map do |value, fallback, limit|
        slug = redactor.redact_text(value).downcase.gsub(/[^a-z0-9]+/, "-")[0, limit].sub(/-+\z/, "").sub(/\A-+/, "")
        slug.empty? ? fallback : slug
      end
      File.join(ENV.fetch("REPORT_DIR"), "#{parts.join('-')}-#{SecureRandom.hex(4)}.png")
    end
  end
end
