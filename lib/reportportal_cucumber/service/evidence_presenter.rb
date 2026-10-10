# frozen_string_literal: true

require "json"
require "uri"
require_relative "../automation/evidence_redactor"

module ReportportalCucumber
  module Service
    # Formats bounded, redacted text for caller-supplied evidence.
    class EvidencePresenter
      SUMMARY_LIMIT = 512
      DETAILS_LIMIT = 16 * 1024
      VALUE_LIMIT = 4 * 1024
      MAX_SANITIZATION_INPUT_BYTES = 64 * 1024
      MAX_INTEGER_BITS = 10_000
      STRUCTURE_NODE_LIMIT = 256
      STRUCTURE_DEPTH_LIMIT = 8
      OMITTED = "[diagnostic omitted: unsafe or oversized input]".freeze
      REDACTOR = Automation::EvidenceRedactor.new
      URL_PATTERN = %r{(?:https?:)?//[^\s"'<>]+}i.freeze

      class << self
        # @return [Hash{Symbol => String}] A concise failure summary and diagnostics.
        # @param action [Object] Action being reported.
        # @param error [Exception] Original error to summarize.
        # @param url [String, nil] Optional URL associated with the failure.
        # @param details [Object, nil] Optional bounded diagnostic details.
        # @param artifact_names [Array<String>] Names of available evidence artifacts.
        # @param artifacts [Array<Hash>, nil] Optional artifact descriptors with names.
        def failure(action:, error:, url: nil, details: nil, artifact_names: [], artifacts: nil)
          summary = [safe_string(action, 128), "#{error.class.name}: #{safe_string(error.message, 256)}"]
          summary << "URL: #{safe_url(url, 512)}" unless url.nil?
          names = []
          artifact_source = artifacts || artifact_names || []
          artifact_source = [artifact_source] unless artifact_source.respond_to?(:each)
          artifact_source.each do |artifact|
            break if names.length >= 16
            next if artifact.nil?

            name = artifact.is_a?(Hash) ? (artifact[:name] || artifact["name"] || "evidence") : artifact
            names << safe_string(name, 128)
          end
          summary << "Evidence: #{names.join(', ')}" unless names.empty?
          { summary: bounded(summary.join(" | "), SUMMARY_LIMIT),
            details: details.nil? ? "" : render(details, DETAILS_LIMIT) }
        rescue StandardError
          { summary: OMITTED, details: OMITTED }
        end

        # @return [Hash{Symbol => String}] A concise status and Markdown comparison.
        # @param name [Object] Assertion or check name.
        # @param expected [Object] Expected value.
        # @param actual [Object] Observed value.
        # @param passed [Boolean] Diagnostic outcome; does not assert or raise.
        # @param details [Object, nil] Optional supplementary diagnostic details.
        def assertion(name:, expected:, actual:, passed:, details: nil)
          status = passed ? "PASS" : "FAIL"
          markdown = assertion_markdown(status, name, expected, actual, details)
          { summary: bounded("#{status}: #{safe_string(name, VALUE_LIMIT)}", SUMMARY_LIMIT),
            markdown: bounded(markdown, DETAILS_LIMIT) }
        rescue StandardError
          { summary: OMITTED, markdown: OMITTED }
        end

        # @param value [Object] Diagnostic text to sanitize.
        # @param limit [Integer] Maximum output bytes.
        # @return [String] Safe, bounded diagnostic text or a fixed omission marker.
        def sanitize_diagnostic(value, limit: DETAILS_LIMIT)
          return OMITTED unless Integer === limit && limit >= 0
          return "" if limit.zero?
          return bounded(OMITTED, limit) unless safe_scalar?(value)
          return bounded(OMITTED, limit) if Integer === value && value.bit_length > MAX_INTEGER_BITS

          bounded(sanitize_text(object_string(value)), limit)
        rescue StandardError
          Integer === limit && limit >= 0 ? bounded(OMITTED, limit) : OMITTED
        end

        private

        def assertion_markdown(status, name, expected, actual, details)
          rows = ["## Assertion: #{render(name, VALUE_LIMIT)}", "", "**Outcome:** #{status}", "",
                  "| Expected | Actual |", "| --- | --- |",
                  "| #{table_cell(expected)} | #{table_cell(actual)} |"]
          rows.concat(["", "### Details", "", render(details, DETAILS_LIMIT)]) unless details.nil?
          rows.join("\n")
        end

        def table_cell(value)
          render(value, VALUE_LIMIT).gsub("|", "\\|").gsub(/[\r\n]+/, " ")
        end

        def render(value, limit)
          result = if value.is_a?(String)
                     sanitize_text(value)
                   else
                     budget = { bytes: DETAILS_LIMIT, nodes: STRUCTURE_NODE_LIMIT }
                     bounded_value = bound_structure(value, budget, 0)
                     JSON.generate(bounded_value)
                   end
          bounded(result, limit)
        rescue JSON::GeneratorError, EncodingError, SystemStackError
          OMITTED
        end

        def bound_structure(value, budget, depth)
          return "[truncated]" if budget[:nodes] <= 0 || budget[:bytes] <= 0 || depth > STRUCTURE_DEPTH_LIMIT

          budget[:nodes] -= 1
          case value
          when String
            safe = sanitize_text(value)
            safe = bounded(safe, VALUE_LIMIT)
            safe = bounded(safe, budget[:bytes])
            budget[:bytes] -= safe.bytesize
            safe
          when Hash
            output = {}
            value.each do |key, item|
              break if budget[:nodes] <= 0 || budget[:bytes] <= 0

              budget[:nodes] -= 1
              budget[:bytes] -= 1

              unless key.is_a?(String) || key.is_a?(Symbol)
                output["[omitted-key]"] = "[omitted]"
                next
              end
              raw_key = key.to_s
              if raw_key.bytesize > MAX_SANITIZATION_INPUT_BYTES
                output["[omitted-key]"] = "[omitted]"
                next
              end
              if REDACTOR.sensitive_key?(raw_key)
                output[bounded(raw_key, [128, budget[:bytes]].min)] = Automation::EvidenceRedactor::MASK
                budget[:bytes] -= [raw_key.bytesize, 128, budget[:bytes]].min
                next
              end
              if raw_key.bytesize > 128
                output["[omitted-key]"] = "[omitted]"
                next
              end

              safe_key = sanitize_text(raw_key)
              safe_key = bounded(safe_key, [128, budget[:bytes]].min)
              budget[:bytes] -= safe_key.bytesize
              output[safe_key] = bound_structure(item, budget, depth + 1)
            end
            output
          when Array
            output = []
            value.each do |item|
              break if budget[:nodes] <= 0 || budget[:bytes] <= 0

              output << bound_structure(item, budget, depth + 1)
            end
            output
          when Integer
            return "[omitted]" if value.bit_length > MAX_INTEGER_BITS

            byte_cost = value.bit_length + 2
            return "[truncated]" if budget[:bytes] < byte_cost

            budget[:bytes] -= byte_cost
            value
          when Float
            return "[truncated]" if budget[:bytes] < 32

            budget[:bytes] -= 32
            value
          when TrueClass, FalseClass, NilClass
            budget[:bytes] -= 16
            value
          else
            safe_string(value, VALUE_LIMIT)
          end
        end

        def safe_string(value, limit)
          sanitize_diagnostic(value, limit: limit)
        end

        def safe_url(value, limit)
          return OMITTED unless String === value

          source = value
          return OMITTED if source.bytesize > MAX_SANITIZATION_INPUT_BYTES

          source = valid_utf8(source)
          parsed = URI.parse(source)
          return OMITTED unless parsed.is_a?(URI::HTTP) || parsed.is_a?(URI::HTTPS)
          return OMITTED unless valid_url_escapes?(parsed)

          bounded(REDACTOR.redact_url(source), limit)
        rescue URI::Error, ArgumentError, EncodingError
          OMITTED
        end

        def object_string(value)
          case value
          when String then value
          when Integer
            return OMITTED if value.bit_length > MAX_INTEGER_BITS

            value.to_s
          when Symbol, Float then value.to_s
          when TrueClass then "true"
          when FalseClass then "false"
          when NilClass then ""
          else OMITTED
          end
        rescue StandardError
          OMITTED
        end

        def safe_scalar?(value)
          case value
          when String, Symbol, Integer, Float, TrueClass, FalseClass, NilClass then true
          else false
          end
        end

        def sanitize_text(value)
          source = value.is_a?(String) ? value : object_string(value)
          return OMITTED if source.bytesize > MAX_SANITIZATION_INPUT_BYTES

          source = valid_utf8(source)
          if source.match?(/\A\s*[\[{]/)
            begin
              return OMITTED unless REDACTOR.valid_json_string_escapes?(source)

              parsed = JSON.parse(source, max_nesting: STRUCTURE_DEPTH_LIMIT + 2)
              budget = { bytes: DETAILS_LIMIT, nodes: STRUCTURE_NODE_LIMIT }
              return JSON.generate(bound_structure(parsed, budget, 0))
            rescue JSON::ParserError, JSON::NestingError, JSON::GeneratorError, EncodingError, SystemStackError
              return OMITTED
            end
          end
          return OMITTED if ambiguous_embedded_json_key?(source)
          return OMITTED unless urls_parseable?(source)

          REDACTOR.redact_text(source)
        rescue StandardError
          OMITTED
        end

        # @param source [String] Complete diagnostic text within the input budget.
        # @return [Boolean] Whether an embedded structure contains ambiguous escapes.
        def ambiguous_embedded_json_key?(source)
          closing_brackets = []
          quote = nil
          index = 0
          while index < source.bytesize
            byte = source.getbyte(index)
            return true if byte == 92 && !closing_brackets.empty?

            if quote
              quote = nil if byte == quote
            elsif !closing_brackets.empty? && (byte == 34 || byte == 39)
              quote = byte
            elsif byte == 123
              closing_brackets << 125
            elsif byte == 91
              closing_brackets << 93
            elsif byte == closing_brackets.last
              closing_brackets.pop
            end
            index += 1
          end
          false
        end

        def urls_parseable?(source)
          source.to_enum(:scan, URL_PATTERN).each do
            parsed = URI.parse(Regexp.last_match(0))
            return false unless valid_url_escapes?(parsed)
          rescue URI::Error, ArgumentError
            return false
          end
          true
        end

        def valid_url_escapes?(uri)
          [uri.query, uri.fragment].compact.none? { |part| part.match?(/%(?![0-9a-f]{2})/i) }
        end

        def valid_utf8(source)
          source = source.dup.force_encoding(Encoding::UTF_8) if source.encoding == Encoding::ASCII_8BIT
          source.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
        end

        def bounded(value, limit)
          return "" if limit <= 0

          text = value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
          return text if text.bytesize <= limit

          return "." * limit if limit < 3

          bytes = text.byteslice(0, limit - 3)
          bytes = bytes.byteslice(0, bytes.bytesize - 1) until bytes.valid_encoding?
          "#{bytes}..."
        end
      end
    end
  end
end
