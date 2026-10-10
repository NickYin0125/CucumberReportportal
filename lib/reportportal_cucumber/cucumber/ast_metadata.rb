# frozen_string_literal: true

require "gherkin"
require "set"

module ReportportalCucumber
  module Cucumber
    # Reads feature, scenario, and step context from official Gherkin ASTs.
    class AstMetadata
      # @param ast_lookup [Object, nil] Cucumber's native AST lookup, when available
      def initialize(ast_lookup: nil)
        @ast_lookup = ast_lookup
        @documents = {}
        @scenario_index = {}
        @step_index = {}
      end

      # @param uri [String]
      # @return [Hash, nil] Feature name, keyword, description, and language
      def feature(uri:)
        document = document_for(uri)
        node = read(document, :feature)
        return unless node

        {
          name: read(node, :name),
          keyword: read(node, :keyword),
          description: clean_description(read(node, :description)),
          language: read(node, :language)
        }
      end

      # @param uri [String]
      # @param location_line [Integer]
      # @return [Hash, nil] Scenario metadata, including outline parameters when applicable
      def scenario(uri:, location_line:)
        return if location_line.nil?

        entry = scenario_index(uri)[location_line.to_i]
        return unless entry

        scenario_node = entry.fetch(:scenario)
        examples = entry[:examples]
        row = entry[:row]
        headers = read(read(examples, :table_header), :cells)
        values = read(row, :cells)
        parameters = if row && headers && values && headers.length == values.length
                       headers.zip(values).to_h { |header, value| [read(header, :value).to_s, read(value, :value).to_s] }
                     end

        {
          scenario_line: read(read(scenario_node, :location), :line),
          scenario_name: read(scenario_node, :name),
          identity_ambiguous: entry.fetch(:identity_ambiguous),
          description: clean_description(read(scenario_node, :description)),
          rule_name: read(entry[:rule], :name),
          rule_description: clean_description(read(entry[:rule], :description)),
          examples_name: read(examples, :name),
          example_row_line: read(read(row, :location), :line),
          parameters: parameters,
          tag_scopes: {
            feature: tag_names(entry[:feature]),
            rule: tag_names(entry[:rule]),
            scenario: tag_names(scenario_node),
            examples: tag_names(examples)
          }
        }
      end

      # @param test_step [Object]
      # @return [Hash, nil] Background classification and its feature/rule scope
      def step(test_step)
        uri = nested_read(test_step, :location, :file)
        lines = nested_read(test_step, :location, :lines)
        line = lines.min if lines.respond_to?(:min)
        line ||= nested_read(test_step, :location, :line)
        return unless uri && line

        entry = step_index(uri)[line.to_i]
        return unless entry && entry[:background]

        {
          background: true,
          background_scope: entry[:rule] ? :rule : :feature,
          rule_name: read(entry[:rule], :name)
        }
      end

      # @param uri [String]
      # @param text [String]
      # @return [Hash, nil] Background metadata only when text identifies one source step uniquely
      def background_for_text(uri:, text:)
        candidates = source_steps(uri).select { |entry| entry[:text] == text.to_s.strip }
        return unless candidates.length == 1 && candidates.first[:background]

        entry = candidates.first
        { background: true, background_scope: entry[:rule] ? :rule : :feature, rule_name: read(entry[:rule], :name) }
      end

      private

      # @param uri [String]
      # @return [Object, nil]
      def document_for(uri)
        key = uri.to_s
        return @documents[key] if @documents.key?(key)

        document = if @ast_lookup&.respond_to?(:gherkin_document)
                     @ast_lookup.gherkin_document(uri)
                   end
        document ||= parse_document(uri)
        @documents[key] = document
      rescue StandardError
        @documents[key] = nil
      end

      # @param uri [String]
      # @return [Object, nil]
      def parse_document(uri)
        return unless File.file?(uri.to_s)
        return unless ::Gherkin.respond_to?(:from_source)

        source = File.read(uri.to_s)
        envelope = ::Gherkin.from_source(
          uri.to_s,
          source,
          include_source: false,
          include_gherkin_document: true,
          include_pickles: false
        ).find { |message| read(message, :gherkin_document) }
        read(envelope, :gherkin_document)
      rescue StandardError
        nil
      end

      # @param uri [String]
      # @return [Hash]
      def scenario_index(uri)
        @scenario_index[uri.to_s] ||= begin
          index = {}
          feature_node = read(document_for(uri), :feature)
          visit_container(feature_node, nil) do |scenario_node, rule, examples, row|
            line = read(read(row || scenario_node, :location), :line)
            index[line.to_i] = {
              feature: feature_node, scenario: scenario_node, rule: rule, examples: examples, row: row
            } if line
          end
          headers = index.values.uniq { |entry| entry[:scenario].object_id }
          counts = headers.each_with_object(Hash.new(0)) do |entry, memo|
            key = [read(entry[:rule], :name).to_s, read(entry[:scenario], :name).to_s]
            memo[key] += 1
          end
          index.each_value do |entry|
            key = [read(entry[:rule], :name).to_s, read(entry[:scenario], :name).to_s]
            entry[:identity_ambiguous] = counts[key] > 1
          end
          index
        end
      end

      # @param uri [String]
      # @return [Hash]
      def step_index(uri)
        @step_index[uri.to_s] ||= begin
          index = {}
          feature_node = read(document_for(uri), :feature)
          visit_container(feature_node, nil) do |scenario_node, rule, _examples, _row|
            next unless scenario_node

            Array(read(scenario_node, :steps)).each do |step_node|
              line = read(read(step_node, :location), :line)
              index[line.to_i] = { rule: rule, background: false } if line
            end
          end
          visit_backgrounds(feature_node, nil, index)
          index
        end
      end

      # @param container [Object]
      # @param rule [Object, nil]
      # @yield [scenario, rule, examples, row]
      # @return [void]
      def visit_container(container, rule, &block)
        Array(read(container, :children)).each do |child|
          child_rule = read(child, :rule)
          if child_rule
            visit_container(child_rule, child_rule, &block)
            next
          end

          scenario_node = read(child, :scenario)
          next unless scenario_node

          examples_list = Array(read(scenario_node, :examples))
          if examples_list.empty?
            block.call(scenario_node, rule, nil, nil)
          else
            block.call(scenario_node, rule, nil, nil)
            examples_list.each do |examples|
              Array(read(examples, :table_body)).each do |row|
                block.call(scenario_node, rule, examples, row)
              end
            end
          end
        end
      end

      # @param container [Object]
      # @param rule [Object, nil]
      # @param index [Hash]
      # @return [void]
      def visit_backgrounds(container, rule, index)
        Array(read(container, :children)).each do |child|
          child_rule = read(child, :rule)
          if child_rule
            visit_backgrounds(child_rule, child_rule, index)
            next
          end

          background = read(child, :background)
          Array(read(background, :steps)).each do |step_node|
            line = read(read(step_node, :location), :line)
            index[line.to_i] = { rule: rule, background: true } if line
          end
        end
      end

      # @param object [Object, nil]
      # @param key [Symbol]
      # @return [Object, nil]
      def read(object, key)
        return if object.nil?

        object.respond_to?(key) ? object.public_send(key) : nil
      end

      # @param object [Object, nil]
      # @param keys [Array<Symbol>]
      # @return [Object, nil]
      def nested_read(object, *keys)
        keys.reduce(object) { |value, key| read(value, key) }
      end

      # @param description [String, nil]
      # @return [String, nil]
      def clean_description(description)
        value = description.to_s.strip
        value.empty? ? nil : value
      end

      # @param node [Object, nil]
      # @return [Array<String>]
      def tag_names(node)
        Array(read(node, :tags)).filter_map do |tag|
          name = read(tag, :name)
          name.to_s unless name.nil?
        end
      end

      # @param uri [String]
      # @return [Array<Hash>]
      def source_steps(uri)
        entries = []
        feature_node = read(document_for(uri), :feature)
        collect_steps(feature_node, nil, entries)
        entries
      end

      # @param container [Object]
      # @param rule [Object, nil]
      # @param entries [Array<Hash>]
      # @return [void]
      def collect_steps(container, rule, entries)
        Array(read(container, :children)).each do |child|
          child_rule = read(child, :rule)
          if child_rule
            collect_steps(child_rule, child_rule, entries)
            next
          end

          background = read(child, :background)
          scenario_node = read(child, :scenario)
          node = background || scenario_node
          Array(read(node, :steps)).each do |step_node|
            entries << { text: read(step_node, :text).to_s.strip, background: !background.nil?, rule: rule }
          end
        end
      end
    end
  end
end
