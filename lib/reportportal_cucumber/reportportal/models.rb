# frozen_string_literal: true

module ReportportalCucumber
  module ReportPortal
    # Helpers that build ReportPortal request bodies and identity values.
    module Models
      module_function

      # @param value [Time, String, Integer, Float, nil]
      # @return [String]
      def unix_ms(value)
        Service::PayloadBuilder.unix_ms(value)
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
        Service::PayloadBuilder.build_launch_start(
          name: name,
          start_time: start_time,
          description: description,
          attributes: attributes,
          mode: mode,
          rerun: rerun,
          rerun_of: rerun_of,
          uuid: uuid
        )
      end

      # @param launch_uuid [String]
      # @param end_time [Time, String, Integer, Float]
      # @param status [String, Symbol, nil]
      # @param attributes [Array<Hash>, nil]
      # @return [Hash]
      def build_launch_finish(launch_uuid:, end_time:, status: nil, attributes: nil)
        Service::PayloadBuilder.build_launch_finish(
          launch_uuid: launch_uuid,
          end_time: end_time,
          status: status,
          attributes: attributes
        )
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
        Service::PayloadBuilder.build_item_start(
          name: name,
          start_time: start_time,
          type: type,
          launch_uuid: launch_uuid,
          description: description,
          attributes: attributes,
          code_ref: code_ref,
          parameters: parameters,
          parent_uuid: parent_uuid,
          has_stats: has_stats,
          retry: retry_flag,
          uuid: uuid,
          test_case_id: test_case_id,
          unique_id: unique_id
        )
      end

      # @param item_uuid [String]
      # @param launch_uuid [String]
      # @param end_time [Time, String, Integer, Float]
      # @param status [String, Symbol, nil]
      # @return [Hash]
      def build_item_finish(item_uuid:, launch_uuid:, end_time:, status: nil)
        Service::PayloadBuilder.build_item_finish(
          item_uuid: item_uuid,
          launch_uuid: launch_uuid,
          end_time: end_time,
          status: status
        )
      end

      # @param launch_uuid [String, nil]
      # @param item_uuid [String, nil]
      # @param time [Time, String, Integer, Float]
      # @param message [String]
      # @param level [String, Symbol]
      # @param file_name [String, nil]
      # @return [Hash]
      def build_log_entry(launch_uuid:, item_uuid:, time:, message:, level:, file_name: nil)
        Service::PayloadBuilder.build_log_entry(
          launch_uuid: launch_uuid,
          item_uuid: item_uuid,
          time: time,
          message: message,
          level: level,
          file_name: file_name
        )
      end

      # @param feature_uri [String]
      # @param scenario_line [Integer, String]
      # @return [String]
      def build_code_ref(feature_uri:, scenario_line:)
        Service::PayloadBuilder.build_code_ref(feature_uri: feature_uri, scenario_line: scenario_line)
      end

      # @param explicit_id [String, nil]
      # @param code_ref [String]
      # @param parameters [Hash, Array<Hash>, nil]
      # @return [String]
      def build_test_case_id(explicit_id: nil, code_ref:, parameters: nil)
        Service::PayloadBuilder.build_test_case_id(explicit_id: explicit_id, code_ref: code_ref, parameters: parameters)
      end

      # @param code_ref [String]
      # @param parameters [Hash, Array<Hash>, nil]
      # @return [String]
      def build_unique_id(code_ref:, parameters: nil)
        Service::PayloadBuilder.build_unique_id(code_ref: code_ref, parameters: parameters)
      end

      # @param parameters [Hash, Array<Hash>, nil]
      # @return [Hash, Array<Hash>, nil]
      def normalize_parameters(parameters)
        Service::PayloadBuilder.normalize_parameters(parameters)
      end

      # @param status [String, Symbol, nil]
      # @return [String, nil]
      def normalize_status(status)
        Service::PayloadBuilder.normalize_status(status)
      end

      # @param base [String]
      # @param parameters [Hash, Array<Hash>, nil]
      # @return [String]
      def append_parameters_identifier(base, parameters)
        Service::PayloadBuilder.append_parameters_identifier(base, parameters)
      end

      # @param value [Array<Hash>, nil]
      # @return [Array<Hash>, nil]
      def compact_array(value)
        value.nil? ? nil : Service::PayloadBuilder.normalize_attributes(value)
      end

      # @param value [Hash]
      # @return [Hash]
      def stringify_hash(value)
        Service::PayloadBuilder.stringify_hash(value)
      end

      # @param parameters [Hash, Array<Hash>, nil]
      # @return [Array<Array<String>>]
      def identifier_pairs(parameters)
        Service::PayloadBuilder.identifier_pairs(parameters)
      end
    end
  end
end
