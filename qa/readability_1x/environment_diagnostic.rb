# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"

SAFE_KEYS = %w[RUBYOPT RUBYLIB RUBYGEMS_GEMDEPS GEM_HOME GEM_PATH BUNDLE_GEMFILE BUNDLE_PATH BUNDLE_APP_CONFIG BUNDLE_BIN_PATH BUNDLER_VERSION BUNDLER_SETUP BUNDLER_ORIG_BUNDLER_SETUP BUNDLER_ORIG_RUBYOPT BUNDLER_ORIG_RUBYLIB BUNDLER_ORIG_RUBYGEMS_GEMDEPS BUNDLER_ORIG_GEM_HOME BUNDLER_ORIG_GEM_PATH BUNDLER_ORIG_BUNDLE_GEMFILE BUNDLER_ORIG_BUNDLE_BIN_PATH BUNDLER_ORIG_BUNDLER_VERSION].freeze

def metadata
  { ruby: RUBY_DESCRIPTION, rubyopt: ENV["RUBYOPT"], rubygems: Gem::VERSION,
    safe_environment: ENV.to_h.slice(*SAFE_KEYS), working_directory: Dir.pwd,
    gemdeps_method: Gem.method(:use_gemdeps).source_location,
    startup_features: $LOADED_FEATURES.grep(%r{rubygems_plugin|bundler/setup|rubygems/defaults}) }
end

if ARGV.include?("--bundled-child")
  result = metadata
  code = "require 'reportportal_cucumber/automation/evidence_redactor'; abort 'Cucumber loaded' if defined?(Cucumber); puts JSON.generate(ok: true, rubygems: Gem::VERSION, gemdeps: ENV['RUBYGEMS_GEMDEPS'])"
  output, status = Open3.capture2e("env", "-u", "RUBYOPT", "-u", "BUNDLE_GEMFILE", "-u", "BUNDLE_BIN_PATH", "-u", "BUNDLER_VERSION",
    RbConfig.ruby, "-I/tmp/qa-1x-source/lib", "-rjson", "-e", code)
  result[:exact_standalone_child] = { exit: status.exitstatus, output: output }
  result[:removed_specific_flag] = ENV.delete("BUNDLER_SETUP")
  corrected, corrected_status = Open3.capture2e("env", "-u", "RUBYOPT", "-u", "BUNDLE_GEMFILE", "-u", "BUNDLE_BIN_PATH", "-u", "BUNDLER_VERSION",
    RbConfig.ruby, "-I/tmp/qa-1x-source/lib", "-rjson", "-e", code)
  result[:corrected_same_standalone_child] = { exit: corrected_status.exitstatus, output: corrected }
  method_file, method_line = Gem.method(:use_gemdeps).source_location
  result[:gemdeps_source_excerpt] = File.readlines(method_file)[method_line - 1, 55].join
  result[:rubygems_startup_footer] = File.readlines(method_file).last(8).join
  puts JSON.pretty_generate(result)
  exit
end

FileUtils.cp_r("/source", "/tmp/qa-1x-source")
FileUtils.cp_r("/bundle", "/tmp/qa-1x-bundle")
FileUtils.mkdir_p("/tmp/qa-1x-runtime")
FileUtils.cp("/original/Gemfile.resolved", "/tmp/qa-1x-runtime/Gemfile")
FileUtils.cp("/original/Gemfile.resolved.lock", "/tmp/qa-1x-runtime/Gemfile.lock")
baseline = metadata
env = { "BUNDLE_GEMFILE" => "/tmp/qa-1x-runtime/Gemfile", "BUNDLE_PATH" => "/tmp/qa-1x-bundle", "BUNDLE_IGNORE_CONFIG" => "1", "BUNDLE_FROZEN" => "true" }
output, status = Open3.capture2e(env, "bundle", "_2.6.6_", "exec", "ruby", __FILE__, "--bundled-child", chdir: "/tmp/qa-1x-source")
result = { bare_image: baseline, bundled_child_exit: status.exitstatus, bundled_child_output: output,
  sdk_tests_run: false, network_used: false }
File.write("/diagnostic/environment-diagnostic.json", JSON.pretty_generate(result) + "\n")
puts JSON.pretty_generate(result)
