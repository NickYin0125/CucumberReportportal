# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Config do
  it "defaults the spool quota to a finite 256 MiB and accepts a strict decimal override" do
    expect(described_class.new.spool_max_bytes).to eq(268_435_456)
    expect(described_class.load(env: { "RP_SPOOL_MAX_BYTES" => "4096" }, yaml_path: File::NULL).spool_max_bytes).to eq(4096)
  end

  it "rejects non-positive and non-decimal spool quotas without echoing the value" do
    [0, -1, "0", "-1", "1.5", "1e3", "256MiB", " 10 ", "+2", true].each do |value|
      error = begin
        described_class.new(spool_max_bytes: value)
        nil
      rescue ArgumentError => raised
        raised
      end
      expect(error).to be_a(ArgumentError)
      expect(error.message).not_to include(value.to_s)
    end
  end
end
