# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Presentation::LedgerJson do
  it "matches the attachment and scalar-object goldens without reordering keys" do
    value = { "source" => "independent acceptance", "synthetic" => true, "values" => [1, true, nil] }
    expect(described_class.format(value)).to eq(<<~JSON.chomp)
      {
        "source": "independent acceptance",
        "synthetic": true,
        "values": [1, true, null]
      }
    JSON
    expect(described_class.format(currency: "USD", notional: 5000000))
      .to eq('{ "currency": "USD", "notional": 5000000 }')
  end

  it "collapses only scalar containers, bottom-up, and includes indentation in the 72-column bound" do
    value = { "nested" => [{ "z" => 1, "a" => 2 }], "wide" => ["x" * 61], "fits" => ["x" * 56] }
    text = described_class.format(value)
    expect(text).to include("  \"nested\": [\n    { \"z\": 1, \"a\": 2 }\n  ]")
    expect(text).to include("  \"wide\": [\n", "  \"fits\": [\"#{'x' * 56}\"]")
    expect(JSON.parse(text)).to eq(value)
  end

  it "preserves scalar JSON spelling, strings, escapes and empty containers" do
    [1.0, -0.0, 1.0e30, nil, true, "a\n[]{}\\\"", [], {}, [[], {}], [1, 2]].each do |value|
      text = described_class.format(value)
      expect(JSON.parse(text)).to eq(value)
      expect(text).to eq(described_class.format(value))
    end
    expect(described_class.format(1.0)).to eq("1.0")
  end

  it "declines unsafe, cyclic, over-deep and oversized input without invoking arbitrary conversion" do
    cycle = []
    cycle << cycle
    [cycle, Object.new, Float::NAN, "x" * 65_537, Array.new(5000, 1), "\xFF".b].each do |value|
      expect(described_class.format(value)).to be_nil
    end
  end
end
