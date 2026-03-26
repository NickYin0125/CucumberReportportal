# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Http::Client do
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp.example.com",
      project: "demo",
      api_key: "token",
      retry_attempts: 2,
      retry_base_interval: 0.01,
      retry_max_interval: 0.01
    )
  end

  let(:client) { described_class.new(config: config) }

  it "retries 5xx responses and eventually succeeds" do
    stub_request(:post, "https://rp.example.com/api/v1/demo/launch")
      .to_return({ status: 500, body: '{"error":"boom"}' }, { status: 200, body: '{"id":"launch-1"}' })

    response = client.post_json(path: "/api/v1/demo/launch", body: { name: "demo" })

    expect(response.status).to eq(200)
    expect(response.body).to eq("id" => "launch-1")
    expect(a_request(:post, "https://rp.example.com/api/v1/demo/launch")).to have_been_made.twice
  end

  it "fails fast for 401 responses" do
    stub_request(:post, "https://rp.example.com/api/v1/demo/launch")
      .to_return(status: 401, body: '{"error":"unauthorized"}')

    expect do
      client.post_json(path: "/api/v1/demo/launch", body: { name: "demo" })
    end.to raise_error(ReportportalCucumber::Http::Client::Error)

    expect(a_request(:post, "https://rp.example.com/api/v1/demo/launch")).to have_been_made.once
  end

  it "builds multipart requests with matching json_request_part and file names" do
    captured_body = nil
    stub_request(:post, "https://rp.example.com/api/v1/demo/log").to_return do |request|
      captured_body = request.body
      { status: 200, body: '{"responses":[{"id":"log-1"}]}' }
    end

    client.post_multipart(
      path: "/api/v1/demo/log",
      parts: [
        {
          name: "json_request_part",
          content_type: "application/json",
          body: '[{"itemUuid":"item-1","launchUuid":"launch-1","time":"1","message":"trace","level":"debug","file":{"name":"trace.log"}}]'
        },
        {
          name: "file",
          filename: "trace.log",
          content_type: "text/plain",
          body: "trace-body"
        }
      ]
    )

    expect(captured_body).to include('name="json_request_part"')
    expect(captured_body).to include('"file":{"name":"trace.log"}')
    expect(captured_body).to include('name="file"; filename="trace.log"')
    expect(captured_body).to include("trace-body")
  end
end
