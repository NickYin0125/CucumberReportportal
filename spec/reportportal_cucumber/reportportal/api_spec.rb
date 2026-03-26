# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::ReportPortal::API do
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp.example.com",
      project: "demo",
      api_key: "token"
    )
  end

  let(:client) { instance_double(ReportportalCucumber::Http::Client) }
  let(:api) { described_class.new(config: config, client: client) }

  it "falls back to parentUuid body mode when the parent endpoint rejects suite children" do
    child_error = ReportportalCucumber::Http::Client::Error.new(
      "HTTP 400",
      response: ReportportalCucumber::Http::Client::Response.new(
        status: 400,
        headers: {},
        body: {
          "errorCode" => 40_016,
          "message" => "Unable to add a not nested step item, because parent item with ID = '427' is a nested step"
        }
      )
    )

    allow(client).to receive(:post_json).with(
      path: "/api/v1/demo/item/feature-uuid",
      body: hash_excluding("parentUuid")
    ).and_raise(child_error)

    allow(client).to receive(:post_json).with(
      path: "/api/v1/demo/item",
      body: hash_including("parentUuid" => "feature-uuid")
    ).and_return(ReportportalCucumber::Http::Client::Response.new(status: 200, headers: {}, body: { "id" => "item-uuid" }))

    result = api.start_item(
      name: "Scenario: Fallback",
      start_time: Time.utc(2026, 3, 26),
      type: "test",
      launch_uuid: "launch-uuid",
      parent_uuid: "feature-uuid",
      has_stats: true,
      retry: false,
      uuid: "item-uuid"
    )

    expect(result).to eq("item-uuid")
  end
end
