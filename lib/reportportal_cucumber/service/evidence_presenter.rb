# frozen_string_literal: true

require "json"
require_relative "../automation/evidence_redactor"

module ReportportalCucumber
  module Service
    # Formats bounded, redacted text for caller-supplied evidence.
    class EvidencePresenter
      SUMMARY_LIMIT = 512
      DETAILS_LIMIT = 16 * 1024
      VALUE_LIMIT = 4 * 1024
      STRUCTURE_NODE_LIMIT = 256
      STRUCTURE_DEPTH_LIMIT = 8
      REDACTOR = Automation::EvidenceRedactor.new

      class << self
        # @return [Hash{Symbol => String}] A concise failure summary and diagnostics.
        # @param action [Object] Action being reported.
        # @param error [Exception] Original error to summarize.
        # @param url [String, nil] Optional URL associated with the failure.
        # @param details [Object, nil] Optional bounded diagnostic details.
        # @param artifact_names [Array<String>] Names of available evidence artifacts.
        # @param artifacts [Array<Hash>, nil] Optional artifact descriptors with names.
        def failure(action:, error:, url: nil, details: nil, artifact_names: [], artifacts: nil)
          summary = [utf8_prefix(action, 128), "#{error.class.name}: #{utf8_prefix(error.message, 256)}"]
          summary << "URL: #{REDACTOR.redact_url(utf8_prefix(url, 512))}" unless url.nil?
          names = []
          artifact_source = artifacts || artifact_names || []
          artifact_source = [artifact_source] unless artifact_source.respond_to?(:each)
          artifact_source.each do |artifact|
            break if names.length >= 16

            next if artifact.nil?

            name = artifact.is_a?(Hash) ? (artifact[:name] || artifact["name"] || "evidence") : artifact
            names << utf8_prefix(name, 128)
          end
          summary << "Evidence: #{names.join(', ')}" unless names.empty?
          { summary: bounded(REDACTOR.redact_text(summary.join(" | ")), SUMMARY_LIMIT),
            details: bounded(details.nil? ? "" : render(details), DETAILS_LIMIT) }
        end

        # @return [Hash{Symbol => String}] A concise status and Markdown comparison.
        # @param name [Object] Assertion or check name.
        # @param expected [Object] Expected value.
        # @param actual [Object] Observed value.
        # @param passed [Boolean] Diagnostic outcome; does not assert or raise.
        # @param details [Object, nil] Optional supplementary diagnostic details.
        def assertion(name:, expected:, actual:, passed:, details: nil)
          status = passed ? "PASS" : "FAIL"
          {
            summary: bounded("#{status}: #{render(name)}", SUMMARY_LIMIT),
            markdown: bounded(assertion_markdown(status, name, expected, actual, details), DETAILS_LIMIT)
          }
        end

        private

        def assertion_markdown(status, name, expected, actual, details)
          rows = ["## Assertion: #{render(name)}", "", "**Outcome:** #{status}", "",
                  "| Expected | Actual |", "| --- | --- |",
                  "| #{table_cell(expected)} | #{table_cell(actual)} |"]
          rows.concat(["", "### Details", "", render(details)]) unless details.nil?
          rows.join("\n")
        end

        def table_cell(value)
          render(value).gsub("|", "\\|").gsub(/[\r\n]+/, " ")
        end

        def render(value)
          if value.is_a?(String)
            REDACTOR.redact_text(utf8_prefix(value, DETAILS_LIMIT))
          else
            budget = { bytes: DETAILS_LIMIT, nodes: STRUCTURE_NODE_LIMIT }
            bounded = bound_structure(value, budget, 0)
            JSON.generate(REDACTOR.redact(bounded))
          end
        rescue JSON::GeneratorError, EncodingError
          REDACTOR.redact_text(utf8_prefix(value.to_s, DETAILS_LIMIT))
        end

        def bound_structure(value, budget, depth)
          return "[truncated]" if budget[:nodes] <= 0 || budget[:bytes] <= 0 || depth > STRUCTURE_DEPTH_LIMIT

          budget[:nodes] -= 1
          case value
          when String
            text = utf8_prefix(value, [VALUE_LIMIT, budget[:bytes]].min)
            budget[:bytes] -= text.bytesize
            text
          when Hash
            output = {}
            value.each do |key, item|
              break if budget[:nodes] <= 0 || budget[:bytes] <= 0

              safe_key = utf8_prefix(key.to_s, [128, budget[:bytes]].min)
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
          when Numeric, TrueClass, FalseClass, NilClass
            budget[:bytes] -= 16
            value
          else
            text = utf8_prefix(value.to_s, [VALUE_LIMIT, budget[:bytes]].min)
            budget[:bytes] -= text.bytesize
            text
          end
        end

        def utf8_prefix(value, limit)
          return "" if limit <= 0

          source = value.is_a?(String) ? value : value.to_s
          output = +""
          source.each_char do |character|
            safe_character = character.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
            break if output.bytesize + safe_character.bytesize > limit

            output << safe_character
          end
          output
        end

        def bounded(value, limit)
          text = value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
          return text if text.bytesize <= limit

          bytes = text.byteslice(0, limit - 3)
          bytes = bytes.byteslice(0, bytes.bytesize - 1) until bytes.valid_encoding?
          "#{bytes}..."
        end
      end
    end
  end
end
