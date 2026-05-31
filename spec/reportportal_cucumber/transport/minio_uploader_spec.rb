# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Transport::MinioUploader do
  let(:config) do
    ReportportalCucumber::Config.new(
      minio_endpoint: "http://localhost:9000",
      minio_public_base_url: "http://localhost:9000",
      minio_bucket: "automation-videos",
      minio_access_key_id: "minioadmin",
      minio_secret_access_key: "minioadmin",
      minio_region: "us-east-1"
    )
  end

  it "streams path-backed mp4 files to MinIO and returns a public URL" do
    Dir.mktmpdir do |dir|
      video_path = File.join(dir, "failure clip.mp4")
      File.binwrite(video_path, "mp4-bytes")
      captured = nil
      client = instance_double(Aws::S3::Client)
      allow(client).to receive(:put_object) do |params|
        captured = params
        expect(params.fetch(:body).read).to eq("mp4-bytes")
      end

      url = described_class.new(config: config, client: client).upload_video(
        path: video_path,
        name: "failure clip.mp4",
        content_type: "application/mp4"
      )

      expect(captured).to include(
        bucket: "automation-videos",
        content_type: "video/mp4"
      )
      expect(captured.fetch(:key)).to match(%r{\Avideos/\d{4}/\d{2}/\d{2}/.+-failure_clip\.mp4\z})
      expect(url).to start_with("http://localhost:9000/automation-videos/videos/")
      expect(url).to end_with("-failure_clip.mp4")
    end
  end
end
