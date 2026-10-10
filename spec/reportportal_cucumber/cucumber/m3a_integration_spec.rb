# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "M3A AST metadata and runtime arguments" do
  let(:root) { File.expand_path("../../..", __dir__) }
  let(:fixture_dir) { File.join(root, "spec", "fixtures", "m3a") }

  it "runs English and zh-CN features through Cucumber and verifies ReportPortal payloads" do
    Dir.mktmpdir("m3a-integration-") do |directory|
      evidence_dir = File.join(root, "tmp", "m3a-20261006")
      FileUtils.mkdir_p(evidence_dir)
      capture_path = File.join(evidence_dir, "mock-api.json")
      formatter_output = File.join(evidence_dir, "reportportal-formatter.out")
      runner_path = File.join(directory, "run_cucumber.rb")
      File.write(runner_path, <<~RUBY)
        require "json"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require "cucumber/cli/main"
        require #{File.join(root, "spec/support/rp_mock_server.rb").inspect}

        class M3AIntegrationKernel
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
          "--require", #{File.join(fixture_dir, "support/m3a_steps.rb").inspect},
          "--format", "progress",
          "--format", "ReportPortal::Cucumber::Formatter",
          "--out", ARGV.fetch(1),
          #{File.join(fixture_dir, "english.feature").inspect},
          #{File.join(fixture_dir, "zh-CN.feature").inspect}
        ]
        status = catch(:cucumber_exit) do
          Cucumber::Cli::Main.new(args, output, errors, M3AIntegrationKernel.new).execute!
        end
        File.write(ARGV.fetch(0), JSON.generate(
          status: status || 0,
          stdout: output.string,
          stderr: errors.string,
          launches: server.launches,
          items: server.items,
          logs: server.logs,
          item_requests: server.item_requests,
          request_order: request_order
        ))
      RUBY

      child_env = {
        "RP_ENDPOINT" => "https://rp-m3a-child.example.test",
        "RP_PROJECT" => "demo",
        "RP_API_KEY" => "m3a-child-only-test-token",
        "RP_LAUNCH" => "M3A metadata integration",
        "RP_CLIENT_JOIN" => "false",
        "RP_BATCH_SIZE_LOGS" => "1",
        "RP_FLUSH_INTERVAL" => "0.05",
        "RP_HTTP_RETRY_ATTEMPTS" => "1"
      }
      stdout, stderr, process = Open3.capture3(
        child_env,
        RbConfig.ruby,
        "-I#{File.join(root, 'lib')}",
        runner_path,
        capture_path,
        formatter_output,
        chdir: root
      )
      expect(process.success?).to be(true), "M3A Cucumber subprocess failed:\n#{stderr}\n#{stdout}"

      result = JSON.parse(File.read(capture_path))
      expect(result.fetch("status")).to eq(0)
      expect(result.fetch("stderr")).to be_empty
      expect(result.fetch("stdout")).to include("8 scenarios")
      items = result.fetch("items").values
      suites = items.select { |item| item["type"] == "SUITE" && item["hasStats"] == true }
      scenarios = items.select { |item| item["type"] == "STEP" && item["hasStats"] == true }
      actions = items.select { |item| item["type"] == "STEP" && item["hasStats"] == false }
      expect(suites.length).to eq(2)
      expect(scenarios.length).to eq(8)
      expect(actions.length).to eq(40)
      expect(items.length).to eq(50)
      expect(items.map { |item| item.fetch("uuid") }.uniq.length).to eq(items.length)

      english_uri = File.join(fixture_dir, "english.feature")
      chinese_uri = File.join(fixture_dir, "zh-CN.feature")
      english_suite = suites.find { |item| item.fetch("name").include?("M3A English metadata fixture") }
      chinese_suite = suites.find { |item| item.fetch("name").include?("M3A 中文元数据夹具") }
      expect(english_suite).not_to be_nil
      expect(chinese_suite).not_to be_nil
      expect(english_suite.fetch("name")).to include("M3A English metadata fixture")
      expect(english_suite.fetch("description")).to include("Feature description line one.", "Feature description line two")
      expect(chinese_suite.fetch("name")).to include("M3A 中文元数据夹具")
      expect(chinese_suite.fetch("description")).to include("功能描述第一行。", "功能描述第二行。")

      english_cases = scenarios.select { |item| item.fetch("codeRef").include?("english.feature") }
      chinese_cases = scenarios.select { |item| item.fetch("codeRef").include?("zh-CN.feature") }
      expect(english_cases.length).to eq(5)
      expect(chinese_cases.length).to eq(3)
      expect(english_cases.map { |item| item.fetch("parentUuid") }.uniq).to eq([english_suite.fetch("uuid")])
      expect(chinese_cases.map { |item| item.fetch("parentUuid") }.uniq).to eq([chinese_suite.fetch("uuid")])

      english_case = english_cases.find { |item| item.fetch("name") == "Scenario: English ordinary case" }
      expect(english_case.fetch("description")).to include("English rule metadata", "Rule description belongs to the case context", "Ordinary scenario description")
      expect(english_case.fetch("description")).not_to include("Feature description")
      chinese_case = chinese_cases.find { |item| item.fetch("name") == "Scenario: 中文普通用例" }
      expect(chinese_case.fetch("description")).to include("中文规则元数据", "规则描述属于用例上下文", "普通场景描述")

      expected_rows = {
        "English outlined case alpha" => { "record" => "alpha", "value" => "first", "template" => "token-a" },
        "English outlined case beta" => { "record" => "beta", "value" => "second", "template" => "token-b" },
        "English outlined case gamma" => { "record" => "gamma", "value" => "third", "template" => "token-c" },
        "English outlined case delta" => { "record" => "delta", "value" => "fourth", "template" => "token-d" },
        "中文示例用例 一组" => { "record" => "一组", "value" => "first", "template" => "token-1" },
        "中文示例用例 二组" => { "record" => "二组", "value" => "second", "template" => "token-2" }
      }
      expect(actions.map { |item| item.fetch("parentUuid") }.uniq.sort).to eq(scenarios.map { |item| item.fetch("uuid") }.sort)
      executed_action_text = actions.map { |item| [item.fetch("name"), item["description"]].compact.join("\n") }.join("\n")
      expect(executed_action_text).not_to include("<record>", "<value>", "<template>")
      rich_actions = actions.select do |item|
        item.fetch("name").match?(/M3A table|M3A document|M3A 表格|M3A 文档/)
      end
      expect(rich_actions.length).to eq(16)
      rich_logs = rich_actions.to_h do |item|
        matching = result.fetch("logs").select { |entry| entry.fetch("itemUuid") == item.fetch("uuid") }
        expect(matching.length).to eq(1), "Expected exactly one rich log for #{item.fetch('name').inspect}"
        [item.fetch("uuid"), matching.first]
      end
      expect(rich_logs.values.map { |entry| entry.fetch("message") }.join("\n")).not_to include("<record>", "<value>", "<template>")

      expected_rows.each do |name, expected|
        item = scenarios.find { |scenario| scenario.fetch("name") == "Scenario: #{name}" }
        expect(item).not_to be_nil, "Missing scenario #{name.inspect}"
        expect(item.fetch("parameters").map { |parameter| parameter.fetch("key") }).to eq(%w[record value template])
        expect(item.fetch("parameters").to_h { |parameter| [parameter.fetch("key"), parameter.fetch("value")] }).to eq(expected)
        expect(item.fetch("description")).to include(expected.fetch("record"), expected.fetch("value"), expected.fetch("template"))
        scenario_actions = actions.select { |action| action.fetch("parentUuid") == item.fetch("uuid") }
        table_step = scenario_actions.find { |action| action.fetch("name").match?(/M3A table|M3A 表格/) }
        document_step = scenario_actions.find { |action| action.fetch("name").match?(/M3A document|M3A 文档/) }
        expect(table_step).not_to be_nil
        expect(document_step).not_to be_nil
        expected_action_name = if name.start_with?("中文")
                                 "当 我验证 M3A 表格 \"#{expected.fetch('record')}\":"
                               else
                                 "When I verify the M3A table for \"#{expected.fetch('record')}\":"
                               end
        expect(table_step.fetch("name")).to eq(expected_action_name)
        expect(rich_logs.fetch(table_step.fetch("uuid")).fetch("message")).to include(expected.fetch("record"), expected.fetch("value"), "A\\|B")
        document_log = rich_logs.fetch(document_step.fetch("uuid")).fetch("message")
        expect(document_log).to include("\"record\": \"#{expected.fetch('record')}\"", "\"template\": \"#{expected.fetch('template')}\"")
      end

      table_action = actions.find { |item| item.fetch("name").include?("verify the M3A table") }
      document_action = actions.find { |item| item.fetch("name").include?("verify the M3A document") }
      expect(table_action).not_to be_nil
      expect(document_action).not_to be_nil
      table_markdown = rich_logs.fetch(table_action.fetch("uuid")).fetch("message")
      document_markdown = rich_logs.fetch(document_action.fetch("uuid")).fetch("message")
      expect(table_markdown).to include("| key | value | escaped | newline | trailing |", "| ordinary | plain | A\\|B | line<br>next |  |")
      expect(document_markdown).to include("````json", "line one\\nline two", "path\\\\leaf", "\"fence\": \"```json\"")

      english_ordinary_actions = actions.select do |item|
        item.fetch("parentUuid") == english_case.fetch("uuid") && item.fetch("name").include?("shared M3A context")
      end
      expect(english_ordinary_actions.length).to eq(2)
      expect(english_ordinary_actions.count { |item| item.fetch("name").start_with?("[Background]") }).to eq(1)
      expect(english_ordinary_actions.count { |item| !item.fetch("name").start_with?("[Background]") }).to eq(1)
      scenarios.each do |scenario|
        scenario_actions = actions.select { |item| item.fetch("parentUuid") == scenario.fetch("uuid") }
        expect(scenario_actions.count { |item| item.fetch("name").start_with?("[Background]") }).to eq(2)
      end

      launch = result.fetch("launches").values.fetch(0)
      expect(launch.fetch("statistics").dig("executions", "total")).to eq(8)
      expect(launch.fetch("statistics").dig("executions", "passed")).to eq(8)
      expect(launch.fetch("statistics").dig("executions", "total")).to eq(8)
      expect(launch.fetch("status")).to eq("PASSED")
      finish_paths = result.fetch("request_order").each_index.select { |index| result.fetch("request_order")[index][1].end_with?("/finish") }
      expect(finish_paths.length).to eq(1)
      finish_index = finish_paths.first
      item_finish_indexes = result.fetch("request_order").each_index.select do |index|
        method, path, = result.fetch("request_order")[index]
        method == "put" && path.match?(%r{/item/[^/]+\z})
      end
      expect(item_finish_indexes.length).to eq(items.length)
      rich_logs.each_value do |entry|
        log_index = result.fetch("request_order").index do |method, path, body|
          method == "post" && path.end_with?("/log") && JSON.parse(body).fetch("itemUuid") == entry.fetch("itemUuid")
        end
        item = actions.find { |candidate| candidate.fetch("uuid") == entry.fetch("itemUuid") }
        finish_index_for_item = result.fetch("request_order").index { |method, path| method == "put" && path.end_with?("/item/#{item.fetch('uuid')}") }
        expect(log_index).not_to be_nil
        expect(finish_index_for_item).not_to be_nil
        expect(log_index).to be < finish_index_for_item
      end

      expect(english_uri).to end_with("english.feature")
      expect(chinese_uri).to end_with("zh-CN.feature")
    end
  end

  it "falls back safely when the AST source is unavailable" do
    metadata = ReportportalCucumber::Cucumber::AstMetadata.new(ast_lookup: nil)
    expect(metadata.feature(uri: "/missing/m3a.feature")).to be_nil
    expect(metadata.scenario(uri: "/missing/m3a.feature", location_line: 1)).to be_nil
    expect(metadata.step(Object.new)).to be_nil
  end
end
