# frozen_string_literal: true

require "json"
require "digest"

if ENV["QA_ADVERSARIAL_BENCH_CHILD"] == "1"
  require "uri"
  gem "cucumber", "10.2.0"
  source = ENV.fetch("QA_SOURCE")
  $LOAD_PATH.unshift(File.join(source, "lib"))
  require "reportportal_cucumber"
  raise "Wrong SDK" unless ReportportalCucumber::VERSION == "1.3.3"

  redactor = Automation::EvidenceRedactor.new
  cases = (2..5).to_h do |depth|
    value = JSON.generate(password: "SYNTHETIC_DEPTH_SENTINEL")
    depth.times { value = URI.encode_www_form_component(value) }
    ["json_path_depth_#{depth}", ["redact_url", "https://example.test/" + value, "SYNTHETIC_DEPTH_SENTINEL"]]
  end
  cases["plaintext_duplicated_bearer"] = ["redact_text", "Authorization: Bearer Bearer SYNTHETIC_BEARER_SENTINEL", "SYNTHETIC_BEARER_SENTINEL"]
  results = cases.to_h do |name, (operation, input, sentinel)|
    original = input.dup
    validate = lambda do |output|
      decoded = output.dup
      6.times { decoded = URI.decode_www_form_component(decoded) }
      raise "Residual synthetic secret: #{name}" if decoded.include?(sentinel)
      raise "Input mutated" unless input == original
    end
    validate.call(redactor.public_send(operation, input))
    20.times { redactor.public_send(operation, input) }
    last = nil
    samples = Array.new(1000) do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      last = redactor.public_send(operation, input)
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    end.sort
    validate.call(last)
    [name, { operation: operation, input_bytes: input.bytesize, input_sha256: Digest::SHA256.hexdigest(input),
      output_sha256: Digest::SHA256.hexdigest(last), no_secret_after_six_decodes: true,
      iterations: samples.length, warmups: 20, median_ms: samples[500], p95_ms: samples[949], samples_ms: samples }]
  end
  hashes = Dir[File.join(source, "lib/**/*.rb")].sort.to_h { |path| [path.delete_prefix(source + "/"), Digest::SHA256.file(path).hexdigest] }
  report = { frozen_sha: ENV.fetch("QA_FROZEN_SHA"), sdk: ReportportalCucumber::VERSION, ruby: RUBY_DESCRIPTION,
    gems: Gem.loaded_specs.sort.to_h.transform_values { |spec| spec.version.to_s }, lib_sha256: hashes,
    scope: "Candidate-only direct calls on a reused EvidenceRedactor; encoding construction and safety validation outside timing; no network/upload SLA or unsafe legacy comparison",
    existing_corpus: "adversarial_spec.rb json_path depths 2/3/4/5 and plaintext duplicated Bearer, unchanged inputs",
    results: results }
  File.write(ENV.fetch("QA_BENCH_OUT"), JSON.pretty_generate(report) + "\n")
  puts JSON.generate(report.slice(:frozen_sha, :sdk, :scope).merge(results: results.transform_values { |entry| entry.reject { |key, _| key == :samples_ms } }))
  exit
end

require "fileutils"
require "optparse"
require "securerandom"
require "time"
options = {}
OptionParser.new do |parser|
  parser.on("--source PATH") { |value| options[:source] = File.expand_path(value) }
  parser.on("--frozen-sha SHA") { |value| options[:sha] = value }
  parser.on("--out PATH") { |value| options[:out] = File.expand_path(value) }
  parser.on("--resource-slot-confirmed") { options[:slot] = true }
end.parse!
abort "Explicit source, full SHA and approved resource slot required" unless options[:source] && options[:sha].to_s.match?(/\A[0-9a-f]{40}\z/) && options[:slot]
head = -> { IO.popen(["git", "-C", options[:source], "rev-parse", "HEAD"], &:read).strip }
clean = -> { IO.popen(["git", "-C", options[:source], "status", "--porcelain"], &:read).empty? }
abort "Source identity/cleanliness mismatch" unless head.call == options[:sha] && clean.call
out = options[:out] || File.expand_path("../../docs/reviews/assets/qa-1.3.3-adversarial-bench-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(2)}", __dir__)
abort "Fresh output required" if File.exist?(out)
FileUtils.mkdir_p(out)
FileUtils.cp(__FILE__, File.join(out, "harness.rb"))
image = JSON.parse(File.read(File.join(__dir__, "environment/images.json"))).fetch("3.3").fetch("image")
argv = ["/usr/local/bin/docker", "run", "--rm", "--network", "none", "--cpus", "1", "--memory", "2g",
  "-v", "#{options[:source]}:/source:ro", "-v", "#{out}:/evidence", "-v", "/private/tmp/ledger-matrix-bundles/ruby33:/bundle:ro",
  "-e", "GEM_PATH=/bundle/ruby/3.3.0", "-e", "QA_SOURCE=/source", "-e", "QA_FROZEN_SHA=#{options[:sha]}",
  "-e", "QA_ADVERSARIAL_BENCH_CHILD=1", "-e", "QA_BENCH_OUT=/evidence/timing.json", image, "ruby", "/evidence/harness.rb"]
File.write(File.join(out, "command.json"), JSON.pretty_generate(argv) + "\n")
abort "Adversarial timing failed" unless system(*argv, out: File.join(out, "timing.log"), err: [:child, :out])
abort "Source changed during timing" unless head.call == options[:sha] && clean.call
report = JSON.parse(File.read(File.join(out, "timing.json")))
expected = Dir[File.join(options[:source], "lib/**/*.rb")].sort.to_h { |path| [path.delete_prefix(options[:source] + "/"), Digest::SHA256.file(path).hexdigest] }
abort "Loaded library inventory mismatch" unless report.fetch("lib_sha256") == expected
File.write(File.join(out, "provenance.json"), JSON.pretty_generate(frozen_sha: options[:sha], image: image,
  tracked_source_clean_before_after: true, library_files_verified: expected.length,
  script_sha256: Digest::SHA256.file(__FILE__).hexdigest, normal_paired_series_rerun: false) + "\n")
puts "QA_ADVERSARIAL_BENCH_EVIDENCE=#{out}"
