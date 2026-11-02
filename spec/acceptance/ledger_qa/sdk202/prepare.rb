# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "fileutils"

module Ledger202Preparation
  ROOT = File.expand_path("../../../..", __dir__)
  QA_BASE = "2f1bf137bab26a39b3c81e6ed8bf9d165acc1411"
  RUNTIME_BASE = "3f20313c20b25071fbc49b31e1c6bc772bd599e4"
  RELEASE = "ef38224b28b451dc4cc94ac314906ac4ecee459a"
  QUIET = "docs/reviews/assets/wp5-ci-final-20261101-quiet/probes/c12.0.1"
  OUTPUT = "docs/reviews/assets/ledger-2.0.2-preparation"

  def self.git(*args)
    out, _, status = Open3.capture3("git", "-C", ROOT, *args)
    raise "Git evidence read failed" unless status.success?
    out.strip
  end

  def self.read(path)
    JSON.parse(File.binread(File.join(ROOT, path)))
  end

  def self.proof(path)
    bytes = File.binread(File.join(ROOT, path))
    blob = git("rev-parse", "#{QA_BASE}:#{path}")
    actual = Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0".b + bytes)
    raise "Historical evidence changed: #{path}" unless blob == actual
    { path: path, git_commit: QA_BASE, git_blob: blob, sha256: Digest::SHA256.hexdigest(bytes) }
  end

  def self.p95(samples)
    raise "Empty historical samples" if samples.empty?
    samples.sort[(samples.length * 0.95).ceil - 1]
  end

  def self.native_errors(value)
    case value
    when Array then value.flat_map { |v| native_errors(v) }
    when Hash
      own = value["status"] == "failed" && value["error_message"] ? [value["error_message"]] : []
      own + value.values.flat_map { |v| native_errors(v) }
    else []
    end
  end

  def self.build
    raise "Wrong QA branch" unless git("branch", "--show-current") == "qa/presentation-ledger-2.0.2"
    report_path = "docs/reviews/assets/presentation-ledger-2.0.1-acceptance.json"
    checks_path = "docs/reviews/assets/wp5-ci-final-20261101/checks.json"
    old_path = "docs/reviews/assets/ledger-qa-performance-2.0.1.json"
    report = read(report_path)
    check = read(checks_path).fetch("checks").select { |c| c["criterion"] == "G11" }
    raise "Ambiguous accepted G11" unless check.length == 1
    check = check.first
    accepted = report.fetch("checks").select { |c| c["criterion"] == "G11" && c["verdict"] == "PASS" }
    raise "Historical signoff mismatch" unless accepted.length == 1 &&
      accepted.first.fetch("actual") == check.fetch("actual") && check["verdict"] == "PASS" &&
      check["runtime_sha"] == RUNTIME_BASE && read(old_path)["verdict"] == "FAIL"

    files = Dir[File.join(ROOT, QUIET, "{micro,parallel-micro}-*/**/presentation-timings.json")].sort
    micro = Hash.new { |h, k| h[k] = [] }
    provenance = files.map do |file|
      path = file.delete_prefix(ROOT + "/")
      data = read(path)
      raise "Historical replay errors" unless data.fetch("replay_errors").empty?
      data.fetch("samples").each { |name, values| micro[name].concat(values) }
      proof(path)
    end
    summary = micro.transform_values { |s| { "count" => s.length, "p95_ms" => p95(s) } }
    raise "Raw micro timings disagree with accepted check" unless summary == check.dig("actual", "micro")
    wall = %w[baseline plain rich].to_h do |mode|
      paths = Dir[File.join(ROOT, QUIET, "wall-*-#{mode}/F07/process.json")].sort.map { |p| p.delete_prefix(ROOT + "/") }
      raise "Historical wall coverage differs" unless paths.length == 3
      provenance.concat(paths.map { |p| proof(p) })
      samples = paths.map { |p| read(p).fetch("seconds") }
      [mode, { "samples_s" => samples, "median_s" => samples.sort[1] }]
    end
    raise "Raw wall timings disagree with accepted check" unless wall == check.dig("actual", "wall")

    modes = %w[plain rich].to_h do |mode|
      cases = []
      Dir[File.join(ROOT, QUIET, "micro-#{mode}/*/presentation-timings.json")].sort.each do |file|
        timing_path = file.delete_prefix(ROOT + "/")
        count = read(timing_path).fetch("samples").fetch("FailureCard.format", []).length
        next if count.zero?
        ndjson = timing_path.sub("presentation-timings.json", "native.ndjson")
        native = timing_path.sub("presentation-timings.json", "native.json")
        exceptions = File.readlines(File.join(ROOT, ndjson)).map do |line|
          JSON.parse(line).dig("testStepFinished", "testStepResult", "exception")
        end.compact
        raise "Historical replay weighting mismatch" unless count == exceptions.length * 50
        errors = native_errors(read(native))
        origins = [proof(ndjson), proof(native), proof(timing_path)]
        exceptions.each do |error|
          frames = error.fetch("stackTrace", "").split("\n", -1)
          frames = [] if error.fetch("stackTrace", "").empty?
          raw = "#{error.fetch('message')} (#{error.fetch('type')})"
          raw += "\n" + frames.join("\n") unless frames.empty?
          raise "Native message/frame boundary unproven" unless errors.include?(raw)
          row = { "class" => error.fetch("type"), "message" => error.fetch("message"), "frames" => frames }
          row["input_id"] = Digest::SHA256.hexdigest(JSON.generate(row.values_at("class", "message", "frames")))
          row["fixture"] = File.basename(File.dirname(file))
          row["origins"] = origins
          cases << row
        end
      end
      raise "Historical FailureCard corpus is not 21 inputs" unless cases.length == 21
      [mode, cases]
    end
    raise "Plain/rich raw corpora differ" unless modes["plain"].map { |r| r["input_id"] } == modes["rich"].map { |r| r["input_id"] }
    ids = modes.fetch("plain").map { |r| r.fetch("input_id") }
    corpus = { schema: "ledger-202-historical-failure-inputs/1", status: "PREPARATION_ONLY",
      corpus_sha256: Digest::SHA256.hexdigest(JSON.generate(ids)), cases: modes.fetch("plain"),
      rich_origins: modes.fetch("rich").map { |r| { input_id: r["input_id"], origins: r["origins"] } } }
    helpers = %w[performance.rb performance_support.rb final_wp5_driver.rb final_wp5_score.rb
      isolated.rb runtime-support.rb].map { |p| proof("spec/acceptance/ledger_qa/#{p}") }
    raise "Historical observer mismatch" unless helpers.find { |p| p[:path].end_with?("performance_support.rb") }[:sha256] == check.dig("inputs", "timing_observer_sha256")
    lib_diff = git("diff", "--name-only", RUNTIME_BASE, RELEASE, "--", "lib")
    raise "Released 2.0.1 library differs from measured baseline" unless lib_diff.empty?
    env_path = "#{QUIET}/micro-plain/provenance.json"
    runtime = read(env_path).fetch("runtime")
    plan = { schema: "ledger-202-baseline-preparation/1", status: "HOLD_FOR_MASTER",
      final_runtime_sha: nil, final_launch_ids: [], quiet_window: nil, final_verdict: nil,
      qa_base: QA_BASE, accepted_runtime: RUNTIME_BASE, released_201: RELEASE,
      measured_release_lib_diff: lib_diff, accepted_check_id: accepted.first.fetch("check_id"),
      accepted_check: check, historical_boundary: "renderer_only; excludes formatter redaction",
      excluded_early_result: { proof: proof(old_path), verdict: "FAIL", p95_ms: read(old_path).dig("micro", "FailureCard.format", "p95_ms") },
      reports: [proof(report_path), proof(checks_path), proof("docs/reviews/2026-11-01-presentation-ledger-2.0.1-acceptance.md")],
      raw_timing_files: provenance, harness: helpers, corpus_sha256: corpus[:corpus_sha256],
      historical_environment: { proof: proof(env_path), ruby: runtime.fetch("ruby"), cucumber: runtime.fetch("cucumber"),
        dependencies: runtime.fetch("gems").transform_values { |v| v.fetch("version") },
        image_note: "Historical probe used mutable ruby:3.4-slim; exact image ID not proven by that command. Pin one image for both fresh arms; do not infer it from matrix image IDs." },
      planned_boundaries: %w[renderer_only redaction_plus_rendering],
      samples_per_mode_per_boundary: 1050, warmups_per_input: 10, samples_per_input: 50,
      stop_ratio: 1.10, presentation_p95_limit_ms_exclusive: 2,
      source_executions: 0, new_launches: [], benchmarks_executed: 0 }
    [plan, corpus]
  end

  def self.write_new(path, value)
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(JSON.pretty_generate(value) + "\n") }
  end

  def self.run
    plan, corpus = build
    output = File.join(ROOT, OUTPUT)
    raise "Preparation already exists; never overwrite evidence" if File.exist?(output)
    FileUtils.mkdir_p(output)
    write_new(File.join(output, "baseline.json"), plan)
    write_new(File.join(output, "failure-corpus.json"), corpus)
    puts JSON.generate(status: plan[:status], historical_p95_ms: plan.dig(:accepted_check, "actual", "micro", "FailureCard.format", "p95_ms"),
      cases: corpus[:cases].length, raw_timing_files: plan[:raw_timing_files].length, benchmarks_executed: 0)
  end
end

Ledger202Preparation.run if $PROGRAM_NAME == __FILE__
