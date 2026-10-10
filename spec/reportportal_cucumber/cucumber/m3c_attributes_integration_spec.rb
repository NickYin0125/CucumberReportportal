# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "M3C scenario attribute integration" do
  let(:root) { File.expand_path("../../..", __dir__) }
  let(:fixture_dir) { File.join(root, "spec", "fixtures", "m3c_attributes") }
  let(:evidence_dir) { File.join(root, "tmp", "m3c-attributes-20261007") }

  it "uses the actual AST Rule and Examples tag nodes for each executed source location" do
    metadata = ReportportalCucumber::Cucumber::AstMetadata.new
    feature = File.join(fixture_dir, "attributes.feature")
    source_lines = File.readlines(feature, chomp: true)
    line_for = ->(text) { source_lines.index(text) + 1 }

    alpha = metadata.scenario(uri: feature, location_line: line_for.call("        | alpha |"))
    beta = metadata.scenario(uri: feature, location_line: line_for.call("        | beta |"))
    explicit = metadata.scenario(uri: feature, location_line: line_for.call("    Scenario: Explicit TMS attribute"))
    retry_case = metadata.scenario(uri: feature, location_line: line_for.call("    Scenario: Retry retains attributes per execution"))

    expect(alpha.fetch(:rule_name)).to eq("Checkout API")
    expect(alpha.fetch(:tag_scopes)).to eq(
      feature: ["@component:payments", "@team:platform", "@owner:feature-owner", "@priority:low", "@unknown:ignored", "@retry:1", "@token:fixture-secret", "@password:fixture-password", "@browser:invalid:colon"],
      rule: ["@component:checkout", "@layer:api", "@priority:normal"],
      scenario: ["@component:scenario", "@owner:scenario-owner", "@layer:api", "@priority:scenario-one", "@priority:scenario-two", "@tms:CASE-M3C-EXAMPLE"],
      examples: ["@component:examples-a", "@owner:examples-owner", "@owner:conflicting-owner", "@layer:table", "@layer:table", "@priority:high"]
    )
    expect(beta.fetch(:rule_name)).to eq("Checkout API")
    expect(beta.fetch(:tag_scopes).fetch(:examples)).to eq(
      ["@component:examples-b", "@team:examples-team", "@priority:examples-one", "@priority:examples-two"]
    )
    expect(explicit.fetch(:tag_scopes).fetch(:examples)).to eq([])
    expect(retry_case.fetch(:rule_name)).to eq("Retry behavior")
    expect(retry_case.fetch(:tag_scopes).fetch(:rule)).to eq([])
  end

  it "ignores three-way conflicting defaults regardless of entry order" do
    entries = [
      { "key" => "owner", "value" => "default-one" },
      { :key => :owner, :value => "default-two" },
      { "key" => "owner", "value" => "default-three" }
    ]

    entries.permutation.each do |ordered_defaults|
      result = ReportportalCucumber::Service::ScenarioAttributes.build(
        defaults: ordered_defaults,
        tag_scopes: nil,
        allowed_keys: [:owner]
      )
      expect(result.attributes).to eq([])
      expect(result.diagnostics).to include(hash_including(reason: :conflict, scope: :default, key: "owner"))
      expect(result.diagnostics.to_s).not_to include("default-one", "default-two", "default-three")
    end
  end

  it "adds only opt-in Scenario attributes across legacy and stable identity modes" do
    FileUtils.mkdir_p(evidence_dir)
    Dir.mktmpdir("m3c-attributes-") do |directory|
      feature_path = File.join(directory, "attributes.feature")
      isolated_feature_path = File.join(directory, "isolated.feature")
      runs = {}

      %w[legacy stable_v1].each do |strategy|
        runs[[strategy, "off"]] = run_fixture(directory, feature_path, isolated_feature_path, strategy: strategy, mode: "off")
        runs[[strategy, "on"]] = run_fixture(directory, feature_path, isolated_feature_path, strategy: strategy, mode: "on")
        runs[[strategy, "changed"]] = run_fixture(directory, feature_path, isolated_feature_path, strategy: strategy, mode: "changed")
      end

      %w[legacy stable_v1].each do |strategy|
        baseline = scenario_items(runs.fetch([strategy, "off"]))
        enabled = scenario_items(runs.fetch([strategy, "on"]))
        changed = scenario_items(runs.fetch([strategy, "changed"]))
        expect(baseline.map { |item| comparable_identity(item) }.sort_by(&:to_s)).to eq(enabled.map { |item| comparable_identity(item) }.sort_by(&:to_s))
        expect(enabled.map { |item| comparable_identity(item) }.sort_by(&:to_s)).to eq(changed.map { |item| comparable_identity(item) }.sort_by(&:to_s))

        baseline.each { |item| expect(item.fetch("attributes")).to eq([]) }
        expect(enabled.length).to eq(6)
        expect(changed.length).to eq(6)
        enabled.each do |item|
          expect(item.fetch("attributes")).to eq(expected_attributes(item, changed: false))
          item.fetch("attributes").each do |attribute|
            expect(attribute.keys.sort).to eq(%w[key value])
            expect(attribute.fetch("key")).not_to eq("system")
          end
        end
        runs.fetch([strategy, "on"]).fetch("items").values.each do |item|
          next if item["type"] == "STEP" && item["hasStats"] == true

          expect(item.fetch("attributes")).to eq([])
        end
        changed.each do |item|
          expect(item.fetch("attributes")).to eq(expected_attributes(item, changed: true))
        end

        retry_attempts = enabled.select { |item| item.fetch("name") == "Scenario: Retry retains attributes per execution" }
        expect(retry_attempts.map { |item| item.fetch("retry") }).to eq([false, true])
        expect(retry_attempts.map { |item| item.fetch("testCaseId") }.uniq.length).to eq(1)
        expect(retry_attempts.map { |item| item.fetch("uniqueId") }.uniq.length).to eq(1)
        expect(retry_attempts.map { |item| item.fetch("uuid") }.uniq.length).to eq(2)
        expect_attempt_logs_are_isolated(runs.fetch([strategy, "on"]), retry_attempts)
        expect_all_item_uuids_unique(runs.fetch([strategy, "on"]))
        expect(runs.fetch([strategy, "on"]).fetch("child_stats")).to eq("5 scenarios (1 flaky, 4 passed)")
        %w[off on changed].each { |mode| expect_parent_topology(runs.fetch([strategy, mode])) }
      end

      env_precedence = run_fixture(
        directory, feature_path, isolated_feature_path, strategy: "legacy", mode: "on",
        test_case_id_override: "CASE-M3C-ENV", tag_filter: "@m3c_explicit"
      )
      expect(scenario_items(env_precedence).fetch(0).fetch("attributes")).to eq([
        { "key" => "browser", "value" => "chrome" },
        { "key" => "component", "value" => "explicit" },
        { "key" => "layer", "value" => "api" },
        { "key" => "owner", "value" => "scenario-owner" },
        { "key" => "priority", "value" => "normal" },
        { "key" => "team", "value" => "platform" },
        { "key" => "tms", "value" => "CASE-M3C-ENV" }
      ])

      custom_allowlist = run_fixture(
        directory, feature_path, isolated_feature_path, strategy: "legacy", mode: "on",
        allowed_keys: "component,custom.key", defaults: '{"custom.key":"from-default","component":"default-component"}',
        tag_filter: "@m3c_explicit"
      )
      expect(scenario_items(custom_allowlist).fetch(0).fetch("attributes")).to eq([
        { "key" => "component", "value" => "explicit" },
        { "key" => "custom.key", "value" => "from-default" }
      ])

      empty_allowlist = run_fixture(
        directory, feature_path, isolated_feature_path, strategy: "legacy", mode: "on",
        allowed_keys: "", tag_filter: "@m3c_explicit"
      )
      expect(scenario_items(empty_allowlist).fetch(0).fetch("attributes")).to eq([])
    end
  end

  private

  def run_fixture(directory, feature_path, isolated_feature_path, strategy:, mode:, test_case_id_override: nil, tag_filter: nil,
                  allowed_keys: nil, defaults: nil)
    source = File.read(File.join(fixture_dir, "attributes.feature"))
    source = source.sub("@component:examples-a", "@component:examples-changed") if mode == "changed"
    File.write(feature_path, source)
    FileUtils.cp(File.join(fixture_dir, "isolated.feature"), isolated_feature_path)

    label = [strategy, mode, test_case_id_override || "all", allowed_keys || "default"].join("-").gsub(/[^a-zA-Z0-9_-]/, "_")
    capture_path = File.join(evidence_dir, "#{label}.json")
    formatter_path = File.join(evidence_dir, "#{label}.reportportal.out")
    runner_path = File.join(directory, "#{label}_runner.rb")
    File.write(runner_path, <<~RUBY)
      require "json"
      require "stringio"
      require "webmock"
      require "reportportal_cucumber"
      require "cucumber/cli/main"
      require #{File.join(root, "spec/support/rp_mock_server.rb").inspect}

      class M3CIntegrationKernel
        def exit(code = 0); throw :cucumber_exit, code; end
        def exit!(code = 0); throw :cucumber_exit, code; end
      end

      WebMock.enable!
      WebMock.disable_net_connect!
      server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: ENV.fetch("RP_ENDPOINT")).install!
      request_order = []
      WebMock.after_request do |request, _response|
        request_order << [request.method.to_s, request.uri.path, request.body]
      end
      output = StringIO.new
      errors = StringIO.new
      args = [
        "--require", #{File.expand_path("lib/reportportal_cucumber.rb", root).inspect},
        "--require", #{File.join(fixture_dir, "support/m3c_steps.rb").inspect},
        "--format", "progress",
        "--format", "ReportPortal::Cucumber::Formatter",
        "--out", ARGV.fetch(1), ARGV.fetch(2), ARGV.fetch(3)
      ]
      args.concat(["--retry", "1"])
      args.concat(["--tags", ENV.fetch("M3C_TAG_FILTER")]) unless ENV.fetch("M3C_TAG_FILTER", "").empty?
      status = catch(:cucumber_exit) do
        Cucumber::Cli::Main.new(args, output, errors, M3CIntegrationKernel.new).execute!
      end
      File.write(ARGV.fetch(0), JSON.generate(
        status: status || 0,
        cucumber_version: Cucumber::VERSION,
        bundle_gemfile: ENV["BUNDLE_GEMFILE"],
        stdout: output.string,
        stderr: errors.string,
        child_stats: output.string.lines.find { |line| line.match?(/\\d+ scenarios? \\(/) }&.strip,
        items: server.items,
        item_requests: server.item_requests,
        logs: server.logs,
        request_order: request_order
      ))
    RUBY

    child_env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
      "RP_ENABLED" => "true",
      "RP_ENDPOINT" => "https://rp-m3c-child.example.test",
      "RP_PROJECT" => "demo",
      "RP_API_KEY" => "m3c-child-only-test-token",
      "RP_LAUNCH" => "M3C #{label}",
      "RP_CLIENT_JOIN" => "false",
      "RP_VIDEO_UPLOAD_MODE" => "reportportal_multipart",
      "RP_BATCH_SIZE_LOGS" => "1",
      "RP_FLUSH_INTERVAL" => "0.02",
      "RP_HTTP_RETRY_ATTEMPTS" => "1",
      "RP_IDENTITY_STRATEGY" => strategy,
      "RP_IDENTITY_ROOT" => directory,
      "RP_IDENTITY_NAMESPACE" => "m3c-acceptance",
      "RP_SCENARIO_ATTRIBUTES_ENABLED" => "#{mode != 'off'}",
      "RP_SCENARIO_ATTRIBUTE_KEYS" => allowed_keys || "component,team,owner,layer,priority,browser,tms",
      "RP_SCENARIO_ATTRIBUTES" => defaults || '{"component":"default-component","team":"default-team","owner":"default-owner","layer":"default-layer","priority":"default-priority","browser":"chrome","tms":"CONFIG-TMS-MUST-NOT-WIN"}',
      "RP_TEST_CASE_ID" => test_case_id_override.to_s,
      "M3C_RETRY_MARKER" => File.join(directory, "#{label}.retry-marker"),
      "M3C_TAG_FILTER" => tag_filter.to_s
    )
    stdout, stderr, process = Open3.capture3(
      child_env,
      RbConfig.ruby,
      "-I#{File.join(root, 'lib')}",
      runner_path,
      capture_path,
      formatter_path,
      feature_path,
      isolated_feature_path,
      chdir: root
    )
    expect(process.success?).to be(true), "M3C subprocess #{label} failed:\n#{stderr}\n#{stdout}"

    result = JSON.parse(File.read(capture_path))
    expect(result.fetch("status")).to eq(0)
    if (expected_version = ENV["M3C_EXPECTED_CUCUMBER_VERSION"])
      expect(result.fetch("cucumber_version")).to eq(expected_version)
    end
    if (expected_gemfile = ENV["M3C_EXPECTED_BUNDLE_GEMFILE"])
      expect(result.fetch("bundle_gemfile")).to eq(expected_gemfile)
    end
    expect(result.fetch("stderr")).to be_empty
    expect(result.fetch("stdout")).to match(/scenarios? \(/)
    result["formatter_output"] = File.file?(formatter_path) ? File.read(formatter_path) : ""
    result["host_stdout"] = stdout
    result["host_stderr"] = stderr
    forbidden_markers = [
      "fixture-secret", "fixture-password", "conflicting-owner", "scenario-one", "invalid:colon",
      "CONFIG-TMS-MUST-NOT-WIN", "m3c-child-only-test-token"
    ]
    %w[stdout stderr host_stdout host_stderr formatter_output].each do |stream|
      forbidden_markers.each do |marker|
        expect(result.fetch(stream, "").include?(marker)).to be(false),
          "Sensitive fixture value leaked to #{stream} in #{label}"
      end
    end
    File.write(capture_path, JSON.pretty_generate(result))
    result
  end

  def scenario_items(result)
    result.fetch("items").values.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
  end

  def comparable_identity(item)
    item.slice("name", "parameters", "testCaseId", "uniqueId", "retry")
  end

  def expected_attributes(item, changed:)
    attributes = {
      "Scenario: Example row alpha" => {
        "component" => changed ? "examples-changed" : "examples-a", "team" => "platform",
        "owner" => "scenario-owner", "layer" => "table", "priority" => "high"
      },
      "Scenario: Example row beta" => {
        "component" => "examples-b", "team" => "examples-team", "owner" => "scenario-owner",
        "layer" => "api", "priority" => "normal"
      },
      "Scenario: Explicit TMS attribute" => {
        "component" => "explicit", "team" => "platform", "owner" => "scenario-owner",
        "layer" => "api", "priority" => "normal"
      },
      "Scenario: Retry retains attributes per execution" => {
        "component" => "retry", "team" => "platform", "owner" => "retry-owner",
        "layer" => "default-layer", "priority" => "low"
      },
      "Scenario: Attributes stay within their feature" => {
        "component" => "isolated", "team" => "second-feature", "owner" => "second-feature",
        "layer" => "default-layer", "priority" => "default-priority"
      }
    }.fetch(item.fetch("name"))
    attributes["browser"] = "chrome"
    attributes["tms"] = item.fetch("name").include?("Example row") ? "CASE-M3C-EXAMPLE" :
      (item.fetch("name").include?("Explicit") ? "CASE-M3C-EXPLICIT" : nil)
    attributes.compact.sort.map { |key, value| { "key" => key, "value" => value } }
  end

  def expect_all_item_uuids_unique(result)
    starts = result.fetch("item_requests").map { |request| request.fetch("body") }
    uuids = starts.map { |body| body.fetch("uuid") }
    expect(uuids.uniq.length).to eq(uuids.length)
    expect(starts.count { |body| body["type"] == "SUITE" }).to eq(2)
    expect(starts.count { |body| body["type"] == "STEP" && body["hasStats"] == true }).to eq(6)
  end

  def expect_parent_topology(result)
    items = result.fetch("items").values
    suites = items.select { |item| item["type"] == "SUITE" }
    scenarios = items.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
    actions = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
    suite_names = {
      "attributes.feature" => "Feature: M3C scenario attributes",
      "isolated.feature" => "Feature: M3C second feature isolation"
    }

    expect(suites.map { |suite| suite.fetch("name") }).to contain_exactly(*suite_names.values)
    scenarios.each do |scenario|
      feature_uri = scenario.fetch("codeRef").sub(/:\d+\z/, "")
      suite_name = suite_names.fetch(File.basename(feature_uri))
      suite = suites.find { |candidate| candidate.fetch("name") == suite_name }
      expect(scenario.fetch("parentUuid")).to eq(suite.fetch("uuid"))
    end
    scenario_uuids = scenarios.map { |scenario| scenario.fetch("uuid") }
    actions.each { |action| expect(scenario_uuids).to include(action.fetch("parentUuid")) }
  end

  def expect_attempt_logs_are_isolated(result, retry_attempts)
    retry_attempts.each do |attempt|
      expected_marker = attempt.fetch("retry") ? "M3C_RETRY_ATTEMPT 2" : "M3C_RETRY_ATTEMPT 1"
      action = result.fetch("items").values.find do |item|
        item["type"] == "STEP" && item["hasStats"] == false && item["parentUuid"] == attempt.fetch("uuid")
      end
      expect(action).not_to be_nil
      logs = result.fetch("logs").select { |entry| entry.fetch("itemUuid") == action.fetch("uuid") }
      expect(logs.map { |entry| entry.fetch("message") }).to include(expected_marker)
      expect(logs.map { |entry| entry.fetch("message") }).not_to include(
        attempt.fetch("retry") ? "M3C_RETRY_ATTEMPT 1" : "M3C_RETRY_ATTEMPT 2"
      )
    end
  end
end
