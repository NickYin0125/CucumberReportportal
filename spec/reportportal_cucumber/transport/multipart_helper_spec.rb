# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Transport::MultipartHelper do
  it "detects MIME types from file names and keeps multipart parts aligned" do
    body = described_class.encode(
      parts: [
        {
          name: "json_request_part",
          content_type: "application/json",
          body: '[{"message":"png","level":"info","file":{"name":"evidence.png"}},{"message":"trace","level":"debug","file":{"name":"trace.log"}}]'
        },
        {
          name: "file",
          filename: "evidence.png",
          body: "png-bytes"
        },
        {
          name: "file",
          filename: "trace.log",
          body: "trace-lines"
        }
      ],
      boundary: "rp-boundary"
    )

    expect(body).to include('filename="evidence.png"')
    expect(body).to include("Content-Type: image/png")
    expect(body).to include('filename="trace.log"')
  end

  it "raises when json_request_part file names do not match binary parts" do
    expect do
      described_class.encode(
        parts: [
          {
            name: "json_request_part",
            content_type: "application/json",
            body: '[{"message":"trace","level":"debug","file":{"name":"trace.log"}}]'
          },
          {
            name: "file",
            filename: "wrong-name.log",
            body: "trace"
          }
        ],
        boundary: "rp-boundary"
      )
    end.to raise_error(ArgumentError, /Multipart log payload mismatch/)
  end

  it "escapes quoted header parameters without changing alignment validation names" do
    body = described_class.encode(
      parts: [
        {
          name: "json_request_part",
          content_type: "application/json",
          body: '[{"message":"trace","level":"debug","file":{"name":"bad\\"name.log"}}]'
        },
        {
          name: "file",
          filename: "bad\"name.log",
          body: "trace"
        }
      ],
      boundary: "rp-boundary"
    )

    expect(body).to include('filename="bad\"name.log"')
  end

  it "sanitizes header-breaking filenames and rejects malformed declared content types" do
    body = described_class.encode(
      parts: [
        {
          name: "json_request_part",
          content_type: "application/json",
          body: '[{"message":"trace","level":"debug","file":{"name":"bad name.png"}}]'
        },
        {
          name: "file",
          filename: "bad\r\nname.png",
          content_type: "image/png\r\nX-Injected: yes",
          body: "png"
        }
      ],
      boundary: "rp-boundary"
    )

    expect(body).to include('filename="bad name.png"')
    expect(body).to include("Content-Type: image/png")
    expect(body).not_to include("X-Injected")
  end

  it "uses safe basenames for paths and curl-form separators" do
    expect(described_class.safe_filename("../../evil;trace.log")).to eq("evil_trace.log")
    expect(described_class.safe_filename("nested\\clip;01.mp4")).to eq("clip_01.mp4")
  end

  it "prefers playable video MIME types for mp4 attachments" do
    expect(described_class.content_type_for(filename: "clip.mp4", declared_type: nil)).to eq("video/mp4")
    expect(described_class.content_type_for(filename: "clip.mp4", declared_type: "application/mp4")).to eq("video/mp4")
  end

  it "builds path-backed multipart bodies through a stream source for video attachments" do
    Dir.mktmpdir do |dir|
      video_path = File.join(dir, "clip.mp4")
      File.binwrite(video_path, "mp4-bytes")

      source = described_class.body_source(
        parts: [
          {
            name: "json_request_part",
            content_type: "application/json",
            body: '[{"message":"video","level":"info","file":{"name":"clip.mp4"}}]'
          },
          {
            name: "file",
            filename: "clip.mp4",
            content_type: "application/mp4",
            path: video_path
          }
        ],
        boundary: "rp-boundary"
      )

      expect(source.body).to be_nil
      expect(source.stream).not_to be_nil
      body = source.stream.read

      expect(body).to include('filename="clip.mp4"')
      expect(body).to include("Content-Type: video/mp4")
      expect(body).to include("mp4-bytes")
    ensure
      source&.tempfile&.close!
    end
  end
end
