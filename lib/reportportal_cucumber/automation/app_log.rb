# frozen_string_literal: true

require_relative "cucumber_logger"

# Global proxy for thread-local automation logging.
module AppLog
  LEVELS = Automation::CucumberLogger::LEVELS

  class << self
    # @param world [Object]
    # @param output [#puts, nil]
    # @param color [Boolean, nil]
    # @return [Automation::CucumberLogger]
    def bind(world, output: nil, color: nil)
      Thread.current[:active_logger] = Automation::CucumberLogger.new(world: world, output: output, color: color)
    end

    # @return [void]
    def clear!
      Thread.current[:active_logger] = nil
    end

    # @return [Automation::CucumberLogger]
    def logger
      active_logger || Automation::CucumberLogger.new
    end

    # @return [Boolean]
    def active?
      !active_logger.nil?
    end

    # @return [Automation::CucumberLogger, nil]
    def active_logger
      Thread.current[:active_logger]
    end

    # @param logger [Automation::CucumberLogger, nil]
    # @return [Automation::CucumberLogger, nil]
    def active_logger=(logger)
      Thread.current[:active_logger] = logger
    end

    # @param logger [Automation::CucumberLogger]
    # @yieldreturn [Object]
    # @return [Object]
    def with_logger(logger)
      previous = active_logger
      self.active_logger = logger
      yield
    ensure
      self.active_logger = previous
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def trace(message, attach: false, file: nil, json: nil, report: nil)
      dispatch(:trace, message, attach: attach, file: file, json: json, report: report)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def debug(message, attach: false, file: nil, json: nil, report: nil)
      dispatch(:debug, message, attach: attach, file: file, json: json, report: report)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def info(message, attach: false, file: nil, json: nil, report: nil)
      dispatch(:info, message, attach: attach, file: file, json: json, report: report)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def warn(message, attach: false, file: nil, json: nil, report: nil)
      dispatch(:warn, message, attach: attach, file: file, json: json, report: report)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def error(message, attach: false, file: nil, json: nil, report: nil)
      dispatch(:error, message, attach: attach, file: file, json: json, report: report)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def fatal(message, attach: false, file: nil, json: nil, report: nil)
      dispatch(:fatal, message, attach: attach, file: file, json: json, report: report)
    end

    # @param method [String, Symbol]
    # @param url [String]
    # @param request [Hash]
    # @param response [Hash]
    # @param duration_ms [Numeric, nil]
    # @param expected_status [Integer, nil]
    # @param error [Object, nil]
    # @param report [Boolean]
    # @return [void]
    def http(method:, url:, request: {}, response: {}, duration_ms: nil, expected_status: nil, error: nil, report: true)
      logger.http(
        method: method,
        url: url,
        request: request,
        response: response,
        duration_ms: duration_ms,
        expected_status: expected_status,
        error: error,
        report: report
      )
    end

    private

    def dispatch(level, message, attach:, file:, json:, report:)
      logger.public_send(level, message, attach: attach, file: file, json: json, report: report)
    end
  end
end
