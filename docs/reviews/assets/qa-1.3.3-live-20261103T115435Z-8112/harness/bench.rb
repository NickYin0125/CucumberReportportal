# frozen_string_literal: true

require "json"
gem "cucumber", ENV.fetch("QA_CUCUMBER", "10.2.0")
$LOAD_PATH.unshift(File.join(ENV.fetch("QA_SOURCE"), "lib"))
require "reportportal_cucumber"

def measure(iterations)
  20.times { yield }
  times = Array.new(iterations) do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  end.sort
  { iterations: iterations, warmup_iterations: 20, median_ms: times[times.length / 2],
    p95_ms: times[(times.length * 0.95).ceil - 1], samples_ms: times }
end

iterations = Integer(ENV.fetch("QA_BENCH_ITERATIONS", "100"))
raise "Expected 1..10000 iterations" unless (1..10_000).cover?(iterations)
error = RuntimeError.new("\nexpected accepted\nactual rejected\n")
frames = Array.new(12) { |number| "/project/features/steps.rb:#{number + 1}:in 'check'" }.join("\n")
results = {}
%w[plain rich].each do |mode|
  results["failure_#{mode}"] = measure(iterations) do
    ReportportalCucumber::Presentation::FailureCard.format(error: error, message: error.message, backtrace: frames, presentation: mode)
  end
  results["assertion_#{mode}"] = measure(iterations) do
    ReportportalCucumber::Service::EvidencePresenter.assertion(name: "order amount", expected: 42, actual: 41, passed: false, presentation: mode)
  end
  results["benign_http_#{mode}"] = measure(iterations) do
    Automation::HttpExchange.new(method: :post, url: "https://example.test/orders?region=eu&page=2",
      request: { headers: { "Content-Type" => "application/json", "X-Region" => "eu" }, body: { order: 42, items: [1, 2, 3] } },
      response: { status: 201, headers: { "Content-Type" => "application/json" }, body: { accepted: true, amount: 42 } }, duration_ms: 23).to_markdown(presentation: mode)
  end
end
report = { source: ENV.fetch("QA_SOURCE"), label: ENV.fetch("QA_BENCH_LABEL", "diagnostic-only"),
  ruby: RUBY_DESCRIPTION, sdk: ReportportalCucumber::VERSION,
  gems: Gem.loaded_specs.sort.to_h.transform_values { |spec| spec.version.to_s },
  diagnostic_only: true, results: results }
File.write(ENV.fetch("QA_BENCH_OUT"), JSON.pretty_generate(report) + "\n")
puts JSON.generate(report.slice(:label, :ruby, :sdk).merge(results: results.transform_values { |entry| entry.reject { |key, _| key == :samples_ms } }))
