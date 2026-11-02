# frozen_string_literal: true

require "json"
require "uri"
root = ENV.fetch("REVIEW_RUNTIME_ROOT")
$LOAD_PATH.unshift(File.join(root, "lib"))
require "reportportal_cucumber/automation/evidence_redactor"
require "reportportal_cucumber/automation/failure_redactor"
require "reportportal_cucumber/automation/http_exchange"
require "reportportal_cucumber/service/evidence_presenter"

SECRET = "SYNTHETIC_INDEPENDENT_SECRET"
def encode_all(value)
  value.bytes.map { |byte| format("%%%02X", byte) }.join
end

def decoded(value)
  3.times { value = URI::DEFAULT_PARSER.unescape(value) }
  value.gsub(/\\u([0-9a-f]{4})/i) { [$1.to_i(16)].pack("U") }
end

cases = []
{ plain: "password", spaced: "pass word", unicode: 'pass\\u0077ord' }.each do |label, key|
  [SECRET, "[REDACTED]#{SECRET}"].each_with_index do |secret, value_index|
    [1, 2, 3].each do |layers|
      component = %({"#{key}":"#{secret}"})
      layers.times { component = encode_all(component) }
      { path: "https://example.test/#{component}", query: "https://example.test/?#{component}",
        fragment: "https://example.test/#x=#{component}", truncated: "https://example.test/bad path##{component}" }.each do |location, input|
        cases << ["json_#{label}_value#{value_index}_layers#{layers}_#{location}", input, nil]
      end
    end
  end
end
[1, 2, 3].each do |layers|
  component = "Bearer #{SECRET}"
  layers.times { component = encode_all(component) }
  { path: "https://example.test/#{component}", query: "https://example.test/?#{component}",
    truncated: "https://example.test/bad path##{component}" }.each do |location, input|
    cases << ["bearer_layers#{layers}_#{location}", input, nil]
  end
end
[
  "https://example.test/files/my%20report.pdf?page=2",
  "https://example.test/users/%7Bid%7D/profile",
  "https://example.test/a?%7B%22page%22%3A2%7D",
  "https://example.test/a?debug&x=1",
  "https://example.test/%E6%B5%8B%E8%AF%95"
].each_with_index { |url, i| cases << ["safe_#{i}", url, url] }

policy = Automation::EvidenceRedactor.new
results = cases.map do |name, input, expected|
  exchange = Automation::HttpExchange.new(method: "GET", url: input, response: { status: 200 })
  failure = Automation::FailureRedactor.new.redact(message: "request failed", frames: [input, "safe.rb:1:in run"])
  output = { url: policy.redact_url(input), text: policy.redact_text(input),
             summary: exchange.summary, plain: exchange.to_markdown(presentation: "plain"),
             rich: exchange.to_markdown(presentation: "rich"), failure: failure.baseline,
             evidence: ReportportalCucumber::Service::EvidencePresenter.failure(
               action: "request", error: RuntimeError.new("request failed"), url: input).values.join("\n") }
  leaked = output.select { |_, value| decoded(value).include?(SECRET) }.keys
  changed = expected && output.fetch(:url) != expected
  { name: name, input: input, output: output, leaked_routes: leaked, safe_url_changed: !!changed,
    pass: leaked.empty? && !changed }
end
puts JSON.pretty_generate(runtime: root, cases: results.length, passed: results.count { |r| r[:pass] },
                          failed: results.count { |r| !r[:pass] }, results: results)
exit(results.all? { |r| r[:pass] } ? 0 : 1)
