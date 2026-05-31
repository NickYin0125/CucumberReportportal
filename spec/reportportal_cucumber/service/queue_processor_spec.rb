# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Service::QueueProcessor do
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp.example.com",
      project: "demo",
      api_key: "token",
      batch_size_logs: 2,
      flush_interval: 0.1,
      retry_attempts: 1,
      video_upload_mode: "minio_markdown"
    )
  end

  let(:api) { instance_double(ReportportalCucumber::ReportPortal::API) }

  class FakeVideoUploader
    attr_reader :calls

    def initialize
      @calls = []
    end

    def upload_video(path:, bytes:, name:, content_type:)
      @calls << { path: path, bytes: bytes, name: name, content_type: content_type }
      "http://localhost:9000/automation-videos/videos/#{name}"
    end
  end

  it "routes mp4 attachments through MinIO and sends a plain error log to ReportPortal" do
    Dir.mktmpdir do |dir|
      video_path = File.join(dir, "failure.mp4")
      File.binwrite(video_path, "mp4-bytes")
      uploader = FakeVideoUploader.new
      captured = []
      allow(api).to receive(:log_batch) { |entries:, files:| captured << [entries, files] }

      processor = described_class.new(api: api, config: config, video_uploader: uploader)
      processor.emit_log(
        item_uuid: "step-1",
        launch_uuid: "launch-1",
        message: "Failure MP4 playback evidence",
        level: :info,
        timestamp: Time.utc(2026, 5, 31, 8, 0, 0),
        attachment: { name: "failure.mp4", mime: "video/mp4", path: video_path }
      )
      expect(processor.shutdown(timeout: 2)).to be(true)

      entries, files = captured.first
      expect(uploader.calls.first).to include(path: video_path, name: "failure.mp4", content_type: "video/mp4")
      expect(files).to eq([])
      expect(entries.first).to include("level" => "error", "itemUuid" => "step-1")
      expect(entries.first).not_to have_key("file")
      expect(entries.first.fetch("message")).to include("Failure MP4 playback evidence")
      expect(entries.first.fetch("message")).to include("<video width=\"640\" controls preload=\"metadata\">")
      expect(entries.first.fetch("message")).to include("http://localhost:9000/automation-videos/videos/failure.mp4")
    end
  end

  it "keeps non-video attachments on the ReportPortal multipart path in mixed batches" do
    Dir.mktmpdir do |dir|
      video_path = File.join(dir, "failure.mp4")
      File.binwrite(video_path, "mp4-bytes")
      uploader = FakeVideoUploader.new
      captured = []
      allow(api).to receive(:log_batch) { |entries:, files:| captured << [entries, files] }

      processor = described_class.new(api: api, config: config, video_uploader: uploader)
      processor.emit_log(
        item_uuid: "step-1",
        launch_uuid: "launch-1",
        message: "screenshot",
        level: :info,
        timestamp: Time.utc(2026, 5, 31, 8, 0, 0),
        attachment: { name: "screen.png", mime: "image/png", bytes: "png-bytes" }
      )
      processor.emit_log(
        item_uuid: "step-1",
        launch_uuid: "launch-1",
        message: "recording",
        level: :info,
        timestamp: Time.utc(2026, 5, 31, 8, 0, 1),
        attachment: { name: "failure.mp4", mime: "video/mp4", path: video_path }
      )
      expect(processor.shutdown(timeout: 2)).to be(true)

      entries, files = captured.first
      expect(entries.map { |entry| entry["message"] }.first).to eq("screenshot")
      expect(entries.last.fetch("message")).to include("UI Failure Playback:")
      expect(files).to contain_exactly(include(name: "screen.png", mime: "image/png", bytes: "png-bytes"))
      expect(uploader.calls.length).to eq(1)
    end
  end
end
