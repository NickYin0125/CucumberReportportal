# frozen_string_literal: true

require "spec_helper"
require_relative "../../examples/day2_faults/sandbox"
require_relative "../../examples/day2_faults/live_validation"

RSpec.describe "Day2 opt-in runner local rehearsal" do
  around do |example|
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
  end

  it "rehearses every real-run scenario and reconciliation without cluster credentials" do
    sandbox = Day2Faults::Sandbox.new(max_body: 256 * 1024, artifact_visibility_delay: 0.06)
    directory = Dir.mktmpdir("day2-rehearsal-")
    suite = Day2Faults::LiveValidation.new(upstream: sandbox.endpoint, token: "local-synthetic", directory: directory,
                                          project: "day2")
    results = suite.run
    expect(results.length).to eq(14)
    failures = results.reject { |result| result[:validated] }.map { |result| result.slice(:label, :error_class, :error) }
    expect(failures).to be_empty, JSON.pretty_generate(failures)
    expect(results.find { |result| result[:label] == "partial-ack" }[:observed_duplicate_logs]).to eq(1)
    expect(results.find { |result| result[:label] == "hidden-ack" }[:observed_duplicate_logs]).to eq(1)
    expect(results.find { |result| result[:label] == "durable-replay" }[:controlled_replay].first[:confirmed]).to eq(1)
    if ENV["DAY2_LOCAL_CAPTURE"]
      FileUtils.cp_r(directory, File.join(ENV.fetch("DAY2_LOCAL_CAPTURE"), "live-runner-local-rehearsal"))
    end
  ensure
    sandbox&.stop
    FileUtils.remove_entry(directory) if directory && File.directory?(directory)
  end

  it "runs the executable 14-case matrix with normal RP environment credentials and no available helper" do
    sandbox = Day2Faults::Sandbox.new(max_body: 256 * 1024, artifact_visibility_delay: 0.06)
    directory = Dir.mktmpdir("day2-portable-cli-")
    root = File.expand_path("../..", __dir__)
    clean = ENV.keys.grep(/\A(?:RP_|DAY2_|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|http_proxy|https_proxy|all_proxy)/)
               .to_h { |key| [key, nil] }
    environment = clean.merge("DAY2_MANAGER_READY" => "true", "RP_ENDPOINT" => sandbox.endpoint,
                              "RP_PROJECT" => "portable_project", "RP_API_KEY" => "synthetic-portable-api-key",
                              "DAY2_EXPECTED_API_VERSION" => "5.15.4", "DAY2_EXPECTED_INSTANCE" => "sandbox-instance",
                              "DAY2_AUTH_HELPER" => "/not-available/auth-helper.rb", "DAY2_EVIDENCE_DIR" => directory)
    stdout, stderr, status = Open3.capture3(environment, RbConfig.ruby, "-I#{File.join(root, 'lib')}",
                                           File.join(root, "examples/day2_faults/run_live.rb"), "--execute-local-rp", chdir: root)
    expect(status.exitstatus).to eq(0), stdout + stderr
    path = Dir.glob(File.join(directory, "real-*", "summary.json")).fetch(0)
    summary = JSON.parse(File.read(path))
    expect(summary).to include("auth_source" => "environment", "project" => "portable_project")
    expect(summary.fetch("results").length).to eq(14)
    expect(summary.fetch("results").map { |result| result.fetch("validated") }).to all(be(true))
    expect(summary.dig("source", "unchanged_during_run")).to be(true)
    manifest = File.join(File.dirname(path), summary.dig("source", "manifest"))
    expect(summary.dig("source", "manifest_sha256")).to eq(Digest::SHA256.file(manifest).hexdigest)
    expect(stdout + stderr + File.read(path)).not_to include("synthetic-portable-api-key")
    if ENV["DAY2_LOCAL_CAPTURE"]
      FileUtils.cp_r(directory, File.join(ENV.fetch("DAY2_LOCAL_CAPTURE"), "portable-env-cli-rehearsal"))
    end
  ensure
    sandbox&.stop
    FileUtils.remove_entry(directory) if directory && File.directory?(directory)
  end
end
