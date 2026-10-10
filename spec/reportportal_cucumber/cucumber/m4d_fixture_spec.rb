# frozen_string_literal: true

require "spec_helper"
require "digest"
require "zlib"
require_relative "../../../examples/m4_delivery_acceptance/png_fixture"

RSpec.describe "M4-D live visual fixture" do
  it "is a deterministic PNG with valid chunk CRCs and an exact 80 by 40 RGB raster" do
    png = M4DeliveryPNG.bytes
    expect(png.encoding).to eq(Encoding::BINARY)
    expect(png).to be_frozen
    expect(png.byteslice(0, 8)).to eq("\x89PNG\r\n\x1A\n".b)
    offset = 8
    chunks = []
    until offset == png.bytesize
      expect(png.bytesize - offset).to be >= 12
      length = png.byteslice(offset, 4).unpack1("N")
      type = png.byteslice(offset + 4, 4)
      expect(offset + 12 + length).to be <= png.bytesize
      payload = png.byteslice(offset + 8, length)
      crc = png.byteslice(offset + 8 + length, 4).unpack1("N")
      expect(crc).to eq(Zlib.crc32(type + payload)), "#{type} CRC is invalid"
      chunks << [type, payload]
      offset += 12 + length
    end
    expect(chunks.map(&:first)).to eq(%w[IHDR IDAT IEND])
    expect(chunks.first.last.unpack("NNC5")).to eq([80, 40, 8, 2, 0, 0, 0])
    expect(chunks.last.last).to eq("".b)
    raster = Zlib::Inflate.inflate(chunks[1][1])
    expect(raster.bytesize).to eq(40 * (1 + 80 * 3))
    expected_pixels = []
    40.times do |y|
      row = raster.byteslice(y * 241, 241)
      expect(row.getbyte(0)).to eq(0)
      pixels = row.byteslice(1, 240).bytes.each_slice(3).to_a
      80.times do |x|
        expected = if x < 5 || y < 5 || x >= 75 || y >= 35
                     [20, 70, 80]
                   elsif x < 40
                     [30, 170 + y, 150]
                   else
                     [240, 190, 60 + y]
                   end
        expect(pixels.fetch(x)).to eq(expected)
        expected_pixels << expected
      end
    end
    expect(expected_pixels.uniq.length).to eq(61)
    expect(Digest::SHA256.hexdigest(M4DeliveryPNG.bytes)).to eq(Digest::SHA256.hexdigest(png))
  end
end
