# frozen_string_literal: true

require "json"

module ReleaseTooling
  # Authorizes a first package build after successful immutable-tag validation.
  # Existing artifacts or even an unpublished draft require the resume path instead.
  class RebuildGate
    REQUIRED_JOBS = [
      "preflight", "validate / gate",
      "validate / test (Ruby 3.3)", "validate / test (Ruby 3.4)",
      "validate / legacy (Ruby 3.1, Cucumber 9)",
      "validate / legacy (Ruby 3.1, Cucumber 10)",
      "validate / legacy (Ruby 3.3, Cucumber 9)",
      "validate / legacy (Ruby 3.3, Cucumber 10)"
    ].freeze

    # @param tag [String] Stable SDK 2.x tag, independently resolved by git.
    # @param sha [String] Immutable original commit.
    # @param run_id [String] Original Tag Release workflow run ID.
    # @param workflow_id [String] Repository's release.yml workflow ID.
    # @param run [Hash] GitHub workflow run metadata.
    # @param jobs [Array<Hash>] Latest-attempt job records, across all pages.
    # @param artifacts [Array<Hash>] All original-run artifacts, including expired ones.
    # @param releases [Array<Hash>] Authenticated releases, including drafts.
    # @return [true]
    # @raise [ArgumentError] When original validation or absence of assets is unproven.
    def self.verify!(tag:, sha:, run_id:, workflow_id:, run:, jobs:, artifacts:, releases:)
      valid = tag.match?(/\Av2\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/) &&
        sha.match?(/\A[0-9a-f]{40}\z/) && run_id.match?(/\A[1-9]\d*\z/) &&
        workflow_id.match?(/\A[1-9]\d*\z/)
      raise ArgumentError, "Invalid original release identity" unless valid
      expected = { "id" => Integer(run_id), "workflow_id" => Integer(workflow_id),
                   "head_sha" => sha, "head_branch" => tag, "event" => "push",
                   "status" => "completed", "conclusion" => "failure" }
      raise ArgumentError, "Original tag run identity or state mismatch" unless expected.all? { |key, value| run.fetch(key) == value }

      REQUIRED_JOBS.each { |name| require_job!(jobs, name, "success") }
      require_job!(jobs, "validate / bundle", "failure")
      require_job!(jobs, "publish", "skipped")
      prefix = "release-bundle-#{run_id}-"
      raise ArgumentError, "Original bundle exists; use artifact resume" if artifacts.any? { |artifact| artifact.fetch("name").start_with?(prefix) }
      raise ArgumentError, "Release or draft already exists; refuse rebuilding" if releases.any? { |release| release.fetch("tag_name") == tag }

      true
    end

    # @param jobs [Array<Hash>]
    # @param name [String]
    # @param conclusion [String]
    # @return [void]
    def self.require_job!(jobs, name, conclusion)
      matching = jobs.select { |job| job.fetch("name") == name }
      valid = matching.length == 1 && matching.first.fetch("status") == "completed" &&
        matching.first.fetch("conclusion") == conclusion
      raise ArgumentError, "Missing, duplicate or unsuccessful job: #{name}" unless valid
    end
    private_class_method :require_job!
  end
end

if $PROGRAM_NAME == __FILE__
  tag, sha, run_id, workflow_id, directory = ARGV
  read = ->(name) { JSON.parse(File.read(File.join(directory, "#{name}.json"))) }
  ReleaseTooling::RebuildGate.verify!(
    tag: tag, sha: sha, run_id: run_id, workflow_id: workflow_id,
    run: read.call("run"), jobs: read.call("jobs").flat_map { |page| page.fetch("jobs") },
    artifacts: read.call("artifacts").flat_map { |page| page.fetch("artifacts") },
    releases: read.call("releases").flatten(1)
  )
  puts "Original tag matrices passed; no original bundle or release exists."
end
