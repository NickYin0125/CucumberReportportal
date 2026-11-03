# frozen_string_literal: true

require "json"
require "strscan"
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
    BEARER_PATTERN = /\b(?:Bearer[ \t]+)+[^\s,;&"'<>]+/i
    MAX_INPUT_BYTES = 64 * 1024
    MAX_STRUCTURE_BYTES = 256 * 1024
    MAX_STRUCTURE_NODES = 1024
    MAX_STRUCTURE_DEPTH = 10
    OMITTED = "[REDACTED] [evidence omitted: unsafe or oversized input]".freeze

    class UnsafeInput < StandardError; end
    private_constant :UnsafeInput

    escaped_quote = Regexp.escape("\\") + '[\r\n]*"'
    escaped_body = [Regexp.escape("\\" * 4), Regexp.escape("\\" * 3 + '"'),
                    "#{Regexp.escape("\\" * 2)}[^\\\\]", /\\[^"\\]/.source, /[^"\\]/.source].join("|")
    BOUNDARY_KEY_PATTERN = /"(?:\\.|[^"\\])*"(?=[ \t\r\n]*[:=])/m.freeze
    BOUNDARY_ENCODED_KEY_PATTERN = Regexp.new(
      "#{escaped_quote}(?:#{escaped_body})*#{escaped_quote}(?=[ \\t\\r\\n]*[:=])",
      Regexp::MULTILINE
    ).freeze
    BOUNDARY_KEY_SEPARATOR = /[ \t\r\n]*[:=][ \t\r\n]*/.freeze
    BOUNDARY_KEY_CHUNK_CHARS = 256
    BOUNDARY_ESCAPED_QUOTE_PATTERN = Regexp.new("\\G#{escaped_quote}", Regexp::MULTILINE).freeze
    BOUNDARY_ESCAPED_VALUE_PATTERN = Regexp.new(
      "\\G#{escaped_quote}(?:#{escaped_body})*(?:#{escaped_quote}|\\z)", Regexp::MULTILINE
    ).freeze
    PERCENT_ESCAPE = /%[0-9a-f]{2}/i.freeze
    PLAIN_TOKEN = /[^\s"'<>]+/.freeze
    JSON_UNICODE_ESCAPE = /\\u([0-9a-f]{4})/i.freeze
    COMPLETE_MASK = /\A(?:\\?["']\[REDACTED\]\\?["']|\[REDACTED\][\]},)]*)\z/.freeze
    MAX_PERCENT_DECODE_PASSES = 3
    private_constant :BOUNDARY_KEY_PATTERN, :BOUNDARY_ENCODED_KEY_PATTERN,
                     :BOUNDARY_KEY_SEPARATOR, :BOUNDARY_KEY_CHUNK_CHARS,
                     :BOUNDARY_ESCAPED_QUOTE_PATTERN, :BOUNDARY_ESCAPED_VALUE_PATTERN,
                     :PERCENT_ESCAPE, :PLAIN_TOKEN, :JSON_UNICODE_ESCAPE, :COMPLETE_MASK, :MAX_PERCENT_DECODE_PASSES

    # @param sensitive_keys [Array<String, Symbol>] Additional sensitive key names.
    # @return [EvidenceRedactor]
    def initialize(sensitive_keys: [])
      keys = DEFAULT_SENSITIVE_KEYS + Array(sensitive_keys).map { |key| valid_utf8(key.to_s) }
      @sensitive_keys = keys.map { |key| normalize_key(key).freeze }.reject(&:empty?).uniq.freeze
      @boundary_key_limit = @sensitive_keys.map(&:length).max || 0
      alternatives = @sensitive_keys.map do |key|
        key.chars.map { |character| Regexp.escape(character) }.join("[-_.]*")
      end.reject(&:empty?).uniq
      # Consume incomplete quoted values through the bounded input end, even after a dangling escape.
      double_quoted_value = /\\?"(?:\\.|[^"\\]|\\\z)*(?:\\?"|\z)/
      single_quoted_value = /\\?'(?:\\.|[^'\\]|\\\z)*(?:\\?'|\z)/
      value_patterns = [
        double_quoted_value, single_quoted_value,
        BEARER_PATTERN, /[^\s,;&"'<>]+/
      ]
      value_pattern = Regexp.union(value_patterns)
      key_pattern = "((?<![a-z0-9_.-])[-_.]*(?:#{alternatives.join('|')})[-_.]*(?![a-z0-9_.-])\\\\?\"?)" \
                    "([ \\t\\r\\n]*[:=][ \\t\\r\\n]*)"
      @key_value_pattern = Regexp.new("#{key_pattern}(?:#{value_pattern.source})", Regexp::IGNORECASE).freeze
      @boundary_plain_key_pattern = Regexp.new(key_pattern, Regexp::IGNORECASE).freeze
      # Detect malformed line breaks conservatively; only the unchanged sanitizer emits text.
      @boundary_value_pattern = Regexp.new(
        "\\G(?:#{value_patterns.map(&:source).join('|')})", Regexp::IGNORECASE | Regexp::MULTILINE
      ).freeze
    end

    # @param value [Object] A nested Hash, Array, or scalar value.
    # @return [Object] A bounded redacted copy, or an omission marker for unsafe input.
    def redact(value)
      redact_value(value, new_budget, 0)
    rescue UnsafeInput, JSON::GeneratorError, EncodingError
      OMITTED
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
      original = bounded_source(url.to_s)
      safe = begin
        uri = URI.parse(original)
        if uri.userinfo
          uri.user = nil
          uri.password = nil
        end
        uri.query = redact_query(uri.query) if uri.query
        uri.path = redact_url_path(uri.path) unless uri.path.nil?
        uri.fragment = redact_fragment(uri.fragment) if uri.fragment
        uri.to_s
      rescue URI::Error, ArgumentError
        fallback_redact_url(original)
      end
      # Decoding must not reveal a credential that the component rules missed.
      encoded_credential_exposed?(safe) ? OMITTED : safe
    rescue UnsafeInput, EncodingError
      OMITTED
    end

    # @param text [#to_s] Text to sanitize, including JSON and bearer values.
    # @return [String] Redacted text, or an omission marker for ambiguous/oversized input.
    def redact_text(text)
      sanitize_text(text.to_s, new_budget, 0)
    rescue UnsafeInput, JSON::GeneratorError, EncodingError
      OMITTED
    end

    # @param units [Array<String>] Original independently redacted failure units.
    # @return [Boolean] Whether a credential requires cross-unit safety context.
    def cross_unit_credential?(units)
      parts = units.map { |part| valid_utf8(part) }
      return false if parts.length < 2
      return true if credential_crosses_units?(parts)

      # A percent-encoded key may end one unit while its value starts the next.
      return false unless parts.any? { |part| part.match?(PERCENT_ESCAPE) }

      credential_crosses_units?(parts.map { |part| percent_decoded(part) })
    end

    private

    def credential_crosses_units?(parts)
      # Assembly and lexical scans still scale with input; only key decoding is bounded.
      source = parts.join("\n")
      boundaries = []
      offset = 0
      parts[0...-1].each do |part|
        offset += part.bytesize
        boundaries << offset
        offset += 1
      end
      scanner = StringScanner.new(source)
      while scanner.skip_until(@boundary_plain_key_pattern)
        start = scanner.pos - scanner.matched_size
        boundary = boundaries.bsearch { |position| position >= start }
        break unless boundary

        finish = boundary_value_end(scanner, boundary)
        return true if finish && crosses_boundary?(boundaries, start, finish)
      end

      # Parse key tokens only: incomplete JSON and trailing stack frames must not
      # hide a credential. Keep original offsets, including unit separator newlines.
      [BOUNDARY_ENCODED_KEY_PATTERN, BOUNDARY_KEY_PATTERN].each do |pattern|
        scanner.reset
        while scanner.skip_until(pattern)
          start = scanner.pos - scanner.matched_size
          boundary = boundaries.bsearch { |position| position >= start }
          break unless boundary

          next unless boundary_sensitive_key?(source, start, scanner.pos, encoded: pattern == BOUNDARY_ENCODED_KEY_PATTERN)

          scanner.skip(BOUNDARY_KEY_SEPARATOR)
          finish = boundary_value_end(scanner, boundary)
          return true if finish && crosses_boundary?(boundaries, start, finish)
        end
      end
      false
    end

    def crosses_boundary?(boundaries, start, finish)
      boundary = boundaries.bsearch { |position| position >= start }
      boundary && boundary < finish
    end

    def boundary_value_end(scanner, boundary)
      return boundary_structure_end(scanner, boundary) if scanner.match?(/[\[{]/)

      pattern = scanner.match?(BOUNDARY_ESCAPED_QUOTE_PATTERN) ? BOUNDARY_ESCAPED_VALUE_PATTERN : @boundary_value_pattern
      scanner.pos if scanner.skip(pattern)
    end

    def boundary_structure_end(scanner, boundary)
      closing = scanner.peek(1) == "[" ? "]" : "}"
      depth = 0
      begin
        character = scanner.peek(1)
        if scanner.match?(BOUNDARY_ESCAPED_QUOTE_PATTERN)
          scanner.getch unless scanner.skip(BOUNDARY_ESCAPED_VALUE_PATTERN)
        elsif character == '"' || character == "'"
          scanner.getch unless scanner.skip(@boundary_value_pattern)
        else
          scanner.getch
          depth += 1 if character == "[" || character == "{"
          depth -= 1 if (character == "]" || character == "}") && (depth > 1 || character == closing)
        end
      end while depth.positive? && !scanner.eos? && scanner.pos <= boundary
      scanner.pos
    end

    def boundary_sensitive_key?(source, start, finish, encoded:)
      characters = boundary_key_characters(source, start, finish, wrapped: encoded)
      characters = decoded_boundary_key_characters(characters)
      if encoded
        characters = characters.lazy.reject { |character| character == "\r" || character == "\n" }
        characters = decoded_boundary_key_characters(characters)
      end
      normalized_boundary_key?(characters)
    rescue JSON::ParserError, JSON::NestingError
      normalized_boundary_key?(boundary_key_characters(source, start, finish))
    end

    def boundary_key_characters(source, start, finish, wrapped: false)
      Enumerator.new do |output|
        scanner = StringScanner.new(source)
        scanner.pos = start
        output << '"' if wrapped
        while scanner.pos < finish
          character = scanner.getch
          # Compact only the detector stream, not the evidence or byte offsets.
          output << character unless character == "\r" || character == "\n"
        end
        output << '"' if wrapped
      end
    end

    def decoded_boundary_key_characters(characters)
      Enumerator.new do |output|
        raise JSON::ParserError unless characters.next == '"'

        while (character = characters.next) != '"'
          if character == "\\"
            escape = character + characters.next
            if escape == "\\u"
              escape << boundary_unicode_digits(characters)
              if escape[2, 4].to_i(16).between?(0xd800, 0xdbff)
                raise JSON::ParserError unless characters.next == "\\" && characters.next == "u"

                escape << "\\u" << boundary_unicode_digits(characters)
              end
            end
            JSON.parse('"' + escape + '"').each_char { |decoded| output << decoded }
          else
            output << character
          end
        end
      rescue StopIteration
        raise JSON::ParserError
      end
    end

    def boundary_unicode_digits(characters)
      digits = 4.times.map { characters.next }.join
      raise JSON::ParserError unless digits.match?(/\A[0-9a-f]{4}\z/i)

      digits
    end

    def normalized_boundary_key?(characters)
      # Reuse the exact policy in fixed-size chunks. Keep at most one chunk
      # beyond the longest configured key, and never accept a mere prefix.
      normalized = +""
      characters.each_slice(BOUNDARY_KEY_CHUNK_CHARS) do |chunk|
        normalized << normalize_key(chunk.join)
        return false if normalized.length > @boundary_key_limit
      end
      sensitive_key?(normalized)
    end

    def new_budget
      { nodes: MAX_STRUCTURE_NODES, bytes: MAX_STRUCTURE_BYTES }
    end

    def consume_node(budget, depth)
      raise UnsafeInput if depth > MAX_STRUCTURE_DEPTH || budget[:nodes] <= 0

      budget[:nodes] -= 1
    end

    def bounded_source(text, budget = nil)
      raise UnsafeInput if text.bytesize > MAX_INPUT_BYTES

      source = valid_utf8(text)
      raise UnsafeInput if source.bytesize > MAX_INPUT_BYTES

      if budget
        budget[:bytes] -= source.bytesize
        raise UnsafeInput if budget[:bytes] < 0
      end
      source
    end

    def redact_value(value, budget, depth, urls: true)
      consume_node(budget, depth)
      case value
      when Hash
        value.each_with_object({}) do |(key, item), output|
          raise UnsafeInput unless key.is_a?(String) || key.is_a?(Symbol)

          consume_node(budget, depth + 1)
          raw_key = bounded_source(key.to_s, budget)
          raise UnsafeInput if raw_key.include?("\\")

          safe_key_text = sanitize_text(raw_key, budget, depth + 1, urls: urls)
          safe_key = key.is_a?(Symbol) && safe_key_text == raw_key ? key : safe_key_text
          output[safe_key] = sensitive_key?(raw_key) ? MASK : redact_value(item, budget, depth + 1, urls: urls)
        end
      when Array
        value.map { |item| redact_value(item, budget, depth + 1, urls: urls) }
      when String
        sanitize_text(value, budget, depth, urls: urls)
      when Integer
        raise UnsafeInput if value.bit_length > 10_000

        budget[:bytes] -= value.bit_length + 2
        raise UnsafeInput if budget[:bytes] < 0

        value
      when Float
        budget[:bytes] -= 32
        raise UnsafeInput if budget[:bytes] < 0

        value.finite? ? value : OMITTED
      when Symbol
        sanitize_text(value.to_s, budget, depth, urls: urls)
      when TrueClass, FalseClass, NilClass
        value
      else
        OMITTED
      end
    end

    def sanitize_text(text, budget, depth, urls: true)
      consume_node(budget, depth)
      source = bounded_source(text, budget)
      begin
        raise JSON::ParserError unless valid_json_string_escapes?(source)

        parsed = JSON.parse(source, max_nesting: MAX_STRUCTURE_DEPTH)
        if parsed.is_a?(Hash) || parsed.is_a?(Array)
          return JSON.generate(redact_value(parsed, budget, depth + 1, urls: urls))
        end
        return sanitize_text(parsed, budget, depth + 1, urls: urls) if parsed.is_a?(String)
      rescue JSON::ParserError
        # Never send ambiguous JSON to the regex fallback, even if preview clipping
        # would hide the escape that makes a credential key unrecognizable.
        return OMITTED if source.match?(/\A\s*[\[{]/) || ambiguous_embedded_json?(source)
      end
      # Nested URLs in encoded URL components are ambiguous; do not recursively
      # re-enter URL parsing with a fresh traversal budget.
      return OMITTED if !urls && source.match?(%r{(?:https?:)?//}i)

      urls ? redact_plain_text(source) : redact_plain_segment(source)
    end

    def ambiguous_embedded_json?(source)
      # Missing opening braces still leave escaped credential keys ambiguous.
      if source.include?("\\")
        separator = [source.rindex(":"), source.rindex("=")].compact.max
        escaped_key = [source.index('"'), source.index("'"), source.index("\\u")].compact.min
        return true if separator && escaped_key && escaped_key < separator
      end

      brackets = []
      quote = nil
      index = 0
      while index < source.bytesize
        byte = source.getbyte(index)
        return true if byte == 92 && !brackets.empty?

        if quote
          quote = nil if byte == quote
        elsif !brackets.empty? && (byte == 34 || byte == 39)
          quote = byte
        elsif byte == 123 || byte == 91
          return true if brackets.length >= MAX_STRUCTURE_DEPTH

          brackets << (byte == 123 ? 125 : 93)
        elsif byte == brackets.last
          brackets.pop
        end
        index += 1
      end
      false
    end

    def normalize_key(key)
      valid_utf8(key.to_s).downcase.gsub(/[^a-z0-9]/, "")
    end

    def redact_plain_text(text)
      raise UnsafeInput if encoded_credential_split?(text)

      url_pattern = %r{(?:https?:)?//[^\s"'<>]+}i
      cursor = 0
      output = +""
      text.to_enum(:scan, url_pattern).each do
        match = Regexp.last_match
        output << redact_plain_text_segment(text[cursor...match.begin(0)])
        output << redact_url(match[0])
        cursor = match.end(0)
      end
      output << redact_plain_text_segment(text[cursor..])
      # Fail closed when decoding still reveals a credential, such as a key and
      # value split by whitespace or a newline inside an incomplete encoded token.
      raise UnsafeInput if encoded_credential_exposed?(output)

      output
    end

    def redact_plain_text_segment(text)
      safe = redact_plain_segment(text)
      return safe unless safe.match?(PERCENT_ESCAPE)

      # Whitespace can end a URL token early, leaving its encoded query or fragment
      # here. Give such tokens the URL component rules instead of literal matching.
      safe.gsub(PLAIN_TOKEN) do |token|
        token.match?(PERCENT_ESCAPE) ? redact_encoded_text_token(token) : token
      end
    end

    def redact_encoded_text_token(token)
      base, fragment = token.split("#", 2)
      safe = base.split("?", -1).map { |part| redact_fragment_query(part) }.join("?")
      fragment.nil? ? safe : "#{safe}##{redact_fragment(fragment)}"
    rescue ArgumentError, EncodingError
      MASK
    end

    def encoded_credential_split?(text)
      return false unless text.match?(PERCENT_ESCAPE)

      # Token rules cannot see a value that follows an encoded key after whitespace.
      text.split(/\s+/).each_cons(2).any? do |token, following|
        token.match?(PERCENT_ESCAPE) &&
          credential_crosses_units?([percent_decoded(token), percent_decoded(following)])
      end
    end

    def encoded_credential_exposed?(text)
      return false unless text.match?(PERCENT_ESCAPE)

      decoded = percent_decoded(text)
      # Residual escapes exceed the inspection budget; withhold rather than
      # accepting a credential that another decoding pass could reveal.
      return true if decoded.match?(PERCENT_ESCAPE)

      decoded = json_unescaped(decoded)
      exposed_value = decoded.to_enum(:scan, @key_value_pattern).any? do
        match = Regexp.last_match
        value = match[0][(match[1].length + match[2].length)..]
        !value.match?(COMPLETE_MASK)
      end
      return true if exposed_value
      return true if decoded.to_enum(:scan, BEARER_PATTERN).any? do
        !Regexp.last_match(0).sub(/\A(?:Bearer[ \t]+)+/i, "").match?(COMPLETE_MASK)
      end

      # Quoted JSON keys use the same normalization as structured evidence, not
      # just the narrower plain-text regex (e.g. "pass word" is a sensitive key).
      [BOUNDARY_KEY_PATTERN, BOUNDARY_ENCODED_KEY_PATTERN].any? do |pattern|
        scanner = StringScanner.new(decoded)
        exposed = false
        while scanner.skip_until(pattern)
          start = scanner.pos - scanner.matched_size
          next unless boundary_sensitive_key?(decoded, start, scanner.pos, encoded: pattern == BOUNDARY_ENCODED_KEY_PATTERN)

          scanner.skip(BOUNDARY_KEY_SEPARATOR)
          value = scanner.scan(@boundary_value_pattern)
          unless value&.match?(COMPLETE_MASK)
            exposed = true
            break
          end
        end
        exposed
      end
    end

    def json_unescaped(text)
      text.gsub(JSON_UNICODE_ESCAPE) do
        codepoint = Regexp.last_match(1).to_i(16)
        codepoint.between?(0xd800, 0xdfff) ? Regexp.last_match(0) : codepoint.chr(Encoding::UTF_8)
      end
    end

    def percent_decoded(text)
      decoded = text
      MAX_PERCENT_DECODE_PASSES.times do
        break unless decoded.match?(PERCENT_ESCAPE)

        decoded = valid_utf8(URI::DEFAULT_PARSER.unescape(decoded))
      end
      decoded
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
        next redact_encoded_component(pair) if raw_value.nil? && pair.match?(PERCENT_ESCAPE)
        next pair if raw_value.nil?

        decoded_key = URI.decode_www_form_component(key)
        if sensitive_key?(decoded_key)
          "#{key}=#{URI.encode_www_form_component(MASK)}"
        else
          decoded_value = valid_utf8(URI.decode_www_form_component(raw_value))
          redacted_value = sanitize_text(decoded_value, new_budget, 0, urls: false)
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

    def redact_url_path(path)
      safe = redact_plain_segment(path)
      return safe unless safe.match?(PERCENT_ESCAPE)

      safe.split("/", -1).map do |segment|
        segment.match?(PERCENT_ESCAPE) ? redact_encoded_component(segment) : segment
      end.join("/")
    end

    # Applies the encoded fragment rules to one path segment or valueless query part.
    def redact_encoded_component(component)
      # Without a key separator or bearer scheme there is no credential syntax to mask,
      # so route templates such as %7Bid%7D stay readable.
      return component unless json_unescaped(percent_decoded(component)).match?(/[:=]|bearer/i)

      safe = redact_encoded_json_fragment(component) || redact_encoded_fragment(component) || component
      safe == MASK ? URI.encode_www_form_component(MASK) : safe
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
      return MASK if sensitive

      safe = sanitize_text(decoded, new_budget, 0, urls: false)
      encode_fragment_component(safe) unless safe == decoded
    rescue ArgumentError, UnsafeInput
      "[REDACTED]"
    end

    def redact_encoded_json_fragment(fragment)
      return unless fragment.match?(/%[0-9a-f]{2}/i)

      decoded = valid_utf8(URI::DEFAULT_PARSER.unescape(fragment))
      return unless decoded.match?(/\A\s*[\[{]/)
      return "[REDACTED]" if malformed_json_string_escape?(decoded)

      parsed = JSON.parse(decoded, max_nesting: 10)
      safe = redact_value(parsed, new_budget, 0, urls: false)
      return if safe == parsed

      encode_fragment_component(JSON.generate(safe))
    rescue JSON::ParserError, JSON::NestingError, JSON::GeneratorError, ArgumentError, EncodingError, UnsafeInput
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
      path = redact_url_path(path)
      path += "?#{redact_query(query)}" unless query.nil?
      path += "##{redact_fragment(fragment)}" unless fragment.nil?
      path
    end
  end
end
