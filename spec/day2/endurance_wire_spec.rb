# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "socket"
require_relative "../../examples/day2_endurance/wire_observer"
require_relative "../../examples/day2_endurance/auth"

RSpec.describe Day2Endurance::WireObserver do
  around do |example|
    Dir.mktmpdir("wire-unit-") do |directory|
      @directory = directory
      example.run
    ensure
      Day2Endurance.wire_observer = nil
      Day2Endurance.session = nil
    end
  end

  def observer(bytes: 2_097_152, entries: 20, endpoint: "http://127.0.0.1:9000")
    described_class.new(endpoint: endpoint, project: "unit", directory: @directory, max_bytes: bytes, max_entries: entries)
  end

  def request_for(body, type: "application/json", stream: false)
    request = Net::HTTP::Post.new("/api/v1/unit/log")
    request["Content-Type"] = type
    request.content_length = body.bytesize
    stream ? request.body_stream = StringIO.new(body) : request.body = body
    request
  end

  def observe_body(sensor, request)
    sensor.observe(request) do
      IO.copy_stream(request.body_stream, StringIO.new) if request.body_stream
      Struct.new(:code).new("201")
    end
  end

  def multipart
    "--unit-boundary\r\nContent-Disposition: form-data; name=\"json_request_part\"\r\nContent-Type: application/json\r\n\r\n" \
      "[{\"itemUuid\":\"original-owner\",\"message\":\"CSV\",\"file\":{\"name\":\"report.csv\"}}]\r\n" \
      "--unit-boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"report.csv\"\r\nContent-Type: text/csv\r\n\r\n" \
      "batch,status\nb1,COMPLETED\n\r\n--unit-boundary--\r\n"
  end

  def populate_valid_stream(sensor)
    observe_body(sensor, request_for(multipart, type: "multipart/form-data; boundary=unit-boundary", stream: true))
  end

  it "measures actual serialized singleton JSON bytes, entries and body hash" do
    body = JSON.generate(itemUuid: "owner", message: "x")
    sensor = observer
    observe_body(sensor, request_for(body))
    expect(sensor.records.first).to include(body_bytes: body.bytesize, serialized_entries: 1, body_sha256: Digest::SHA256.hexdigest(body), owner_uuids: ["owner"])
  end

  it "measures every consumed streamed multipart byte including framing and CSV" do
    sensor = observer
    populate_valid_stream(sensor)
    expect(sensor.records.first).to include(body_bytes: multipart.bytesize, content_length: multipart.bytesize, serialized_entries: 1, streamed: true, body_sha256: Digest::SHA256.hexdigest(multipart))
    expect(sensor.validate!(receipt: { confirmed: 1 }, sent_batches: 1).fetch(:streamed_requests)).to eq(1)
  end

  it "rejects actual byte overflow even when an estimated content length claims it fits" do
    sensor = observer(bytes: 10)
    request = request_for(JSON.generate(message: "x" * 100))
    request.content_length = 5
    observe_body(sensor, request)
    expect { sensor.validate!(receipt: { confirmed: 1 }, sent_batches: 1) }.to raise_error(Day2Endurance::InvariantError, "actual upload body byte bound")
  end

  it "rejects an actual serialized batch of 21 entries" do
    sensor = observer
    observe_body(sensor, request_for(JSON.generate(Array.new(21) { { message: "entry" } })))
    expect { sensor.validate!(receipt: { confirmed: 21 }, sent_batches: 1) }.to raise_error(Day2Endurance::InvariantError, "actual serialized batch entry bound")
  end

  it "accepts the exact configured entry bound before the independent stream requirement" do
    sensor = observer
    observe_body(sensor, request_for(JSON.generate(Array.new(20) { { message: "entry" } })))
    expect(sensor.summary.fetch(:observed_max_entries)).to eq(20)
    expect { sensor.validate!(receipt: { confirmed: 20 }, sent_batches: 1) }.to raise_error(Day2Endurance::InvariantError, "actual CSV stream observed")
  end

  it "rejects content length differing from consumed bytes" do
    sensor = observer
    request = request_for(multipart, type: "multipart/form-data; boundary=unit-boundary", stream: true)
    request.content_length = multipart.bytesize - 1
    observe_body(sensor, request)
    expect { sensor.validate!(receipt: { confirmed: 1 }, sent_batches: 1) }.to raise_error(Day2Endurance::InvariantError, "actual uploaded content length")
  end

  it "rejects mismatched logical sent-batch totals" do
    sensor = observer
    populate_valid_stream(sensor)
    expect { sensor.validate!(receipt: { confirmed: 1 }, sent_batches: 2) }.to raise_error(Day2Endurance::InvariantError, "wire request count matches sent batches")
  end

  it "rejects mismatched confirmed-entry totals" do
    sensor = observer
    populate_valid_stream(sensor)
    expect { sensor.validate!(receipt: { confirmed: 2 }, sent_batches: 1) }.to raise_error(Day2Endurance::InvariantError, "wire entries match confirmed receipt")
  end

  it "rejects malformed serialized JSON without storing raw payload or headers" do
    sensor = observer
    request = request_for("not-json")
    request["Authorization"] = "Bearer unit-private-canary"
    observe_body(sensor, request)
    expect { sensor.validate!(receipt: { confirmed: 1 }, sent_batches: 1) }.to raise_error(Day2Endurance::InvariantError, "actual serialized batch entry bound")
    expect(File.read(File.join(@directory, "wire.ndjson"))).not_to include("unit-private-canary", "not-json")
  end

  it "preserves the original transport exception identity" do
    original = IOError.new("unit transport failure")
    sensor = observer
    expect { sensor.observe(request_for(JSON.generate(message: "entry"))) { raise original } }.to raise_error { |error| expect(error).to equal(original) }
    expect(sensor.records.first.fetch(:transport_error)).to eq("IOError")
  end

  it "observes a real loopback HTTP request and matches the server's received bytes" do
    WebMock.disable!
    Net::HTTP.prepend(Day2Endurance::WireHook) unless Net::HTTP.ancestors.include?(Day2Endurance::WireHook)
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr.fetch(1)
    received = Queue.new
    worker = Thread.new do
      socket = server.accept
      headers = +""
      headers << socket.read(1) until headers.end_with?("\r\n\r\n")
      length = headers.match(/Content-Length: (\d+)/i)[1].to_i
      received << socket.read(length)
      socket.write("HTTP/1.1 201 Created\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}")
      socket.close
    end
    sensor = observer(endpoint: "http://127.0.0.1:#{port}")
    Day2Endurance.wire_observer = sensor
    request = request_for(multipart, type: "multipart/form-data; boundary=unit-boundary", stream: true)
    Net::HTTP.start("127.0.0.1", port) { |http| http.request(request) }
    actual = received.pop
    worker.join
    expect(actual).to eq(multipart)
    expect(sensor.records.size).to eq(1)
    expect(sensor.records.first).to include(body_bytes: actual.bytesize, body_sha256: Digest::SHA256.hexdigest(actual))
    expect(sensor.validate!(receipt: { confirmed: 1 }, sent_batches: 1).fetch(:request_count)).to eq(1)
  ensure
    server&.close
    worker&.kill if worker&.alive?
    WebMock.enable!
  end
end

RSpec.describe Day2Endurance::Auth do
  it "uses standard RP_API_KEY without reading or loading a proprietary helper" do
    expect(File).not_to receive(:file?)
    expect(described_class.resolve(endpoint: "http://rp.example", directory: Dir.tmpdir,
                                  environment: { "RP_API_KEY" => "unit-env-token", "DAY2_AUTH_HELPER" => "/unavailable" })).to eq(["unit-env-token", "RP_API_KEY environment"])
  end

  it "fails clearly when neither credentials nor an available optional helper exists" do
    expect { described_class.resolve(endpoint: "http://localhost", directory: Dir.tmpdir,
                                     environment: {}) }.to raise_error(ArgumentError, /explicitly provide/)
  end
end
