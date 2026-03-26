# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Service::PayloadBuilder do
  describe ".build_launch_start" do
    it "keeps description and attributes explicit even when unset" do
      body = described_class.build_launch_start(
        name: "Launch",
        start_time: Time.utc(2026, 3, 26, 12, 0, 0),
        description: nil,
        attributes: nil,
        mode: "DEFAULT",
        rerun: false,
        rerun_of: nil,
        uuid: "launch-uuid"
      )

      expect(body).to include(
        "name" => "Launch",
        "description" => "",
        "attributes" => [],
        "mode" => "DEFAULT",
        "rerun" => false,
        "uuid" => "launch-uuid"
      )
    end
  end

  describe ".build_log_batch" do
    it "keeps multipart file names aligned with json_request_part and de-duplicates duplicates" do
      payload = described_class.build_log_batch(
        [
          {
            item_uuid: "item-1",
            launch_uuid: "launch-1",
            message: "png",
            level: :info,
            timestamp: Time.utc(2026, 3, 26, 12, 0, 0),
            attachment: {
              name: "evidence.txt",
              mime: "text/plain",
              bytes: "one"
            }
          },
          {
            item_uuid: "item-1",
            launch_uuid: "launch-1",
            message: "duplicate",
            level: :info,
            timestamp: Time.utc(2026, 3, 26, 12, 0, 1),
            attachment: {
              name: "evidence.txt",
              mime: "text/plain",
              bytes: "two"
            }
          }
        ]
      )

      expect(payload.fetch(:entries).map { |entry| entry.dig("file", "name") }).to eq(["evidence.txt", "evidence-1.txt"])
      expect(payload.fetch(:files).map { |file| file.fetch(:name) }).to eq(["evidence.txt", "evidence-1.txt"])
    end

    it "pretty prints JSON attachments and appends a markdown preview to the log message" do
      payload = described_class.build_log_batch(
        [
          {
            item_uuid: "item-1",
            launch_uuid: "launch-1",
            message: "Structured config snapshot",
            level: :debug,
            timestamp: Time.utc(2026, 3, 26, 12, 0, 0),
            attachment: {
              name: "config",
              mime: "application/json",
              bytes: '{"buyer":"JPM","amount":10}'
            }
          }
        ]
      )

      entry = payload.fetch(:entries).first
      file = payload.fetch(:files).first

      expect(file.fetch(:name)).to eq("config.json")
      expect(file.fetch(:bytes)).to include("\"buyer\": \"JPM\"")
      expect(entry.fetch("message")).to include("Structured config snapshot")
      expect(entry.fetch("message")).to include("```json")
    end

    it "truncates long text attachment previews after 100 lines" do
      payload = described_class.build_log_batch(
        [
          {
            item_uuid: "item-1",
            launch_uuid: "launch-1",
            message: "Transport trace",
            level: :info,
            timestamp: Time.utc(2026, 3, 26, 12, 0, 0),
            attachment: {
              name: "trace.log",
              mime: "text/plain",
              bytes: (1..120).map { |index| "line-#{index}" }.join("\n")
            }
          }
        ]
      )

      message = payload.fetch(:entries).first.fetch("message")

      expect(message).to include("line-100")
      expect(message).not_to include("line-101")
      expect(message).to include("[View Full Log](attachment://trace.log)")
    end
  end
end
