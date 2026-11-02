#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

qa_root = File.expand_path("../../../..", __dir__)
runtime_root = File.expand_path(ENV.fetch("SDK202_RUNTIME_ROOT", File.join(File.dirname(qa_root), "crr-2.0.2")))
require File.join(runtime_root, "lib/reportportal_cucumber/automation/failure_redactor")

# Deferred security blocker, not a pending test or a performance-release waiver.
message_secret = "FROZEN_MESSAGE_SECRET"
frame_secret = "FROZEN_FRAME_SECRET"
message = "request https://alice:FROZEN_MESSAGE_SECRET@example.test/path?token=FROZEN_MESSAGE_SECRET&count=12"
frame = "https://example.test/bad path#%7B%22pass%5Cu0077ord%22%3A%22FROZEN_FRAME_SECRET%22%7D"
safe_frames = [
  "/project/FROZEN/support.rb:65:in 'inner_failure'",
  "/project/FROZEN/support.rb:59:in 'deep_failure'",
  "/project/FROZEN/support.rb:136:in 'step'",
  "/project/FROZEN/features/audit.feature:5:in 'failure'"
] + Array.new(56) { |index| "/ruby/gems/cucumber/FROZEN/runner.rb:#{index + 1}:in 'run'" } +
  ["-e:1:in 'run'", "<internal:kernel>:90:in 'require'"]
input = { message: message, frames: [frame, *safe_frames].each(&:freeze).freeze }.freeze

fresh_policy = Automation::EvidenceRedactor.new
results = {
  shared_default: Automation::FailureRedactor.new.redact(**input).to_h,
  fresh_injected: Automation::FailureRedactor.new(redactor: fresh_policy).redact(**input).to_h
}
leaked_fields = results.each_with_object({}) do |(name, result), failures|
  fields = result.filter_map do |field, value|
    next unless value.is_a?(String)

    field if [message_secret, frame_secret].any? { |marker| value.include?(marker) }
  end
  failures[name] = fields unless fields.empty?
end
equivalent = results.fetch(:shared_default) == results.fetch(:fresh_injected)
blocked = !leaked_fields.empty? || !equivalent

puts JSON.pretty_generate(
  status: blocked ? "BLOCKED" : "PASS",
  runtime_root: runtime_root,
  fixture: input,
  decoded_fragment: URI.decode_www_form_component(frame.split("#", 2).last),
  safe_frame_count: safe_frames.length,
  results: results,
  all_result_fields_equal: equivalent,
  leaked_fields: leaked_fields,
  diagnostics: {
    direct_redact_text: fresh_policy.redact_text(frame),
    direct_redact_url: fresh_policy.redact_url(frame)
  }
)
$stdout.flush

if blocked
  warn "BLOCKED: original whitespace-URL credential regression remains unresolved."
  exit 1
end

puts "PASS: neither failure-redactor policy exposes the fixture credential markers."
