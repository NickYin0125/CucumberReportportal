# frozen_string_literal: true

require_relative "../../script/acceptance/cucumber12_blackbox"

# Installed-package checks are explicit, never an implicit local-cache CI dependency.
RSpec.describe Cucumber12Independent::Audit do
  let(:audit) { described_class.new }
  let(:current) { { "id" => "validator", "assertions" => [], "failures" => [], "runs" => [] } }
  let(:run) do
    { "label" => "portable-validator", "wire" => {
      "errors" => [], "logs" => [], "items" => {}, "launches" => {
        "launch" => { "uuid" => "launch", "startTime" => "1000", "startSequence" => 0,
                      "finish" => { "endTime" => "1010", "status" => "PASSED" }, "finishSequence" => 2 }
      }
    } }
  end

  before { audit.instance_variable_set(:@current, current) }

  it "accepts a closed owned launch without installing packages or starting Cucumber" do
    audit.send(:verify_wire, run)
    expect(current.fetch("failures")).to eq([])
  end

  it "rejects an unfinished launch even without an explicit IN_PROGRESS field" do
    run.fetch("wire").fetch("launches").fetch("launch").delete("finish")
    audit.send(:verify_wire, run)
    expect(current.fetch("failures")).to include(a_string_including("every emitted launch/item"))
  end

  it "rejects an explicit nonterminal status" do
    run.fetch("wire").fetch("launches").fetch("launch").fetch("finish")["status"] = "IN_PROGRESS"
    audit.send(:verify_wire, run)
    expect(current.fetch("failures")).to include(a_string_including("no IN_PROGRESS"))
  end

  it "rejects evidence whose UUID has no emitted owner" do
    run.fetch("wire").fetch("logs") << { "itemUuid" => "unowned", "launchUuid" => "launch", "time" => "1005", "sequence" => 1 }
    audit.send(:verify_wire, run)
    expect(current.fetch("failures")).to include(a_string_including("log UUID/sequence/timestamp"))
  end

  it "rejects a log sent after launch finish" do
    run.fetch("wire").fetch("logs") << { "launchUuid" => "launch", "time" => "1011", "sequence" => 3 }
    audit.send(:verify_wire, run)
    expect(current.fetch("failures")).to include(a_string_including("log UUID/sequence/timestamp"))
  end

  it "rejects server-reported HTTP protocol violations" do
    run.fetch("wire").fetch("errors") << "child URL differs from parentUuid"
    audit.send(:verify_wire, run)
    expect(current.fetch("failures")).to include(a_string_including("HTTP collector accepted every request"))
  end

  it "removes both Bundler activation channels instead of weakening installed-source provenance" do
    allow(ENV).to receive(:keys).and_return(%w[BUNDLE_GEMFILE BUNDLER_SETUP BUNDLER_VERSION BUNDLER_ORIG_RUBYOPT RUBYOPT RUBYLIB])
    cleaned = audit.send(:clean_environment)
    expect(cleaned.values_at("BUNDLE_GEMFILE", "BUNDLER_SETUP", "BUNDLER_VERSION", "BUNDLER_ORIG_RUBYOPT", "RUBYOPT", "RUBYLIB")).to eq([nil] * 6)
  end
end
