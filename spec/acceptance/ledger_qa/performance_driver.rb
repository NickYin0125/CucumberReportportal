# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"

root = File.expand_path("../../..", __dir__)
version = root.end_with?("1.3.2") ? "1.3.2" : "2.0.1"
legacy = version == "1.3.2"
gems = legacy ? "/private/tmp/reportportal-cucumber12-legacy-bundle-ruby342/ruby/3.4.0" : "/private/tmp/reportportal-cucumber12-bundle-ruby342/ruby/3.4.0"
cucumber = legacy ? "10.2.0" : "12.0.1"
baseline = legacy ? "/Users/nick/Documents/crr-qa-baseline-1.3.1" : "/Users/nick/Documents/crr-qa-baseline-2.0.0"
prefix = File.join(root, "docs/reviews/assets/ledger-qa-performance", ARGV.fetch(0))
records = []
capture = lambda do |kind, mode, sdk, fixtures, suffix|
  output = File.join(prefix, suffix)
  command = [RbConfig.ruby, File.join(__dir__, "performance.rb"), kind, "--transport", "offline", "--mode", mode,
    "--sdk-root", sdk, "--cucumber", cucumber, "--gem-path", gems, "--fixtures", fixtures,
    "--jpeg", ENV.fetch("QA_JPEG"), "--output", output]
  stdout, stderr, status = Open3.capture3(*command)
  record = { kind: kind, mode: mode, sdk: sdk, command: command, exit: status.exitstatus,
    stdout: stdout, stderr: stderr, output: output }
  records << record
  File.write(File.join(prefix, "driver.json"), JSON.pretty_generate(records) + "\n")
  raise "Performance capture failed; preserve driver evidence" unless status.success?
end

3.times do |repeat|
  [["plain", baseline, "baseline"], ["plain", root, "plain"], ["rich", root, "rich"]].rotate(repeat).each do |mode, sdk, label|
    capture.call("wall", mode, sdk, "F07", "wall-#{repeat + 1}-#{label}")
  end
end
fixtures = (1..18).reject { |number| number == 6 }.map { |number| format("F%02d", number) }.join(",")
%w[plain rich].each do |mode|
  capture.call("micro", mode, root, fixtures, "micro-#{mode}")
  capture.call("parallel-micro", mode, root, "F06", "parallel-micro-#{mode}") unless legacy
end
puts JSON.generate(version: version, performance_captures: records.length, output: prefix)
