# frozen_string_literal: true

module ReportportalCucumber
  module ReportPortal
    # Helpers that build ReportPortal request bodies and identity values.
    module Models
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
            if parsed.match?(/\A\d+\z/)
              return parsed
            end

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
          "description" => description,
          "attributes" => compact_array(attributes),
          "mode" => mode,
          "rerun" => rerun,
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
          "attributes" => compact_array(attributes)
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
      # @param has_stats [Boolean]
      # @param retry [Boolean]
      # @param uuid [String, nil]
      # @param test_case_id [String, nil]
      # @param unique_id [String, nil]
      # @return [Hash]
      def build_item_start(name:, start_time:, type:, launch_uuid:, description:, attributes:, code_ref:, parameters:,
                           has_stats:, retry:, uuid:, test_case_id:, unique_id:)
        retry_flag = binding.local_variable_get(:retry)
        {
          "name" => name,
          "startTime" => unix_ms(start_time),
          "type" => type,
          "launchUuid" => launch_uuid,
          "description" => description,
          "attributes" => compact_array(attributes),
          "codeRef" => code_ref,
          "parameters" => parameters.nil? ? nil : normalize_parameters(parameters),
          "hasStats" => has_stats,
          "retry" => retry_flag,
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
      # @param level [String, Symbol]
      # @param file_name [String, nil]
      # @return [Hash]
      def build_log_entry(launch_uuid:, item_uuid:, time:, message:, level:, file_name: nil)
        entry = {
          "launchUuid" => launch_uuid,
          "itemUuid" => item_uuid,
          "time" => unix_ms(time),
          "message" => message.to_s,
          "level" => level.to_s.downcase
        }
        entry["file"] = { "name" => file_name } if file_name
        entry
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
        payload = {
          code_ref: code_ref,
          parameters: normalize_parameters(parameters)
        }
        Digest::SHA1.hexdigest(JSON.generate(payload))
      end

      # @param parameters [Hash, Array<Hash>, nil]
      # @return [Hash, Array<Hash>, nil]
      def normalize_parameters(parameters)
        case parameters
        when nil
          nil
        when Array
          parameters.map { |item| stringify_hash(item) }
        when Hash
          parameters.each_with_object({}) { |(key, value), memo| memo[key.to_s] = value.to_s }
        else
          { "value" => parameters.to_s }
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

      # @param base [String]
      # @param parameters [Hash, Array<Hash>, nil]
      # @return [String]
      def append_parameters_identifier(base, parameters)
        normalized = normalize_parameters(parameters)
        return base if normalized.nil? || normalized == {} || normalized == []

        suffix =
          case normalized
          when Array
            normalized.map do |item|
              stringify_hash(item).sort.map { |key, value| "#{key}=#{value}" }.join(",")
            end.join(";")
          when Hash
            normalized.sort.map { |key, value| "#{key}=#{value}" }.join(",")
          else
            normalized.to_s
          end

        "#{base}[#{suffix}]"
      end

      # @param value [Array<Hash>, nil]
      # @return [Array<Hash>, nil]
      def compact_array(value)
        return nil if value.nil?

        value.map { |item| stringify_hash(item).compact }.reject(&:empty?)
      end

      # @param value [Hash]
      # @return [Hash]
      def stringify_hash(value)
        value.each_with_object({}) { |(key, item), memo| memo[key.to_s] = item }
      end
    end
  end
end
