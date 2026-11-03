# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"

results = []
%w[9.2.1 10.2.0].each do |version|
  expressions = version.start_with?("9.") ? "17.1.0" : "18.1.0"
  boot = "gem 'cucumber-cucumber-expressions', '=#{expressions}'; gem 'cucumber', '=#{version}'; require 'cucumber/cli/main'; exit Cucumber::Cli::Main.new(ARGV).execute!"
  path = "/evidence/fixture-cucumber#{version}.json"
  output, status = Open3.capture2e(RbConfig.ruby, "-I", "/source/lib", "-e", boot, "--", "--dry-run", "--publish-quiet",
    "--require", "/qa/live_steps.rb", "--format", "json", "--out", path, "/qa/live.feature", chdir: "/tmp")
  File.write("/evidence/fixture-cucumber#{version}.log", output)
  raise "Fixture parse failed for Cucumber #{version}" unless status.success?
  elements = JSON.parse(File.read(path)).flat_map { |feature| feature.fetch("elements", []) }
  scenarios = elements.select { |element| element["type"] == "scenario" }
  raise "Expected five dry-run scenarios" unless scenarios.length == 5
  results << { cucumber: version, expressions: expressions, scenarios: scenarios.length,
    parse_only: true, real_rp_launches: 0, compound_arguments: "N/A unsupported; separate steps used" }
end
File.write("/evidence/fixture-check.json", JSON.pretty_generate(results) + "\n")
puts JSON.generate(results)
