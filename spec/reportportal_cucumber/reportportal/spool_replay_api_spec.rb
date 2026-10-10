# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ReportPortal v1 UUID lookups for spool replay" do
  let(:config) do
    ReportportalCucumber::Config.new(endpoint: "https://rp-replay.example.test", project: "demo", api_key: "test-token",
                                    retry_attempts: 1)
  end
  let(:client) { ReportportalCucumber::Transport::HTTPClient.new(config: config) }
  let(:api) { ReportportalCucumber::ReportPortal::API.new(config: config, client: client) }
  let(:launch_uuid) { "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" }
  let(:item_uuid) { "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb" }

  it "looks up launch and item UUIDs only through the official v1 endpoints" do
    launch = stub_request(:get, "https://rp-replay.example.test/api/v1/demo/launch/uuid/#{launch_uuid}")
             .with(headers: { "Authorization" => "Bearer test-token" })
             .to_return(status: 200, body: { "uuid" => launch_uuid, "status" => "IN_PROGRESS" }.to_json)
    item = stub_request(:get, "https://rp-replay.example.test/api/v1/demo/item/uuid/#{item_uuid}")
           .with(headers: { "Authorization" => "Bearer test-token" })
           .to_return(status: 200, body: { "uuid" => item_uuid, "status" => "IN_PROGRESS" }.to_json)

    expect(api.launch_by_uuid(uuid: launch_uuid)).to include("uuid" => launch_uuid, "status" => "IN_PROGRESS")
    expect(api.item_by_uuid(uuid: item_uuid)).to include("uuid" => item_uuid, "status" => "IN_PROGRESS")
    expect(launch).to have_been_made.once
    expect(item).to have_been_made.once
  end

  it "rejects malformed UUIDs without making a request" do
    expect do
      api.item_by_uuid(uuid: "../../launch")
    end.to raise_error(ArgumentError, /UUID/)
  end
end
