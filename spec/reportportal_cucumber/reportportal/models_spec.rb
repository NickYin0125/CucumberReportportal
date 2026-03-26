# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::ReportPortal::Models do
  describe ".build_test_case_id" do
    it "uses the explicit id and appends normalized parameters" do
      identifier = described_class.build_test_case_id(
        explicit_id: "TMS-123",
        code_ref: "features/a.feature:12",
        parameters: { example: 1, login: "ok" }
      )

      expect(identifier).to eq("TMS-123[example=1,login=ok]")
    end

    it "falls back to code_ref when no explicit id exists" do
      identifier = described_class.build_test_case_id(
        explicit_id: nil,
        code_ref: "features/a.feature:12",
        parameters: { example: 1 }
      )

      expect(identifier).to eq("features/a.feature:12[example=1]")
    end
  end

  describe ".build_item_start" do
    it "produces the required ReportPortal field names" do
      body = described_class.build_item_start(
        name: "Scenario: Login ok",
        start_time: Time.utc(2026, 3, 23),
        type: "step",
        launch_uuid: "launch-1",
        description: nil,
        attributes: nil,
        code_ref: "features/login.feature:12",
        parameters: { example: 1 },
        has_stats: true,
        retry: true,
        uuid: "item-uuid",
        test_case_id: "TMS-123[example=1]",
        unique_id: "abc123"
      )

      expect(body).to include(
        "name" => "Scenario: Login ok",
        "type" => "step",
        "launchUuid" => "launch-1",
        "hasStats" => true,
        "retry" => true,
        "codeRef" => "features/login.feature:12",
        "testCaseId" => "TMS-123[example=1]",
        "uniqueId" => "abc123"
      )
      expect(body["parameters"]).to eq("example" => "1")
      expect(body["startTime"]).to match(/\A\d+\z/)
    end
  end
end
