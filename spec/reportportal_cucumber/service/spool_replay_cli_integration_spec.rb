# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "reportportal_cucumber/service/spool_replay"
require "reportportal_cucumber/service/spool_store"

RSpec.describe "reportportal-spool executable" do
  let(:executable) { File.expand_path("../../../exe/reportportal-spool", __dir__) }

  it "exposes explicit dry-run and execute modes from the packaged entry point" do
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-Ilib", executable, "--help", chdir: File.expand_path("../../..", __dir__))

    expect(status.exitstatus).to eq(0), stderr
    expect(stdout).to include("--dry-run", "--execute", "--allow-duplicates", "--timeout")
  end

  it "returns syntax exit 1 without echoing a rejected argument value" do
    root = File.expand_path("../../..", __dir__)
    stdout, stderr, status = Open3.capture3(
      { "RP_ENDPOINT" => nil, "RP_PROJECT" => nil, "RP_API_KEY" => nil },
      RbConfig.ruby, "-Ilib", executable, "--spool-dir", "/private/spool", "--transaction", "txn-selected",
      "--timeout", "SENSITIVE_ARGUMENT", chdir: root
    )

    expect(status.exitstatus).to eq(1)
    expect(stdout).to be_empty
    expect(stderr).to include("invalid command-line options")
    expect(stderr).not_to include("SENSITIVE_ARGUMENT", "/private/spool")
  end

  it "dry-runs an actual published transaction with endpoint, project, and credentials unset" do
    Dir.mktmpdir("m4c-cli-dry-run-") do |spool_dir|
      config = ReportportalCucumber::Config.new(
        endpoint: "https://rp-cli.example.test", project: "cli-demo", spool_dir: spool_dir,
        spool_max_bytes: 2 * 1024 * 1024
      )
      entry = {
        "launchUuid" => "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        "itemUuid" => "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        "time" => "1791650000000", "message" => "synthetic only", "level" => "INFO"
      }
      id = ReportportalCucumber::Service::SpoolStore.new(config: config).persist(
        entries: [entry], files: [], outcome: "failed"
      )
      root = File.expand_path("../../..", __dir__)
      env = { "RP_ENDPOINT" => nil, "RP_PROJECT" => nil, "RP_API_KEY" => nil,
              "RP_CONFIG" => nil, "RP_SPOOL_DIR" => nil }

      stdout, stderr, status = Open3.capture3(
        env, RbConfig.ruby, "-Ilib", executable, "--spool-dir", spool_dir,
        "--transaction", id, "--dry-run", chdir: root
      )

      expect(status.exitstatus).to eq(0), stderr
      expect(JSON.parse(stdout)).to include("dry_run" => true, "pending" => 1, "retained" => true)
    end
  end

  it "resumes a fully confirmed real Store transaction without looking up closed targets" do
    Dir.mktmpdir("m4c-confirmed-resume-") do |spool_dir|
      endpoint = "https://rp-closed-resume.example.test"
      config = ReportportalCucumber::Config.new(
        endpoint: endpoint, project: "cli-demo", api_key: "test-token",
        spool_dir: spool_dir, retry_attempts: 1
      )
      launch_uuid = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
      item_uuid = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
      entries = 2.times.map do |index|
        { "launchUuid" => launch_uuid, "itemUuid" => item_uuid,
          "time" => "179165000000#{index}", "message" => "synthetic #{index}", "level" => "INFO" }
      end
      store = ReportportalCucumber::Service::SpoolStore.new(config: config)
      transaction_id = store.persist(entries: entries, files: [], outcome: "failed")
      replay = ReportportalCucumber::Service::SpoolReplay.new(store: store, config: config)

      stub_request(:get, "#{endpoint}/api/v1/cli-demo/launch/uuid/#{launch_uuid}")
        .to_return(status: 200, body: { "uuid" => launch_uuid, "status" => "IN_PROGRESS" }.to_json)
      stub_request(:get, "#{endpoint}/api/v1/cli-demo/item/uuid/#{item_uuid}")
        .to_return(status: 200, body: { "uuid" => item_uuid, "status" => "IN_PROGRESS" }.to_json)
      stub_request(:post, "#{endpoint}/api/v1/cli-demo/log").to_return(
        { status: 200, body: { "id" => "ack-one" }.to_json },
        { status: 200, body: { "id" => "ack-two" }.to_json }
      )

      completed = replay.run(transaction_id: transaction_id, execute: true, timeout: 5)

      expect(completed).to include(confirmed: 2, retained: false)
      expect(a_request(:post, "#{endpoint}/api/v1/cli-demo/log")).to have_been_made.twice
      WebMock.reset!
      closed_launch = stub_request(:get, "#{endpoint}/api/v1/cli-demo/launch/uuid/#{launch_uuid}")
        .to_return(status: 200, body: { "uuid" => launch_uuid, "status" => "STOPPED" }.to_json)
      closed_item = stub_request(:get, "#{endpoint}/api/v1/cli-demo/item/uuid/#{item_uuid}")
        .to_return(status: 200, body: { "uuid" => item_uuid, "status" => "STOPPED" }.to_json)

      resumed = replay.run(transaction_id: transaction_id, execute: true, timeout: 5)

      expect(resumed).to include(confirmed: 2, retained: false)
      expect(closed_launch).not_to have_been_made
      expect(closed_item).not_to have_been_made
      expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states").map { |state| state["state"] })
        .to eq(%w[confirmed confirmed])
    end
  end
end
