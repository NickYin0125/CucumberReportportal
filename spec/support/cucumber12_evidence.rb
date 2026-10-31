# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "open3"
require "time"

module Cucumber12Evidence
  module_function

  def read(path)
    JSON.parse(File.read(path))
  end

  def coverage(directory, parent:)
    processes = Dir[File.join(directory, "**/*.json")].map { |path| read(path) }
    selected = parent.nil? ? processes : processes.select { |entry| entry.fetch("program").include?("rspec") == parent }
    files = {}
    selected.each do |process|
      process.fetch("files").each do |path, measurement|
        previous = files[path]
        if previous
          raise "Cannot merge different compiled sources for #{path}" unless previous["sha256"] == measurement["sha256"]

          previous.fetch("lines").each_with_index do |count, index|
            other = measurement.fetch("lines")[index]
            previous.fetch("lines")[index] = count.to_i + other.to_i unless count.nil? && other.nil?
          end
        else
          files[path] = measurement.dup.merge("lines" => measurement.fetch("lines").dup)
        end
      end
    end
    per_file = files.transform_values do |entry|
      counts = entry.fetch("lines")
      { covered: counts.count { |count| count && count.positive? }, executable: counts.compact.length,
        sha256: entry.fetch("sha256"), compiled_sha256: entry["compiled_sha256"] }
    end
    covered = per_file.values.sum { |entry| entry.fetch(:covered) }
    executable = per_file.values.sum { |entry| entry.fetch(:executable) }
    { processes: selected.length, loaded_files: per_file.length, covered: covered, executable: executable,
      percent: executable.zero? ? nil : (covered * 100.0 / executable).round(3), files: per_file }
  end

  def case_summary(path)
    result = read(path)
    wire = result.fetch("wire")
    items = wire.fetch("items").values
    tests = items.select { |item| item["type"] == "STEP" && item["hasStats"] }
    {
      evidence: File.basename(path), native_exit: result.fetch("exit"), seconds: result.fetch("seconds"),
      reporting_receipt: result["receipt"],
      wire_errors: wire.fetch("errors"),
      native_statuses: result.fetch("native").filter_map { |entry| entry.dig("testStepFinished", "testStepResult", "status") }.uniq,
      will_be_retried: result.fetch("native").filter_map { |entry| entry["testCaseFinished"] }.map { |entry| entry["willBeRetried"] },
      scenarios: tests.map { |item| item.slice("name", "uuid", "parentUuid", "testCaseId", "uniqueId", "retry", "finish") },
      launches: wire.fetch("launches").values.map { |entry| entry.slice("uuid", "name", "finish") },
      item_count: items.length, unique_item_uuids: items.map { |item| item.fetch("uuid") }.uniq.length,
      native_attach_called_count: result.fetch("events", []).length,
      native_attachment_envelope_count: result.fetch("native").count { |entry| entry["attachment"] },
      html_bytes: result.fetch("html_bytes", 0),
      attachments: wire.fetch("logs").filter_map do |entry|
        file = entry["wireFile"]
        next unless file

        bytes = Base64.strict_decode64(file.fetch("base64"))
        file.slice("name", "mime").merge("itemUuid" => entry["itemUuid"], "bytes" => bytes.bytesize,
                                          "sha256" => Digest::SHA256.hexdigest(bytes))
      end,
      injected_503_count: wire.fetch("requests").count { |request| request["injectedStatus"] == 503 },
      unhandled_thread_exception: (result.fetch("stdout") + result.fetch("stderr")).match?(/terminated with exception|report_on_exception/)
    }
  end

  def run(baseline, candidate, output, linux = nil)
    root = File.expand_path("../..", __dir__)
    baseline_result = read(File.join(baseline, "rspec.json"))
    candidate_result = read(File.join(candidate, "rspec.json"))
    summaries = Dir[File.join(candidate, "cli/*.json")].sort.map { |path| case_summary(path) }
    data = {
      generated_at: Time.now.utc.iso8601, baseline_commit: "4ca2f770e0a84e83688f165ba04b4db8ef855cf9",
      candidate_git_head: Open3.capture2("git", "rev-parse", "HEAD", chdir: root).first.strip,
      candidate_is_uncommitted_worktree: true,
      source_sha256: Dir[File.join(root, "lib/**/*.rb")].sort.to_h { |path| [path.delete_prefix(root + "/"), Digest::SHA256.file(path).hexdigest] },
      baseline_rspec: baseline_result.fetch("summary"), candidate_rspec: candidate_result.fetch("summary"),
      candidate_examples: candidate_result.fetch("examples").map { |entry| entry.slice("full_description", "status", "file_path", "line_number", "exception") },
      candidate_cucumber_transcript: File.read(File.join(candidate, "cucumber.log")),
      coverage_scope: "Only SDK lib files loaded by the measured process. Child CLI coverage is separate; not total repository coverage or a 100% claim.",
      baseline_rspec_in_process_coverage: coverage(File.join(baseline, "coverage"), parent: true),
      candidate_rspec_in_process_coverage: coverage(File.join(candidate, "coverage"), parent: true),
      candidate_acceptance_child_cli_coverage: coverage(File.join(candidate, "coverage/acceptance-cli"), parent: false),
      baseline_observed_process_union_coverage: coverage(File.join(baseline, "coverage"), parent: nil),
      candidate_observed_process_union_coverage: coverage(File.join(candidate, "coverage"), parent: nil),
      native_cases: summaries,
      packaging: read(File.join(candidate, "packaging/packaging-manifest.json"))
    }
    data[:packaging_current_core_audit] = data.fetch(:source_sha256).to_h do |path, digest|
      [path, data.fetch(:packaging).fetch("source_sha256")[path] == digest]
    end
    raise "Final package contains stale SDK source" unless data[:packaging_current_core_audit].values.all?
    parallel_parent = File.join(candidate, "parallel-parent.json")
    data[:parallel_parent_after_workers] = read(parallel_parent) if File.file?(parallel_parent)
    if linux
      linux_results = read(File.join(linux, "rspec.json"))
      linux_package = read(File.join(linux, "packaging/packaging-manifest.json"))
      data[:ruby33] = { rspec: linux_results.fetch("summary"),
                       nonpassing_examples: linux_results.fetch("examples").reject { |entry| entry["status"] == "passed" }
                         .map { |entry| entry.slice("full_description", "status", "pending_message", "exception") },
                       cucumber_transcript: File.read(File.join(linux, "cucumber.log")),
                       image: "ruby:3.3-slim", ruby: linux_package.fetch("ruby_version"), helm: "3.18.4",
                       packaging: linux_package }
      data[:ruby33][:packaging_current_core_audit] = data.fetch(:source_sha256).to_h do |path, digest|
        [path, data[:ruby33][:packaging].fetch("source_sha256")[path] == digest]
      end
      raise "Ruby 3.3 package contains stale SDK source" unless data[:ruby33][:packaging_current_core_audit].values.all?
    end
    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(data) + "\n")
    File.write(output.sub(/\.json\z/, "-wire.json"), JSON.pretty_generate(
      Dir[File.join(candidate, "cli/*.json")].sort.to_h { |path| [File.basename(path), read(path)] }
    ) + "\n")
    puts JSON.generate(baseline: data[:baseline_rspec], candidate: data[:candidate_rspec], ruby33: data.dig(:ruby33, :rspec), native_cases: summaries.length)
  end
end

Cucumber12Evidence.run(*ARGV) if $PROGRAM_NAME == __FILE__
