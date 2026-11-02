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
    ], description: "4 workers · feature/ledger@e7dae2b · build 42")
    expect(metadata.to_s).not_to include("never-collect-this")
  end

  it "preserves explicit values including system metadata and never mutates the caller's attributes" do
    attributes = [{ "key" => "sdk", "value" => "custom", "system" => true }.freeze, { value: "smoke" }.freeze].freeze
    description = "<Given description>\nCucumber custom · Ruby custom".freeze
    result = metadata(attributes: attributes, description: description)
    expect(result[:attributes]).to eq(attributes + [
      { key: "cucumber", value: "12.0.1" }, { key: "ruby", value: "3.4.2" },
      { key: "workers", value: "4" }, { key: "git.branch", value: "feature/ledger" },
      { key: "git.sha", value: "e7dae2b" }, { key: "ci.build", value: "42" }
    ])
    expect(result[:description]).to equal(description)
    expect(attributes).to eq([{ "key" => "sdk", "value" => "custom", "system" => true }, { value: "smoke" }])
  end

  it "keeps explicit version attributes instead of adding generated duplicates" do
    attributes = [{ key: "cucumber", value: "custom-cucumber" }, { "key" => "ruby", "value" => "custom-ruby" }]
    expect(metadata(attributes: attributes, env: {})).to eq(
      attributes: attributes + [{ key: "sdk", value: "2.0.1" }], description: ""
    )
  end

  it "omits workers entirely on the legacy release line" do
    result = metadata(sdk_version: "1.3.2", cucumber_version: "10.2.0", include_workers: false)
    expect(result[:attributes].map { |entry| entry[:key] }).not_to include("workers")
    expect(result[:description]).to eq("feature/ledger@e7dae2b · build 42")
  end

  it "uses only present parts and respects the documented environment precedence" do
    environment = { "GITHUB_REF_NAME" => " ", "CI_COMMIT_REF_NAME" => "gitlab-branch", "BRANCH_NAME" => "jenkins-branch",
                    "GITHUB_SHA" => "abc1234xxxx", "CI_COMMIT_SHA" => "def5678xxxx", "CI_PIPELINE_ID" => "77", "BUILD_NUMBER" => "99" }
    result = metadata(env: environment)
    expect(result[:description]).to eq("gitlab-branch@abc1234 · build 77")
    expect(result[:attributes]).to include({ key: "ci.build", value: "77" })
  end

  [
    ["workers only", { "PARALLEL_TEST_GROUPS" => "1" }, "1 worker", [{ key: "workers", value: "1" }]],
    ["branch only", { "GITHUB_REF_NAME" => "main" }, "main", [{ key: "git.branch", value: "main" }]],
    ["SHA only", { "GITHUB_SHA" => "abc1234xxxx" }, "abc1234", [{ key: "git.sha", value: "abc1234" }]],
    ["build only", { "BUILD_NUMBER" => "42" }, "build 42", [{ key: "ci.build", value: "42" }]],
    ["empty context", {}, "", []],
    ["blank context", { "PARALLEL_TEST_GROUPS" => " ", "GITHUB_REF_NAME" => "\t",
                        "GITHUB_SHA" => "", "BUILD_NUMBER" => nil }, "", []]
  ].each do |name, environment, generated_description, context_attributes|
    it "generates only present parts for #{name} while preserving exact attributes" do
      [nil, ""].each do |description|
        expect(metadata(env: environment, description: description)).to eq(
          attributes: [
            { key: "sdk", value: "2.0.1" }, { key: "cucumber", value: "12.0.1" }, { key: "ruby", value: "3.4.2" }
          ] + context_attributes,
          description: generated_description
        )
      end
    end
  end

  it "returns empty metadata when versions and context are absent" do
    [nil, " "].each do |version|
      expect(metadata(env: {}, sdk_version: version, cucumber_version: version, ruby_version: version))
        .to eq(attributes: [], description: "")
    end
  end

  it "preserves an explicit description even without generated context" do
    description = "<Given description>\n".freeze
    expect(metadata(env: {}, description: description)).to eq(
      attributes: [
        { key: "sdk", value: "2.0.1" }, { key: "cucumber", value: "12.0.1" }, { key: "ruby", value: "3.4.2" }
      ], description: description
    )
  end

  it "bounds Unicode values by characters and escapes only the generated Markdown description" do
    result = metadata(env: { "GITHUB_REF_NAME" => "中" * 200, "BUILD_NUMBER" => "a" * 200 })
    expect(result[:attributes].find { |entry| entry[:key] == "git.branch" }[:value].length).to eq(128)
    expect(result[:attributes].find { |entry| entry[:key] == "ci.build" }[:value].length).to eq(128)
    expect(metadata(env: { "GITHUB_REF_NAME" => "<other>" })[:description]).to end_with("&lt;other&gt;")
    expect(metadata(env: { "GITHUB_REF_NAME" => "<other>" })[:attributes]).to include({ key: "git.branch", value: "<other>" })
    expect(metadata(env: { "BUILD_NUMBER" => "<42>" })[:description]).to eq("build &lt;42&gt;")
    expect(metadata(env: { "BUILD_NUMBER" => "<42>" })[:attributes]).to include({ key: "ci.build", value: "<42>" })
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
