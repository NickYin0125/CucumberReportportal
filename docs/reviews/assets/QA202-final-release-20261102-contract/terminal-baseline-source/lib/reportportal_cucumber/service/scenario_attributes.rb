# frozen_string_literal: true

require_relative "../automation/credential_keys"

module ReportportalCucumber
  module Service
    # Resolves safe, allowlisted business attributes from defaults and scoped Cucumber tags.
    module ScenarioAttributes
      SCOPES = %w[feature rule scenario examples].freeze
      DEFAULT_ALLOWED_KEYS = %w[component team owner layer priority browser tms].freeze
      RESERVED_KEYS = %w[
        retry wip skip ignore focus only api_key authorization password token secret
        immediateautoanalysis immediatepatternanalysis skippedisnotissue
      ].freeze
      KEY_PATTERN = /\A[a-z][a-z0-9_.-]*\z/.freeze
      MAX_KEY_LENGTH = 512
      MAX_VALUE_LENGTH = 512
      TAG_PATTERN = /\A@([a-z][a-z0-9_.-]*):(.*)\z/im.freeze

      # Immutable result for one scenario-attribute resolution.
      # @!attribute [r] attributes
      #   @return [Array<Hash{String => String}>] Sorted, deeply frozen attribute pairs.
      # @!attribute [r] diagnostics
      #   @return [Array<Hash>] Safe reason/scope/key records.
      Result = Struct.new(:attributes, :diagnostics, keyword_init: true) do
        # @param attributes [Array<Hash>]
        # @param diagnostics [Array<Hash>]
        # @return [Result]
        def initialize(attributes:, diagnostics:)
          super(attributes: attributes, diagnostics: diagnostics)
          freeze
        end
      end

      module_function

      # @param defaults [Hash, Array<Hash>]
      # @param tag_scopes [Hash, nil] Tags grouped by feature, rule, scenario, and examples.
      # @param allowed_keys [Array<String, Symbol>]
      # @param explicit_id [String, nil] The already-selected explicit test-case ID.
      # @return [Result] Detached, deeply frozen attributes and safe diagnostics.
      def build(defaults:, tag_scopes:, allowed_keys:, explicit_id: nil)
        keys = normalize_allowed_keys(allowed_keys)
        diagnostics = []
        defaults_by_key = normalize_defaults(defaults, keys, diagnostics)
        current = defaults_by_key

        if tag_scopes.nil?
          diagnostics << diagnostic(:missing_source, :scenario, nil)
        else
          unless tag_scopes.is_a?(Hash)
            raise ArgumentError, "Invalid scenario attribute tag scopes"
          end

          SCOPES.each do |scope|
            tags = hash_value(tag_scopes, scope)
            next if tags.nil?
            raise ArgumentError, "Invalid scenario attribute tag scopes" unless tags.is_a?(Array)

            candidates = Hash.new { |hash, key| hash[key] = [] }
            tags.each do |tag|
              next unless tag.is_a?(String)

              unless tag.valid_encoding?
                match = tag.b.match(/\A@([a-z][a-z0-9_.-]*):/in)
                key = match && match[1].force_encoding(Encoding::UTF_8).downcase
                diagnostics << diagnostic(:invalid_value, scope.to_sym, key) if key && keys.include?(key) && key != "tms"
                next
              end

              match = TAG_PATTERN.match(tag)
              next unless match

              key = match[1].downcase
              next unless keys.include?(key) && key != "tms"

              value = valid_value(match[2])
              unless value
                diagnostics << diagnostic(:invalid_value, scope.to_sym, key)
                next
              end
              candidates[key] << value
            end

            candidates.each do |key, values|
              distinct = values.uniq
              if distinct.length > 1
                diagnostics << diagnostic(:conflict, scope.to_sym, key)
                next
              end

              current[key] = distinct.first
            end
          end
        end

        current.delete("tms")
        if keys.include?("tms") && !explicit_id.nil?
          value = valid_value(explicit_id)
          if value
            current["tms"] = value
          else
            diagnostics << diagnostic(:invalid_value, :explicit_id, "tms")
          end
        end

        attributes = current.sort_by { |key, _value| key }.map do |key, value|
          { "key" => key.dup.freeze, "value" => value.dup.freeze }.freeze
        end.freeze
        diagnostics.sort_by! { |entry| [entry[:scope].to_s, entry[:key].to_s, entry[:reason].to_s] }
        Result.new(attributes: attributes, diagnostics: deep_freeze(diagnostics))
      end

      # @param allowed_keys [Array<String, Symbol>]
      # @return [Array<String>] Normalized and frozen business keys.
      # @raise [ArgumentError] When a key is invalid, reserved, or duplicates another normalized key.
      def normalize_allowed_keys(allowed_keys)
        raise ArgumentError, "Invalid scenario attribute allowlist" unless allowed_keys.is_a?(Array)

        normalized = allowed_keys.map do |key|
          string = safe_key_string(key)
          string = string&.downcase
          unless string && string.length <= MAX_KEY_LENGTH && KEY_PATTERN.match?(string)
            raise ArgumentError, "Invalid scenario attribute allowlist"
          end
          if RESERVED_KEYS.include?(string) || Automation::CredentialKeys.sensitive?(string)
            raise ArgumentError, "Reserved scenario attribute key"
          end

          string.freeze
        end
        raise ArgumentError, "Invalid scenario attribute allowlist" unless normalized.uniq.length == normalized.length

        normalized.freeze
      end

      # @param value [Object]
      # @return [String, nil] A detached valid value, or nil when invalid.
      def valid_value(value)
        return unless value.is_a?(String)

        utf8_value = value.dup.force_encoding(Encoding::UTF_8)
        return unless utf8_value.valid_encoding?
        return if utf8_value.match?(/[\x00-\x1f\x7f]/)

        stripped = utf8_value.strip
        return if stripped.empty? || stripped.length > MAX_VALUE_LENGTH || stripped.include?(":")

        stripped.dup
      end
      private_class_method :valid_value

      # @param defaults [Hash, Array<Hash>] Hashes are key/value maps; array entries may be pair records.
      # @param keys [Array<String>]
      # @param diagnostics [Array<Hash>]
      # @return [Hash{String => String}]
      def normalize_defaults(defaults, keys, diagnostics)
        unless defaults.is_a?(Hash) || defaults.is_a?(Array)
          raise ArgumentError, "Invalid scenario attribute defaults"
        end

        entries = defaults.is_a?(Hash) ? defaults.map { |key, value| { "key" => key, "value" => value } } : defaults
        grouped = Hash.new { |hash, key| hash[key] = [] }
        entries.each do |entry|
          pair = default_pair(entry)
          unless pair
            diagnostics << diagnostic(:invalid_entry, :default, nil)
            next
          end
          key, raw_value = pair
          key = safe_key_string(key)&.downcase
          next unless key && keys.include?(key) && key != "tms"

          value = valid_value(raw_value)
          unless value
            diagnostics << diagnostic(:invalid_value, :default, key)
            next
          end
          grouped[key] << value
        end
        grouped.sort.each_with_object({}) do |(key, values), chosen|
          distinct = values.uniq
          if distinct.length > 1
            diagnostics << diagnostic(:conflict, :default, key)
          else
            chosen[key] = distinct.first
          end
        end
      end
      private_class_method :normalize_defaults

      # @param entry [Object]
      # @return [Array<Object>, nil] A key/value pair from one supported default entry.
      def default_pair(entry)
        return unless entry.is_a?(Hash)

        if entry.key?("key") || entry.key?(:key)
          [hash_value(entry, "key"), hash_value(entry, "value")]
        elsif entry.length == 1
          entry.first
        end
      end
      private_class_method :default_pair

      # @param hash [Hash]
      # @param key [String]
      # @return [Object, nil]
      def hash_value(hash, key)
        hash.key?(key) ? hash[key] : hash[key.to_sym]
      end
      private_class_method :hash_value

      # @param key [Object]
      # @return [String, nil] Detached, stripped, lowercase ASCII candidate key.
      def safe_key_string(key)
        string = if key.is_a?(String) && key.valid_encoding?
                   key.dup
                 elsif key.is_a?(Symbol)
                   key.to_s
                 end
        return unless string&.ascii_only?

        string.strip.downcase
      end
      private_class_method :safe_key_string

      # @param reason [Symbol]
      # @param scope [Symbol]
      # @param key [String, nil]
      # @return [Hash]
      def diagnostic(reason, scope, key)
        { reason: reason, scope: scope, key: key&.dup&.freeze }.freeze
      end
      private_class_method :diagnostic

      # @param value [Object]
      # @return [Object] The same value with all nested members frozen.
      def deep_freeze(value)
        case value
        when Array then value.each { |item| deep_freeze(item) }.freeze
        when Hash then value.each { |key, item| deep_freeze(key); deep_freeze(item) }.freeze
        when String then value.freeze
        else value.freeze
        end
      end
      private_class_method :deep_freeze
    end
  end
end
