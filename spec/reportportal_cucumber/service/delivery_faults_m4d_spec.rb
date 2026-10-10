# frozen_string_literal: true

require "spec_helper"
require "socket"
require "timeout"

RSpec.describe "M4-D delivery under transport and persistence faults" do
  class M4DDelayedServer
    attr_reader :port

    def initialize
      @listener = TCPServer.new("127.0.0.1", 0)
      @port = @listener.addr[1]
      @mutex = Mutex.new
      @requests = []
      @connections = []
      @handlers = []
      @release = Queue.new
      @entered = Queue.new
      @acceptor = Thread.new do
        loop do
          socket = @listener.accept
          @mutex.synchronize { @connections << socket }
          @handlers << Thread.new(socket) { |connection| handle(connection) }
        end
      rescue IOError, Errno::EBADF
        nil
      end
    end

    def endpoint = "http://127.0.0.1:#{port}"
    def first_received = Timeout.timeout(1) { @entered.pop }
    def requests = @mutex.synchronize { @requests.map(&:dup) }

    def stop
      @release << true
      @listener.close
      @acceptor.join(0.2)
      @connections.each { |socket| socket.close rescue nil }
      @handlers.each { |thread| thread.join(0.2); thread.kill if thread.alive? }
    end

    private

    def handle(socket)
      line = socket.gets("\r\n")
      return unless line

      headers = {}
      while (line = socket.gets("\r\n")) && line != "\r\n"
        key, value = line.split(":", 2)
        headers[key.downcase] = value.strip
      end
      entry = JSON.parse(socket.read(headers.fetch("content-length").to_i))
      ordinal = @mutex.synchronize { @requests << entry; @requests.length }
      if ordinal == 1
        @entered << true
        @release.pop
      end
      body = JSON.generate("id" => "accepted-attempt-#{ordinal}")
      socket.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
    rescue IOError, Errno::EPIPE, Errno::ECONNRESET
      nil
    ensure
      socket.close rescue nil
    end
  end

  let(:directory) { Dir.mktmpdir("m4d-fault-") }
  let(:endpoint) { "https://rp-m4d-fault.example.test" }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: endpoint, project: "m4d", api_key: "synthetic-m4d-token", spool_dir: directory,
      retry_attempts: 2, retry_base_interval: 0.001, retry_max_interval: 0.001,
      flush_interval: 10, batch_size_logs: 2, exit_flush_timeout_ms: 200,
      open_timeout: 0.06, read_timeout: 0.06, write_timeout: 0.06
    )
  end
  let(:api) { ReportportalCucumber::ReportPortal::API.new(config: config) }
  let(:processor) { ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, video_uploader: nil) }

  def emit(message, timestamp: Time.utc(2026, 10, 10))
    processor.emit_log(launch_uuid: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                       item_uuid: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", message: message,
                       timestamp: timestamp, level: :info)
  end

  after do
    @processor&.shutdown_receipt(timeout: 0.2)
    FileUtils.remove_entry(directory) if File.directory?(directory)
  end

  [408, 429, 502, 504].each do |status|
    it "retries HTTP #{status}, confirms the eventual ID, and retains duplicate risk" do
      request = stub_request(:post, "#{endpoint}/api/v1/m4d/log").to_return(
        { status: status, body: '{"message":"controlled transient failure"}' },
        { status: 200, body: '{"id":"eventual-log-id"}' }
      )
      @processor = processor
      expect(emit("retry-#{status}")).to be(true)
      receipt = processor.flush_receipt(timeout: 0.2)

      expect(request).to have_been_made.twice
      expect(receipt.to_h).to include(confirmed: 1, pending: 0, possible_duplicates: 1, complete: false)
      expect(ReportportalCucumber::Service::SpoolStore.new(config: config).transactions).to be_empty
    end
  end

  [400, 401, 403, 404, 422].each do |status|
    it "settles HTTP #{status} as failed after one attempt and preserves its original owner" do
      request = stub_request(:post, "#{endpoint}/api/v1/m4d/log").to_return(status: status, body: '{"message":"definitive refusal"}')
      @processor = processor
      expect(emit("refused-#{status}")).to be(true)
      receipt = processor.flush_receipt(timeout: 0.2)
      store = ReportportalCucumber::Service::SpoolStore.new(config: config)
      transactions = store.transactions.map { |id| store.load_transaction(id: id) }

      expect(request).to have_been_made.once
      expect(receipt.to_h).to include(failed: 1, ambiguous: 0, spooled: 1, confirmed: 0, pending: 0, complete: false)
      expect(transactions.length).to eq(1)
      expect(transactions.first.fetch(:entries).first).to include(
        "launchUuid" => "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        "itemUuid" => "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "message" => "refused-#{status}"
      )
      expect(transactions.first.fetch(:checkpoint).fetch("states")).to eq([{ "state" => "pending" }])
    end
  end

  it "spools only the unacknowledged sibling of a partial HTTP 200 batch" do
    request = stub_request(:post, "#{endpoint}/api/v1/m4d/log")
              .to_return(status: 200, body: '{"responses":[{"id":"first-confirmed"}]}')
    @processor = processor
    expect(emit("confirmed-first")).to be(true)
    expect(emit("ambiguous-second")).to be(true)
    receipt = processor.flush_receipt(timeout: 0.2)
    store = ReportportalCucumber::Service::SpoolStore.new(config: config)
    transactions = store.transactions.map { |id| store.load_transaction(id: id) }

    expect(request).to have_been_made.once
    expect(receipt.to_h).to include(confirmed: 1, ambiguous: 1, spooled: 1, pending: 0, complete: false)
    expect(transactions.flat_map { |transaction| transaction.fetch(:entries) }.map { |entry| entry.fetch("message") }).to eq(["ambiguous-second"])
  end

  it "exposes duplicate risk when a real server accepts a POST but its first response times out" do
    server = M4DDelayedServer.new
    WebMock.disable_net_connect!(allow: ["127.0.0.1"])
    allow(config).to receive(:endpoint).and_return(server.endpoint)
    allow(config).to receive(:read_timeout).and_return(0.06)
    allow(config).to receive(:flush_interval).and_return(0.01)
    @processor = processor
    expect(emit("accepted-before-lost-response")).to be(true)
    server.first_received
    receipt = processor.flush_receipt(timeout: 0.2)
    requests = server.requests

    expect(requests.length).to eq(2)
    expect(requests.first).to eq(requests.last)
    expect(requests.first).to include("message" => "accepted-before-lost-response", "time" => "1791590400000")
    expect(receipt.to_h).to include(confirmed: 1, possible_duplicates: 1, pending: 0, complete: false)
  ensure
    server&.stop
  end

  it "shares one 80ms shutdown deadline with real slow HTTP and does not send another attempt" do
    server = M4DDelayedServer.new
    WebMock.disable_net_connect!(allow: ["127.0.0.1"])
    allow(config).to receive(:endpoint).and_return(server.endpoint)
    allow(config).to receive(:read_timeout).and_return(1)
    allow(config).to receive(:flush_interval).and_return(10)
    @processor = processor
    expect(emit("shutdown-before-response")).to be(true)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    receipt = processor.shutdown_receipt(timeout: 0.08)

    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.18
    expect(server.requests.length).to eq(1)
    expect(receipt.confirmed).to eq(0)
    expect(receipt.complete).to be(false)
    expect(receipt.pending + receipt.ambiguous).to eq(1)
  ensure
    server&.stop
  end

  it "retains an ambiguous receipt after bounded offline connection attempts" do
    listener = TCPServer.new("127.0.0.1", 0)
    port = listener.addr[1]
    listener.close
    WebMock.disable_net_connect!(allow: ["127.0.0.1"])
    allow(config).to receive(:endpoint).and_return("http://127.0.0.1:#{port}")
    @processor = processor
    expect(emit("offline-log")).to be(true)
    receipt = processor.flush_receipt(timeout: 0.2)

    expect(receipt.to_h).to include(confirmed: 0, ambiguous: 1, spooled: 1, pending: 0, complete: false)
  end

  it "reports failed persistence under ENOSPC without a published or unlimited fallback transaction" do
    stub_request(:post, "#{endpoint}/api/v1/m4d/log").to_return(status: 503, body: '{"message":"offline"}')
    allow(File).to receive(:open).and_wrap_original do |original, path, *arguments, **keywords, &block|
      raise Errno::ENOSPC if path.to_s.start_with?(directory + File::SEPARATOR) && path.to_s.end_with?("entries.ndjson")

      original.call(path, *arguments, **keywords, &block)
    end
    @processor = processor
    expect(emit("disk-full-log")).to be(true)
    receipt = processor.flush_receipt(timeout: 0.2)

    expect(receipt.to_h).to include(confirmed: 0, ambiguous: 1, spooled: 0, complete: false)
    expect(processor.diagnostics.dig(:counters, :spool_failed)).to eq(1)
    expect(Dir.glob(File.join(directory, "tx-*.ndjson"))).to be_empty
  end
end
