# frozen_string_literal: true

require_relative "fallback"

module ReportportalCucumber
  module Presentation
    # Bounded Markdown primitives. Limits apply to input bytes before escaping;
    # output grows only by escaping, delimiters, and the truncation marker.
    # These helpers do not redact: callers must sanitize before presentation.
    module MarkdownText
      INPUT_LIMIT = 64 * 1024
      TEXT_LIMIT = 16 * 1024
      CELL_LIMIT = 512
      CODE_LIMIT = 1024
      MAX_FENCE_BYTES = 32
      TRUNCATED = "[truncated]".freeze
      OMITTED = "[presentation omitted]".freeze

      class << self
        # @param text [String, Symbol, Numeric, nil] Text outside code.
        # @param limit [Integer] Input byte limit, capped at 64 KiB.
        # @return [String] Entity-escaped, valid UTF-8 text.
        def html(text, limit: TEXT_LIMIT)
          Fallback.render(fallback: -> { OMITTED }) { escape_html(bounded(text, limit)) }
        end

        # @param text [String, Symbol, Numeric, nil] Cell data, never trusted HTML.
        # @param limit [Integer] Input byte limit (512 by default).
        # @return [String] Escaped cell with only client-generated <br> tags.
        def cell(text, limit: CELL_LIMIT)
          Fallback.render(fallback: -> { OMITTED }) do
            html(text, limit: limit).gsub(/[\\|]/) { |char| "\\#{char}" }.gsub(/\r\n|\r|\n/, "<br>")
          end
        end

        # @param text [String, Symbol, Numeric, nil] Data in a title or caption.
        # @param limit [Integer] Input byte limit, capped at 64 KiB.
        # @return [String] One-line, entity-escaped Markdown text.
        def inline(text, limit: TEXT_LIMIT)
          Fallback.render(fallback: -> { OMITTED }) do
            value = html(text, limit: limit).gsub(/[\\`*_\[\]|~]/) { |char| "\\#{char}" }
            value = value.gsub(/\r\n|\r|\n/, " ")
            value.sub(/\A(\s*)([#>+\-]|\d+\.)/) do
              leading, token = Regexp.last_match(1), Regexp.last_match(2)
              token.end_with?(".") ? "#{leading}#{token[0...-1]}\\." : "#{leading}\\#{token}"
            end
          end
        end

        # @param text [String, Symbol, Numeric, nil] Chip content; not entity-escaped.
        # @param limit [Integer] Input byte limit (1 KiB by default).
        # @return [String] Dynamic code span, or `(empty)` for empty input.
        def code(text, limit: CODE_LIMIT)
          Fallback.render(fallback: -> { "`#{OMITTED}`" }) do
            value = bounded(text, limit).gsub(/[\x00-\x1f\x7f]/, " ").gsub(/[[:space:]]+/, " ").strip
            value = "(empty)" if value.empty?
            delimiter = "`" * [1, longest_run(value, "`") + 1].max
            padding = value.start_with?("`") || value.end_with?("`") ? " " : ""
            "#{delimiter}#{padding}#{value}#{padding}#{delimiter}"
          end
        end

        # @param text [String] Raw block content; never entity-escaped.
        # @param lang [String] Optional ASCII language identifier.
        # @param limit [Integer] Input byte limit, capped at 64 KiB.
        # @return [String, nil] Complete fence, or nil when no safe <=32-byte
        #   delimiter exists. Callers retain their existing omission marker.
        def fence(text, lang = "", limit: TEXT_LIMIT)
          Fallback.render(fallback: -> { nil }) do
            value = bounded(text, limit)
            delimiter = ["`", "~"].filter_map do |char|
              length = [3, longest_run(value, char) + 1].max
              char * length if length <= MAX_FENCE_BYTES
            end.first
            next nil unless delimiter

            language = bounded(lang, 64)
            language = "" unless language.match?(/\A[a-zA-Z0-9_+-]*\z/)
            "#{delimiter}#{language}\n#{value}\n#{delimiter}"
          end
        end

        private

        def escape_html(text)
          text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
        end

        def bounded(value, limit)
          limit = limit.is_a?(Integer) ? [[limit, 0].max, INPUT_LIMIT].min : TEXT_LIMIT
          text = case value
                 when String then value
                 when Symbol, Float, TrueClass, FalseClass then value.to_s
                 when Integer then value.bit_length <= 10_000 ? value.to_s : OMITTED
                 when NilClass then ""
                 else OMITTED
                 end
          prefix = text.byteslice(0, limit).to_s.dup.force_encoding(Encoding::UTF_8).scrub
          truncated = text.bytesize > limit || prefix.bytesize > limit
          prefix = prefix.byteslice(0, limit).to_s.scrub("") if truncated
          truncated ? prefix + TRUNCATED : prefix
        end

        def longest_run(text, character)
          text.scan(/#{Regexp.escape(character)}+/).map(&:length).max || 0
        end
      end
    end
  end
end
