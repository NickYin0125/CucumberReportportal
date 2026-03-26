# frozen_string_literal: true

module ReportportalCucumber
  module Service
    # Background processor that batches logs and attachments before sending them to ReportPortal.
    class QueueProcessor
      LogRecord = Struct.new(:item_uuid, :launch_uuid, :message, :level, :timestamp, :attachment, keyword_init: true)

      # @param api [ReportportalCucumber::ReportPortal::API]
      # @param config [ReportportalCucumber::Config]
      # @param on_error [#call, nil]
      def initialize(api:, config:, on_error: nil)
        @api = api
        @config = config
        @on_error = on_error
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @records = []
        @flush_requests = []
        @closed = false
        @worker = Thread.new { worker_loop }
        @worker.name = "reportportal-log-buffer" if @worker.respond_to?(:name=)
      end

      # @param item_uuid [String, nil]
      # @param launch_uuid [String, nil]
      # @param message [String]
      # @param level [String, Symbol]
      # @param timestamp [Time, String, Integer, Float]
      # @param attachment [Hash, nil]
      # @return [void]
      def emit_log(item_uuid:, launch_uuid:, message:, level:, timestamp:, attachment: nil)
        @mutex.synchronize do
          return if @closed

          @records << LogRecord.new(
            item_uuid: item_uuid,
            launch_uuid: launch_uuid,
            message: message,
            level: level,
            timestamp: timestamp,
            attachment: attachment
          )
          @condition.signal
        end
      end

      # @param timeout [Numeric]
      # @return [Boolean]
      def flush(timeout: @config.exit_flush_timeout_ms / 1000.0)
        acknowledge(timeout: timeout) do |ack|
          @flush_requests << ack
          @condition.signal
        end
      end

      # @param timeout [Numeric]
      # @return [Boolean]
      def shutdown(timeout: @config.exit_flush_timeout_ms / 1000.0)
        acknowledge(timeout: timeout) do |ack|
          return true if @closed && !@worker.alive?

          @closed = true
          @flush_requests << ack
          @condition.broadcast
        end.tap do
          @worker.join(timeout)
        end
      end

      private

      # @param timeout [Numeric]
      # @yieldparam ack [Queue]
      # @return [Boolean]
      def acknowledge(timeout:)
        acknowledgement = Queue.new
        @mutex.synchronize { yield acknowledgement }
        Timeout.timeout(timeout) { acknowledgement.pop }
      rescue Timeout::Error
        false
      end

      # @return [void]
      def worker_loop
        loop do
          batch, acknowledgements, should_stop = next_work_unit
          flush_batch(batch) unless batch.empty?
          acknowledgements.each { |ack| ack << true }
          break if should_stop
        end
      rescue StandardError => error
        fail_pending_flushes
        handle_error(error)
      end

      # @return [Array<Array<LogRecord>, Array<Queue>, Boolean>]
      def next_work_unit
        @mutex.synchronize do
          wait_for_work
          wait_for_batch_fill if @records.any? && @flush_requests.empty? && !@closed

          batch_size = (@flush_requests.any? || @closed) ? @records.length : @config.batch_size_logs
          batch = @records.shift(batch_size)
          acknowledgements = @flush_requests.shift(@flush_requests.length)
          should_stop = @closed && @records.empty?
          [batch, acknowledgements, should_stop]
        end
      end

      # @return [void]
      def wait_for_work
        while @records.empty? && @flush_requests.empty? && !@closed
          @condition.wait(@mutex)
        end
      end

      # @return [void]
      def wait_for_batch_fill
        deadline = monotonic_now + @config.flush_interval
        while @records.length < @config.batch_size_logs && @flush_requests.empty? && !@closed
          remaining = deadline - monotonic_now
          break if remaining <= 0

          @condition.wait(@mutex, remaining)
        end
      end

      # @param records [Array<LogRecord>]
      # @return [void]
      def flush_batch(records)
        return if records.empty?

        payload = Service::PayloadBuilder.build_log_batch(records)
        attempts = 0

        begin
          attempts += 1
          @api.log_batch(entries: payload.fetch(:entries), files: payload.fetch(:files))
        rescue StandardError => error
          if attempts < @config.retry_attempts
            sleep(backoff_for(attempts))
            retry
          end

          spool(records, error)
          handle_error(error)
        end
      end

      # @param records [Array<LogRecord>]
      # @param error [StandardError]
      # @return [void]
      def spool(records, error)
        directory = File.expand_path(@config.spool_dir, Dir.pwd)
        FileUtils.mkdir_p(directory)

        basename = "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(6)}"
        payload = Service::PayloadBuilder.build_log_batch(records)
        attachments_dir = File.join(directory, "#{basename}.attachments")
        FileUtils.mkdir_p(attachments_dir)

        payload.fetch(:files).each do |file|
          File.binwrite(File.join(attachments_dir, file.fetch(:name)), file.fetch(:bytes))
        end

        File.open(File.join(directory, "#{basename}.ndjson"), "wb") do |file|
          payload.fetch(:entries).each do |entry|
            file.puts(JSON.generate(entry.merge("spoolError" => error.message)))
          end
        end
      end

      # @return [void]
      def fail_pending_flushes
        @mutex.synchronize do
          @flush_requests.shift(@flush_requests.length).each { |ack| ack << false }
        end
      end

      # @param attempt [Integer]
      # @return [Float]
      def backoff_for(attempt)
        base = @config.retry_base_interval * (2**(attempt - 1))
        capped = [base, @config.retry_max_interval].min
        capped + rand * (capped / 4.0)
      end

      # @return [Float]
      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # @param error [StandardError]
      # @return [void]
      def handle_error(error)
        @on_error&.call(error)
      end
    end
  end
end
