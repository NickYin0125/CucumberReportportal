# frozen_string_literal: true

require_relative "evidence_presenter"
require_relative "spool_store"

module ReportportalCucumber
  module Service
    # Background processor with bounded admission and bounded FIFO request bodies.
    class QueueProcessor
      RECORD_OVERHEAD_BYTES = 256
      MAX_CONTROL_REQUESTS = 64
      SPOOL_WARNING_REASONS = %i[
        quota_exceeded deadline_expired lock_timeout quota_lock_failed unsafe_root
        missing_root root_unavailable unsafe_path unsafe_evidence changed_evidence
        publish_failed persistence_failed
      ].freeze
      DIAGNOSTIC_KEYS = %i[
        accepted rejected_overflow rejected_admission_timeout rejected_oversized
        rejected_unsupported rejected_closed control_rejected control_timed_out
        sent_batches delivery_failed oversized_wire spool_failed worker_failed
        confirmed accepted_awaiting_persistence spooled failed ambiguous settled degraded_evidence possible_duplicates
      ].freeze
      LogRecord = Struct.new(:item_uuid, :launch_uuid, :message, :level, :timestamp,
                             :attachment, :accounted_bytes, :sequence, keyword_init: true)
      class SnapshotError < ArgumentError; end

      # @param api [ReportportalCucumber::ReportPortal::API]
      # @param config [ReportportalCucumber::Config]
      # @param on_error [#call, nil]
      # @param video_uploader [ReportportalCucumber::Transport::MinioUploader, nil]
      def initialize(api:, config:, on_error: nil, video_uploader: nil)
        @api = api
        @config = config
        @on_error = on_error
        @video_uploader = video_uploader || default_video_uploader
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @records = []
        @in_flight_records = []
        @in_flight_unsettled = []
        @spool_store = Service::SpoolStore.new(config: config)
        @flush_requests = []
        @accepted_sequence = 0
        @settled_sequence = 0
        @reserved_records = 0
        @reserved_bytes = 0
        @peak_records = 0
        @peak_bytes = 0
        @counters = DIAGNOSTIC_KEYS.to_h { |key| [key, 0] }
        @warned_reasons = {}
        @closed = false
        @worker_failed = false
        @worker = Thread.new { worker_loop }
        @worker.name = "reportportal-log-buffer" if @worker.respond_to?(:name=)
      end

      # @param item_uuid [String, nil]
      # @param launch_uuid [String, nil]
      # @param message [String]
      # @param level [String, Symbol]
      # @param timestamp [Time, String, Integer, Float]
      # @param attachment [Hash, nil]
      # @return [Boolean] Whether this record was admitted to the local queue.
      def emit_log(item_uuid:, launch_uuid:, message:, level:, timestamp:, attachment: nil)
        estimate, reason, = estimate_record(item_uuid, launch_uuid, message, level, timestamp, attachment)
        return reject(reason) if reason
        return reject(:rejected_oversized) if estimate > queue_max_bytes

        warning = nil
        admitted = false
        deadline = monotonic_now + queue_admission_timeout_ms / 1000.0
        @mutex.synchronize do
          loop do
            if @closed || @worker_failed || !@worker.alive?
              warning = increment_rejection(:rejected_closed)
              break
            end

            estimate, reason, plan = estimate_record(item_uuid, launch_uuid, message, level, timestamp, attachment)
            if reason
              warning = increment_rejection(reason)
              break
            end
            if estimate > queue_max_bytes
              warning = increment_rejection(:rejected_oversized)
              break
            end

            if capacity_available?(estimate)
              admitted = reserve_and_commit_snapshot(plan, estimate)
              warning = increment_rejection(:rejected_unsupported) unless admitted
              break
            end

            if queue_overflow_policy == "reject_new"
              warning = increment_rejection(:rejected_overflow)
              break
            end

            remaining = deadline - monotonic_now
            if remaining <= 0
              warning = increment_rejection(:rejected_admission_timeout)
              break
            end
            @condition.wait(@mutex, remaining)
          end
        end
        warn_rejection(warning) if warning
        admitted
      end

      # @return [Hash] Immutable point-in-time admission and occupancy diagnostics.
      def diagnostics
        @mutex.synchronize do
          {
            counters: @counters.dup.freeze,
            current_records: @reserved_records,
            current_bytes: @reserved_bytes,
            peak_records: @peak_records,
            peak_bytes: @peak_bytes,
            closed: @closed,
            worker_alive: @worker.alive? && !@worker_failed
          }.freeze
        end
      end

      # @param timeout [Numeric]
      # @return [Boolean]
      def flush(timeout: @config.exit_flush_timeout_ms / 1000.0)
        flush_receipt(timeout: timeout).local_settled
      end

      # @param timeout [Numeric]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [ReportportalCucumber::Service::DeliveryReceipt]
      def flush_receipt(timeout: @config.exit_flush_timeout_ms / 1000.0, deadline: nil)
        barrier_receipt(timeout: timeout, deadline: deadline)
      end

      # @param timeout [Numeric]
      # @return [Boolean]
      def shutdown(timeout: @config.exit_flush_timeout_ms / 1000.0)
        shutdown_receipt(timeout: timeout).local_settled
      end

      # @param timeout [Numeric]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [ReportportalCucumber::Service::DeliveryReceipt]
      def shutdown_receipt(timeout: @config.exit_flush_timeout_ms / 1000.0, deadline: nil)
        deadline ||= Service::ReportingDeadline.new(timeout: timeout)
        receipt = barrier_receipt(timeout: timeout, deadline: deadline, close: true)
        remaining = deadline.remaining
        @worker.join(remaining) if remaining.positive?
        receipt
      end

      # @param rejected [Integer]
      # @param capture_close_timeouts [Integer]
      # @param metadata_failures [Integer]
      # @param degraded_evidence [Integer]
      # @param finalization_complete [Boolean]
      # @return [ReportportalCucumber::Service::DeliveryReceipt]
      def reporting_receipt(rejected: nil, capture_close_timeouts: 0, metadata_failures: 0,
                            degraded_evidence: 0, finalization_complete: false)
        @mutex.synchronize do
          totals = @counters
          rejected_count = rejected || %i[rejected_overflow rejected_admission_timeout rejected_oversized
                                         rejected_unsupported rejected_closed].sum { |key| totals[key] }
          complete = @settled_sequence >= @accepted_sequence && totals[:confirmed] == @accepted_sequence &&
                     rejected_count.zero? && capture_close_timeouts.zero? && metadata_failures.zero? &&
                     degraded_evidence.zero? && totals[:degraded_evidence].zero? &&
                     totals[:possible_duplicates].zero? && finalization_complete
          degraded_evidence += totals[:degraded_evidence]
          counts = @counters.slice(*zero_outcomes.keys)
          counts[:pending] = [@accepted_sequence - @settled_sequence, 0].max
          build_receipt(cutoff: @accepted_sequence, counts: counts, rejected: rejected_count,
                        capture_close_timeouts: capture_close_timeouts, metadata_failures: metadata_failures,
                        degraded_evidence: degraded_evidence, timed_out: false, complete: complete)
        end
      end

      private

      def estimate_record(item_uuid, launch_uuid, message, level, timestamp, attachment)
        return [0, :rejected_unsupported] unless message.instance_of?(String)
        return [0, :rejected_unsupported] unless valid_optional_string?(item_uuid) && valid_optional_string?(launch_uuid)
        return [0, :rejected_unsupported] unless level.instance_of?(String) || level.instance_of?(Symbol)
        return [0, :rejected_unsupported] unless [Time, String, Integer, Float].any? { |type| timestamp.instance_of?(type) }

        values = { item_uuid: item_uuid, launch_uuid: launch_uuid, message: message,
                   level: level, timestamp: timestamp }
        attachment_values = nil
        if attachment
          return [0, :rejected_unsupported] unless attachment.instance_of?(Hash)

          attachment_values = {
            path: attachment[:path] || attachment["path"] || attachment[:file_path] || attachment["file_path"],
            bytes: attachment[:bytes] || attachment["bytes"],
            name: attachment[:name] || attachment["name"],
            mime: attachment[:mime] || attachment["mime"]
          }
          values.merge!(attachment_values)
        end
        path = values[:path]
        data = values[:bytes]
        name = values[:name]
        mime = values[:mime]
        return [0, :rejected_unsupported] if path && data
        return [0, :rejected_unsupported] unless valid_optional_string?(name) && valid_optional_string?(mime)
        return [0, :rejected_unsupported] unless path.nil? || path.instance_of?(String)
        return [0, :rejected_unsupported] unless data.nil? || data.instance_of?(String)
        return [0, :rejected_unsupported] if attachment && data.nil? && path.nil?

        sizes = values.each_with_object({}) do |(key, value), memo|
          memo[key] = value.bytesize if value.instance_of?(String)
        end
        bytes = RECORD_OVERHEAD_BYTES + values.sum do |key, value|
          sizes.fetch(key) { value.to_s.bytesize }
        end
        [bytes, nil, { values: values, sizes: sizes, attachment: attachment,
                       attachment_values: attachment_values }]
      end

      def valid_optional_string?(value)
        value.nil? || value.instance_of?(String)
      end

      def reserve_and_commit_snapshot(plan, estimate)
        reserved = false
        committed = false
        published = false
        previous_records = @reserved_records
        previous_bytes = @reserved_bytes
        begin
          # Object also covers Thread#kill; preparation itself stays interruptible.
          Thread.handle_interrupt(Object => :never) do
            reserved = true
            @reserved_records += 1
            @reserved_bytes += estimate
          end
          record = snapshot_record(plan, estimate)
          actual = record.accounted_bytes
          raise SnapshotError if actual > estimate || actual > queue_max_bytes

          Thread.handle_interrupt(Object => :never) do
            @accepted_sequence += 1
            record.sequence = @accepted_sequence
            record.freeze
            @records << record
            published = true
            @reserved_bytes -= estimate - actual
            @peak_records = [@peak_records, @reserved_records].max
            @peak_bytes = [@peak_bytes, @reserved_bytes].max
            @counters[:accepted] += 1
            committed = true
            @condition.signal
          end
          true
        rescue SnapshotError
          false
        ensure
          if reserved && !committed
            Thread.handle_interrupt(Object => :never) do
              @records.pop if published
              @reserved_records = previous_records
              @reserved_bytes = previous_bytes
              @condition.broadcast
            end
          end
        end
      end

      def snapshot_record(plan, estimate)
        values = plan.fetch(:values)
        sizes = plan.fetch(:sizes)
        budget = estimate - RECORD_OVERHEAD_BYTES
        detached = {}
        values.each do |key, value|
          if value.instance_of?(String)
            copy, budget = bounded_snapshot(value, sizes.fetch(key), budget)
            raise SnapshotError unless copy
            detached[key] = copy
          else
            detached[key] = value.instance_of?(Time) ? value.dup.freeze : value
          end
        end
        if plan[:attachment] && !attachment_values_match?(plan[:attachment], plan[:attachment_values])
          raise SnapshotError
        end
        normalized_attachment = nil
        if values.key?(:name) || values.key?(:mime) || values.key?(:path) || values.key?(:bytes)
          detached_name = detached[:name]
          detached_mime = detached[:mime]
          normalized_attachment = {
            name: detached_name,
            mime: detached_mime
          }
          normalized_attachment[:path] = detached[:path] if values[:path]
          normalized_attachment[:bytes] = detached[:bytes] if values[:bytes]
          normalized_attachment.freeze
        end
        actual = RECORD_OVERHEAD_BYTES + detached.sum do |key, value|
          value.instance_of?(String) ? value.bytesize : value.to_s.bytesize
        end
        LogRecord.new(
          item_uuid: detached[:item_uuid],
          launch_uuid: detached[:launch_uuid],
          message: detached[:message],
          level: detached[:level],
          timestamp: detached[:timestamp],
          attachment: normalized_attachment,
          accounted_bytes: actual
        )
      end

      def bounded_snapshot(value, expected_size, remaining_budget)
        return [nil, remaining_budget] if expected_size > remaining_budget || value.bytesize != expected_size

        copy = value.byteslice(0, [expected_size, remaining_budget].min)
        return [nil, remaining_budget] unless value.bytesize == expected_size && copy && copy.bytesize == expected_size

        [copy.freeze, remaining_budget - copy.bytesize]
      end

      def attachment_values_match?(attachment, captured)
        current = {
          path: attachment[:path] || attachment["path"] || attachment[:file_path] || attachment["file_path"],
          bytes: attachment[:bytes] || attachment["bytes"],
          name: attachment[:name] || attachment["name"],
          mime: attachment[:mime] || attachment["mime"]
        }
        captured.all? { |key, value| current[key].equal?(value) }
      end

      def capacity_available?(bytes)
        @reserved_records < queue_max_records && @reserved_bytes + bytes <= queue_max_bytes
      end

      def reject(reason)
        warning = @mutex.synchronize { increment_rejection(reason) }
        warn_rejection(warning) if warning
        false
      end

      def increment_rejection(reason)
        @counters[reason] += 1
        return unless @warned_reasons[reason].nil?

        @warned_reasons[reason] = true
        reason
      end

      def warn_rejection(reason)
        ReportportalCucumber.logger.warn("ReportPortal log admission rejected (#{reason.to_s.delete_prefix('rejected_')})")
      rescue StandardError
        nil
      end

      def barrier_receipt(timeout:, deadline: nil, close: false)
        acknowledgement = Queue.new
        cutoff = nil
        request = nil
        already_settled = false
        enqueued = @mutex.synchronize do
          cutoff = @accepted_sequence
          already_settled = cutoff <= @settled_sequence
          if deadline
            @work_deadline = deadline
            @work_deadline_cutoff = cutoff
          end
          request = { acknowledgement: acknowledgement, cutoff: cutoff, from: @settled_sequence,
                      counts: @counters.slice(*zero_outcomes.keys), rejected: rejected_count }
          @closed = true if close
          @condition.broadcast if close
          if cutoff <= @settled_sequence
            acknowledgement << true
            true
          else
            if @worker_failed || !@worker.alive? || @flush_requests.length >= MAX_CONTROL_REQUESTS
              @counters[:control_rejected] += 1
              false
            else
              @flush_requests << request
              # Producers and the worker share this condition; wake the worker
              # rather than relying on ConditionVariable#signal choosing it.
              @condition.broadcast
              true
            end
          end
        end
        remaining = deadline ? deadline.remaining : [timeout.to_f, 0].max
        completed = already_settled || (enqueued && remaining.positive? && (acknowledgement.pop(true) rescue false))
        if enqueued && !completed && remaining.positive?
          completed = Timeout.timeout(remaining) { acknowledgement.pop }
        end
        @mutex.synchronize do
          @flush_requests.delete(request) unless completed
          @counters[:control_timed_out] += 1 if enqueued && !completed && remaining.positive?
          if deadline && @work_deadline.equal?(deadline) && (already_settled || !enqueued)
            @work_deadline = nil
            @work_deadline_cutoff = nil
          end
          request[:counts][:pending] = [cutoff - request[:counts][:settled], 0].max
          build_receipt(cutoff: cutoff, counts: request[:counts], rejected: request[:rejected],
                        capture_close_timeouts: 0, metadata_failures: 0, degraded_evidence: 0,
                        timed_out: !completed, complete: false)
        end
      rescue Timeout::Error
        @mutex.synchronize do
          @flush_requests.delete(request)
          @counters[:control_timed_out] += 1
          request[:counts][:pending] = [cutoff - request[:counts][:settled], 0].max
          build_receipt(cutoff: cutoff, counts: request[:counts], rejected: request[:rejected],
                        capture_close_timeouts: 0, metadata_failures: 0, degraded_evidence: 0,
                        timed_out: true, complete: false)
        end
      end

      def zero_outcomes
        %i[settled confirmed accepted_awaiting_persistence spooled failed ambiguous possible_duplicates]
          .to_h { |key| [key, 0] }
      end

      def rejected_count
        %i[rejected_overflow rejected_admission_timeout rejected_oversized
           rejected_unsupported rejected_closed].sum { |key| @counters[key] }
      end

      def build_receipt(cutoff:, counts:, rejected:, capture_close_timeouts:, metadata_failures:,
                        degraded_evidence:, timed_out:, complete:)
        Service::DeliveryReceipt.new(
          cutoff: cutoff, settled: counts[:settled], confirmed: counts[:confirmed],
          accepted_awaiting_persistence: counts[:accepted_awaiting_persistence],
          spooled: counts[:spooled], failed: counts[:failed],
          ambiguous: counts[:ambiguous], possible_duplicates: counts[:possible_duplicates],
          pending: counts[:pending] || [cutoff - counts[:settled], 0].max,
          rejected: rejected,
          capture_close_timeouts: capture_close_timeouts, metadata_failures: metadata_failures,
          degraded_evidence: degraded_evidence, complete: complete,
          local_settled: counts[:pending].zero? && !timed_out, timed_out: timed_out
        )
      end

      def locally_drained?
        @records.empty? && @in_flight_records.empty? && @reserved_records.zero? && @reserved_bytes.zero?
      end

      def worker_loop
        begin
          loop do
            batch, should_stop = next_work_unit
            break if should_stop
            next if batch.empty?

            begin
              flush_batch(batch)
              release_records(batch)
            rescue Exception => error
              fail_worker(error)
              raise unless error.is_a?(StandardError)
              break
            end
          end
        ensure
          unless @worker_failed || worker_quiescent?
            begin
              fail_worker(ReportportalCucumber::ReportingError.new("Log buffer worker terminated unexpectedly"))
            rescue Exception
              # Do not replace an exception that caused worker termination.
            end
          end
        end
      end

      def worker_quiescent?
        @mutex.synchronize do
          locally_drained? && @flush_requests.empty?
        end
      end

      def release_records(records)
        count = records.length
        bytes = records.sum(&:accounted_bytes)
        @mutex.synchronize do
          Thread.handle_interrupt(Object => :never) do
            @in_flight_records = []
            @in_flight_unsettled = []
            @reserved_records -= count
            @reserved_bytes -= bytes
            @condition.broadcast
          end
        end
      end

      def next_work_unit
        @mutex.synchronize do
          wait_for_work
          wait_for_batch_fill if @records.any? && @flush_requests.empty? && !@closed
          count = [@records.length, batch_size_logs].min
          Thread.handle_interrupt(Object => :never) do
            batch = @records.shift(count)
            @in_flight_records = batch
            @in_flight_unsettled = batch.dup
            drained = batch.empty? && @records.empty? && @in_flight_records.empty? && @reserved_records.zero?
            should_stop = @closed && drained
            [batch, should_stop]
          end
        end
      end

      def wait_for_work
        while @records.empty? && @flush_requests.empty? && !@closed
          @condition.wait(@mutex)
        end
      end

      def wait_for_batch_fill
        deadline = monotonic_now + @config.flush_interval
        while @records.length < batch_size_logs && @flush_requests.empty? && !@closed
          remaining = deadline - monotonic_now
          break if remaining <= 0

          @condition.wait(@mutex, remaining)
        end
      end

      def flush_batch(records)
        unsettled = records.dup
        routed = route_external_video_records(records)
        chunk = []
        routed.each do |record|
          candidate = chunk + [record]
          payload = build_payload(candidate)
          size = Transport::MultipartHelper.log_batch_bytes(entries: payload.fetch(:entries), files: payload.fetch(:files))
          if size <= batch_max_bytes
            chunk = candidate
            next
          end

          unless chunk.empty?
            send_chunk(chunk)
            sent_sequences = chunk.map(&:sequence)
            unsettled.reject! { |record| sent_sequences.include?(record.sequence) }
          end
          chunk = []
          single = build_payload([record])
          single_size = Transport::MultipartHelper.log_batch_bytes(entries: single.fetch(:entries), files: single.fetch(:files))
          if single_size > batch_max_bytes
            warn_diagnostic_once(:oversized_wire, "ReportPortal log exceeded the request byte limit; preserved in local spool best-effort")
            error = Transport::MultipartHelper::SizeLimitError.new
            spooled = safe_spool([record], error, outcome: :failed)
            record_delivery([record], [:failed], spooled_indexes: spooled ? [0] : [])
            unsettled.delete(record)
          else
            chunk = [record]
          end
        end
        unless chunk.empty?
          send_chunk(chunk)
          sent_sequences = chunk.map(&:sequence)
          unsettled.reject! { |record| sent_sequences.include?(record.sequence) }
        end
      rescue StandardError => error
        unless unsettled.empty?
          spooled = safe_spool(unsettled, error)
          record_delivery(unsettled, Array.new(unsettled.length, :ambiguous),
                          spooled_indexes: spooled ? (0...unsettled.length).to_a : [])
        end
        mark_diagnostic(:delivery_failed)
        handle_error(error)
      end

      def build_payload(records)
        Service::PayloadBuilder.build_log_batch(records)
      end

      def method_accepts_deadline?(method)
        method.parameters.any? { |kind, name| kind == :key && name == :deadline }
      end

      def send_chunk(records)
        payload = build_payload(records)
        deadline = @mutex.synchronize { @work_deadline }
        result = begin
          use_result_api = @api.respond_to?(:log_batch_result) &&
                           (@api.is_a?(ReportPortal::API) || !@api.respond_to?(:log_batch))
          if use_result_api
            if deadline && method_accepts_deadline?(@api.method(:log_batch_result))
              @api.log_batch_result(entries: payload.fetch(:entries), files: payload.fetch(:files), deadline: deadline)
            else
              @api.log_batch_result(entries: payload.fetch(:entries), files: payload.fetch(:files))
            end
          elsif deadline
            if method_accepts_deadline?(@api.method(:log_batch))
              @api.log_batch(entries: payload.fetch(:entries), files: payload.fetch(:files), deadline: deadline)
            else
              @api.log_batch(entries: payload.fetch(:entries), files: payload.fetch(:files))
            end
          else
            @api.log_batch(entries: payload.fetch(:entries), files: payload.fetch(:files))
          end
        rescue StandardError => error
          response = error.respond_to?(:response) ? error.response : nil
          rejected_status = response && response.status >= 400 && response.status < 500 && ![408, 429].include?(response.status)
          category = error.is_a?(Transport::MultipartHelper::SizeLimitError) || rejected_status ? :failed : :ambiguous
          spooled = safe_spool(records, error, outcome: category)
          record_delivery(records, Array.new(records.length, category),
                          spooled_indexes: spooled ? (0...records.length).to_a : [])
          if error.is_a?(Transport::MultipartHelper::SizeLimitError)
            warn_diagnostic_once(:oversized_wire, "ReportPortal log exceeded the request byte limit; preserved in local spool best-effort")
          else
            mark_diagnostic(:delivery_failed)
          end
          handle_error(error)
          return
        end

        response = result.respond_to?(:body) ? result.body : result
        may_duplicate = result.respond_to?(:may_duplicate) && result.may_duplicate
        outcomes = Service::LogResponseParser.outcomes(body: response, entries: payload.fetch(:entries))
        spooled = []
        %i[failed ambiguous].each do |category|
          indexes = outcomes.each_index.select { |index| outcomes[index] == category }
          next if indexes.empty?

          success = safe_spool(indexes.map { |index| records[index] },
                               ReportingError.new("Log acknowledgement incomplete"), outcome: category)
          spooled.concat(indexes) if success
        end
        duplicate_indexes = may_duplicate ? (0...records.length).to_a : []
        record_delivery(records, outcomes, spooled_indexes: spooled,
                        possible_duplicate_indexes: duplicate_indexes)
        mark_diagnostic(:sent_batches)
      end

      def default_video_uploader
        return nil unless @config.minio_markdown_video?

        Transport::MinioUploader.new(config: @config)
      end

      def route_external_video_records(records)
        return records unless @video_uploader

        records.map do |record|
          attachment = Service::PayloadBuilder.normalize_attachment(record.attachment)
          next record unless Service::PayloadBuilder.video_attachment?(attachment)

          public_url = @video_uploader.upload_video(path: attachment[:path], bytes: attachment[:bytes],
                                                   name: attachment.fetch(:name), content_type: attachment.fetch(:mime))
          message = if video_upload_url?(public_url)
                      Service::PayloadBuilder.build_video_markdown_message(message: record.message, url: public_url)
                    else
                      mark_diagnostic(:degraded_evidence)
                      [record.message, public_url.to_s].reject(&:empty?).join("\n\n")
                    end
          LogRecord.new(item_uuid: record.item_uuid, launch_uuid: record.launch_uuid, message: message,
                        level: :error, timestamp: record.timestamp, attachment: nil,
                        accounted_bytes: record.accounted_bytes, sequence: record.sequence).freeze
        end
      end

      def video_upload_url?(value)
        value.to_s.match?(%r{\Ahttps?://})
      end

      def safe_spool(records, error, outcome: :ambiguous)
        deadline = @mutex.synchronize { @work_deadline }
        return false if deadline&.expired?

        spool(records, error, outcome: outcome)
        true
      rescue Service::SpoolStore::Error => spool_error
        warn_spool_failure(spool_error.reason)
        false
      rescue StandardError => builder_error
        begin
          raw_spool(records, error, builder_error, File.expand_path(@config.spool_dir, Dir.pwd), outcome)
          true
        rescue StandardError
          warn_spool_failure(:persistence_failed)
          false
        end
      end

      def warn_spool_failure(reason)
        label = SPOOL_WARNING_REASONS.include?(reason) ? reason : :store_error
        warn_diagnostic_once(:spool_failed,
                             "ReportPortal durable log retention failed (#{label}); reporting remains incomplete")
      end

      def record_delivery(records, outcomes, spooled_indexes: [], possible_duplicate_indexes: [])
        @mutex.synchronize do
          records.each_with_index do |record, index|
            outcome = outcomes[index] || :ambiguous
            outcome = :accepted_awaiting_persistence if outcome == :confirmed && @config.respond_to?(:reporting_async?) && @config.reporting_async?
            @counters[outcome] += 1 if @counters.key?(outcome)
            spooled = spooled_indexes.include?(index)
            @counters[:spooled] += 1 if spooled
            possible_duplicate = possible_duplicate_indexes.include?(index)
            @counters[:possible_duplicates] += 1 if possible_duplicate
            @counters[:settled] += 1
            @in_flight_unsettled.reject! { |pending| pending.sequence == record.sequence }
            @settled_sequence = [@settled_sequence, record.sequence || 0].max
            @flush_requests.each do |request|
              next unless record.sequence && record.sequence <= request[:cutoff] && record.sequence > request[:from]

              request[:counts][:settled] += 1
              request[:counts][outcome] += 1 if request[:counts].key?(outcome)
              request[:counts][:spooled] += 1 if spooled
              request[:counts][:possible_duplicates] += 1 if possible_duplicate
            end
          end
          finished = @flush_requests.select { |request| request[:counts][:settled] >= request[:cutoff] }
          finished.each do |request|
            @flush_requests.delete(request)
            request[:acknowledgement] << true
          end
          if @work_deadline_cutoff && @settled_sequence >= @work_deadline_cutoff
            @work_deadline = nil
            @work_deadline_cutoff = nil
          end
          @condition.broadcast
        end
      end

      def spool(records, error, outcome: :ambiguous)
        payload = build_payload(records)
        deadline = @mutex.synchronize { @work_deadline }
        @spool_store.persist(entries: payload.fetch(:entries), files: payload.fetch(:files), outcome: outcome,
                             diagnostics: { spoolError: safe_exception_text(error) }, deadline: deadline)
      end

      def raw_spool(records, original_error, spool_error, directory, outcome = :ambiguous)
        entries = []
        files = []
        used_names = Hash.new(0)
        records.each_with_index do |record, index|
          attachment = normalize_raw_attachment(record.attachment)
          filename = attachment && Service::PayloadBuilder.unique_filename(attachment.fetch(:name), used_names)
          raw_entry = Service::PayloadBuilder.build_log_entry(
            launch_uuid: record.launch_uuid, item_uuid: record.item_uuid, time: record.timestamp,
            message: record.message,
            level: record.level, file_name: filename
          )
          raw_entry["time"] = raw_time(record.timestamp)
          entries << raw_entry
          next unless attachment

          file = { name: filename, mime: attachment.fetch(:mime), entry_index: index }
          file[attachment.key?(:path) ? :path : :bytes] = attachment.fetch(attachment.key?(:path) ? :path : :bytes)
          files << file
        end
        deadline = @mutex.synchronize { @work_deadline }
        @spool_store.persist(entries: entries, files: files, outcome: outcome,
                             diagnostics: { rawSpool: true, spoolError: safe_exception_summary(original_error),
                                            fallbackSpoolError: safe_exception_summary(spool_error) },
                             deadline: deadline)
      end

      def normalize_raw_attachment(attachment)
        return Service::PayloadBuilder.normalize_attachment(attachment) unless attachment && attachment[:path]

        # Preserve the admitted path descriptor; Store owns safe copying and
        # explicit unavailable markers when the source disappears after send.
        path = attachment.fetch(:path)
        name = Transport::MultipartHelper.safe_filename(attachment[:name] || File.basename(path))
        mime = Transport::MultipartHelper.content_type_for(
          filename: Service::PayloadBuilder.mime_detection_filename(name: name, path: path),
          declared_type: attachment[:mime]
        )
        name = Transport::MultipartHelper.ensure_filename_extension(
          name: name, content_type: mime, fallback: Service::PayloadBuilder.default_attachment_name(mime)
        )
        { name: name, mime: mime, path: path }
      end

      def raw_record(record)
        { "itemUuid" => record.item_uuid, "launchUuid" => record.launch_uuid,
          "message" => record.message, "level" => record.level.to_s, "time" => raw_time(record.timestamp) }.compact
      end

      def raw_time(value)
        return (value.to_r * 1000).to_i.to_s if value.is_a?(Time)
        return value.to_i.to_s if value.is_a?(Float)

        value.to_s
      end

      def safe_exception_text(error)
        Service::EvidencePresenter.sanitize_diagnostic(error.message, limit: 2048)
      end

      def safe_exception_summary(error)
        klass = Service::EvidencePresenter.sanitize_diagnostic(error.class.name, limit: 256)
        "#{klass}: #{safe_exception_text(error)}"
      end

      def spool_unflushed(message)
        records = @mutex.synchronize { @in_flight_unsettled + @records }
        records.each_slice(batch_size_logs) do |bounded_records|
          safe_spool(bounded_records, ReportportalCucumber::ReportingError.new(message))
        end unless records.empty?
      end

      def fail_worker(error)
        pending = nil
        charged = nil
        begin
          @mutex.synchronize do
            Thread.handle_interrupt(Object => :never) do
              return if @worker_failed

              pending = @in_flight_unsettled.dup + @records
              charged = @in_flight_records.dup + @records
              @worker_failed = true
              @closed = true
              @records.clear
              @counters[:worker_failed] += 1
              @condition.broadcast
            end
          end
          pending.each_slice(batch_size_logs) do |bounded_records|
            spooled = safe_spool(bounded_records, error)
            record_delivery(bounded_records, Array.new(bounded_records.length, :ambiguous),
                            spooled_indexes: spooled ? (0...bounded_records.length).to_a : [])
          end unless pending.empty?
        ensure
          release_records(charged) if charged
        end
        handle_error(error)
      rescue StandardError
        nil
      end

      def mark_diagnostic(key)
        @mutex.synchronize { @counters[key] += 1 }
      end

      def warn_diagnostic_once(key, message)
        emit = @mutex.synchronize do
          @counters[key] += 1
          next false if @warned_reasons[key]

          @warned_reasons[key] = true
        end
        ReportportalCucumber.logger.warn(message) if emit
      rescue StandardError
        nil
      end

      def handle_error(error)
        @on_error&.call(error)
      rescue StandardError
        raise if @config.fail_on_reporting_error?
      end

      def queue_max_records
        @config.respond_to?(:queue_max_records) ? @config.queue_max_records : 1000
      end

      def queue_max_bytes
        @config.respond_to?(:queue_max_bytes) ? @config.queue_max_bytes : 16 * 1024 * 1024
      end

      def queue_overflow_policy
        @config.respond_to?(:queue_overflow_policy) ? @config.queue_overflow_policy : "reject_new"
      end

      def queue_admission_timeout_ms
        @config.respond_to?(:queue_admission_timeout_ms) ? @config.queue_admission_timeout_ms : 100
      end

      def batch_size_logs
        @config.batch_size_logs
      end

      def batch_max_bytes
        @config.respond_to?(:batch_max_bytes) ? @config.batch_max_bytes : 8 * 1024 * 1024
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
