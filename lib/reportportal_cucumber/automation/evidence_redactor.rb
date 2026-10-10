# frozen_string_literal: true

require "json"
require "uri"
require_relative "credential_keys"

module Automation
  # Redacts common credentials from structured HTTP evidence and text.
  #
  # This is intended for HTTP request/response evidence, not as a universal
  # sanitizer for arbitrary free text, video, or attachments.
  class EvidenceRedactor
    DEFAULT_SENSITIVE_KEYS = CredentialKeys::DEFAULT_KEYS
    MASK = "[REDACTED]".freeze
    BEARER_PATTERN = /\bBearer[ \t]+[^\s,;&"'<>]+/i

    # @param sensitive_keys [Array<String, Symbol>] Additional sensitive key names.
    # @return [EvidenceRedactor]
    def initialize(sensitive_keys: [])
      keys = DEFAULT_SENSITIVE_KEYS + Array(sensitive_keys).map { |key| valid_utf8(key.to_s) }
      @sensitive_keys = keys.map { |key| normalize_key(key).freeze }.reject(&:empty?).uniq.freeze
      alternatives = @sensitive_keys.map do |key|
        key.chars.map { |character| Regexp.escape(character) }.join("[-_.]*")
      end.reject(&:empty?).uniq
      # Consume incomplete quoted values through the bounded input end, even after a dangling escape.
      double_quoted_value = /\\?"(?:\\.|[^"\\]|\\\z)*(?:\\?"|\z)/
      single_quoted_value = /\\?'(?:\\.|[^'\\]|\\\z)*(?:\\?'|\z)/
      value_pattern = Regexp.union(
        double_quoted_value, single_quoted_value,
        /Bearer[ \t]+[^\s,;&"'<>]+/, /[^\s,;&"'<>]+/
      )
      @key_value_pattern = Regexp.new(
        "((?<![a-z0-9_.-])[-_.]*(?:#{alternatives.join('|')})[-_.]*(?![a-z0-9_.-])\\\\?\"?)" \
        "([ \\t\\r\\n]*[:=][ \\t\\r\\n]*)(?:#{value_pattern.source})",
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

    # @param key [Object]
    # @return [Boolean] Whether a key matches the built-in or configured policy.
    def sensitive_key?(key)
      @sensitive_keys.include?(normalize_key(key)) || CredentialKeys.sensitive?(key)
    end

    # @param source [String]
    # @return [Boolean] Whether all JSON string escapes use the strict JSON escape set.
    def valid_json_string_escapes?(source)
      !malformed_json_string_escape?(source)
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
      uri.fragment = redact_fragment(uri.fragment) if uri.fragment
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

    def redact_fragment(fragment)
      json_fragment = redact_encoded_json_fragment(fragment)
      return json_fragment unless json_fragment.nil?

      fragment.split("?", -1).map { |query| redact_fragment_query(query) }.join("?")
    end

    def redact_fragment_query(query)
      json_fragment = redact_encoded_json_fragment(query)
      return json_fragment unless json_fragment.nil?

      query.split(/([&;])/, -1).map do |part|
        if part == "&" || part == ";"
          part
        else
          encoded = redact_encoded_json_fragment(part) || redact_encoded_fragment(part)
          encoded || (part.include?("=") ? redact_query(part) : redact_plain_segment(part))
        end
      end.join
    end

    def redact_encoded_fragment(fragment)
      return unless fragment.include?("%")

      decoded = valid_utf8(URI.decode_www_form_component(fragment))
      sensitive = decoded.split(/[?&;]/, -1).any? do |pair|
        key, value = pair.split("=", 2)
        next false if value.nil?

        sensitive_key?(URI.decode_www_form_component(key))
      rescue ArgumentError
        true
      end
      "[REDACTED]" if sensitive
    rescue ArgumentError
      "[REDACTED]"
    end

    def redact_encoded_json_fragment(fragment)
      return unless fragment.match?(/%[0-9a-f]{2}/i)

      decoded = valid_utf8(URI::DEFAULT_PARSER.unescape(fragment))
      return unless decoded.match?(/\A\s*[\[{]/)
      return "[REDACTED]" if malformed_json_string_escape?(decoded)

      parsed = JSON.parse(decoded, max_nesting: 10)
      safe = redact(parsed)
      return if safe == parsed

      encode_fragment_component(JSON.generate(safe))
    rescue JSON::ParserError, JSON::NestingError, JSON::GeneratorError, ArgumentError, EncodingError
      "[REDACTED]"
    end

    def malformed_json_string_escape?(source)
      source.to_enum(:scan, /"((?:\\.|[^"\\])*)"/).any? do
        body = Regexp.last_match(1)
        index = 0
        malformed = false
        while index < body.length
          if body[index] == "\\"
            escaped = body[index + 1]
            unless %w[" \\ / b f n r t u].include?(escaped)
              malformed = true
              break
            end
            if escaped == "u"
              codepoint = body[index + 2, 4]
              unless codepoint&.match?(/\A[0-9a-f]{4}\z/i)
                malformed = true
                break
              end
              index += 6
            else
              index += 2
            end
          else
            index += 1
          end
        end
        malformed
      end
    end

    def encode_fragment_component(value)
      value.b.bytes.map do |byte|
        character = byte.chr
        if (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5a) ||
           (byte >= 0x61 && byte <= 0x7a) || "-._~".include?(character)
          character
        else
          format("%%%02X", byte)
        end
      end.join
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
