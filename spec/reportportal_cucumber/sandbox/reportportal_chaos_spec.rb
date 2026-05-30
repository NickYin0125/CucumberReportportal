# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ReportPortal backend chaos sandbox" do
  def chaos_config(overrides = {})
    ReportportalCucumber::Config.new(
      {
        endpoint: "https://rp-chaos.example.com",
        project: "demo",
        api_key: "token",
        batch_size_logs: 2,
        flush_interval: 0.1,
        retry_attempts: 3,
        retry_base_interval: 0.01,
        retry_max_interval: 0.01,
        exit_flush_timeout_ms: 2_000
      }.merge(overrides)
    )
  end

  describe ReportportalCucumber::Transport::HTTPClient do
    it "retries transient RP status codes and keeps fatal auth/config errors fail-fast" do
      retriable_codes = [408, 429, 502, 504]
      fatal_codes = [400, 401, 403]

      retriable_codes.each do |status|
        config = chaos_config
        client = described_class.new(config: config)
        allow(client).to receive(:sleep)

        launch_url = "https://rp-chaos.example.com/api/v1/demo/launch/#{status}"
        stub_request(:post, launch_url)
          .to_return({ status: status, body: { error: "temporary" }.to_json },
                     { status: 200, body: { id: "launch-#{status}" }.to_json })

        response = client.post_json(path: "/api/v1/demo/launch/#{status}", body: { name: "chaos" })

        expect(response.body).to eq("id" => "launch-#{status}")
        expect(a_request(:post, launch_url)).to have_been_made.twice
      ensure
        client&.close
      end

      fatal_codes.each do |status|
        config = chaos_config
        client = described_class.new(config: config)
        allow(client).to receive(:sleep)

        launch_url = "https://rp-chaos.example.com/api/v1/demo/launch/fatal/#{status}"
        stub_request(:post, launch_url)
          .to_return(status: status, body: { error: "fatal" }.to_json)

        expect do
          client.post_json(path: "/api/v1/demo/launch/fatal/#{status}", body: { name: "chaos" })
        end.to raise_error(ReportportalCucumber::Transport::HTTPClient::Error)

        expect(a_request(:post, launch_url)).to have_been_made.once
      ensure
        client&.close
      end
    end

    it "retries network connection failures before succeeding" do
      config = chaos_config(retry_attempts: 3)
      client = described_class.new(config: config)
      allow(client).to receive(:sleep)

      url = "https://rp-chaos.example.com/api/v1/demo/launch/network"
      stub_request(:post, url)
        .to_raise(Errno::ECONNRESET)
        .then
        .to_return(status: 200, body: { id: "launch-network" }.to_json)

      response = client.post_json(path: "/api/v1/demo/launch/network", body: { name: "chaos" })

      expect(response.body).to eq("id" => "launch-network")
      expect(a_request(:post, url)).to have_been_made.twice
    ensure
      client.close
    end
  end

  describe ReportportalCucumber::ReportPortal::API do
    it "does not fallback to parentUuid body mode for unrelated 400 start item errors" do
      config = chaos_config(retry_attempts: 1)
      api = described_class.new(config: config)

      child_url = "https://rp-chaos.example.com/api/v1/demo/item/parent-uuid"
      fallback_url = "https://rp-chaos.example.com/api/v1/demo/item"
      stub_request(:post, child_url)
        .to_return(
          status: 400,
          body: {
            errorCode: 40_001,
            message: "Start time must be greater than parent start time"
          }.to_json
        )
      stub_request(:post, fallback_url).to_return(status: 200, body: { id: "wrong-fallback" }.to_json)

      expect do
        api.start_item(
          name: "Scenario: timing inversion",
          start_time: Time.utc(2026, 5, 30),
          type: "test",
          launch_uuid: "launch-uuid",
          parent_uuid: "parent-uuid",
          has_stats: true,
          retry: false,
          uuid: "scenario-uuid"
        )
      end.to raise_error(ReportportalCucumber::Transport::HTTPClient::Error)

      expect(a_request(:post, child_url)).to have_been_made.once
      expect(a_request(:post, fallback_url)).not_to have_been_made
    end

    it "preserves multipart json_request_part to file ordering for mixed log attachments" do
      config = chaos_config(retry_attempts: 1)
      api = described_class.new(config: config)
      captured_body = nil

      stub_request(:post, "https://rp-chaos.example.com/api/v1/demo/log").to_return do |request|
        captured_body = request.body
        { status: 200, body: { responses: [{ id: "log-1" }, { id: "log-2" }] }.to_json }
      end

      api.log_batch(
        entries: [
          {
            "launchUuid" => "launch-uuid",
            "itemUuid" => "step-uuid",
            "time" => "1770000000000",
            "message" => "screenshot",
            "level" => "info",
            "file" => { "name" => "test.png" }
          },
          {
            "launchUuid" => "launch-uuid",
            "itemUuid" => "step-uuid",
            "time" => "1770000000001",
            "message" => "trace",
            "level" => "debug",
            "file" => { "name" => "trace.log" }
          }
        ],
        files: [
          { name: "test.png", mime: "image/png", bytes: "png-bytes" },
          { name: "trace.log", mime: "text/plain", bytes: "trace-lines" }
        ]
      )

      expect(captured_body).to include('"file":{"name":"test.png"}')
      expect(captured_body).to include('"file":{"name":"trace.log"}')
      expect(captured_body.index('filename="test.png"')).to be < captured_body.index('filename="trace.log"')
      expect(captured_body).to include("Content-Type: image/png")
      expect(captured_body).to include("Content-Type: text/plain")
    end
  end

  describe ReportportalCucumber::Runtime::LogBuffer do
    it "spools pending log batches when RP remains unavailable with 502 responses" do
      Dir.mktmpdir do |dir|
        config = chaos_config(
          retry_attempts: 2,
          batch_size_logs: 2,
          spool_dir: File.join(dir, "spool")
        )
        api = ReportportalCucumber::ReportPortal::API.new(config: config)
        errors = []
        buffer = described_class.new(api: api, config: config, on_error: ->(error) { errors << error })

        stub_request(:post, "https://rp-chaos.example.com/api/v1/demo/log")
          .to_return(status: 502, body: { error: "bad gateway" }.to_json)

        buffer.emit_log(
          item_uuid: "step-uuid",
          launch_uuid: "launch-uuid",
          message: "one",
          level: :info,
          timestamp: Time.utc(2026, 5, 30),
          attachment: { name: "trace.log", mime: "text/plain", bytes: "line 1\n" }
        )
        buffer.emit_log(
          item_uuid: "step-uuid",
          launch_uuid: "launch-uuid",
          message: "two",
          level: :debug,
          timestamp: Time.utc(2026, 5, 30),
          attachment: { name: "config.json", mime: "application/json", bytes: '{"enabled":true}' }
        )

        expect(buffer.shutdown(timeout: 2)).to be(true)

        ndjson_files = Dir[File.join(dir, "spool", "*.ndjson")]
        attachment_files = Dir[File.join(dir, "spool", "*.attachments", "*")]
        spooled_lines = ndjson_files.flat_map { |path| File.readlines(path, chomp: true) }

        expect(errors).not_to be_empty
        expect(ndjson_files.length).to eq(1)
        expect(spooled_lines.length).to eq(2)
        expect(attachment_files.map { |path| File.basename(path) }).to contain_exactly("trace.log", "config.json")
      end
    end

    it "does not retry fatal log authentication failures after HTTPClient fails fast" do
      config = chaos_config(retry_attempts: 3, batch_size_logs: 1)
      api = ReportportalCucumber::ReportPortal::API.new(config: config)
      buffer = described_class.new(api: api, config: config)

      log_url = "https://rp-chaos.example.com/api/v1/demo/log"
      stub_request(:post, log_url)
        .to_return(status: 401, body: { error: "expired token" }.to_json)

      buffer.emit_log(
        item_uuid: "step-uuid",
        launch_uuid: "launch-uuid",
        message: "auth should fail fast",
        level: :info,
        timestamp: Time.utc(2026, 5, 30)
      )
      buffer.shutdown(timeout: 2)

      expect(a_request(:post, log_url)).to have_been_made.once
    end
  end
end
