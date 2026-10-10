# frozen_string_literal: true

module ReportportalCucumber
  module Runtime
    # Thin compatibility wrapper around the queue processor used by the formatter.
    class LogBuffer
      # @param api [ReportportalCucumber::ReportPortal::API]
      # @param config [ReportportalCucumber::Config]
      # @param on_error [#call, nil]
      # @param video_uploader [ReportportalCucumber::Transport::MinioUploader, nil]
      def initialize(api:, config:, on_error: nil, video_uploader: nil)
        @processor = Service::QueueProcessor.new(
          api: api,
          config: config,
          on_error: on_error,
          video_uploader: video_uploader
        )
      end

      # @param item_uuid [String, nil]
      # @param launch_uuid [String, nil]
      # @param message [String]
      # @param level [String, Symbol]
      # @param timestamp [Time, String, Integer, Float]
      # @param attachment [Hash, nil]
      # @return [Boolean] Whether the record was admitted to the local queue.
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

      # @return [Hash] Immutable, thread-safe queue counters and occupancy.
      def diagnostics
        @processor.diagnostics
      end

      # @param timeout [Numeric]
      # @return [Boolean]
      def flush(timeout:)
        @processor.flush(timeout: timeout)
      end

      # @param timeout [Numeric]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [ReportportalCucumber::Service::DeliveryReceipt]
      def flush_receipt(timeout:, deadline: nil)
        @processor.flush_receipt(timeout: timeout, deadline: deadline)
      end

      # @param timeout [Numeric]
      # @return [Boolean]
      def shutdown(timeout:)
        @processor.shutdown(timeout: timeout)
      end

      # @param timeout [Numeric]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [ReportportalCucumber::Service::DeliveryReceipt]
      def shutdown_receipt(timeout:, deadline: nil)
        @processor.shutdown_receipt(timeout: timeout, deadline: deadline)
      end

      # @param rejected [Integer, nil]
      # @param capture_close_timeouts [Integer]
      # @param metadata_failures [Integer]
      # @param degraded_evidence [Integer]
      # @param finalization_complete [Boolean]
      # @return [ReportportalCucumber::Service::DeliveryReceipt]
      def reporting_receipt(rejected: nil, capture_close_timeouts: 0, metadata_failures: 0,
                            degraded_evidence: 0, finalization_complete: false)
        @processor.reporting_receipt(rejected: rejected, capture_close_timeouts: capture_close_timeouts,
                                     metadata_failures: metadata_failures, degraded_evidence: degraded_evidence,
                                     finalization_complete: finalization_complete)
      end
    end
  end
end
