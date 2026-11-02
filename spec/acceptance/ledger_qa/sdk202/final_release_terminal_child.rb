# frozen_string_literal: true

require "json"
require "stringio"
$LOAD_PATH.unshift(File.join(ARGV.fetch(0), "lib"))
require "reportportal_cucumber"
require "reportportal_cucumber/automation/cucumber_logger"

rows = Dir[File.join(ARGV.fetch(1), "{F10*,F11*}/inputs.ndjson")].sort.flat_map do |path|
  File.readlines(path).map { |l| JSON.parse(l) }.select { |r| %w[assertion http].include?(r["kind"]) }
end
output = StringIO.new
logger = Automation::CucumberLogger.new(output: output, color: false)
rows.each do |row|
  kind = row.fetch("kind")
  values = row.reject { |k, _| k == "kind" }.transform_keys(&:to_sym)
  logger.public_send(kind, **values, report: false)
end
curl = "curl --request GET 'https://api.example.test/words?token=SAFE_CURL_FIXTURE' --header 'Authorization: Bearer SAFE_CURL_FIXTURE'"
logger.info(curl, report: false)
puts JSON.generate(stdout: output.string, input_count: rows.length, raw_curl: curl,
  loaded_sdk_files: $LOADED_FEATURES.grep(%r{/reportportal_cucumber(?:/|\.rb)}))
