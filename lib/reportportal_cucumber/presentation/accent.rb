# frozen_string_literal: true

require_relative "markdown_text"

module ReportportalCucumber
  module Presentation
    # Pure, opt-in building blocks for client-authored RP log cards only.
    # Callers supply sanitized data and choose the channel/mode themselves.
    # Build plain and rich inside Fallback.render(fallback: original_baseline),
    # then guard the whole message. This module never rescues helper failures.
    module Accent
      PILL = "display:inline-block;padding:0 7px;border-radius:9px;font:600 10.5px/1.7 system-ui,-apple-system,Segoe UI,sans-serif;letter-spacing:.04em".freeze
      PASS = "color:#276E50;background:#E6F5EE".freeze
      FAIL = "color:#B23B3B;background:#FBEAEA".freeze
      WARN = "color:#8A5A00;background:#FFF3D6".freeze
      INFO = "color:#0F6C7A;background:#E3F4F7".freeze
      TITLE = "font:600 13.5px/1.5 system-ui,-apple-system,Segoe UI,sans-serif;color:#2B2B2D".freeze
      TH = "font:600 10.5px system-ui,-apple-system,Segoe UI,sans-serif;letter-spacing:.06em;text-transform:uppercase;color:#6B6B6D".freeze
      MAX_ADDED_BYTES = 1024
      MAX_HEADER_COLUMNS = 6
      TONES = { pass: PASS, fail: FAIL, warn: WARN, info: INFO }.freeze
      LEVELS = %i[trace debug info warn error fatal].freeze
      private_constant :TONES, :LEVELS

      class << self
        # @param label [String] Sanitized data, not pre-escaped text or HTML.
        # @param tone [Symbol] Exactly :pass, :fail, :warn or :info.
        # @param limit [Integer] Input byte limit, 0..MarkdownText::INPUT_LIMIT.
        # @return [String] Escaped label in an exact PILL;TONE span.
        def pill(label, tone:, limit: MarkdownText::CODE_LIMIT)
          check_text!(label)
          check_limit!(limit)
          style = "#{PILL};#{TONES.fetch(tone)}"
          span(MarkdownText.inline(label, limit: limit), style)
        end

        # @param text [String] Sanitized title data, never an assembled message.
        # @param limit [Integer] Input byte limit, 0..MarkdownText::INPUT_LIMIT.
        # @return [String] Escaped single-line title in an exact TITLE span.
        def title(text, limit: MarkdownText::TEXT_LIMIT)
          check_text!(text)
          check_limit!(limit)
          span(MarkdownText.inline(text, limit: limit), TITLE)
        end

        # @param text [String] Sanitized, unescaped text of one header cell.
        # @param columns [Integer] Positive column count of the owning table.
        # @param limit [Integer] Input byte limit, 0..MarkdownText::INPUT_LIMIT.
        # @return [String] Escaped TH span for <=6 columns; plain escaped cell
        #   otherwise. Does not inspect or rewrite table rows/alignment.
        def table_header(text, columns:, limit: MarkdownText::CELL_LIMIT)
          check_text!(text)
          check_limit!(limit)
          raise ArgumentError, "columns must be a positive Integer" unless columns.is_a?(Integer) && columns.positive?

          cell = MarkdownText.cell(text, limit: limit)
          check_text!(cell)
          columns <= MAX_HEADER_COLUMNS ? span(cell, TH) : cell
        end

        # @param summary [String] Sanitized caption data, not markup.
        # @param body [String] Sanitized raw block content, not a fence or HTML.
        # @param language [String] Code language; MarkdownText enforces its allowlist.
        # @param limit [Integer] Body input byte limit, 0..MarkdownText::INPUT_LIMIT.
        # @param summary_limit [Integer] Summary input byte limit in the same range.
        # @return [String] A details/summary block with a dynamic code fence and
        #   one blank line on each side of that fence. Unsafe fences raise.
        def details(summary:, body:, language: "text", limit: MarkdownText::TEXT_LIMIT,
                    summary_limit: MarkdownText::CODE_LIMIT)
          [summary, body, language].each { |text| check_text!(text) }
          [limit, summary_limit].each { |value| check_limit!(value) }
          # The summary is an HTML block's text node, not Markdown inline text.
          caption = MarkdownText.html(summary, limit: summary_limit)
          check_text!(caption)
          caption = caption.gsub(/\r\n|\r|\n/, " ")
          fence = MarkdownText.fence(body, language, limit: limit)
          raise ArgumentError, "Safe folded evidence fence unavailable" unless fence.is_a?(String)

          "<details><summary>#{caption}</summary>\n\n#{fence}\n\n</details>"
        end

        # @param plain [String] Complete, already-rendered Tier 1 message.
        # @param rich [String] Complete candidate assembled from these helpers.
        # @param level [Symbol, String] trace/debug/info/warn/error/fatal; strings
        #   are case-insensitive. This is explicit input, never global context.
        # @return [String] The exact plain object for ERROR/FATAL, or if rich
        #   adds >1024 bytes; otherwise the exact rich object.
        #   This is not an HTML rewriter or a replacement for outer Fallback.
        def guard(plain:, rich:, level:)
          [plain, rich].each { |text| check_text!(text) }
          level = level.downcase.to_sym if level.is_a?(String)
          raise ArgumentError, "unknown log level" unless LEVELS.include?(level)

          return plain if %i[error fatal].include?(level)
          return plain if rich.bytesize > plain.bytesize + MAX_ADDED_BYTES

          rich
        end

        private

        def span(text, style)
          check_text!(text)
          "<span style=\"#{style}\">#{text}</span>"
        end

        def check_text!(text)
          raise TypeError, "expected String data" unless text.is_a?(String)
        end

        def check_limit!(limit)
          unless limit.is_a?(Integer) && (0..MarkdownText::INPUT_LIMIT).cover?(limit)
            raise ArgumentError, "input limit must be an Integer within MarkdownText's byte budget"
          end
        end
      end
    end
  end
end
