# frozen_string_literal: true

require "spec_helper"
require "stringio"

begin
  require "reportportal_cucumber/automation/cucumber_logger"
rescue LoadError
  # The implementation is supplied by the Builder agent; keep the spec as the
  # executable contract for the new public API.
end

RSpec.describe "Automation::CucumberLogger" do
  class TripleTrackWorldSpy
    attr_reader :logs, :attachments, :rp_logs, :rp_attachments

    def initialize(rp_active: false)
      @rp_active = rp_active
      @logs = []
      @attachments = []
      @rp_logs = []
      @rp_attachments = []
    end

    def log(*args)
      @logs << args
    end

    def attach(*args, **kwargs)
      @attachments << [args, kwargs]
    end

    def rp_active?
      @rp_active
    end

    def rp_log(*args, **kwargs)
      @rp_logs << [args, kwargs]
    end

    def rp_attach(*args, **kwargs)
      @rp_attachments << [args, kwargs]
    end
  end

  def build_logger(world)
    Automation::CucumberLogger.new(world: world)
  end

  def capture_stdout
    original_stdout = $stdout
    stream = StringIO.new
    $stdout = stream
    yield
    stream.string
  ensure
    $stdout = original_stdout
  end

  around do |example|
    original_logger = Thread.current[:active_logger]
    Thread.current[:active_logger] = nil
    example.run
  ensure
    Thread.current[:active_logger] = original_logger
  end

  it "keeps attach:false terminal-only and does not call Cucumber or ReportPortal tracks" do
    world = TripleTrackWorldSpy.new(rp_active: true)
    logger = build_logger(world)

    expect do
      logger.info("local diagnostic only", attach: false)
    end.to output(/local diagnostic only/).to_stdout

    expect(world.logs).to be_empty
    expect(world.attachments).to be_empty
    expect(world.rp_logs).to be_empty
    expect(world.rp_attachments).to be_empty
  end

  it "keeps large JSON out of terminal output while attaching Markdown-fenced JSON to Cucumber" do
    world = TripleTrackWorldSpy.new
    logger = build_logger(world)
    payload = {
      account: "ACC-9000",
      positions: Array.new(12) { |index| { id: index, exposure: index * 1000, currency: "USD" } }
    }

    terminal_output = capture_stdout do
      logger.info("Margin Payload", attach: true, json: payload)
    end

    expect(terminal_output).to include("Margin Payload")
    expect(terminal_output).not_to include("ACC-9000")
    expect(terminal_output).not_to include("positions")

    expect(world.logs.length).to eq(1)
    cucumber_log_message = world.logs.first.flatten.join("\n")
    expect(cucumber_log_message).to include("```json")
    expect(cucumber_log_message).to include(JSON.pretty_generate(payload))
  end

  it "routes AppLog calls to the logger bound to the current thread" do
    first_world = TripleTrackWorldSpy.new
    second_world = TripleTrackWorldSpy.new
    first_logger = Automation::CucumberLogger.new(world: first_world, output: StringIO.new)
    second_logger = Automation::CucumberLogger.new(world: second_world, output: StringIO.new)

    first_thread = Thread.new do
      Thread.current[:active_logger] = first_logger
      AppLog.info("first thread event", attach: true, json: { thread: "first" })
    ensure
      Thread.current[:active_logger] = nil
    end

    second_thread = Thread.new do
      Thread.current[:active_logger] = second_logger
      AppLog.info("second thread event", attach: true, json: { thread: "second" })
    ensure
      Thread.current[:active_logger] = nil
    end

    [first_thread, second_thread].each(&:join)

    first_log = first_world.logs.first.flatten.join("\n")
    second_log = second_world.logs.first.flatten.join("\n")
    expect(first_log).to include("first thread event")
    expect(first_log).to include('"thread": "first"')
    expect(first_log).not_to include("second thread event")
    expect(second_log).to include("second thread event")
    expect(second_log).to include('"thread": "second"')
    expect(second_log).not_to include("first thread event")
  end
end
