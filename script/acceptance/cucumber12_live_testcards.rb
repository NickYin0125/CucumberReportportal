# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "zlib"

module Cucumber12LiveTestcards
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

  def generate(directory)
    FileUtils.mkdir_p(directory)
    manifest = (1..10).map do |index|
      bytes = png(index)
      name = format("screenshot-%02d.png", index)
      File.binwrite(File.join(directory, name), bytes)
      { "name" => name, "width" => 640, "height" => 360, "sha256" => Digest::SHA256.hexdigest(bytes),
        "description" => "Deterministic synthetic test card, not a browser screenshot" }
    end
    File.write(File.join(directory, "manifest.json"), JSON.pretty_generate(manifest) + "\n")
    manifest
  end
end

if $PROGRAM_NAME == __FILE__
  directory = File.expand_path(ARGV.fetch(0))
  allowed = File.expand_path("../../tmp/cucumber12-independent/live/", __dir__) + "/"
  raise "Output outside owned evidence" unless directory.start_with?(allowed)
  puts JSON.generate(Cucumber12LiveTestcards.generate(directory))
end
