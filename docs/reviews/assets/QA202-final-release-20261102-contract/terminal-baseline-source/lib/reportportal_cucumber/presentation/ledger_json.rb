# frozen_string_literal: true

require "json"
require_relative "fallback"

module ReportportalCucumber
  module Presentation
    # Deterministic JSON layout without changing key order or scalar spelling.
    module LedgerJson
      INPUT_LIMIT = 64 * 1024
      NODE_LIMIT = 4096
      DEPTH_LIMIT = 32
      WIDTH = 72

      # @param value [Hash, Array, String, Numeric, Boolean, nil] Parsed JSON value,
      #   not JSON source text. Strings are serialized as JSON strings.
      # @return [String, nil] Pretty JSON with scalar-only containers collapsed
      #   within 72 columns; nil for cyclic, unsupported, or over-budget input.
      #   Traversal is limited to 4,096 nodes, depth 32 and 64 KiB scalar data.
      def self.format(value)
        Fallback.render(fallback: -> { nil }) do
          next nil unless bounded_value?(value, { nodes: NODE_LIMIT, bytes: INPUT_LIMIT }, 0)

          pretty = JSON.pretty_generate(value, max_nesting: DEPTH_LIMIT)
          compact_containers(pretty)
        end
      end

      def self.bounded_value?(value, budget, depth)
        budget[:nodes] -= 1
        return false if budget[:nodes] < 0 || depth > DEPTH_LIMIT

        case value
        when Hash
          value.all? do |key, item|
            (key.is_a?(String) || key.is_a?(Symbol)) &&
              bounded_value?(key.to_s, budget, depth + 1) && bounded_value?(item, budget, depth + 1)
          end
        when Array
          value.all? { |item| bounded_value?(item, budget, depth + 1) }
        when String
          budget[:bytes] -= value.bytesize
          budget[:bytes] >= 0 && value.valid_encoding?
        when Integer
          budget[:bytes] -= value.bit_length + 2
          value.bit_length <= 10_000 && budget[:bytes] >= 0
        when Float
          budget[:bytes] -= 32
          value.finite? && budget[:bytes] >= 0
        when TrueClass, FalseClass, NilClass
          budget[:bytes] -= 5
          budget[:bytes] >= 0
        else
          false
        end
      end

      def self.compact_containers(pretty)
        # Work on JSON.pretty_generate's lines, preserving its scalar formatting.
        lines = pretty.lines(chomp: true)
        stack = []
        lines.each_index do |index|
          line = lines[index]
          if line.match?(/[\[{]\z/)
            stack.last[:nested] = true unless stack.empty?
            stack << { start: index, nested: false }
          elsif line.match?(/\A\s*[\]}],?\z/)
            container = stack.pop
            next unless container && !container[:nested]

            start = container[:start]
            opening = lines[start]
            members = lines[(start + 1)...index].map(&:strip).join(" ")
            object = opening.end_with?("{")
            compact = opening + (object ? " " : "") + members + (object ? " " : "") + line.strip
            next if compact.length > WIDTH

            lines[start] = compact
            ((start + 1)..index).each { |position| lines[position] = nil }
          end
        end
        lines.compact.join("\n")
      end
      private_class_method :bounded_value?, :compact_containers
    end
  end
end
