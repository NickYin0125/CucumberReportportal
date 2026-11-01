# frozen_string_literal: true

require_relative "final_wp5_driver"

names = %w[queue_processor_m4b_spec.rb queue_processor_presentation_failures_spec.rb queue_processor_render_cache_spec.rb]
normalize = lambda do |source|
  source.lines.reject { |line| line.include?("# Keep RSpec's prepended Method intact through Ruby 3.1 keyword forwarding.") }.map do |line|
    if line.include?("and_wrap_original do |")
      line.gsub(/\*\*(options|payload)/, '\1').gsub(/\boptions = \{\}/, "options")
    else
      line
    end
  end.join
end
LedgerFinalWP5::LINES.each do |version, config|
  sdk = "/Users/nick/Documents/crr-#{version}"
  qa = "/Users/nick/Documents/crr-qa-#{version}"
  rows = names.map do |name|
    relative = "spec/reportportal_cucumber/service/#{name}"
    old, status = Open3.capture2("git", "-C", sdk, "show", "#{config[:sha]}:#{relative}")
    raise "Original test unavailable" unless status.success?
    current = File.read(File.join(sdk, relative))
    { path: relative, old_sha256: Digest::SHA256.hexdigest(old), corrected_sha256: Digest::SHA256.hexdigest(current),
      changed: old != current, normalized_old_sha256: Digest::SHA256.hexdigest(normalize.call(old)),
      normalized_current_sha256: Digest::SHA256.hexdigest(normalize.call(current)),
      only_named_spy_signature_or_explanatory_comment_changed: normalize.call(old) == normalize.call(current) }
  end
  runtime_delta = LedgerFinalWP5.git(sdk, "diff", "HEAD", "--name-only", "--", "lib", "Gemfile", "Gemfile.lock", "reportportal-cucumber-ruby.gemspec")
  record = { schema: "independent-test-spy-signature-inspection/1", checked_at_utc: Time.now.utc.iso8601,
    runtime_sha: config[:sha], actual_feature_head: LedgerFinalWP5.git(sdk, "rev-parse", "HEAD"), test_files: rows,
    runtime_dependency_or_gemspec_delta: runtime_delta, product_assertions_and_timeouts_byte_identical_after_narrow_signature_normalization: rows.all? { |row| row[:only_named_spy_signature_or_explanatory_comment_changed] },
    verdict: rows.all? { |row| row[:changed] && row[:only_named_spy_signature_or_explanatory_comment_changed] } && runtime_delta.empty? ? "PASS" : "FAIL",
    claim_limit: "Inspection and focused repair reproduction are not a full G10 rerun or acceptance waiver. Original failed source/results remain unchanged." }
  LedgerFinalWP5.write(File.join(qa, "docs/reviews/assets", LedgerFinalWP5::STAMP, "spec-repair-inspection.json"), record)
  puts JSON.generate(version: version, verdict: record[:verdict], runtime_unchanged: runtime_delta.empty?, assertions_and_timeouts_unchanged: record[:product_assertions_and_timeouts_byte_identical_after_narrow_signature_normalization])
end
