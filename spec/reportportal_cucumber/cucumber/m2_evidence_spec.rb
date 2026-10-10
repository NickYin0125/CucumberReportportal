# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "open3"
require "rbconfig"

RSpec.describe ReportportalCucumber::Cucumber::World do
  subject(:world) do
    Class.new { include ReportportalCucumber::Cucumber::World }.new
  end

  after { ReportportalCucumber.current_runtime = nil }

  def formatter_config
    Class.new do
      attr_reader :handlers

      def initialize
        @handlers = {}
      end

      def on_event(name, &block)
        handlers[name] = block
      end

      def include(_mod); end
    end.new
  end

  it "captures opaque action targets and routes evidence to the failed step, not scenario or hook" do
    runtime = double("runtime")
    ReportportalCucumber.current_runtime = runtime
    step_target = Object.new.freeze
    hook_target = Object.new.freeze
    allow(runtime).to receive(:rp_capture_target).and_return(step_target, hook_target)
    expect(runtime).to receive(:rp_evidence).with(
      action: "missing locator", error: an_instance_of(RuntimeError), url: nil,
      details: nil, artifacts: [], target: step_target
    ).and_return(true)

    captured = world.rp_capture_target
    expect(captured).to equal(step_target)
    error = RuntimeError.new("locator missing")
    expect(world.rp_evidence(action: "missing locator", error: error, target: captured)).to be(true)
    expect(world.rp_capture_target).to equal(hook_target)
  end

  it "returns false for disabled, closed, and foreign handles without retargeting" do
    runtime = double("runtime")
    ReportportalCucumber.current_runtime = runtime
    target = Object.new.freeze
    expect(runtime).to receive(:rp_evidence).with(hash_including(target: target)).and_return(false, false, false)

    3.times do
      expect(world.rp_evidence(action: "failure", error: RuntimeError.new("original"), target: target)).to be(false)
    end
  end

  it "rejects an explicit false target while a later step is open without enqueueing" do
    config = ReportportalCucumber::Config.new(endpoint: "https://m2-false-target.example.test",
      project: "demo", api_key: "token", join: false)
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
    formatter = ReportportalCucumber::Cucumber::Formatter.new(formatter_config)
    context = formatter.runtime_context
    next_target = Object.new.freeze
    allow(formatter).to receive(:reporting_enabled?).and_return(true)
    allow(formatter).to receive(:capture_target).and_return(next_target)
    allow(context).to receive(:acquire_capture_target).with(false, launch_uuid: nil).and_return(nil)
    expect(formatter).not_to receive(:capture_target)
    expect(context).not_to receive(:acquire_capture_target).with(next_target, launch_uuid: nil)
    expect(formatter.instance_variable_get(:@log_buffer)).not_to receive(:emit_log)

    expect(formatter.rp_evidence(action: "false adapter sentinel", error: RuntimeError.new("synthetic"),
                                 target: false)).to be(false)
  ensure
    formatter&.instance_variable_get(:@log_buffer)&.shutdown(timeout: 2)
    ReportportalCucumber.current_runtime = nil
  end

  it "preserves path-backed artifacts and enforces the in-memory bytes ceiling" do
    runtime = double("runtime")
    ReportportalCucumber.current_runtime = runtime
    target = Object.new.freeze
    path = File.join(Dir.tmpdir, "caller-owned-large-evidence.bin")
    expect(runtime).to receive(:rp_evidence).with(
      hash_including(artifacts: [{ path: path, name: "large.bin" }], target: target)
    ).and_return(true)
    expect(runtime).to receive(:rp_evidence).with(
      hash_including(artifacts: [{ bytes: "x" * (1024 * 1024 + 1) }], target: target)
    ).and_return(false)

    expect(world.rp_evidence(action: "failure", error: RuntimeError.new("bad"),
                             artifacts: [{ path: path, name: "large.bin" }], target: target)).to be(true)
    expect(world.rp_evidence(action: "failure", error: RuntimeError.new("bad"),
                             artifacts: [{ bytes: "x" * (1024 * 1024 + 1) }], target: target)).to be(false)
  end

  it "does not replace the original exception when evidence reporting fails" do
    original = RuntimeError.new("original browser failure")
    runtime = double("runtime")
    ReportportalCucumber.current_runtime = runtime
    allow(runtime).to receive(:rp_evidence).and_raise("reporting failure")

    expect do
      begin
        raise original
      rescue => error
        world.rp_evidence(action: "click", error: error)
        raise
      end
    end.to raise_error { |raised| expect(raised).to equal(original) }
  end

  it "keeps manual-step evidence within the manual action target" do
    runtime = double("runtime")
    ReportportalCucumber.current_runtime = runtime
    target = Object.new.freeze
    expect(runtime).to receive(:with_manual_step).with("manual check").and_yield
    expect(runtime).to receive(:rp_capture_target).and_return(target)
    expect(runtime).to receive(:rp_evidence).with(hash_including(target: target)).and_return(true)

    world.rp_step("manual check") do
      expect(world.rp_evidence(action: "check", error: RuntimeError.new("bad"),
                               target: world.rp_capture_target)).to be(true)
    end
  end

  it "routes step evidence by UUID before finish, rejects late handles, and isolates retry targets" do
    config = ReportportalCucumber::Config.new(
      endpoint: "https://m2-evidence.example.test", project: "demo", api_key: "test-token",
      launch: "M2 evidence", batch_size_logs: 1, flush_interval: 0.05,
      retry_attempts: 1, join: false, exit_flush_timeout_ms: 2_000
    )
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
    calls = []
    item_counter = 0
    stub_request(:post, "https://m2-evidence.example.test/api/v1/demo/launch")
      .to_return(status: 200, body: '{"id":"launch-m2"}')
    stub_request(:post, %r{\Ahttps://m2-evidence\.example\.test/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      item_counter += 1
      body = JSON.parse(request.body)
      uuid = "m2-item-#{item_counter}"
      calls << [:start_item, uuid, body]
      { status: 200, body: { id: uuid }.to_json }
    end
    stub_request(:post, "https://m2-evidence.example.test/api/v1/demo/log").to_return do |request|
      calls << [:log, request.body]
      { status: 200, body: '{"responses":[{"message":"ok"}]}' }
    end
    stub_request(:put, %r{\Ahttps://m2-evidence\.example\.test/api/v1/demo/item/.*\z}).to_return do |request|
      calls << [:finish_item, request.uri.path, request.body]
      { status: 200, body: '{"message":"ok"}' }
    end
    stub_request(:put, "https://m2-evidence.example.test/api/v1/demo/launch/launch-m2/finish")
      .to_return(status: 200, body: '{"message":"ok"}')

    formatter = ReportportalCucumber::Cucumber::Formatter.new(formatter_config)
    world_class = Class.new { include ReportportalCucumber::Cucumber::World }
    world = world_class.new
    formatter.ingest_event("type" => "test_run_started", "timestamp" => "2026-09-25T00:00:00Z")
    formatter.ingest_event("type" => "test_suite_started", "feature_uri" => "features/m2.feature")

    start_attempt = lambda do |step_id|
      formatter.ingest_event("type" => "test_case_started", "feature_uri" => "features/m2.feature",
                             "scenario_name" => "retryable evidence", "scenario_line" => 8)
      formatter.ingest_event("type" => "test_step_started", "step_id" => step_id,
                             "step_text" => "When the browser action fails", "hook" => false)
      world.rp_capture_target
    end

    first_target = start_attempt.call("step-first")
    Dir.mktmpdir("m2-evidence-") do |directory|
      image_path = File.join(directory, "failure.png")
      File.binwrite(image_path, "png-data")
      log_calls_before_rejection = calls.count { |type, _| type == :log }
      expect(world.rp_evidence(action: "oversized bytes", error: RuntimeError.new("too large"),
                               artifacts: [{ bytes: "x" * (1_048_577), name: "too-large.bin" }],
                               target: first_target)).to be(false)
      expect(calls.count { |type, _| type == :log }).to eq(log_calls_before_rejection)
      expect(File).not_to receive(:binread).with(image_path)
      expect(world.rp_evidence(
        action: "find submit button", error: RuntimeError.new("not found"),
        details: "caller supplied diagnostic", artifacts: [
          { path: image_path, name: "failure.png", mime: "image/png" },
          { bytes: "console excerpt", name: "console.txt", mime: "text/plain" }
        ], target: first_target
      )).to be(true)
      expect(formatter.instance_variable_get(:@log_buffer).flush(timeout: 2)).to be(true)
    end
    formatter.ingest_event("type" => "test_step_finished", "step_id" => "step-first", "status" => "failed")
    first_step = calls.find { |type, _uuid, body| type == :start_item && body["hasStats"] == false && body["name"].include?("browser action") }
    first_uuid = first_step.fetch(1)
    first_finish_index = calls.index { |type, path, _body| type == :finish_item && path.end_with?(first_uuid) }
    expect(first_finish_index).not_to be_nil
    log_requests = calls.select { |type, _body| type == :log }
    summary_request = log_requests.find { |_type, body| body.include?("find submit button") }
    attachment_request = log_requests.find do |_type, body|
      body.include?("failure.png") && body.include?("image/png")
    end
    expect(summary_request).not_to be_nil
    expect(attachment_request).not_to be_nil
    expect(attachment_request).not_to equal(summary_request)
    expect(summary_request.last).to include(first_uuid, "caller supplied diagnostic")
    expect(attachment_request.last).to include(first_uuid, "image/png", "failure.png")
    summary_log_index = calls.index { |type, body| type == :log && body.include?("find submit button") }
    attachment_log_index = calls.index do |type, body|
      type == :log && body.include?("failure.png") && body.include?("image/png")
    end
    expect(summary_log_index).to be < first_finish_index
    expect(attachment_log_index).to be < first_finish_index

    formatter.ingest_event("type" => "test_step_started", "step_id" => "after-1",
                           "step_text" => "close browser", "hook_type" => "after")
    late_log_count = calls.count { |type, body| type == :log && body.include?("late evidence") }
    expect(world.rp_evidence(action: "late evidence", error: RuntimeError.new("late"), target: first_target)).to be(false)
    expect(calls.count { |type, body| type == :log && body.include?("late evidence") }).to eq(late_log_count)
    formatter.ingest_event("type" => "test_step_finished", "step_id" => "after-1", "status" => "passed")
    formatter.ingest_event("type" => "test_case_finished", "status" => "failed")

    second_target = start_attempt.call("step-retry")
    expect(second_target).not_to equal(first_target)
    expect(world.rp_evidence(action: "retry evidence", error: RuntimeError.new("retry"), target: second_target)).to be(true)
    formatter.ingest_event("type" => "test_step_finished", "step_id" => "step-retry", "status" => "failed")
    second_step = calls.reverse.find { |type, _uuid, body| type == :start_item && body["hasStats"] == false && body["name"].include?("browser action") }
    expect(second_step.fetch(1)).not_to eq(first_uuid)
  ensure
    if formatter
      formatter.send(:finalize_reporting, status: "failed", end_time: Time.now)
      formatter.instance_variable_get(:@log_buffer).shutdown(timeout: 2)
    end
  end

  it "targets a real failing hook and manual item rather than their scenario" do
    config = ReportportalCucumber::Config.new(endpoint: "https://m2-actions.example.test", project: "demo",
      api_key: "token", launch: "Actions", batch_size_logs: 1, retry_attempts: 1, join: false)
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
    item_counter = 0
    requests = []
    stub_request(:post, "https://m2-actions.example.test/api/v1/demo/launch")
      .to_return(status: 200, body: '{"id":"actions-launch"}')
    stub_request(:post, %r{\Ahttps://m2-actions\.example\.test/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      item_counter += 1
      body = JSON.parse(request.body)
      requests << [:start, "action-item-#{item_counter}", body]
      { status: 200, body: { id: "action-item-#{item_counter}" }.to_json }
    end
    stub_request(:post, "https://m2-actions.example.test/api/v1/demo/log").to_return do |request|
      requests << [:log, request.body]
      { status: 200, body: '{"responses":[{"message":"ok"}]}' }
    end
    stub_request(:put, %r{\Ahttps://m2-actions\.example\.test/api/v1/demo/item/.*\z}).to_return do |request|
      requests << [:finish, request.uri.path]
      { status: 200, body: '{"message":"ok"}' }
    end
    stub_request(:put, "https://m2-actions.example.test/api/v1/demo/launch/actions-launch/finish")
      .to_return(status: 200, body: '{"message":"ok"}')

    formatter = ReportportalCucumber::Cucumber::Formatter.new(formatter_config)
    formatter.ingest_event("type" => "test_run_started")
    formatter.ingest_event("type" => "test_suite_started", "feature_uri" => "features/actions.feature")
    formatter.ingest_event("type" => "test_case_started", "feature_uri" => "features/actions.feature",
                           "scenario_name" => "hook and manual", "scenario_line" => 4)
    formatter.ingest_event("type" => "test_step_started", "step_id" => "before", "step_text" => "setup",
                           "hook_type" => "before")
    hook_target = world.rp_capture_target
    expect(world.rp_evidence(action: "hook setup", error: RuntimeError.new("bad"), target: hook_target)).to be(true)
    formatter.ingest_event("type" => "test_step_finished", "step_id" => "before", "status" => "failed")
    hook_item = requests.find { |kind, _uuid, body| kind == :start && body["type"] == "BEFORE_METHOD" }
    expect(requests.find { |kind, body| kind == :log && body.include?("hook setup") }.last).to include(hook_item.fetch(1))

    world.rp_step("manual evidence") do
      manual_target = world.rp_capture_target
      expect(world.rp_evidence(action: "manual check", error: RuntimeError.new("bad"), target: manual_target)).to be(true)
    end
    manual_item = requests.find { |kind, _uuid, body| kind == :start && body["name"] == "manual evidence" }
    manual_log = requests.find { |kind, body| kind == :log && body.include?("manual check") }
    expect(manual_log.last).to include(manual_item.fetch(1))
    expect(requests.index(manual_log)).to be < requests.index { |kind, path| kind == :finish && path.end_with?(manual_item.fetch(1)) }
  ensure
    if formatter
      formatter.send(:finalize_reporting, status: "failed", end_time: Time.now)
      formatter.instance_variable_get(:@log_buffer).shutdown(timeout: 2)
    end
  end

  it "rejects a foreign explicit handle but resolves its owner when the helper thread has no runtime" do
    configs = %w[a b].map do |suffix|
      ReportportalCucumber::Config.new(endpoint: "https://m2-foreign-#{suffix}.example.test", project: "demo",
        api_key: "token", launch: "Foreign #{suffix}", batch_size_logs: 1, retry_attempts: 1, join: false)
    end
    allow(ReportportalCucumber::Config).to receive(:load).and_return(*configs)
    logs = Queue.new
    item_counter = 0
    stub_request(:post, %r{\Ahttps://m2-foreign-[ab]\.example\.test/api/v1/demo/launch\z}).to_return do |request|
      suffix = request.uri.host[/m2-foreign-([ab])/, 1]
      { status: 200, body: { id: "foreign-launch-#{suffix}" }.to_json }
    end
    stub_request(:post, %r{\Ahttps://m2-foreign-[ab]\.example\.test/api/v1/demo/item(?:/.*)?\z}).to_return do |_request|
      item_counter += 1
      { status: 200, body: { id: "foreign-item-#{item_counter}" }.to_json }
    end
    stub_request(:post, %r{\Ahttps://m2-foreign-[ab]\.example\.test/api/v1/demo/log\z}).to_return do |request|
      logs << [request.uri.host, request.body]
      { status: 200, body: '{"responses":[{"message":"ok"}]}' }
    end
    stub_request(:put, %r{\Ahttps://m2-foreign-[ab]\.example\.test/api/v1/demo/item/.*\z})
      .to_return(status: 200, body: '{"message":"ok"}')
    %w[a b].each do |suffix|
      stub_request(:put, "https://m2-foreign-#{suffix}.example.test/api/v1/demo/launch/foreign-launch-#{suffix}/finish")
        .to_return(status: 200, body: '{"message":"ok"}')
    end

    formatter_a = ReportportalCucumber::Cucumber::Formatter.new(formatter_config)
    formatter_a.ingest_event("type" => "test_run_started")
    formatter_a.ingest_event("type" => "test_suite_started", "feature_uri" => "features/foreign.feature")
    formatter_a.ingest_event("type" => "test_case_started", "feature_uri" => "features/foreign.feature",
                             "scenario_name" => "owner A", "scenario_line" => 1)
    formatter_a.ingest_event("type" => "test_step_started", "step_id" => "owner-a-step", "step_text" => "A action")
    target_a = world.rp_capture_target

    formatter_b = ReportportalCucumber::Cucumber::Formatter.new(formatter_config)
    formatter_b.ingest_event("type" => "test_run_started")
    formatter_b.ingest_event("type" => "test_suite_started", "feature_uri" => "features/foreign.feature")
    formatter_b.ingest_event("type" => "test_case_started", "feature_uri" => "features/foreign.feature",
                             "scenario_name" => "owner B", "scenario_line" => 2)
    formatter_b.ingest_event("type" => "test_step_started", "step_id" => "owner-b-step", "step_text" => "B action")

    expect(world.rp_evidence(action: "foreign rejected", error: RuntimeError.new("wrong owner"), target: target_a)).to be(false)
    expect(logs.empty?).to be(true)

    worker_result = Queue.new
    worker = Thread.new do
      ReportportalCucumber.current_runtime = nil
      worker_result << world.rp_evidence(action: "owner A accepted", error: RuntimeError.new("worker"), target: target_a)
    end
    expect(worker_result.pop).to be(true)
    worker.join
    expect(formatter_a.instance_variable_get(:@log_buffer).flush(timeout: 2)).to be(true)
    owner_log = logs.pop
    expect(owner_log.first).to eq("m2-foreign-a.example.test")
    expect(owner_log.last).to include("owner A accepted", "foreign-item-3")
    expect(logs.empty?).to be(true)
  ensure
    [formatter_b, formatter_a].compact.each do |formatter|
      formatter.send(:finalize_reporting, status: "failed", end_time: Time.now)
      formatter.instance_variable_get(:@log_buffer).shutdown(timeout: 2)
    end
    ReportportalCucumber.current_runtime = nil
  end

  it "isolates evidence UUIDs for two concurrent scenarios on one formatter" do
    config = ReportportalCucumber::Config.new(endpoint: "https://m2-concurrent.example.test", project: "demo",
      api_key: "token", launch: "Concurrent evidence", batch_size_logs: 1,
      retry_attempts: 1, join: false, exit_flush_timeout_ms: 2_000)
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
    events = []
    events_mutex = Mutex.new
    item_counter = 0
    item_mutex = Mutex.new
    stub_request(:post, "https://m2-concurrent.example.test/api/v1/demo/launch")
      .to_return(status: 200, body: '{"id":"concurrent-launch"}')
    stub_request(:post, %r{\Ahttps://m2-concurrent\.example\.test/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      body = JSON.parse(request.body)
      uuid = item_mutex.synchronize { item_counter += 1; "concurrent-item-#{item_counter}" }
      events_mutex.synchronize { events << [:start, uuid, body] }
      { status: 200, body: { id: uuid }.to_json }
    end
    stub_request(:post, "https://m2-concurrent.example.test/api/v1/demo/log").to_return do |request|
      events_mutex.synchronize { events << [:log, request.body] }
      { status: 200, body: '{"responses":[{"message":"ok"}]}' }
    end
    stub_request(:put, %r{\Ahttps://m2-concurrent\.example\.test/api/v1/demo/item/.*\z}).to_return do |request|
      events_mutex.synchronize { events << [:finish, request.uri.path] }
      { status: 200, body: '{"message":"ok"}' }
    end
    stub_request(:put, "https://m2-concurrent.example.test/api/v1/demo/launch/concurrent-launch/finish")
      .to_return(status: 200, body: '{"message":"ok"}')

    formatter = ReportportalCucumber::Cucumber::Formatter.new(formatter_config)
    formatter.ingest_event("type" => "test_run_started")
    formatter.ingest_event("type" => "test_suite_started", "feature_uri" => "features/concurrent.feature")
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    workers = %w[alpha beta].map do |name|
      Thread.new do
        ReportportalCucumber.current_runtime = formatter
        step_id = "concurrent-#{name}"
        formatter.ingest_event("type" => "test_case_started", "feature_uri" => "features/concurrent.feature",
          "scenario_name" => "scenario #{name}", "scenario_line" => name == "alpha" ? 10 : 20)
        formatter.ingest_event("type" => "test_step_started", "step_id" => step_id,
          "step_text" => "When #{name} action runs")
        target = world.rp_capture_target
        ready << [name, step_id, target]
        release.pop
        reported = world.rp_evidence(action: "evidence #{name}", error: RuntimeError.new(name), target: target)
        formatter.ingest_event("type" => "test_step_finished", "step_id" => step_id, "status" => "failed")
        formatter.ingest_event("type" => "test_case_finished", "status" => "failed")
        results << [name, target, reported]
      ensure
        ReportportalCucumber.current_runtime = nil
      end
    end

    open = 2.times.map { ready.pop }
    expect(open.map(&:last).uniq.length).to eq(2)
    2.times { release << true }
    workers.each(&:value)
    reported = 2.times.map { results.pop }.to_h { |name, target, accepted| [name, [target, accepted]] }
    expect(reported.values.map(&:first).uniq.length).to eq(2)
    expect(reported.values.map(&:last)).to eq([true, true])

    step_uuids = events.filter_map do |kind, uuid, body|
      [body["name"], uuid] if kind == :start && body["hasStats"] == false && body["name"].include?("action runs")
    end.to_h
    expect(step_uuids.keys.length).to eq(2)
    log_records = events.filter_map do |kind, body|
      next unless kind == :log

      json_part = body[/Content-Type: application\/json\r?\n\r?\n(.*?)\r?\n--/m, 1]
      payload = json_part || body
      parsed = JSON.parse(payload)
      expect(parsed).to satisfy { |value| value.is_a?(Hash) || value.is_a?(Array) }
      parsed
    end.flatten
    %w[alpha beta].each do |name|
      record = log_records.find { |entry| entry.fetch("message").include?("evidence #{name}") }
      item_uuid = record.fetch("itemUuid")
      own_step_uuid = step_uuids.find { |step_name, _uuid| step_name.include?(name) }.last
      expect(item_uuid).to eq(own_step_uuid)
      other_name = name == "alpha" ? "beta" : "alpha"
      other_step_uuid = step_uuids.find { |step_name, _uuid| step_name.include?(other_name) }.last
      expect(item_uuid).not_to eq(other_step_uuid)
      log_index = events.index { |kind, body| kind == :log && body.include?("evidence #{name}") }
      finish_index = events.index { |kind, path| kind == :finish && path.end_with?(own_step_uuid) }
      expect(log_index).to be < finish_index
    end
    expect(log_records.count { |entry| entry.fetch("message").include?("evidence ") }).to eq(2)
  ensure
    workers&.each { |thread| release << true if thread.alive? }
    workers&.each(&:join)
    if formatter
      formatter.send(:finalize_reporting, status: "failed", end_time: Time.now)
      formatter.instance_variable_get(:@log_buffer).shutdown(timeout: 2)
    end
  end

  it "keeps secrets redacted when failed RP delivery is written to the spool" do
    Dir.mktmpdir("m2-evidence-spool-") do |directory|
      spool_dir = File.join(directory, "spool")
      config = ReportportalCucumber::Config.new(endpoint: "https://m2-spool.example.test", project: "demo",
        api_key: "token", launch: "Spool evidence", batch_size_logs: 1, flush_interval: 0.01,
        retry_attempts: 1, join: false, spool_dir: spool_dir, exit_flush_timeout_ms: 2_000)
      allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
      stub_request(:post, "https://m2-spool.example.test/api/v1/demo/launch")
        .to_return(status: 200, body: '{"id":"spool-launch"}')
      item_id = 0
      stub_request(:post, %r{\Ahttps://m2-spool\.example\.test/api/v1/demo/item(?:/.*)?\z}).to_return do |_request|
        item_id += 1
        { status: 200, body: { id: "spool-item-#{item_id}" }.to_json }
      end
      stub_request(:post, "https://m2-spool.example.test/api/v1/demo/log")
        .to_return(status: 503, body: "temporary reporting failure")
      stub_request(:put, %r{\Ahttps://m2-spool\.example\.test/api/v1/demo/item/.*\z})
        .to_return(status: 200, body: '{"message":"ok"}')
      stub_request(:put, "https://m2-spool.example.test/api/v1/demo/launch/spool-launch/finish")
        .to_return(status: 200, body: '{"message":"ok"}')

      formatter = ReportportalCucumber::Cucumber::Formatter.new(formatter_config)
      formatter.ingest_event("type" => "test_run_started")
      formatter.ingest_event("type" => "test_suite_started", "feature_uri" => "features/spool.feature")
      formatter.ingest_event("type" => "test_case_started", "feature_uri" => "features/spool.feature",
                             "scenario_name" => "spooled evidence", "scenario_line" => 5)
      formatter.ingest_event("type" => "test_step_started", "step_id" => "spool-step", "step_text" => "send evidence")
      truncated_canary = "CANARY_M2_SPOOL_" + ("s" * 17_000)
      error_canary = "CANARY_M2_ERROR_" + ("e" * 300)
      expect(world.rp_evidence(
        action: "request failed", error: RuntimeError.new(JSON.generate(password: error_canary)),
        url: "https://alice:url-secret@example.test/path?token=query-secret",
        details: JSON.generate(password: truncated_canary), target: world.rp_capture_target
      )).to be(true)
      expect(formatter.instance_variable_get(:@log_buffer).flush(timeout: 3)).to be(true)

      spool_files = Dir[File.join(spool_dir, "*.ndjson")]
      expect(spool_files).not_to be_empty
      spool_text = spool_files.flat_map { |path| File.readlines(path, chomp: true) }.join("\n")
      expect(spool_text).to include("[REDACTED]")
      expect(spool_text).not_to include("alice", "url-secret", "query-secret", "CANARY_M2_")
    ensure
      if formatter
        formatter.send(:finalize_reporting, status: "failed", end_time: Time.now)
        formatter.instance_variable_get(:@log_buffer).shutdown(timeout: 2)
      end
    end
  end

  it "integrates assertion and evidence through Cucumber once on the active step" do
    Dir.mktmpdir("m2-cucumber-integration-") do |directory|
      feature_dir = File.join(directory, "features")
      support_dir = File.join(feature_dir, "support")
      FileUtils.mkdir_p(support_dir)
      result_path = File.join(directory, "result.json")
      messages_path = File.join(directory, "messages.ndjson")
      steps_path = File.join(support_dir, "m2_steps.rb")
      File.write(File.join(feature_dir, "m2.feature"), <<~FEATURE)
        Feature: M2 assertion and evidence

          Scenario: both diagnostics belong to one step
            When I report M2 assertion and evidence
      FEATURE
      File.write(steps_path, <<~RUBY)
        Before { AppLog.bind(self, color: false) }
        After { AppLog.clear! }

        When("I report M2 assertion and evidence") do
          AppLog.assertion(name: "M2 unique assertion", expected: "ready", actual: "ready", passed: true,
            details: JSON.generate(password: "CANARY_M2_NATIVE_" + ("n" * 17_000)))
          rp_evidence(
            action: "M2 unique evidence action",
            error: RuntimeError.new(JSON.generate(password: "CANARY_M2_ERROR_" + ("r" * 300))),
            url: "https://user:url-secret@example.test/?token=query-secret",
            details: JSON.generate(password: "CANARY_M2_RP_" + ("p" * 17_000)),
            target: rp_capture_target
          )
        end
      RUBY
      runner_path = File.join(directory, "run_cucumber.rb")
      mock_helper = File.expand_path("../../support/rp_mock_server.rb", __dir__)
      library_path = File.expand_path("../../../lib/reportportal_cucumber.rb", __dir__)
      File.write(runner_path, <<~RUBY)
        require "json"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require #{mock_helper.inspect}
        require "cucumber/cli/main"

        class M2IntegrationKernel
          def exit(code = 0) = throw(:cucumber_exit, code)
          def exit!(code = 0) = throw(:cucumber_exit, code)
        end

        WebMock.enable!
        WebMock.disable_net_connect!
        endpoint = ENV.fetch("RP_ENDPOINT")
        mock = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
        feature_dir, steps_path, result_path, messages_path = ARGV
        stdout = StringIO.new
        stderr = StringIO.new
        args = [
          "--require", #{library_path.inspect},
          "--require", steps_path,
          "--format", "ReportPortal::Cucumber::Formatter",
          "--format", "message",
          "--out", messages_path,
          feature_dir
        ]
        status = catch(:cucumber_exit) do
          Cucumber::Cli::Main.new(args, stdout, stderr, M2IntegrationKernel.new).execute!
        end
        File.write(result_path, JSON.generate(
          status: status || 0, stdout: stdout.string, stderr: stderr.string,
          logs: mock.logs, item_requests: mock.item_requests
        ))
      RUBY

      endpoint = "https://m2-cucumber-child.example.test"
      stdout, stderr, process_status = Open3.capture3(
        { "RP_ENDPOINT" => endpoint, "RP_PROJECT" => "demo", "RP_API_KEY" => "test-token",
          "RP_LAUNCH" => "M2 Cucumber integration", "RP_CLIENT_JOIN" => "false",
          "RP_BATCH_SIZE_LOGS" => "1", "RP_HTTP_RETRY_ATTEMPTS" => "1" },
        RbConfig.ruby, "-I#{File.expand_path("../../../lib", __dir__)}", runner_path,
        feature_dir, steps_path, result_path, messages_path,
        chdir: File.expand_path("../../..", __dir__)
      )
      expect(process_status.success?).to be(true), "Cucumber subprocess failed:\n#{stderr}"

      result = JSON.parse(File.read(result_path))
      expect(result.fetch("status")).to eq(0), "Cucumber failed: #{result.inspect}"
      step_request = result.fetch("item_requests").find do |item|
        body = item.fetch("body")
        body["type"] == "STEP" && body["hasStats"] == false && body["name"].include?("I report M2 assertion")
      end
      expect(step_request).not_to be_nil
      step_uuid = step_request.fetch("responseUuid")
      logs = result.fetch("logs")
      assertion_logs = logs.select { |entry| entry.fetch("message").include?("M2 unique assertion") }
      evidence_logs = logs.select { |entry| entry.fetch("message").include?("M2 unique evidence action") }
      expect(assertion_logs.length).to eq(1)
      expect(assertion_logs.first).to include("itemUuid" => step_uuid)
      expect(evidence_logs.length).to eq(1)
      expect(evidence_logs.first).to include("itemUuid" => step_uuid, "level" => "error")

      native = File.readlines(messages_path, chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }
      assertion_attachments = native.filter_map do |envelope|
        attachment = envelope["attachment"]
        next unless attachment

        body = attachment.fetch("body", "")
        text = attachment["contentEncoding"] == "BASE64" ? Base64.decode64(body) : body
        { text: text, test_step_id: attachment["testStepId"] } if text.include?("M2 unique assertion")
      end
      expect(assertion_attachments.length).to eq(1)
      step_started = native.find do |envelope|
        envelope.dig("testStepStarted", "testStepId") == assertion_attachments.first.fetch(:test_step_id)
      end
      expect(step_started).not_to be_nil
      expect(assertion_attachments.first.fetch(:test_step_id)).not_to be_empty
      expect(stdout + stderr + result.fetch("stdout") + result.fetch("stderr")).not_to include(
        "url-secret", "query-secret", "CANARY_M2_"
      )
      expect(messages_path && File.read(messages_path)).not_to include("CANARY_M2_")
      expect(logs.map { |entry| entry.fetch("message") }.join).not_to include("CANARY_M2_")
    end
  end

  it "serializes a writer racing target closure without placing late evidence after finish" do
    config = ReportportalCucumber::Config.new(endpoint: "https://m2-race.example.test", project: "demo",
      api_key: "token", launch: "Race", batch_size_logs: 1, retry_attempts: 1, join: false)
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
    calls = []
    item_counter = 0
    stub_request(:post, "https://m2-race.example.test/api/v1/demo/launch")
      .to_return(status: 200, body: '{"id":"race-launch"}')
    stub_request(:post, %r{\Ahttps://m2-race\.example\.test/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      item_counter += 1
      { status: 200, body: { id: "race-#{item_counter}" }.to_json }
    end
    stub_request(:post, "https://m2-race.example.test/api/v1/demo/log").to_return do |request|
      calls << [:log, request.body]
      { status: 200, body: '{"responses":[{"message":"ok"}]}' }
    end
    stub_request(:put, %r{\Ahttps://m2-race\.example\.test/api/v1/demo/item/.*\z}).to_return do |request|
      calls << [:finish, request.uri.path]
      { status: 200, body: '{"message":"ok"}' }
    end
    stub_request(:put, "https://m2-race.example.test/api/v1/demo/launch/race-launch/finish")
      .to_return(status: 200, body: '{"message":"ok"}')

    formatter = ReportportalCucumber::Cucumber::Formatter.new(formatter_config)
    formatter.ingest_event("type" => "test_run_started")
    formatter.ingest_event("type" => "test_suite_started", "feature_uri" => "features/race.feature")
    formatter.ingest_event("type" => "test_case_started", "feature_uri" => "features/race.feature",
                           "scenario_name" => "close race", "scenario_line" => 2)
    formatter.ingest_event("type" => "test_step_started", "step_id" => "race-step", "step_text" => "race")
    target = world.rp_capture_target
    queued = Queue.new
    continue_writer = Queue.new
    target_closed = Queue.new
    result = Queue.new
    writer = Thread.new do
      queued << true
      continue_writer.pop
      result << world.rp_evidence(action: "accepted racing write", error: RuntimeError.new("first"), target: target)
      target_closed.pop
      result << world.rp_evidence(action: "rejected racing write", error: RuntimeError.new("late"), target: target)
    end
    queued.pop
    continue_writer << true
    expect(result.pop).to be(true)
    formatter.ingest_event("type" => "test_step_finished", "step_id" => "race-step", "status" => "failed")
    target_closed << true
    expect(result.pop).to be(false)
    writer.join

    accepted_index = calls.index { |kind, body| kind == :log && body.include?("accepted racing write") }
    finish_index = calls.index { |kind, path| kind == :finish && path.end_with?("race-3") }
    expect(accepted_index).not_to be_nil
    expect(finish_index).not_to be_nil
    expect(accepted_index).to be < finish_index
    expect(calls.none? { |kind, body| kind == :log && body.include?("rejected racing write") }).to be(true)
  ensure
    if formatter
      formatter.send(:finalize_reporting, status: "failed", end_time: Time.now)
      formatter.instance_variable_get(:@log_buffer).shutdown(timeout: 2)
    end
  end

  describe ReportportalCucumber::Runtime::Context do
    it "holds an acquired writer lease until release and rejects acquisition after close" do
      context = described_class.new
      item = described_class::ItemHandle.new(uuid: "leased-item", name: "leased", kind: :step,
        parent_uuid: "scenario", type: "STEP", has_stats: false, metadata: {})
      target = context.register_capture_target(item, launch_uuid: "lease-launch")
      expect(context.acquire_capture_target(target, launch_uuid: "lease-launch")).to equal(item)

      condition = context.instance_variable_get(:@capture_target_condition)
      original_wait = condition.method(:wait)
      close_waiting = Queue.new
      allow(condition).to receive(:wait) do |mutex|
        close_waiting << true
        original_wait.call(mutex)
      end
      close_finished = Queue.new
      close_thread = Thread.new do
        context.close_capture_target(target)
        close_finished << true
      end

      close_waiting.pop
      expect { close_finished.pop(true) }.to raise_error(ThreadError)
      context.release_capture_target(target)
      close_finished.pop
      close_thread.join
      expect(context.acquire_capture_target(target, launch_uuid: "lease-launch")).to be_nil
    ensure
      context&.release_capture_target(target)
      close_thread&.join
    end

    it "cancels a held writer on bounded close and rejects publication after finish" do
      context = described_class.new
      item = described_class::ItemHandle.new(uuid: "cancelled-item", name: "cancelled", kind: :step,
        parent_uuid: "scenario", type: "STEP", has_stats: false, metadata: {})
      target = context.register_capture_target(item, launch_uuid: "cancel-launch")
      writer_acquired = Queue.new
      resume_writer = Queue.new
      writer_result = Queue.new
      emitted_logs = Queue.new
      writer = Thread.new do
        leased_item = context.acquire_capture_target(target, launch_uuid: "cancel-launch")
        writer_acquired << leased_item
        resume_writer.pop
        published = context.publish_capture_target(target, launch_uuid: "cancel-launch") do |open_item|
          emitted_logs << [open_item.uuid, "evidence after finish"]
        end
        writer_result << (leased_item && published)
      ensure
        context.release_capture_target(target)
      end

      expect(writer_acquired.pop).to equal(item)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(context.close_capture_target(target, timeout: 0.05)).to be(false)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      expect(elapsed).to be < 0.5
      expect(context.acquire_capture_target(target, launch_uuid: "cancel-launch")).to be_nil
      finish_order = Queue.new
      finish_order << :item_finished

      resume_writer << true
      expect(writer_result.pop).to be(false)
      writer.join
      expect(finish_order.pop).to eq(:item_finished)
      expect(emitted_logs.empty?).to be(true)
    ensure
      resume_writer << true if writer&.alive?
      writer&.join
    end
  end
end
