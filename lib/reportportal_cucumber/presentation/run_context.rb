# frozen_string_literal: true

require_relative "markdown_text"

module ReportportalCucumber
  module Presentation
    # Builds opt-in Launch metadata from a small, explicit environment allowlist.
    module RunContext
      VALUE_LIMIT = 128

      # @param attributes [Array<Hash>] Explicit attributes always take precedence.
      # @param description [String, nil] A non-empty explicit description is untouched.
      # @param sdk_version [String] Active SDK version.
      # @param cucumber_version [String] Active Cucumber version.
      # @param ruby_version [String] Active Ruby version.
      # @param include_workers [Boolean] False on the maintenance 1.x release line.
      # @param env [Hash, ENV] Environment snapshot; only documented keys are read.
      # @return [Hash] New :attributes and :description, without mutating inputs.
      def self.build(attributes:, description:, sdk_version:, cucumber_version:, include_workers:, env: ENV,
                     ruby_version: RUBY_VERSION)
        baseline = { attributes: attributes, description: description }
        Fallback.render(fallback: -> { baseline }) do
          branch = first(env, "GITHUB_REF_NAME", "CI_COMMIT_REF_NAME", "BRANCH_NAME")
          sha = first(env, "RP_SOURCE_COMMIT", "GITHUB_SHA", "CI_COMMIT_SHA")&.slice(0, 7)
          build_id = first(env, "GITHUB_RUN_ID", "CI_PIPELINE_ID", "BUILD_NUMBER")
          workers = first(env, "PARALLEL_TEST_GROUPS") if include_workers
          values = { "sdk" => trim(sdk_version), "cucumber" => trim(cucumber_version), "ruby" => trim(ruby_version),
                     "workers" => workers, "git.branch" => branch, "git.sha" => sha, "ci.build" => build_id }
          explicit = Array(attributes).map(&:dup)
          keys = explicit.map { |entry| (entry[:key] || entry["key"]).to_s }
          values.each do |key, value|
            explicit << { key: key, value: value } if value && !keys.include?(key)
          end

          generated = ["Cucumber #{trim(cucumber_version)}", "Ruby #{trim(ruby_version)}"]
          generated << "#{workers} #{workers == '1' ? 'worker' : 'workers'}" if workers
          generated << [branch, sha].compact.join("@") if branch || sha
          output_description = description
          if description.to_s.empty?
            output_description = generated.map { |part| MarkdownText.inline(part, limit: 512) }.join(" · ")
          end
          { attributes: explicit, description: output_description }
        end
      end

      def self.first(env, *keys)
        keys.each do |key|
          value = trim(env[key])
          return value if value
        end
        nil
      end

      def self.trim(value)
        return nil if value.nil?

        # Bound work before Unicode conversion, then apply the documented character limit.
        text = value.to_s.byteslice(0, 4096).to_s.dup.force_encoding(Encoding::UTF_8).scrub.strip.slice(0, VALUE_LIMIT)
        text.empty? ? nil : text
      end
      private_class_method :first, :trim
    end
  end
end
