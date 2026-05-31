# frozen_string_literal: true

module ReportportalCucumber
  module Service
    # Pure builders for ReportPortal request payloads and identity values.
    module PayloadBuilder
      module_function

      MIME_EXTENSION_MAP = {
        "application/json" => ".json",
        "application/pdf" => ".pdf",
        "application/octet-stream" => ".bin",
        "image/jpeg" => ".jpg",
        "image/png" => ".png",
        "text/plain" => ".txt",
        "video/mp4" => ".mp4"
      }.freeze
      ITEM_TYPE_MAP = {
        "suite" => "SUITE",
        "story" => "STORY",
        "test" => "TEST",
        "scenario" => "SCENARIO",
        "step" => "STEP",
        "before_class" => "BEFORE_CLASS",
        "before_groups" => "BEFORE_GROUPS",
        "before_method" => "BEFORE_METHOD",
        "before_suite" => "BEFORE_SUITE",
        "before_test" => "BEFORE_TEST",
        "after_class" => "AFTER_CLASS",
        "after_groups" => "AFTER_GROUPS",
        "after_method" => "AFTER_METHOD",
        "after_suite" => "AFTER_SUITE",
        "after_test" => "AFTER_TEST"
      }.freeze

      # @param value [Time, String, Integer, Float, nil]
      # @return [String]
      def unix_ms(value)
        time =
          case value
          when nil
            Time.now
          when Time
            value
          when Integer
            Time.at(value / 1000.0)
          when Float
            Time.at(value)
          else
            parsed = value.to_s
            return parsed if parsed.match?(/\A\d+\z/)

            Time.parse(parsed)
          end

        (time.to_r * 1000).to_i.to_s
      end

      # @param name [String]
      # @param start_time [Time, String, Integer, Float]
      # @param description [String, nil]
      # @param attributes [Array<Hash>, nil]
      # @param mode [String, nil]
      # @param rerun [Boolean]
      # @param rerun_of [String, nil]
      # @param uuid [String, nil]
      # @return [Hash]
      def build_launch_start(name:, start_time:, description:, attributes:, mode:, rerun:, rerun_of:, uuid:)
        {
          "name" => name,
          "startTime" => unix_ms(start_time),
          "description" => description.to_s,
          "attributes" => normalize_attributes(attributes),
          "mode" => mode,
          "rerun" => !!rerun,
          "rerunOf" => rerun_of,
          "uuid" => uuid
        }.compact
      end

      # @param launch_uuid [String]
      # @param end_time [Time, String, Integer, Float]
      # @param status [String, Symbol, nil]
      # @param attributes [Array<Hash>, nil]
      # @return [Hash]
      def build_launch_finish(launch_uuid:, end_time:, status: nil, attributes: nil)
        {
          "endTime" => unix_ms(end_time),
          "status" => normalize_status(status),
          "attributes" => normalize_attributes(attributes)
        }.compact
      end

      # @param name [String]
      # @param start_time [Time, String, Integer, Float]
      # @param type [String]
      # @param launch_uuid [String]
      # @param description [String, nil]
      # @param attributes [Array<Hash>, nil]
      # @param code_ref [String, nil]
      # @param parameters [Hash, Array<Hash>, nil]
      # @param parent_uuid [String, nil]
      # @param has_stats [Boolean]
      # @param retry [Boolean]
      # @param uuid [String, nil]
      # @param test_case_id [String, nil]
      # @param unique_id [String, nil]
      # @return [Hash]
      def build_item_start(name:, start_time:, type:, launch_uuid:, description:, attributes:, code_ref:, parameters:,
                           parent_uuid: nil, has_stats:, retry:, uuid:, test_case_id:, unique_id:)
        retry_flag = binding.local_variable_get(:retry)
        {
          "name" => name,
          "startTime" => unix_ms(start_time),
          "type" => normalize_item_type(type),
          "launchUuid" => launch_uuid,
          "parentUuid" => parent_uuid,
          "description" => description,
          "attributes" => normalize_attributes(attributes),
          "codeRef" => code_ref,
          "parameters" => parameters.nil? ? nil : normalize_parameters(parameters),
          "hasStats" => has_stats,
          "retry" => !!retry_flag,
          "uuid" => uuid,
          "testCaseId" => test_case_id,
          "uniqueId" => unique_id
        }.compact
      end

      # @param item_uuid [String]
      # @param launch_uuid [String]
      # @param end_time [Time, String, Integer, Float]
      # @param status [String, Symbol, nil]
      # @return [Hash]
      def build_item_finish(item_uuid:, launch_uuid:, end_time:, status: nil)
        {
          "endTime" => unix_ms(end_time),
          "launchUuid" => launch_uuid,
          "status" => normalize_status(status)
        }.compact
      end

      # @param launch_uuid [String, nil]
      # @param item_uuid [String, nil]
      # @param time [Time, String, Integer, Float]
      # @param message [String]
      # @param level [String, Symbol, Integer]
      # @param file_name [String, nil]
      # @return [Hash]
      def build_log_entry(launch_uuid:, item_uuid:, time:, message:, level:, file_name: nil)
        entry = {
          "launchUuid" => launch_uuid,
          "itemUuid" => item_uuid,
          "time" => unix_ms(time),
          "message" => message.to_s,
          "level" => normalize_log_level(level)
        }.compact
        entry["file"] = { "name" => file_name } if file_name
        entry
      end

      # @param records [Array<#to_h, Hash>]
      # @return [Hash]
      def build_log_batch(records)
        used_names = Hash.new(0)
        entries = []
        files = []

        Array(records).each do |record|
          payload = record.respond_to?(:to_h) ? record.to_h : record
          attachment = normalize_attachment(payload[:attachment] || payload["attachment"])
          filename = attachment && unique_filename(attachment.fetch(:name), used_names)
          entries << build_log_entry(
            launch_uuid: payload[:launch_uuid] || payload["launch_uuid"],
            item_uuid: payload[:item_uuid] || payload["item_uuid"],
            time: payload[:timestamp] || payload["timestamp"],
            message: enrich_log_message(payload[:message] || payload["message"], attachment),
            level: payload[:level] || payload["level"],
            file_name: filename
          )

          next unless attachment

          file = {
            name: filename,
            mime: attachment.fetch(:mime)
          }
          if attachment[:path]
            file[:path] = attachment.fetch(:path)
          else
            file[:bytes] = attachment.fetch(:bytes).dup.force_encoding(Encoding::BINARY)
          end
          files << file
        end

        validate_log_batch!(entries: entries, files: files)
        { entries: entries, files: files }
      end

      # @param attachment [Hash, nil]
      # @return [Boolean]
      def video_attachment?(attachment)
        return false unless attachment

        mime = attachment[:mime] || attachment["mime"]
        name = attachment[:name] || attachment["name"]
        mime.to_s.downcase == "video/mp4" || File.extname(name.to_s).downcase == ".mp4"
      end

      # @param message [String, nil]
      # @param url [String]
      # @param width [Integer]
      # @return [String]
      def build_video_markdown_message(message:, url:, width: 640)
        base = message.to_s.strip
        video = "UI Failure Playback:\n\n" \
                "<video width=\"#{Integer(width)}\" controls preload=\"metadata\">" \
                "<source src=\"#{CGI.escapeHTML(url.to_s)}\" type=\"video/mp4\"></video>"
        return video if base.empty?

        "#{base}\n\n#{video}"
      end

      # @param feature_uri [String]
      # @param scenario_line [Integer, String]
      # @return [String]
      def build_code_ref(feature_uri:, scenario_line:)
        "#{feature_uri}:#{scenario_line}"
      end

      # @param explicit_id [String, nil]
      # @param code_ref [String]
      # @param parameters [Hash, Array<Hash>, nil]
      # @return [String]
      def build_test_case_id(explicit_id: nil, code_ref:, parameters: nil)
        base = explicit_id.nil? || explicit_id.to_s.strip.empty? ? code_ref : explicit_id.to_s.strip
        append_parameters_identifier(base, parameters)
      end

      # @param code_ref [String]
      # @param parameters [Hash, Array<Hash>, nil]
      # @return [String]
      def build_unique_id(code_ref:, parameters: nil)
        Digest::SHA1.hexdigest(
          JSON.generate(
            code_ref: code_ref,
            parameters: normalize_parameters(parameters)
          )
        )
      end

      # @param parameters [Hash, Array<Hash>, nil]
      # @return [Array<Hash>, nil]
      def normalize_parameters(parameters)
        case parameters
        when nil
          nil
        when Array
          parameters.map do |item|
            hash = stringify_hash(item)
            if hash.key?("key")
              {
                "key" => hash["key"].to_s,
                "value" => hash["value"].to_s
              }
            else
              key, value = hash.first
              {
                "key" => key.to_s,
                "value" => value.to_s
              }
            end
          end
        when Hash
          parameters.map do |key, value|
            {
              "key" => key.to_s,
              "value" => value.to_s
            }
          end
        else
          [{ "key" => "value", "value" => parameters.to_s }]
        end
      end

      # @param status [String, Symbol, nil]
      # @return [String, nil]
      def normalize_status(status)
        return nil if status.nil?

        case status.to_s.downcase
        when "passed", "pass", "success"
          "passed"
        when "failed", "failure"
          "failed"
        when "skipped", "pending", "undefined", "ambiguous"
          "skipped"
        else
          status.to_s.downcase
        end
      end

      # @param type [String, Symbol]
      # @return [String]
      def normalize_item_type(type)
        normalized = type.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").sub(/\A_+/, "").sub(/_+\z/, "")
        ITEM_TYPE_MAP.fetch(normalized, type.to_s.upcase)
      end

      # @param level [String, Symbol, Integer]
      # @return [String, Integer]
      def normalize_log_level(level)
        return level if level.is_a?(Integer)

        value = level.to_s.downcase
        return value unless value.empty?

        "info"
      end

      # @param attachment [Hash, nil]
      # @return [Hash, nil]
      def normalize_attachment(attachment)
        return nil if attachment.nil?

        payload = attachment.respond_to?(:to_h) ? attachment.to_h : attachment
        name = payload[:name] || payload["name"]
        mime = payload[:mime] || payload["mime"]
        bytes = payload[:bytes] || payload["bytes"]
        path = payload[:path] || payload["path"] || payload[:file_path] || payload["file_path"]

        path = normalize_attachment_path(path)
        name ||= File.basename(path) if path
        name = Transport::MultipartHelper.safe_filename(name)
        mime = Transport::MultipartHelper.content_type_for(
          filename: mime_detection_filename(name: name, path: path),
          declared_type: mime
        )
        name = Transport::MultipartHelper.ensure_filename_extension(
          name: name,
          content_type: mime,
          fallback: default_attachment_name(mime)
        )

        result = {
          name: name,
          mime: mime
        }
        if path
          result[:path] = path
        else
          result[:bytes] = normalize_attachment_bytes(bytes: bytes, mime: mime)
        end
        result
      end

      # @param message [String, nil]
      # @param attachment [Hash, nil]
      # @return [String]
      def enrich_log_message(message, attachment)
        base = message.to_s.strip
        preview = attachment_preview(attachment)
        parts = []
        parts << base unless base.empty?
        parts << preview unless preview.to_s.strip.empty?
        return "Attachment" if parts.empty?

        parts.join("\n\n")
      end

      # @param attributes [Array<Hash>, nil]
      # @return [Array<Hash>]
      def normalize_attributes(attributes)
        Array(attributes).map { |item| stringify_hash(item).compact }.reject(&:empty?)
      end

      # @param media_type [String, nil]
      # @return [String]
      def default_attachment_name(media_type)
        "attachment#{mime_extension(media_type)}"
      end

      # @param base [String]
      # @param parameters [Hash, Array<Hash>, nil]
      # @return [String]
      def append_parameters_identifier(base, parameters)
        pairs = identifier_pairs(parameters)
        return base if pairs.empty?

        "#{base}[#{pairs.map { |key, value| "#{key}=#{value}" }.join(',')}]"
      end

      # @param parameters [Hash, Array<Hash>, nil]
      # @return [Array<Array<String>>]
      def identifier_pairs(parameters)
        case parameters
        when nil
          []
        when Hash
          parameters.map { |key, value| [key.to_s, value.to_s] }
        when Array
          parameters.flat_map do |item|
            hash = stringify_hash(item)
            if hash.key?("key")
              [[hash["key"].to_s, hash["value"].to_s]]
            else
              hash.map { |key, value| [key.to_s, value.to_s] }
            end
          end
        else
          [["value", parameters.to_s]]
        end
      end

      # @param entries [Array<Hash>]
      # @param files [Array<Hash>]
      # @return [void]
      def validate_log_batch!(entries:, files:)
        referenced_files = entries.filter_map { |entry| entry.dig("file", "name") }
        actual_files = files.map { |file| file.fetch(:name) }
        return if referenced_files == actual_files

        raise ArgumentError, "Multipart log payload mismatch between json_request_part and file parts"
      end

      # @param value [Hash]
      # @return [Hash]
      def stringify_hash(value)
        value.each_with_object({}) { |(key, item), memo| memo[key.to_s] = item }
      end

      # @param bytes [Object]
      # @param mime [String]
      # @return [String]
      def normalize_attachment_bytes(bytes:, mime:)
        raw =
          if bytes.respond_to?(:read)
            data = bytes.read
            bytes.rewind if bytes.respond_to?(:rewind)
            data
          else
            bytes.to_s
          end

        return "#{pretty_json(raw)}\n" if json_attachment?(mime: mime)

        raw
      end

      # @param path [String, nil]
      # @return [String, nil]
      def normalize_attachment_path(path)
        return nil if path.to_s.strip.empty?

        expanded = File.expand_path(path.to_s)
        raise ArgumentError, "Attachment file does not exist: #{expanded}" unless File.file?(expanded)
        raise ArgumentError, "Attachment file is not readable: #{expanded}" unless File.readable?(expanded)

        expanded
      end

      # @param name [String]
      # @param path [String, nil]
      # @return [String]
      def mime_detection_filename(name:, path:)
        path && File.extname(name.to_s).empty? ? File.basename(path) : name
      end

      # @param attachment [Hash, nil]
      # @return [String, nil]
      def attachment_preview(attachment)
        return nil unless attachment
        return nil unless attachment.key?(:bytes)

        if json_attachment?(mime: attachment.fetch(:mime), name: attachment.fetch(:name))
          "```json\n#{pretty_json(safe_utf8(attachment.fetch(:bytes)))}\n```"
        elsif text_attachment?(mime: attachment.fetch(:mime), name: attachment.fetch(:name))
          text_preview(attachment)
        end
      end

      # @param attachment [Hash]
      # @return [String]
      def text_preview(attachment)
        content = safe_utf8(attachment.fetch(:bytes))
        lines = content.lines
        snippet = lines.first(100).join
        preview = "```text\n#{snippet.rstrip}\n```"
        return preview if lines.length <= 100

        "#{preview}\n\nFull log is attached as `#{attachment.fetch(:name)}`."
      end

      # @param value [Object]
      # @return [String]
      def safe_utf8(value)
        value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      end

      # @param content [String]
      # @return [String]
      def pretty_json(content)
        JSON.pretty_generate(JSON.parse(content.to_s))
      rescue JSON::ParserError
        content.to_s
      end

      # @param mime [String]
      # @param name [String, nil]
      # @return [Boolean]
      def json_attachment?(mime:, name: nil)
        mime.to_s.downcase == "application/json" || File.extname(name.to_s).downcase == ".json"
      end

      # @param mime [String]
      # @param name [String, nil]
      # @return [Boolean]
      def text_attachment?(mime:, name: nil)
        mime.to_s.downcase.start_with?("text/") || %w[.log .txt].include?(File.extname(name.to_s).downcase)
      end

      # @param media_type [String, nil]
      # @return [String]
      def mime_extension(media_type)
        normalized = media_type.to_s.downcase
        return MIME_EXTENSION_MAP[normalized] if MIME_EXTENSION_MAP.key?(normalized)

        detected = MIME::Types[normalized].first
        extension = detected&.preferred_extension.to_s
        extension.empty? ? "" : ".#{extension}"
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
    end
  end
end
