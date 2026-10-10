# frozen_string_literal: true

module Automation
  # Shared exact-match policy for credential-like key names.
  module CredentialKeys
    DEFAULT_KEYS = %w[
      authorization proxy-authorization cookie set-cookie token access_token
      refresh_token api_key apikey x-api-key password passwd pwd secret
      client_secret secret_access_key session_token access_token clientsecret
    ].freeze

    module_function

    # @param key [Object]
    # @return [Boolean] Whether the complete normalized key is credential-like.
    def sensitive?(key)
      normalized = normalize(key)
      !normalized.empty? && NORMALIZED_KEYS.include?(normalized)
    end

    # @param key [Object]
    # @return [String] ASCII case-folded key with separators removed.
    def normalize(key)
      key.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end

    NORMALIZED_KEYS = DEFAULT_KEYS.map { |key| normalize(key).freeze }.uniq.freeze
    private_constant :NORMALIZED_KEYS
  end
end
