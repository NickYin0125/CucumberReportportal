# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "Default Cucumber duration isolation" do
  it "loads the ordinary default profile without starting a listener, registering cleanup or changing mock settings" do
    root = File.expand_path("../..", __dir__)
    code = <<~'RUBY'
      require "bundler/setup"
      require "cucumber/cli/main"
      require "json"
      require "stringio"
      root = ARGV.shift
      ARGV << "features/duration"
      %w[CLEARING_MOCK_AUTOSTART CLEARING_MOCK_DISABLED CLEARING_MOCK_URL DURATION_REGRESSION_SMOKE].each { |key| ENV.delete(key) }
      before = ENV.select { |key, _| key.start_with?("CLEARING_MOCK_", "DURATION_") }
      require File.join(root, "features/support/clearing_mock_server")
      class << ClearingMockServer
        def start = raise("unexpected default listener startup")
        def stop = raise("unexpected default cleanup side effect")
      end
      output = StringIO.new
      native_exit = begin
        Cucumber::Cli::Main.new(["--profile", "default", "--format", "progress"], output, output).execute!
      rescue SystemExit => error
        error.status
      end
      after = ENV.select { |key, _| key.start_with?("CLEARING_MOCK_", "DURATION_") }
      puts JSON.generate(native_exit: native_exit, unchanged_environment: before == after,
                         server_threads: Thread.list.count { |thread| thread.name == "clearing-mock-sinatra" },
                         progress: output.string)
    RUBY
    stdout, stderr, status = Open3.capture3({ "RP_ENABLED" => nil }, RbConfig.ruby, "-e", code, root, chdir: root)
    expect(status.exitstatus).to eq(0), stderr
    result = JSON.parse(stdout.lines.last)
    expect(result).to include("native_exit" => 0, "unchanged_environment" => true, "server_threads" => 0)
    expect(result.fetch("progress")).to include("1 scenario (1 passed)")
    expect(stderr).not_to include("unexpected default")
  end
end
