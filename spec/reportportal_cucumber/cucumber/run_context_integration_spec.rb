# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Opt-in Launch run context" do
  RunContextConfig = Struct.new(:handlers) do
    def on_event(name, &block)
      handlers[name] = block
    end

    def include(_mod); end
  end

  let(:calls) { [] }
  let(:context_env) do
    { "GITHUB_REF_NAME" => "feature/ledger", "RP_SOURCE_COMMIT" => "e7dae2b1234567",
      "GITHUB_RUN_ID" => "42", "PARALLEL_TEST_GROUPS" => "4" }
  end

  around do |example|
    keys = %w[GITHUB_REF_NAME CI_COMMIT_REF_NAME BRANCH_NAME RP_SOURCE_COMMIT GITHUB_SHA CI_COMMIT_SHA
              GITHUB_RUN_ID CI_PIPELINE_ID BUILD_NUMBER PARALLEL_TEST_GROUPS]
    saved = keys.to_h { |key| [key, ENV[key]] }
    keys.each { |key| ENV.delete(key) }
    context_env.each { |key, value| ENV[key] = value }
    example.run
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  before do
    stub_request(:post, "https://rp.example.com/api/v1/demo/launch").to_return do |request|
      calls << [:start, JSON.parse(request.body)]
      { status: 200, body: JSON.generate(id: "launch-context") }
    end
    stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-context/finish").to_return do |request|
      calls << [:finish, JSON.parse(request.body)]
      { status: 200, body: JSON.generate(message: "ok") }
    end
  end

  def run_launch(**overrides)
    config = ReportportalCucumber::Config.new(
      { endpoint: "https://rp.example.com", project: "demo", api_key: "token", launch: "Context",
        launch_description: "", launch_attributes: [], retry_attempts: 1, join: false }.merge(overrides)
    )
    allow(ReportportalCucumber::Config).to receive(:load).and_return(config)
    formatter = ReportportalCucumber::Cucumber::Formatter.new(RunContextConfig.new({}))
    formatter.ingest_event(type: "test_run_started")
    yield if block_given?
    formatter.ingest_event(type: "test_run_finished", success: true)
    expect(formatter.reporting_receipt.complete).to be(true)
  ensure
    formatter&.ingest_event(type: "test_run_finished", success: true)
  end

  it "leaves the default wire metadata unchanged without invoking enrichment" do
    expect(ReportportalCucumber::Presentation::RunContext).not_to receive(:build)
    run_launch
    expect(calls.map(&:first)).to eq(%i[start finish])
    expect(calls.first.last).to include("description" => "", "attributes" => [])
    expect(calls.last.last.fetch("attributes")).to eq([])
  end

  it "sends the exact allowlisted metadata and retains it when finishing" do
    run_launch(run_context: true) { ENV["GITHUB_REF_NAME"] = "changed-after-start" }
    attributes = [
      { "key" => "sdk", "value" => ReportportalCucumber::VERSION },
      { "key" => "cucumber", "value" => Gem.loaded_specs.fetch("cucumber").version.to_s },
      { "key" => "ruby", "value" => RUBY_VERSION },
      { "key" => "git.branch", "value" => "feature/ledger" },
      { "key" => "git.sha", "value" => "e7dae2b" },
      { "key" => "ci.build", "value" => "42" }
    ]
    expect(calls.first.last.fetch("attributes")).to eq(attributes)
    expect(calls.last.last.fetch("attributes")).to eq(attributes)
    expect(calls.first.last.fetch("description"))
      .to eq("feature/ledger@e7dae2b · build 42")
  end

  it "preserves explicit attributes and descriptions with no duplicate generated keys" do
    run_launch(run_context: true, launch_description: "Given description",
               launch_attributes: [{ key: "sdk", value: "custom", system: true }])
    expect(calls.first.last.fetch("description")).to eq("Given description")
    expect(calls.first.last.fetch("attributes").select { |entry| entry["key"] == "sdk" })
      .to eq([{ "key" => "sdk", "value" => "custom", "system" => true }])
    expect(calls.last.last.fetch("attributes")).to eq(calls.first.last.fetch("attributes"))
  end

  it "uses baseline metadata at both boundaries and warns once if rendering fails" do
    allow(ReportportalCucumber::Presentation::MarkdownText).to receive(:inline).and_raise("SECRET renderer fault")
    expect(ReportportalCucumber.logger).to receive(:warn)
      .with("ReportPortal presentation failed; using baseline format").once
    run_launch(run_context: true)
    expect(calls.first.last).to include("description" => "", "attributes" => [])
    expect(calls.last.last.fetch("attributes")).to eq([])
  end

  it "uses the cached baseline and one sanitized warning if the RunContext entry point itself raises" do
    expect(ReportportalCucumber::Presentation::RunContext).to receive(:build).once.and_raise("SECRET renderer fault")
    expect(ReportportalCucumber.logger).to receive(:warn)
      .with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    run_launch(run_context: true)
    expect(calls.map(&:first)).to eq(%i[start finish])
    expect(calls.first.last).to include("description" => "", "attributes" => [])
    expect(calls.last.last.fetch("attributes")).to eq([])
  end
end
