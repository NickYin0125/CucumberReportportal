# frozen_string_literal: true

require "json"
require "digest"
require "/qa/script/acceptance/presentation_ledger_developer/activation"
LedgerDeveloper::Activation.activate!
require "cucumber/load_path"
$LOAD_PATH.delete("lib")
$LOAD_PATH.unshift("/qa202-sdk/lib")
require "reportportal_cucumber"
require "reportportal_cucumber/automation/http_exchange"
require "reportportal_cucumber/automation/cucumber_logger"
require "/qa/spec/acceptance/ledger_qa/sdk202/benchmark"

def sample(invoke, warmup: 10, count: 50)
  warmup.times { invoke.call }
  allocations = GC.stat(:total_allocated_objects)
  values = count.times.map do
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    invoke.call
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
  end
  { samples_ms: values, allocations: GC.stat(:total_allocated_objects) - allocations }
end

def summarize(values)
  sorted = values.sort
  { n: sorted.length, p50_ms: sorted[(sorted.length * 0.50).ceil - 1],
    p95_ms: sorted[(sorted.length * 0.95).ceil - 1], p99_ms: sorted[(sorted.length * 0.99).ceil - 1],
    mean_ms: values.sum / values.length }
end

arm, mode, round = ARGV
corpus = JSON.parse(File.read("/qa/docs/reviews/assets/ledger-2.0.2-preparation/failure-corpus.json"))
ids = corpus.fetch("cases").map do |row|
  id = Digest::SHA256.hexdigest(JSON.generate(row.values_at("class", "message", "frames")))
  raise "Corpus entry changed" unless id == row.fetch("input_id")
  id
end
raise "Corpus changed" unless ids.length == 21 && Digest::SHA256.hexdigest(JSON.generate(ids)) == corpus.fetch("corpus_sha256")
measurements = Hash.new { |hash, key| hash[key] = { samples_ms: [], allocations: 0 } }
corpus.fetch("cases").each do |row|
  formatter = ReportportalCucumber::Cucumber::Formatter.allocate
  formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new("rp.presentation" => mode))
  formatter.instance_variable_set(:@launch_uuid, "offline-performance-review")
  sink = Object.new
  sink.define_singleton_method(:emit_log) { |**_| nil }
  formatter.instance_variable_set(:@log_buffer, sink)
  formatter.define_singleton_method(:monotonic_timestamp) { |value| value }
  error = Ledger202Benchmark.error_for(row)
  timestamp = Time.utc(2026, 11, 1)
  invoke = -> { formatter.send(:emit_error_log, item_uuid: "offline", error: error, timestamp: timestamp) }
  target = ReportportalCucumber::Presentation::FailureCard
  original = target.method(:format)
  calls = []
  wrapper = Module.new do
    define_method(:format) do |*args, **kwargs, &block|
      calls << [args, kwargs, block]
      super(*args, **kwargs, &block)
    end
  end
  target.singleton_class.prepend(wrapper)
  begin
    invoke.call
  ensure
    wrapper.send(:remove_method, :format)
  end
  raise "Renderer did not run exactly once" unless calls.length == 1
  args, kwargs, block = calls.first
  { renderer_only: -> { original.call(*args, **kwargs, &block) }, redaction_plus_rendering: invoke }.each do |name, callable|
    row_result = sample(callable)
    measurements[name][:samples_ms].concat(row_result.fetch(:samples_ms))
    measurements[name][:allocations] += row_result.fetch(:allocations)
  end
end

policy = Automation::EvidenceRedactor.new
url = "https://example.test/Bearer%2520SYNTHETIC_PERF_SECRET"
encoded = URI.encode_www_form_component(URI.encode_www_form_component(JSON.generate(password: "[REDACTED]SYNTHETIC_PERF_SECRET")))
variants = {
  url_plain: "https://example.test/orders/123?page=1",
  url_safe_encoded: "https://example.test/files/my%20report.pdf?page=2",
  url_double_bearer: url,
  url_double_mask_prefix: "https://example.test/#{encoded}"
}
variants.each { |name, input| measurements[name] = sample(-> { policy.redact_url(input) }, warmup: 30, count: 200) }
world = Object.new
world.define_singleton_method(:log) { |_| nil }
world.define_singleton_method(:rp_active?) { true }
world.define_singleton_method(:rp_log) { |_, **| nil }
terminal = Object.new
terminal.define_singleton_method(:puts) { |_| nil }
logger = Automation::CucumberLogger.new(world: world, output: terminal, color: false)
curl = "Reproduce request:\n\n```bash\ncurl 'https://example.test/orders' -H 'Authorization: Bearer SYNTHETIC_PERF_SECRET' --data-raw '{\"id\":123}'\n```"
measurements[:ordinary_curl_logger] = sample(-> { logger.info(curl, report: true) }, warmup: 30, count: 1000)
small = JSON.generate(status: "ok", trade: { id: "T-123", amount: 123.45, currency: "USD" })
large = JSON.generate(trades: Array.new(64) { |i| { id: "T-#{i}", amount: 123.45, currency: "USD", details: "x" * 512 } })
{ http_small: [variants[:url_plain], small], http_large: [variants[:url_plain], large],
  http_encoded: [url, small] }.each do |name, (input, body)|
  measurements[name] = sample(-> {
    exchange = Automation::HttpExchange.new(method: "POST", url: input,
      request: { headers: { "Authorization" => "Bearer SYNTHETIC_PERF_SECRET" }, body: small },
      response: { status: 400, body: body })
    exchange.to_markdown(presentation: mode)
  }, warmup: 20, count: 100)
end

source_files = Dir.glob("/qa202-sdk/lib/**/*").select { |p| File.file?(p) }.sort.map do |p|
  [p.delete_prefix("/qa202-sdk/"), Digest::SHA256.file(p).hexdigest]
end
result = { scope: "OFFLINE_DIAGNOSTIC_NOT_G11_CERTIFICATION", arm: arm, mode: mode, round: round,
  ruby: RUBY_DESCRIPTION, activation: LedgerDeveloper::Activation.provenance,
  source_manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(source_files)),
  corpus_sha256: corpus.fetch("corpus_sha256"), http_body_bytes: { small: small.bytesize, large: large.bytesize },
  results: measurements.transform_values { |r| r.merge(summary: summarize(r.fetch(:samples_ms)), allocations_per_call: r.fetch(:allocations).fdiv(r.fetch(:samples_ms).length)) } }
path = "/evidence/performance/#{arm}-#{mode}-#{round}.json"
File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(JSON.pretty_generate(result) + "\n") }
puts JSON.generate(arm: arm, mode: mode, round: round, summaries: result[:results].transform_values { |r| r[:summary] })
