# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Config do
  describe ".detect_profile_from_argv" do
    it "extracts the short profile flag" do
      expect(described_class.detect_profile_from_argv(%w[-p rerun_config])).to eq("rerun_config")
    end

    it "extracts the long profile flag" do
      expect(described_class.detect_profile_from_argv(["--profile=verification"])).to eq("verification")
    end
  end
end
