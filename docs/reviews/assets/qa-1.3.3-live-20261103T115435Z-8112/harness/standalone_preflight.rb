# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"

lib = File.join(ENV.fetch("QA_SOURCE"), "lib")
checks = {
  redactor: "require 'reportportal_cucumber/automation/evidence_redactor'; abort 'redactor failed' if Automation::EvidenceRedactor.new.redact(password: 'synthetic').inspect.include?('synthetic')",
  http: "require 'reportportal_cucumber/automation/http_exchange'; value=Automation::HttpExchange.new(method: :get,url: 'https://example.test/orders',response: {status: 200}); abort 'summary failed' unless value.summary.include?('status=200')",
  accent: "require 'reportportal_cucumber/presentation/accent'; abort 'accent failed' unless ReportportalCucumber::Presentation::Accent.pill('safe',tone: :info).include?('safe')"
}
results = checks.map do |name, operation|
  script = operation + "; abort 'Cucumber loaded' if defined?(Cucumber); abort 'SDK core loaded' if defined?(ReportportalCucumber::Config); abort 'Bundler setup auto-loaded' if $LOADED_FEATURES.any? {|f| f.end_with?('/bundler/setup.rb')}; puts 'STANDALONE_OK'"
  command = ["env", "-u", "RUBYOPT", "-u", "BUNDLE_GEMFILE", "-u", "BUNDLE_BIN_PATH", "-u", "BUNDLER_VERSION", "-u", "BUNDLER_SETUP", RbConfig.ruby, "-I#{lib}", "-e", script]
  output, error, status = Open3.capture3(*command)
  raise "#{name} standalone preflight failed: #{output}\n#{error}" unless status.success? && output.strip == "STANDALONE_OK"
  { helper: name, exit: status.exitstatus, output: output.strip, stderr: error, argv: command }
end
result = { status: "PASS", ruby: RUBY_DESCRIPTION, rubygems: Gem::VERSION, current_bundle_preserved: defined?(Bundler) && Bundler::VERSION,
  child_bootstrap_flag_explicitly_unset: "BUNDLER_SETUP", parent_environment_mutated: false,
  orig_environment_deleted_blindly: false, checks: results }
File.write(ENV.fetch("QA_STANDALONE_PREFLIGHT_OUT"), JSON.pretty_generate(result) + "\n")
puts JSON.generate(result)
