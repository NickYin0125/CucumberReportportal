# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "open3"
require "rubygems"
require "socket"
require "tmpdir"
require "uri"

module M4InstalledGemConsumer
  TEST_TOKEN = "m4-installed-consumer-test-only-token"
  PROJECT = "m4_installed_consumer"
  LAUNCH_UUID = "11111111-1111-4111-8111-111111111111"
  ITEM_UUID = "22222222-2222-4222-8222-222222222222"
  JSON_MESSAGE = JSON.generate("test" => "installed-gem", "ordinal" => 1).freeze
  PNG_BYTES = Base64.strict_decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nXxkAAAAASUVORK5CYII="
  ).b.freeze

  class StatefulMock
    attr_reader :port

    def initialize
      @server = TCPServer.new("127.0.0.1", 0)
      @port = @server.addr[1]
      @mutex = Mutex.new
      @requests = []
      @log_attempt = 0
      @item_status = "IN_PROGRESS"
      @stopping = false
      @thread = Thread.new { serve }
    end

    def endpoint
      "http://127.0.0.1:#{port}"
    end

    def requests
      @mutex.synchronize { @requests.map(&:dup) }
    end

    def set_item_status(status)
      @mutex.synchronize { @item_status = status }
    end

    def stop
      @stopping = true
      @server.close
      @thread.join(1)
    rescue IOError
      @thread&.join(1)
    end

    private

    def serve
      loop do
        socket = @server.accept
        Thread.new(socket) { |connection| handle(connection) }
      rescue IOError, Errno::EBADF
        break if @stopping
        raise
      end
    end

    def handle(socket)
      request_line = socket.gets("\r\n")
      return unless request_line

      method, target, = request_line.split(" ", 3)
      headers = {}
      while (line = socket.gets("\r\n")) && line != "\r\n"
        key, value = line.split(":", 2)
        headers[key.to_s.downcase] = value.to_s.strip
      end
      body = socket.read(headers.fetch("content-length", "0").to_i) || "".b
      path = URI(target).path
      request = { method: method, path: path }
      status, payload = route(method, path, headers, body, request)
      @mutex.synchronize { @requests << request.merge(status: status) }
      encoded = JSON.generate(payload)
      socket.write("HTTP/1.1 #{status} #{reason(status)}\r\n")
      socket.write("Content-Type: application/json\r\n")
      socket.write("Content-Length: #{encoded.bytesize}\r\n")
      socket.write("Connection: close\r\n\r\n")
      socket.write(encoded)
    rescue StandardError => error
      warn("mock request rejected: #{error.class}")
      begin
        socket.write("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
      rescue IOError
        nil
      end
    ensure
      socket&.close
    end

    def route(method, path, headers, body, request)
      if method == "GET" && path.end_with?("/launch/uuid/#{LAUNCH_UUID}")
        return [200, { "id" => LAUNCH_UUID, "uuid" => LAUNCH_UUID, "status" => "IN_PROGRESS" }]
      end
      if method == "GET" && path.end_with?("/item/uuid/#{ITEM_UUID}")
        status = @mutex.synchronize { @item_status }
        return [200, { "id" => ITEM_UUID, "uuid" => ITEM_UUID, "status" => status }]
      end
      if method == "POST" && path.end_with?("/log")
        request.merge!(parse_log_request(headers, body))
        attempt = @mutex.synchronize { @log_attempt += 1 }
        return [503, { "message" => "controlled replay fault" }] if attempt == 2
        return [200, { "id" => "ack-json-#{attempt}" }] if attempt == 1
        return [200, { "responses" => [{ "id" => "ack-png-#{attempt}" }] }] if attempt == 3

        return [503, { "message" => "unexpected extra replay request" }]
      end

      [404, { "message" => "mock route not found" }]
    end

    def parse_log_request(headers, body)
      content_type = headers.fetch("content-type", "")
      if content_type.start_with?("application/json")
        { content_type: "application/json", entries: [JSON.parse(body)], files: [] }
      elsif content_type.start_with?("multipart/form-data")
        boundary = content_type[/boundary=(?:"([^"]+)"|([^;]+))/, 1] || Regexp.last_match(2)
        raise "multipart boundary absent" if boundary.to_s.empty?

        entries = []
        files = []
        body.split("--#{boundary}").each do |part|
          part = part.sub(/\A\r\n/, "").sub(/\r\n\z/, "")
          next if part.empty? || part == "--" || part.start_with?("--\r\n")

          part_headers, bytes = part.split("\r\n\r\n", 2)
          next unless bytes

          bytes = bytes.sub(/\r\n\z/, "").b
          disposition = part_headers[/Content-Disposition:\s*([^\r\n]+)/i, 1].to_s
          name = disposition[/\bname="([^"]+)"/, 1]
          filename = disposition[/\bfilename="([^"]+)"/, 1]
          type = part_headers[/Content-Type:\s*([^\r\n]+)/i, 1].to_s.strip
          if filename
            files << { name: filename, mime: type, byte_length: bytes.bytesize,
                       sha256: Digest::SHA256.hexdigest(bytes) }
          elsif name == "json_request_part"
            entries.concat(Array(JSON.parse(bytes)))
          end
        end
        { content_type: "multipart/form-data", entries: entries, files: files }
      else
        raise "unsupported mock log content type"
      end
    end

    def reason(status)
      { 200 => "OK", 400 => "Bad Request", 404 => "Not Found", 503 => "Service Unavailable" }.fetch(status)
    end
  end

  module_function

  def run
    reject_stale_runtime_environment!
    candidate = File.realpath(ENV.fetch("M4_CANDIDATE"))
    manifest_path = File.realpath(ENV.fetch("M4_CANDIDATE_MANIFEST"))
    gem_root = File.realpath(ENV.fetch("M4_INSTALLED_GEM_ROOT"))
    gem_bin = File.realpath(ENV.fetch("M4_INSTALLED_GEM_BIN"))
    evidence = private_evidence_dir
    manifest = JSON.parse(File.read(manifest_path))
    spec = Gem::Specification.find_by_name("reportportal-cucumber-ruby")
    assert(File.realpath(spec.full_gem_path) == gem_root, "active gem is not the isolated installed package")

    gem spec.name, "=#{spec.version}"
    require "reportportal_cucumber"
    require "cucumber"
    require "reportportal_cucumber/service/spool_store"
    require "reportportal_cucumber/service/spool_replay"
    verify_loaded_sdk!(gem_root, manifest)
    verify_executable!(spec, gem_root, manifest, gem_bin)
    cucumber_version = Gem.loaded_specs.fetch("cucumber").version.to_s
    assert(cucumber_version.start_with?("10."), "installed consumer did not use the final native Cucumber 10 lane")
    cli = File.join(gem_bin, "reportportal-spool")
    assert(File.executable?(cli), "installed reportportal-spool executable is missing")

    work = File.join(evidence, "consumer-work")
    Dir.mkdir(work, 0o700)
    File.chmod(0o700, work)
    spool_dir = File.join(work, "spool")
    FileUtils.mkdir_p(spool_dir, mode: 0o700)
    mock = StatefulMock.new
    receipt = {
      candidate: candidate,
      installed_gem_root: gem_root,
      cucumber_version: cucumber_version,
      loaded_sdk_files: loaded_sdk_files(gem_root),
      executable_sha256: Digest::SHA256.file(File.join(gem_root, "exe/reportportal-spool")).hexdigest,
      mock_endpoint: mock.endpoint,
      spool_dir: spool_dir,
      cli_runs: []
    }

    transaction_id = create_fixture_transaction(mock.endpoint, spool_dir)
    receipt[:transaction] = transaction_id
    verify_transaction_fixture!(spool_dir, transaction_id)

    help = cli_run(cli, ["--help"], mock.endpoint, spool_dir, evidence, "help", api_key: nil)
    assert(help.fetch(:status).zero?, "installed --help did not exit successfully")
    assert(help.fetch(:stdout).include?("--allow-duplicates"), "installed help omitted replay controls")
    receipt[:cli_runs] << sanitized_cli_receipt(help)

    dry_run = cli_run(cli, ["--spool-dir", spool_dir, "--transaction", transaction_id],
                      mock.endpoint, spool_dir, evidence, "dry-run", api_key: nil)
    assert(dry_run.fetch(:status).zero?, "dry-run inspection did not exit successfully")
    dry_summary = parse_summary(dry_run)
    assert(dry_summary.fetch("dry_run") == true, "default CLI invocation was not dry-run")
    assert(mock.requests.none? { |request| request[:method] == "GET" || request[:method] == "POST" },
           "dry-run unexpectedly contacted the mock API")
    receipt[:cli_runs] << sanitized_cli_receipt(dry_run).merge(summary: dry_summary)

    mock.set_item_status("PASSED")
    before_closed = mock.requests.count { |request| request[:method] == "POST" && request[:path].end_with?("/log") }
    closed = cli_run(cli, replay_args(spool_dir, transaction_id, execute: true, allow_duplicates: true),
                     mock.endpoint, spool_dir, evidence, "closed-target", api_key: TEST_TOKEN)
    assert(closed.fetch(:status) == 2, "closed target was not refused")
    assert(closed.fetch(:stderr).include?("Original target is not open"), "closed-target refusal was not explicit")
    after_closed = mock.requests.count { |request| request[:method] == "POST" && request[:path].end_with?("/log") }
    assert(before_closed == after_closed, "closed target refusal sent or retargeted a log")
    receipt[:cli_runs] << sanitized_cli_receipt(closed)

    mock.set_item_status("IN_PROGRESS")
    execution = cli_run(cli, replay_args(spool_dir, transaction_id, execute: true, allow_duplicates: true),
                        mock.endpoint, spool_dir, evidence, "execute-fault", api_key: TEST_TOKEN)
    assert(execution.fetch(:status) == 2, "faulted execute did not retain uncertain work")
    execution_summary = parse_summary(execution)
    assert(execution_summary.fetch("confirmed") == 1, "first JSON log was not checkpoint-confirmed")
    assert(execution_summary.fetch("ambiguous") == 1, "faulted PNG log was not ambiguous")
    receipt[:cli_runs] << sanitized_cli_receipt(execution).merge(summary: execution_summary)

    resume = cli_run(cli, replay_args(spool_dir, transaction_id, execute: true, allow_duplicates: true),
                     mock.endpoint, spool_dir, evidence, "resume", api_key: TEST_TOKEN)
    assert(resume.fetch(:status).zero?, "resume did not finish the remaining transaction")
    resume_summary = parse_summary(resume)
    assert(resume_summary.fetch("confirmed") == 2, "resume did not confirm both entries")
    receipt[:cli_runs] << sanitized_cli_receipt(resume).merge(summary: resume_summary)

    verify_request_sequence!(mock.requests)
    verify_completed_checkpoint!(spool_dir, transaction_id)
    receipt[:mock_requests] = mock.requests
    receipt[:assertions] = {
      dry_run_no_http: true,
      closed_target_no_post: true,
      json_entry_acknowledged_once: true,
      png_entry_retried_only_after_explicit_duplicate_opt_in: true,
      checkpoint_resume_preserved_confirmed_json: true
    }
    write_private_json(File.join(evidence, "installed-consumer-receipt.json"), receipt)
    puts "installed_consumer=PASS evidence=#{evidence} cucumber=#{cucumber_version} loaded_sdk_files=#{receipt[:loaded_sdk_files].length}"
    0
  ensure
    mock&.stop
  end

  def reject_stale_runtime_environment!
    stale = %w[RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_VERSION].select do |key|
      !ENV[key].to_s.empty?
    end
    assert(stale.empty?, "consumer launched with stale Ruby/Bundler environment variables")
    assert(!defined?(Bundler), "Bundler autoloaded in the installed consumer")
  end

  def private_evidence_dir
    root = File.realpath(ENV.fetch("M4_INSTALLED_EVIDENCE_DIR"))
    File.chmod(0o700, root)
    path = File.join(root, "consumer-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}-#{Process.pid}")
    Dir.mkdir(path, 0o700)
    File.chmod(0o700, path)
    path
  end

  def loaded_sdk_files(gem_root)
    prefix = File.join(gem_root, "lib") + File::SEPARATOR
    $LOADED_FEATURES.filter_map do |feature|
      next unless feature.include?("reportportal_cucumber") && File.file?(feature)

      path = File.realpath(feature)
      assert(path.start_with?(prefix), "SDK feature loaded outside installed gem root: #{path}")
      path
    end.uniq.sort
  end

  def verify_loaded_sdk!(gem_root, manifest)
    files = loaded_sdk_files(gem_root)
    assert(files.any? { |path| path.end_with?("/lib/reportportal_cucumber.rb") },
           "installed SDK entrypoint is absent from $LOADED_FEATURES")
    files.each do |path|
      relative = path.delete_prefix(File.join(gem_root, "") )
      expected = manifest.fetch("files")[relative]
      assert(expected, "loaded SDK file is absent from candidate manifest")
      assert(Digest::SHA256.file(path).hexdigest == expected, "loaded SDK file hash differs from candidate")
    end
  end

  def verify_executable!(spec, gem_root, manifest, gem_bin)
    assert(spec.executables.include?("reportportal-spool"), "gemspec omitted reportportal-spool")
    source = File.join(gem_root, "exe/reportportal-spool")
    expected = manifest.fetch("files").fetch("exe/reportportal-spool")
    assert(Digest::SHA256.file(source).hexdigest == expected, "installed executable source hash differs")
    assert(File.executable?(File.join(gem_bin, "reportportal-spool")), "installed executable wrapper is absent")
  end

  def create_fixture_transaction(endpoint, spool_dir)
    config = ReportportalCucumber::Config.new(
      endpoint: endpoint, project: PROJECT, api_key: TEST_TOKEN, spool_dir: spool_dir,
      join: false, retry_attempts: 1, batch_size_logs: 2, batch_max_bytes: 32_768,
      flush_interval: 10, exit_flush_timeout_ms: 1_000
    )
    records = [
      { launch_uuid: LAUNCH_UUID, item_uuid: ITEM_UUID, timestamp: Time.now.utc,
        message: JSON_MESSAGE, level: :info },
      { launch_uuid: LAUNCH_UUID, item_uuid: ITEM_UUID, timestamp: Time.now.utc,
        message: "PNG evidence", level: :info,
        attachment: { name: "m4-installed-screen.png", mime: "image/png", bytes: PNG_BYTES } }
    ]
    payload = ReportportalCucumber::Service::PayloadBuilder.build_log_batch(records)
    store = ReportportalCucumber::Service::SpoolStore.new(config: config)
    id = store.persist(entries: payload.fetch(:entries), files: payload.fetch(:files), outcome: :ambiguous,
                       diagnostics: { "consumer" => "installed-gem" })
    assert(store.transactions.include?(id), "Store did not publish the generated fixture transaction")
    id
  end

  def verify_transaction_fixture!(spool_dir, transaction_id)
    config = ReportportalCucumber::Config.new(endpoint: "http://127.0.0.1", project: PROJECT,
                                               spool_dir: spool_dir, api_key: "")
    transaction = ReportportalCucumber::Service::SpoolStore.new(config: config).load_transaction(id: transaction_id)
    entries = fetch(transaction, :entries)
    files = Array(fetch(transaction, :files))
    assert(entries.length == 2, "fixture transaction did not retain both log entries")
    assert(entries.map { |entry| fetch(entry, "launchUuid") }.uniq == [LAUNCH_UUID],
           "fixture transaction changed original launch ownership")
    assert(entries.map { |entry| fetch(entry, "itemUuid") }.uniq == [ITEM_UUID],
           "fixture transaction changed original item ownership")
    png = files.find { |file| fetch(file, "name") == "m4-installed-screen.png" }
    assert(png, "fixture transaction lost its PNG descriptor")
    path = fetch(png, "path")
    assert(path && File.file?(path), "fixture PNG is not path-backed after loading")
    assert(File.size(path) == PNG_BYTES.bytesize, "fixture PNG byte length changed")
    assert(Digest::SHA256.file(path).hexdigest == Digest::SHA256.hexdigest(PNG_BYTES),
           "fixture PNG byte hash changed")
    manifest = fetch(transaction, :manifest)
    assert(!JSON.generate(manifest).match?(/api[_-]?key|authorization|secret/i),
           "transaction manifest appears to contain credentials")
  end

  def verify_request_sequence!(requests)
    logs = requests.select { |request| request[:method] == "POST" && request[:path].end_with?("/log") }
    assert(logs.length == 3, "expected exactly three replay POSTs (JSON, faulted PNG, resumed PNG)")
    json = logs.find { |request| request[:content_type] == "application/json" }
    pngs = logs.select { |request| request[:content_type] == "multipart/form-data" }
    assert(json && pngs.length == 2, "replay did not use one JSON and two PNG multipart requests")
    json_entry = json.fetch(:entries).fetch(0)
    assert(fetch(json_entry, "message") == JSON_MESSAGE, "JSON log content changed")
    assert(fetch(json_entry, "launchUuid") == LAUNCH_UUID && fetch(json_entry, "itemUuid") == ITEM_UUID,
           "JSON log was retargeted")
    assert(pngs.all? { |request| request.fetch(:entries).length == 1 }, "PNG replay was not per-entry")
    png_entry = pngs.first.fetch(:entries).fetch(0)
    assert(fetch(png_entry, "launchUuid") == LAUNCH_UUID && fetch(png_entry, "itemUuid") == ITEM_UUID,
           "PNG log was retargeted")
    assert(pngs.all? do |request|
      file = request.fetch(:files).fetch(0)
      file.fetch(:byte_length) == PNG_BYTES.bytesize && file.fetch(:sha256) == Digest::SHA256.hexdigest(PNG_BYTES)
    end, "PNG request bytes differ from the persisted attachment")
    assert(logs.map { |request| request.fetch(:status) } == [200, 503, 200],
           "controlled replay fault/acknowledgement sequence changed")
  end

  def verify_completed_checkpoint!(spool_dir, transaction_id)
    config = ReportportalCucumber::Config.new(endpoint: "http://127.0.0.1", project: PROJECT,
                                               spool_dir: spool_dir, api_key: "")
    transaction = ReportportalCucumber::Service::SpoolStore.new(config: config).load_transaction(id: transaction_id)
    states = fetch(fetch(transaction, :checkpoint), :states)
    assert(states.length == 2, "checkpoint entry count changed")
    assert(states.all? { |state| fetch(state, "state") == "confirmed" }, "resume did not confirm both entries")
    ids = states.map { |state| fetch(state, "id") }
    assert(ids == ["ack-json-1", "ack-png-3"], "checkpoint did not retain exact per-entry acknowledgement IDs")
  end

  def replay_args(spool_dir, transaction_id, execute:, allow_duplicates:)
    args = ["--spool-dir", spool_dir, "--transaction", transaction_id, "--timeout", "8"]
    args << "--execute" if execute
    args << "--allow-duplicates" if allow_duplicates
    args
  end

  def cli_run(cli, args, endpoint, spool_dir, evidence, label, api_key:)
    env = ENV.keys.each_with_object({}) do |key, clean|
      clean[key] = nil if key.start_with?("RP_")
    end.merge(
      "RUBYOPT" => nil,
      "RUBYLIB" => nil,
      "BUNDLE_GEMFILE" => nil,
      "BUNDLE_BIN_PATH" => nil,
      "BUNDLER_VERSION" => nil,
      "RP_ENDPOINT" => endpoint,
      "RP_PROJECT" => PROJECT,
      "RP_SPOOL_DIR" => spool_dir,
      "RP_API_KEY" => api_key,
      "RP_HTTP_RETRY_ATTEMPTS" => "1",
      "PATH" => "#{ENV.fetch('M4_INSTALLED_GEM_BIN')}:#{ENV.fetch('PATH', '')}"
    )
    stdout, stderr, status = Open3.capture3(env, cli, *args, chdir: evidence)
    result = { command: ([cli] + args).join(" "), status: status.exitstatus,
               stdout: stdout, stderr: stderr }
    write_private(File.join(evidence, "#{label}.stdout"), stdout)
    write_private(File.join(evidence, "#{label}.stderr"), stderr)
    write_private(File.join(evidence, "#{label}.command"), result.fetch(:command) + "\n")
    result
  end

  def sanitized_cli_receipt(result)
    { command: result.fetch(:command), exit_status: result.fetch(:status),
      stdout: redact(result.fetch(:stdout)), stderr: redact(result.fetch(:stderr)) }
  end

  def parse_summary(result)
    JSON.parse(result.fetch(:stdout).lines.find { |line| line.lstrip.start_with?("{") } || "")
  rescue JSON::ParserError
    raise "installed replay CLI did not emit a JSON receipt"
  end

  def write_private_json(path, value)
    write_private(path, JSON.pretty_generate(value) + "\n")
  end

  def write_private(path, contents)
    File.open(path, "wb", 0o600) { |file| file.write(redact(contents)) }
    File.chmod(0o600, path)
  end

  def redact(contents)
    contents.to_s.gsub(TEST_TOKEN, "[REDACTED]")
  end

  def fetch(hash, key)
    hash[key] || hash[key.to_s] || hash[key.to_sym]
  end

  def assert(condition, message)
    raise "M4 installed consumer: #{message}" unless condition
  end
end

exit(M4InstalledGemConsumer.run) if $PROGRAM_NAME == __FILE__
