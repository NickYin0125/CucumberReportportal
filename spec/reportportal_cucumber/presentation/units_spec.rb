# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Presentation::Units do
  it "formats the specified byte examples and unit boundaries" do
    { 0 => "0 B", 75 => "75 B", 1023 => "1023 B", 1024 => "1 KB", 5421 => "5.3 KB",
      10_240 => "10 KB", 36_612 => "36 KB", 1_048_576 => "1 MB", 1_258_291 => "1.2 MB" }.each do |input, expected|
      expect(described_class.bytes(input)).to eq(expected)
    end
  end

  it "formats duration and singular/plural counts" do
    expect(described_class.duration(84)).to eq("84 ms")
    expect(described_class.duration(999)).to eq("999 ms")
    expect(described_class.duration(1000)).to eq("1.0 s")
    expect(described_class.duration(1400)).to eq("1.4 s")
    expect(described_class.count(1, "row")).to eq("1 row")
    expect(described_class.count(2, "column")).to eq("2 columns")
    expect(described_class.count(62, "frame")).to eq("62 frames")
    expect(described_class.count(0, "child", "children")).to eq("0 children")
  end

  it "declines negative, non-finite and unbounded values" do
    [-1, Float::INFINITY, Float::NAN, 2**10_000, Object.new].each do |value|
      expect(described_class.bytes(value)).to eq(described_class::OMITTED)
      expect(described_class.duration(value)).to eq(described_class::OMITTED)
      expect(described_class.count(value, "row")).to eq(described_class::OMITTED)
    end
  end
end
