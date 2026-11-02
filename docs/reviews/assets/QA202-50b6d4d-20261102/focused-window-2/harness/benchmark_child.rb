# frozen_string_literal: true

require_relative "benchmark"
require_relative "../../../../script/acceptance/presentation_ledger_developer/activation"

receipt_path, corpus_path, output, role, mode = ARGV
receipt = JSON.parse(File.read(receipt_path))
Ledger202Benchmark.gate!(receipt, role: role, mode: mode)
raise "Output exists" if File.exist?(output)
LedgerDeveloper::Activation.activate!
require "cucumber/load_path"
$LOAD_PATH.delete("lib")
$LOAD_PATH.unshift(File.join(ENV.fetch("LEDGER_SDK_ROOT"), "lib"))
require File.join(ENV.fetch("LEDGER_SDK_ROOT"), "lib/reportportal_cucumber")
result = Ledger202Benchmark.measure(receipt: receipt, corpus: JSON.parse(File.read(corpus_path)), role: role, mode: mode)
result["activation"] = LedgerDeveloper::Activation.provenance
result["loaded_sdk_files"] = $LOADED_FEATURES.grep(%r{/reportportal_cucumber(?:/|\.rb)})
raise "Wrong SDK loaded" unless result["loaded_sdk_files"].all? { |p| File.realpath(p).start_with?("/qa202-sdk/lib/") }
File.open(output, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(JSON.pretty_generate(result) + "\n") }
puts JSON.generate(role: role, mode: mode, status: result["status"], error_class: result["error_class"], samples: result["samples_ms"].transform_values(&:length))
exit(result["status"] == "MEASURED_NOT_SCORED" ? 0 : 2)
