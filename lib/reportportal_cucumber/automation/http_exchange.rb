# frozen_string_literal: true

require "json"
require_relative "evidence_redactor"

module Automation
  # A redacted snapshot and Markdown rendering of one observed HTTP call.
  #
  # This class records evidence only; it does not perform network requests.
  class HttpExchange
    MAX_PREVIEW_BYTES = 16 * 1024
    MAX_PREVIEW_LINES = 100
    MAX_SUMMARY_BYTES = 1024
    MAX_METADATA_BYTES = 1024
    TRUNCATION_MARKER = "[preview truncated]".freeze

    # @param method [#to_s] HTTP method.
    # @param url [#to_s] Request URL.
    # @param request [Hash] Request headers/body.
    # @param response [Hash] Response status/headers/body.
    # @param duration_ms [Numeric, nil] Observed request duration.
    # @param expected_status [Integer, String, nil] Expected response status.
    # @param error [Object, nil] Error observed while making the call.
    # @param sensitive_keys [Array<String, Symbol>] Additional keys for redaction.
    # @return [HttpExchange]
    def initialize(method:, url:, request: {}, response: {}, duration_ms: nil, expected_status: nil, error: nil,
                   sensitive_keys: [])
      @redactor = EvidenceRedactor.new(sensitive_keys: sensitive_keys)
      @method = @redactor.redact_text(method.to_s).upcase.freeze
      @url = @redactor.redact_url(url.to_s).freeze
      @request = safe_section(request)
      @response = safe_section(response)
      @duration_ms = duration_ms.nil? ? nil : @redactor.redact(duration_ms).to_s.freeze
      @expected_status = immutable_copy(@redactor.redact(expected_status))
      @error = error.nil? ? nil : error_snapshot(error)
      status = fetch(@response, :status)
      @status_text = status.nil? ? "unknown" : @redactor.redact_text(status.to_s).freeze
    end

    # @return [String] One concise, single-line diagnostic without a body.
    def summary
      parts = [bounded_text(plain_line(@method), 32), bounded_text(plain_line(@url), 384),
               "status=#{bounded_text(plain_line(@status_text), 64)}"]
      parts << "#{bounded_text(plain_line(@duration_ms), 64)}ms" unless @duration_ms.nil?
      parts << "error=#{bounded_text(plain_line(@error), 384)}" unless @error.nil?
      bounded_text(parts.join(" "), MAX_SUMMARY_BYTES)
    end

    # @return [String] Structured, bounded Markdown evidence for the exchange.
    def to_markdown
      preview_budget = { bytes: MAX_PREVIEW_BYTES, lines: MAX_PREVIEW_LINES }
      lines = ["### Request", "- #{inline_code(@method)} #{inline_code(@url)}"]
      append_section(lines, @request, preview_budget)
      lines << ""
      lines << "### Response"
      lines << "- Status: #{inline_code(@status_text)}"
      append_headers(lines, @response, preview_budget)
      append_body(lines, @response, preview_budget)
      lines << ""
      lines << "- Duration: #{inline_code(@duration_ms)} ms" unless @duration_ms.nil?
      lines << "- Error: #{inline_code(@error)}" unless @error.nil?
      lines.compact.join("\n")
    end

    # @return [Symbol] Severity based on the observed and expected status.
    def level
      return :error unless @error.nil?

      actual = status_number
      expected = integer_status(@expected_status)
      return expected && actual == expected ? :info : :error unless @expected_status.nil?
      return :warn if actual && (400..599).cover?(actual)

      :info
    end

    private

    def safe_section(section)
      return {}.freeze unless section.is_a?(Hash)

      # Evidence budgets must not erase the independently observed HTTP status.
      headers = @redactor.redact(fetch(section, :headers))
      headers = { "[omitted]" => EvidenceRedactor::OMITTED } if headers == EvidenceRedactor::OMITTED
      immutable_copy(status: safe_status(fetch(section, :status)), headers: headers,
                     body: @redactor.redact(fetch(section, :body)))
    end

    def safe_status(status)
      if status.is_a?(Integer)
        return status if (100..599).cover?(status)
      elsif status.is_a?(String) && status.bytesize == 3 && status.match?(/\A[1-5][0-9]{2}\z/)
        return status
      end
      nil
    end

    def append_section(lines, section, preview_budget)
      append_headers(lines, section, preview_budget)
      append_body(lines, section, preview_budget)
    end

    def append_headers(lines, section, preview_budget)
      headers = fetch(section, :headers)
      return unless headers.is_a?(Hash) && !headers.empty?

      lines << "- Headers:"
      content = headers.map { |key, value| "#{key}: #{value}" }.join("\n")
      displayed = preview_lines(content, preview_budget)
      fence = fence_for(displayed.join("\n"))
      lines << "#{fence}text"
      lines.concat(displayed)
      lines << fence
    end

    def append_body(lines, section, preview_budget)
      body = fetch(section, :body)
      return if body.nil?

      json = pretty_json(body)
      content = json || body.to_s
      displayed = preview_lines(content, preview_budget)
      lines << "- Body:"
      fence = fence_for(displayed.join("\n"))
      lines << "#{fence}#{json ? 'json' : 'text'}"
      lines.concat(displayed)
      lines << fence
    end

    def pretty_json(value)
      return nil if value.is_a?(String) && !json_string?(value)

      JSON.pretty_generate(value.is_a?(String) ? JSON.parse(value) : value)
    rescue JSON::ParserError, JSON::GeneratorError, TypeError
      nil
    end

    def json_string?(value)
      JSON.parse(value)
      true
    rescue JSON::ParserError
      false
    end

    def preview_lines(content, budget)
      text = valid_utf8(content.to_s)
      return [] if text.empty?

      byte_limit = budget.fetch(:bytes)
      line_limit = budget.fetch(:lines)
      return [TRUNCATION_MARKER] if byte_limit.zero? || line_limit.zero?

      prefix = utf8_prefix(text, byte_limit)
      lines = prefix.each_line(chomp: true).take(line_limit + 1)
      truncated = text.bytesize > byte_limit || lines.length > line_limit
      displayed = lines.first(line_limit)
      displayed = utf8_prefix(displayed.join("\n"), byte_limit).lines(chomp: true) if truncated
      content_bytes = displayed.join("\n").bytesize
      budget[:bytes] -= content_bytes
      budget[:lines] -= displayed.length
      displayed << TRUNCATION_MARKER if truncated
      displayed
    end

    def status_number
      integer_status(fetch(@response, :status))
    end

    def integer_status(value)
      Integer(value.to_s, 10)
    rescue ArgumentError, TypeError
      nil
    end

    def fetch(hash, key)
      hash.key?(key) ? hash[key] : hash[key.to_s]
    end

    def plain_line(value)
      valid_utf8(value.to_s).gsub(/[\x00-\x1f\x7f]/, " ").gsub(/[[:space:]]+/, " ").strip
    end

    def inline_code(value)
      text = bounded_text(plain_line(value), MAX_METADATA_BYTES)
      text = "(empty)" if text.empty?
      backticks = text.scan(/`+/).map(&:length).max || 0
      delimiter = "`" * [1, backticks + 1].max
      pad = text.start_with?("`") || text.end_with?("`") ? " " : ""
      "#{delimiter}#{pad}#{text}#{pad}#{delimiter}"
    end

    def bounded_text(value, limit)
      text = valid_utf8(value.to_s)
      return text if text.bytesize <= limit

      marker = "...[truncated]"
      utf8_prefix(text, limit - marker.bytesize) + marker
    end

    def valid_utf8(text)
      text = text.dup.force_encoding(Encoding::UTF_8) if text.encoding == Encoding::ASCII_8BIT
      text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
    end

    def utf8_prefix(text, limit)
      text.byteslice(0, limit).to_s.scrub("")
    end

    def fence_for(content)
      text = content.to_s
      backticks = text.scan(/`+/).map(&:length).max || 0
      tildes = text.scan(/~+/).map(&:length).max || 0
      if backticks <= tildes
        "`" * [3, backticks + 1].max
      else
        "~" * [3, tildes + 1].max
      end
    end

    def error_snapshot(error)
      sanitized = @redactor.redact(error.is_a?(Exception) ? error.message : error)
      text = if sanitized.is_a?(Hash) || sanitized.is_a?(Array)
               JSON.generate(sanitized)
             else
               sanitized.to_s
             end
      immutable_copy(text)
    rescue StandardError
      EvidenceRedactor::OMITTED
    end

    def immutable_copy(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, item), output|
          output[immutable_copy(key)] = immutable_copy(item)
        end.freeze
      when Array
        value.map { |item| immutable_copy(item) }.freeze
      when String
        value.dup.freeze
      else
        value.dup.freeze
      end
    rescue TypeError
      value
    end
  end
end
