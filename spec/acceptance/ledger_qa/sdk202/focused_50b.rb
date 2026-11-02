# frozen_string_literal: true

require_relative "host"
require_relative "benchmark"
require "time"

module Ledger202Focused50b
  FINAL = "50b6d4d1d3b6c61926a023fc96bf291878ab68b0"
  PREVIOUS = "090b633842f5b24d46a244f854daf95c9477b9ca"
  ROOT = Ledger202Host::ROOT
  OUTPUT = File.join(ROOT, "docs/reviews/assets/QA202-50b6d4d-20261102")
  WINDOW = File.join(OUTPUT, "focused-window-2")
  SOURCE = "/private/tmp/ledger-qa202-50b6d4d/candidate"
  PATHS = %w[lib examples reportportal-cucumber-ruby.gemspec Gemfile Gemfile.lock].freeze
  CHANGED = "lib/reportportal_cucumber/automation/failure_redactor.rb"

  def self.write(name, value) = Ledger202Host.write_new(File.join(WINDOW, name), value)
  def self.read(path) = JSON.parse(File.read(path))
  def self.git(*args) = Ledger202Host.read_command("git", "-C", ROOT, *args)

  def self.source(role)
    role == "baseline" ? File.join(Ledger202Host::SOURCE, "baseline") : SOURCE
  end

  def self.container(role)
    ["docker", "run", "--rm", "--name", "ledger-qa202-50b-focused", "--network", "none", "--cpus", "1", "--memory", "2g",
      "-v", "#{ROOT}:#{ROOT}", "-v", "#{source(role)}:/qa202-sdk:ro", "-v", "#{Ledger202Host::VOLUME}:/bundle:ro", "-w", ROOT,
      "-e", "GEM_HOME=/bundle/ruby/3.4.0", "-e", "GEM_PATH=/bundle/ruby/3.4.0", "-e", "LEDGER_SDK_ROOT=/qa202-sdk",
      "-e", "LEDGER_CUCUMBER=12.0.1", Ledger202Host::IMAGE, "ruby"]
  end

  def self.verify(role)
    return Ledger202Host.verify_source(role) if role == "baseline"
    read(File.join(WINDOW, "source-proof.json")).fetch("files").each do |entry|
      raise "Candidate snapshot changed" unless Digest::SHA256.file(File.join(SOURCE, entry["path"])).hexdigest == entry["sha256"]
    end
  end

  def self.load_sample
    out = Ledger202Host.read_command("docker", "stats", "--no-stream", "--format", "{{.Name}} {{.CPUPerc}} {{.MemUsage}}")
    rows = out.lines.map { |line| name, cpu, *memory = line.split; { name: name, cpu_percent: Float(cpu.delete_suffix("%")), memory: memory.join(" ") } }
    { utc: Time.now.utc.iso8601, containers: rows, total_cpu_percent: rows.sum { |r| r[:cpu_percent] } }
  end

  def self.prepare
    raise "Never overwrite preparation" if File.exist?(OUTPUT) || File.exist?(SOURCE)
    changed = git("diff", "--name-only", PREVIOUS, FINAL).lines.map(&:chomp)
    allowed = ["CHANGELOG.md", CHANGED, "spec/reportportal_cucumber/automation/failure_redactor_reuse_spec.rb"]
    raise "Unexpected committed scope" unless changed.sort == allowed.sort
    raise "Runtime scope widened" unless git("diff", "--name-only", PREVIOUS, FINAL, "--", *PATHS).lines.map(&:chomp) == [CHANGED]
    FileUtils.mkdir_p(SOURCE)
    archive, _, status = Open3.capture3("git", "-C", ROOT, "archive", FINAL, *PATHS)
    raise "Archive failed" unless status.success?
    _, _, status = Open3.capture3("tar", "-xf", "-", "-C", SOURCE, stdin_data: archive)
    raise "Export failed" unless status.success?
    old = git("ls-tree", "-r", PREVIOUS, "--", *PATHS).lines.to_h { |line| info, path = line.chomp.split("\t", 2); [path, info.split.last] }
    members = git("ls-tree", "-r", FINAL, "--", *PATHS).lines.map do |line|
      info, path = line.chomp.split("\t", 2)
      blob = info.split.last
      bytes = File.binread(File.join(SOURCE, path))
      raise "Export byte mismatch" unless Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0".b + bytes) == blob
      { path: path, git_blob: blob, previous_blob: old.fetch(path), sha256: Digest::SHA256.hexdigest(bytes), unchanged: blob == old[path] }
    end
    write("source-proof.json", candidate: FINAL, behavior_reference: PREVIOUS, source_directory: SOURCE, files: members,
      changed_paths: changed, runtime_diff: git("diff", PREVIOUS, FINAL, "--", CHANGED), prior_runtime_launch_ids: [3847, 3848, 3849, 3850, 3851, 3852], current_runtime_launch_ids: [])
    archive_dir = File.join(WINDOW, "harness")
    FileUtils.mkdir_p(archive_dir)
    harness = %w[benchmark.rb benchmark_child.rb focused_50b.rb].map do |name|
      target = File.join(archive_dir, name)
      FileUtils.cp(File.join(__dir__, name), target)
      { name: name, sha256: Digest::SHA256.file(target).hexdigest }
    end
    original_harness = File.join(Ledger202Host::OUTPUT, "offline-review/window1-harness")
    %w[benchmark.rb benchmark_child.rb].each do |name|
      raise "Measurement helper differs from window 1" unless File.binread(File.join(__dir__, name)) == File.binread(File.join(original_harness, name))
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
      sample = load_sample
      samples << sample
      puts JSON.generate(settling: sample)
      $stdout.flush
      recent = samples.last(3)
      allowed = recent.all? { |s| s[:containers].all? { |r| %w[rp2607-control-plane typewords-local-typewords-1].include?(r[:name]) } }
      stable = allowed && recent.length == 3 && recent.all? { |s| s[:total_cpu_percent] <= 35 } && recent.map { |s| s[:total_cpu_percent] }.minmax.then { |a, b| b - a <= 15 }
      break if stable
      sleep 10 unless samples.length == 18
    end
    write("settling.json", samples: samples, stable: stable, maximum_percent: 35, consecutive: 3, maximum_spread: 15)
    raise "Load did not settle; no timing started" unless stable
    write("ready.json", utc: Time.now.utc.iso8601, candidate: FINAL, timings_started: false)
    puts "READY_FOR_FOCUSED_TIMING=#{FINAL}"
  end

  def self.measure
    raise "Never rerun a timing window" if File.exist?(File.join(WINDOW, "start.json"))
    ready = read(File.join(WINDOW, "ready.json"))
    raise "Settling receipt expired" unless Time.now.utc - Time.parse(ready.fetch("utc")) < 90
    deps = read(File.join(WINDOW, "dependency-recheck.json"))
    env = read(File.join(Ledger202Host::OUTPUT, "environment.json"))
    corpus_path = File.join(ROOT, "docs/reviews/assets/ledger-2.0.2-preparation/failure-corpus.json")
    corpus = read(corpus_path)
    started = Time.now.utc
    write("start.json", utc: started.iso8601, candidate: FINAL, scope: "FOCUSED_MATCHED_PLAIN_RICH_ONLY", no_live_activity: true,
      authorization: "Master explicitly authorized focused retiming at committed 50b; security blocker remains deferred")
    puts "TIMING_START_UTC=#{started.iso8601}"
    $stdout.flush
    results = []
    %w[plain rich].each do |mode|
      %w[baseline candidate].each do |role|
        verify(role)
        receipt = { master_final_handoff: true, final_sha: FINAL,
          launch_ids: [3847, 3848, 3849, 3850, 3851, 3852], launch_id_scope: "PRIOR_RUNTIME_REFERENCES_ONLY_NOT_EXECUTED_AT_50b", current_runtime_launch_ids: [],
          master_quiet_window_approved: true, quiet_window_id: "50b-focused-window-2", no_other_heavy_jobs: true,
          source_bytes_verified: true, source_sha: role == "baseline" ? Ledger202Host::BASE : FINAL, corpus_sha256: corpus["corpus_sha256"],
          environment: { image_id: Ledger202Host::IMAGE, ruby: deps["ruby"], cucumber: "12.0.1", architecture: env["architecture"],
            dependency_sha256: deps["manifest_sha256"], cpu_limit: "1", memory_limit: "2g" } }
        name = "matched-#{role}-#{mode}"
        write("#{name}-receipt.json", receipt)
        argv = container(role) + [File.join(__dir__, "benchmark_child.rb"), File.join(WINDOW, "#{name}-receipt.json"), corpus_path,
          File.join(WINDOW, "#{name}.json"), role, mode]
        out, err, status = Open3.capture3(*argv)
        write("#{name}-process.json", argv: argv, exit: status.exitstatus, stdout: out, stderr: err)
        puts out
        $stdout.flush
        raise "Incomplete measurement: #{name}" unless status.success?
        verify(role)
      end
      before, after = %w[baseline candidate].map { |role| read(File.join(WINDOW, "matched-#{role}-#{mode}.json")) }
      raise "Activation mismatch" unless before.fetch("activation").fetch("gems") == after.fetch("activation").fetch("gems")
      comparison = Ledger202Benchmark.compare(before, after).map { |row| row.merge(mode: mode, ratio: row[:new_p95_ms] / row[:old_p95_ms]) }
      write("matched-#{mode}-comparison.json", comparison)
      results.concat(comparison)
      puts JSON.generate(mode: mode, comparison: comparison)
      $stdout.flush
      raise "STOP: matched p95 exceeds +10%" if comparison.any? { |r| r[:stop_more_than_10_percent] }
      raise "STOP: renderer p95 not below 2ms" if comparison.any? { |r| r[:presentation_under_2_ms] == false }
    end
    write("result.json", status: "FOCUSED_GATE_PASS_NOT_FULL_G11", comparisons: results,
      F07: "NOT_RUN", all_presentation: "NOT_RUN", G8: "BLOCKED", release: "NOT_ACCEPTED", new_launches: [])
    puts "FOCUSED_GATE_PASS; G8_BLOCKED; RELEASE_NOT_ACCEPTED"
  rescue StandardError => error
    write("stop.json", status: "STOP_OR_INCOMPLETE", reason: error.message, utc: Time.now.utc.iso8601)
    puts "TIMING_STOP=#{error.message}"
  ensure
    if started
      ended = Time.now.utc
      write("end.json", utc: ended.iso8601, started_utc: started.iso8601, elapsed_seconds: ended - started)
      puts "TIMING_END_UTC=#{ended.iso8601}; ELAPSED_SECONDS=#{ended - started}"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  action, authorization = ARGV
  abort "Use prepare|measure --master-quiet-approved" unless %w[prepare measure].include?(action) && authorization == "--master-quiet-approved"
  Ledger202Focused50b.public_send(action)
end
