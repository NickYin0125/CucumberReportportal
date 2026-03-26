# frozen_string_literal: true

require "spec_helper"
require "cucumber/cli/main"
require "stringio"

RSpec.describe "example cucumber integration" do
  class ExitSignal < StandardError
    attr_reader :status

    def initialize(status)
      @status = status
      super("exit #{status}")
      set_backtrace([])
    end
  end

  KernelDouble = Struct.new(:status) do
    def exit(code = 0)
      throw :kernel_exit, code
    end

    def exit!(code = 0)
      throw :kernel_exit, code
    end
  end

  around do |example|
    original = ENV.to_h.slice(
      "RP_ENDPOINT",
      "RP_PROJECT",
      "RP_API_KEY",
      "RP_LAUNCH",
      "RP_CLIENT_JOIN",
      "RP_BATCH_SIZE_LOGS",
      "RP_FLUSH_INTERVAL",
      "RP_HTTP_RETRY_ATTEMPTS"
    )
    ENV["RP_ENDPOINT"] = "https://rp.example.com"
    ENV["RP_PROJECT"] = "demo"
    ENV["RP_API_KEY"] = "token"
    ENV["RP_LAUNCH"] = "Example launch"
    ENV["RP_CLIENT_JOIN"] = "false"
    ENV["RP_BATCH_SIZE_LOGS"] = "2"
    ENV["RP_FLUSH_INTERVAL"] = "0.1"
    ENV["RP_HTTP_RETRY_ATTEMPTS"] = "1"
    example.run
  ensure
    %w[
      RP_ENDPOINT
      RP_PROJECT
      RP_API_KEY
      RP_LAUNCH
      RP_CLIENT_JOIN
      RP_BATCH_SIZE_LOGS
      RP_FLUSH_INTERVAL
      RP_HTTP_RETRY_ATTEMPTS
    ].each { |key| ENV.delete(key) }
    original.each { |key, value| ENV[key] = value if value }
    Cucumber.wants_to_quit = false
  end

  it "runs the minimal example through the real cucumber CLI and reports in order" do
    calls = []
    start_item_counter = 0

    stub_request(:post, "https://rp.example.com/api/v1/demo/launch").to_return do |request|
      calls << [:start_launch, JSON.parse(request.body)]
      { status: 200, body: '{"id":"launch-1"}' }
    end

    stub_request(:post, %r{\Ahttps://rp\.example\.com/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
      start_item_counter += 1
      body = JSON.parse(request.body)
      kind =
        case start_item_counter
        when 1 then :start_suite
        when 2 then :start_scenario
        else :start_step
        end
      calls << [kind, body]
      { status: 200, body: { id: "item-#{start_item_counter}" }.to_json }
    end

    stub_request(:post, "https://rp.example.com/api/v1/demo/log").to_return do |request|
      calls << [:log_batch, request.body]
      { status: 200, body: '{"responses":[{"message":"ok"}]}' }
    end

    stub_request(:put, %r{\Ahttps://rp\.example\.com/api/v1/demo/item/.*\z}).to_return do |request|
      calls << [:finish_item, JSON.parse(request.body)]
      { status: 200, body: '{"message":"ok"}' }
    end

    stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish").to_return do |request|
      calls << [:finish_launch, JSON.parse(request.body)]
      { status: 200, body: '{"message":"ok"}' }
    end

    out = StringIO.new
    err = StringIO.new
    kernel_double = KernelDouble.new(nil)
    args = [
      "--require", "lib/reportportal_cucumber.rb",
      "--require", "examples/minimal/features",
      "--format", "ReportPortal::Cucumber::Formatter",
      "examples/minimal/features"
    ]

    status = catch(:kernel_exit) do
      Cucumber::Cli::Main.new(args, out, err, kernel_double).execute!
    end

    expect(status).to eq(0)
    expect(calls.map(&:first)).to include(:start_launch, :start_suite, :start_scenario, :log_batch, :finish_launch)
    expect(calls.find { |name, _| name == :log_batch }.last).to include("seed.txt")
    expect(calls.find { |name, body| name == :start_scenario && body["hasStats"] == true }.last["name"]).to eq("Scenario: Successful reporting flow")
  end
end
