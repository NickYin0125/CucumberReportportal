# frozen_string_literal: true

module Automation
  # Scoped metadata for synchronous Cucumber World callbacks.
  # Thread#[] also isolates fibers, matching AppLog's active logger scope.
  module ReportContext
    THREAD_KEY = :reportportal_cucumber_report_context

    # Trusted, message-local RP alternatives, created only by structured SDK logs.
    # Rendering is lazy so plain formatters never invoke accent helpers; it is
    # memoized so synchronous rich subscribers share one result and warning.
    class LogCard
      attr_reader :native, :plain

      # @param native [String] Exact native message, not a selector or pattern.
      # @param plain [String] RP-only plain rendering, independent of native output.
      # @yieldreturn [String] RP-only rendering with its original-baseline fallback.
      def initialize(native, plain: native, &render)
        @native = native.dup.freeze
        @plain = plain.dup.freeze
        @render = render
      end

      # @return [String] Memoized RP body; never the native/caller message.
      def rich
        return @rich if defined?(@rich)

        @rich = @render.call.freeze
        @render = nil
        @rich
      end
    end

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
