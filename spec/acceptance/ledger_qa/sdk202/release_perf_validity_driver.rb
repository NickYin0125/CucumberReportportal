# frozen_string_literal: true

require_relative "release_perf_driver"

module ReleasePerfValidity202
  BASE = ReleasePerfDriver202
  OUT = BASE::OUT
  STAGE = File.join(OUT, "harness-root-v6")
  SCRIPTS = BASE::SCRIPTS
  FEATURES = %w[features/presentation_ledger/f13_numeric.feature features/presentation_ledger/f14_escaping.feature].freeze

  def self.prepare
    raise "Never overwrite v6 preparation" if File.exist?(STAGE)
    BASE.verify!
    original = BASE.read(File.join(OUT, "harness-manifest-v5.json"))
    files = original.map { |r| r.fetch("path") } + FEATURES +
      Dir.glob(File.join(__dir__, "release_perf_*.rb")).map { |p| p.delete_prefix(BASE::QA + "/") }
    manifest = files.uniq.sort.map do |path|
      previous = original.find { |r| r.fetch("path") == path }
      source = previous ? File.join(BASE::STAGE, path) : File.join(BASE::QA, path)
      target = File.join(STAGE, path)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(source, target)
      { path: path, sha256: Digest::SHA256.file(target).hexdigest }
    end
    BASE.write(File.join(OUT, "harness-manifest-v6.json"), manifest)
    FEATURES.each do |path|
      raise "Fixture copy changed bytes" unless File.binread(File.join(STAGE, path)) == File.binread(File.join(BASE::QA, path))
    end
    # This is source/catalog validation only, without SDK activation or timing.
    require File.join(STAGE, "script/acceptance/presentation_ledger_developer/fixtures.rb")
    catalog = LedgerDeveloper.catalog
    f07 = catalog.find { |row| row[:id] == "F07" }
    raise "F07 workload changed" unless f07.fetch(:source).scan(/^    Given ledger rapid record /).length == 50
    BASE.write(File.join(OUT, "v6-catalog-preflight.json"), status: "PASS_UNTIMED", catalog_ids: catalog.map { |r| r[:id] },
      F07_steps: 50, fixtures: FEATURES, timing_samples_collected: 0, SDK_loaded: false,
      scope: "QA packaging only; v5 raw samples, source, and result unchanged",
      future_time_fields: { execution_deadline_utc: "Deadline, not actual stop", actual_execution_end_utc: "Observed end/STOP timestamp" })
    puts "V6 catalog preparation PASS_UNTIMED; missing fixture files copied unchanged; no benchmark run"
  end

  def self.verify
    BASE.verify!
    BASE.read(File.join(OUT, "harness-manifest-v6.json")).each do |row|
      raise "V6 harness drift" unless Digest::SHA256.file(File.join(STAGE, row.fetch("path"))).hexdigest == row.fetch("sha256")
    end
  end

  def self.run(label, role, mode, kind, fixtures)
    raise "Bad untimed validity selection" unless label.match?(/\A[a-zA-Z0-9_-]+\z/) && %w[baseline candidate].include?(role) &&
      %w[plain rich].include?(mode) && %w[wall micro parallel-micro].include?(kind)
    verify
    target = File.join(STAGE, "docs/reviews/assets/v6-untimed-validity", label)
    raise "Never overwrite validity execution" if File.exist?(target) || File.exist?(File.join(OUT, "v6-#{label}-process.json"))
    args = BASE.container(role).map { |entry| entry == BASE::STAGE ? STAGE : entry } +
      [File.join(STAGE, SCRIPTS, "release_perf_validity_fixture.rb"), kind, "--transport", "offline", "--mode", mode,
       "--fixtures", fixtures, "--sdk-root", "/qa202-sdk", "--cucumber", "12.0.1", "--gem-path", "/bundle/ruby/3.4.0",
       "--jpeg", File.join(OUT, "jpeg.jpg"), "--output", target]
    stdout, stderr, status = Open3.capture3(*args)
    BASE.write(File.join(OUT, "v6-#{label}-process.json"), argv: args, exit: status.exitstatus, stdout: stdout, stderr: stderr,
      timing_collection: "DISABLED", performance_acceptance: "NOT_ASSESSED")
    raise "Untimed fixture driver failed: #{label}" unless status.success?
    processes = Dir.glob(File.join(target, "**/process.json")) + [File.join(target, "probe.json")]
    raise "No subprocess proof" if processes.empty?
    processes.each do |path|
      process = BASE.read(path)
      raise "Harness timing accidentally enabled" unless process["timing_collection"] == "DISABLED_UNTIMED_VALIDITY" && process["seconds"].nil?
      raise "Subprocess timeout/signal" if process["timed_out"] || process["signal"]
      next if File.basename(path) == "probe.json"
      raise "Source guard failed" unless process.dig("source_guard", "passed") == true
    end
    modes = Dir.glob(File.join(target, "**/release-mode-proof.json"))
    raise "Mode proof absent/failed" if modes.empty? || modes.any? { |p| BASE.read(p)["passed"] != true }
    replay = Dir.glob(File.join(target, "**/presentation-validity.json"))
    if kind != "wall"
      raise "Untimed replay absent" if replay.empty?
      replay.each do |path|
        data = BASE.read(path)
        raise "Replay failed or timing present" unless data.fetch("replay_errors").empty? && data["timing_samples_collected"] == 0
      end
    else
      result = BASE.read(File.join(target, "F07/result.json"))
      raise "F07 did not execute its 50 passed steps" unless result["exit"] == 0 && result.dig("native_steps", "passed") == 50
    end
    raise "Timing artifact unexpectedly produced" unless Dir.glob(File.join(target, "**/presentation-timings.json")).empty?
    verify
    BASE.write(File.join(OUT, "v6-#{label}-validity.json"), status: "PASS_UNTIMED", role: role, mode: mode, kind: kind,
      evidence: target, timing_samples_collected: 0, performance_acceptance: "NOT_ASSESSED", mode_proofs: modes.length,
      subprocess_proofs: processes.length, replay_proofs: replay.length)
    puts "PASS_UNTIMED #{label}"
  end
end

if $PROGRAM_NAME == __FILE__
  case ARGV.shift
  when "prepare" then ReleasePerfValidity202.prepare
  when "run" then ReleasePerfValidity202.run(*ARGV)
  else abort "Use prepare, or run LABEL ROLE MODE KIND FIXTURES; timings are always disabled"
  end
end
