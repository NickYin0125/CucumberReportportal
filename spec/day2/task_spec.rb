# frozen_string_literal: true

require "rake"
require "rbconfig"

RSpec.describe "Day-2 task delegation" do
  def command_owner(name)
    Rake::Task[name].actions.first.binding.receiver
  end

  around do |example|
    previous = Rake.application
    previous_env = ENV.to_h
    Rake.application = Rake::Application.new
    load File.expand_path("../../Rakefile", __dir__)
    example.run
  ensure
    Rake.application = previous
    ENV.replace(previous_env)
  end

  it "delegates default duration acceptance with a real 900-second minimum and deterministic seed" do
    ENV["RP_ENDPOINT"] = "http://rp-latest.localhost"
    %w[DAY2_MODE DAY2_SECONDS DAY2_ITERATIONS DAY2_SEED].each { |key| ENV.delete(key) }
    task = Rake::Task["rp:duration"]
    expect(command_owner("rp:duration")).not_to receive(:fetch_reportportal_token)
    expect(command_owner("rp:duration")).to receive(:system).with(
      RbConfig.ruby, end_with("/examples/day2_endurance/run.rb"),
      "--mode", "live", "--seconds", "900", "--iterations", "750", "--seed", "20261013",
      "--endpoint", "http://rp-latest.localhost"
    ).and_return(true)
    task.invoke
  end

  it "allows a credential-free smoke without passing an endpoint" do
    ENV["DAY2_MODE"] = "smoke"
    ENV.delete("RP_ENDPOINT")
    expect(command_owner("rp:duration")).to receive(:system).with(
      RbConfig.ruby, end_with("/examples/day2_endurance/run.rb"),
      "--mode", "smoke", "--seconds", anything, "--iterations", anything, "--seed", anything
    ).and_return(true)
    Rake::Task["rp:duration"].invoke
  end

  it "uses an offline fault sandbox by default, not a live cluster" do
    ENV.delete("DAY2_LIVE")
    expect(command_owner("rp:failure_stress")).to receive(:system).with(
      RbConfig.ruby, end_with("/examples/day2_faults/run_local.rb")
    ).and_return(true)
    Rake::Task["rp:failure_stress"].invoke
  end

  it "preserves a failed child validation as a nonzero task outcome" do
    ENV["DAY2_LIVE"] = "true"
    expect(command_owner("rp:failure_stress")).to receive(:system).with(
      RbConfig.ruby, end_with("/examples/day2_faults/run_live.rb"), "--execute-local-rp"
    ).and_return(false)
    expect { Rake::Task["rp:failure_stress"].invoke }.to raise_error(SystemExit) { |error| expect(error.status).not_to eq(0) }
  end
end
