# frozen_string_literal: true

require "json"
require "uri"
require_relative "../automation/evidence_redactor"
require_relative "../presentation/markdown_text"
require_relative "../presentation/ledger_json"

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
        # @return [Hash{Symbol => String}] Unchanged summary/diagnostics and a plain card.
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
          result = { summary: bounded(summary.join(" | "), SUMMARY_LIMIT),
                     details: details.nil? ? "" : render(details, DETAILS_LIMIT) }
          result[:card] = Presentation::Fallback.render(fallback: -> { result.values.reject(&:empty?).join("\n\n") }) do
            failure_card(action, error, url, names, details, result[:details])
          end
          result
        rescue StandardError
          { summary: OMITTED, details: OMITTED, card: OMITTED }
        end

        # @return [Hash{Symbol => String}] A concise status and Markdown comparison.
        # @param name [Object] Assertion or check name.
        # @param expected [Object] Expected value.
        # @param actual [Object] Observed value.
        # @param passed [Boolean] Diagnostic outcome; does not assert or raise.
        # @param details [Object, nil] Optional supplementary diagnostic details.
        def assertion(name:, expected:, actual:, passed:, details: nil)
          status = passed ? "PASS" : "FAIL"
          markdown = Presentation::Fallback.render(fallback: -> { assertion_markdown(status, name, expected, actual, details, presentation: false) }) do
            assertion_markdown(status, name, expected, actual, details, presentation: true)
          end
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

        def assertion_markdown(status, name, expected, actual, details, presentation:)
          return assertion_card(status, name, expected, actual, details) if presentation

          title = render(name, VALUE_LIMIT)
          rows = ["## Assertion: #{title}", "", "**Outcome:** #{status}", "",
                  "| Expected | Actual |", "| --- | --- |",
                  "| #{table_cell(expected)} | #{table_cell(actual)} |"]
          unless details.nil?
            text = render(details, DETAILS_LIMIT)
            rows.concat(["", "### Details", "", text])
          end
          rows.join("\n")
        end

        def table_cell(value)
          render(value, VALUE_LIMIT).gsub("|", "\\|").gsub(/[\r\n]+/, " ")
        end

        def assertion_card(status, name, expected, actual, details)
          title = card_title(render(name, VALUE_LIMIT))
          expected_text = ledger_value(expected, VALUE_LIMIT)
          if status == "PASS"
            title = "\u2713 Assertion passed \u00b7 #{title}"
            if expected_text.length <= 60 && !expected_text.match?(/[\r\n]/)
              title += " \u00b7 expected #{card_code(expected_text)}"
            end
            parts = [title]
          else
            parts = ["## \u2717 Assertion failed \u00b7 #{title}"]
            actual_text = ledger_value(actual, VALUE_LIMIT)
            limit = DETAILS_LIMIT - parts.first.bytesize - 72 - (details.nil? ? 0 : 256)
            comparison = comparison_block(expected_text, actual_text, limit)
            append_card_fence(parts, comparison, "text")
          end
          append_card_details(parts, details, render(details, DETAILS_LIMIT)) unless details.nil?
          parts.join("\n\n")
        end

        def failure_card(action, error, url, names, details, diagnostic)
          title = safe_string(action, 128)
          title = "Failure evidence" if title.strip.empty?
          parts = ["## \u2717 #{card_title(title)}"]
          location = []
          klass = safe_string(error.class.name, 128)
          location << card_code(klass) unless klass.empty?
          location << "at #{card_code(safe_url(url, 512))}" unless url.nil?
          meta = [location.join(" ")].reject(&:empty?)
          meta << "evidence #{names.map { |name| card_code(name) }.join(', ')}" unless names.empty?
          parts << meta.join(" \u00b7 ") unless meta.empty?
          message = safe_string(error.message, VALUE_LIMIT)
          append_card_fence(parts, message, "text") unless message.empty?
          append_card_details(parts, details, diagnostic) unless details.nil?
          parts.join("\n\n")
        end

        def ledger_value(value, limit)
          text = render(value, limit)
          return text if value.is_a?(String)

          bounded(ledger_json(parsed_diagnostic(text)), limit)
        end

        def parsed_diagnostic(text)
          JSON.parse(text)
        rescue JSON::ParserError
          text
        end

        def ledger_json(value)
          Presentation::LedgerJson.format(value) || raise(StandardError, "JSON presentation unavailable")
        end

        def append_card_details(parts, original, diagnostic)
          value = original.is_a?(String) ? diagnostic : parsed_diagnostic(diagnostic)
          if inline_details?(value)
            pairs = value.map { |key, item| "#{card_code(key)} = #{card_code(scalar_text(item))}" }
            section = "_Details_ #{pairs.join(" \u00b7 ")}".rstrip
            if parts.join("\n\n").bytesize + section.bytesize + 2 <= DETAILS_LIMIT
              parts << section
              return
            end
          end
          append_card_fence(parts, ledger_json(value), "json", caption: "_Details_")
        end

        def inline_details?(value)
          value.is_a?(Hash) && value.length <= 6 && value.values.all? do |item|
            safe_scalar?(item) && !item.is_a?(Symbol) && scalar_text(item).length <= 80
          end
        end

        def scalar_text(value)
          value.is_a?(String) ? value : ledger_json(value)
        end

        def comparison_block(expected, actual, limit)
          values = [expected, actual].map { |text| text.gsub(/\r\n|\r|\n/, "\n          ") }
          # Indentation can expand newline-heavy values beyond the whole card's
          # budget. Keep both labels, rather than clipping away the actual value.
          if values.sum(&:bytesize) + 21 > limit
            values = values.map { |text| bounded(text, (limit - 21) / 2) }
          end
          "expected  #{values.first}\nactual    #{values.last}"
        end

        def card_code(text)
          Presentation::MarkdownText.code(text, limit: VALUE_LIMIT)
        end

        def card_title(text)
          loop do
            escaped = Presentation::MarkdownText.inline(text, limit: VALUE_LIMIT)
            return escaped if escaped.bytesize <= VALUE_LIMIT

            text = bounded(text, [text.bytesize - (escaped.bytesize - VALUE_LIMIT), 3].max)
          end
        end

        def append_card_fence(parts, text, language, caption: nil)
          # Reserve both maximum-size delimiters before clipping raw evidence,
          # never clip the finished Markdown and leave user text outside a fence.
          prefix = caption ? "#{caption}\n\n" : ""
          remaining = DETAILS_LIMIT - parts.join("\n\n").bytesize - prefix.bytesize - 2
          limit = [remaining - 2 * Presentation::MarkdownText::MAX_FENCE_BYTES - language.bytesize - 2, 0].max
          content = bounded(text, limit)
          fence = Presentation::MarkdownText.fence(content, language, limit: DETAILS_LIMIT)
          raise StandardError, "Safe evidence fence unavailable" unless fence

          raise StandardError, "Evidence card budget exhausted" if fence.bytesize > remaining

          parts << prefix + fence
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
