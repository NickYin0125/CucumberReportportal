# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "M3C scenario link integration" do
  let(:root) { File.expand_path("../../..", __dir__) }
  let(:fixture_dir) { File.join(root, "spec", "fixtures", "m3c_links") }
  let(:evidence_dir) { ENV["M3C_LINKS_EVIDENCE_DIR"] || File.join(root, "tmp", "m3c-links-20261007") }

  it "adds only opt-in references at the same source path under legacy and stable identities" do
    FileUtils.mkdir_p(evidence_dir)
    Dir.mktmpdir("m3c-links-") do |directory|
      feature_path = File.join(directory, "checkout links.feature")
      isolated_path = File.join(directory, "isolated links.feature")
      results = {}

      %w[legacy stable_v1].each do |strategy|
        %w[off on changed].each do |mode|
          results[[strategy, mode]] = run_fixture(
            directory, feature_path, isolated_path, strategy: strategy, mode: mode
          )
        end
      end

      %w[legacy stable_v1].each do |strategy|
        off = results.fetch([strategy, "off"])
        on = results.fetch([strategy, "on"])
        changed = results.fetch([strategy, "changed"])
        off_scenarios = scenarios(off)
        on_scenarios = scenarios(on)
        changed_scenarios = scenarios(changed)

        expect(off_scenarios.map { |item| comparable_item(item) }.sort_by(&:to_s)).to eq(
          on_scenarios.map { |item| comparable_item(item) }.sort_by(&:to_s)
        )
        expect(on_scenarios.map { |item| comparable_item(item) }.sort_by(&:to_s)).to eq(
          changed_scenarios.map { |item| comparable_item(item) }.sort_by(&:to_s)
        )
        expect(off_scenarios).to all(satisfy { |item| item.fetch("attributes").is_a?(Array) })
        expect(on_scenarios.length).to eq(6)
        expect(changed_scenarios.length).to eq(6)

        on_scenarios.each do |item|
          description = item.fetch("description")
          original = strip_references(description)
          expect(original).to eq(off_scenarios.find { |candidate| candidate.fetch("name") == item.fetch("name") && candidate.fetch("retry") == item.fetch("retry") }.fetch("description"))
          expect(original).to include("Rule description remains before generated references.") if item.fetch("name").include?("Link example")
          if item.fetch("name").include?("Link example")
            expected_row = item.fetch("name").include?("alpha") ? "| alpha |" : "| beta |"
            expect(original).to include("Scenario-specific outline prose remains unchanged.", "| outline | preserved |", expected_row)
          elsif item.fetch("name").include?("Explicit TMS")
            expect(original).to include("Explicit Scenario prose remains unchanged.")
          elsif item.fetch("name").include?("Flaky retry")
            expect(original).to include("Retry Scenario prose remains unchanged.")
          else
            expect(original).to include("Isolated Scenario prose remains unchanged.")
          end
          expect(original).not_to include("Feature prose belongs to the Suite")

          expected_source = expected_source_url(item, feature_path)
          expect(description).to include("[Source](<#{expected_source}>)")
          expect(description).to include("[CI Run](<https://ci.example.test/jobs/42>)")
          expect(description).to include("[TMS](<#{expected_tms_url(item)}>)") if expected_tms_url(item)
          expected_refs = ["[Source](<#{expected_source}>)", "[CI Run](<https://ci.example.test/jobs/42>)"]
          expected_refs << "[TMS](<#{expected_tms_url(item)}>)" if expected_tms_url(item)
          expect(description).to end_with("### References\n\n#{expected_refs.join(' | ')}")
          expect(description.scan(/\[Source\]\(/).length).to eq(1)
          expect(description.scan(/\[CI Run\]\(/).length).to eq(1)
          expect(description.scan(/\[TMS\]\(/).length).to eq(expected_tms_url(item) ? 1 : 0)
        end

        expect(changed_scenarios.map { |item| strip_references(item.fetch("description")) }.sort).to eq(
          on_scenarios.map { |item| strip_references(item.fetch("description")) }.sort
        )
        changed_scenarios.each do |item|
          expect(item.fetch("description")).to include(expected_source_url(item, feature_path, changed: true))
          expect(item.fetch("description")).to include("[CI Run](<https://ci-changed.example.test/jobs/43>)")
          tms = expected_tms_url(item, changed: true)
          expect(item.fetch("description")).to include("[TMS](<#{tms}>)") if tms
        end

        [off, on, changed].each do |capture|
          expect(capture.fetch("items").values.none? { |item| item.key?("links") }).to be(true)
          expect(capture.fetch("item_requests").none? { |request| request.fetch("body").key?("links") }).to be(true)
          expect(capture.fetch("logs").none? { |entry| entry.fetch("message", "").include?("References") }).to be(true)
        end
        expect(on.fetch("child_stats")).to eq("5 scenarios (1 flaky, 4 passed)")
        expect_retry_logs(on)
        expect_parent_topology(off)
        expect_parent_topology(on)
        expect_parent_topology(changed)
        expect_non_description_wire_unchanged(off, on)
        expect_non_description_wire_unchanged(on, changed)
        expect_non_scenario_items_have_no_references(on)
        expect(off.fetch("items").values.none? { |item| item.fetch("description", "").include?("### References") }).to be(true)
        expect_attributes_unchanged(off, on, changed)
        expect_retry_identity_and_uuids(off, on, changed)
      end

      tms_precedence = run_fixture(
        directory, feature_path, isolated_path, strategy: "legacy", mode: "on", test_case_id_override: "CASE ENV/42"
      )
      explicit = scenarios(tms_precedence).find { |item| item.fetch("name") == "Scenario: Explicit TMS selection" }
      expect(explicit.fetch("description")).to include(
        "[TMS](<https://tms.example.test/cases/CASE%20ENV%2F42>)"
      )
      expect(explicit.fetch("description")).not_to include("CASE-TAG-SHOULD-LOSE")

      no_id = scenarios(results.fetch(["legacy", "on"])).find { |item| item.fetch("name") == "Scenario: No explicit TMS ID" }
      expect(no_id.fetch("description")).not_to include("[TMS]")
    end
  end

  it "skips unsafe configured URLs without leaking inputs and retains valid sibling links" do
    FileUtils.mkdir_p(evidence_dir)
    Dir.mktmpdir("m3c-links-invalid-") do |directory|
      feature_path = File.join(directory, "checkout links.feature")
      isolated_path = File.join(directory, "isolated links.feature")
      result = run_fixture(
        directory, feature_path, isolated_path, strategy: "legacy", mode: "mixed-invalid",
        test_case_id_override: "CASE/SAFE-8"
      )

      descriptions = scenarios(result).map { |item| item.fetch("description", "") }
      expect(descriptions).to all(include("[TMS](<https://tms.example.test/cases/CASE%2FSAFE-8>)"))
      expect(descriptions.join).not_to include("[Source]", "[CI Run]")
      expect(result.fetch("items").values.none? { |item| item.key?("links") }).to be(true)
      expect(result.fetch("stdout")).not_to include("credential-marker", "secret-marker")
      expect(result.fetch("stderr")).not_to include("credential-marker", "secret-marker")
      expect(result.fetch("formatter_output")).not_to include("credential-marker", "secret-marker")
    end
  end

  private

  def run_fixture(directory, feature_path, isolated_path, strategy:, mode:, test_case_id_override: nil)
    FileUtils.cp(File.join(fixture_dir, "links.feature"), feature_path)
    FileUtils.cp(File.join(fixture_dir, "isolated.feature"), isolated_path)

    label = [strategy, mode, test_case_id_override || "none"].join("-").gsub(/[^a-zA-Z0-9_-]/, "_")
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

      class M3CLinksIntegrationKernel
        def exit(code = 0); throw :cucumber_exit, code; end
        def exit!(code = 0); throw :cucumber_exit, code; end
      end

      WebMock.enable!
      WebMock.disable_net_connect!
      server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: ENV.fetch("RP_ENDPOINT")).install!
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
      status = catch(:cucumber_exit) do
        Cucumber::Cli::Main.new(args, output, errors, M3CLinksIntegrationKernel.new).execute!
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
        logs: server.logs
      ))
    RUBY

    invalid = mode == "mixed-invalid"
    child_env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
      "RP_ENABLED" => "true",
      "RP_ENDPOINT" => "https://rp-m3c-links-child.example.test",
      "RP_PROJECT" => "demo",
      "RP_API_KEY" => "m3c-links-child-test-token",
      "RP_LAUNCH" => "M3C links #{label}",
      "RP_CLIENT_JOIN" => "false",
      "RP_VIDEO_UPLOAD_MODE" => "reportportal_multipart",
      "RP_BATCH_SIZE_LOGS" => "1",
      "RP_FLUSH_INTERVAL" => "0.02",
      "RP_HTTP_RETRY_ATTEMPTS" => "1",
      "RP_IDENTITY_STRATEGY" => strategy,
      "RP_IDENTITY_ROOT" => directory,
      "RP_IDENTITY_NAMESPACE" => "m3c-links-acceptance",
      "RP_SCENARIO_LINKS_ENABLED" => "#{mode != 'off'}",
      "RP_SCENARIO_ATTRIBUTES_ENABLED" => "true",
      "RP_SCENARIO_ATTRIBUTE_KEYS" => "component,team,owner,layer,priority,browser,tms",
      "RP_SCENARIO_ATTRIBUTES" => '{"component":"configured-component","team":"configured-team"}',
      "RP_SOURCE_URL_TEMPLATE" => invalid ? "https://user:credential-marker@source.example.test/{path}?line={line}&commit={commit}" :
        (mode == "changed" ? "https://source-changed.example.test/repo/blob/{commit}/{path}?line={line}" :
          "https://source.example.test/repo/blob/{commit}/{path}?line={line}"),
      "RP_SOURCE_COMMIT" => mode == "changed" ? "abcdef0123456789abcdef0123456789abcdef01" : "0123456789abcdef0123456789abcdef01234567",
      "RP_SOURCE_ROOT" => directory,
      "RP_CI_RUN_URL" => invalid ? "https://ci.example.test/run?access_token=secret-marker" :
        (mode == "changed" ? "https://ci-changed.example.test/jobs/43" : "https://ci.example.test/jobs/42"),
      "RP_TMS_URL_TEMPLATE" => mode == "changed" ? "https://tms-changed.example.test/tickets/{id}" : "https://tms.example.test/cases/{id}",
      "RP_TEST_CASE_ID" => test_case_id_override.to_s,
      "M3C_LINK_RETRY_MARKER" => File.join(directory, "#{label}.retry-marker")
    )
    stdout, stderr, process = Open3.capture3(
      child_env,
      RbConfig.ruby,
      "-I#{File.join(root, 'lib')}",
      runner_path,
      capture_path,
      formatter_path,
      feature_path,
      isolated_path,
      chdir: root
    )
    expect(process.success?).to be(true), "M3C links subprocess #{label} failed:\n#{stderr}\n#{stdout}"

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
    ["m3c-links-child-test-token", "CASE-TAG-SHOULD-LOSE"].each do |marker|
      %w[stdout stderr host_stdout host_stderr formatter_output].each do |stream|
        expect(result.fetch(stream, "")).not_to include(marker), "Sensitive value leaked to #{stream} in #{label}"
      end
    end
    ["credential-marker", "secret-marker"].each do |marker|
      expect(JSON.generate(result)).not_to include(marker), "Unsafe URL input leaked into captured request evidence in #{label}"
    end
    File.write(capture_path, JSON.pretty_generate(result))
    result
  end

  def scenarios(result)
    result.fetch("items").values.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
  end

  def comparable_item(item)
    item.reject { |key, _value| key == "description" }.slice(
      "name", "parameters", "codeRef", "testCaseId", "uniqueId", "retry", "type", "hasStats", "attributes"
    )
  end

  def strip_references(description)
    description.sub(/\n\n### References\n\n.*\z/m, "")
  end

  def expected_source_url(item, feature_path, changed: false)
    path = File.basename(item.fetch("codeRef").sub(/:\d+\z/, "")).gsub(" ", "%20")
    line = if item.fetch("name").include?("Link example alpha")
             fixture_line("links.feature", "        | alpha |")
           elsif item.fetch("name").include?("Link example beta")
             fixture_line("links.feature", "        | beta |")
           elsif item.fetch("name").include?("No explicit TMS ID")
             fixture_line("isolated.feature", "  Scenario: No explicit TMS ID")
           else
             fixture_line("links.feature", "    Scenario: #{item.fetch('name').delete_prefix('Scenario: ')}")
           end
    commit = changed ? "abcdef0123456789abcdef0123456789abcdef01" : "0123456789abcdef0123456789abcdef01234567"
    base = changed ? "https://source-changed.example.test/repo/blob" : "https://source.example.test/repo/blob"
    "#{base}/#{commit}/#{path}?line=#{line}"
  end

  def fixture_line(file, exact_line)
    File.readlines(File.join(fixture_dir, file), chomp: true).index(exact_line) + 1
  end

  def expected_tms_url(item, changed: false)
    base = changed ? "https://tms-changed.example.test/tickets/" : "https://tms.example.test/cases/"
    case item.fetch("name")
    when "Scenario: Explicit TMS selection"
      "#{base}CASE-TAG-SHOULD-LOSE"
    when "Scenario: Flaky retry link"
      "#{base}CASE-RETRY-7"
    when /Link example/
      "#{base}CASE-OUTLINE-42"
    end
  end

  def expect_attributes_unchanged(*results)
    baseline = scenarios(results.first).map { |item| [item.fetch("name"), item.fetch("retry"), item.fetch("attributes")] }.sort_by(&:to_s)
    results.drop(1).each do |result|
      expect(scenarios(result).map { |item| [item.fetch("name"), item.fetch("retry"), item.fetch("attributes")] }.sort_by(&:to_s)).to eq(baseline)
    end
    expect(baseline.flat_map(&:last)).not_to be_empty
    outline = scenarios(results.first).find { |item| item.fetch("name") == "Scenario: Link example alpha" }
    expect(outline.fetch("attributes")).to include(
      { "key" => "component", "value" => "payments" },
      { "key" => "team", "value" => "platform" }
    )
    isolated = scenarios(results.first).find { |item| item.fetch("name") == "Scenario: No explicit TMS ID" }
    expect(isolated.fetch("attributes")).to include(
      { "key" => "component", "value" => "configured-component" },
      { "key" => "team", "value" => "configured-team" }
    )
  end

  def expect_non_description_wire_unchanged(before, after)
    expect(normalized_item_requests(before)).to eq(normalized_item_requests(after))
  end

  def normalized_item_requests(result)
    result.fetch("item_requests").map do |request|
      body = request.fetch("body").reject do |key, _value|
        %w[description uuid launchUuid startTime parentUuid].include?(key)
      end
      expect(request.fetch("body")).not_to have_key("links")
      route = request.fetch("path").sub(%r{(/item)/[^/]+\z}, '\\1/<parent>')
      [route, body]
    end.sort_by(&:to_s)
  end

  def expect_retry_logs(result)
    attempts = scenarios(result).select { |item| item.fetch("name") == "Scenario: Flaky retry link" }
    expect(attempts.map { |item| item.fetch("retry") }).to eq([false, true])
    attempts.each do |attempt|
      marker = attempt.fetch("retry") ? "M3C_LINK_RETRY_ATTEMPT 2" : "M3C_LINK_RETRY_ATTEMPT 1"
      action = result.fetch("items").values.find do |item|
        item["type"] == "STEP" && item["hasStats"] == false && item["parentUuid"] == attempt.fetch("uuid")
      end
      expect(action).not_to be_nil
      logs = result.fetch("logs").select { |entry| entry.fetch("itemUuid") == action.fetch("uuid") }
      expect(logs.map { |entry| entry.fetch("message") }).to include(marker)
      expect(logs.map { |entry| entry.fetch("message") }).not_to include(
        attempt.fetch("retry") ? "M3C_LINK_RETRY_ATTEMPT 1" : "M3C_LINK_RETRY_ATTEMPT 2"
      )
    end
  end

  def expect_parent_topology(result)
    items = result.fetch("items").values
    suites = items.select { |item| item["type"] == "SUITE" }
    scenarios = scenarios(result)
    actions = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
    expect(suites.length).to eq(2)
    expect(suites.find { |item| item.fetch("name") == "Feature: M3C isolated link suite" }.fetch("description")).to include(
      "Feature prose belongs to the Suite"
    )
    scenarios.each do |scenario|
      feature_path = scenario.fetch("codeRef").sub(/:\d+\z/, "")
      expected_suite = suites.find { |suite| suite.fetch("name") == "Feature: M3C #{File.basename(feature_path).start_with?("isolated") ? "isolated link suite" : "scenario link presentation"}" }
      expect(expected_suite).not_to be_nil
      request = result.fetch("item_requests").find { |entry| entry.dig("body", "uuid") == scenario.fetch("uuid") }
      expect(request.fetch("path")).to end_with("/item/#{expected_suite.fetch('uuid')}")
      expect(scenario.fetch("parentUuid")).to eq(expected_suite.fetch("uuid"))
    end
    scenario_uuids = scenarios.map { |scenario| scenario.fetch("uuid") }
    actions.each { |action| expect(scenario_uuids).to include(action.fetch("parentUuid")) }
  end

  def expect_non_scenario_items_have_no_references(result)
    scenarios = scenarios(result).map { |item| item.fetch("uuid") }
    result.fetch("items").values.reject { |item| scenarios.include?(item.fetch("uuid")) }.each do |item|
      expect(item.fetch("description", "")).not_to include("### References")
    end
  end

  def expect_retry_identity_and_uuids(*results)
    retry_sets = results.map do |result|
      scenarios(result).select { |item| item.fetch("name") == "Scenario: Flaky retry link" }
    end
    retry_sets.each do |attempts|
      expect(attempts.map { |item| item.fetch("uuid") }.uniq.length).to eq(2)
      expect(attempts.map { |item| item.fetch("testCaseId") }.uniq.length).to eq(1)
      expect(attempts.map { |item| item.fetch("uniqueId") }.uniq.length).to eq(1)
    end
    retry_sets.drop(1).each do |attempts|
      expect(attempts.map { |item| item.slice("name", "testCaseId", "uniqueId", "retry") }).to eq(
        retry_sets.first.map { |item| item.slice("name", "testCaseId", "uniqueId", "retry") }
      )
    end
    results.each do |result|
      uuids = result.fetch("item_requests").map { |request| request.fetch("body").fetch("uuid") }
      expect(uuids.uniq.length).to eq(uuids.length)
    end
  end
end
