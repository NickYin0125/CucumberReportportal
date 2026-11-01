# frozen_string_literal: true

require "zlib"

module LedgerDeveloper
  # Deterministic generator copied from cucumber12_live_testcards.rb, without
  # its runner or file-writing code. Both SDK lines retain the same media bytes.
  module Testcards
    SHA256 = %w[
      e0670cf624674df9a2485177d68ca12d3dc501db2249e05c325a999c22db2bc0
      3b8bb02939a65d0a6b2b2f1f09ead0e0ef307b7a9980728597b8acd6e4cb6e81
      90d4861ea3069cf643e614eb93042c1798f7734a67db85dcd321f47fc93ff4ec
      37d0ec24678bd20d7185ebce206476c6b3b7a67976342e12c5839e0793e93a19
      034995c752ea5f3ccd11ddbdb825ef40a9abf43fcd16ef43dcb97ae4d4f3567c
      f11a227b89c21a5e4f5780686e4c64855d53eab2c55280a6402bcf650c83b3c3
      b41e221f01c5be5a6490fd7450ed2ef936728244b6a75002fcc4bbfb66e6cf62
      7d64d0ab42a432766f9aca9089bd3d5df3f4dfbe9b0b85d382a45806ecb36b2f
      41d60d3f8fe7fa1be586975b3874aceced291a5f1e55b32c2f6c7d0531700753
      d0e84ea0d515941ef90306584433121aad9f443b85fe5093f27f34424af4a966
    ].freeze

    FONT = {
      " " => %w[00000 00000 00000 00000 00000 00000 00000],
      "0" => %w[01110 10001 10011 10101 11001 10001 01110],
      "1" => %w[00100 01100 00100 00100 00100 00100 01110],
      "2" => %w[01110 10001 00001 00010 00100 01000 11111],
      "3" => %w[11110 00001 00001 01110 00001 00001 11110],
      "4" => %w[00010 00110 01010 10010 11111 00010 00010],
      "5" => %w[11111 10000 10000 11110 00001 00001 11110],
      "6" => %w[01110 10000 10000 11110 10001 10001 01110],
      "7" => %w[11111 00001 00010 00100 01000 01000 01000],
      "8" => %w[01110 10001 10001 01110 10001 10001 01110],
      "9" => %w[01110 10001 10001 01111 00001 00001 01110],
      "A" => %w[01110 10001 10001 11111 10001 10001 10001],
      "C" => %w[01111 10000 10000 10000 10000 10000 01111],
      "E" => %w[11111 10000 10000 11110 10000 10000 11111],
      "F" => %w[11111 10000 10000 11110 10000 10000 10000],
      "H" => %w[10001 10001 10001 11111 10001 10001 10001],
      "I" => %w[11111 00100 00100 00100 00100 00100 11111],
      "N" => %w[10001 11001 10101 10011 10001 10001 10001],
      "O" => %w[01110 10001 10001 10001 10001 10001 01110],
      "P" => %w[11110 10001 10001 11110 10000 10000 10000],
      "R" => %w[11110 10001 10001 11110 10100 10010 10001],
      "S" => %w[01111 10000 10000 01110 00001 00001 11110],
      "T" => %w[11111 00100 00100 00100 00100 00100 00100],
      "U" => %w[10001 10001 10001 10001 10001 10001 01110],
      "X" => %w[10001 10001 01010 00100 01010 10001 10001],
      "Y" => %w[10001 10001 01010 00100 00100 00100 00100]
    }.freeze

    module_function

    def chunk(type, bytes)
      [bytes.bytesize].pack("N") + type.b + bytes + [Zlib.crc32(type.b + bytes)].pack("N")
    end

    def png(index)
      width, height = 640, 360
      rows = Array.new(height) do |y|
        Array.new(width) do |x|
          y < 16 ? [19, 113 + index * 7, 129] : [240 - x / 40, 243 - y / 24, 231 + index]
        end
      end
      text = lambda do |label, left, top, scale, color|
        label.each_char.with_index do |letter, i|
          FONT.fetch(letter).each_with_index do |bits, y|
            bits.chars.each_with_index do |bit, x|
              next unless bit == "1"
              scale.times do |dy|
                scale.times { |dx| rows[top + y * scale + dy][left + (i * 6 + x) * scale + dx] = color }
              end
            end
          end
        end
      end
      text.call("SYNTHETIC RP", 40, 45, 5, [19, 74, 79])
      text.call(format("FIXTURE %02d", index), 40, 110, 8, [18 + index * 9, 85, 105])
      text.call("640 X 360", 40, 215, 4, [50, 66, 65])
      text.call("NOT A SCREEN CAPTURE", 40, 280, 3, [111, 62, 32])
      scanlines = rows.map { |row| "\0".b + row.flatten.pack("C*") }.join
      "\x89PNG\r\n\x1a\n".b + chunk("IHDR", [width, height, 8, 2, 0, 0, 0].pack("NNC5")) +
        chunk("IDAT", Zlib::Deflate.deflate(scanlines)) + chunk("IEND", "".b)
    end
  end
end
