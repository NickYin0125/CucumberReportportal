# frozen_string_literal: true

require "json"
require "uri"

module Automation
  # Redacts common credentials from structured HTTP evidence and text.
  #
  # This is intended for HTTP request/response evidence, not as a universal
  # sanitizer for arbitrary free text, video, or attachments.
  class EvidenceRedactor
    DEFAULT_SENSITIVE_KEYS = %w[
      authorization proxy-authorization cookie set-cookie token access_token
      refresh_token api_key x-api-key password secret client_secret
    ].freeze
    MASK = "[REDACTED]".freeze
    BEARER_PATTERN = /\bBearer[ \t]+[^\s,;&"'<>]+/i

    # @param sensitive_keys [Array<String, Symbol>] Additional sensitive key names.
    # @return [EvidenceRedactor]
    def initialize(sensitive_keys: [])
      keys = DEFAULT_SENSITIVE_KEYS + Array(sensitive_keys).map { |key| valid_utf8(key.to_s) }
      @sensitive_keys = keys.map { |key| normalize_key(key).freeze }.reject(&:empty?).uniq.freeze
      alternatives = keys.map do |key|
        key.split(/[^a-z0-9]+/i).map { |part| Regexp.escape(part) }.join("[-_.]?")
      end.reject(&:empty?).uniq
      value_pattern = /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|Bearer[ \t]+[^\s,;&"'<>]+|[^\s,;&"'<>]+/
      @key_value_pattern = Regexp.new(
        "(\\b(?:#{alternatives.join('|')})\\b)([ \\t]*[:=][ \\t]*)(?:#{value_pattern.source})",
        Regexp::IGNORECASE
      ).freeze
    end

    # @param value [Object] A nested Hash, Array, or scalar value.
    # @return [Object] A recursively redacted copy; the input is not modified.
    def redact(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, item), output|
          output[key] = sensitive_key?(key) ? MASK : redact(item)
        end
      when Array
        value.map { |item| redact(item) }
      when String
        redact_text(value)
      else
        value
      end
    end

    # @param url [#to_s] URL to sanitize.
    # @return [String] URL with userinfo and sensitive query values masked.
    def redact_url(url)
      original = valid_utf8(url.to_s)
      uri = URI.parse(original)
      if uri.userinfo
        uri.user = nil
        uri.password = nil
      end
      uri.query = redact_query(uri.query) if uri.query
      uri.path = redact_plain_segment(uri.path) unless uri.path.nil?
      uri.fragment = redact_plain_segment(uri.fragment) if uri.fragment
      uri.to_s
    rescue URI::Error, ArgumentError
      fallback_redact_url(original)
    end

    # @param text [#to_s] Text to sanitize, including JSON and bearer values.
    # @return [String] Redacted text.
    def redact_text(text)
      source = valid_utf8(text.to_s)
      parsed = JSON.parse(source)
      return JSON.generate(redact(parsed)) if parsed.is_a?(Hash) || parsed.is_a?(Array)

      redact_plain_text(source)
    rescue JSON::ParserError, JSON::GeneratorError
      redact_plain_text(source)
    end

    private

    def sensitive_key?(key)
      @sensitive_keys.include?(normalize_key(key))
    end

    def normalize_key(key)
      valid_utf8(key.to_s).downcase.gsub(/[^a-z0-9]/, "")
    end

    def redact_plain_text(text)
      url_pattern = %r{(?:https?:)?//[^\s"'<>]+}i
      cursor = 0
      output = +""
      text.to_enum(:scan, url_pattern).each do
        match = Regexp.last_match
        output << redact_plain_segment(text[cursor...match.begin(0)])
        output << redact_url(match[0])
        cursor = match.end(0)
      end
      output << redact_plain_segment(text[cursor..])
      output
    end

    def redact_plain_segment(text)
      text.gsub(@key_value_pattern) { "#{Regexp.last_match(1)}#{Regexp.last_match(2)}#{MASK}" }
          .gsub(BEARER_PATTERN) { "Bearer #{MASK}" }
    end

    def valid_utf8(text)
      text = text.dup.force_encoding(Encoding::UTF_8) if text.encoding == Encoding::ASCII_8BIT
      text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
    end

    def redact_query(query)
      query.split("&", -1).map do |pair|
        key, raw_value = pair.split("=", 2)
        next pair if raw_value.nil?

        decoded_key = URI.decode_www_form_component(key)
        if sensitive_key?(decoded_key)
          "#{key}=#{URI.encode_www_form_component(MASK)}"
        else
          decoded_value = valid_utf8(URI.decode_www_form_component(raw_value))
          redacted_value = redact_plain_segment(decoded_value)
          redacted_value == decoded_value ? pair : "#{key}=#{URI.encode_www_form_component(redacted_value)}"
        end
      rescue ArgumentError
        if sensitive_key?(key)
          "#{key}=#{URI.encode_www_form_component(MASK)}"
        else
          pair
        end
      end.join("&")
    end

    def fallback_redact_url(original)
      safe = original.gsub(%r{((?:[a-z][a-z0-9+.-]*:)?//)[^/?#]*@}i, "\\1")
      base, fragment = safe.split("#", 2)
      path, query = base.split("?", 2)
      path = redact_plain_segment(path)
      path += "?#{redact_query(query)}" unless query.nil?
      path += "##{redact_plain_segment(fragment)}" unless fragment.nil?
      path
    end
  end
end
