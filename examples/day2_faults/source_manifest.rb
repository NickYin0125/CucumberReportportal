# frozen_string_literal: true

require "digest"
require "json"
require "fileutils"
require "rbconfig"

module Day2Faults
  module SourceManifest
    ROOT = File.expand_path("../..", __dir__)
    INPUTS = %w[examples/day2_faults/*.rb examples/day2_faults/*.feature examples/day2_faults/*.yml
                examples/day2_faults/README.md spec/day2/fault_*.rb lib/**/*.rb Gemfile Gemfile.lock
                reportportal-cucumber-ruby.gemspec].freeze
    module_function

    def capture
      files = INPUTS.flat_map { |pattern| Dir.glob(pattern, base: ROOT) }.uniq.sort.to_h do |path|
        [path, Digest::SHA256.file(File.join(ROOT, path)).hexdigest]
      end
      { algorithm: "SHA256", files: files, inputs_sha256: Digest::SHA256.hexdigest(JSON.generate(files)),
        ruby: RUBY_VERSION, ruby_platform: RUBY_PLATFORM, ruby_executable: RbConfig.ruby,
        cucumber: Gem.loaded_specs["cucumber"]&.version&.to_s,
        excluded_generated_report: "examples/day2_faults/VALIDATION.md" }
    end

    def record(directory:, before:)
      after = capture
      stable = before.fetch(:inputs_sha256) == after.fetch(:inputs_sha256)
      FileUtils.mkdir_p(directory, mode: 0o700)
      path = File.join(directory, "source-manifest.json")
      File.open(path, "wb", 0o600) do |file|
        file.write(JSON.pretty_generate(before: before, after: after, unchanged_during_run: stable))
      end
      { manifest: "source-manifest.json", manifest_sha256: Digest::SHA256.file(path).hexdigest,
        inputs_sha256: before.fetch(:inputs_sha256), unchanged_during_run: stable }
    end
  end
end
