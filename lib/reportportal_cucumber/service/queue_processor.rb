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
        @in_flight_records = []
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
        result = acknowledge(timeout: timeout) do |ack|
          return true if @closed && !@worker.alive?

          @closed = true
          @flush_requests << ack
          @condition.broadcast
        end
        spool_unflushed("Log buffer shutdown timed out") unless result
        @worker.join(timeout)
        result
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
          mark_in_flight(batch)
          flush_batch(batch) unless batch.empty?
          mark_in_flight([])
          acknowledgements.each { |ack| ack << true }
          break if should_stop
        end
      rescue StandardError => error
        mark_in_flight([])
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

        attempts = 0

        begin
          attempts += 1
          payload = Service::PayloadBuilder.build_log_batch(records)
          @api.log_batch(entries: payload.fetch(:entries), files: payload.fetch(:files))
        rescue StandardError => error
          if retryable_reporting_error?(error) && attempts < @config.retry_attempts
            sleep(backoff_for(attempts))
            retry
          end

          safe_spool(records, error)
          handle_error(error)
        end
      end

      # @param error [StandardError]
      # @return [Boolean]
      def retryable_reporting_error?(error)
        response = error.respond_to?(:response) ? error.response : nil
        return false if response && [400, 401, 403].include?(response.status)

        true
      end

      # @param records [Array<LogRecord>]
      # @param error [StandardError]
      # @return [void]
      def safe_spool(records, error)
        spool(records, error)
      rescue StandardError => spool_error
        fallback_spool(records, error, spool_error)
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
          attachment_path = File.join(attachments_dir, file.fetch(:name))
          if file[:path]
            IO.copy_stream(file.fetch(:path), attachment_path)
          else
            File.binwrite(attachment_path, file.fetch(:bytes))
          end
        end

        File.open(File.join(directory, "#{basename}.ndjson"), "wb") do |file|
          payload.fetch(:entries).each do |entry|
            file.puts(JSON.generate(entry.merge("spoolError" => error.message)))
          end
        end
      end

      # @param records [Array<LogRecord>]
      # @param original_error [StandardError]
      # @param spool_error [StandardError]
      # @return [void]
      def fallback_spool(records, original_error, spool_error)
        begin
          raw_spool(records, original_error, spool_error, File.expand_path(@config.spool_dir, Dir.pwd))
        rescue StandardError
          begin
            raw_spool(records, original_error, spool_error, File.join(Dir.tmpdir, "reportportal-cucumber-spool"))
          rescue StandardError => final_error
            handle_error(final_error)
          end
        end
      end

      # @param records [Array<LogRecord>]
      # @param original_error [StandardError]
      # @param spool_error [StandardError]
      # @param directory [String]
      # @return [void]
      def raw_spool(records, original_error, spool_error, directory)
        FileUtils.mkdir_p(directory)
        basename = "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(6)}"
        attachments_dir = File.join(directory, "#{basename}.attachments")
        FileUtils.mkdir_p(attachments_dir)

        File.open(File.join(directory, "#{basename}.ndjson"), "wb") do |file|
          records.each_with_index do |record, index|
            attachment = raw_attachment(record, attachments_dir, index)
            file.puts(
              JSON.generate(
                raw_record(record).merge(
                  "attachment" => attachment,
                  "rawSpool" => true,
                  "spoolError" => "#{original_error.class}: #{original_error.message}",
                  "fallbackSpoolError" => "#{spool_error.class}: #{spool_error.message}"
                ).compact
              )
            )
          end
        end
      end

      # @param record [LogRecord]
      # @return [Hash]
      def raw_record(record)
        {
          "itemUuid" => record.item_uuid,
          "launchUuid" => record.launch_uuid,
          "message" => record.message.to_s,
          "level" => record.level.to_s,
          "time" => raw_time(record.timestamp)
        }.compact
      end

      # @param value [Time, String, Integer, Float]
      # @return [String]
      def raw_time(value)
        case value
        when Time
          (value.to_r * 1000).to_i.to_s
        when Integer
          value.to_s
        when Float
          value.to_i.to_s
        else
          value.to_s
        end
      end

      # @param record [LogRecord]
      # @param directory [String]
      # @param index [Integer]
      # @return [Hash, nil]
      def raw_attachment(record, directory, index)
        attachment = record.attachment
        return nil unless attachment

        payload = attachment.respond_to?(:to_h) ? attachment.to_h : attachment
        name = Transport::MultipartHelper.safe_filename(payload[:name] || payload["name"] || "attachment-#{index}")
        path = payload[:path] || payload["path"] || payload[:file_path] || payload["file_path"]
        if path && File.file?(File.expand_path(path.to_s))
          IO.copy_stream(File.expand_path(path.to_s), File.join(directory, name))
        else
          bytes = payload[:bytes] || payload["bytes"] || ""
          data = bytes.respond_to?(:read) ? bytes.read : bytes.to_s
          bytes.rewind if bytes.respond_to?(:rewind)
          File.binwrite(File.join(directory, name), data)
        end
        {
          "name" => name,
          "mime" => payload[:mime] || payload["mime"],
          "spooledPath" => File.join(File.basename(directory), name)
        }.compact
      end

      # @param message [String]
      # @return [void]
      def spool_unflushed(message)
        records = nil
        @mutex.synchronize do
          records = @in_flight_records + @records
        end
        return if records.empty?

        safe_spool(records, ReportportalCucumber::ReportingError.new(message))
      end

      # @return [void]
      def fail_pending_flushes
        @mutex.synchronize do
          @flush_requests.shift(@flush_requests.length).each { |ack| ack << false }
        end
      end

      # @param records [Array<LogRecord>]
      # @return [void]
      def mark_in_flight(records)
        @mutex.synchronize { @in_flight_records = records.dup }
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
