# frozen_string_literal: true

require "digest"
require "spec_helper"

legacy_root = File.realpath(ENV.fetch("LEGACY_SOURCE_ROOT"))
original = File.join(legacy_root, "spec/day2/fault_process_spec.rb")
unless Digest::SHA256.file(original).hexdigest == "4b2e01d3343dba4d1d902b8cc835e7c29a82893efb87241453783fcb379ced70"
  raise "Legacy fault overlay requires the unchanged immutable v1.3.1 original spec"
end
require File.join(legacy_root, "examples/day2_faults/sandbox")
require File.join(legacy_root, "examples/day2_faults/process_run")

# The seven released fault cases are retained; only provenance is version-neutral.
RSpec.describe "Day2 native process fault isolation (immutable legacy compatibility driver)" do
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
        expect(result.fetch("cucumber")).to eq(Gem.loaded_specs.fetch("cucumber").version.to_s)
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
