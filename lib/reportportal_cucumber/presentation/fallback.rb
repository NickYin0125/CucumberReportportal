# frozen_string_literal: true

module ReportportalCucumber
  module Presentation
    # A rendering transaction: nested helper failures restore the whole message.
    module Fallback
      ACTIVE_KEY = :reportportal_cucumber_presentation_active
      WARNING = "ReportPortal presentation failed; using baseline format".freeze

      # Run only presentation work in this block, never reporting or business work.
      # Nested calls let the outermost message renderer handle the failure once.
      # The baseline callable runs outside the rescue and must not use new helpers.
      # @param fallback [#call] Exact pre-Ledger renderer for this message.
      # @param state [Hash, nil] Optional message-local failure latch for repeated
      #   queue size probes. A failed message uses baseline without retrying helpers.
      # @yieldreturn [Object] Newly rendered message or helper value.
      # @return [Object] Rendered value, or the baseline on StandardError.
      def self.render(fallback:, state: nil)
        return fallback.call if state && state[:failed]
        return yield if Thread.current[ACTIVE_KEY]

        failed = false
        begin
          Thread.current[ACTIVE_KEY] = true
          result = yield
        rescue StandardError
          failed = true
          state[:failed] = true if state
          warn_once
        ensure
          Thread.current[ACTIVE_KEY] = nil
        end
        failed ? fallback.call : result
      end

      def self.warn_once
        # Never include exception text, class names, or evidence in diagnostics.
        ReportportalCucumber.logger.warn(WARNING)
      rescue StandardError
        nil
      end
      private_class_method :warn_once
    end
  end
end
