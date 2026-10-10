# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "securerandom"
require "time"
require "uri"

module ReportportalCucumber
  module Service
    # Private, quota-bounded transaction store for failed ReportPortal logs.
    class SpoolStore
      VERSION = 1
      DEFAULT_MAX_BYTES = 268_435_456
      COPY_CHUNK_BYTES = 64 * 1024
      MAX_ENTRIES = 1_000
      MAX_ENTRY_BYTES = 16 * 1024 * 1024
      MAX_ENTRIES_BYTES = 32 * 1024 * 1024
      MAX_METADATA_BYTES = 1024 * 1024
      INTERNAL_FIELDS = %w[spoolError fallbackSpoolError rawSpool deliveryOutcome attachment].freeze
      WIRE_FIELDS = %w[launchUuid itemUuid time message level file].freeze
      STATES = %w[pending in_flight confirmed ambiguous failed].freeze
      ID_PATTERN = /\Atx-[0-9a-f]{32}\z/.freeze

      class Error < ReportportalCucumber::ReportingError
        attr_reader :reason

        # @param reason [Symbol]
        # @param message [String]
        def initialize(reason, message = "Spool transaction unavailable")
          @reason = reason
          super(message)
        end
      end

      # @param config [ReportportalCucumber::Config]
      def initialize(config:)
        @config = config
        @root = File.expand_path(config.spool_dir, Dir.pwd)
        @max_bytes = config.respond_to?(:spool_max_bytes) ? config.spool_max_bytes : DEFAULT_MAX_BYTES
        @thread_lock_key = "rp_spool_store_lock_#{object_id}".to_sym
      end

      # Persist a complete private transaction and return its ID after publication.
      # @param entries [Array<Hash>] Canonical ReportPortal wire entries.
      # @param files [Array<Hash>] Attachment parts with name, mime, and path or bytes.
      # @param outcome [String, Symbol] Delivery classification for this transaction.
      # @param diagnostics [Hash] Small sanitized local-only diagnostics.
      # @param deadline [ReportingDeadline, nil]
      # @return [String] Published transaction ID.
      def persist(entries:, files:, outcome:, diagnostics: {}, deadline: nil)
        deadline ||= default_deadline
        check_deadline!(deadline)
        outcome = outcome.to_s
        raise Error.new(:invalid_outcome) unless %w[ambiguous failed].include?(outcome)
        normalized_entries = validate_entries(entries)
        normalized_files = validate_files(files, normalized_entries)
        normalized_diagnostics = sanitize_diagnostics(diagnostics, outcome)
        ensure_root!
        id = "tx-#{SecureRandom.hex(16)}"
        stage = File.join(@root, ".staging-#{id}")
        directory = transaction_directory(id)
        published = false

        with_quota_lock(deadline) do
          check_deadline!(deadline)
          raise Error.new(:id_collision) if File.exist?(stage) || File.exist?(directory) || File.exist?(marker_path(id))

          Dir.mkdir(stage, 0o700)
          File.chmod(0o700, stage)
          sync_directory(@root)
        end
        attachments_dir = File.join(stage, ".attachments-data")
        Dir.mkdir(attachments_dir, 0o700) unless normalized_files.empty?

        stored_files = persist_attachments(normalized_files, normalized_entries, attachments_dir, deadline)
        entries_content = encode_entries(normalized_entries, normalized_diagnostics, stored_files, id)
        entries_path = File.join(stage, ".entries.ndjson")
        write_quota_file(entries_path, entries_content, deadline)
        entries_digest = digest_file(entries_path, deadline)
        checkpoint = initial_checkpoint(id, entries_digest.fetch("sha256"), normalized_entries.length,
                                        normalized_diagnostics)
        checkpoint_path = File.join(stage, ".checkpoint.json")
        write_json_file(checkpoint_path, checkpoint, deadline)
        manifest = build_manifest(id, normalized_diagnostics, normalized_entries.length,
                                  entries_digest, stored_files)
        manifest_bytes = JSON.generate(manifest)
        raise Error.new(:metadata_limit) if manifest_bytes.bytesize > MAX_METADATA_BYTES

        write_quota_file(File.join(stage, ".manifest.json"), manifest_bytes, deadline)
        sync_directory(attachments_dir) if File.directory?(attachments_dir)
        sync_directory(stage)

        with_quota_lock(deadline) do
          check_deadline!(deadline)
          raise Error.new(:quota_exceeded) if usage_bytes > @max_bytes

          File.rename(stage, directory)
          sync_directory(@root)
          begin
            File.link(File.join(directory, ".entries.ndjson"), marker_path(id))
            begin
              sync_directory(@root)
            rescue StandardError
              File.unlink(marker_path(id)) rescue nil
              sync_directory(@root) rescue nil
              raise
            end
            published = true
          rescue SystemCallError => error
            File.unlink(marker_path(id)) if File.file?(marker_path(id))
            sync_directory(@root)
            raise Error.new(:publish_failed, safe_io_message(error))
          end
        end
        id
      rescue Error
        cleanup_unpublished(stage, directory, id, published, deadline)
        raise
      rescue StandardError => error
        cleanup_unpublished(stage, directory, id, published, deadline)
        raise Error.new(:persistence_failed, safe_io_message(error))
      end

      # Return only IDs whose atomic publication marker and versioned directory agree.
      # @return [Array<String>]
      def transactions
        return [].freeze unless File.exist?(@root) || File.symlink?(@root)

        ensure_root!(create: false)
        Dir.children(@root).filter_map do |name|
          next unless name.match?(/\A#{Regexp.escape("tx-")}([0-9a-f]{32})\.ndjson\z/)

          id = name.delete_suffix(".ndjson")
          load_transaction(id: id)
          id
        rescue Error, SystemCallError, JSON::ParserError
          nil
        end.sort.freeze
      end

      # Load and validate one published transaction without taking its replay lock.
      # @param id [String]
      # @return [Hash] Frozen manifest, normalized checkpoint, canonical entries, files, and directory.
      def load_transaction(id:)
        validate_id!(id)
        ensure_root!(create: false)
        directory = transaction_directory(id)
        marker = marker_path(id)
        ensure_regular_file!(marker)
        ensure_directory!(directory)
        ensure_marker_matches!(marker, File.join(directory, ".entries.ndjson"))
        manifest = read_json_file(safe_child(directory, ".manifest.json"), MAX_METADATA_BYTES)
        validate_manifest!(manifest, id)
        entries_path = safe_child(directory, manifest.fetch("entries").fetch("path"))
        entries_bytes = read_bounded_file(entries_path, MAX_ENTRIES_BYTES)
        entry_meta = manifest.fetch("entries")
        unless entries_bytes.bytesize == entry_meta.fetch("length") && Digest::SHA256.hexdigest(entries_bytes) == entry_meta.fetch("sha256")
          raise Error.new(:corrupt_entries)
        end
        entries = decode_entries(entries_bytes, manifest.fetch("files"))
        raise Error.new(:invalid_entries) unless entries.length == entry_meta.fetch("count")
        checkpoint = read_checkpoint(directory, entries.length, id: id,
                                     entries_sha256: entry_meta.fetch("sha256"))
        files = load_files(directory, manifest.fetch("files"), entries)
        deep_freeze({ id: id.freeze, manifest: manifest, checkpoint: checkpoint,
                      entries: entries, files: files, directory: directory.freeze })
      rescue Error
        raise
      rescue StandardError => error
        raise Error.new(:invalid_transaction, safe_io_message(error))
      end

      # Hold the selected transaction's exclusive lock across the caller's replay operation.
      # @param id [String]
      # @param deadline [ReportingDeadline, nil]
      # @yield [transaction] Validated transaction hash.
      # @return [Object] Block result.
      def with_transaction(id:, deadline: nil)
        deadline ||= default_deadline
        validate_id!(id)
        raise Error.new(:nested_transaction_lock) if Thread.current[@thread_lock_key]
        ensure_root!(create: false)
        ensure_directory!(transaction_directory(id))
        transaction_lock = safe_child(transaction_directory(id), ".replay.lock")
        ensure_regular_or_absent!(transaction_lock)
        lock_flags = File::RDWR | File::CREAT
        lock_flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
        File.open(transaction_lock, lock_flags, 0o600) do |lock|
          File.chmod(0o600, transaction_lock)
          acquire_lock!(lock, deadline)
          previous = nil
          transaction = load_transaction(id: id)
          context = { id: id, directory: transaction.fetch(:directory),
                      entry_count: transaction.fetch(:entries).length,
                      entries_sha256: transaction.fetch(:manifest).fetch("entries").fetch("sha256"),
                      checkpoint: transaction.fetch(:checkpoint) }
          Thread.current[@thread_lock_key] = context
          yield transaction
        ensure
          Thread.current[@thread_lock_key] = previous
          lock.flock(File::LOCK_UN) rescue nil
        end
      rescue Error
        raise
      rescue StandardError => error
        raise Error.new(:transaction_lock_failed, safe_io_message(error))
      end

      # Atomically replace a complete checkpoint after validating every entry state.
      # @param id [String]
      # @param states [Array<Hash>] Full state array, one object per canonical entry.
      # @param deadline [ReportingDeadline, nil]
      # @return [Hash] Frozen committed checkpoint.
      def update_checkpoint(id:, states:, deadline: nil)
        deadline ||= default_deadline
        validate_id!(id)
        context = Thread.current[@thread_lock_key]
        if context && context.fetch(:id) == id
          updated = update_checkpoint_locked(id, states, deadline, context: context,
                                             prior: context.fetch(:checkpoint))
          context[:checkpoint] = updated
          return updated
        end

        with_transaction(id: id, deadline: deadline) do |transaction|
          context = Thread.current[@thread_lock_key]
          updated = update_checkpoint_locked(id, states, deadline, context: context,
                                             prior: transaction.fetch(:checkpoint))
          context[:checkpoint] = updated
          updated
        end
      end

      private

      def update_checkpoint_locked(id, states, deadline, context:, prior: nil)
        manifest = read_json_file(safe_child(context.fetch(:directory), ".manifest.json"), MAX_METADATA_BYTES)
        validate_manifest!(manifest, id)
        identity = { id: id, entries_sha256: manifest.fetch("entries").fetch("sha256") }
        previous = prior || read_checkpoint(context.fetch(:directory), context.fetch(:entry_count), **identity)
        previous_states = previous.fetch("states")
        normalized = validate_states(states, context.fetch(:entry_count))
        previous_states.each_with_index do |previous, index|
          next unless previous.fetch("state") == "confirmed"
          current = normalized[index]
          raise Error.new(:checkpoint_regression) unless current.fetch("state") == "confirmed" &&
                                                         current.fetch("id") == previous.fetch("id")
        end
        normalized.each do |state|
          raise Error.new(:invalid_checkpoint) if state.fetch("state") == "confirmed" && state.fetch("id", "").empty?
        end
        value = { "version" => VERSION, "transactionId" => id,
                  "entriesSha256" => identity.fetch(:entries_sha256), "states" => normalized,
                  "updatedAt" => Time.now.utc.iso8601(6) }
        bytes = JSON.generate(value)
        raise Error.new(:metadata_limit) if bytes.bytesize > MAX_METADATA_BYTES
        destination = safe_child(context.fetch(:directory), ".checkpoint.json")
        temporary = safe_child(context.fetch(:directory), ".checkpoint-#{SecureRandom.hex(8)}.tmp")
        write_quota_file(temporary, bytes, deadline)
        with_quota_lock(deadline) do
          check_deadline!(deadline)
          raise Error.new(:quota_exceeded) if usage_bytes > @max_bytes
          File.rename(temporary, destination)
          sync_directory(context.fetch(:directory))
        end
        deep_freeze(value)
      rescue Error
        remove_file_best_effort(temporary) if temporary
        raise
      rescue StandardError => error
        remove_file_best_effort(temporary) if temporary
        raise Error.new(:checkpoint_failed, safe_io_message(error))
      end

      def initial_checkpoint(id, entries_sha256, entry_count, diagnostics)
        initial_state = diagnostics.fetch("deliveryOutcome") == "ambiguous" ? "ambiguous" : "pending"
        { "version" => VERSION, "transactionId" => id, "entriesSha256" => entries_sha256,
          "states" => Array.new(entry_count) { { "state" => initial_state } },
          "updatedAt" => Time.now.utc.iso8601(6) }
      end

      def build_manifest(id, diagnostics, entry_count, entries_digest, files)
        {
          "version" => VERSION,
          "transactionId" => id,
          "createdAt" => Time.now.utc.iso8601(6),
          "outcome" => diagnostics.fetch("deliveryOutcome"),
          "target" => { "endpoint" => sanitized_endpoint, "project" => @config.project.to_s },
          "entries" => { "path" => ".entries.ndjson", "count" => entry_count,
                         "length" => entries_digest.fetch("length"),
                         "sha256" => entries_digest.fetch("sha256") },
          "files" => files,
          "diagnostics" => diagnostics
        }
      end

      def persist_attachments(files, entries, attachments_dir, deadline)
        files.each_with_index.map do |file, index|
          check_deadline!(deadline)
          filename = format("%04d.blob", index)
          destination = File.join(attachments_dir, filename)
          entry_index = file.fetch(:entry_index)
          metadata = { "path" => ".attachments-data/#{filename}", "name" => file.fetch(:name),
                       "mime" => file.fetch(:mime), "entry_index" => entry_index }
          begin
            length, digest = copy_attachment(file, destination, deadline)
            metadata.merge("length" => length, "sha256" => digest)
          rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES, IOError
            remove_file_best_effort(destination)
            metadata.merge("unavailable" => true, "reason" => "source_unavailable")
          end
        end
      end

      def copy_attachment(file, destination, deadline)
        digest = Digest::SHA256.new
        length = 0
        File.open(destination, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |output|
          output.binmode
          output.sync = true
          if file[:path]
            copy_path(file[:path], output, digest, deadline) { |size| length += size }
          else
            bytes = file.fetch(:bytes)
            offset = 0
            while offset < bytes.bytesize
              check_deadline!(deadline)
              chunk = bytes.byteslice(offset, COPY_CHUNK_BYTES)
              write_quota_chunk(output, chunk, deadline)
              digest.update(chunk)
              length += chunk.bytesize
              offset += chunk.bytesize
            end
          end
          output.flush
          output.fsync
        end
        [length, digest.hexdigest]
      rescue StandardError
        remove_file_best_effort(destination)
        raise
      end

      def copy_path(path, output, digest, deadline)
        expanded = File.expand_path(path)
        before = File.lstat(expanded)
        raise Error.new(:unsafe_evidence) if before.symlink? || !before.file?
        flags = File::RDONLY
        flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
        File.open(expanded, flags) do |input|
          input.binmode
          opened = input.stat
          raise Error.new(:unsafe_evidence) unless opened.file? && opened.dev == before.dev && opened.ino == before.ino
          raise Error.new(:changed_evidence) unless opened.size == before.size && opened.mtime.to_r == before.mtime.to_r

          copied = 0
          while (chunk = input.read(COPY_CHUNK_BYTES))
            check_deadline!(deadline)
            write_quota_chunk(output, chunk, deadline)
            digest.update(chunk)
            copied += chunk.bytesize
            yield chunk.bytesize
          end
          after = File.lstat(expanded)
          raise Error.new(:unsafe_evidence) if after.symlink? || after.dev != before.dev || after.ino != before.ino
          raise Error.new(:changed_evidence) unless copied == opened.size && after.size == opened.size && after.mtime.to_r == opened.mtime.to_r
        end
      end

      def validate_entries(entries)
        raise Error.new(:invalid_entries) unless entries.is_a?(Array) && entries.length.between?(1, MAX_ENTRIES)

        aggregate = 0
        normalized = entries.map do |entry|
          raise Error.new(:invalid_entry) unless entry.is_a?(Hash)
          value = entry.each_with_object({}) do |(key, item), memo|
            name = key.to_s
            raise Error.new(:invalid_entry) unless WIRE_FIELDS.include?(name) || INTERNAL_FIELDS.include?(name)
            next if INTERNAL_FIELDS.include?(name)

            memo[name] = item
          end
          validate_wire_entry!(value)
          line_size = JSON.generate(value).bytesize + 1
          raise Error.new(:entry_limit) if line_size > MAX_ENTRY_BYTES
          aggregate += line_size
          raise Error.new(:entries_limit) if aggregate > MAX_ENTRIES_BYTES

          value
        end
        normalized
      end

      def validate_wire_entry!(entry)
        required = %w[time message level]
        raise Error.new(:invalid_entry) unless (required - entry.keys).empty?
        raise Error.new(:invalid_entry) unless entry["time"].is_a?(String) && entry["message"].is_a?(String) && entry["level"].is_a?(String)
        %w[launchUuid itemUuid].each do |key|
          raise Error.new(:invalid_entry) if entry.key?(key) && !entry[key].is_a?(String)
        end
        return unless entry.key?("file")

        file = entry["file"]
        raise Error.new(:invalid_entry) unless file.is_a?(Hash) && file.keys.map(&:to_s) == ["name"] && file.values.first.is_a?(String)
      end

      def validate_files(files, entries)
        raise Error.new(:invalid_files) unless files.is_a?(Array) && files.length <= entries.length
        references = entries.each_with_index.filter_map do |entry, index|
          [entry.fetch("file").fetch("name"), index] if entry["file"]
        end
        raise Error.new(:invalid_files) unless references.length == files.length

        used = {}
        files.map do |file|
          raise Error.new(:invalid_file) unless file.is_a?(Hash)
          name = (file[:name] || file["name"]).to_s
          mime = file[:mime] || file["mime"]
          path = file[:path] || file["path"]
          bytes = file[:bytes] || file["bytes"]
          raise Error.new(:invalid_file) unless safe_logical_name?(name) && mime.is_a?(String) && mime.bytesize <= 255
          raise Error.new(:invalid_file) unless (path.nil? ^ bytes.nil?)
          raise Error.new(:invalid_file) if path && (!path.is_a?(String) || path.empty?)
          raise Error.new(:invalid_file) if bytes && !bytes.is_a?(String)
          entry_index = references.find { |entry_name, index| entry_name == name && !used[index] }&.last
          raise Error.new(:file_alignment) unless entry_index
          used[entry_index] = true
          { name: name.dup.freeze, mime: mime.dup.freeze, path: path, bytes: bytes,
            entry_index: entry_index }
        end
      end

      def encode_entries(entries, diagnostics, files, id)
        internal = diagnostics.slice("spoolError", "fallbackSpoolError", "rawSpool", "deliveryOutcome")
        lines = entries.each_with_index.map do |entry, index|
          metadata = internal.dup
          file = files.find { |candidate| candidate.fetch("entry_index") == index }
          if diagnostics["rawSpool"] && file
            compatibility = { "name" => file.fetch("name"), "mime" => file.fetch("mime") }
            if file["unavailable"]
              compatibility.merge!("missing" => true, "unavailable" => true)
            else
              compatibility["spooledPath"] = "#{id}.attachments/#{file.fetch('path')}"
            end
            metadata["attachment"] = compatibility
          end
          line = JSON.generate(entry.merge(metadata))
          raise Error.new(:entry_limit) if line.bytesize + 1 > MAX_ENTRY_BYTES

          line
        end
        content = lines.join("\n") + "\n"
        raise Error.new(:entries_limit) if content.bytesize > MAX_ENTRIES_BYTES

        content
      end

      def decode_entries(bytes, file_metadata)
        lines = bytes.lines
        raise Error.new(:invalid_entries) unless lines.length.between?(1, MAX_ENTRIES)
        entries = lines.map do |line|
          parsed = JSON.parse(line)
          raise Error.new(:invalid_entry) unless parsed.is_a?(Hash)
          raise Error.new(:invalid_entry) unless (parsed.keys - WIRE_FIELDS - INTERNAL_FIELDS).empty?
          wire = parsed.select { |key, _value| WIRE_FIELDS.include?(key) }
          validate_wire_entry!(wire)
          wire
        end
        validate_alignment!(entries, file_metadata)
        entries
      end

      def validate_alignment!(entries, file_metadata)
        refs = entries.each_with_index.filter_map do |entry, index|
          [entry.fetch("file").fetch("name"), index] if entry["file"]
        end
        raise Error.new(:file_alignment) unless refs.length == file_metadata.length
        seen = {}
        file_metadata.each do |file|
          entry_index = file.fetch("entry_index")
          key = [file.fetch("name"), entry_index]
          raise Error.new(:file_alignment) unless refs.include?(key) && !seen[key]
          seen[key] = true
        end
      end

      def load_files(directory, metadata, entries)
        metadata.map do |file|
          unavailable = !!file["unavailable"]
          item = { name: file.fetch("name"), mime: file.fetch("mime"),
                   entry_index: file.fetch("entry_index"), unavailable: unavailable }
          if unavailable
            item[:path] = file.fetch("path").freeze
            item[:reason] = file.fetch("reason").freeze
          else
            item[:length] = file.fetch("length")
            item[:sha256] = file.fetch("sha256").freeze
            path = safe_child(directory, file.fetch("path"))
            verify_file!(path, file.fetch("length"), file.fetch("sha256"))
            item[:path] = File.expand_path(path).freeze
          end
          item.freeze
        end
      end

      def read_checkpoint(directory, entry_count, id:, entries_sha256:)
        checkpoint = read_json_file(safe_child(directory, ".checkpoint.json"), MAX_METADATA_BYTES)
        raise Error.new(:invalid_checkpoint) unless checkpoint["version"] == VERSION &&
                                                    checkpoint["transactionId"] == id &&
                                                    checkpoint["entriesSha256"] == entries_sha256 &&
                                                    (checkpoint.keys - %w[version transactionId entriesSha256 states updatedAt]).empty? &&
                                                    checkpoint["updatedAt"].is_a?(String) && checkpoint["updatedAt"].bytesize <= 32
        states = validate_states(checkpoint["states"], entry_count)
        states = states.map do |state|
          state["state"] == "in_flight" ? state.merge("state" => "ambiguous") : state
        end
        checkpoint.merge("states" => states)
      end

      def validate_states(states, count)
        raise Error.new(:invalid_checkpoint) unless states.is_a?(Array) && states.length == count

        states.map do |state|
          raise Error.new(:invalid_checkpoint) unless state.is_a?(Hash)
          normalized = state.each_with_object({}) { |(key, value), memo| memo[key.to_s] = value }
          raise Error.new(:invalid_checkpoint) unless (normalized.keys - %w[state id]).empty?
          raise Error.new(:invalid_checkpoint) unless STATES.include?(normalized["state"])
          if normalized.key?("id")
            raise Error.new(:invalid_checkpoint) unless normalized["id"].is_a?(String) && normalized["id"].bytesize <= 512
          end
          raise Error.new(:invalid_checkpoint) if normalized["state"] == "confirmed" && normalized.fetch("id", "").empty?
          normalized
        end
      end

      def validate_manifest!(manifest, id)
        raise Error.new(:invalid_manifest) unless manifest.is_a?(Hash) && manifest["version"] == VERSION && manifest["transactionId"] == id
        entries = manifest["entries"]
        raise Error.new(:invalid_manifest) unless entries.is_a?(Hash) && entries["path"] == ".entries.ndjson"
        raise Error.new(:invalid_manifest) unless entries["count"].is_a?(Integer) && entries["count"].between?(1, MAX_ENTRIES)
        raise Error.new(:invalid_manifest) unless entries["length"].is_a?(Integer) && entries["length"].between?(1, MAX_ENTRIES_BYTES)
        raise Error.new(:invalid_manifest) unless entries["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
        files = manifest["files"]
        raise Error.new(:invalid_manifest) unless files.is_a?(Array) && files.length <= entries["count"]
        files.each { |file| validate_file_metadata!(file, entries["count"]) }
      end

      def validate_file_metadata!(file, count)
        raise Error.new(:invalid_manifest) unless file.is_a?(Hash)
        raise Error.new(:invalid_manifest) unless safe_logical_name?(file["name"]) && file["mime"].is_a?(String)
        raise Error.new(:invalid_manifest) unless file["entry_index"].is_a?(Integer) && file["entry_index"].between?(0, count - 1)
        if file["unavailable"]
          safe_relative_path!(file["path"])
          raise Error.new(:invalid_manifest) unless file["path"].is_a?(String) && file["reason"] == "source_unavailable"
          raise Error.new(:invalid_manifest) if file.key?("length") || file.key?("sha256")
        else
          safe_relative_path!(file["path"])
          raise Error.new(:invalid_manifest) unless file["length"].is_a?(Integer) && file["length"] >= 0
          raise Error.new(:invalid_manifest) unless file["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
        end
      end

      def safe_child(directory, relative)
        safe_relative_path!(relative)
        path = File.expand_path(relative, directory)
        raise Error.new(:unsafe_path) unless path.start_with?("#{directory}/")
        cursor = directory
        relative.split("/").each_with_index do |part, index|
          cursor = File.join(cursor, part)
          next unless File.exist?(cursor) || File.symlink?(cursor)

          stat = File.lstat(cursor)
          raise Error.new(:unsafe_path) if stat.symlink?
          raise Error.new(:unsafe_path) if index < relative.split("/").length - 1 && !stat.directory?
        end
        if File.exist?(path) || File.symlink?(path)
          root_real = File.realpath(directory)
          path_real = File.realpath(path)
          raise Error.new(:unsafe_path) unless path_real.start_with?("#{root_real}/")
        end
        path
      end

      def safe_relative_path!(path)
        parts = path.to_s.split("/", -1)
        raise Error.new(:unsafe_path) if path.to_s.empty? || path.start_with?("/") || parts.any? { |part| part.empty? || part == "." || part == ".." }
      end

      def safe_logical_name?(name)
        name.is_a?(String) && !name.empty? && name.bytesize <= 255 && name == File.basename(name) &&
          !name.include?("\0") && name != "." && name != ".."
      end

      def verify_file!(path, expected_length, expected_digest)
        ensure_regular_file!(path)
        digest = Digest::SHA256.new
        length = 0
        File.open(path, File::RDONLY | (File.const_defined?(:NOFOLLOW) ? File::NOFOLLOW : 0)) do |file|
          file.binmode
          while (chunk = file.read(COPY_CHUNK_BYTES))
            digest.update(chunk)
            length += chunk.bytesize
            raise Error.new(:corrupt_attachment) if length > expected_length
          end
        end
        raise Error.new(:corrupt_attachment) unless length == expected_length && digest.hexdigest == expected_digest
      rescue Error => error
        raise unless error.reason == :missing_transaction

        raise Error.new(:missing_attachment)
      rescue Errno::ENOENT
        raise Error.new(:missing_attachment)
      end

      def write_json_file(path, value, deadline)
        bytes = JSON.generate(value)
        raise Error.new(:metadata_limit) if bytes.bytesize > MAX_METADATA_BYTES
        write_quota_file(path, bytes, deadline)
      end

      def write_quota_file(path, bytes, deadline)
        check_deadline!(deadline)
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          file.binmode
          File.chmod(0o600, path)
          file.sync = true
          offset = 0
          while offset < bytes.bytesize
            check_deadline!(deadline)
            chunk = bytes.byteslice(offset, COPY_CHUNK_BYTES)
            write_quota_chunk(file, chunk, deadline)
            offset += chunk.bytesize
          end
          file.flush
          file.fsync
        end
        sync_directory(File.dirname(path))
      end

      def write_quota_chunk(file, chunk, deadline)
        with_quota_lock(deadline) do
          check_deadline!(deadline)
          raise Error.new(:quota_exceeded) if usage_bytes + chunk.bytesize > @max_bytes
          written = file.write(chunk)
          raise Error.new(:write_failed) unless written == chunk.bytesize
        end
      end

      def digest_file(path, deadline)
        digest = Digest::SHA256.new
        length = 0
        File.open(path, File::RDONLY) do |file|
          file.binmode
          while (chunk = file.read(COPY_CHUNK_BYTES))
            check_deadline!(deadline)
            digest.update(chunk)
            length += chunk.bytesize
          end
        end
        { "length" => length, "sha256" => digest.hexdigest }
      end

      def read_json_file(path, max_bytes)
        bytes = read_bounded_file(path, max_bytes)
        JSON.parse(bytes)
      rescue JSON::ParserError
        raise Error.new(:invalid_json)
      end

      def read_bounded_file(path, max_bytes)
        ensure_regular_file!(path)
        flags = File::RDONLY
        flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
        bytes = File.open(path, flags) do |file|
          file.binmode
          raise Error.new(:unsafe_path) unless file.stat.file?
          raise Error.new(:metadata_limit) if file.stat.size > max_bytes

          file.read(max_bytes + 1)
        end
        bytes.tap do |content|
          raise Error.new(:metadata_limit) if content.bytesize > max_bytes
        end
      end

      def ensure_marker_matches!(marker, entries)
        ensure_regular_file!(entries)
        left = File.stat(marker)
        right = File.stat(entries)
        raise Error.new(:invalid_publication) unless left.dev == right.dev && left.ino == right.ino
      end

      def ensure_regular_file!(path)
        stat = File.lstat(path)
        raise Error.new(:unsafe_path) if stat.symlink? || !stat.file?
      rescue Errno::ENOENT
        raise Error.new(:missing_transaction)
      end

      def ensure_directory!(path)
        stat = File.lstat(path)
        raise Error.new(:unsafe_path) if stat.symlink? || !stat.directory?
      rescue Errno::ENOENT
        raise Error.new(:missing_transaction)
      end

      def ensure_regular_or_absent!(path)
        stat = File.lstat(path)
        raise Error.new(:unsafe_path) if stat.symlink? || !stat.file?
      rescue Errno::ENOENT
        true
      end

      def ensure_root!(create: true)
        if File.symlink?(@root)
          raise Error.new(:unsafe_root)
        elsif !File.exist?(@root)
          raise Error.new(:missing_root) unless create

          FileUtils.mkdir_p(@root, mode: 0o700)
        end
        stat = File.lstat(@root)
        raise Error.new(:unsafe_root) if stat.symlink? || !stat.directory?
        File.chmod(0o700, @root)
      rescue Error
        raise
      rescue StandardError => error
        raise Error.new(:root_unavailable, safe_io_message(error))
      end

      def with_quota_lock(deadline)
        ensure_root!
        lock_path = File.join(@root, ".quota.lock")
        ensure_regular_or_absent!(lock_path)
        lock_flags = File::RDWR | File::CREAT
        lock_flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
        File.open(lock_path, lock_flags, 0o600) do |lock|
          File.chmod(0o600, lock_path)
          acquire_lock!(lock, deadline)
          yield
        ensure
          lock.flock(File::LOCK_UN) rescue nil
        end
      rescue Error
        raise
      rescue StandardError => error
        raise Error.new(:quota_lock_failed, safe_io_message(error))
      end

      def acquire_lock!(lock, deadline)
        loop do
          check_deadline!(deadline)
          return if lock.flock(File::LOCK_EX | File::LOCK_NB)

          remaining = deadline.remaining
          raise Error.new(:deadline_expired) if remaining <= 0
          sleep([remaining, 0.01].min)
        end
      rescue Error
        raise
      rescue SystemCallError => error
        raise Error.new(:lock_failed, safe_io_message(error))
      end

      def usage_bytes
        seen = {}
        total = 0
        walk = lambda do |directory|
          Dir.children(directory).each do |name|
            path = File.join(directory, name)
            stat = File.lstat(path)
            raise Error.new(:unsafe_path) if stat.symlink?
            if stat.directory?
              walk.call(path)
            elsif stat.file?
              key = [stat.dev, stat.ino]
              next if seen[key]

              seen[key] = true
              total += stat.size
              raise Error.new(:quota_exceeded) if total > @max_bytes
            else
              raise Error.new(:unsafe_path)
            end
          end
        end
        walk.call(@root)
        total
      rescue Error
        raise
      rescue StandardError => error
        raise Error.new(:quota_scan_failed, safe_io_message(error))
      end

      def sync_directory(path)
        File.open(path, File::RDONLY) { |directory| directory.fsync }
      rescue Errno::EINVAL, Errno::ENOTSUP, Errno::EBADF, NotImplementedError
        nil
      end

      def marker_path(id)
        File.join(@root, "#{id}.ndjson")
      end

      def transaction_directory(id)
        File.join(@root, "#{id}.attachments")
      end

      def validate_id!(id)
        raise Error.new(:invalid_transaction_id) unless id.is_a?(String) && ID_PATTERN.match?(id)
      end

      def sanitized_endpoint
        uri = URI.parse(@config.endpoint.to_s)
        uri.user = nil
        uri.password = nil
        uri.query = nil
        uri.fragment = nil
        uri.to_s
      rescue URI::InvalidURIError
        ""
      end

      def sanitize_diagnostics(diagnostics, outcome)
        raise Error.new(:invalid_diagnostics) unless diagnostics.is_a?(Hash)
        safe = { "deliveryOutcome" => outcome.to_s }
        diagnostics.each do |key, value|
          name = key.to_s
          next unless INTERNAL_FIELDS.include?(name) && name != "deliveryOutcome"
          case value
          when String
            safe[name] = EvidencePresenter.sanitize_diagnostic(value, limit: 2_048)
          when true, false
            safe[name] = value if name == "rawSpool"
          end
        end
        safe
      end

      def check_deadline!(deadline)
        raise Error.new(:deadline_expired) if deadline&.expired?
      end

      def default_deadline
        timeout_ms = @config.respond_to?(:exit_flush_timeout_ms) ? @config.exit_flush_timeout_ms : 5_000
        ReportingDeadline.new(timeout: timeout_ms / 1000.0)
      end

      def cleanup_unpublished(stage, directory, id, published, deadline)
        return if published || deadline&.expired?
        paths = [stage]
        paths << directory if id && File.directory?(directory) && !File.exist?(marker_path(id))
        paths.each do |path|
          next unless path && File.directory?(path)

          FileUtils.remove_entry_secure(path)
        rescue StandardError
          nil
        end
      end

      def remove_file_best_effort(path)
        return unless path && File.file?(path) && !File.symlink?(path)

        File.unlink(path)
      rescue StandardError
        nil
      end

      def safe_io_message(error)
        EvidencePresenter.sanitize_diagnostic(error.message, limit: 512)
      rescue StandardError
        "Spool operation failed"
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, item| deep_freeze(key); deep_freeze(item) }
        when Array
          value.each { |item| deep_freeze(item) }
        end
        value.freeze
      end
    end
  end
end
