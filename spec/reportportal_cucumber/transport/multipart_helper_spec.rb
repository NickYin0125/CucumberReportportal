# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Transport::MultipartHelper do
  it "rejects aligned duplicates and sanitization collisions across all multipart construction paths" do
    [
      ["evidence.txt", "evidence.txt"],
      ["../../evidence.txt", "evidence.txt"],
      ["bad\r\nname.txt", "bad name.txt"]
    ].each do |names|
      entries = names.each_with_index.map do |name, index|
        { "itemUuid" => "item-#{index}", "file" => { "name" => described_class.safe_filename(name) } }
      end
      parts = [{ name: "json_request_part", content_type: "application/json", body: JSON.generate(entries) }]
      names.each_with_index { |name, index| parts << { name: "file", filename: name, body: "distinct-bytes-#{index}" } }
      [:encode, :body_source, :encoded_length].each do |method|
        expect { described_class.public_send(method, parts: parts, boundary: "collision-boundary") }
          .to raise_error(ArgumentError, /Multipart log payload mismatch/)
      end
      expect { described_class.validate_alignment!(parts) }.to raise_error(ArgumentError, /Multipart log payload mismatch/)
    end
  end

  it "requires JSON to name the exact sanitized wire parts without silently rewriting its references" do
    parts = [
      { name: "json_request_part", content_type: "application/json", body: '[{"file":{"name":"../../evidence.txt"}}]' },
      { name: "file", filename: "../../evidence.txt", body: "evidence" }
    ]
    [:encode, :body_source, :encoded_length].each do |method|
      expect { described_class.public_send(method, parts: parts, boundary: "exact-boundary") }
        .to raise_error(ArgumentError, /Multipart log payload mismatch/)
    end
  end

  it "keeps unique sanitized filenames, exact framing lengths and distinct bytes valid" do
    parts = [
      { name: "json_request_part", content_type: "application/json", body: '[{"file":{"name":"evidence.txt"}},{"file":{"name":"evidence-1.txt"}}]' },
      { name: "file", filename: "../../evidence.txt", body: "bytes-one" },
      { name: "file", filename: "evidence-1.txt", body: "bytes-two" }
    ]
    body = described_class.encode(parts: parts, boundary: "valid-boundary")
    source = described_class.body_source(parts: parts, boundary: "valid-boundary")
    expect(source.body).to eq(body)
    expect(described_class.encoded_length(parts: parts, boundary: "valid-boundary")).to eq(body.bytesize)
    expect(body).to include('filename="evidence.txt"', 'filename="evidence-1.txt"', "bytes-one", "bytes-two")
  end

  it "rejects duplicate filenames supplied directly to API.log_batch before any HTTP request" do
    config = ReportportalCucumber::Config.new(endpoint: "https://multipart-collision.example.test", project: "capture", api_key: "synthetic")
    api = ReportportalCucumber::ReportPortal::API.new(config: config)
    entries = 2.times.map { |index| { "itemUuid" => "item-#{index}", "file" => { "name" => "evidence.txt" } } }
    files = 2.times.map { |index| { name: "evidence.txt", mime: "text/plain", bytes: "bytes-#{index}" } }
    expect { api.log_batch(entries: entries, files: files) }.to raise_error(ArgumentError, /Multipart log payload mismatch/)
    expect(a_request(:post, %r{multipart-collision\.example\.test/.*/log})).not_to have_been_made
  end

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
