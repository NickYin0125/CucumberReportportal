# frozen_string_literal: true

require "spec_helper"
require_relative "../../examples/day2_faults/sandbox"
require_relative "../../examples/day2_faults/process_run"

RSpec.describe "Day2 native process fault isolation" do
  around do |example|
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
  end

  before do
    @sandbox = Day2Faults::Sandbox.new
    @directory = Dir.mktmpdir("day2-native-")
  end

  after do
    @proxy&.stop
    @sandbox.stop
    FileUtils.remove_entry(@directory)
  end

  def run_case(steps:, scope: :logs, repeat: true, **options)
    @proxy = Day2Faults::FaultProxy.new(upstream: @sandbox.endpoint, steps: steps, scope: scope, repeat: repeat)
    result = Day2Faults::ProcessRun.run(endpoint: @proxy.endpoint, directory: @directory, **options)
    if ENV["DAY2_LOCAL_CAPTURE"]
      Day2Faults.write_evidence(File.join(ENV.fetch("DAY2_LOCAL_CAPTURE"), "processes", "#{result.fetch('launch_name')}.json"),
                               { process: result, proxy_events: @proxy.events, sandbox: @sandbox.snapshot })
    end
    result
  end

  [400, 401].each do |status|
    [false, true].each do |strict|
      it "preserves original native business failure under HTTP #{status}, strict=#{strict}" do
        result = run_case(steps: [{ action: :status, status: status }], mode: "business_failure", strict: strict)
        expect(result.fetch("exit")).to eq(1)
        expect(result.fetch("stdout") + result.fetch("stderr")).to include("DAY2_ORIGINAL_BUSINESS_FAILURE")
        expect(result.fetch("receipt")).to include("complete" => false, "confirmed" => 0, "ambiguous" => 0)
        expect(result.dig("receipt", "failed")).to be > 0
        expect(result.fetch("cucumber")).to eq("10.2.0")
        requests = @proxy.events.select { |event| event[:path].end_with?("/log") }
        expect(requests.map { |event| event[:request_sha256] }.uniq.length).to eq(requests.length)
      end
    end
  end

  it "handles real SIGINT in a Cucumber subprocess with a bounded exit and an honest receipt" do
    result = run_case(steps: [{ action: :status, status: 503 }], mode: "sigint")
    expect(result.fetch("signal_to_exit")).to be < 2
    expect(result.fetch("exit")).not_to be_nil
    expect(result.fetch("receipt")).to include("complete" => false)
    expect(result.dig("receipt", "spooled")).to be > 0
    expect(@sandbox.snapshot.fetch("logs").any? { |log| log["message"] == "day2 native second marker" }).to be(false)
    expect(@sandbox.snapshot.fetch("launches").length).to eq(1)
  end

  it "does not replace a business failure with final metadata outage" do
    result = run_case(steps: [{ action: :status, status: 503 }], scope: :finish, mode: "business_failure")
    expect(result.fetch("exit")).to eq(1)
    expect(result.fetch("stdout")).to include("DAY2_ORIGINAL_BUSINESS_FAILURE")
    expect(result.dig("receipt", "metadata_failures")).to be > 0
    expect(result.dig("receipt", "complete")).to be(false)
  end

  it "bounds the whole native finalization with slow HTTP instead of one budget per request" do
    result = run_case(steps: [{ action: :slow, delay: 0.3 }], scope: :finish, flush_ms: 80)
    expect(result.fetch("elapsed")).to be < 7
    expect(result.fetch("finalization_elapsed")).to be < 0.35
    expect(result.dig("receipt", "complete")).to be(false)
    expect(result.dig("receipt", "metadata_failures")).to be > 0
  end
end
