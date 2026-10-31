# frozen_string_literal: true

require_relative "cucumber12_blackbox"

RSpec.describe "Independent installed SDK 2.0 / Cucumber12 acceptance" do
  before(:context) { @audit = Cucumber12Independent::Audit.new.setup }

  (1..14).each do |number|
    id = format("TC%02d", number)
    it "#{id} checks the supported contract and classifies literal request gaps" do
      @audit.run_case(id)
      row = @audit.report.fetch("cases").fetch(id)
      expect(row.fetch("failures")).to eq([]), row.fetch("failures").join("\n")
      expected_status = { "TC01" => "APPLICABILITY", "TC03" => "APPLICABILITY", "TC04" => "UNSUPPORTED", "TC08" => "APPLICABILITY" }.fetch(id, "PASS")
      expect(row.fetch("status")).to eq(expected_status)
      expect(row.fetch("supportedContractStatus")).to eq(id == "TC04" ? "NOT_APPLICABLE" : "PASS")
      expect(row.fetch("requestedGaps")).not_to be_empty if %w[TC01 TC03 TC04 TC08].include?(id)
    end
  end

  after(:context) { @audit&.finish }

  it "closes every item, emits no unhandled thread exception, and owns ten distinct screenshots" do
    report = @audit.finish
    expect(report.fetch("hardGates").transform_values { |row| row.fetch("pass") }).to eq(
      "noInProgress" => true, "noUnhandledThreadExceptions" => true, "tenDistinctScreenshots" => true
    )
  end
end
