# frozen_string_literal: true

require "cucumber/cli/main"
require "reportportal_cucumber"

root = File.expand_path("../..", __dir__)
fixtures = File.join(root, "spec", "fixtures", "m3a")
stdout_formatter = ENV.fetch("M3A_STDOUT_FORMAT", "progress")
raise "M3A_STDOUT_FORMAT must be progress or pretty" unless %w[progress pretty].include?(stdout_formatter)

args = [
  "--require", File.join(fixtures, "support", "m3a_steps.rb"),
  "--format", stdout_formatter,
  File.join(fixtures, "english.feature"),
  File.join(fixtures, "zh-CN.feature")
]
args.concat(ARGV)
exit(Cucumber::Cli::Main.execute(args))
