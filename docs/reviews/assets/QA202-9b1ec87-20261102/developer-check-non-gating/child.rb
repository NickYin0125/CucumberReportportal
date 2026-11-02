# Non-gating developer check only: host Ruby, no container, no quiet window.
require "json"
sdk, mode, out = ARGV
$LOAD_PATH.unshift(File.join(sdk, "lib"))
require "reportportal_cucumber"
require "/Users/nick/Documents/crr-qa-2.0.2/spec/acceptance/ledger_qa/sdk202/benchmark"
module Ledger202Benchmark; def self.gate!(*) = true; end
corpus = JSON.parse(File.read("/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/ledger-2.0.2-preparation/failure-corpus.json"))
r = Ledger202Benchmark.measure(receipt: { "corpus_sha256" => corpus["corpus_sha256"] }, corpus: corpus, role: "baseline", mode: mode)
abort r["error_class"].to_s if r["status"] != "MEASURED_NOT_SCORED"
raise "wrong sdk" unless $LOADED_FEATURES.grep(%r{reportportal_cucumber/automation/evidence}).all? { _1.start_with?(sdk) }
File.write(out, JSON.generate(r["samples_ms"]))
