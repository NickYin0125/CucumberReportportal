# frozen_string_literal: true

require_relative "release_perf_benchmark"
require_relative "../../../../script/acceptance/presentation_ledger_developer/activation"

action, role, mode, source_sha, corpus_path, output, receipt_path, environment_path = ARGV
raise "Invalid action/role/mode" unless %w[validate measure supplement].include?(action) &&
  %w[baseline candidate].include?(role) && %w[plain rich].include?(mode)
raise "Wrong source selection" unless source_sha == (role == "baseline" ? ReleasePerf202::BASELINE : ReleasePerf202::FINAL)
timed = action != "validate"
ReleasePerf202.gate!(JSON.parse(File.read(receipt_path))) if timed
raise "Refusing existing output" if File.exist?(output)
raise "Ruby/architecture mismatch" unless RUBY_VERSION == "3.4.12" && RUBY_PLATFORM.include?("aarch64-linux")
raise "Corpus file drift" unless Digest::SHA256.file(corpus_path).hexdigest == ReleasePerf202::CORPUS_FILE
corpus = JSON.parse(File.read(corpus_path))
rows = ReleasePerf202.validate_corpus!(corpus)
rows = ReleasePerf202.supplement if action == "supplement"
LedgerDeveloper::Activation.activate!
require "cucumber/load_path"
$LOAD_PATH.delete("lib")
sdk = File.realpath(ENV.fetch("LEDGER_SDK_ROOT"))
$LOAD_PATH.unshift(File.join(sdk, "lib"))
require File.join(sdk, "lib/reportportal_cucumber")
raise "Wrong Cucumber" unless Gem.loaded_specs.fetch("cucumber").version.to_s == "12.0.1"
loaded = $LOADED_FEATURES.grep(%r{/reportportal_cucumber(?:/|\.rb)})
raise "Wrong SDK loaded" unless !loaded.empty? && loaded.all? { |p| File.realpath(p).start_with?(sdk + "/lib/") }
result = ReleasePerf202.measure(rows: rows, mode: mode, timed: timed)
result.merge!("role" => role, "source_sha" => source_sha, "scope" => action == "supplement" ? "supplement_only_not_frozen_corpus" : "frozen21",
  "corpus_sha256" => action == "supplement" ? Digest::SHA256.hexdigest(JSON.generate(rows)) : ReleasePerf202::CORPUS,
  "activation" => LedgerDeveloper::Activation.provenance, "loaded_sdk_files" => loaded,
  "receipt_sha256" => timed ? Digest::SHA256.file(receipt_path).hexdigest : nil,
  "environment_sha256" => Digest::SHA256.file(environment_path).hexdigest)
File.open(output, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(JSON.pretty_generate(result) + "\n") }
puts JSON.generate(status: result["status"], role: role, mode: mode, cases: result["cases"].length,
  samples: result["samples_ms"].transform_values(&:length))
