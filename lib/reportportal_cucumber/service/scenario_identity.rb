# frozen_string_literal: true

require "digest/sha1"
require "digest/sha2"
require "json"
require "pathname"
require_relative "payload_builder"

module ReportportalCucumber
  module Service
    # Builds legacy-compatible or deterministic versioned scenario identities.
    module ScenarioIdentity
      STRATEGIES = %w[legacy stable_v1].freeze
      TEST_CASE_DOMAIN = "reportportal-cucumber:stable-v1:test_case\0"
      RETRY_DOMAIN = "reportportal-cucumber:stable-v1:retry\0"

      # Frozen result record for one scenario identity calculation.
      # Legacy results intentionally retain the caller's original parameters object.
      Result = Struct.new(:test_case_id, :unique_id, :parameters, :strategy, :fallback_reason, keyword_init: true) do
        # @param test_case_id [String]
        # @param unique_id [String]
        # @param parameters [Object] Stable results use a detached, deeply frozen canonical value;
        #   legacy results retain the original object, which may remain mutable.
        # @param strategy [String]
        # @param fallback_reason [Symbol, nil]
        # @return [Result] A frozen record; freezing the record does not freeze legacy parameters.
        def initialize(**attributes)
          super
          freeze
        end
      end

      module_function

      # @param strategy [String]
      # @param explicit_id [String, nil]
      # @param code_ref [String, nil]
      # @param parameters [Hash, Array<Hash>, nil]
      # @param feature_uri [String, nil]
      # @param source [Hash, nil]
      # @param root [String]
      # @param namespace [String, nil]
      # @return [Result]
      def build(strategy: "legacy", explicit_id: nil, code_ref:, parameters: nil, feature_uri: nil, source: nil,
                root: Dir.pwd, namespace: nil)
        selected_strategy = strategy.to_s
        unless STRATEGIES.include?(selected_strategy)
          raise ArgumentError, "Unsupported scenario identity strategy"
        end

        return legacy_result(explicit_id, code_ref, parameters) if selected_strategy == "legacy"

        explicit = explicit_id.to_s.strip
        return stable_result({ "kind" => "explicit", "id" => explicit }, parameters, namespace) unless explicit.empty?

        reason = source_fallback_reason(source, feature_uri)
        return legacy_result(explicit_id, code_ref, parameters, reason) if reason

        base = {
          "kind" => "source",
          "feature" => normalized_feature_path(feature_uri, root),
          "rule" => source_value(source, :rule_name).to_s,
          "scenario" => source_value(source, :scenario_name).to_s
        }
        stable_result(base, parameters, namespace)
      end

      # @param explicit_id [String, nil]
      # @param code_ref [String, nil]
      # @param parameters [Object]
      # @param fallback_reason [Symbol, nil]
      # @return [Result]
      def legacy_result(explicit_id, code_ref, parameters, fallback_reason = nil)
        Result.new(
          test_case_id: PayloadBuilder.build_test_case_id(explicit_id: explicit_id, code_ref: code_ref, parameters: parameters),
          unique_id: PayloadBuilder.build_unique_id(code_ref: code_ref, parameters: parameters),
          parameters: parameters,
          strategy: "legacy",
          fallback_reason: fallback_reason
        )
      end
      private_class_method :legacy_result

      # @param base [Hash]
      # @param parameters [Object]
      # @param namespace [String, nil]
      # @return [Result]
      def stable_result(base, parameters, namespace)
        canonical_parameters = canonical_parameters(parameters)
        identity = {
          "version" => 1,
          "namespace" => namespace.to_s,
          "base" => base,
          "parameters" => canonical_parameters
        }
        payload = JSON.generate(identity)
        retry_digest = Digest::SHA256.hexdigest(RETRY_DOMAIN + payload)
        test_case_digest = Digest::SHA256.hexdigest(TEST_CASE_DOMAIN + payload)
        deep_freeze(canonical_parameters)
        Result.new(
          test_case_id: "rp:stable-v1:#{test_case_digest}".freeze,
          unique_id: retry_digest.freeze,
          parameters: canonical_parameters,
          strategy: "stable_v1".freeze,
          fallback_reason: nil
        )
      end
      private_class_method :stable_result

      # @param parameters [Object]
      # @return [Array<Hash>]
      def canonical_parameters(parameters)
        pairs = case parameters
                when nil
                  []
                when Hash
                  parameters.map { |key, value| [key.to_s.dup, scalar_wire_value(value)] }
                when Array
                  parameters.map { |entry| parameter_pair(entry) }
                else
                  [["value", scalar_wire_value(parameters)]]
                end
        pairs.sort_by! { |key, value| [key, value] }
        pairs.map { |key, value| { "key" => key, "value" => value } }
      rescue ArgumentError
        raise
      rescue StandardError
        raise ArgumentError, "Invalid scenario identity parameters"
      end
      private_class_method :canonical_parameters

      # @param entry [Object]
      # @return [Array<String>]
      def parameter_pair(entry)
        unless entry.is_a?(Hash) && !entry.empty?
          raise ArgumentError, "Invalid scenario identity parameters"
        end

        if entry.key?("key") || entry.key?(:key)
          key = entry.key?("key") ? entry["key"] : entry[:key]
          value = entry.key?("value") ? entry["value"] : entry[:value]
          [key.to_s.dup, scalar_wire_value(value)]
        elsif entry.length == 1
          key, value = entry.first
          [key.to_s.dup, scalar_wire_value(value)]
        else
          raise ArgumentError, "Invalid scenario identity parameters"
        end
      end
      private_class_method :parameter_pair

      # @param value [Object]
      # @return [String]
      def scalar_wire_value(value)
        case value
        when Hash, Array
          JSON.generate(canonical_nested(value, {}))
        when String, Symbol, Numeric, TrueClass, FalseClass, NilClass
          value.to_s.dup
        else
          raise ArgumentError, "Invalid scenario identity parameters"
        end
      end
      private_class_method :scalar_wire_value

      # @param value [Object]
      # @param ancestors [Hash]
      # @return [Object]
      def canonical_nested(value, ancestors)
        case value
        when Hash
          guard_cycle(value, ancestors) do
            normalized = {}
            value.each do |key, item|
              normalized_key = key.to_s.dup
              raise ArgumentError, "Invalid scenario identity parameters" if normalized.key?(normalized_key)

              normalized[normalized_key] = canonical_nested(item, ancestors)
            end
            normalized.sort.to_h
          end
        when Array
          guard_cycle(value, ancestors) { value.map { |item| canonical_nested(item, ancestors) } }
        when String, Numeric, TrueClass, FalseClass, NilClass
          value.is_a?(String) ? value.dup : value
        else
          raise ArgumentError, "Invalid scenario identity parameters"
        end
      end
      private_class_method :canonical_nested

      # @param object [Hash, Array]
      # @param ancestors [Hash]
      # @yield
      # @return [Object]
      def guard_cycle(object, ancestors)
        raise ArgumentError, "Invalid scenario identity parameters" if ancestors.key?(object.object_id)

        ancestors[object.object_id] = true
        yield
      ensure
        ancestors.delete(object.object_id)
      end
      private_class_method :guard_cycle

      # @param source [Hash, nil]
      # @param feature_uri [String, nil]
      # @return [Symbol, nil]
      def source_fallback_reason(source, feature_uri)
        return :missing_source unless source.is_a?(Hash) && !source_value(source, :scenario_name).nil?
        return :ambiguous_source if source_value(source, :identity_ambiguous)
        return :missing_source if feature_uri.to_s.strip.empty?

        nil
      end
      private_class_method :source_fallback_reason

      # @param source [Hash]
      # @param key [Symbol]
      # @return [Object]
      def source_value(source, key)
        source.key?(key) ? source[key] : source[key.to_s]
      end
      private_class_method :source_value

      # @param feature_uri [String, nil]
      # @param root [String]
      # @return [String]
      def normalized_feature_path(feature_uri, root)
        base = Pathname.new(File.expand_path(root.to_s))
        path = Pathname.new(File.expand_path(feature_uri.to_s, base.to_s))
        relative = path.relative_path_from(base).to_s
        relative == ".." || relative.start_with?("../") ? path.to_s : relative
      rescue ArgumentError
        raise ArgumentError, "Invalid scenario identity source path"
      end
      private_class_method :normalized_feature_path

      # @param value [Object]
      # @return [Object]
      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, item| deep_freeze(key); deep_freeze(item) }
        when Array
          value.each { |item| deep_freeze(item) }
        end
        value.freeze
      end
      private_class_method :deep_freeze
    end
  end
end
