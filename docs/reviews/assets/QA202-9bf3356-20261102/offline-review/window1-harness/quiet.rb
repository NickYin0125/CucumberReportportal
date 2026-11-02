# frozen_string_literal: true

require_relative "host"
require_relative "benchmark"
require "time"

module Ledger202Quiet
  FINAL = "090b633842f5b24d46a244f854daf95c9477b9ca"
  ROOT = Ledger202Host::ROOT
  OUTPUT = File.join(Ledger202Host::OUTPUT, "quiet-090b-window-1")
  SOURCES = { "baseline" => File.join(Ledger202Host::SOURCE, "baseline"),
    "candidate" => File.join(Ledger202Host::SOURCE, "final-090b6338") }.freeze

  def self.write(name, value) = Ledger202Host.write_new(File.join(OUTPUT, name), value)

  def self.load_sample
    output = Ledger202Host.read_command("docker", "stats", "--no-stream", "--format", "{{.Name}} {{.CPUPerc}} {{.MemUsage}}")
    rows = output.lines.map do |line|
      name, cpu, *memory = line.split
      { name: name, cpu_percent: Float(cpu.delete_suffix("%")), memory: memory.join(" ") }
    end
    { utc: Time.now.utc.iso8601, containers: rows, total_cpu_percent: rows.sum { |r| r[:cpu_percent] } }
  end

  def self.verify(role)
    if role == "baseline"
      Ledger202Host.verify_source(role)
    else
      binding = JSON.parse(File.read(File.join(Ledger202Host::OUTPUT, "final-090b-binding.json")))
      raise "Wrong final binding" unless binding["final_sha"] == FINAL
      binding.fetch("files").each do |entry|
        raise "Final snapshot drift" unless Digest::SHA256.file(File.join(SOURCES.fetch(role), entry["path"])).hexdigest == entry["sha256"]
      end
    end
  end

  def self.container(role)
    ["docker", "run", "--rm", "--name", "ledger-qa202-quiet", "--network", "none", "--cpus", "1", "--memory", "2g",
      "-v", "#{ROOT}:#{ROOT}", "-v", "#{SOURCES.fetch(role)}:/qa202-sdk:ro",
      "-v", "#{Ledger202Host::SOURCE}/jpeg.jpg:/qa202-jpeg.jpg:ro", "-v", "#{Ledger202Host::VOLUME}:/bundle:ro", "-w", ROOT,
      "-e", "GEM_HOME=/bundle/ruby/3.4.0", "-e", "GEM_PATH=/bundle/ruby/3.4.0", "-e", "LEDGER_SDK_ROOT=/qa202-sdk",
      "-e", "LEDGER_CUCUMBER=12.0.1", Ledger202Host::IMAGE, "ruby"]
  end

  def self.execute(label, role, tail)
    verify(role)
    argv = container(role) + tail
    output, errors, status = Open3.capture3(*argv)
    write("#{label}-process.json", argv: argv, exit: status.exitstatus, stdout: output, stderr: errors)
    puts output
    $stdout.flush
    raise "Execution failed: #{label}" unless status.success?
    verify(role)
  end

  def self.run
    raise "Explicit Master quiet-window authorization required" unless ARGV == ["--master-quiet-approved"]
    raise "Never overwrite a window" if File.exist?(OUTPUT)
    FileUtils.mkdir_p(OUTPUT)
    @started = nil
    samples = []
    18.times do
      sample = load_sample
      samples << sample
      puts JSON.generate(settling: sample)
      $stdout.flush
      recent = samples.last(3)
      allowed = recent.all? { |s| s[:containers].all? { |r| %w[rp2607-control-plane typewords-local-typewords-1].include?(r[:name]) } }
      stable = recent.length == 3 && recent.all? { |s| s[:total_cpu_percent] <= 35 } && recent.map { |s| s[:total_cpu_percent] }.minmax.then { |a, b| b - a <= 15 }
      break if allowed && stable
      raise "Background not stable after three minutes; no timing started" if samples.length == 18
      sleep 10
    end
    write("settling.json", samples: samples, limit_percent: 35, consecutive: 3, maximum_spread_percent: 15)
    dep_script = 'require "json"; require "digest"; m=Dir.glob("/bundle/**/*",File::FNM_DOTMATCH).sort.filter_map{|p| next if File.directory?(p);[p.delete_prefix("/bundle/"),Digest::SHA256.file(p).hexdigest]}; puts JSON.generate(files:m.length,manifest_sha256:Digest::SHA256.hexdigest(JSON.generate(m)),ruby:RUBY_DESCRIPTION)'
    dep_out, dep_err, dep_status = Open3.capture3(*(container("baseline") + ["-e", dep_script]))
    raise "Dependency proof failed" unless dep_status.success?
    deps = JSON.parse(dep_out)
    env = JSON.parse(File.read(File.join(Ledger202Host::OUTPUT, "environment.json")))
    raise "Dependency bytes changed" unless deps == env.fetch("dependencies")
    write("dependency-recheck.json", deps.merge("stderr" => dep_err))
    corpus_path = File.join(ROOT, "docs/reviews/assets/ledger-2.0.2-preparation/failure-corpus.json")
    corpus = JSON.parse(File.read(corpus_path))
    @started = Time.now.utc
    write("start.json", utc: @started.iso8601, final_sha: FINAL, authorization: "Master explicitly opened quiet G11 window after RP health restoration",
      network: "none", credentials_forwarded: false, no_other_heavy_jobs: true)
    puts "TIMING_START_UTC=#{@started.iso8601}"
    $stdout.flush
    comparisons = []
    %w[plain rich].each do |mode|
      %w[baseline candidate].each do |role|
        receipt = { master_final_handoff: true, final_sha: FINAL, launch_ids: [3847, 3848, 3849, 3850, 3851, 3852],
          master_quiet_window_approved: true, quiet_window_id: "090b-window-1", no_other_heavy_jobs: true,
          source_bytes_verified: true, source_sha: role == "baseline" ? Ledger202Host::BASE : FINAL, corpus_sha256: corpus["corpus_sha256"],
          environment: { image_id: Ledger202Host::IMAGE, ruby: deps["ruby"], cucumber: "12.0.1", architecture: env["architecture"],
            dependency_sha256: deps["manifest_sha256"], cpu_limit: "1", memory_limit: "2g" } }
        name = "matched-#{role}-#{mode}"
        write("#{name}-receipt.json", receipt)
        execute(name, role, [File.join(__dir__, "benchmark_child.rb"), File.join(OUTPUT, "#{name}-receipt.json"), corpus_path,
          File.join(OUTPUT, "#{name}.json"), role, mode])
      end
      before, after = %w[baseline candidate].map { |role| JSON.parse(File.read(File.join(OUTPUT, "matched-#{role}-#{mode}.json"))) }
      result = Ledger202Benchmark.compare(before, after)
      comparisons.concat(result.map { |r| r.merge(mode: mode) })
      write("matched-#{mode}-comparison.json", result)
      puts JSON.generate(mode: mode, comparisons: result)
      $stdout.flush
      raise "STOP: matched FailureCard regression exceeds +10%" if result.any? { |r| r[:stop_more_than_10_percent] }
      raise "STOP: FailureCard renderer p95 is not below 2ms" if result.any? { |r| r[:presentation_under_2_ms] == false }
    end
    wall = Hash.new { |h, k| h[k] = [] }
    3.times do |repeat|
      [%w[baseline plain], %w[candidate plain], %w[candidate rich]].rotate(repeat).each do |role, mode|
        label = "wall-#{repeat + 1}-#{role}-#{mode}"
        target = File.join(OUTPUT, label)
        execute(label, role, [File.join(ROOT, "spec/acceptance/ledger_qa/performance.rb"), "wall", "--transport", "offline", "--mode", mode,
          "--fixtures", "F07", "--sdk-root", "/qa202-sdk", "--cucumber", "12.0.1", "--gem-path", "/bundle/ruby/3.4.0",
          "--jpeg", "/qa202-jpeg.jpg", "--output", target])
        process = JSON.parse(File.read(File.join(target, "F07/process.json")))
        raise "Invalid F07 run" unless process["exit"] == 0 && process.dig("source_guard", "passed")
        wall["#{role}-#{mode}"] << process.fetch("seconds")
      end
    end
    wall_summary = wall.transform_values { |v| { samples_s: v, median_s: v.sort[1] } }
    old = wall_summary.fetch("baseline-plain")[:median_s]
    write("wall-comparison.json", results: wall_summary, baseline: "accepted SDK2.0.1 3f20313", pass: wall_summary.values.all? { |r| r[:median_s] <= old * 1.10 })
    raise "STOP: F07 wall median exceeds +10%" unless wall_summary.values.all? { |r| r[:median_s] <= old * 1.10 }
    fixtures = (1..18).reject { |n| n == 6 }.map { |n| format("F%02d", n) }.join(",")
    %w[plain rich].each do |mode|
      [["micro", fixtures], ["parallel-micro", "F06"]].each do |kind, selection|
        label = "#{kind}-#{mode}"
        execute(label, "candidate", [File.join(ROOT, "spec/acceptance/ledger_qa/performance.rb"), kind, "--transport", "offline", "--mode", mode,
          "--fixtures", selection, "--sdk-root", "/qa202-sdk", "--cucumber", "12.0.1", "--gem-path", "/bundle/ruby/3.4.0",
          "--jpeg", "/qa202-jpeg.jpg", "--output", File.join(OUTPUT, label)])
      end
    end
    pooled = Hash.new { |h, k| h[k] = [] }
    paths = Dir[File.join(OUTPUT, "{micro,parallel-micro}-*", "**", "presentation-timings.json")]
    paths.each do |path|
      data = JSON.parse(File.read(path))
      raise "Presentation replay incomplete" unless data.fetch("replay_errors").empty?
      data.fetch("samples").each { |name, values| pooled[name].concat(values) }
    end
    presentation = pooled.transform_values { |v| { count: v.length, p95_ms: Ledger202Benchmark.p95(v) } }
    write("presentation-summary.json", presentation)
    raise "STOP: Presentation p95 exceeds 2ms" unless !presentation.empty? && presentation.values.all? { |r| r[:p95_ms] < 2 }
    write("result.json", status: "PASS", matched: comparisons, wall: wall_summary, presentation: presentation)
  rescue StandardError => error
    write("stop.json", status: "STOP_OR_INCOMPLETE", reason: error.message, utc: Time.now.utc.iso8601)
    puts "TIMING_STOP=#{error.message}"
  ensure
    if @started
      ended = Time.now.utc
      write("end.json", utc: ended.iso8601, started_utc: @started.iso8601, elapsed_seconds: ended - @started)
      puts "TIMING_END_UTC=#{ended.iso8601}; ELAPSED_SECONDS=#{ended - @started}"
    end
  end
end

Ledger202Quiet.run if $PROGRAM_NAME == __FILE__
