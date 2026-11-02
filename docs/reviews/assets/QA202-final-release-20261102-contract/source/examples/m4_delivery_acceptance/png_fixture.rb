# frozen_string_literal: true

require "zlib"

module M4DeliveryPNG
  WIDTH = 80
  HEIGHT = 40
  SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze

  def self.chunk(type, payload)
    body = type.b + payload.b
    [payload.bytesize].pack("N") + body + [Zlib.crc32(body)].pack("N")
  end

  def self.bytes
    @bytes ||= begin
      raster = String.new(encoding: Encoding::BINARY)
      HEIGHT.times do |y|
        raster << "\x00".b
        WIDTH.times do |x|
          rgb = if x < 5 || y < 5 || x >= WIDTH - 5 || y >= HEIGHT - 5
                  [20, 70, 80]
                elsif x < WIDTH / 2
                  [30, 170 + y, 150]
                else
                  [240, 190, 60 + y]
                end
          raster << rgb.pack("C3")
        end
      end
      header = [WIDTH, HEIGHT, 8, 2, 0, 0, 0].pack("NNC5")
      (SIGNATURE + chunk("IHDR", header) +
        chunk("IDAT", Zlib::Deflate.deflate(raster, Zlib::BEST_COMPRESSION)) + chunk("IEND", "".b)).freeze
    end
  end
end
