# frozen_string_literal: true

# Window 3: matched baseline/50b and baseline/candidate timings for the malformed-URL
# redaction candidate. Reuses window-1 measurement helpers byte-for-byte, the frozen
# corpus, image, dependency volume, container limits and window-2 load thresholds.
# Writes only new files; one bounded preflight, no automatic retry.

require_relative "host"
require_relative "benchmark"
require "time"

module Ledger202Window3
  BASE = Ledger202Host::BASE
  PREVIOUS = "50b6d4d1d3b6c61926a023fc96bf291878ab68b0"
  ROOT = Ledger202Host::ROOT
  PATHS = %w[lib examples reportportal-cucumber-ruby.gemspec Gemfile Gemfile.lock].freeze
  PREVIOUS_SOURCE = "/private/tmp/ledger-qa202-50b6d4d/candidate"
  PREVIOUS_PROOF = File.join(ROOT, "docs/reviews/assets/QA202-50b6d4d-20261102/focused-window-2/source-proof.json")
  CORPUS = File.join(ROOT, "docs/reviews/assets/ledger-2.0.2-preparation/failure-corpus.json")
  WINDOW1_HARNESS = File.join(Ledger202Host::OUTPUT, "offline-review/window1-harness")
  ALLOWED_CONTAINERS = %w[rp2607-control-plane typewords-local-typewords-1].freeze

  module_function

  def candidate = ENV.fetch("WINDOW3_CANDIDATE").tap { |sha| raise "Full candidate SHA required" unless sha.match?(/\A[0-9a-f]{40}\z/) }
  def output = File.join(ROOT, "docs/reviews/assets/QA202-#{candidate[0, 7]}-20261102/focused-window-3")
  def candidate_source = "/private/tmp/ledger-qa202-#{candidate[0, 7]}/candidate"
  def write(name, value) = Ledger202Host.write_new(File.join(output, name), value)
  def read(path) = JSON.parse(File.read(path))
  def git(*args) = Ledger202Host.read_command("git", "-C", ROOT, *args)

  def source(arm)
    { "baseline" => File.join(Ledger202Host::SOURCE, "baseline"), "previous" => PREVIOUS_SOURCE, "candidate" => candidate_source }.fetch(arm)
  end

  def arm_sha(arm) = { "baseline" => BASE, "previous" => PREVIOUS, "candidate" => candidate }.fetch(arm)

  def container(arm)
    ["docker", "run", "--rm", "--name", "ledger-qa202-window3", "--network", "none", "--cpus", "1", "--memory", "2g",
      "-v", "#{ROOT}:#{ROOT}", "-v", "#{source(arm)}:/qa202-sdk:ro", "-v", "#{Ledger202Host::VOLUME}:/bundle:ro", "-w", ROOT,
      "-e", "GEM_HOME=/bundle/ruby/3.4.0", "-e", "GEM_PATH=/bundle/ruby/3.4.0", "-e", "LEDGER_SDK_ROOT=/qa202-sdk",
      "-e", "LEDGER_CUCUMBER=12.0.1", Ledger202Host::IMAGE, "ruby"]
  end

  def tree(sha)
    git("ls-tree", "-r", sha, "--", *PATHS).lines.map do |line|
      info, path = line.chomp.split("\t", 2)
      [path, info.split.last]
    end
  end

  def verify(arm)
    return Ledger202Host.verify_source("baseline") if arm == "baseline"

    if arm == "previous"
      read(PREVIOUS_PROOF).fetch("files").each do |entry|
        raise "50b snapshot changed" unless Digest::SHA256.file(File.join(PREVIOUS_SOURCE, entry["path"])).hexdigest == entry["sha256"]
      end
    else
      tree(candidate).each do |path, blob|
        bytes = File.binread(File.join(candidate_source, path))
        raise "Candidate snapshot changed" unless Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0".b + bytes) == blob
      end
    end
  end

  def host_load
    { loadavg: Ledger202Host.read_command("sysctl", "-n", "vm.loadavg"), ncpu: Ledger202Host.read_command("sysctl", "-n", "hw.ncpu") }
  end

  def load_sample
    out = Ledger202Host.read_command("docker", "stats", "--no-stream", "--format", "{{.Name}} {{.CPUPerc}} {{.MemUsage}}")
    rows = out.lines.map { |line| name, cpu, *memory = line.split; { name: name, cpu_percent: Float(cpu.delete_suffix("%")), memory: memory.join(" ") } }
    { utc: Time.now.utc.iso8601, containers: rows, total_cpu_percent: rows.sum { |r| r[:cpu_percent] }, host: host_load }
  end

  def prepare
    raise "Never overwrite preparation" if File.exist?(output) || File.exist?(candidate_source)
    %w[benchmark.rb benchmark_child.rb].each do |name|
      raise "Measurement helper differs from window 1" unless File.binread(File.join(__dir__, name)) == File.binread(File.join(WINDOW1_HARNESS, name))
    end
    raise "Candidate does not descend from 50b" unless system("git", "-C", ROOT, "merge-base", "--is-ancestor", PREVIOUS, candidate)
    FileUtils.mkdir_p(candidate_source)
    archive, _, status = Open3.capture3("git", "-C", ROOT, "archive", candidate, *PATHS)
    raise "Archive failed" unless status.success?
    _, _, status = Open3.capture3("tar", "-xf", "-", "-C", candidate_source, stdin_data: archive)
    raise "Export failed" unless status.success?
    verify("candidate")
    previous = tree(PREVIOUS).to_h
    write("source-proof.json", candidate: candidate, previous: PREVIOUS, baseline: BASE, candidate_source: candidate_source,
      files: tree(candidate).map { |path, blob| { path: path, git_blob: blob, previous_blob: previous[path], unchanged_from_50b: blob == previous[path] } },
      runtime_paths_changed_from_50b: git("diff", "--name-only", PREVIOUS, candidate, "--", *PATHS).lines.map(&:chomp),
      baseline_proof: Ledger202Host.verify_source("baseline").slice(:source_sha, :manifest_sha256))
    archive_dir = File.join(output, "harness")
    FileUtils.mkdir_p(archive_dir)
    harness = %w[benchmark.rb benchmark_child.rb focused_window3.rb].map do |name|
      FileUtils.cp(File.join(__dir__, name), File.join(archive_dir, name))
      { name: name, sha256: Digest::SHA256.file(File.join(archive_dir, name)).hexdigest }
    end
    write("harness-proof.json", files: harness, measurement_helpers_unchanged_from_window_1: true)
    env = read(File.join(Ledger202Host::OUTPUT, "environment.json"))
    code = 'require "json";require "digest";m=Dir.glob("/bundle/**/*",File::FNM_DOTMATCH).sort.filter_map{|p|next if File.directory?(p);[p.delete_prefix("/bundle/"),Digest::SHA256.file(p).hexdigest]};puts JSON.generate(files:m.length,manifest_sha256:Digest::SHA256.hexdigest(JSON.generate(m)),ruby:RUBY_DESCRIPTION)'
    out, err, status = Open3.capture3(*(container("baseline") + ["-e", code]))
    raise "Dependency recheck failed" unless status.success?
    deps = JSON.parse(out)
    raise "Dependency bytes differ from first window" unless deps == env.fetch("dependencies")
    write("dependency-recheck.json", deps.merge("stderr" => err))
    samples = []
    stable = false
    18.times do
      samples << load_sample
      puts JSON.generate(settling: samples.last)
      $stdout.flush
      recent = samples.last(3)
      allowed = recent.all? { |s| s[:containers].all? { |r| ALLOWED_CONTAINERS.include?(r[:name]) } }
      # Window-2 container criteria unchanged; the host-load bound is an added, stricter criterion.
      host_quiet = recent.all? { |s| Float(s[:host][:loadavg].delete("{}").split.first) <= Integer(s[:host][:ncpu]) }
      stable = allowed && host_quiet && recent.length == 3 && recent.all? { |s| s[:total_cpu_percent] <= 35 } &&
               recent.map { |s| s[:total_cpu_percent] }.minmax.then { |a, b| b - a <= 15 }
      break if stable
      sleep 10 unless samples.length == 18
    end
    write("settling.json", samples: samples, stable: stable, maximum_percent: 35, consecutive: 3, maximum_spread: 15,
      added_host_criterion: "1-minute loadavg <= hw.ncpu for the same three samples")
    unless stable
      write("end.json", status: "PREPARATION_BLOCKED", phase: "LOAD_PREFLIGHT", load_samples: samples.length,
        observed_peak_cpu_percent: samples.map { |s| s[:total_cpu_percent] }.max, timing_started: false,
        benchmark_samples_collected: 0, plain_result: "NOT_RUN", rich_result: "NOT_RUN", next_execution: "No automatic retry")
      raise "Load did not settle; no timing started"
    end
    write("ready.json", utc: Time.now.utc.iso8601, candidate: candidate, timings_started: false)
    puts "READY_FOR_WINDOW3_TIMING=#{candidate}"
  end

  def measure
    raise "Never rerun a timing window" if File.exist?(File.join(output, "start.json"))
    ready = read(File.join(output, "ready.json"))
    raise "Settling receipt expired" unless Time.now.utc - Time.parse(ready.fetch("utc")) < 90
    deps = read(File.join(output, "dependency-recheck.json"))
    env = read(File.join(Ledger202Host::OUTPUT, "environment.json"))
    corpus = read(CORPUS)
    started = Time.now.utc
    write("start.json", utc: started.iso8601, candidate: candidate, previous: PREVIOUS, host: host_load,
      scope: "MATCHED_PLAIN_RICH_BASELINE_VS_50B_AND_CANDIDATE", no_live_activity: true)
    results = []
    %w[plain rich].each do |mode|
      %w[previous candidate].each do |arm|
        pair = {}
        ["baseline", arm].each do |role_arm|
          role = role_arm == "baseline" ? "baseline" : "candidate"
          verify(role_arm)
          receipt = { master_final_handoff: true, final_sha: arm_sha(arm),
            launch_ids: [3847, 3848, 3849, 3850, 3851, 3852], launch_id_scope: "PRIOR_RUNTIME_REFERENCES_ONLY_NOT_EXECUTED_AT_THIS_SHA",
            current_runtime_launch_ids: [], master_quiet_window_approved: true, quiet_window_id: "window-3-#{candidate[0, 7]}",
            no_other_heavy_jobs: true, source_bytes_verified: true, source_sha: arm_sha(role_arm), corpus_sha256: corpus["corpus_sha256"],
            environment: { image_id: Ledger202Host::IMAGE, ruby: deps["ruby"], cucumber: "12.0.1", architecture: env["architecture"],
              dependency_sha256: deps["manifest_sha256"], cpu_limit: "1", memory_limit: "2g" } }
          name = "matched-#{arm}-#{role}-#{mode}"
          write("#{name}-receipt.json", receipt)
          argv = container(role_arm) + [File.join(__dir__, "benchmark_child.rb"), File.join(output, "#{name}-receipt.json"), CORPUS,
            File.join(output, "#{name}.json"), role, mode]
          out, err, status = Open3.capture3(*argv)
          write("#{name}-process.json", argv: argv, exit: status.exitstatus, stdout: out, stderr: err, host_after: host_load)
          puts out
          $stdout.flush
          raise "Incomplete measurement: #{name}" unless status.success?
          verify(role_arm)
          pair[role] = read(File.join(output, "#{name}.json"))
        end
        raise "Activation mismatch" unless pair["baseline"].fetch("activation").fetch("gems") == pair["candidate"].fetch("activation").fetch("gems")
        comparison = Ledger202Benchmark.compare(pair["baseline"], pair["candidate"]).map do |row|
          row.merge(mode: mode, arm: arm, sha: arm_sha(arm), ratio: row[:new_p95_ms] / row[:old_p95_ms])
        end
        write("matched-#{arm}-#{mode}-comparison.json", comparison)
        results.concat(comparison)
        puts JSON.generate(mode: mode, arm: arm, comparison: comparison)
        $stdout.flush
      end
    end
    failed = results.select { |r| r[:stop_more_than_10_percent] || r[:presentation_under_2_ms] == false }
    write("result.json", status: failed.empty? ? "MATCHED_GATE_PASS_NOT_FULL_G11" : "MATCHED_GATE_FAIL", comparisons: results,
      failed: failed, G8: "NOT_DECIDED_HERE", release: "NOT_ACCEPTED", new_launches: [])
  rescue StandardError => error
    write("stop.json", status: "STOP_OR_INCOMPLETE", reason: error.message, utc: Time.now.utc.iso8601)
    puts "TIMING_STOP=#{error.message}"
  ensure
    if started
      ended = Time.now.utc
      write("end.json", utc: ended.iso8601, started_utc: started.iso8601, elapsed_seconds: ended - started, host: host_load)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  action = ARGV.first
  abort "Use prepare|measure with WINDOW3_CANDIDATE=<sha>" unless %w[prepare measure].include?(action)
  Ledger202Window3.public_send(action)
end
