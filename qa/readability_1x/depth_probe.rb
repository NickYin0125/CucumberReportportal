# frozen_string_literal: true

require "json"
require "uri"
require "digest"
require "open3"
reference_files = {}
if ENV["QA_REFERENCE_COMMIT"]
  %w[evidence_redactor credential_keys].each do |name|
    relative = "lib/reportportal_cucumber/automation/#{name}.rb"
    bytes, status = Open3.capture2("git", "-C", ENV.fetch("QA_SOURCE"), "show", "#{ENV.fetch('QA_REFERENCE_COMMIT')}:#{relative}")
    raise "Cannot verify reference file" unless status.success?
    digest = Digest::SHA256.hexdigest(bytes)
    raise "Reference source file differs" unless Digest::SHA256.file(File.join(ENV.fetch("QA_SOURCE"), relative)).hexdigest == digest
    reference_files[relative] = digest
  end
end
require File.join(ENV.fetch("QA_SOURCE"), "lib/reportportal_cucumber/automation/evidence_redactor")

redactor = Automation::EvidenceRedactor.new
results = (1..5).map do |depth|
  value = JSON.generate(password: "SYNTHETIC_DEPTH_SENTINEL")
  depth.times { value = URI.encode_www_form_component(value) }
  input = "https://example.test/" + value
  output = redactor.redact_url(input)
  decoded = output.dup
  6.times { decoded = URI.decode_www_form_component(decoded) }
  { depth: depth, input: input, output: output, decoded_output: decoded,
    leaked: decoded.include?("SYNTHETIC_DEPTH_SENTINEL") }
end
source = File.join(ENV.fetch("QA_SOURCE"), "lib/reportportal_cucumber/automation/evidence_redactor.rb")
report = JSON.pretty_generate(source: ENV.fetch("QA_SOURCE"), reference: ENV["QA_REFERENCE"],
  reference_commit: ENV["QA_REFERENCE_COMMIT"], verified_reference_files: reference_files,
  redactor_sha256: Digest::SHA256.file(source).hexdigest, synthetic_only: true, results: results)
File.write(ENV.fetch("QA_DEPTH_OUT"), report + "\n") if ENV["QA_DEPTH_OUT"]
puts report
exit(results.any? { |result| result[:leaked] } ? 1 : 0)
