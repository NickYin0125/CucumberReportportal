# frozen_string_literal: true

require_relative "fallback"

module ReportportalCucumber
  module Presentation
    # Locale-independent display units. Evidence values themselves stay intact.
    module Units
      OMITTED = "[unit omitted]".freeze

      # @param value [Integer] Non-negative byte count.
      # @return [String] Base-1024 B, KB or MB, with at most one decimal below 10.
      def self.bytes(value)
        Fallback.render(fallback: -> { OMITTED }) do
          next OMITTED unless valid_number?(value) && value.is_a?(Integer)
          next "#{value} B" if value < 1024

          unit = value < 1024 * 1024 ? "KB" : "MB"
          size = value.fdiv(unit == "KB" ? 1024 : 1024 * 1024)
          digits = size < 10 ? Kernel.format("%.1f", size).sub(/\.0\z/, "") : size.round.to_s
          "#{digits} #{unit}"
        end
      end

      # @param value [Integer] Non-negative count.
      # @param singular [String] Singular noun, e.g. "row".
      # @param plural [String] Optional irregular plural; defaults to noun + "s".
      # @return [String] Count and singular/plural noun, bounded to 128 noun bytes.
      def self.count(value, singular, plural = nil)
        Fallback.render(fallback: -> { OMITTED }) do
          next OMITTED unless valid_number?(value) && value.is_a?(Integer)
          next OMITTED unless singular.is_a?(String) && singular.bytesize <= 128
          next OMITTED unless plural.nil? || (plural.is_a?(String) && plural.bytesize <= 128)

          "#{value} #{value == 1 ? singular : (plural || singular + 's')}"
        end
      end

      # @param value [Integer, Float] Non-negative duration in milliseconds.
      # @return [String] Rounded integer milliseconds below 1 s, else one decimal s.
      def self.duration(value)
        Fallback.render(fallback: -> { OMITTED }) do
          next OMITTED unless valid_number?(value)

          value < 1000 ? "#{value.round} ms" : "#{Kernel.format('%.1f', value / 1000.0)} s"
        end
      end

      def self.valid_number?(value)
        (value.is_a?(Integer) && value.bit_length <= 128 && value >= 0) ||
          (value.is_a?(Float) && value.finite? && value >= 0 && value <= 2**128)
      end
      private_class_method :valid_number?
    end
  end
end
