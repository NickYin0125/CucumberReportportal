# frozen_string_literal: true

require "bundler/setup"
require_relative "session"
require "cucumber/cli/main"

# Credentials enter the child through a private pipe, never argv or a file.
input = JSON.parse(STDIN.read)
ENV.keys.grep(/\ARP_/).each { |key| ENV.delete(key) }
input.fetch("env").each { |key, value| ENV[key] = value }
$day2_mode = input.fetch("mode")
STDOUT.sync = true

at_exit do
  formatter = $day2_formatter
  if formatter
    puts "DAY2_RESULT=#{JSON.generate(receipt: formatter.reporting_receipt.to_h,
                                      diagnostics: formatter.reporting_diagnostics,
                                      finalization_elapsed: $day2_after_all_at &&
                                        Process.clock_gettime(Process::CLOCK_MONOTONIC) - $day2_after_all_at,
                                      cucumber: Gem.loaded_specs.fetch('cucumber').version.to_s)}"
  end
end

args = ["--no-profile", "--publish-quiet", "--require", File.join(__dir__, "native_steps.rb"),
        "--format", "progress", "--format", "ReportPortal::Cucumber::Formatter", "--out", File::NULL,
        File.join(__dir__, "native.feature")]
Cucumber::Cli::Main.new(args).execute!
