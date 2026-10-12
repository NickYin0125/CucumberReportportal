# frozen_string_literal: true

module CurrentSDK
  module World
    def api
      @api ||= ApiClient.new(FIXTURE.url)
    end

    def check_equal(name, expected, actual)
      passed = expected == actual
      AppLog.assertion(name: name, expected: expected, actual: actual, passed: passed)
      raise "#{name}: expected #{expected.inspect}, got #{actual.inspect}" unless passed
    end

    def ui_action(name)
      @last_ui_action = name
      AppLog.info("UI action: #{name}", report: true)
      yield
    rescue StandardError => error
      @ui_failure = error
      raise # Preserve the original Playwright exception and backtrace.
    end

    def capture_failure(scenario)
      return unless scenario.failed? && @page

      error = @ui_failure || scenario.exception
      screenshot = File.join(ENV.fetch("REPORT_DIR"), "failure.png")
      @page.screenshot(path: screenshot, fullPage: true, timeout: 5000)
      action = @last_ui_action || "UI scenario failure"
      safe_error = Automation::EvidenceRedactor.new.redact_text(error.message)
      AppLog.error("Failure screenshot for #{action}: #{error.class}: #{safe_error}",
                   file: screenshot, report: true)
      # The failed step has already closed. Capture the current open After hook,
      # never silently retarget a stale step handle to a different action.
      target = rp_capture_target
      accepted = rp_evidence(action: action, error: error, url: @page.url,
                             details: "Captured by the framework After hook, not the closed failed step.",
                             target: target)
      attach(JSON.generate(action: action, error_class: error.class.name,
                           target: "After hook", rp_evidence_accepted: accepted),
             "application/json", "failure-routing.json")
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

      screenshot = File.join(ENV.fetch("REPORT_DIR"), "typewords.png")
      @page.screenshot(path: screenshot, fullPage: true, timeout: 5000)
      AppLog.info("Opt-in Typewords screenshot", file: screenshot, report: true)
    end
  end
end
