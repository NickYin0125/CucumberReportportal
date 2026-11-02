# frozen_string_literal: true

require_relative "fallback"

module ReportportalCucumber
  module Presentation
    # Reads only headers; never decodes, guesses MIME, or mutates image evidence.
    module ImageDimensions
      HEADER_LIMIT = 64 * 1024
      PNG_SIGNATURE = "\x89PNG\r\n\x1a\n".b.freeze
      SOF_MARKERS = [0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].freeze

      # @param bytes [String] At most the first 64 KiB will be inspected.
      # @param mime [String] Declared MIME; signature mismatch omits dimensions.
      # @return [Array<Integer>, nil] Width and height, or no trustworthy header.
      def self.read(bytes, mime:)
        Fallback.render(fallback: -> { nil }) do
          next nil unless bytes.is_a?(String)

          header = bytes.byteslice(0, HEADER_LIMIT).b
          dimensions = case mime.to_s.split(";", 2).first.to_s.strip.downcase
                       when "image/png" then png(header)
                       when "image/jpeg" then jpeg(header)
                       end
          dimensions if dimensions && dimensions.all?(&:positive?)
        end
      end

      def self.png(header)
        return nil unless header.bytesize >= 24 && header.start_with?(PNG_SIGNATURE)
        return nil unless header.byteslice(8, 4).unpack1("N") == 13 && header.byteslice(12, 4) == "IHDR"

        header.byteslice(16, 8).unpack("NN")
      end

      def self.jpeg(header)
        return nil unless header.start_with?("\xff\xd8\xff".b)

        offset = 2
        while offset < header.bytesize
          return nil unless header.getbyte(offset) == 0xff

          offset += 1 while header.getbyte(offset) == 0xff
          marker = header.getbyte(offset)
          return nil unless marker
          return nil if marker == 0xda || marker == 0xd9 || marker.zero?

          offset += 1
          next if marker == 0xd8 || marker == 0x01 || (0xd0..0xd7).cover?(marker)
          return nil if offset + 2 > header.bytesize

          length = header.byteslice(offset, 2).unpack1("n")
          return nil if length < 2 || offset + length > header.bytesize
          if SOF_MARKERS.include?(marker)
            return nil if length < 8

            height, width = header.byteslice(offset + 3, 4).unpack("nn")
            return [width, height]
          end
          offset += length
        end
        nil
      end
      private_class_method :png, :jpeg
    end
  end
end
