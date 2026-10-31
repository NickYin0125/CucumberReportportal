# frozen_string_literal: true

require "rake"

RSpec.describe "Live regression task" do
  around do |example|
    previous = Rake.application
    Rake.application = Rake::Application.new
    load File.expand_path("../../Rakefile", __dir__)
    example.run
  ensure
    Rake.application = previous
  end

  let(:runner) { TOPLEVEL_BINDING.eval("self") }
  let(:launch) { { "id" => 1, "uuid" => "synthetic-launch", "statistics" => { "executions" => executions } } }
  let(:executions) { { "total" => 7, "passed" => 6, "failed" => 1 } }

  before do
    allow(runner).to receive(:fetch_reportportal_token).and_return("synthetic-token")
    allow(runner).to receive(:wait_for_launch).and_return(launch)
    allow(runner).to receive(:puts)
  end

  it "bypasses the offline profile and gives each formatter its own output" do
    arguments = nil
    allow(runner).to receive(:system) do |*command|
      arguments = command
      false # The live fixture intentionally preserves one business failure.
    end

    expect { Rake::Task["rp:regression"].invoke }.not_to raise_error
    expect(arguments.drop(1)).to include("--no-profile", "features/deep_water", "pretty")
    formatter = arguments.index("ReportPortal::Cucumber::Formatter")
    expect(arguments[formatter + 1]).to eq("--out")
    expect(arguments[formatter + 2]).to start_with("tmp/reportportal-regression-")
  end

  it "refuses an empty report instead of calling skipped scenarios a successful regression" do
    allow(runner).to receive(:system).and_return(true)
    executions.replace("total" => 0, "passed" => 0, "failed" => 0)
    allow(runner).to receive(:abort) { |message| raise RuntimeError, message }

    expect { Rake::Task["rp:regression"].invoke }.to raise_error(RuntimeError, /Unexpected ReportPortal stats/)
  end
end
