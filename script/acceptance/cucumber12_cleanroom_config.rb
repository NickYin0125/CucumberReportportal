# frozen_string_literal: true

require "digest"
require "json"
require "rubygems/package"
require_relative "cucumber12_cleanroom_audit"

module Cucumber12Cleanroom
  class Config
    ROOT = File.expand_path("../..", __dir__)
    BASELINE_SHA = "68b1ab8889f1e3448f6809b498c0aa7ff9ef9a03f4f1f5ae6d4e01fe2f6d17b3"
    LEGACY_SHA = "bbec7ce0840ea17ae1d7d6106a2047a92474b970c57131ced8679f7e75e54e12"
    LEGACY_PATH = "pkg/releases/v1.3.1/reportportal-cucumber-ruby-1.3.1.gem"
    RUNTIME_CONTRACT = {
      "aws-sdk-s3" => ">= 1.180", "base64" => "~> 0.2", "cgi" => "~> 0.4",
      "cucumber" => "~> 12.0, >= 12.0.1", "logger" => "~> 1.6", "mime-types" => ">= 3.5"
    }.freeze

    attr_reader :packages, :expected_source_head

    def initialize(env = ENV, root: ROOT)
      archive = env.fetch("CLEANROOM_CANDIDATE_ARCHIVE", "")
      sha = env.fetch("CLEANROOM_CANDIDATE_SHA256", "")
      raise ArgumentError, "Set BOTH CLEANROOM_CANDIDATE_ARCHIVE and CLEANROOM_CANDIDATE_SHA256; no baseline fallback" if archive.empty? || sha.empty?
      raise ArgumentError, "CLEANROOM_CANDIDATE_SHA256 must be exactly 64 lowercase hex characters" unless sha.match?(/\A[0-9a-f]{64}\z/)
      @expected_source_head = env["CLEANROOM_EXPECTED_SOURCE_HEAD"]
      if @expected_source_head && !@expected_source_head.match?(/\A[0-9a-f]{40}\z/)
        raise ArgumentError, "CLEANROOM_EXPECTED_SOURCE_HEAD must be exactly 40 lowercase hex characters"
      end
      @packages = {
        "2.0.0" => { path: File.realpath(File.expand_path(archive, root)), sha256: sha },
        "1.3.1" => { path: File.realpath(File.join(root, LEGACY_PATH)), sha256: LEGACY_SHA }
      }
      manifest
    end

    def manifest
      packages.to_h do |version, entry|
        path, sha = entry.values_at(:path, :sha256)
        verify_hash!(path, sha)
        spec = Gem::Package.new(path).spec
        unless spec.name == "reportportal-cucumber-ruby" && spec.version.to_s == version && spec.platform.to_s == "ruby"
          raise ArgumentError, "Unexpected package identity/platform: #{path}"
        end
        required_entrypoints = Cucumber12CleanroomAudit.required_entrypoints(version: version)
        missing = required_entrypoints - spec.files
        raise ArgumentError, "Required SDK entrypoints absent from archive manifest: #{missing.join(', ')}" unless missing.empty?
        if version == "2.0.0"
          runtime = spec.runtime_dependencies.to_h { |dep| [dep.name, dep.requirement.to_s] }
          unless runtime == RUNTIME_CONTRACT && spec.required_ruby_version.to_s == ">= 3.3"
            raise ArgumentError, "Candidate runtime dependency/Ruby contract changed; stop for parent review"
          end
        end
        verify_hash!(path, sha)
        [version, { path: path, sha256: sha, filename: filename(version), bytes: File.size(path),
                    payload_files: spec.files.size, payload_paths_sha256: Digest::SHA256.hexdigest(spec.files.sort.join("\n")),
                    required_ruby: spec.required_ruby_version.to_s,
                    required_entrypoints: required_entrypoints,
                    gemspec_sha256: Digest::SHA256.hexdigest(spec.to_ruby),
                    dependencies: spec.dependencies.map { |dep| { name: dep.name, type: dep.type, requirement: dep.requirement.to_s } } }]
      end
    end

    def filename(version)
      "reportportal-cucumber-ruby-#{version}.gem"
    end

    def hashes
      packages.transform_values { |entry| entry.fetch(:sha256) }
    end

    def candidate_kind
      hashes.fetch("2.0.0") == BASELINE_SHA ? "baseline" : "candidate"
    end

    def latest_pointer
      candidate_kind == "baseline" ? "latest-baseline-reproduction.json" : "latest-postfix.json"
    end

    def verify_hash!(path, expected)
      raise ArgumentError, "Not a regular gem archive: #{path}" unless File.file?(path) && path.end_with?(".gem")
      raise ArgumentError, "Archive SHA-256 mismatch: #{path}" unless Digest::SHA256.file(path).hexdigest == expected
    end
  end
end
