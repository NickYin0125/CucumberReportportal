# frozen_string_literal: true

require "json"
require_relative "../../presentation/markdown_text"
require_relative "../../presentation/ledger_json"
require_relative "../../presentation/units"

module ReportportalCucumber
  module ReportPortal
    module Models
      # Builds markdown-rich descriptions for Gherkin steps.
      class StepDesc
        CONTENT_BYTE_LIMIT = 16 * 1024
        CONTENT_LINE_LIMIT = 100
        STEP_TEXT_BYTE_LIMIT = 4096
        KEYWORD_BYTE_LIMIT = 128
        JSON_PARSE_BYTE_LIMIT = 4096
        CELL_BYTE_LIMIT = 512
        TABLE_COLUMN_LIMIT = 32
        MAX_FENCE_BYTES = 32
        TRUNCATION_MARKER = "[truncated]"
        TABLE_OMITTED_MARKER = "[table omitted: preview limit exceeded]"
        DOC_OMITTED_MARKER = "[DocString omitted: preview limit exceeded]"
        NUMERIC_CELL = /\A[+-]?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?%?\z/

        # @param step [Object] The localized Gherkin source step.
        # @param multiline_content [String, nil] Legacy executed DocString content.
        # @param executed_text [String, nil] Framework-provided executed step text.
        # @param multiline_arg [Object, nil] Framework-provided executed multiline argument.
        # @return [StepDesc]
        def initialize(step:, multiline_content: nil, executed_text: nil, multiline_arg: nil)
          @step = step
          @multiline_content = multiline_content
          @executed_text = executed_text
          @multiline_arg = multiline_arg
        end

        # @param test_step [Object] The executed Cucumber Core test step.
        # @param ast_lookup [Object] Lookup that maps runtime steps to localized Gherkin steps.
        # @return [ReportportalCucumber::ReportPortal::Models::StepDesc, nil]
        def self.from_test_step(test_step, ast_lookup:)
          source = ast_lookup&.step_source(test_step)
          return nil unless source&.respond_to?(:step) && source.step

          executed_text = test_step.text if test_step.respond_to?(:text)
          multiline_arg = test_step.multiline_arg if test_step.respond_to?(:multiline_arg)

          new(step: source.step, executed_text: executed_text, multiline_arg: multiline_arg)
        rescue StandardError
          nil
        end

        # @return [String]
        def summary_name
          parts = [keyword_label, step_text].reject(&:empty?)
          parts.join(" ").strip
        end

        # @return [String]
        def gherkin_text
          step_text
        end

        # @param mode [Symbol] :description keeps the header; :log uses argument captions.
        # @return [String] Bounded Markdown, or the complete pre-Ledger description on failure.
        def to_markdown(mode: :description)
          Presentation::Fallback.render(fallback: -> { baseline_markdown }) do
            raise ArgumentError, "Unknown step presentation mode" unless %i[log description].include?(mode)

            render_markdown(presentation: true, mode: mode)
          end
        end

        # Exact pre-Ledger rendering, deliberately independent of Presentation helpers.
        # @return [String] Baseline message for caller-level rendering fallbacks.
        def baseline_markdown
          render_markdown(presentation: false)
        end

        # @return [Boolean]
        def rich?
          multiline_sections(presentation: false).any? { |section| !section.to_s.strip.empty? }
        end

        private

        def render_markdown(presentation:, mode: :description)
          sections = mode == :log ? [] : [header_line(presentation: presentation)]
          multiline_sections(presentation: presentation, mode: mode).each do |section|
            sections << section unless section.to_s.strip.empty?
          end
          sections.join("\n\n")
        end

        # @return [String]
        def header_line(presentation: true)
          keyword = presentation ? Presentation::MarkdownText.inline(keyword_label) : keyword_label
          text = presentation ? Presentation::MarkdownText.inline(step_text) : step_text
          # Leave room for argument previews even when entity escaping expands a hostile title.
          if presentation && text.bytesize > CONTENT_BYTE_LIMIT / 2
            text = Presentation::MarkdownText.inline(step_text, limit: STEP_TEXT_BYTE_LIMIT / 6)
          end
          if text.empty?
            "**#{keyword}**"
          else
            "**#{keyword}** #{text}"
          end
        end

        # @return [Array<String>]
        def multiline_sections(presentation: true, mode: :description)
          sections = []
          remaining = CONTENT_BYTE_LIMIT - (mode == :log ? 0 : header_line(presentation: presentation).bytesize)
          rows = table_rows
          doc_string = runtime_doc_string || source_doc_string

          if rows && !rows.empty?
            reserve = 2 + (doc_string ? DOC_OMITTED_MARKER.bytesize + 2 : 0)
            caption = table_caption(rows) if presentation && mode == :log
            reserve += caption.bytesize + 2 if caption
            reserve += doc_caption_reserve(doc_string) if presentation && mode == :log && doc_string
            table = data_table_markdown(byte_limit: remaining - reserve, presentation: presentation)
            table = "#{caption}\n\n#{table}" if caption && table
          end
          if table
            sections << table
            remaining -= table.bytesize + 2
          end

          doc = doc_string_markdown(byte_limit: remaining - 2, presentation: presentation, mode: mode) if doc_string
          sections << doc if doc
          sections
        end

        def table_caption(rows)
          columns = row_cells(rows.first).length
          "_Data table \u00b7 #{Presentation::Units.count(columns, 'column')} \u00d7 #{Presentation::Units.count(rows.length - 1, 'row')}_"
        end

        def row_cells(row)
          Array(row.respond_to?(:cells) ? row.cells : row)
        end

        def table_alignment(rows, columns)
          # Alignment is optional; never inspect beyond the existing preview
          # window merely to prove a column numeric, including hidden rows.
          return Array.new(columns, '---') if rows.length > CONTENT_LINE_LIMIT

          numeric = Array.new(columns, true)
          populated = Array.new(columns, false)
          rows.each_with_index do |row, index|
            next if index.zero?
            break unless numeric.any?

            cells = row_cells(row)
            columns.times do |column|
              next unless numeric[column]

              value = cell_value(cells[column])
              if value.bytesize > CELL_BYTE_LIMIT
                numeric[column] = false
                next
              end
              value = value.strip
              next if value.empty?

              populated[column] = true
              numeric[column] = value.match?(NUMERIC_CELL)
            end
          end
          columns.times.map { |column| numeric[column] && populated[column] ? '--:' : '---' }
        end

        # @return [String]
        def keyword_label
          label = @step.respond_to?(:keyword) ? @step.keyword.to_s.strip : ""
          label, truncated = bounded_utf8(label, KEYWORD_BYTE_LIMIT)
          label = "#{label}#{TRUNCATION_MARKER}" if truncated
          label.empty? ? "Step" : label
        end

        # @return [String]
        def step_text
          text = @executed_text.nil? ? source_step_text : @executed_text
          prefix, truncated = bounded_utf8(text.to_s, STEP_TEXT_BYTE_LIMIT)
          prefix = "#{prefix}#{TRUNCATION_MARKER}" if truncated
          prefix.strip
        end

        # @return [String]
        def source_step_text
          if @step.respond_to?(:text)
            @step.text
          elsif @step.respond_to?(:name)
            @step.name
          else
            ""
          end
        end

        # @param byte_limit [Integer]
        # @return [String, nil]
        def data_table_markdown(byte_limit:, presentation: true)
          rows = table_rows
          return nil unless rows && !rows.empty?
          return TABLE_OMITTED_MARKER if byte_limit <= TABLE_OMITTED_MARKER.bytesize

          lines = []
          used_bytes = 0
          rows.each_with_index do |row, index|
            if index >= CONTENT_LINE_LIMIT
              return append_table_marker(lines, used_bytes, byte_limit)
            end

            cells = row_cells(row)
            return append_table_marker(lines, used_bytes, byte_limit) if cells.length > TABLE_COLUMN_LIMIT

            rendered_cells = cells.map { |cell| escape_markdown_cell(cell_value(cell), presentation: presentation) }
            row_line = "| #{rendered_cells.join(' | ')} |"
            if index.zero?
              alignment = presentation ? table_alignment(rows, cells.length) : Array.new(cells.length, '---')
              candidate = [row_line, "| #{alignment.join(' | ')} |"]
            else
              candidate = [row_line]
            end
            candidate_bytes = candidate.sum(&:bytesize) + (candidate.length - 1)
            candidate_bytes += 1 unless lines.empty?
            marker_reserve = rows.length > index + 1 ? TABLE_OMITTED_MARKER.bytesize + 1 : 0

            if used_bytes + candidate_bytes + marker_reserve > byte_limit
              return append_table_marker(lines, used_bytes, byte_limit)
            end

            lines.concat(candidate)
            used_bytes += candidate_bytes
          end
          lines.join("\n")
        end

        # @param lines [Array<String>]
        # @param used_bytes [Integer]
        # @param byte_limit [Integer]
        # @return [String]
        def append_table_marker(lines, used_bytes, byte_limit)
          return TABLE_OMITTED_MARKER if lines.empty?
          return lines.join("\n") unless used_bytes + TABLE_OMITTED_MARKER.bytesize + 1 <= byte_limit

          (lines + [TABLE_OMITTED_MARKER]).join("\n")
        end

        # @return [Array<Array<String>>, nil]
        def runtime_table_rows
          return nil unless @multiline_arg&.respond_to?(:data_table?) && @multiline_arg.data_table?
          return nil unless @multiline_arg.respond_to?(:raw)

          @multiline_arg.raw
        end

        # @return [Array<Object>, nil]
        def source_table_rows
          table = @step.respond_to?(:data_table) ? @step.data_table : nil
          table.rows if table&.respond_to?(:rows)
        end

        # @return [Array<Object>, nil] Only the legacy executed/source table.
        def table_rows
          runtime_table_rows || source_table_rows
        end

        # @param cell [Object]
        # @return [String]
        def cell_value(cell)
          cell.respond_to?(:value) ? cell.value.to_s : cell.to_s
        end

        # @param byte_limit [Integer]
        # @return [String, nil]
        def doc_string_markdown(byte_limit:, presentation: true, mode: :description)
          body = doc_string_body(byte_limit: byte_limit, presentation: presentation)
          return body unless body && presentation && mode == :log

          doc_string = runtime_doc_string || source_doc_string
          type = normalized_media_type(doc_string_media_type(doc_string))
          label = json_media_type?(type) || body.match?(/\A(?:`{3,}|~{3,})json\n/) ? "JSON" : type
          caption = doc_caption(label)
          body = doc_string_body(byte_limit: byte_limit - caption.bytesize - 2, presentation: presentation)
          body ? "#{caption}\n\n#{body}" : nil
        end

        def doc_caption(label)
          label.empty? ? "_Doc string_" : "_Doc string \u00b7 #{Presentation::MarkdownText.inline(label, limit: 128)}_"
        end

        def doc_caption_reserve(doc_string)
          type = normalized_media_type(doc_string_media_type(doc_string))
          label = type.empty? || json_media_type?(type) ? "JSON" : type
          doc_caption(label).bytesize + 2
        end

        def doc_string_body(byte_limit:, presentation:)
          doc_string = runtime_doc_string || source_doc_string
          return nil unless doc_string
          return DOC_OMITTED_MARKER if byte_limit <= DOC_OMITTED_MARKER.bytesize

          content_limit = [CONTENT_BYTE_LIMIT, byte_limit - (MAX_FENCE_BYTES * 2 + 128)].min
          return DOC_OMITTED_MARKER if content_limit <= 0

          content, truncated = bounded_doc_string_content(doc_string_content(doc_string), byte_limit: content_limit)
          return nil if content.empty?

          media_type = doc_string_media_type(doc_string)
          normalized_type = normalized_media_type(media_type)
          declared_json = json_media_type?(normalized_type)
          json = declared_json || (
            normalized_type.empty? && !truncated && content.bytesize <= JSON_PARSE_BYTE_LIMIT && json_value?(content, presentation: presentation)
          )
          fallback_marker = TRUNCATION_MARKER

          if json
            if truncated
              fallback_marker = TRUNCATION_MARKER
            elsif content.bytesize > JSON_PARSE_BYTE_LIMIT
              fallback_marker = "[JSON pretty-print skipped; showing text]"
            else
              begin
                parsed = JSON.parse(content)
                baseline_pretty = JSON.pretty_generate(parsed)
              rescue JSON::ParserError, JSON::GeneratorError
                fallback_marker = declared_json ? "[invalid JSON; shown as text]" : TRUNCATION_MARKER
              else
                pretty = presentation ? Presentation::LedgerJson.format(parsed) : baseline_pretty
                pretty ||= baseline_pretty
                bounded_pretty, pretty_truncated = bounded_doc_string_content(pretty, byte_limit: content_limit)
                unless pretty_truncated
                  block = fenced_block(bounded_pretty, "json", presentation: presentation)
                  return block if block && block.bytesize <= byte_limit
                end
                fallback_marker = "[JSON pretty-print skipped; showing text]"
              end
            end
          end

          content = append_truncation_marker(content, fallback_marker) if truncated || fallback_marker != TRUNCATION_MARKER
          block = fenced_block(content, json ? "json" : doc_string_language(normalized_type), presentation: presentation)
          return block if block && block.bytesize <= byte_limit

          DOC_OMITTED_MARKER
        end

        # @return [Object, nil]
        def runtime_doc_string
          return nil unless @multiline_arg&.respond_to?(:doc_string?) && @multiline_arg.doc_string?

          @multiline_arg
        end

        # @return [Object, nil]
        def source_doc_string
          @step.doc_string if @step.respond_to?(:doc_string)
        end

        # @param doc_string [Object]
        # @return [String]
        def doc_string_content(doc_string)
          return @multiline_content.to_s unless @multiline_content.nil?
          return doc_string.content.to_s if doc_string.respond_to?(:content)

          doc_string.to_s
        end

        # @param doc_string [Object]
        # @return [String]
        def doc_string_media_type(doc_string)
          value = if doc_string.respond_to?(:content_type)
                    doc_string.content_type
                  elsif doc_string.respond_to?(:media_type)
                    doc_string.media_type
                  end
          value.to_s
        end

        # @param content [String]
        # @param byte_limit [Integer]
        # @return [Array<String, Boolean>]
        def bounded_doc_string_content(content, byte_limit:)
          prefix, byte_truncated = bounded_utf8(content, byte_limit)
          lines = []
          line_truncated = false
          prefix.each_line do |line|
            if lines.length >= CONTENT_LINE_LIMIT
              line_truncated = true
              break
            end
            lines << line
          end
          [lines.join, byte_truncated || line_truncated]
        end

        # @param content [String]
        # @param byte_limit [Integer]
        # @return [Array<String, Boolean>]
        def bounded_utf8(content, byte_limit)
          prefix = content.byteslice(0, byte_limit) || ""
          repaired = prefix.dup.force_encoding(Encoding::UTF_8).scrub
          truncated = content.bytesize > byte_limit || repaired.bytesize > byte_limit
          return [repaired, truncated] unless truncated

          bounded = String.new(capacity: byte_limit, encoding: Encoding::UTF_8)
          repaired.each_char do |character|
            break if bounded.bytesize + character.bytesize > byte_limit

            bounded << character
          end
          [bounded, true]
        end

        # @param content [String]
        # @param marker [String]
        # @return [String]
        def append_truncation_marker(content, marker)
          separator = content.empty? || content.end_with?("\n") ? "" : "\n"
          "#{content}#{separator}#{marker}"
        end

        # @param content [String]
        # @param language [String]
        # @return [String, nil]
        def fenced_block(content, language, presentation: true)
          if presentation
            return Presentation::MarkdownText.fence(content, language, limit: CONTENT_BYTE_LIMIT)
          end

          fence = safe_fence(content)
          return nil unless fence

          info = language.empty? ? "" : language
          "#{fence}#{info}\n#{content}\n#{fence}"
        end

        # @param content [String]
        # @return [String, nil]
        def safe_fence(content)
          backticks = longest_fence_run(content, "`")
          return "`" * [3, backticks + 1].max if backticks + 1 <= MAX_FENCE_BYTES

          tildes = longest_fence_run(content, "~")
          return "~" * [3, tildes + 1].max if tildes + 1 <= MAX_FENCE_BYTES

          nil
        end

        # @param content [String]
        # @param character [String]
        # @return [Integer]
        def longest_fence_run(content, character)
          content.scan(/#{Regexp.escape(character)}+/).map(&:length).max || 0
        end

        # @param media_type [String]
        # @return [String]
        def normalized_media_type(media_type)
          type = media_type.to_s.split(";", 2).first.to_s.strip.downcase
          return "application/json" if type == "json"
          return "text/plain" if type == "text"
          return "text/markdown" if type == "markdown"

          type
        end

        # @param media_type [String]
        # @return [Boolean]
        def json_media_type?(media_type)
          type = normalized_media_type(media_type)
          type == "application/json" || type.match?(%r{\Aapplication/[a-z0-9!#$&^_.+-]+\+json\z})
        end

        # @param content [String]
        # @return [Boolean]
        def json_value?(content, presentation: true)
          value = JSON.parse(content)
          presentation || !value.nil?
        rescue JSON::ParserError
          false
        end

        # @param media_type [String]
        # @return [String]
        def doc_string_language(media_type)
          case normalized_media_type(media_type)
          when "application/json"
            "json"
          when "text/plain"
            "text"
          when "text/markdown"
            "markdown"
          else
            json_media_type?(media_type) ? "json" : ""
          end
        end

        # @param value [String]
        # @return [String]
        def escape_markdown_cell(value, presentation: true)
          return Presentation::MarkdownText.cell(value, limit: CELL_BYTE_LIMIT) if presentation

          prefix, truncated = bounded_utf8(value, CELL_BYTE_LIMIT)
          escaped = prefix.gsub(/[\\|]/) { |character| "\\#{character}" }
          escaped = escaped.gsub(/\r\n|\r|\n/, "<br>")
          truncated ? "#{escaped}#{TRUNCATION_MARKER}" : escaped
        end
      end
    end
  end
end
