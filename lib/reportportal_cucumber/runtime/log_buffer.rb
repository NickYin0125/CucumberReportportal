# frozen_string_literal: true

module ReportportalCucumber
  module Runtime
    # Buffers logs on a background worker and flushes them in batches.
    class LogBuffer
      # @param api [ReportportalCucumber::ReportPortal::API]
      # @param config [ReportportalCucumber::Config]
      # @param on_error [#call, nil]
      def initialize(api:, config:, on_error: nil)
        @api = api
        @config = config
        @on_error = on_error
        @queue = Queue.new
        @closed = false
        @worker = Thread.new { worker_loop }
      end

      # @param item_uuid [String, nil]
      # @param launch_uuid [String, nil]
      # @param message [String]
      # @param level [String, Symbol]
      # @param timestamp [Time, String, Integer, Float]
      # @param attachment [Hash, nil]
      # @return [void]
      def emit_log(item_uuid:, launch_uuid:, message:, level:, timestamp:, attachment: nil)
        return if @closed

        @queue << {
          command: :log,
          entry: ReportPortal::Models.build_log_entry(
            launch_uuid: launch_uuid,
            item_uuid: item_uuid,
            time: timestamp,
            message: message,
            level: level,
            file_name: attachment && attachment[:name]
          ),
          attachment: attachment
        }
      end

      # @param timeout [Numeric]
      # @return [Boolean]
      def flush(timeout: @config.exit_flush_timeout_ms / 1000.0)
        acknowledgement = Queue.new
        @queue << { command: :flush, ack: acknowledgement }
        Timeout.timeout(timeout) { acknowledgement.pop }
      rescue Timeout::Error
        false
      end

      # @param timeout [Numeric]
      # @return [Boolean]
      def shutdown(timeout: @config.exit_flush_timeout_ms / 1000.0)
        return true if @closed

        @closed = true
        acknowledgement = Queue.new
        @queue << { command: :stop, ack: acknowledgement }
        Timeout.timeout(timeout) { acknowledgement.pop }
        @worker.join(timeout)
        true
      rescue Timeout::Error
        false
      end

      private

      # @return [void]
      def worker_loop
        batch = []
        first_item_at = nil

        loop do
          begin
            payload = @queue.pop(true)
            case payload.fetch(:command)
            when :log
              batch << payload
              first_item_at ||= monotonic_now
              if batch.length >= @config.batch_size_logs
                flush_batch(batch)
                batch = []
                first_item_at = nil
              end
            when :flush
              flush_batch(batch)
              batch = []
              first_item_at = nil
              payload.fetch(:ack) << true
            when :stop
              flush_batch(batch)
              payload.fetch(:ack) << true
              break
            end
          rescue ThreadError
            if !batch.empty? && first_item_at && (monotonic_now - first_item_at) >= @config.flush_interval
              flush_batch(batch)
              batch = []
              first_item_at = nil
            else
              sleep(0.05)
            end
          end
        end
      rescue StandardError => error
        handle_error(error)
      end

      # @param items [Array<Hash>]
      # @return [void]
      def flush_batch(items)
        return if items.empty?

        entries, files = build_payload(items)
        attempts = 0

        begin
          attempts += 1
          @api.log_batch(entries: entries, files: files)
        rescue StandardError => error
          if attempts < @config.retry_attempts
            sleep(backoff_for(attempts))
            retry
          end

          spool(items, error)
          handle_error(error)
        end
      end

      # @param items [Array<Hash>]
      # @return [Array<Array<Hash>, Array<Hash>>]
      def build_payload(items)
        used_names = Hash.new(0)
        entries = []
        files = []

        items.each do |item|
          entry = Marshal.load(Marshal.dump(item.fetch(:entry)))
          attachment = item[:attachment]
          if attachment
            filename = unique_filename(attachment.fetch(:name), used_names)
            entry["file"] = { "name" => filename }
            files << {
              name: filename,
              mime: attachment.fetch(:mime),
              bytes: attachment.fetch(:bytes)
            }
          end
          entries << entry
        end

        [entries, files]
      end

      # @param items [Array<Hash>]
      # @param error [StandardError]
      # @return [void]
      def spool(items, error)
        directory = File.expand_path(@config.spool_dir, Dir.pwd)
        FileUtils.mkdir_p(directory)

        basename = "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(6)}"
        ndjson_path = File.join(directory, "#{basename}.ndjson")
        attachments_dir = File.join(directory, "#{basename}.attachments")
        FileUtils.mkdir_p(attachments_dir)

        File.open(ndjson_path, "wb") do |file|
          items.each do |item|
            payload = item.fetch(:entry).dup
            if (attachment = item[:attachment])
              filename = attachment.fetch(:name)
              File.binwrite(File.join(attachments_dir, filename), attachment.fetch(:bytes))
              payload["file"] = { "name" => filename, "directory" => attachments_dir }
            end
            payload["spoolError"] = error.message
            file.puts(JSON.generate(payload))
          end
        end
      end

      # @param attempt [Integer]
      # @return [Float]
      def backoff_for(attempt)
        base = @config.retry_base_interval * (2**(attempt - 1))
        capped = [base, @config.retry_max_interval].min
        capped + rand * (capped / 4.0)
      end

      # @param filename [String]
      # @param used_names [Hash<String, Integer>]
      # @return [String]
      def unique_filename(filename, used_names)
        count = used_names[filename]
        used_names[filename] += 1
        return filename if count.zero?

        extension = File.extname(filename)
        stem = extension.empty? ? filename : filename.delete_suffix(extension)
        "#{stem}-#{count}#{extension}"
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
