# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "Native named hooks across retries" do
  it "retains names on both attempts, correct types and ownership, then releases the metadata" do
    root = File.expand_path("../../..", __dir__)
    Dir.mktmpdir("ledger-native-hook-retry-") do |dir|
      feature, steps, runner, capture = %w[retry.feature steps.rb runner.rb capture.json].map { |name| File.join(dir, name) }
      File.write(feature, "Feature: Hook retry names\n  Scenario: retry once\n    Given the first attempt fails\n")
      File.write(steps, <<~'RUBY')
        $attempts = 0
        Before(name: "Open browser") do
          $attempts += 1
          $runtime = ReportportalCucumber.current_runtime
          log("setup")
        end
        After(name: "Close browser") { log("teardown") }
        AfterStep(name: "Check browser") { log("checkpoint") }
        Given("the first attempt fails") { raise "expected first failure" if $attempts == 1 }
      RUBY
      File.write(runner, <<~RUBY)
        require "json"
        require "stringio"
        require "webmock"
        require "reportportal_cucumber"
        require #{File.join(root, "spec/support/rp_mock_server.rb").inspect}
        require "cucumber/cli/main"
        class HookRetryKernel
          def exit(code = 0) = throw(:cucumber_exit, code)
          def exit!(code = 0) = throw(:cucumber_exit, code)
        end
        WebMock.enable!
        WebMock.disable_net_connect!
        mock = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: ENV.fetch("RP_ENDPOINT")).install!
        feature, steps, capture = ARGV
        args = ["--no-profile", "--retry", "1", "--require", #{File.join(root, "lib/reportportal_cucumber.rb").inspect},
          "--require", steps, "--format", "ReportPortal::Cucumber::Formatter", feature]
        stdout, stderr = StringIO.new, StringIO.new
        status = catch(:cucumber_exit) { Cucumber::Cli::Main.new(args, stdout, stderr, HookRetryKernel.new).execute! } || 0
        File.write(capture, JSON.generate(status: status, attempts: $attempts, items: mock.items.values, logs: mock.logs,
          retained_hook_names: $runtime.instance_variable_get(:@hook_names).length, stderr: stderr.string))
      RUBY
      env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
        "RP_ENDPOINT" => "https://hook-names.example.test", "RP_PROJECT" => "demo", "RP_API_KEY" => "synthetic-only",
        "RP_LAUNCH" => "Hook retry", "RP_CLIENT_JOIN" => "false", "RP_HTTP_RETRY_ATTEMPTS" => "1",
        "CUCUMBER_PUBLISH_QUIET" => "true"
      )
      stdout, stderr, process = Open3.capture3(env, "perl", "-e", "alarm 30; exec @ARGV",
        RbConfig.ruby, "-I#{File.join(root, 'lib')}", runner, feature, steps, capture, chdir: root)
      expect(process.success?).to be(true), "#{stdout}\n#{stderr}"
      result = JSON.parse(File.read(capture))
      expect(result).to include("status" => 0, "attempts" => 2, "retained_hook_names" => 0)
      { "Before hook \u00b7 Open browser" => ["BEFORE_METHOD", "setup"],
        "After hook \u00b7 Close browser" => ["AFTER_METHOD", "teardown"],
        "AfterStep hook \u00b7 Check browser" => ["AFTER_METHOD", "checkpoint"] }.each do |name, (type, message)|
        hooks = result["items"].select { |item| item["name"] == name }
        expect(hooks.length).to eq(2)
        if message == "checkpoint"
          expect(hooks.map { |hook| hook["status"].downcase }).to eq(["skipped", "passed"])
        end
        hooks.each do |hook|
          expect(hook).to include("type" => type, "hasStats" => false)
          owned_logs = result["logs"].select { |log| log["itemUuid"] == hook["uuid"] }
          if hook["status"].downcase == "skipped"
            expect(owned_logs).to be_empty
          else
            expect(owned_logs).to include(hash_including("message" => message))
          end
        end
      end
    end
  end
end
