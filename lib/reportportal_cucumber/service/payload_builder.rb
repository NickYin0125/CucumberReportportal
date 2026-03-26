# frozen_string_literal: true

module ReportportalCucumber
  module Service
    # Pure builders for ReportPortal request payloads and identity values.
    module PayloadBuilder
      module_function

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
          "launchUuid" => launch_uuid,
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
          "type" => type,
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
          attachment = payload[:attachment] || payload["attachment"]
          filename = attachment && unique_filename(attachment.fetch(:name), used_names)
          entries << build_log_entry(
            launch_uuid: payload[:launch_uuid] || payload["launch_uuid"],
            item_uuid: payload[:item_uuid] || payload["item_uuid"],
            time: payload[:timestamp] || payload["timestamp"],
            message: payload[:message] || payload["message"],
            level: payload[:level] || payload["level"],
            file_name: filename
          )

          next unless attachment

          files << {
            name: filename,
            mime: attachment.fetch(:mime),
            bytes: attachment.fetch(:bytes)
          }
        end

        validate_log_batch!(entries: entries, files: files)
        { entries: entries, files: files }
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

      # @param level [String, Symbol, Integer]
      # @return [String, Integer]
      def normalize_log_level(level)
        return level if level.is_a?(Integer)

        value = level.to_s.downcase
        return value unless value.empty?

        "info"
      end

      # @param attributes [Array<Hash>, nil]
      # @return [Array<Hash>]
      def normalize_attributes(attributes)
        Array(attributes).map { |item| stringify_hash(item).compact }.reject(&:empty?)
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
