# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "timeout"

RSpec.describe "AppLog ReportPortal routing" do
  ConfigSpy = Struct.new(:handlers) do
    def on_event(name, &block)
      handlers[name] = block
    end

    def include(_mod); end
  end

  class RoutingWorld
    attr_reader :native_logs

    def initialize(formatter, &before_attach)
      @formatter = formatter
      @before_attach = before_attach
      @native_logs = []
    end

    def log(message)
      @native_logs << message
      @before_attach&.call
      @formatter.attach(message, "text/x.cucumber.log+plain")
    end
  end

  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://rp-routing.example.test",
      project: "demo",
      api_key: "test-token",
      launch: "Routing spec",
      batch_size_logs: 1,
      flush_interval: 0.1,
      retry_attempts: 1,
      join: false
    )
  end

  before do
    @formatters = []
    @mock_server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: config.endpoint).install!
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
    Thread.current[:active_logger] = nil
  end

  after do
    @formatters.each { |formatter| finalize_formatter(formatter) }
    ReportportalCucumber.current_runtime = nil
    Thread.current[:active_logger] = nil
  end

  def build_formatter(start: true)
    formatter = ReportportalCucumber::Cucumber::Formatter.new(ConfigSpy.new({}))
    @formatters << formatter
    start_report_items(formatter) if start
    formatter
  end

  def start_report_items(formatter, suffix: "")
    formatter.ingest_event("type" => "test_run_started", "timestamp" => "2026-09-23T00:00:00Z")
    formatter.ingest_event("type" => "test_suite_started", "feature_uri" => "features/routing.feature")
    formatter.ingest_event(
      "type" => "test_case_started",
      "feature_uri" => "features/routing.feature",
      "scenario_name" => "Routing#{suffix}",
      "scenario_line" => suffix.empty? ? 1 : 2
    )
    formatter.ingest_event("type" => "test_step_started", "step_text" => "emit logs", "step_id" => "routing-step#{suffix}")
  end

  def capture_report_logs(formatter, entries = [])
    buffer = formatter.instance_variable_get(:@log_buffer)
    allow(buffer).to receive(:emit_log).and_wrap_original do |original, **record|
      entries << record
      original.call(**record)
    end
    entries
  end

  def finalize_formatter(formatter)
    buffer = formatter.instance_variable_get(:@log_buffer)
    return unless buffer

    formatter.send(:finalize_reporting, status: "passed", end_time: Time.now)
  ensure
    buffer&.shutdown(timeout: 2)
  end

  it "routes exactly one DEBUG and ERROR record to the active step and keeps native world.log at INFO" do
    formatter = build_formatter
    entries = capture_report_logs(formatter)
    world = RoutingWorld.new(formatter)
    AppLog.bind(world, output: StringIO.new, color: false)

    AppLog.debug("debug evidence", report: true)
    AppLog.error("error evidence", report: true)
    world.log("native world.log evidence")
    formatter.instance_variable_get(:@log_buffer).flush(timeout: 2)

    step_uuid = formatter.runtime_context.current_item_uuid
    routed = entries.select { |entry| entry[:message].include?("evidence") }
    expect(routed.count { |entry| entry[:message].include?("debug evidence") }).to eq(1)
    expect(routed.count { |entry| entry[:message].include?("error evidence") }).to eq(1)
    expect(routed.find { |entry| entry[:message].include?("debug evidence") }).to include(level: :debug, item_uuid: step_uuid)
    expect(routed.find { |entry| entry[:message].include?("error evidence") }).to include(level: :error, item_uuid: step_uuid)
    expect(routed.find { |entry| entry[:message].include?("native world.log evidence") }).to include(level: :info, item_uuid: step_uuid)

    stored = @mock_server.logs.select { |entry| entry["message"].include?("evidence") }
    expect(stored.count { |entry| entry["message"].include?("debug evidence") }).to eq(1)
    expect(stored.count { |entry| entry["message"].include?("error evidence") }).to eq(1)
    expect(stored.find { |entry| entry["message"].include?("debug evidence") }).to include("level" => "debug", "itemUuid" => step_uuid)
    expect(stored.find { |entry| entry["message"].include?("error evidence") }).to include("level" => "error", "itemUuid" => step_uuid)
    expect(stored.find { |entry| entry["message"].include?("native world.log evidence") }).to include("level" => "info", "itemUuid" => step_uuid)
  end

  it "restores nested callback metadata after normal return and exceptions without leaking" do
    formatter = build_formatter
    entries = capture_report_logs(formatter)
    world = RoutingWorld.new(formatter)

    Automation::ReportContext.with(level: :debug) do
      world.log("outer debug scope")
      expect do
        Automation::ReportContext.with(level: :error) do
          world.log("inner error scope")
          raise "scope failure"
        end
      end.to raise_error("scope failure")
      world.log("outer restored scope")
    end
    world.log("unscoped default")
    formatter.instance_variable_get(:@log_buffer).flush(timeout: 2)

    scoped_entries = entries.select { |entry| entry[:message].match?(/scope|unscoped/) }
    expect(scoped_entries.map { |entry| [entry[:message], entry[:level]] }).to eq([
      ["outer debug scope", :debug],
      ["inner error scope", :error],
      ["outer restored scope", :debug],
      ["unscoped default", :info]
    ])
    expect(Automation::ReportContext.current).to eq({})
  end

  it "isolates scoped callback levels and active step UUIDs across threads" do
    entries = Queue.new
    worlds = Queue.new
    ready = Queue.new
    release = Queue.new
    workers = 2.times.map do |index|
      Thread.new do
        formatter = build_formatter
        world = RoutingWorld.new(formatter) do
          ready << index
          release.pop
        end
        buffer = formatter.instance_variable_get(:@log_buffer)
        original_emit = buffer.method(:emit_log)
        buffer.define_singleton_method(:emit_log) do |**record|
          entries << record
          original_emit.call(**record)
        end
        AppLog.bind(world, output: StringIO.new, color: false)
        AppLog.public_send(index.zero? ? :debug : :error, "thread #{index} callback", report: true)
        formatter.instance_variable_get(:@log_buffer).flush(timeout: 2)
        worlds << { index: index, world: world, uuid: formatter.runtime_context.current_item_uuid, context: Automation::ReportContext.current }
      ensure
        AppLog.clear!
        finalize_formatter(formatter) if formatter
      end
    end
    begin
      Timeout.timeout(5) { 2.times { ready.pop } }
    ensure
      2.times { release << true }
      workers.each(&:value)
    end

    records = entries.size.times.map { entries.pop }
    thread_data = worlds.size.times.map { worlds.pop }
    expect(records.map { |record| record[:message] }.sort).to eq(["thread 0 callback", "thread 1 callback"])
    expect(thread_data.length).to eq(2)
    expect(thread_data.map { |data| data[:uuid] }.uniq.length).to eq(2)
    thread_data.each do |data|
      index = data.fetch(:index)
      record = records.find { |candidate| candidate[:message] == "thread #{index} callback" }
      expect(record).to include(
        level: index.zero? ? :debug : :error,
        item_uuid: data[:uuid]
      )
      expect(data[:context]).to eq({})
    end
    expect(thread_data.map { |data| data[:world].native_logs.length }).to eq([1, 1])
    expect(Automation::ReportContext.current).to eq({})
  end

  it "keeps Cucumber world.log usable when ReportPortal mode is disabled" do
    disabled_config = config
    allow(disabled_config).to receive(:enabled?).and_return(false)
    allow(ReportportalCucumber::Config).to receive(:load).and_return(disabled_config)
    expect(ReportportalCucumber::ReportPortal::API).not_to receive(:new)
    expect(ReportportalCucumber::Runtime::LogBuffer).not_to receive(:new)
    formatter = build_formatter(start: false)
    world = RoutingWorld.new(formatter)
    AppLog.bind(world, output: StringIO.new, color: false)

    expect { AppLog.info("native only", report: true) }.not_to raise_error
    expect(world.native_logs).to eq(["native only"])
    expect(@mock_server.logs).to be_empty
    expect(formatter.instance_variable_get(:@api)).to be_nil
    expect(formatter.instance_variable_get(:@log_buffer)).to be_nil
  end

  it "keeps attach:false terminal-only and lets report:false override attach:true" do
    formatter = build_formatter
    entries = capture_report_logs(formatter)
    world = RoutingWorld.new(formatter)
    AppLog.bind(world, output: StringIO.new, color: false)

    AppLog.info("legacy local", attach: false)
    AppLog.error("explicitly suppressed", attach: true, report: false)
    formatter.instance_variable_get(:@log_buffer).flush(timeout: 2)

    expect(world.native_logs).to be_empty
    expect(entries).to be_empty
    expect(@mock_server.logs).to be_empty
  end
end
