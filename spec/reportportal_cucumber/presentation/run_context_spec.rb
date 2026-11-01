# frozen_string_literal: true

require "spec_helper"
require "reportportal_cucumber/presentation/run_context"

RSpec.describe ReportportalCucumber::Presentation::RunContext do
  let(:env) do
    { "GITHUB_REF_NAME" => "feature/ledger", "RP_SOURCE_COMMIT" => "e7dae2b1234567",
      "GITHUB_RUN_ID" => "42", "PARALLEL_TEST_GROUPS" => "4", "RP_API_KEY" => "never-collect-this" }
  end

  def metadata(**overrides)
    described_class.build(**{ attributes: [], description: nil, sdk_version: "2.0.1", cucumber_version: "12.0.1",
                              ruby_version: "3.4.2", include_workers: true, env: env }.merge(overrides))
  end

  it "creates the exact documented metadata without collecting unrelated environment values" do
    expect(metadata).to eq(attributes: [
      { key: "sdk", value: "2.0.1" }, { key: "cucumber", value: "12.0.1" }, { key: "ruby", value: "3.4.2" },
      { key: "workers", value: "4" }, { key: "git.branch", value: "feature/ledger" },
      { key: "git.sha", value: "e7dae2b" }, { key: "ci.build", value: "42" }
    ], description: "Cucumber 12.0.1 · Ruby 3.4.2 · 4 workers · feature/ledger@e7dae2b")
    expect(metadata.to_s).not_to include("never-collect-this")
  end

  it "preserves explicit values including system metadata and never mutates the caller's attributes" do
    attributes = [{ "key" => "sdk", "value" => "custom", "system" => true }.freeze, { value: "smoke" }.freeze].freeze
    result = metadata(attributes: attributes, description: "Given description")
    expect(result[:attributes].first).to eq(attributes.first)
    expect(result[:attributes].count { |entry| (entry[:key] || entry["key"]) == "sdk" }).to eq(1)
    expect(result[:description]).to eq("Given description")
    expect(attributes.size).to eq(2)
  end

  it "omits workers entirely on the legacy release line" do
    result = metadata(sdk_version: "1.3.2", cucumber_version: "10.2.0", include_workers: false)
    expect(result[:attributes].map { |entry| entry[:key] }).not_to include("workers")
    expect(result[:description]).to eq("Cucumber 10.2.0 · Ruby 3.4.2 · feature/ledger@e7dae2b")
  end

  it "uses only present parts and respects the documented environment precedence" do
    environment = { "GITHUB_REF_NAME" => " ", "CI_COMMIT_REF_NAME" => "gitlab-branch", "BRANCH_NAME" => "jenkins-branch",
                    "GITHUB_SHA" => "abc1234xxxx", "CI_COMMIT_SHA" => "def5678xxxx", "CI_PIPELINE_ID" => "77", "BUILD_NUMBER" => "99" }
    result = metadata(env: environment)
    expect(result[:description]).to eq("Cucumber 12.0.1 · Ruby 3.4.2 · gitlab-branch@abc1234")
    expect(result[:attributes]).to include({ key: "ci.build", value: "77" })
    expect(metadata(env: {})[:description]).to eq("Cucumber 12.0.1 · Ruby 3.4.2")
  end

  it "bounds Unicode values by characters and escapes only the generated Markdown description" do
    result = metadata(env: { "GITHUB_REF_NAME" => "中" * 200, "BUILD_NUMBER" => "a" * 200 })
    expect(result[:attributes].find { |entry| entry[:key] == "git.branch" }[:value].length).to eq(128)
    expect(result[:attributes].find { |entry| entry[:key] == "ci.build" }[:value].length).to eq(128)
    expect(metadata(env: { "GITHUB_REF_NAME" => "<other>" })[:description]).to end_with("&lt;other&gt;")
    expect(metadata(env: { "GITHUB_REF_NAME" => "<other>" })[:attributes]).to include({ key: "git.branch", value: "<other>" })
  end

  it "returns the exact explicit metadata and one warning on a formatting fault" do
    attributes = [{ key: "sdk", value: "custom" }]
    allow(ReportportalCucumber::Presentation::MarkdownText).to receive(:inline).and_raise("unsafe SECRET error")
    expect(ReportportalCucumber.logger).to receive(:warn).with("ReportPortal presentation failed; using baseline format").once
    result = metadata(attributes: attributes)
    expect(result).to eq(attributes: attributes, description: nil)
    expect(result[:attributes]).to equal(attributes)
  end
end
