# frozen_string_literal: true

require_relative "release_perf_validity_driver"

module ReleasePerfRemainder202
  B = ReleasePerfDriver202
  V = ReleasePerfValidity202
  OUT = B::OUT
  STAGE = V::STAGE
  READY = File.join(OUT, "remaining-readiness-v6-authorized.json")
  PRIOR = File.join(OUT, "isolated-v5-20261102T150814Z")

  def self.verify
    V.verify
    proof = B.read(READY)
    raise "Remainder entry changed" unless Digest::SHA256.file(__FILE__).hexdigest == proof.fetch("entry_sha256")
    raise "V6 package changed" unless Digest::SHA256.file(File.join(OUT, "harness-manifest-v6.json")).hexdigest == proof.fetch("package_manifest_sha256")
    proof.fetch("retained_v5_files").each do |row|
      raise "Retained V5 evidence changed" unless Digest::SHA256.file(File.join(OUT, row.fetch("path"))).hexdigest == row.fetch("sha256")
    end
  end

  def self.prepare
    raise "Readiness exists" if File.exist?(READY)
    V.verify
    validity = Dir.glob(File.join(OUT, "v6-*-validity.json")).map { |p| B.read(p) }
    raise "Seven untimed validity runs required" unless validity.length == 7 && validity.all? { |j| j["status"] == "PASS_UNTIMED" && j["timing_samples_collected"] == 0 }
    previous = B.read(File.join(PRIOR, "result.json"))
    raise "V5 complete frozen21 PASS absent" unless previous.dig("frozen21", "status") == "PASS" && previous.dig("frozen21", "rounds") == 2 &&
      previous.dig("frozen21", "comparisons").length == 8
    (1..2).each do |round|
      %w[plain rich].each do |mode|
        a, z = %w[baseline candidate].map { |role| B.read(File.join(PRIOR, "round#{round}-#{role}-#{mode}.json")) }
        rows = ReleasePerf202.compare(a, z)
        raise "Retained comparison did not pass" unless rows.all? { |r| r["regression_pass"] && r["renderer_under_2ms"] != false }
      end
    end
    paths = Dir.glob(File.join(PRIOR, "*.json")) + [File.join(OUT, "harness-manifest-v5.json"), File.join(OUT, "final-result-v5.json")]
    proof = paths.sort.map { |p| { path: p.delete_prefix(OUT + "/"), sha256: Digest::SHA256.file(p).hexdigest } }
    B.write(READY, status: "READY_WAITING_NEW_MASTER_PAUSED_WINDOW", entry_sha256: Digest::SHA256.file(__FILE__).hexdigest,
      package_manifest_sha256: Digest::SHA256.file(File.join(OUT, "harness-manifest-v6.json")).hexdigest,
      validity_runs: 7, timing_samples_from_validity: 0, retained_v5_files: proof,
      next_scope: "Remaining only: 9 F07 runs, plain/rich F01-F18 and F06 replay, 4 supplementary absolute-URL arms; no frozen21 rerun",
      expected_duration: "3-5 minutes estimated, not a performance claim; deadline abort before the 600-second restore watchdog without reducing samples",
      timestamp_names: { execution_deadline_utc: "Configured deadline", actual_execution_end_utc: "Observed end or STOP" })
    puts JSON.generate(B.read(READY).reject { |k, _| k == "retained_v5_files" })
  end

  def self.container(role)
    B.container(role).map { |entry| entry == B::STAGE ? STAGE : entry }
  end

  def self.execute(window, label, role, tail)
    verify
    args = container(role) + tail
    stdout, stderr, status = Open3.capture3(*args)
    B.write(File.join(window, "#{label}-process.json"), argv: args, exit: status.exitstatus, stdout: stdout, stderr: stderr)
    raise B::Invalid, "Remainder child failed: #{label}" unless status.success?
    verify
  end

  def self.fixture(window, label, role, mode, kind, selection)
    target = File.join(STAGE, "docs/reviews/assets", File.basename(window), label)
    execute(window, label, role, [File.join(STAGE, B::SCRIPTS, "release_perf_fixture.rb"), kind,
      "--transport", "offline", "--mode", mode, "--fixtures", selection, "--sdk-root", "/qa202-sdk", "--cucumber", "12.0.1",
      "--gem-path", "/bundle/ruby/3.4.0", "--jpeg", File.join(OUT, "jpeg.jpg"), "--output", target])
    Dir.glob(File.join(target, "**/process.json")).each do |p|
      j = B.read(p)
      raise B::Invalid, "Remainder source guard/child failed" unless j.dig("source_guard", "passed") && !j["timed_out"] && j["signal"].nil?
    end
    audits = Dir.glob(File.join(target, "**/release-mode-proof.json"))
    raise B::Invalid, "Mode audit absent/failed" if audits.empty? || audits.any? { |p| B.read(p)["passed"] != true }
    target
  end

  def self.run(receipt_path)
    receipt = B.read(receipt_path)
    ReleasePerf202.gate!(receipt)
    raise "Explicit remainder-only and signal authorization required" unless receipt["run_scope"] == "remaining_only" && receipt["completion_signal_approved"] == true && receipt["host_load_role"] == "diagnostic_only"
    verify
    deadline = Time.parse(receipt.fetch("execution_deadline_utc"))
    restore = Time.parse(receipt.fetch("watchdog_restore_utc"))
    raise "Invalid future deadline" unless deadline > Time.now.utc && restore - deadline >= 30
    signal_path = receipt.fetch("completion_signal_path")
    raise "Only the authorized v6 signal is allowed" unless signal_path == "/private/tmp/rp-release-20261102/performance-pause-v6-done"
    raise "Master must clear previous completion signal before a new pause" if File.exist?(signal_path)
    window = File.join(OUT, receipt.fetch("quiet_window_id"))
    raise "Never overwrite/retry a window" if File.exist?(window)
    B.write(File.join(window, "authorization.json"), receipt)
    B.write(File.join(window, "harness-binding.json"), readiness_sha256: Digest::SHA256.file(READY).hexdigest,
      entry_sha256: Digest::SHA256.file(__FILE__).hexdigest, package_manifest_sha256: Digest::SHA256.file(File.join(OUT, "harness-manifest-v6.json")).hexdigest)
    result = { "status" => "NOT RUN", "frozen21" => { "status" => "PASS_RETAINED_V5", "window" => File.basename(PRIOR) },
      "F07" => "NOT RUN", "all_presentation" => "NOT RUN", "supplement" => "NOT RUN",
      "execution_deadline_utc" => deadline.iso8601, "watchdog_restore_utc" => restore.iso8601 }
    begin
      timer = Thread.new do
        sleep [deadline - Time.now.utc, 0].max
        Open3.capture3("docker", "kill", "ledger-qa202-final-performance")
        Thread.main.raise(B::Invalid, "Execution deadline reached; incomplete, no reduced samples or retry")
      end
      B.instance_variable_set(:@isolated_window, true)
      B.instance_variable_set(:@paused_identity, nil)
      bytes = File.binread(receipt.fetch("pause_receipt_path"))
      File.open(File.join(window, "pause-receipt-before.ndjson"), File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(bytes) }
      raise B::Invalid, "Dependencies changed" unless B.dependencies == B.read(File.join(OUT, "dependencies.json"))
      settling = []
      18.times do |i|
        settling << B.load_sample
        break if B.quiet?(settling.last(3))
        sleep 10 unless i == 17
      end
      B.write(File.join(window, "settling.json"), samples: settling, conditions: B::QUIET_CONDITIONS)
      raise B::Invalid, "Original quiet gate not settled" unless B.quiet?(settling.last(3))
      recent = settling.last(3)
      B.write(File.join(window, "start.json"), utc: Time.now.utc.iso8601, run_scope: "remaining_only", frozen21_rerun: false)
      wall = Hash.new { |h, k| h[k] = [] }
      3.times do |repeat|
        [["baseline", "plain"], ["candidate", "plain"], ["candidate", "rich"]].rotate(repeat).each do |role, mode|
          label = "wall-#{repeat + 1}-#{role}-#{mode}"
          B.observe!(window, "#{label}-before", recent)
          target = fixture(window, label, role, mode, "wall", "F07")
          native = B.read(File.join(target, "F07/result.json"))
          raise B::Invalid, "F07 did not pass all 50 steps" unless native["exit"] == 0 && native.dig("native_steps", "passed") == 50
          wall["#{role}-#{mode}"] << B.read(File.join(target, "F07/process.json")).fetch("seconds")
          B.observe!(window, "#{label}-after", recent)
        end
      end
      wall = wall.transform_values { |v| { "raw_seconds" => v, "median_seconds" => v.sort[1] } }
      pass = wall.values.all? { |r| r.fetch("median_seconds") <= wall.fetch("baseline-plain").fetch("median_seconds") * 1.10 }
      result["F07"] = { "status" => pass ? "PASS" : "FAIL", "results" => wall }
      B.write(File.join(window, "wall-comparison.json"), result["F07"])
      raise B::Regression, "F07 median > +10%" unless pass
      all = {}
      %w[plain rich].each do |mode|
        pooled = Hash.new { |h, k| h[k] = [] }
        ids = (1..18).reject { |n| n == 6 }.map { |n| format("F%02d", n) }.join(",")
        [["micro", ids], ["parallel-micro", "F06"]].each do |kind, selection|
          label = "#{kind}-#{mode}"
          B.observe!(window, "#{label}-before", recent)
          target = fixture(window, label, "candidate", mode, kind, selection)
          paths = Dir.glob(File.join(target, "**/presentation-timings.json"))
          raise B::Invalid, "Timed replay absent" if paths.empty?
          paths.each do |path|
            data = B.read(path)
            raise B::Invalid, "Presentation replay error" unless data.fetch("replay_errors").empty?
            data.fetch("samples").each { |key, values| pooled[key].concat(values) }
          end
          B.observe!(window, "#{label}-after", recent)
        end
        raise B::Invalid, "FailureCard weight changed" unless pooled.fetch("FailureCard.format").length == 1050
        summary = pooled.transform_values { |v| { "count" => v.length, "p95_ms" => ReleasePerf202.p95(v) } }
        B.write(File.join(window, "all-presentation-#{mode}.json"), summary)
        unless summary.values.all? { |r| r.fetch("p95_ms") < 2 }
          result["all_presentation"] = { "status" => "FAIL", "mode" => mode, "summary" => summary }
          raise B::Regression, "Presentation entry-point p95 >=2ms"
        end
        all[mode] = summary
      end
      result["all_presentation"] = { "status" => "PASS", "modes" => all }
      supplements = {}
      %w[plain rich].each do |mode|
        supplements[mode] = {}
        %w[baseline candidate].each do |role|
          label = "supplement-#{role}-#{mode}"
          B.observe!(window, "#{label}-before", recent)
          output = File.join(window, "#{label}.json")
          sha = role == "baseline" ? ReleasePerf202::BASELINE : ReleasePerf202::FINAL
          execute(window, label, role, [File.join(STAGE, B::SCRIPTS, "release_perf_child.rb"), "supplement", role, mode, sha,
            File.join(STAGE, B::CORPUS_PATH), output, File.join(window, "authorization.json"), File.join(OUT, "environment.json")])
          B.observe!(window, "#{label}-after", recent)
          supplements[mode][role] = ReleasePerf202.diagnostic_cost(B.read(output))
        end
      end
      result["supplement"] = { "status" => "DIAGNOSTIC_MEASURED", "absolute_cost" => supplements, "blocking_speed_threshold" => nil }
      B.write(File.join(window, "supplement-absolute-cost.json"), supplements)
      verify
      raise B::Invalid, "Dependencies changed after measurements" unless B.dependencies == B.read(File.join(OUT, "dependencies.json"))
      result["status"] = "PASS"
    rescue B::Regression => error
      result["status"], result["reason"] = "FAIL", error.message
    rescue StandardError => error
      result["status"], result["reason"] = "NOT RUN", "#{error.class}: #{error.message}"
    ensure
      timer.kill if timer
      result["actual_execution_end_utc"] = Time.now.utc.iso8601
      B.write(File.join(window, "result.json"), result)
      File.open(signal_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(JSON.generate(utc: Time.now.utc.iso8601, event: "performance_window_ended_restore_now", result: result["status"]) + "\n") }
      puts "RESTORE RP/TYPEWORDS NOW: completion signal written; no further measurements"
      puts JSON.generate(result)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  case ARGV.shift
  when "prepare" then ReleasePerfRemainder202.prepare
  when "run" then ReleasePerfRemainder202.run(ARGV.fetch(0))
  else abort "Use prepare, or run NEW_MASTER_RECEIPT.json after a new explicit paused-window grant"
  end
end
