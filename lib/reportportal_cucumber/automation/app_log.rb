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
    # @return [void]
    def trace(message, attach: false, file: nil, json: nil)
      dispatch(:trace, message, attach: attach, file: file, json: json)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @return [void]
    def debug(message, attach: false, file: nil, json: nil)
      dispatch(:debug, message, attach: attach, file: file, json: json)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @return [void]
    def info(message, attach: false, file: nil, json: nil)
      dispatch(:info, message, attach: attach, file: file, json: json)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @return [void]
    def warn(message, attach: false, file: nil, json: nil)
      dispatch(:warn, message, attach: attach, file: file, json: json)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @return [void]
    def error(message, attach: false, file: nil, json: nil)
      dispatch(:error, message, attach: attach, file: file, json: json)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @return [void]
    def fatal(message, attach: false, file: nil, json: nil)
      dispatch(:fatal, message, attach: attach, file: file, json: json)
    end

    private

    def dispatch(level, message, attach:, file:, json:)
      logger.public_send(level, message, attach: attach, file: file, json: json)
    end
  end
end
