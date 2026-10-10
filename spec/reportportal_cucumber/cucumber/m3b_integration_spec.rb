# frozen_string_literal: true

require "spec_helper"
require "digest/sha1"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "M3B stable identity and retry integration" do
  let(:root) { File.expand_path("../../..", __dir__) }
  let(:fixture_dir) { File.join(root, "spec", "fixtures", "m3b") }

  it "compares legacy and stable identities from independent Cucumber API payloads" do
    Dir.mktmpdir("m3b-integration-") do |directory|
      legacy = run_fixture(directory, "legacy-a", "variant_a.feature", "legacy")
      stable_a = run_fixture(directory, "stable-a", "variant_a.feature", "stable_v1")
      stable_b = run_fixture(directory, "stable-b", "variant_b.feature", "stable_v1")

      [legacy, stable_a, stable_b].each do |result|
        expect(result.fetch("child_stats")).to eq("5 scenarios (1 flaky, 4 passed)")
      end

      legacy_cases = scenarios(legacy)
      stable_a_cases = scenarios(stable_a)
      stable_b_cases = scenarios(stable_b)
      expect(legacy_cases.length).to eq(6)
      expect(stable_a_cases.length).to eq(6)
      expect(stable_b_cases.length).to eq(6)

      legacy_cases.each do |item|
        expected_test_case_id = legacy_test_case_id(item)
        expected_unique_id = legacy_unique_id(item)
        expect(item.fetch("testCaseId")).to eq(expected_test_case_id)
        expect(item.fetch("uniqueId")).to eq(expected_unique_id)
        expect(item.fetch("testCaseId")).not_to start_with("rp:stable-v1:")
      end

      stable_a_by_case = cases_by_key(stable_a_cases)
      stable_b_by_case = cases_by_key(stable_b_cases)
      expect(stable_a_by_case.keys).to contain_exactly(*stable_b_by_case.keys)
      stable_a_by_case.each do |key, item|
        paired = stable_b_by_case.fetch(key)
        expect(item.fetch("testCaseId")).to eq(paired.fetch("testCaseId")), "#{key}: #{item.fetch('testCaseId')} != #{paired.fetch('testCaseId')}"
        expect(item.fetch("uniqueId")).to eq(paired.fetch("uniqueId")), "#{key}: #{item.fetch('uniqueId')} != #{paired.fetch('uniqueId')}"
        expect(item.fetch("testCaseId")).to start_with("rp:stable-v1:")
        expect(item.fetch("uuid")).not_to eq(paired.fetch("uuid"))
        expect(item.fetch("codeRef")).to match(%r{#{Regexp.escape(File.join(directory, 'm3b.feature'))}:\d+\z})
        expect(paired.fetch("codeRef")).to match(%r{#{Regexp.escape(File.join(directory, 'm3b.feature'))}:\d+\z})
        expect(item.fetch("codeRef")).not_to eq(paired.fetch("codeRef"))
        expect(code_ref_line(item)).not_to eq(code_ref_line(paired)), "#{key} did not move source lines"
        expect(parameter_map(item)).to eq(parameter_map(paired))
      end

      explicit = stable_a_cases.find { |item| item.fetch("name") == "Scenario: Explicit payment identity" }
      expect(explicit.fetch("testCaseId")).to eq(stable_b_by_case.fetch("explicit").fetch("testCaseId"))
      expect(stable_a_by_case.fetch("alpha").fetch("testCaseId")).not_to eq(stable_a_by_case.fetch("beta").fetch("testCaseId"))
      %w[alpha beta].each do |name|
        expect(parameter_map(stable_a_by_case.fetch(name))).to eq(
          "amount" => name == "alpha" ? "30" : "40",
          "case" => name,
          "region" => name == "alpha" ? "north" : "south"
        )
        expect(stable_a_by_case.fetch(name).fetch("parameters").map { |parameter| parameter.fetch("key") }).to eq(%w[amount case region])
      end

      [legacy, stable_a, stable_b].each do |result|
        expect_all_item_uuids_unique(result)
        scenario_items = scenarios(result)
        expect(scenario_items.map { |item| item.fetch("uuid") }.uniq.length).to eq(scenario_items.length)
        expect(scenario_items.length).to eq(6)
        retry_attempts = scenario_items.select { |item| item.fetch("name") == "Scenario: Retry keeps case identity but separates execution" }
        expect(retry_attempts.length).to eq(2)
        expect(retry_attempts.map { |item| item.fetch("retry") }).to eq([false, true])
        expect(retry_attempts.map { |item| item.fetch("testCaseId") }.uniq.length).to eq(1)
        expect(retry_attempts.map { |item| item.fetch("uniqueId") }.uniq.length).to eq(1)
        expect(retry_attempts.map { |item| item.fetch("uuid") }.uniq.length).to eq(2)
        expect_attempt_logs_are_isolated(result, retry_attempts)
      end

      expect(legacy.fetch("suite_finish_status")).to eq("failed")
      expect(stable_a.fetch("suite_finish_status")).to eq("passed")
      expect(stable_b.fetch("suite_finish_status")).to eq("passed")

      env_override = run_fixture(
        directory, "stable-env-override", "variant_a.feature", "stable_v1",
        native_retry: false, test_case_id_override: "ENV-CASE-OVERRIDE", tag_filter: "@m3b_env_id"
      )
      env_case = scenarios(env_override).fetch(0)
      expect(env_override.fetch("child_stats")).to eq("1 scenario (1 passed)")
      expected_env_identity = ReportportalCucumber::Service::ScenarioIdentity.build(
        strategy: "stable_v1", explicit_id: "ENV-CASE-OVERRIDE", code_ref: env_case.fetch("codeRef"),
        parameters: env_case["parameters"], namespace: "m3b-acceptance"
      )
      expect(env_case.fetch("testCaseId")).to eq(expected_env_identity.test_case_id)
      expect(env_case.fetch("uniqueId")).to eq(expected_env_identity.unique_id)
    end
  end

  it "does not freeze caller-owned mutable parameter keys or values during stable identity building" do
    hash_key = +"mutable-hash-key"
    hash_value = +"mutable-hash-value"
    pair_key = +"mutable-pair-key"
    pair_value = +"mutable-pair-value"

    result = ReportportalCucumber::Service::ScenarioIdentity.build(
      strategy: "stable_v1",
      explicit_id: "M3B-MUTABILITY",
      code_ref: "unused.feature:1",
      parameters: [{ hash_key => hash_value }, { "key" => pair_key, "value" => pair_value }]
    )

    expect([hash_key, hash_value, pair_key, pair_value].map(&:frozen?)).to eq([false, false, false, false])
    [hash_key, hash_value, pair_key, pair_value].each { |string| string << "-still-mutable" }
    expect(result.parameters).to eq([
      { "key" => "mutable-hash-key", "value" => "mutable-hash-value" },
      { "key" => "mutable-pair-key", "value" => "mutable-pair-value" }
    ])
    expect(result.parameters).to be_frozen
    expect(result.parameters.all?(&:frozen?)).to be(true)
  end

  private

  def run_fixture(directory, label, fixture, strategy, native_retry: true, test_case_id_override: nil, tag_filter: nil)
    capture_path = File.join(directory, "#{label}.json")
    formatter_path = File.join(directory, "#{label}.reportportal.out")
    runner_path = File.join(directory, "#{label}_runner.rb")
    feature_path = File.join(directory, "m3b.feature")
    FileUtils.cp(File.join(fixture_dir, fixture), feature_path)
    File.write(runner_path, <<~RUBY)
      require "json"
      require "stringio"
      require "webmock"
      require "reportportal_cucumber"
      require "cucumber/cli/main"
      require #{File.join(root, "spec/support/rp_mock_server.rb").inspect}

      class M3BIntegrationKernel
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
        "--require", #{File.join(fixture_dir, "support/m3b_steps.rb").inspect},
        "--format", "progress",
        "--format", "ReportPortal::Cucumber::Formatter",
        "--out", ARGV.fetch(1),
        ARGV.fetch(2)
      ]
      args.concat(["--retry", "1"]) if ENV["M3B_NATIVE_RETRY"] == "true"
      args.concat(["--tags", ENV.fetch("M3B_TAG_FILTER")]) unless ENV.fetch("M3B_TAG_FILTER", "").empty?
      status = catch(:cucumber_exit) do
        Cucumber::Cli::Main.new(args, output, errors, M3BIntegrationKernel.new).execute!
      end
      suite = server.items.values.find { |item| item["type"] == "SUITE" }
      suite_finish = request_order.filter_map do |method, path, body|
        JSON.parse(body) if method == "put" && suite && path.end_with?("/item/\#{suite.fetch('uuid')}")
      end.last
      File.write(ARGV.fetch(0), JSON.generate(
        status: status || 0,
        stdout: output.string,
        child_stats: output.string.lines.find { |line| line.match?(/\\d+ scenarios? \\(/) }&.strip,
        stderr: errors.string,
        items: server.items,
        item_requests: server.item_requests,
        logs: server.logs,
        request_order: request_order,
        suite_finish_status: suite_finish && suite_finish["status"]
      ))
    RUBY

    child_env = {
      "RP_ENDPOINT" => "https://rp-m3b-child.example.test",
      "RP_PROJECT" => "demo",
      "RP_API_KEY" => "m3b-child-only-test-token",
      "RP_LAUNCH" => "M3B #{label}",
      "RP_CLIENT_JOIN" => "false",
      "RP_BATCH_SIZE_LOGS" => "1",
      "RP_FLUSH_INTERVAL" => "0.02",
      "RP_HTTP_RETRY_ATTEMPTS" => "1",
      "RP_IDENTITY_STRATEGY" => strategy,
      "RP_IDENTITY_ROOT" => directory,
      "RP_IDENTITY_NAMESPACE" => "m3b-acceptance",
      "RP_TEST_CASE_ID" => test_case_id_override.to_s,
      "M3B_RETRY_MARKER" => File.join(directory, "#{label}.retry-marker"),
      "M3B_NATIVE_RETRY" => native_retry.to_s,
      "M3B_TAG_FILTER" => tag_filter.to_s
    }
    stdout, stderr, process = Open3.capture3(
      child_env,
      RbConfig.ruby,
      "-I#{File.join(root, 'lib')}",
      runner_path,
      capture_path,
      formatter_path,
      feature_path,
      chdir: root
    )
    expect(process.success?).to be(true), "M3B Cucumber subprocess #{label} failed:\n#{stderr}\n#{stdout}"

    result = JSON.parse(File.read(capture_path))
    expect(result.fetch("status")).to eq(0)
    expect(result.fetch("stderr")).to be_empty
    expect(result.fetch("stdout")).to match(/scenarios? \(/)
    expect(result.fetch("child_stats")).not_to be_nil, "Missing Cucumber child stats in #{result.fetch('stdout').inspect}"
    result
  end

  def scenarios(result)
    result.fetch("items").values.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
  end

  def cases_by_key(items)
    items.to_h do |item|
      key = if item.fetch("name").include?("Explicit payment")
              "explicit"
            elsif item.fetch("name").include?("Source fallback")
              "fallback"
            elsif item.fetch("name").include?("Dataset identity")
              parameter_map(item).fetch("case")
            else
              "retry"
            end
      [key, item]
    end
  end

  def parameter_map(item)
    Array(item["parameters"]).to_h { |parameter| [parameter.fetch("key"), parameter.fetch("value")] }
  end

  def code_ref_line(item)
    item.fetch("codeRef").match(/:(\d+)\z/).captures.fetch(0).to_i
  end

  def expect_all_item_uuids_unique(result)
    requests = result.fetch("item_requests")
    starts = requests.map { |request| request.fetch("body") }
    uuids = starts.map { |body| body.fetch("uuid") }
    expect(starts.length).to eq(13)
    expect(starts.count { |body| body["type"] == "SUITE" }).to eq(1)
    expect(starts.count { |body| body["type"] == "STEP" && body["hasStats"] == true }).to eq(6)
    expect(starts.count { |body| body["type"] == "STEP" && body["hasStats"] == false }).to eq(6)
    expect(uuids.uniq.length).to eq(13), "Duplicate UUID among Suite/scenario/action starts: #{uuids.inspect}"
  end

  def explicit_id_for(item)
    item.fetch("name").include?("Explicit payment") ? "CASE-EXPLICIT-42" : nil
  end

  def legacy_test_case_id(item)
    base = explicit_id_for(item) || item.fetch("codeRef")
    pairs = Array(item["parameters"]).map do |parameter|
      [parameter.fetch("key").to_s, parameter.fetch("value").to_s]
    end
    return base if pairs.empty?

    "#{base}[#{pairs.map { |key, value| "#{key}=#{value}" }.join(',')}]"
  end

  def legacy_unique_id(item)
    normalized_parameters = item["parameters"]&.map do |parameter|
      { "key" => parameter.fetch("key").to_s, "value" => parameter.fetch("value").to_s }
    end
    Digest::SHA1.hexdigest(JSON.generate(code_ref: item.fetch("codeRef"), parameters: normalized_parameters))
  end

  def expect_attempt_logs_are_isolated(result, attempts)
    attempt_actions = attempts.map do |attempt|
      result.fetch("items").values.select do |item|
        item["parentUuid"] == attempt.fetch("uuid") && item["hasStats"] == false
      end.map { |item| item.fetch("uuid") }
    end
    logs = result.fetch("logs")

    attempts.each_with_index do |_attempt, index|
      marker = "M3B_RETRY_ATTEMPT #{index + 1}"
      marker_logs = logs.select { |log| log.fetch("message").include?(marker) }
      expect(marker_logs.length).to eq(1), "Expected one global owner for #{marker.inspect}: #{logs.inspect}"
      expect(attempt_actions[index]).to include(marker_logs.first.fetch("itemUuid")),
        "#{marker.inspect} was not owned by attempt #{index + 1}"

      other_marker = "M3B_RETRY_ATTEMPT #{2 - index}"
      other_logs = logs.select { |log| log.fetch("message").include?(other_marker) }
      expect(other_logs.length).to eq(1), "Expected one global owner for #{other_marker.inspect}: #{logs.inspect}"
      expect(attempt_actions[index]).not_to include(other_logs.first.fetch("itemUuid")),
        "#{other_marker.inspect} crossed into attempt #{index + 1}"
      expect(attempt_actions[1 - index]).to include(other_logs.first.fetch("itemUuid")),
        "#{other_marker.inspect} was not owned by the other retry attempt"
    end
  end
end
