# frozen_string_literal: true

require "spec_helper"
require "reportportal_cucumber/service/scenario_links"

RSpec.describe ReportportalCucumber::Service::ScenarioLinks do
  let(:root) { "/workspace/project" }
  let(:source_template) { "https://code.example.test/repo/blob/{commit}/{path}#L{line}" }

  def build(**options)
    described_class.build(
      description: "Scenario details", feature_uri: "features/sample.feature", scenario_line: 12,
      source_url_template: source_template, source_commit: "abcdef0123456789", source_root: root,
      **options
    )
  end

  it "adds deterministic links in fixed order and chooses the example row line" do
    result = build(
      example_row_line: 27, explicit_id: "CASE 1/a",
      ci_run_url: "https://ci.example.test/run/3?view=full#results",
      tms_url_template: "https://tms.example.test/case/{id}"
    )

    expect(result.links).to eq([
      { label: "Source", url: "https://code.example.test/repo/blob/abcdef0123456789/features/sample.feature#L27" },
      { label: "CI Run", url: "https://ci.example.test/run/3?view=full#results" },
      { label: "TMS", url: "https://tms.example.test/case/CASE%201%2Fa" }
    ])
    expect(result.description).to eq(
      "Scenario details\n\n### References\n\n" \
      "[Source](<https://code.example.test/repo/blob/abcdef0123456789/features/sample.feature#L27>) | " \
      "[CI Run](<https://ci.example.test/run/3?view=full#results>) | " \
      "[TMS](<https://tms.example.test/case/CASE%201%2Fa>)"
    )
    expect(result.diagnostics).to eq([])
  end

  it "supports relative and absolute feature paths without filesystem access" do
    relative = build(feature_uri: "features/a feature.feature")
    absolute = build(feature_uri: "/workspace/project/features/a feature.feature")

    expect(relative.links.first[:url]).to include("features/a%20feature.feature")
    expect(absolute.links.first[:url]).to eq(relative.links.first[:url])
  end

  it "percent-encodes Unicode path segments and preserves separators" do
    result = build(feature_uri: "features/caf\u00e9/file.feature")

    expect(result.links.first[:url]).to include("features/caf%C3%A9/file.feature")
  end

  it "uses the scenario line if the example row line is invalid" do
    expect(build(example_row_line: nil).links.first[:url]).to end_with("#L12")
    expect(build(example_row_line: 0).links).to eq([])
    expect(build(scenario_line: "12").links).to eq([])
  end

  it "omits an invalid example source link while preserving valid sibling links" do
    result = build(
      example_row_line: "27", explicit_id: "CASE-27",
      tms_url_template: "https://tms.example.test/{id}",
      ci_run_url: "https://ci.example.test/run"
    )

    expect(result.links.map { |link| link[:label] }).to eq(["CI Run", "TMS"])
    expect(result.diagnostics).to eq([:source_unavailable])
  end

  it "rejects invalid commits, templates, placeholders, and paths without exposing values" do
    cases = [
      { source_commit: "main" },
      { source_commit: "abcdef" },
      { source_url_template: "https://code.example.test/{commit}/{path}" },
      { source_url_template: "https://{commit}.example.test/{path}/{line}" },
      { source_url_template: "https://code.example.test/{commit}/{path}/{line}/{other}" },
      { feature_uri: "../outside.feature" },
      { feature_uri: "/workspace/project/../outside.feature" },
      { feature_uri: "/workspace/project-other/a.feature" },
      { feature_uri: "C:\\project\\a.feature" },
      { feature_uri: "features/%2e%2e/a.feature" },
      { feature_uri: "features/..\\a.feature" }
    ]

    cases.each do |overrides|
      result = build(**overrides)
      expect(result.links).to eq([])
      expect(result.description).to eq("Scenario details")
      expect(result.diagnostics).to eq([:source_unavailable])
      expect(result.diagnostics.join).not_to match(/outside|abcdef|commit|secret_marker/i)
    end
  end

  it "does not infer a TMS URL from an attribute-like ID or stringify non-string IDs" do
    expect(build(explicit_id: Object.new, tms_url_template: "https://tms.example.test/{id}").links)
      .to eq(build(explicit_id: nil, tms_url_template: "https://tms.example.test/{id}").links)
    expect(build(explicit_id: "", tms_url_template: "https://tms.example.test/{id}").links)
      .to eq(build(explicit_id: nil, tms_url_template: "https://tms.example.test/{id}").links)
  end

  it "skips unsafe URLs while preserving valid sibling links" do
    result = build(
      ci_run_url: "https://user:pass@ci.example.test/run",
      tms_url_template: "https://tms.example.test/{id}", explicit_id: "T-7"
    )

    expect(result.links.map { |link| link[:label] }).to eq(%w[Source TMS])
    expect(result.diagnostics).to eq([:ci_run_url_unsafe])
    expect(result.description).not_to include("user", "pass")
  end

  it "rejects unsafe credential query names after percent decoding" do
    [
      "https://ci.example.test/run?access_token=hidden",
      "https://ci.example.test/run?%61pi%5Fkey=hidden",
      "https://ci.example.test/run?auth%6Frization=hidden",
      "https://ci.example.test/run?password=hidden",
      "https://ci.example.test/run?key=hidden",
      "https://ci.example.test/run?x-amz-signature=hidden",
      "https://ci.example.test/run?apiKey=hidden",
      "https://ci.example.test/run?accessToken=hidden",
      "https://ci.example.test/run?credentials%5Btoken%5D=hidden",
      "https://ci.example.test/run?X-Api-Key=hidden",
      "https://ci.example.test/run#access_token=hidden",
      "https://ci.example.test/run#secret=hidden",
      "https://ci.example.test/run#credentials%5Btoken%5D=hidden"
    ].each do |url|
      result = build(source_url_template: nil, ci_run_url: url)
      expect(result.links).to eq([])
      expect(result.diagnostics).to eq([:ci_run_url_unsafe])
      expect(result.description).to eq("Scenario details")
    end
  end

  it "rejects encoded controls, malformed escapes, userinfo, delimiters, and excessive input" do
    [
      "https://ci.example.test/%0Apath",
      "https://ci.example.test/%5Cpath",
      "https://ci.example.test/%00path",
      "https://ci.example.test/path%",
      "https://ci.example.test/<tag>",
      "https://ci.example.test/\"quoted\"",
      "https://ci.example.test/`code`",
      "https://user@ci.example.test/run",
      "https://ci.example.test/#{'a' * 2_049}"
    ].each do |url|
      result = build(source_url_template: nil, ci_run_url: url)
      expect(result.links).to eq([])
      expect(result.diagnostics).to eq([:ci_run_url_unsafe])
    end
  end

  it "encodes parentheses and non-ASCII URL characters for Markdown-safe output" do
    result = build(source_url_template: nil, ci_run_url: "https://ci.example.test/run(a)?q=caf\u00e9")

    expect(result.links.first[:url]).to eq("https://ci.example.test/run%28a%29?q=caf%C3%A9")
  end

  it "rejects binary strings and bounds oversized template, path, and ID inputs early" do
    binary_url = "https://ci.example.test/\xFF".b
    expect(build(source_url_template: nil, ci_run_url: binary_url).links).to eq([])
    expect(build(source_url_template: "x" * 8_193).links).to eq([])
    expect(build(feature_uri: "a" * 4_097).links).to eq([])
    long_id = build(explicit_id: "x" * 2_049, tms_url_template: "https://tms.example.test/{id}")
    expect(long_id.links.map { |link| link[:label] }).to eq(["Source"])
    expect(long_id.diagnostics).to eq([:tms_link_unavailable])
  end

  it "preserves nil, empty, and nonblank original descriptions exactly when no links survive" do
    [nil, "", "\n", "Original\n\n table | stays\n"].each do |description|
      result = described_class.build(
        description: description, feature_uri: "../outside", scenario_line: 10,
        source_url_template: source_template, source_commit: "abcdef123", source_root: root
      )
      expect(result.description).to eq(description)
    end
  end

  it "returns deeply frozen detached results and preserves original frozen input" do
    original = +"Frozen source description"
    result = build(description: original, ci_run_url: "https://ci.example.test/run")

    expect(original).not_to be_frozen
    expect(result).to be_frozen
    expect(result.description).to be_frozen
    expect(result.links).to be_frozen
    expect(result.links.first).to be_frozen
    expect(result.links.first[:url]).to be_frozen
    expect(result.diagnostics).to be_frozen
    expect { result.links.first[:label] << "!" }.to raise_error(FrozenError)
    expect(original).to eq("Frozen source description")
  end

  it "exposes only a frozen fixed diagnostic enum" do
    expect(described_class::DIAGNOSTIC_REASONS).to be_frozen
    expect(described_class::DIAGNOSTIC_REASONS).to all(be_a(Symbol))
    expect(described_class::DIAGNOSTIC_REASONS).not_to include("secret_marker")
  end
end
