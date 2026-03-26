# frozen_string_literal: true

module ReportportalCucumber
  module Runtime
    # Thin compatibility wrapper around the queue processor used by the formatter.
    class LogBuffer
      # @param api [ReportportalCucumber::ReportPortal::API]
      # @param config [ReportportalCucumber::Config]
      # @param on_error [#call, nil]
      def initialize(api:, config:, on_error: nil)
        @processor = Service::QueueProcessor.new(api: api, config: config, on_error: on_error)
      end

      # @param item_uuid [String, nil]
      # @param launch_uuid [String, nil]
      # @param message [String]
      # @param level [String, Symbol]
      # @param timestamp [Time, String, Integer, Float]
      # @param attachment [Hash, nil]
      # @return [void]
      def emit_log(item_uuid:, launch_uuid:, message:, level:, timestamp:, attachment: nil)
        @processor.emit_log(
          item_uuid: item_uuid,
          launch_uuid: launch_uuid,
          message: message,
          level: level,
          timestamp: timestamp,
          attachment: attachment
        )
      end

      # @param timeout [Numeric]
      # @return [Boolean]
      def flush(timeout:)
        @processor.flush(timeout: timeout)
      end

      # @param timeout [Numeric]
      # @return [Boolean]
      def shutdown(timeout:)
        @processor.shutdown(timeout: timeout)
      end
    end
  end
end
