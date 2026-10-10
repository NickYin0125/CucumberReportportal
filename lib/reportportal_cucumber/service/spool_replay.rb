# frozen_string_literal: true

require "timeout"

module ReportportalCucumber
  module Service
    # Replays one validated transaction while preserving its original RP ownership.
    class SpoolReplay
      MAX_SUMMARY_ENTRIES = 1_000
      WIRE_ENTRY_FIELDS = %w[launchUuid itemUuid time message level].freeze

      # @param store [ReportportalCucumber::Service::SpoolStore]
      # @param config [ReportportalCucumber::Config]
      # @param api [ReportportalCucumber::ReportPortal::API, nil]
      def initialize(store:, config:, api: nil)
        @store = store
        @config = config
        @api = api
      end

      # @param transaction_id [String]
      # @param execute [Boolean]
      # @param allow_duplicates [Boolean]
      # @param timeout [Numeric]
      # @return [Hash]
      def run(transaction_id:, execute: false, allow_duplicates: false, timeout: 30.0)
        unless timeout.is_a?(Numeric) && timeout.to_f.finite? && timeout.to_f >= 0
          raise ArgumentError, "Replay timeout must be finite and non-negative"
        end
        deadline = ReportingDeadline.new(timeout: timeout)
        transaction = load_transaction_with_deadline(transaction_id, deadline)
        manifest = fetch(transaction, :manifest)
        entries = Array(fetch(transaction, :entries))
        raise ReportingError, "Transaction has too many entries" if entries.length > MAX_SUMMARY_ENTRIES
        checkpoint = fetch(transaction, :checkpoint)
        states = checkpoint_states(checkpoint, entries.length)
        ensure_deadline!(deadline)

        return summarize(transaction_id, states, dry_run: true, files: fetch(transaction, :files)) unless execute

        result = nil
        @store.with_transaction(id: transaction_id, deadline: deadline) do |locked|
          tx = locked || @store.load_transaction(id: transaction_id)
          tx_entries = Array(fetch(tx, :entries))
          tx_manifest = fetch(tx, :manifest)
          tx_states = checkpoint_states(fetch(tx, :checkpoint), tx_entries.length)
          ensure_deadline!(deadline)
          eligible = eligible_indices(tx_states, allow_duplicates)
          if eligible.empty?
            result = summarize(transaction_id, tx_states, dry_run: false)
            next
          end

          raise ReportingError, "Async v2 replay is not supported" if @config.reporting_async?
          raise ReportingError, "ReportPortal credentials are required for execution" if @config.api_key.to_s.empty?

          assert_binding!(tx_manifest)
          eligible_entries = eligible.map { |index| tx_entries.fetch(index) }
          validate_entries!(eligible_entries)
          targets = verify_targets!(eligible_entries, deadline)
          wire_entries = tx_entries.map { |entry| canonical_wire_entry(entry) }
          file_sets = eligible.to_h do |index|
            entry = wire_entries.fetch(index)
            files = attachment_for(tx, entry, index)
            validate_wire_size!(entry, files)
            [index, files]
          end
          result = replay_entries(transaction_id, wire_entries, tx_states, targets, file_sets,
                                  allow_duplicates: allow_duplicates, deadline: deadline)
        end
        result
      end

      private

      def load_transaction_with_deadline(transaction_id, deadline)
        ensure_deadline!(deadline)
        remaining = deadline.remaining
        transaction = Timeout.timeout(remaining) do
          @store.load_transaction(id: transaction_id)
        end
        ensure_deadline!(deadline)
        transaction
      rescue StandardError
        raise ReportingError, "Replay deadline expired during transaction validation" if deadline.expired?

        raise
      end

      def ensure_deadline!(deadline)
        raise ReportingError, "Replay deadline expired during transaction validation" if deadline.expired?
      end

      def eligible_indices(states, allow_duplicates)
        states.each_index.select do |index|
          state = state_name(states[index])
          %w[pending failed].include?(state) ||
            (allow_duplicates && %w[in_flight ambiguous].include?(state))
        end
      end

      def replay_entries(transaction_id, entries, states, targets, file_sets, allow_duplicates:, deadline:)
        entries.each_with_index do |entry, index|
          state = state_name(states[index])
          next if state == "confirmed"

          if %w[in_flight ambiguous].include?(state)
            next unless allow_duplicates
          elsif !%w[pending failed].include?(state)
            next
          end

          break if deadline.remaining <= 0

          persist_state!(transaction_id, states, index, "in_flight", deadline)
          extra = {}
          begin
            launch_uuid = value(entry, "launchUuid")
            item_uuid = value(entry, "itemUuid")
            raise ReportingError, "Original target is not open" unless targets.fetch(launch_uuid) &&
                                                                       (item_uuid.nil? || targets.fetch(item_uuid))

            response = api.log_batch_result(entries: [entry], files: file_sets.fetch(index), deadline: deadline)
            outcomes = LogResponseParser.outcomes(body: response.body, entries: [entry])
            if outcomes == [:confirmed]
              next_state = "confirmed"
              extra = { "id" => ack_id(response.body) }
            elsif outcomes == [:failed]
              next_state = "failed"
            else
              next_state = "ambiguous"
            end
          rescue StandardError => error
            next_state = definitive_http_failure?(error) ? "failed" : "ambiguous"
          end

          begin
            persist_state!(transaction_id, states, index, next_state, deadline, extra)
          rescue StandardError
            # The durable in-flight state remains uncertain; do not attempt another checkpoint or POST.
            break
          end
          break if next_state == "ambiguous"
        end
        summarize(transaction_id, states, dry_run: false)
      end

      def verify_targets!(entries, deadline)
        uuids = entries.flat_map { |entry| [value(entry, "launchUuid"), value(entry, "itemUuid")] }
                       .compact.uniq
        statuses = {}
        uuids.each do |uuid|
          launch = entries.any? { |entry| value(entry, "launchUuid") == uuid }
          target = launch ? api.launch_by_uuid(uuid: uuid, deadline: deadline) : api.item_by_uuid(uuid: uuid, deadline: deadline)
          raise ReportingError, "Original target was not found" unless target.is_a?(Hash)
          status = target["status"] || target["state"]
          raise ReportingError, "Original target is not open" unless status.to_s.upcase == "IN_PROGRESS"

          statuses[uuid] = true
        end
        statuses
      end

      def validate_entries!(entries)
        raise ReportingError, "Transaction contains no replayable entries" if entries.empty?
        entries.each do |entry|
          unless entry.is_a?(Hash) && value(entry, "launchUuid").is_a?(String) &&
                 (value(entry, "itemUuid").nil? || value(entry, "itemUuid").is_a?(String)) && value(entry, "time") &&
                 value(entry, "message").is_a?(String) && value(entry, "level")
            raise ReportingError, "Transaction entry schema is not replayable"
          end
        end
      end

      def attachment_for(transaction, entry, index)
        descriptor = value(entry, "file")
        return [] unless descriptor

        name = descriptor.is_a?(Hash) ? (descriptor["name"] || descriptor[:name]) : nil
        files = Array(fetch(transaction, :files))
        file = files.find do |candidate|
          value(candidate, "name") == name && value(candidate, "entry_index") == index
        end
        raise ReportingError, "Transaction attachment is unavailable" unless file
        raise ReportingError, "Transaction attachment is unavailable" if value(file, "unavailable")
        path = value(file, "path")
        mime = value(file, "mime")
        directory = fetch(transaction, :directory)
        unless path.is_a?(String) && mime.is_a?(String) && directory.is_a?(String) && safe_file?(path, directory)
          raise ReportingError, "Transaction attachment path is unsafe"
        end

        [{ name: name, mime: mime, path: path }]
      end

      def canonical_wire_entry(entry)
        result = WIRE_ENTRY_FIELDS.each_with_object({}) do |key, wire|
          candidate = value(entry, key)
          wire[key] = candidate unless candidate.nil?
        end
        if (descriptor = value(entry, "file"))
          name = descriptor.is_a?(Hash) ? (descriptor["name"] || descriptor[:name]) : nil
          raise ReportingError, "Transaction attachment is unavailable" unless name.is_a?(String)

          result["file"] = { "name" => name }
        end
        result
      end

      def validate_wire_size!(entry, files)
        bytes = Transport::MultipartHelper.log_batch_bytes(entries: [entry], files: files)
        raise ReportingError, "Transaction entry exceeds the configured request limit" if bytes > @config.batch_max_bytes
      end

      def safe_file?(path, directory)
        return false if File.symlink?(path)

        expanded_dir = File.realpath(directory)
        expanded_path = File.realpath(path)
        expanded_path.start_with?(expanded_dir + File::SEPARATOR) && File.file?(expanded_path)
      rescue SystemCallError
        false
      end

      def assert_binding!(manifest)
        target = value(manifest, "target")
        endpoint = value(target, "endpoint")
        project = value(target, "project")
        unless endpoint.is_a?(String) && normalize_endpoint(endpoint) == normalize_endpoint(@config.endpoint) &&
               project == @config.project
          raise ReportingError, "Configured endpoint/project does not match the selected transaction"
        end
      end

      def normalize_endpoint(endpoint)
        uri = URI.parse(endpoint)
        raise ArgumentError unless uri.is_a?(URI::HTTP) && uri.host

        uri.normalize.to_s.sub(%r{/+\z}, "")
      rescue URI::InvalidURIError, ArgumentError
        ""
      end

      def checkpoint_states(checkpoint, count)
        raw = fetch(checkpoint, :entries) || fetch(checkpoint, :states)
        raise ReportingError, "Transaction checkpoint schema is invalid" unless raw.is_a?(Array) && raw.length == count

        raw.map do |state|
          normalized = state.is_a?(Hash) ? state.dup : { "state" => state.to_s }
          raise ReportingError, "Transaction checkpoint schema is invalid" unless
            %w[pending in_flight confirmed ambiguous failed].include?(state_name(normalized))

          normalized
        end
      end

      def persist_state!(transaction_id, states, index, state, deadline, extra = {})
        updated = states.map(&:dup)
        updated[index] = { "state" => state }.merge(extra)
        @store.update_checkpoint(id: transaction_id, states: updated, deadline: deadline)
        states[index] = updated[index]
      end

      def state_name(state)
        (state["state"] || state[:state]).to_s
      end

      def ack_id(body)
        return body["id"] if body.is_a?(Hash) && body["id"].is_a?(String)
        responses = body.is_a?(Hash) && body["responses"]
        responses&.first&.fetch("id", nil) if responses.is_a?(Array) && responses.first.is_a?(Hash)
      end

      def summarize(id, states, dry_run:, files: [])
        counts = states.each_with_object(Hash.new(0)) { |entry, memo| memo[state_name(entry).to_sym] += 1 }
        summary = {
          transaction: id,
          dry_run: dry_run,
          async_v2: @config.reporting_async?,
          confirmed: counts[:confirmed],
          ambiguous: counts[:ambiguous] + counts[:in_flight],
          failed: counts[:failed],
          pending: counts[:pending],
          retained: counts.values_at(:pending, :ambiguous, :in_flight, :failed).sum.positive?
        }
        if dry_run
          unavailable = Array(files).take(MAX_SUMMARY_ENTRIES).count { |file| value(file, "unavailable") == true }
          summary[:unavailable_artifacts] = unavailable
          summary[:unavailable_artifact_reasons] = (unavailable.positive? ? ["source_unavailable"] : []).freeze
        end
        summary.freeze
      end

      def definitive_http_failure?(error)
        response = error.respond_to?(:response) ? error.response : nil
        response && response.status >= 400 && response.status < 500 && ![408, 429].include?(response.status)
      end

      def api
        return @api if @api

        replay_config = Config.new(
          endpoint: @config.endpoint, project: @config.project, api_key: @config.api_key,
          reporting_async: false, retry_attempts: 1, open_timeout: @config.open_timeout,
          read_timeout: @config.read_timeout, write_timeout: @config.write_timeout,
          batch_size_logs: @config.batch_size_logs, batch_max_bytes: @config.batch_max_bytes,
          debug_curl_mode: false
        )
        @api = ReportPortal::API.new(config: replay_config)
      end

      def fetch(hash, key)
        return nil unless hash.respond_to?(:key?)

        [key, key.to_s, key.to_s.to_sym].uniq.each do |candidate|
          return hash[candidate] if hash.key?(candidate)
        end
        nil
      end

      def value(hash, key)
        fetch(hash, key)
      end
    end
  end
end
