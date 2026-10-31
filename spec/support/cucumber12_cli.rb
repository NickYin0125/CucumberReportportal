# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "shellwords"
require "tmpdir"
require "timeout"

module Cucumber12QA
  ROOT = File.expand_path("../..", __dir__)
  FIXTURES = File.join(ROOT, "spec/fixtures/cucumber12")

  module_function

  def run(server, fixture:, tags: nil, options: [], parallel: false, launch_uuid: nil, label: nil, after_all_failure: false, require_complete: true)
    Dir.mktmpdir("cucumber12-cli-") do |directory|
      native = File.join(directory, "native.ndjson")
      formatter = parallel ? "ReportPortal::Cucumber::ParallelFormatter" : "ReportPortal::Cucumber::Formatter"
      arguments = ["--no-profile", "--require", File.join(ROOT, "lib/reportportal_cucumber.rb"),
                   "--require", File.join(FIXTURES, "support/steps.rb"),
                   "--format", "progress", "--format", formatter, "--out", File.join(directory, "rp.out")]
      arguments.concat(["--tags", tags]) if tags
      arguments.concat(options)
      unless parallel
        arguments.concat(["--format", "html", "--out", File.join(directory, "native.html"),
                          "--format", "Cucumber12EventAudit", "--out", File.join(directory, "events.json"),
                          "--format", "message", "--out", native, File.join(FIXTURES, fixture)])
      end
      environment = ENV.keys.grep(/\A(?:RP_|CUCUMBER_)/).to_h { |key| [key, nil] }.merge(
        "RP_ENDPOINT" => server.endpoint, "RP_PROJECT" => "qa", "RP_API_KEY" => WireServer::TOKEN,
        "RP_LAUNCH" => "Cucumber12 QA", "RP_CLIENT_JOIN" => "false", "RP_LAUNCH_UUID" => launch_uuid,
        "RP_IDENTITY_STRATEGY" => "stable_v1", "RP_IDENTITY_ROOT" => FIXTURES,
        "RP_RULE_SUITES" => "true",
        "RP_HTTP_RETRY_ATTEMPTS" => "1", "RP_FLUSH_INTERVAL" => "0.02", "RP_BATCH_SIZE_LOGS" => "1",
        "RP_EXIT_FLUSH_TIMEOUT_MS" => "3000", "RP_FAIL_ON_REPORTING_ERROR" => "true",
        "RP_REQUIRE_COMPLETE_REPORTING" => require_complete.to_s, "RP_SPOOL_DIR" => File.join(directory, "spool"),
        "CUCUMBER_PUBLISH_QUIET" => "true", "NO_COLOR" => "1", "TEST_ENV_NUMBER" => nil,
        "QA_AFTER_ALL_FAIL" => after_all_failure.to_s,
        "QA_REPORTING_RECEIPT_PATH" => File.join(directory, "receipt.json"),
        "BUNDLE_GEMFILE" => ENV.fetch("BUNDLE_GEMFILE", File.join(ROOT, "Gemfile"))
      )
      if ENV["RP_QA_COVERAGE_DIR"]
        bootstrap = File.join(directory, "coverage.rb")
        FileUtils.cp(File.join(ROOT, "spec/support/cucumber12_coverage.rb"), bootstrap)
        environment.merge!("RP_QA_COVERAGE_DIR" => File.join(ENV.fetch("RP_QA_COVERAGE_DIR"), "acceptance-cli"),
                           "RP_QA_SOURCE_ROOT" => ROOT,
                           "RUBYOPT" => [ENV["RUBYOPT"], "-r#{bootstrap}"].compact.join(" "))
      end
      command = if parallel
                  [RbConfig.ruby, Gem.bin_path("parallel_tests", "parallel_cucumber"), "-n", "2", "--group-by", "filesize",
                   "--test-options", Shellwords.join(arguments), File.join(FIXTURES, fixture)]
                else
                  [RbConfig.ruby, "-I#{File.join(ROOT, 'lib')}", Gem.bin_path("cucumber", "cucumber"), *arguments]
                end
      stdout = stderr = nil
      status = nil
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Open3.popen3(environment, *command, chdir: directory, pgroup: true) do |input, output, errors, process|
        input.close
        readers = [Thread.new { output.read }, Thread.new { errors.read }]
        begin
          Timeout.timeout(30) { status = process.value }
        rescue Timeout::Error
          Process.kill("KILL", -process.pid)
          raise "Cucumber12 CLI exceeded 30 seconds: #{command.inspect}"
        ensure
          stdout, stderr = readers.map(&:value)
        end
      end
      result = {
        "exit" => status.exitstatus, "stdout" => stdout, "stderr" => stderr,
        "seconds" => Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
        "command" => command,
        "native" => File.file?(native) ? File.readlines(native).map { |line| JSON.parse(line) } : [],
        "events" => File.file?(File.join(directory, "events.json")) ? JSON.parse(File.read(File.join(directory, "events.json"))) : [],
        "html_bytes" => File.file?(File.join(directory, "native.html")) ? File.size(File.join(directory, "native.html")) : 0,
        "receipt" => File.file?(File.join(directory, "receipt.json")) ? JSON.parse(File.read(File.join(directory, "receipt.json"))) : nil,
        "wire" => server.snapshot
      }
      if ENV["RP_QA_EVIDENCE_DIR"]
        FileUtils.mkdir_p(ENV.fetch("RP_QA_EVIDENCE_DIR"))
        mode = parallel ? "parallel-#{launch_uuid ? 'owned' : 'missing'}" : "single"
        label = [fixture.tr("/.", "--"), tags, *options, mode, label].compact.join("_").gsub(/[^a-zA-Z0-9_-]/, "-")
        File.write(File.join(ENV.fetch("RP_QA_EVIDENCE_DIR"), "#{label}.json"), JSON.pretty_generate(result) + "\n")
      end
      result
    end
  end
end
