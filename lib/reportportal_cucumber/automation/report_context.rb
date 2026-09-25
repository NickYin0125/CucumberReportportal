# frozen_string_literal: true

module Automation
  # Scoped metadata for synchronous Cucumber World callbacks.
  # Thread#[] also isolates fibers, matching AppLog's active logger scope.
  module ReportContext
    THREAD_KEY = :reportportal_cucumber_report_context

    class << self
      # @return [Hash]
      def current
        Thread.current[THREAD_KEY] || {}
      end

      # @param metadata [Hash, nil]
      # @param attributes [Hash]
      # @yieldreturn [Object]
      # @return [Object]
      def with(metadata = nil, **attributes)
        previous = Thread.current[THREAD_KEY]
        Thread.current[THREAD_KEY] = current.merge(metadata || {}).merge(attributes)
        yield
      ensure
        Thread.current[THREAD_KEY] = previous
      end
    end
  end
end
