# frozen_string_literal: true

require "reportportal_cucumber"
require "json"

module LedgerWP5QueueErrorObservation
  private

  def handle_error(error)
    if ENV["QA_QUEUE_ERRORS"]
      record = { ruby: RUBY_DESCRIPTION, cucumber: Gem.loaded_specs["cucumber"]&.version&.to_s,
        sdk: ReportportalCucumber::VERSION, example: defined?(RSpec) && RSpec.current_example&.full_description,
        class: error.class.name, message: error.message, backtrace: error.backtrace&.first(20) }
      File.open(ENV.fetch("QA_QUEUE_ERRORS"), "a") { |file| file.puts(JSON.generate(record)) }
    end
    super
  end
end
ReportportalCucumber::Service::QueueProcessor.prepend(LedgerWP5QueueErrorObservation)
