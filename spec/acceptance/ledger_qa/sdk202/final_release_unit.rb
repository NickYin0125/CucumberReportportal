# frozen_string_literal: true

require_relative "final_release_common"

FinalRelease202.verify
paths = %w[
  spec/reportportal_cucumber/automation/evidence_redactor_encoded_safety_spec.rb
  spec/reportportal_cucumber/automation/evidence_redactor_encoded_url_spec.rb
  spec/reportportal_cucumber/automation/failure_redactor_malformed_url_spec.rb
  spec/reportportal_cucumber/automation/failure_redactor_spec.rb
  spec/reportportal_cucumber/automation/failure_redactor_reuse_spec.rb
  spec/reportportal_cucumber/automation/cucumber_logger_spec.rb
  spec/reportportal_cucumber/automation/http_ledger_spec.rb
  spec/reportportal_cucumber/service/evidence_presenter_spec.rb
  spec/reportportal_cucumber/presentation/failure_card_spec.rb
]
command = [RbConfig.ruby, "-I", File.join(FinalRelease202::SOURCE, "lib"), "-I", File.join(FinalRelease202::SDK, "spec"),
  "-e", 'gem "diff-lcs", "< 2"; require "rspec/core"; exit RSpec::Core::Runner.run(ARGV)', "--",
  *paths.map { |p| File.join(FinalRelease202::SDK, p) }, "--format", "json"]
result = FinalRelease202.command(*command, chdir: FinalRelease202::OUT, env: { "RP_API_KEY" => nil }, seconds: 90)
FinalRelease202.write(File.join(FinalRelease202::OUT, "focused-rspec.json"), result.merge(source_sha: FinalRelease202::SHA,
  specs: paths.map { |p| { path: p, sha256: Digest::SHA256.file(File.join(FinalRelease202::SDK, p)).hexdigest } }))
summary = JSON.parse(result[:stdout]).fetch("summary") rescue { harness_error: true }
puts JSON.generate(exit: result[:exit], summary: summary)
exit(result[:exit] || 2)
