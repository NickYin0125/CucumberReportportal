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
end
