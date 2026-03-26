# frozen_string_literal: true

module ReportportalCucumber
  module ReportPortal
    module Models
      # Builds markdown-rich descriptions for Gherkin steps.
      class StepDesc
        # @param step [Object]
        # @param multiline_content [String, nil]
        def initialize(step:, multiline_content: nil)
          @step = step
          @multiline_content = multiline_content
        end

        # @param test_step [Object]
        # @param ast_lookup [Object]
        # @return [ReportportalCucumber::ReportPortal::Models::StepDesc, nil]
        def self.from_test_step(test_step, ast_lookup:)
          source = ast_lookup&.step_source(test_step)
          return nil unless source&.respond_to?(:step) && source.step

          multiline_content =
            if test_step.respond_to?(:multiline_arg) && test_step.multiline_arg.respond_to?(:content)
              test_step.multiline_arg.content
            end

          new(step: source.step, multiline_content: multiline_content)
        rescue StandardError
          nil
        end

        # @return [String]
        def summary_name
          parts = [keyword_label, step_text].reject(&:empty?)
          parts.join(" ").strip
        end

        # @return [String]
        def to_markdown
          sections = [header_line]
          multiline_sections.each do |section|
            sections << section unless section.to_s.strip.empty?
          end
          sections.join("\n\n")
        end

        private

        # @return [String]
        def header_line
          if step_text.empty?
            "**#{keyword_label}**"
          else
            "**#{keyword_label}** #{step_text}"
          end
        end

        # @return [Array<String>]
        def multiline_sections
          [data_table_markdown, doc_string_markdown].compact
        end

        # @return [String]
        def keyword_label
          label = @step.respond_to?(:keyword) ? @step.keyword.to_s.strip : ""
          label.empty? ? "Step" : label
        end

        # @return [String]
        def step_text
          if @step.respond_to?(:text)
            @step.text.to_s.strip
          elsif @step.respond_to?(:name)
            @step.name.to_s.strip
          else
            ""
          end
        end

        # @return [String, nil]
        def data_table_markdown
          data_table = @step.respond_to?(:data_table) ? @step.data_table : nil
          return nil unless data_table && data_table.respond_to?(:rows)

          rows = data_table.rows.map do |row|
            cells = row.respond_to?(:cells) ? row.cells : []
            cells.map do |cell|
              value = cell.respond_to?(:value) ? cell.value : cell
              escape_markdown_cell(value.to_s)
            end
          end
          return nil if rows.empty?

          header = rows.first
          lines = []
          lines << "| #{header.join(' | ')} |"
          lines << "| #{Array.new(header.length, '---').join(' | ')} |"
          rows.drop(1).each do |row|
            lines << "| #{row.join(' | ')} |"
          end
          lines.join("\n")
        end

        # @return [String, nil]
        def doc_string_markdown
          doc_string = @step.respond_to?(:doc_string) ? @step.doc_string : nil
          return nil unless doc_string

          content = extract_doc_string_content
          return nil if content.empty?

          media_type = doc_string.respond_to?(:media_type) ? doc_string.media_type.to_s : ""
          if json_doc_string?(content, media_type)
            "```json\n#{pretty_json(content)}\n```"
          else
            info_string = doc_string_language(media_type)
            "```#{info_string}\n#{content}\n```"
          end
        end

        # @return [String]
        def extract_doc_string_content
          content = @multiline_content
          if content.to_s.empty? && @step.respond_to?(:doc_string) && @step.doc_string.respond_to?(:content)
            content = @step.doc_string.content
          end
          content.to_s
        end

        # @param content [String]
        # @param media_type [String]
        # @return [Boolean]
        def json_doc_string?(content, media_type)
          media_type.to_s.downcase == "application/json" || !JSON.parse(content).nil?
        rescue JSON::ParserError
          false
        end

        # @param content [String]
        # @return [String]
        def pretty_json(content)
          JSON.pretty_generate(JSON.parse(content))
        rescue JSON::ParserError
          content
        end

        # @param media_type [String]
        # @return [String]
        def doc_string_language(media_type)
          case media_type.to_s.downcase
          when "application/json"
            "json"
          when "text/plain"
            "text"
          when "text/markdown"
            "markdown"
          else
            ""
          end
        end

        # @param value [String]
        # @return [String]
        def escape_markdown_cell(value)
          value.gsub("\\", "\\\\").gsub("|", "\\|").gsub("\n", "<br>")
        end
      end
    end
  end
end
