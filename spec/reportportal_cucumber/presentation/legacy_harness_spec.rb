# frozen_string_literal: true

require "spec_helper"
require_relative "../../../script/acceptance/presentation_ledger_developer"

RSpec.describe "Legacy Ledger developer runner selection" do
  it "defaults to supported Cucumber 10.2.0 without activating a different runtime" do
    loaded = Gem.loaded_specs.fetch("cucumber")
    runner = LedgerDeveloper::Runner.new([])
    expect(runner.instance_variable_get(:@options)).to include(cucumber: "10.2.0", transport: "offline")
    expect(Gem.loaded_specs.fetch("cucumber")).to equal(loaded)
  end

  %w[9.2.1 10.2.0].each do |version|
    it "retains the explicit Cucumber #{version} override" do
      runner = LedgerDeveloper::Runner.new(["--cucumber", version])
      expect(runner.instance_variable_get(:@options)).to include(cucumber: version)
    end
  end

  it "documents the legacy default and Cucumber 9 override in its help" do
    expect { LedgerDeveloper::Runner.new(["--help"]) }
      .to output(/1\.x default: 10\.2\.0.*--cucumber 9\.2\.1/).to_stdout
  end
end
