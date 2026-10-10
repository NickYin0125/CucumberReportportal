# frozen_string_literal: true

require "spec_helper"
require "base64"
require "digest"
require "open3"
require "rbconfig"
require "reportportal_cucumber/service/spool_replay"

RSpec.describe "M4 independent replay feedback with a real Store" do
  let(:directory) { Dir.mktmpdir("m4d-replay-feedback-") }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp-feedback.example.test", project: "feedback", api_key: "synthetic-token",
      spool_dir: File.join(directory, "spool"), retry_attempts: 1
    )
  end
  let(:store) { ReportportalCucumber::Service::SpoolStore.new(config: config) }
  let(:replay) { ReportportalCucumber::Service::SpoolReplay.new(store: store, config: config) }
  let(:entries) do
    4.times.map do |index|
      { "launchUuid" => "11111111-1111-4111-8111-111111111111",
        "itemUuid" => "#{index + 2}2222222-2222-4222-8222-222222222222",
        "time" => "179165000000#{index}", "message" => "synthetic owner #{index}", "level" => "INFO" }
    end
  end
  let(:log_url) { "#{config.endpoint}/api/v1/feedback/log" }

  after do
    FileUtils.remove_entry(directory)
  end

  def open_targets(records)
    stub_request(:get, "#{config.endpoint}/api/v1/feedback/launch/uuid/#{records.first.fetch('launchUuid')}")
      .to_return(status: 200, body: { "status" => "IN_PROGRESS" }.to_json)
    records.each do |entry|
      stub_request(:get, "#{config.endpoint}/api/v1/feedback/item/uuid/#{entry.fetch('itemUuid')}")
        .to_return(status: 200, body: { "status" => "IN_PROGRESS" }.to_json)
    end
  end

  def decode_multipart(body, content_type)
    boundary = content_type[/boundary=(?:"([^"]+)"|([^;]+))/, 1] || Regexp.last_match(2)
    raise "multipart boundary missing" unless boundary

    decoded = { entries: [], files: [] }
    body.b.split("--#{boundary}".b).each do |part|
      headers, bytes = part.delete_prefix("\r\n").split("\r\n\r\n", 2)
      next unless bytes

      bytes = bytes.delete_suffix("\r\n")
      filename = headers[/\bfilename="([^"]+)"/, 1]
      if filename
        decoded[:files] << { name: filename, mime: headers[/Content-Type:\s*([^\r\n]+)/i, 1],
                             bytes: Base64.strict_encode64(bytes), sha256: Digest::SHA256.hexdigest(bytes) }
      elsif headers.include?('name="json_request_part"')
        decoded[:entries].concat(JSON.parse(bytes))
      end
    end
    decoded
  end

  def duplicate_name_fixture
    records = entries.first(2).each_with_index.map { |entry, index| entry.merge("file" => { "name" => "owner-#{index}.bin" }) }
    transaction_id = store.persist(
      entries: records,
      files: records.each_with_index.map do |entry, index|
        { name: entry.fetch("file").fetch("name"), mime: "application/octet-stream", bytes: "owner-#{index}-evidence" }
      end,
      outcome: "failed"
    )
    transaction = store.load_transaction(id: transaction_id)
    root = transaction.fetch(:directory)
    records.each { |entry| entry["file"] = { "name" => "same.bin" } }
    encoded = records.map { |entry| JSON.generate(entry.merge("deliveryOutcome" => "failed")) }.join("\n") + "\n"
    digest = Digest::SHA256.hexdigest(encoded)
    File.binwrite(File.join(root, transaction.fetch(:manifest).fetch("entries").fetch("path")), encoded)
    manifest = JSON.parse(File.read(File.join(root, ".manifest.json")))
    manifest.fetch("entries").merge!("length" => encoded.bytesize, "sha256" => digest)
    manifest.fetch("files").each { |file| file["name"] = "same.bin" }
    manifest.fetch("files").reverse!
    File.write(File.join(root, ".manifest.json"), JSON.generate(manifest))
    checkpoint = JSON.parse(File.read(File.join(root, ".checkpoint.json")))
    checkpoint["entriesSha256"] = digest
    File.write(File.join(root, ".checkpoint.json"), JSON.generate(checkpoint))
    [transaction_id, store.load_transaction(id: transaction_id)]
  end

  def counts(summary)
    summary.slice(:confirmed, :ambiguous, :failed, :pending)
  end

  it "replays the actual symbol-keyed Store descriptor with original attachment bytes and resumes without HTTP" do
    bytes = "\x00healthy-artifact\xFF".b
    record = entries.first.merge("file" => { "name" => "ordinary.bin" })
    transaction_id = store.persist(entries: [record], files: [{ name: "ordinary.bin", mime: "application/octet-stream", bytes: bytes }], outcome: "failed")
    loaded = store.load_transaction(id: transaction_id)
    expect(loaded.fetch(:files).first).to include(name: "ordinary.bin", entry_index: 0, unavailable: false)
    expect(loaded.fetch(:files).first).not_to have_key("name")
    open_targets([record])
    posts = []
    stub_request(:post, log_url).to_return do |request|
      posts << decode_multipart(request.body, request.headers.fetch("Content-Type"))
      { status: 200, body: { "id" => "ordinary-ack" }.to_json }
    end

    summary = replay.run(transaction_id: transaction_id, execute: true, timeout: 5)

    expect(summary).to include(confirmed: 1, ambiguous: 0, pending: 0, retained: false)
    expect(posts).to eq([{ entries: [record], files: [{ name: "ordinary.bin", mime: "application/octet-stream",
                                                     bytes: Base64.strict_encode64(bytes), sha256: Digest::SHA256.hexdigest(bytes) }] }])
    expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states"))
      .to eq([{ "state" => "confirmed", "id" => "ordinary-ack" }])
    WebMock.reset!
    expect(replay.run(transaction_id: transaction_id, execute: true, timeout: 5)).to include(confirmed: 1, retained: false)
    expect(a_request(:any, %r{rp-feedback\.example\.test})).not_to have_been_made
  end

  it "binds same-name attachments by entry index even when another owner's descriptor appears first" do
    transaction_id, loaded = duplicate_name_fixture
    expect(loaded.fetch(:files).map { |file| [file.fetch(:name), file.fetch(:entry_index)] })
      .to eq([["same.bin", 1], ["same.bin", 0]])
    open_targets(loaded.fetch(:entries))
    posts = []
    stub_request(:post, log_url).to_return do |request|
      posts << decode_multipart(request.body, request.headers.fetch("Content-Type"))
      { status: 200, body: { "id" => "owner-ack-#{posts.length}" }.to_json }
    end

    summary = replay.run(transaction_id: transaction_id, execute: true, timeout: 5)

    expect(summary).to include(confirmed: 2, retained: false)
    expect(posts.map { |post| [post.fetch(:entries).first.fetch("itemUuid"), post.fetch(:files).first.fetch(:bytes)] })
      .to eq(entries.first(2).each_with_index.map { |entry, index| [entry.fetch("itemUuid"), Base64.strict_encode64("owner-#{index}-evidence")] })
    expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states").map { |state| state.fetch("id") })
      .to eq(%w[owner-ack-1 owner-ack-2])
  end

  it "counts all durable sibling states after an ambiguous response stops replay" do
    transaction_id = store.persist(entries: entries, files: [], outcome: "failed")
    states = [{ "state" => "failed" }, { "state" => "confirmed", "id" => "existing-sibling-ack" },
              { "state" => "failed" }, { "state" => "ambiguous" }]
    store.update_checkpoint(id: transaction_id, states: states)
    open_targets(entries)
    request = stub_request(:post, log_url).to_return(status: 200, body: "{}")

    summary = replay.run(transaction_id: transaction_id, execute: true, timeout: 5)

    expect(counts(summary)).to eq(confirmed: 1, ambiguous: 2, failed: 1, pending: 0)
    expect(summary).to be_frozen
    expect(counts(replay.run(transaction_id: transaction_id, timeout: 5))).to eq(counts(summary))
    expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states").drop(1)).to eq(states.drop(1))
    expect(request).to have_been_made.once
  end

  { "confirmed" => { "id" => "unpersisted-ack" }, "failed" => { "responses" => [{ "message" => "rejected" }] }, "ambiguous" => {} }.each do |next_state, body|
    it "keeps an unpersisted #{next_state} result ambiguous while preserving a confirmed sibling" do
      transaction_id = store.persist(entries: entries.first(2), files: [], outcome: "failed")
      sibling = { "state" => "confirmed", "id" => "existing-sibling-ack" }
      store.update_checkpoint(id: transaction_id, states: [{ "state" => "pending" }, sibling])
      directory = store.load_transaction(id: transaction_id).fetch(:directory)
      writes = []
      allow(store).to receive(:update_checkpoint).and_wrap_original do |original, **arguments|
        state = arguments.fetch(:states).first.fetch("state")
        writes << state
        raise IOError, "synthetic checkpoint unavailable" if state == next_state

        original.call(**arguments)
      end
      open_targets(entries.first(2))
      request = stub_request(:post, log_url).to_return(status: 200, body: body.to_json)

      summary = replay.run(transaction_id: transaction_id, execute: true, timeout: 5)

      expect(counts(summary)).to eq(confirmed: 1, ambiguous: 1, failed: 0, pending: 0)
      expect(writes).to eq(["in_flight", next_state])
      expect(JSON.parse(File.read(File.join(directory, ".checkpoint.json"))).fetch("states"))
        .to eq([{ "state" => "in_flight" }, sibling])
      expect(counts(replay.run(transaction_id: transaction_id, timeout: 5))).to eq(counts(summary))
      expect(request).to have_been_made.once
    end
  end

  it "preserves failed and confirmed states when the budget expires after target validation" do
    transaction_id = store.persist(entries: entries.first(2), files: [], outcome: "failed")
    states = [{ "state" => "failed" }, { "state" => "confirmed", "id" => "existing-sibling-ack" }]
    store.update_checkpoint(id: transaction_id, states: states)
    offset = 0
    allow(ReportportalCucumber::Service::ReportingDeadline).to receive(:now).and_wrap_original { |original| original.call + offset }
    open_targets(entries.first(2))
    stub_request(:get, "#{config.endpoint}/api/v1/feedback/item/uuid/#{entries.first.fetch('itemUuid')}").to_return do
      offset = 10
      { status: 200, body: { "status" => "IN_PROGRESS" }.to_json }
    end

    summary = replay.run(transaction_id: transaction_id, execute: true, timeout: 5)

    expect(counts(summary)).to eq(confirmed: 1, ambiguous: 0, failed: 1, pending: 0)
    expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states")).to eq(states)
    expect(a_request(:post, log_url)).not_to have_been_made
  end

  [404, 422].each do |status|
    it "checkpoints HTTP #{status} rejection as failed and retries later without duplicate consent" do
      transaction_id = store.persist(entries: entries.first(1), files: [], outcome: "failed")
      open_targets(entries.first(1))
      rejected = stub_request(:post, log_url).to_return(status: status, body: '{"message":"rejected"}')

      summary = replay.run(transaction_id: transaction_id, execute: true, timeout: 5)

      expect(counts(summary)).to eq(confirmed: 0, ambiguous: 0, failed: 1, pending: 0)
      expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states"))
        .to eq([{ "state" => "failed" }])
      expect(rejected).to have_been_made.once
      WebMock.reset!
      open_targets(entries.first(1))
      accepted = stub_request(:post, log_url).to_return(status: 200, body: '{"id":"retry-ack"}')

      expect(replay.run(transaction_id: transaction_id, execute: true, timeout: 5))
        .to include(confirmed: 1, ambiguous: 0, failed: 0, retained: false)
      expect(accepted).to have_been_made.once
      expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states"))
        .to eq([{ "state" => "confirmed", "id" => "retry-ack" }])
    end
  end

  %w[missing checksum path].each do |failure|
    it "refuses #{failure} attachment evidence before any HTTP or in-flight checkpoint" do
      record = entries.first.merge("file" => { "name" => "ordinary.bin" })
      transaction_id = store.persist(entries: [record], files: [{ name: "ordinary.bin", mime: "application/octet-stream", bytes: "original" }], outcome: "failed")
      loaded = store.load_transaction(id: transaction_id)
      file = loaded.fetch(:files).first.fetch(:path)
      case failure
      when "missing"
        File.unlink(file)
      when "checksum"
        File.binwrite(file, "tampered")
      when "path"
        manifest_path = File.join(loaded.fetch(:directory), ".manifest.json")
        manifest = JSON.parse(File.read(manifest_path))
        manifest.fetch("files").first["path"] = "../outside.bin"
        File.write(manifest_path, JSON.generate(manifest))
      end

      expect do
        replay.run(transaction_id: transaction_id, execute: true, timeout: 5)
      end.to raise_error(ReportportalCucumber::Service::SpoolStore::Error)

      expect(a_request(:any, %r{rp-feedback\.example\.test})).not_to have_been_made
      expect(JSON.parse(File.read(File.join(loaded.fetch(:directory), ".checkpoint.json"))).fetch("states"))
        .to eq([{ "state" => "pending" }])
    end
  end

  def run_cli(transaction_id, label)
    root = File.expand_path("../../..", __dir__)
    bootstrap = File.join(directory, "cli-webmock.rb")
    capture_path = File.join(directory, "#{label}.json")
    File.write(bootstrap, <<~'RUBY')
      require "webmock"
      require "base64"
      require "digest"
      require "json"
      include WebMock::API
      WebMock.enable!
      WebMock.disable_net_connect!
      requests = []
      WebMock.after_request do |request, _response|
        requests << { method: request.method, uri: request.uri.to_s,
                      content_type: request.headers["Content-Type"], body: Base64.strict_encode64(request.body.to_s.b) }
      end
      stub_request(:get, %r{\Ahttps://rp-feedback\.example\.test/api/v1/feedback/(launch|item)/uuid/})
        .to_return(status: 200, body: { "status" => "IN_PROGRESS" }.to_json)
      stub_request(:post, "https://rp-feedback.example.test/api/v1/feedback/log")
        .to_return(status: 200, body: { "id" => "cli-attachment-ack" }.to_json)
      at_exit do
        sdk = $LOADED_FEATURES.select { |path| path.match?(%r{/reportportal_cucumber(?:/|\.rb)}) && File.file?(path) }
        capture = { requests: requests, gem_root: Gem.loaded_specs["reportportal-cucumber-ruby"]&.full_gem_path,
                    sdk: sdk.map { |path| { path: File.realpath(path), sha256: Digest::SHA256.file(path).hexdigest } } }
        File.write(ENV.fetch("M4_REPLAY_CAPTURE_PATH"), JSON.pretty_generate(capture))
      end
    RUBY
    env = ENV.keys.select { |key| key.start_with?("RP_") }.to_h { |key| [key, nil] }
    env.merge!("RP_ENDPOINT" => config.endpoint, "RP_PROJECT" => config.project, "RP_API_KEY" => config.api_key,
               "RP_ENABLED" => "true", "RP_REPORTING_ASYNC" => "false", "RP_CONFIG" => nil,
               "M4_REPLAY_CAPTURE_PATH" => capture_path, "CUCUMBER_PROFILE" => nil)
    if (installed = ENV["M4_REPLAY_FEEDBACK_INSTALLED_CLI"])
      env.merge!("RUBYOPT" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLE_BIN_PATH" => nil, "BUNDLER_VERSION" => nil,
                 "GEM_HOME" => ENV.fetch("M4_REPLAY_FEEDBACK_GEM_HOME"), "GEM_PATH" => ENV.fetch("M4_REPLAY_FEEDBACK_GEM_PATH"))
      command = [RbConfig.ruby, "-r", bootstrap, installed]
      expected_root = ENV.fetch("M4_REPLAY_FEEDBACK_INSTALLED_ROOT")
    else
      command = [RbConfig.ruby, "-I#{File.join(root, 'lib')}", "-r", bootstrap, File.join(root, "exe/reportportal-spool")]
      expected_root = root
    end
    stdout, stderr, result = Open3.capture3(env, *command, "--spool-dir", config.spool_dir, "--transaction", transaction_id,
                                           "--execute", "--timeout", "5", chdir: directory)
    capture = JSON.parse(File.read(capture_path))
    store_source = capture.fetch("sdk").find { |file| file.fetch("path").end_with?("/service/spool_store.rb") }
    expect(store_source.fetch("path")).to eq(File.join(File.realpath(expected_root), "lib/reportportal_cucumber/service/spool_store.rb"))
    expect(store_source.fetch("sha256")).to eq(Digest::SHA256.file(File.join(root, "lib/reportportal_cucumber/service/spool_store.rb")).hexdigest)
    if (evidence = ENV["M4_REPLAY_FEEDBACK_EVIDENCE"])
      FileUtils.mkdir_p(evidence)
      File.write(File.join(evidence, "#{label}.json"), JSON.pretty_generate(capture.merge("exit_status" => result.exitstatus, "stdout" => stdout, "stderr" => stderr)))
    end
    [stdout, stderr, result, capture]
  end

  it "executes and resumes attachment replay through the actual CLI process" do
    bytes = "\x00cli-artifact\xFF".b
    record = entries.first.merge("file" => { "name" => "cli.bin" })
    transaction_id = store.persist(entries: [record], files: [{ name: "cli.bin", mime: "application/octet-stream", bytes: bytes }], outcome: "failed")

    stdout, stderr, result, capture = run_cli(transaction_id, "attachment-execute")

    expect(result.exitstatus).to eq(0), stderr
    expect(JSON.parse(stdout)).to include("confirmed" => 1, "retained" => false)
    posts = capture.fetch("requests").select { |request| request.fetch("method") == "post" }
    expect(posts.length).to eq(1)
    decoded = decode_multipart(Base64.strict_decode64(posts.first.fetch("body")), posts.first.fetch("content_type"))
    expect(decoded.fetch(:entries)).to eq([record])
    expect(decoded.fetch(:files).first).to include(name: "cli.bin", bytes: Base64.strict_encode64(bytes))
    expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states"))
      .to eq([{ "state" => "confirmed", "id" => "cli-attachment-ack" }])

    resumed, resumed_stderr, resumed_result, resumed_capture = run_cli(transaction_id, "attachment-resume")

    expect(resumed_result.exitstatus).to eq(0), resumed_stderr
    expect(JSON.parse(resumed)).to include("confirmed" => 1, "retained" => false)
    expect(resumed_capture.fetch("requests")).to be_empty
  end

  it "preserves the wrapped unavailable-attachment message in the CLI's sanitized refusal" do
    record = entries.first.merge("file" => { "name" => "unavailable.bin" })
    transaction_id = store.persist(entries: [record], files: [{ name: "unavailable.bin", mime: "application/octet-stream", path: File.join(directory, "missing-source.bin") }], outcome: "failed")

    stdout, stderr, result, capture = run_cli(transaction_id, "attachment-unavailable")

    expect(result.exitstatus).to eq(2)
    expect(stdout).to be_empty
    expect(stderr).to include("Transaction attachment is unavailable")
    expect(stderr).not_to include(directory, config.api_key)
    expect(capture.fetch("requests").none? { |request| request.fetch("method") == "post" }).to be(true)
    expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states"))
      .to eq([{ "state" => "pending" }])
  end
end
