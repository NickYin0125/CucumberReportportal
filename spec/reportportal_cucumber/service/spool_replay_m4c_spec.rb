# frozen_string_literal: true

require "spec_helper"
require "reportportal_cucumber/service/spool_replay"

RSpec.describe ReportportalCucumber::Service::SpoolReplay do
  LAUNCH = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  ITEM = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"

  class ReplayStoreDouble
    attr_reader :transaction, :writes

    def initialize(transaction)
      @transaction = transaction
      @writes = []
    end

    def load_transaction(id:)
      raise "wrong transaction" unless id == "txn-safe-1"

      transaction
    end

    def with_transaction(id:, deadline:)
      load_transaction(id: id)
      yield transaction
    end

    def update_checkpoint(id:, states:, deadline:)
      raise "wrong transaction" unless id == "txn-safe-1"

      writes << states.map(&:dup)
      transaction[:checkpoint] = { "states" => states.map(&:dup) }
    end
  end

  let(:config) do
    ReportportalCucumber::Config.new(endpoint: "https://rp.example.test", project: "demo", api_key: "token",
                                    retry_attempts: 1, batch_size_logs: 20, batch_max_bytes: 8 * 1024 * 1024)
  end
  let(:entry) do
    { "launchUuid" => LAUNCH, "itemUuid" => ITEM, "time" => "1791650000000",
      "message" => "kept message", "level" => "INFO" }
  end
  let(:transaction) do
    { manifest: { "target" => { "endpoint" => "https://rp.example.test", "project" => "demo" } },
      checkpoint: { "states" => [{ "state" => "pending" }] }, entries: [entry], files: [],
      directory: Dir.tmpdir }
  end
  let(:store) { ReplayStoreDouble.new(transaction) }
  let(:api) { instance_double(ReportportalCucumber::ReportPortal::API) }
  let(:replay) { described_class.new(store: store, config: config, api: api) }

  it "dry-runs a selected transaction without credentials or any HTTP/API call" do
    inspection = described_class.new(store: store, config: ReportportalCucumber::Config.new)
    expect(ReportportalCucumber::ReportPortal::API).not_to receive(:new)
    result = inspection.run(transaction_id: "txn-safe-1", timeout: 1)

    expect(result).to include(transaction: "txn-safe-1", dry_run: true, pending: 1, retained: true)
    expect(api).not_to receive(:launch_by_uuid)
    expect(store.writes).to be_empty
  end

  it "refuses a zero execution budget before loading the transaction" do
    expect(store).not_to receive(:load_transaction)

    expect do
      replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 0)
    end.to raise_error(ReportportalCucumber::ReportingError, /deadline expired during transaction validation/)
  end

  it "bounds the initial transaction load by the overall deadline" do
    allow(store).to receive(:load_transaction) do
      sleep 0.05
      transaction
    end

    expect do
      replay.run(transaction_id: "txn-safe-1", timeout: 0.005)
    end.to raise_error(ReportportalCucumber::ReportingError, /deadline expired during transaction validation/)
  end

  it "durably marks each entry in flight before one POST, then checkpoints its acknowledgement" do
    expect(api).to receive(:launch_by_uuid).with(uuid: LAUNCH, deadline: instance_of(ReportportalCucumber::Service::ReportingDeadline))
      .and_return({ "uuid" => LAUNCH, "status" => "IN_PROGRESS" })
    expect(api).to receive(:item_by_uuid).with(uuid: ITEM, deadline: instance_of(ReportportalCucumber::Service::ReportingDeadline))
      .and_return({ "uuid" => ITEM, "status" => "IN_PROGRESS" })
    expect(api).to receive(:log_batch_result).once do |entries:, files:, deadline:|
      expect(entries).to eq([entry])
      expect(files).to be_empty
      expect(store.writes.last.first["state"]).to eq("in_flight")
      expect(deadline).to be_a(ReportportalCucumber::Service::ReportingDeadline)
      double(body: { "id" => "confirmed-log-id" })
    end

    result = replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)

    expect(result).to include(dry_run: false, confirmed: 1, retained: false)
    expect(store.writes.map { |write| write.first["state"] }).to eq(%w[in_flight confirmed])
    expect(store.writes.last.first["id"]).to eq("confirmed-log-id")
  end

  it "requires duplicate consent for a persisted in-flight entry and never resends confirmed siblings" do
    transaction[:entries] = [entry, entry.merge("message" => "second")]
    transaction[:checkpoint] = { "states" => [{ "state" => "confirmed", "id" => "first-id" },
                                                   { "state" => "in_flight" }] }
    allow(api).to receive(:launch_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    allow(api).to receive(:item_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    expect(api).not_to receive(:log_batch_result)

    result = replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)

    expect(result).to include(confirmed: 1, ambiguous: 1, retained: true)
  end

  it "permits uncertain resend only with explicit consent and checkpoints transport failures as ambiguous" do
    transaction[:checkpoint] = { "states" => [{ "state" => "ambiguous" }] }
    allow(api).to receive(:launch_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    allow(api).to receive(:item_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    expect(api).to receive(:log_batch_result).once.and_raise(IOError, "synthetic transport failure")

    result = replay.run(transaction_id: "txn-safe-1", execute: true, allow_duplicates: true, timeout: 1)

    expect(result).to include(ambiguous: 1, retained: true)
    expect(store.writes.map { |write| write.first["state"] }).to eq(%w[in_flight ambiguous])
  end

  it "retries definite failed entries without duplicate consent and preserves failure state" do
    transaction[:checkpoint] = { "states" => [{ "state" => "failed" }] }
    allow(api).to receive(:launch_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    allow(api).to receive(:item_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    expect(api).to receive(:log_batch_result).once.and_return(double(body: { "responses" => [{ "message" => "rejected" }] }))

    result = replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)

    expect(result).to include(failed: 1, ambiguous: 0, retained: true)
    expect(store.writes.map { |write| write.first["state"] }).to eq(%w[in_flight failed])
  end

  it "classifies explicit authorization/server rejection as failed and permits later retry" do
    allow(api).to receive(:launch_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    allow(api).to receive(:item_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    response = ReportportalCucumber::Transport::HTTPClient::Response.new(status: 400, headers: {}, body: {})
    error = ReportportalCucumber::Transport::HTTPClient::Error.new("HTTP 400", response: response)
    expect(api).to receive(:log_batch_result).once.and_raise(error)

    result = replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)

    expect(result).to include(failed: 1, ambiguous: 0, retained: true)
    expect(store.writes.map { |write| write.first["state"] }).to eq(%w[in_flight failed])
  end

  it "stops after an acknowledgement whose confirmation checkpoint cannot be persisted" do
    transaction[:entries] = [entry, entry.merge("message" => "sibling")]
    transaction[:checkpoint] = { "states" => [{ "state" => "pending" }, { "state" => "pending" }] }
    allow(api).to receive(:launch_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    allow(api).to receive(:item_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    requests = 0
    allow(api).to receive(:log_batch_result) do
      requests += 1
      double(body: { "id" => "accepted-but-not-durable" })
    end
    allow(store).to receive(:update_checkpoint).and_wrap_original do |original, **arguments|
      raise IOError, "checkpoint unavailable" if arguments[:states].first["state"] == "confirmed"

      original.call(**arguments)
    end

    result = replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)

    expect(requests).to eq(1)
    expect(result).to include(confirmed: 0, ambiguous: 1, pending: 1, retained: true)
    expect(store.writes.map { |write| write.first["state"] }).to eq(["in_flight"])
  end

  it "preserves launch-level logs without requiring an item UUID" do
    entry.delete("itemUuid")
    allow(api).to receive(:launch_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    expect(api).not_to receive(:item_by_uuid)
    expect(api).to receive(:log_batch_result) do |entries:, files:, deadline:|
      expect(entries).to eq([entry.slice("launchUuid", "time", "message", "level")])
      expect(files).to eq([])
      expect(deadline).to be_a(ReportportalCucumber::Service::ReportingDeadline)
      double(body: { "id" => "launch-log-id" })
    end

    result = replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)

    expect(result).to include(confirmed: 1)
  end

  it "strips spool-only metadata before constructing the wire request" do
    entry["deliveryOutcome"] = "ambiguous"
    entry["spoolError"] = "private diagnostic"
    allow(api).to receive(:launch_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    allow(api).to receive(:item_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    expect(api).to receive(:log_batch_result) do |entries:, files:, deadline:|
      expect(entries.first.keys).to match_array(%w[launchUuid itemUuid time message level])
      double(body: { "id" => "clean-wire-id" })
    end

    replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)
  end

  it "matches path-backed attachments by exact logical name and entry index and never forwards internal fields" do
    Dir.mktmpdir("m4c-attachment-") do |directory|
      selected = File.join(directory, "selected.png")
      other = File.join(directory, "other.png")
      File.binwrite(selected, "selected-bytes")
      File.binwrite(other, "other-bytes")
      transaction[:directory] = directory
      transaction[:entries] = [entry.merge("file" => { "name" => "logical.png" }, "rawSpool" => true)]
      transaction[:files] = [
        { "name" => "different-logical-name.png", "mime" => "image/png", "path" => other, "entry_index" => 0 },
        { "name" => "logical.png", "mime" => "image/png", "path" => other, "entry_index" => 1 },
        { "name" => "logical.png", "mime" => "image/png", "path" => selected, "entry_index" => 0 }
      ]
      allow(api).to receive(:launch_by_uuid).and_return({ "status" => "IN_PROGRESS" })
      allow(api).to receive(:item_by_uuid).and_return({ "status" => "IN_PROGRESS" })
      expect(api).to receive(:log_batch_result) do |entries:, files:, deadline:|
        expect(entries.first.keys).to match_array(%w[launchUuid itemUuid time message level file])
        expect(files).to eq([{ name: "logical.png", mime: "image/png", path: selected }])
        double(body: { "id" => "attachment-log-id" })
      end

      replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)
    end
  end

  it "does not POST when the durable in-flight checkpoint fails" do
    allow(api).to receive(:launch_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    allow(api).to receive(:item_by_uuid).and_return({ "status" => "IN_PROGRESS" })
    allow(store).to receive(:update_checkpoint).and_raise(IOError, "disk unavailable")
    expect(api).not_to receive(:log_batch_result)

    expect do
      replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)
    end.to raise_error(IOError)
  end

  it "refuses endpoint or project mismatch before target lookup" do
    transaction[:manifest]["target"]["project"] = "other-project"
    expect(api).not_to receive(:launch_by_uuid)

    expect do
      replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)
    end.to raise_error(ReportportalCucumber::ReportingError, /endpoint\/project/)
  end

  it "refuses a closed original launch without creating or posting to another target" do
    allow(api).to receive(:launch_by_uuid).and_return({ "status" => "STOPPED" })
    expect(api).not_to receive(:item_by_uuid)
    expect(api).not_to receive(:log_batch_result)

    expect do
      replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)
    end.to raise_error(ReportportalCucumber::ReportingError, /not open/)
  end

  it "refuses async v2 execution rather than treating acceptance as persistence" do
    async_config = ReportportalCucumber::Config.new(endpoint: config.endpoint, project: config.project,
                                                    api_key: config.api_key, reporting_async: true)
    async_replay = described_class.new(store: store, config: async_config, api: api)
    expect(api).not_to receive(:launch_by_uuid)

    expect do
      async_replay.run(transaction_id: "txn-safe-1", execute: true, timeout: 1)
    end.to raise_error(ReportportalCucumber::ReportingError, /Async v2/)
  end
end
