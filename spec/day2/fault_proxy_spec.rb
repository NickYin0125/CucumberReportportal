# frozen_string_literal: true

require "spec_helper"
require_relative "../../examples/day2_faults/session"
require_relative "../../examples/day2_faults/sandbox"

RSpec.describe Day2Faults::FaultProxy do
  around do |example|
    # WebMock materializes body_stream via read(nil), changing streaming semantics.
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
  end

  before do
    @sandbox = Day2Faults::Sandbox.new
    @sessions = []
    @proxies = []
  end

  after do
    if ENV["DAY2_LOCAL_CAPTURE"]
      @sessions.each do |run|
        Day2Faults.write_evidence(File.join(ENV.fetch("DAY2_LOCAL_CAPTURE"), "sessions", "#{run.name}.json"),
                                 { receipt: run.queue.reporting_receipt.to_h, diagnostics: run.queue.diagnostics,
                                   proxy_events: run.proxy.events, sandbox: @sandbox.snapshot, spool: run.spool_evidence })
      end
    end
    @sessions.each { |session| session.close; FileUtils.remove_entry(session.directory) }
    @proxies.each(&:stop)
    @sandbox.stop
  end

  def session(**options)
    Day2Faults::Session.new(upstream: @sandbox.endpoint, **options).tap { |value| @sessions << value }
  end

  def proxy(**options)
    described_class.new(upstream: @sandbox.endpoint, **options).tap { |value| @proxies << value }
  end

  it "streams binary multipart unchanged with bounded chunks and no captured authorization" do
    run = session
    binary = ("\x00\xff\r\n\x80".b * 20_000).freeze
    expect(run.emit(attachment: { name: "binary.dat", mime: "application/octet-stream", bytes: binary })).to be(true)
    expect(run.flush.confirmed).to eq(1)
    sent = run.proxy.events.find { |event| event[:path].end_with?("/log") }
    received = @sandbox.snapshot.fetch("requests").find { |event| event["path"].end_with?("/log") }
    expect(sent[:request_sha256]).to eq(received.fetch("sha256"))
    expect(sent[:request_bytes]).to eq(received.fetch("bytes"))
    expect(sent[:peak_chunk]).to be <= Day2Faults::BodyStream::CHUNK
    expect(@sandbox.snapshot.fetch("logs").first.fetch("files").first).to include(
      "bytes" => binary.bytesize, "sha256" => Digest::SHA256.hexdigest(binary)
    )
    expect(JSON.generate(run.proxy.events)).not_to include("local-synthetic", "Authorization")
  end

  it "preserves status, end-to-end headers, exact binary response, path and query" do
    edge = proxy
    uri = URI(edge.endpoint + "/api/v1/day2/download?selector=a%2Fb")
    request = Net::HTTP::Get.new(uri)
    request["X-Day2-Trace"] = "preserved"
    response = Net::HTTP.start(uri.host, uri.port, nil) { |http| http.request(request) }
    expect(response.code).to eq("200")
    expect(response["x-day2-upstream"]).to eq("sandbox")
    expect(response["content-type"]).to eq("application/octet-stream")
    expect(response.body.b).to eq("\x00\xffbinary\r\n".b)
    expect(@sandbox.snapshot.fetch("requests").last.fetch("trace")).to eq("preserved")
    expect(@sandbox.snapshot.fetch("requests").last.fetch("query")).to eq("selector=a%2Fb")
  end

  it "rejects excessive request bodies before any upstream traffic" do
    edge = proxy(max_body: 100)
    uri = URI(edge.endpoint + "/api/v1/day2/log")
    response = Net::HTTP.start(uri.host, uri.port, nil) { |http| http.post(uri.path, "x" * 101) }
    expect(response.code).to eq("413")
    expect(@sandbox.snapshot.fetch("requests")).to be_empty
  end

  it "caps response bytes and retained request evidence" do
    edge = proxy(response_cap: 4, max_events: 2)
    uri = URI(edge.endpoint + "/download")
    4.times do
      expect { Net::HTTP.start(uri.host, uri.port, nil) { |http| http.max_retries = 0; http.get(uri.path) } }
        .to raise_error(EOFError)
    end
    expect(edge.events.length).to eq(2)
    expect(edge.seen).to eq(4)
    expect(edge.events.map { |event| event[:error_class] }).to all(eq("Day2Faults::LimitError"))
  end

  it "keeps creation and finish metadata coherent when faults target logs only" do
    run = session(steps: [{ action: :status, status: 503 }], repeat: true, retry_attempts: 1)
    run.emit
    expect(run.flush.to_h).to include(ambiguous: 1, spooled: 1, failed: 0)
    run.finish(status: "FAILED")
    snapshot = @sandbox.snapshot
    expect(snapshot.fetch("launches").fetch(run.launch).fetch("status")).to eq("FAILED")
    expect(snapshot.fetch("items").fetch(run.item).fetch("status")).to eq("FAILED")
    expect(run.proxy.events.reject { |event| event[:path].end_with?("/log") }.map { |event| event[:action] })
      .to all(eq(:pass))
  end

  it "retries 503 and 504 then succeeds with identical upload bodies and original owner UUIDs" do
    run = session(steps: [{ action: :status, status: 503 }, { action: :status, status: 504 }])
    run.emit("retry body")
    receipt = run.flush
    expect(receipt.to_h).to include(confirmed: 1, possible_duplicates: 1, pending: 0, complete: false)
    logs = run.proxy.events.select { |event| event[:path].end_with?("/log") }
    expect(logs.map { |event| event[:status] }).to eq([503, 504, 201])
    expect(logs.map { |event| event[:request_sha256] }.uniq.length).to eq(1)
    expect(@sandbox.snapshot.fetch("logs").first).to include("launchUuid" => run.launch, "itemUuid" => run.item)
    expect(run.store.transactions).to be_empty
  end

  it "reuses multipart request bytes and UUIDs across a retry" do
    run = session(steps: [{ action: :status, status: 504 }])
    run.emit("retry attachment", attachment: { name: "evidence.png", mime: "image/png", bytes: Day2Faults::Session::PNG })
    expect(run.flush.to_h).to include(confirmed: 1, possible_duplicates: 1)
    logs = run.proxy.events.select { |event| event[:path].end_with?("/log") }
    expect(logs.length).to eq(2)
    expect(logs.map { |event| event[:request_sha256] }.uniq.length).to eq(1)
  end

  it "reuses the supplied launch UUID across retried metadata creation" do
    run = session(scope: :all, steps: [{ action: :status, status: 503 }])
    requests = run.proxy.events.select { |event| event[:path].end_with?("/launch") }
    expect(requests.length).to eq(2)
    expect(requests.map { |event| event[:request_sha256] }.uniq.length).to eq(1)
    expect(@sandbox.snapshot.fetch("launches").keys).to eq([run.launch])
  end

  it "reports async acknowledgement as awaiting persistence, never v1-confirmed delivery" do
    run = session(reporting_async: true)
    run.emit
    expect(run.flush.to_h).to include(confirmed: 0, accepted_awaiting_persistence: 1, complete: false)
  end

  it "reports quota-limited retention failure without claiming a durable spool" do
    run = session(steps: [{ action: :status, status: 503 }], repeat: true, retry_attempts: 1, spool_max_bytes: 200)
    run.emit("quota-limited")
    expect(run.flush.to_h).to include(confirmed: 0, ambiguous: 1, spooled: 0, complete: false)
    expect(run.queue.diagnostics.dig(:counters, :spool_failed)).to eq(1)
    expect(run.store.transactions).to be_empty
  end

  it "rejects ambiguous request framing before forwarding to RP" do
    edge = proxy
    socket = TCPSocket.new("127.0.0.1", edge.port)
    socket.write("POST /api/v1/day2/log HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n")
    expect(socket.gets).to include("400")
    expect(@sandbox.snapshot.fetch("requests")).to be_empty
  ensure
    socket&.close
  end

  [400, 401].each do |code|
    it "fails fast on HTTP #{code} without a network retry" do
      run = session(steps: [{ action: :status, status: code }], repeat: true)
      run.emit
      expect(run.flush.to_h).to include(confirmed: 0, failed: 1, spooled: 1, ambiguous: 0, pending: 0)
      expect(run.proxy.events.count { |event| event[:path].end_with?("/log") }).to eq(1)
      expect(run.store.transactions.length).to eq(1)
    end
  end

  it "acknowledges slow but successful RP within the flush budget" do
    run = session(steps: [{ action: :slow, delay: 0.08 }])
    run.emit
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(run.flush.to_h).to include(confirmed: 1, pending: 0, ambiguous: 0, spooled: 0)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).to be_between(0.07, 0.6)
  end

  it "settles deterministic disconnects as ambiguous and durably retains them" do
    run = session(steps: [{ action: :disconnect }], repeat: true, retry_attempts: 2)
    run.emit
    expect(run.flush.to_h).to include(confirmed: 0, ambiguous: 1, spooled: 1, pending: 0)
    expect(run.proxy.events.count { |event| event[:action] == :disconnect }).to eq(2)
    expect(@sandbox.snapshot.fetch("logs")).to be_empty
  end

  it "settles a deterministic response timeout without treating it as a definite refusal" do
    run = session(steps: [{ action: :timeout, delay: 1.2 }], retry_attempts: 1)
    run.emit
    expect(run.flush(timeout: 1.4).to_h).to include(confirmed: 0, ambiguous: 1, spooled: 1, pending: 0)
  end

  it "marks accepted-but-hidden acknowledgement retries as possibly duplicate" do
    run = session(steps: [{ action: :hidden_ack }], retry_attempts: 2)
    run.emit("accepted twice")
    expect(run.flush.to_h).to include(confirmed: 1, possible_duplicates: 1, complete: false)
    expect(@sandbox.snapshot.fetch("logs").length).to eq(2)
    expect(run.proxy.events.find { |event| event[:action] == :hidden_ack }).to include(uncertain: true, upstream_status: 201)
  end

  it "retains only unacknowledged siblings after hiding part of real accepted batch" do
    run = session(steps: [{ action: :partial_ack, keep: 1 }])
    run.emit("known-confirmed")
    run.emit("accepted-but-hidden", attachment: { name: "evidence.png", mime: "image/png", bytes: Day2Faults::Session::PNG })
    expect(run.flush.to_h).to include(confirmed: 1, ambiguous: 1, spooled: 1, pending: 0, complete: false)
    expect(@sandbox.snapshot.fetch("logs").length).to eq(2)
    transaction = run.spool_evidence.first
    expect(transaction.fetch(:entries).map { |entry| entry.fetch("message") }).to eq(["accepted-but-hidden"])
    expect(transaction.fetch(:artifacts).first).to include(bytes: Day2Faults::Session::PNG.bytesize,
                                                         sha256: Digest::SHA256.hexdigest(Day2Faults::Session::PNG))
    expect(run.replay(execute: true).first).to include(ambiguous: 1, confirmed: 0)
    expect(@sandbox.snapshot.fetch("logs").length).to eq(2)
    expect(run.replay(execute: true, allow_duplicates: true).first).to include(confirmed: 1, ambiguous: 0)
    expect(@sandbox.snapshot.fetch("logs").length).to eq(3)
    expect(run.replay(execute: true, allow_duplicates: true).first).to include(confirmed: 1)
    expect(@sandbox.snapshot.fetch("logs").length).to eq(3)
    expect(@sandbox.snapshot.fetch("logs").count { |log| log["message"] == "known-confirmed" }).to eq(1)
  end

  it "persists failed multipart bytes and replays to original open owner without known-confirmed resend" do
    run = session(steps: [{ action: :status, status: 400 }], retry_attempts: 1)
    run.emit("durable artifact", attachment: { name: "evidence.png", mime: "image/png", bytes: Day2Faults::Session::PNG })
    expect(run.flush.to_h).to include(failed: 1, spooled: 1)
    evidence = run.spool_evidence.first
    expect(evidence.fetch(:manifest).dig("entries", "length")).to be > 0
    expect(evidence.fetch(:artifacts).first).to include(bytes: Day2Faults::Session::PNG.bytesize,
                                                      sha256: Digest::SHA256.hexdigest(Day2Faults::Session::PNG))
    expect(run.replay.first).to include(dry_run: true, pending: 1)
    expect(run.replay(execute: true).first).to include(confirmed: 1, pending: 0, retained: false)
    before = run.proxy.seen
    expect(run.replay(execute: true).first).to include(confirmed: 1)
    expect(run.proxy.seen).to eq(before)
    log = @sandbox.snapshot.fetch("logs").first
    expect(log).to include("launchUuid" => run.launch, "itemUuid" => run.item)
    expect(log.fetch("files").first).to include("sha256" => Digest::SHA256.hexdigest(Day2Faults::Session::PNG))
  end

  it "recovers durable artifacts and confirmed checkpoints after recreating the proxy and replay objects" do
    run = session(steps: [{ action: :status, status: 400 }], retry_attempts: 1)
    run.emit("restart replay", attachment: { name: "restart.png", mime: "image/png", bytes: Day2Faults::Session::PNG })
    expect(run.flush.spooled).to eq(1)
    run.queue.shutdown_receipt(timeout: 0.2)
    port = run.proxy.port
    run.proxy.stop
    edge = proxy(port: port)
    store = ReportportalCucumber::Service::SpoolStore.new(config: run.config)
    id = store.transactions.first
    replay = ReportportalCucumber::Service::SpoolReplay.new(store: store, config: run.config)
    expect(replay.run(transaction_id: id, execute: true, timeout: 1)).to include(confirmed: 1)
    second = ReportportalCucumber::Service::SpoolReplay.new(
      store: ReportportalCucumber::Service::SpoolStore.new(config: run.config), config: run.config
    )
    before = edge.seen
    expect(second.run(transaction_id: id, execute: true, timeout: 1)).to include(confirmed: 1)
    expect(edge.seen).to eq(before)
    expect(@sandbox.snapshot.fetch("logs").last).to include("launchUuid" => run.launch, "itemUuid" => run.item)
    expect(@sandbox.snapshot.fetch("logs").last.fetch("files").first.fetch("sha256"))
      .to eq(Digest::SHA256.hexdigest(Day2Faults::Session::PNG))
  end

  it "enforces queue record and byte bounds including rejected large records" do
    run = session(queue_max_records: 4, queue_max_bytes: 4096, steps: [{ action: :timeout, delay: 0.5 }], repeat: true)
    admissions = 50.times.map { |index| run.emit("#{index}:#{'x' * 800}") }
    expect(run.emit("x" * 5000)).to be(false)
    diagnostics = run.queue.diagnostics
    expect(diagnostics[:peak_records]).to be <= 4
    expect(diagnostics[:peak_bytes]).to be <= 4096
    expect(admissions.count(false)).to be > 0
    expect(diagnostics.dig(:counters, :rejected_oversized)).to be > 0
  end

  it "honors an already expired total flush budget without claiming confirmed or durable delivery" do
    run = session
    run.emit
    deadline = ReportportalCucumber::Service::ReportingDeadline.new(timeout: 0)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    receipt = run.queue.shutdown_receipt(timeout: 1, deadline: deadline)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).to be < 0.15
    expect(receipt.to_h).to include(confirmed: 0, complete: false, timed_out: true)
    expect(receipt.pending + receipt.ambiguous).to eq(1)
  end

  it "bounds shutdown during slow HTTP by one total deadline" do
    run = session(steps: [{ action: :slow, delay: 0.5 }])
    run.emit
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    receipt = run.queue.shutdown_receipt(timeout: 0.08)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).to be < 0.25
    expect(receipt.confirmed).to eq(0)
    expect(receipt.complete).to be(false)
    expect(receipt.pending + receipt.ambiguous).to eq(1)
  end

  it "surfaces finish outage while successful log delivery does not imply coherent completion" do
    run = session(scope: :finish, steps: [{ action: :status, status: 503 }], repeat: true, retry_attempts: 2)
    run.emit
    expect(run.flush.confirmed).to eq(1)
    deadline = ReportportalCucumber::Service::ReportingDeadline.new(timeout: 0.3)
    expect { run.finish(deadline: deadline) }.to raise_error(ReportportalCucumber::Transport::HTTPClient::Error)
    expect(@sandbox.snapshot.fetch("items").fetch(run.item).fetch("status")).to eq("IN_PROGRESS")
  end
end
