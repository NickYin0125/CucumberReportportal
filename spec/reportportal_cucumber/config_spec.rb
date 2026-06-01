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

  describe ".load" do
    it "parses MinIO markdown video routing from environment variables" do
      config = described_class.load(
        env: {
          "RP_VIDEO_UPLOAD_MODE" => "minio_markdown",
          "RP_MINIO_ENDPOINT" => "http://minio.local:9000",
          "RP_MINIO_PUBLIC_BASE_URL" => "http://assets.local:9000",
          "RP_MINIO_BUCKET" => "automation-videos",
          "RP_MINIO_ACCESS_KEY_ID" => "access",
          "RP_MINIO_SECRET_ACCESS_KEY" => "secret",
          "RP_MINIO_REGION" => "us-west-2"
        }
      )

      expect(config).to be_minio_markdown_video
      expect(config.minio_endpoint).to eq("http://minio.local:9000")
      expect(config.minio_public_base_url).to eq("http://assets.local:9000")
      expect(config.minio_bucket).to eq("automation-videos")
      expect(config.minio_access_key_id).to eq("access")
      expect(config.minio_secret_access_key).to eq("secret")
      expect(config.minio_region).to eq("us-west-2")
    end

    it "parses console mirror mode from environment variables" do
      enabled = described_class.load(env: { "RP_CONSOLE_MIRROR" => "true" })
      disabled = described_class.load(env: { "RP_CONSOLE_MIRROR" => "false" })

      expect(enabled).to be_console_mirror
      expect(disabled).not_to be_console_mirror
    end
  end
end
