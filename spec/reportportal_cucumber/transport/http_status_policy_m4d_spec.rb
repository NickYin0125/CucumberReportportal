# frozen_string_literal: true

require "spec_helper"
require "reportportal_cucumber/service/spool_replay"

RSpec.describe ReportportalCucumber::Transport::HTTPClient do
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp-status-policy.example.test", project: "status-policy", api_key: "synthetic-token",
      retry_attempts: 5, retry_base_interval: 0.01, retry_max_interval: 0.02
    )
  end
  let(:client) { described_class.new(config: config) }
  let(:log_url) { "#{config.endpoint}/api/v1/status-policy/log" }

  before do
    allow(client).to receive(:sleep)
    allow(client).to receive(:rand).and_return(0.0)
  end

  [400, 401, 403, 404, 422].each do |status|
    it "raises HTTP #{status} after one request without backoff" do
      request = stub_request(:post, log_url)
        .to_return(status: status, body: { "message" => "synthetic refusal" }.to_json)

      expect do
        client.post_json(path: "/api/v1/status-policy/log", body: { "message" => "synthetic" })
      end.to raise_error(described_class::Error) { |error| expect(error.response.status).to eq(status) }

      expect(request).to have_been_made.once
      expect(client).not_to have_received(:sleep)
    end
  end

  [408, 429, 502, 504].each do |status|
    it "retries HTTP #{status} with capped exponential backoff and marks eventual success" do
      refusal = { status: status, body: { "message" => "synthetic retry" }.to_json }
      request = stub_request(:post, log_url).to_return(
        refusal, refusal, refusal, { status: 200, body: { "id" => "synthetic-ack" }.to_json }
      )

      response = client.post_json(path: "/api/v1/status-policy/log", body: { "message" => "synthetic" })

      expect(response.status).to eq(200)
      expect(response.body).to eq("id" => "synthetic-ack")
      expect(response.may_duplicate).to be(true)
      expect(request).to have_been_made.times(4)
      expect(client).to have_received(:sleep).with(0.01).once
      expect(client).to have_received(:sleep).with(0.02).twice
      expect(client).to have_received(:sleep).exactly(3).times
    end
  end

  it "stops a retriable HTTP failure at the configured attempt limit" do
    request = stub_request(:post, log_url).to_return(status: 502, body: "{}")

    expect do
      client.post_json(path: "/api/v1/status-policy/log", body: { "message" => "synthetic" })
    end.to raise_error(described_class::Error) { |error| expect(error.response.status).to eq(502) }

    expect(request).to have_been_made.times(5)
    expect(client).to have_received(:sleep).with(0.01).once
    expect(client).to have_received(:sleep).with(0.02).exactly(3).times
    expect(client).to have_received(:sleep).exactly(4).times
  end

  it "preserves retry and duplicate-risk marking after a lost network response" do
    request = stub_request(:post, log_url).to_raise(EOFError.new("synthetic lost response"))
      .then.to_return(status: 200, body: { "id" => "synthetic-ack" }.to_json)

    response = client.post_json(path: "/api/v1/status-policy/log", body: { "message" => "synthetic" })

    expect(response.may_duplicate).to be(true)
    expect(request).to have_been_made.twice
    expect(client).to have_received(:sleep).with(0.01).once
    expect(client).to have_received(:sleep).once
  end

  context "when replay checks original targets through a five-attempt client" do
    let(:spool_dir) { Dir.mktmpdir("m4d-status-replay-") }
    let(:config) do
      ReportportalCucumber::Config.new(
        endpoint: "https://rp-status-policy.example.test", project: "status-policy", api_key: "synthetic-token",
        retry_attempts: 5, retry_base_interval: 0.01, retry_max_interval: 0.02, spool_dir: spool_dir
      )
    end
    let(:launch_uuid) { "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" }
    let(:item_uuid) { "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb" }
    let(:launch_url) { "#{config.endpoint}/api/v1/status-policy/launch/uuid/#{launch_uuid}" }
    let(:item_url) { "#{config.endpoint}/api/v1/status-policy/item/uuid/#{item_uuid}" }
    let(:store) { ReportportalCucumber::Service::SpoolStore.new(config: config) }
    let(:transaction_id) do
      store.persist(
        entries: [{ "launchUuid" => launch_uuid, "itemUuid" => item_uuid,
                    "time" => "1791650000000", "message" => "synthetic", "level" => "INFO" }],
        files: [], outcome: "failed"
      )
    end
    let(:replay) do
      api = ReportportalCucumber::ReportPortal::API.new(config: config, client: client)
      ReportportalCucumber::Service::SpoolReplay.new(store: store, config: config, api: api)
    end

    after do
      FileUtils.remove_entry(spool_dir)
    end

    %w[launch item].each do |resource|
      it "refuses an original #{resource} HTTP 404 without retrying or changing its checkpoint" do
        if resource == "item"
          stub_request(:get, launch_url)
            .to_return(status: 200, body: { "status" => "IN_PROGRESS" }.to_json)
        end
        request = stub_request(:get, resource == "launch" ? launch_url : item_url)
          .to_return(status: 404, body: { "message" => "synthetic missing target" }.to_json)

        expect do
          replay.run(transaction_id: transaction_id, execute: true, timeout: 1)
        end.to raise_error(ReportportalCucumber::ReportingError, "HTTP 404")

        expect(request).to have_been_made.once
        expect(client).not_to have_received(:sleep)
        expect(a_request(:post, log_url)).not_to have_been_made
        expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states"))
          .to eq([{ "state" => "pending" }])
      end
    end

    it "refuses a closed original item without retrying, posting, or changing its checkpoint" do
      stub_request(:get, launch_url)
        .to_return(status: 200, body: { "status" => "IN_PROGRESS" }.to_json)
      request = stub_request(:get, item_url)
        .to_return(status: 200, body: { "status" => "PASSED" }.to_json)

      expect do
        replay.run(transaction_id: transaction_id, execute: true, timeout: 1)
      end.to raise_error(ReportportalCucumber::ReportingError, "Original target is not open")

      expect(request).to have_been_made.once
      expect(client).not_to have_received(:sleep)
      expect(a_request(:post, log_url)).not_to have_been_made
      expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states"))
        .to eq([{ "state" => "pending" }])
    end
  end
end
