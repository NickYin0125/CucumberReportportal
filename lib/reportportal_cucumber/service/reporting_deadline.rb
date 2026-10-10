# frozen_string_literal: true

module ReportportalCucumber
  module Service
    # Monotonic deadline shared by all work in one reporting finalization.
    class ReportingDeadline
      # @param timeout [Numeric]
      def initialize(timeout:)
        @expires_at = self.class.now + [timeout.to_f, 0].max
      end

      # @return [Float]
      def remaining
        [@expires_at - self.class.now, 0].max
      end

      # @return [Boolean]
      def expired?
        remaining.zero?
      end

      # @return [Float]
      def self.now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
