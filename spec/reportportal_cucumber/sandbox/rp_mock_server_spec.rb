# frozen_string_literal: true

require "spec_helper"
require "net/http"

RSpec.describe ReportportalCucumber::SpecSupport::RPMockServer do
  it "models nested launch, item, multipart log, finish, and query flows" do
    server = described_class.new.install!
    config = ReportportalCucumber::Config.new(
      endpoint: server.endpoint,
      project: "demo",
      api_key: "token",
      join: false,
      retry_attempts: 1
    )
    api = ReportportalCucumber::ReportPortal::API.new(config: config)

    launch_uuid = api.start_launch(
      name: "Sandbox",
      start_time: Time.utc(2026, 5, 30, 12, 0, 0),
      description: "nested mock",
      attributes: [{ "key" => "suite", "value" => "sandbox" }],
      mode: "DEFAULT",
      rerun: false,
      rerun_of: nil,
      uuid: "launch-uuid"
    )
    suite_uuid = api.start_item(
      name: "Feature",
      start_time: Time.utc(2026, 5, 30, 12, 0, 1),
      type: "suite",
      launch_uuid: launch_uuid,
      has_stats: false,
      retry: false,
      uuid: nil
    )
    scenario_uuid = api.start_item(
      name: "Scenario",
      start_time: Time.utc(2026, 5, 30, 12, 0, 2),
      type: "test",
      launch_uuid: launch_uuid,
      parent_uuid: suite_uuid,
      parameters: { "buyer" => "JPM" },
      has_stats: true,
      retry: false,
      uuid: nil
    )
    step_uuid = api.start_item(
      name: "Step",
      start_time: Time.utc(2026, 5, 30, 12, 0, 3),
      type: "step",
      launch_uuid: launch_uuid,
      parent_uuid: scenario_uuid,
      has_stats: false,
      retry: false,
      uuid: "step-uuid"
    )

    api.log_batch(
      entries: [
        {
          "launchUuid" => launch_uuid,
          "itemUuid" => step_uuid,
          "time" => "1770000000000",
          "message" => "png",
          "level" => "info",
          "file" => { "name" => "shot.png" }
        },
        {
          "launchUuid" => launch_uuid,
          "itemUuid" => step_uuid,
          "time" => "1770000000001",
          "message" => "video",
          "level" => "debug",
          "file" => { "name" => "clip.mp4" }
        }
      ],
      files: [
        { name: "shot.png", mime: "image/png", bytes: "png-bytes" },
        { name: "clip.mp4", mime: "video/mp4", bytes: "mp4-bytes" }
      ]
    )
    api.finish_item(item_uuid: step_uuid, launch_uuid: launch_uuid, end_time: Time.utc(2026, 5, 30, 12, 0, 4), status: "passed")
    api.finish_item(item_uuid: scenario_uuid, launch_uuid: launch_uuid, end_time: Time.utc(2026, 5, 30, 12, 0, 5), status: "passed")
    api.finish_launch(launch_uuid: launch_uuid, end_time: Time.utc(2026, 5, 30, 12, 0, 6), status: "passed")

    launch = server.launches.fetch("launch-uuid")
    feature_request = server.item_requests.find { |request| request.fetch("name") == "Feature" }
    scenario_request = server.item_requests.find { |request| request.fetch("name") == "Scenario" }
    multipart = server.multipart_requests.first

    expect(launch).to include("description" => "nested mock")
    expect(feature_request.fetch("responseUuid")).to eq(suite_uuid)
    expect(scenario_request.fetch("parentUuid")).to eq(feature_request.fetch("responseUuid"))
    expect(scenario_request.fetch("path")).to end_with("/api/v1/demo/item/#{suite_uuid}")
    expect(server.items.fetch(scenario_uuid)["parentUuid"]).to eq(suite_uuid)
    expect(server.items.fetch(scenario_uuid)["parameters"]).to eq([{ "key" => "buyer", "value" => "JPM" }])
    expect(multipart.fetch(:files).map { |file| file.fetch(:content_type) }).to eq(["image/png", "video/mp4"])
    expect(server.logs.length).to eq(2)
    expect(launch.dig("statistics", "executions", "total")).to eq(1)
    expect(launch["status"]).to eq("PASSED")

    response = Net::HTTP.get_response(URI("#{server.endpoint}/api/v1/project/demo/launch/#{launch_uuid}"))
    expect(response.code.to_i).to eq(200)
    expect(JSON.parse(response.body)).to include("uuid" => "launch-uuid", "status" => "PASSED")
  end
end
