# frozen_string_literal: true

require "spec_helper"
require "reportportal_cucumber/service/spool_replay"

RSpec.describe "M4 Store binary encoding with Cucumber's UTF-8 internal encoding" do
  let(:directory) { Dir.mktmpdir("m4d-store-encoding-") }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://binary-store.example.test", project: "synthetic", api_key: "synthetic-key",
      spool_dir: File.join(directory, "spool"), batch_size_logs: 20, flush_interval: 60,
      retry_attempts: 1, exit_flush_timeout_ms: 2_000, video_upload_mode: "reportportal_multipart"
    )
  end
  let(:store) { ReportportalCucumber::Service::SpoolStore.new(config: config) }
  let(:timestamp) { Time.utc(2026, 10, 10) }
  let(:wire) do
    { "launchUuid" => "11111111-1111-4111-8111-111111111111",
      "itemUuid" => "22222222-2222-4222-8222-222222222222", "time" => "1791590400000",
      "message" => "original binary evidence", "level" => "info" }
  end

  around do |example|
    original_internal = Encoding.default_internal
    Encoding.default_internal = Encoding::UTF_8
    example.run
  ensure
    Encoding.default_internal = original_internal
  end

  after { FileUtils.remove_entry(directory) if File.exist?(directory) }

  def attachment_source(name, bytes, source)
    return { bytes: bytes } if source == :bytes

    path = File.join(directory, name)
    File.binwrite(path, bytes)
    { path: path }
  end

  def multipart(request)
    boundary = request.headers.fetch("Content-Type")[/boundary=(?:"([^"]+)"|([^;]+))/, 1] || Regexp.last_match(2)
    result = { entries: [], files: [] }
    request.body.b.split("--#{boundary}".b).each do |part|
      headers, body = part.delete_prefix("\r\n").split("\r\n\r\n", 2)
      next unless body

      body = body.delete_suffix("\r\n").b
      if (name = headers[/\bfilename="([^"]+)"/, 1])
        result[:files] << { name: name, bytes: body }
      elsif headers.include?('name="json_request_part"')
        result[:entries].concat(JSON.parse(body))
      end
    end
    result
  end

  fixtures = [
    ["all-bytes.bin", "application/octet-stream", (0..255).to_a.pack("C*").b],
    ["invalid-utf8.png", "image/png", "\x89PNG\r\n\x1A\n\xFF\xFE\x80\x00".dup.force_encoding(Encoding::UTF_8)],
    ["binary-video.mp4", "video/mp4", "\x00\x00\x00\x18ftypmp42\x00\xFF\xFE\x80".b]
  ]

  fixtures.each do |name, mime, bytes|
    %i[path bytes].each do |source|
      it "persists and validates exact #{name} #{source} bytes without transcoding" do
        expect(Encoding.default_internal).to eq(Encoding::UTF_8)
        record = wire.merge("file" => { "name" => name })
        part = { name: name, mime: mime }.merge(attachment_source(name, bytes, source))
        id = store.persist(entries: [record], files: [part], outcome: :failed)
        transaction = store.load_transaction(id: id)
        file = transaction.fetch(:files).first

        expect(transaction.fetch(:entries)).to eq([record])
        expect(file).to include(name: name, entry_index: 0, length: bytes.bytesize,
                               sha256: Digest::SHA256.hexdigest(bytes), unavailable: false)
        expect(File.binread(file.fetch(:path))).to eq(bytes.b)
        expect(transaction.fetch(:checkpoint).fetch("states")).to eq([{ "state" => "pending" }])
      end

      it "retains and actually replays public Queue #{name} #{source} bytes with original ownership" do
        expect(Encoding.default_internal).to eq(Encoding::UTF_8)
        captures = []
        log_url = "#{config.endpoint}/api/v1/#{config.project}/log"
        stub_request(:post, log_url).to_return do |request|
          captures << multipart(request)
          captures.length == 1 ? { status: 503, body: "{}" } :
            { status: 200, body: { "responses" => [{ "id" => "binary-ack" }] }.to_json }
        end
        processor = ReportportalCucumber::Service::QueueProcessor.new(
          api: ReportportalCucumber::ReportPortal::API.new(config: config), config: config
        )
        expect(processor.emit_log(
          launch_uuid: wire.fetch("launchUuid"), item_uuid: wire.fetch("itemUuid"),
          message: wire.fetch("message"), level: :info, timestamp: timestamp,
          attachment: { name: name, mime: mime }.merge(attachment_source(name, bytes, source))
        )).to be(true)
        receipt = processor.shutdown_receipt(timeout: 2)
        expect(receipt).to have_attributes(spooled: 1, ambiguous: 1, confirmed: 0, local_settled: true)
        expect(processor.diagnostics.dig(:counters, :spool_failed)).to eq(0)

        id = store.transactions.fetch(0)
        transaction = store.load_transaction(id: id)
        record = wire.merge("file" => { "name" => name })
        expect(transaction.fetch(:entries)).to eq([record])
        file = transaction.fetch(:files).first
        expect(File.binread(file.fetch(:path))).to eq(bytes.b)
        expect(file).to include(entry_index: 0, length: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes))
        %w[launch item].each do |kind|
          uuid = wire.fetch(kind == "launch" ? "launchUuid" : "itemUuid")
          stub_request(:get, "#{config.endpoint}/api/v1/#{config.project}/#{kind}/uuid/#{uuid}")
            .to_return(status: 200, body: { "status" => "IN_PROGRESS" }.to_json)
        end
        replay = ReportportalCucumber::Service::SpoolReplay.new(store: store, config: config)
        result = replay.run(transaction_id: id, execute: true, allow_duplicates: true, timeout: 2)

        expect(result).to include(confirmed: 1, pending: 0, ambiguous: 0, retained: false)
        expect(captures).to eq(Array.new(2) { { entries: [record], files: [{ name: name, bytes: bytes.b }] } })
        expect(store.load_transaction(id: id).fetch(:checkpoint).fetch("states"))
          .to eq([{ "state" => "confirmed", "id" => "binary-ack" }])
        WebMock.reset!
        expect(replay.run(transaction_id: id, execute: true, timeout: 2)).to include(confirmed: 1, retained: false)
        expect(a_request(:any, %r{binary-store\.example\.test})).not_to have_been_made
      ensure
        processor&.shutdown(timeout: 2)
      end
    end
  end

  it "hashes UTF-8 metadata as stored bytes and preserves its exact Unicode wire text" do
    record = wire.merge("message" => "unicode \u96EA \u{1F680}")
    id = store.persist(entries: [record], files: [], outcome: :failed)
    transaction = store.load_transaction(id: id)
    metadata = transaction.fetch(:manifest).fetch("entries")
    bytes = File.binread(File.join(transaction.fetch(:directory), metadata.fetch("path")))

    expect(transaction.fetch(:entries)).to eq([record])
    expect(metadata).to include("length" => bytes.bytesize, "sha256" => Digest::SHA256.hexdigest(bytes))
    expect(store.update_checkpoint(id: id, states: [{ "state" => "confirmed", "id" => "metadata-ack" }]))
      .to include("states" => [{ "state" => "confirmed", "id" => "metadata-ack" }])
  end

  it "spools a locally rejected binary size-limit record as retry-eligible pending" do
    limited = ReportportalCucumber::Config.new(
      endpoint: config.endpoint, project: config.project, api_key: config.api_key,
      spool_dir: config.spool_dir, batch_max_bytes: 1_000, batch_size_logs: 20, flush_interval: 60
    )
    processor = ReportportalCucumber::Service::QueueProcessor.new(
      api: ReportportalCucumber::ReportPortal::API.new(config: limited), config: limited
    )
    bytes = (0..255).to_a.pack("C*").b * 8
    expect(processor.emit_log(
      launch_uuid: wire.fetch("launchUuid"), item_uuid: wire.fetch("itemUuid"),
      message: wire.fetch("message"), level: :info, timestamp: timestamp,
      attachment: { name: "large.bin", mime: "application/octet-stream", bytes: bytes }
    )).to be(true)
    expect(processor.shutdown_receipt(timeout: 2)).to have_attributes(failed: 1, spooled: 1)
    transaction = store.load_transaction(id: store.transactions.fetch(0))
    expect(transaction.fetch(:checkpoint).fetch("states")).to eq([{ "state" => "pending" }])
    expect(File.binread(transaction.fetch(:files).first.fetch(:path))).to eq(bytes)
    expect(a_request(:post, "#{config.endpoint}/api/v1/#{config.project}/log")).not_to have_been_made
  ensure
    processor&.shutdown(timeout: 2)
  end
end
