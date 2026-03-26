# frozen_string_literal: true

require "base64"
require "digest/sha1"
require "fileutils"
require "json"
require "logger"
require "securerandom"
require "time"
require "timeout"
require "uri"

require_relative "reportportal_cucumber/version"

module ReportportalCucumber
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ReportingError < Error; end
end

require_relative "reportportal_cucumber/config"
require_relative "reportportal_cucumber/http/client"
require_relative "reportportal_cucumber/reportportal/models"
require_relative "reportportal_cucumber/reportportal/api"
require_relative "reportportal_cucumber/runtime/context"
require_relative "reportportal_cucumber/runtime/log_buffer"
require_relative "reportportal_cucumber/runtime/join"
require_relative "reportportal_cucumber/cucumber/world"
require_relative "reportportal_cucumber/cucumber/formatter"

module ReportportalCucumber
  class << self
    attr_writer :logger

    # @return [Logger]
    def logger
      @logger ||= Logger.new($stderr).tap do |instance|
        instance.level = Logger::INFO
        instance.progname = "reportportal-cucumber"
      end
    end

    # @return [Object, nil]
    def current_runtime
      Thread.current[:reportportal_cucumber_runtime]
    end

    # @param runtime [Object, nil]
    # @return [Object, nil]
    def current_runtime=(runtime)
      Thread.current[:reportportal_cucumber_runtime] = runtime
    end
  end
end

module ReportPortal
  module Cucumber
    Formatter = ::ReportportalCucumber::Cucumber::Formatter
    World = ::ReportportalCucumber::Cucumber::World
  end
end
