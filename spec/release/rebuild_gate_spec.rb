# frozen_string_literal: true

require "rspec"
require_relative "../../script/release/rebuild_gate"

RSpec.describe ReleaseTooling::RebuildGate do
  let(:inputs) do
    {
      tag: "v2.0.0", sha: "a" * 40, run_id: "123", workflow_id: "456",
      run: { "id" => 123, "workflow_id" => 456, "head_sha" => "a" * 40,
             "head_branch" => "v2.0.0", "event" => "push", "status" => "completed",
             "conclusion" => "failure" },
      jobs: (described_class::REQUIRED_JOBS.map { |name| job(name, "success") } +
             [job("validate / bundle", "failure"), job("publish", "skipped")]),
      artifacts: [], releases: []
    }
  end

  def job(name, conclusion)
    { "name" => name, "status" => "completed", "conclusion" => conclusion }
  end

  it "permits only a first build after the original complete matrix passed" do
    expect(described_class.verify!(**inputs)).to be(true)
  end

  %w[id workflow_id head_sha head_branch event status conclusion].each do |key|
    it "rejects mismatched original-run #{key}" do
      inputs[:run][key] = "unexpected"
      expect { described_class.verify!(**inputs) }.to raise_error(ArgumentError)
    end
  end

  it "rejects unsafe or unsupported input identities" do
    [{ tag: "v1.3.1" }, { tag: "v2.0.0-rc.1" }, { tag: "v2.00.0" },
     { sha: "main" }, { run_id: "123; echo unsafe" }, { workflow_id: "0" }].each do |change|
      expect { described_class.verify!(**inputs.merge(change)) }.to raise_error(ArgumentError)
    end
  end

  it "requires every original matrix cell, not only a successful gate label" do
    described_class::REQUIRED_JOBS.each do |name|
      altered = inputs[:jobs].map { |entry| entry["name"] == name ? job(name, "failure") : entry }
      expect { described_class.verify!(**inputs.merge(jobs: altered)) }.to raise_error(ArgumentError)
    end
  end

  it "rejects missing, duplicated or still-running jobs" do
    [inputs[:jobs].drop(1), inputs[:jobs] + [inputs[:jobs].first],
     inputs[:jobs].map { |entry| entry.merge("status" => "in_progress") }].each do |altered|
      expect { described_class.verify!(**inputs.merge(jobs: altered)) }.to raise_error(ArgumentError)
    end
  end

  it "rejects skipped/successful builds or an already-attempted publisher" do
    [["validate / bundle", "skipped"], ["validate / bundle", "success"],
     ["publish", "failure"], ["publish", "success"]].each do |name, result|
      altered = inputs[:jobs].map { |entry| entry["name"] == name ? job(name, result) : entry }
      expect { described_class.verify!(**inputs.merge(jobs: altered)) }.to raise_error(ArgumentError)
    end
  end

  it "rejects retained or expired original bundles from any attempt" do
    [false, true].each do |expired|
      inputs[:artifacts] = [{ "name" => "release-bundle-123-2", "expired" => expired }]
      expect { described_class.verify!(**inputs) }.to raise_error(ArgumentError, /resume/)
    end
  end

  it "rejects existing releases and hidden drafts" do
    [false, true].each do |draft|
      inputs[:releases] = [{ "tag_name" => "v2.0.0", "draft" => draft }]
      expect { described_class.verify!(**inputs) }.to raise_error(ArgumentError, /already exists/)
    end
  end

  it "allows unrelated legacy artifacts and releases without dropping them" do
    inputs[:artifacts] = [{ "name" => "legacy-lock-ruby-3.1-cucumber-9-1" }]
    inputs[:releases] = [{ "tag_name" => "v1.3.1" }]
    expect(described_class.verify!(**inputs)).to be(true)
  end
end
