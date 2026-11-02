# frozen_string_literal: true

require_relative "release_perf_benchmark"
require "open3"
require "fileutils"
require "time"

module ReleasePerfDriver202
  QA = File.expand_path("../../../..", __dir__)
  SDK = "/Users/nick/Documents/crr-2.0.2"
  OUT = File.join(QA, "docs/reviews/assets/QA202-final-release-20261102-performance")
  REVISION = "v3"
  STAGE = File.join(OUT, "harness-root-#{REVISION}")
  MANIFEST = File.join(OUT, "harness-manifest-#{REVISION}.json")
  SCRIPTS = "spec/acceptance/ledger_qa/sdk202"
  CORPUS_PATH = "docs/reviews/assets/ledger-2.0.2-preparation/failure-corpus.json"
  ALLOWED_CONTAINERS = %w[rp2607-control-plane typewords-local-typewords-1].freeze
  QUIET_CONDITIONS = {
    "original_container_criterion" => { "consecutive" => 3, "maximum_cpu_percent" => 35,
      "maximum_spread_percentage_points" => 15, "eligible_containers" => ALLOWED_CONTAINERS },
    "additional_host_preflight" => { "criterion" => "1-minute loadavg <= hw.ncpu",
      "origin" => "Later third-party focused_window3.rb preflight; not original G11/Decision25 or original container criterion",
      "retained_for_this_execution" => true, "acceptance_threshold" => false }
  }.freeze
  class Invalid < StandardError; end
  class Regression < StandardError; end

  def self.command(*argv)
    out, err, status = Open3.capture3(*argv)
    raise Invalid, "Command failed: #{argv.first}: #{err}" unless status.success?
    out
  end

  def self.write(path, data)
    FileUtils.mkdir_p(File.dirname(path))
    text = JSON.pretty_generate(data) + "\n"
    secret = ENV["RP_API_KEY"].to_s
    raise Invalid, "Credential in evidence" if !secret.empty? && text.include?(secret)
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(text) }
  end

  def self.read(path)
    JSON.parse(File.read(path))
  end

  def self.source_manifest(role)
    sha = role == "baseline" ? ReleasePerf202::BASELINE : ReleasePerf202::FINAL
    directory = File.join(OUT, "sources", role)
    entries = command("git", "-C", SDK, "ls-tree", "-r", sha, "--", "lib", "reportportal-cucumber-ruby.gemspec").lines.map do |line|
      info, path = line.chomp.split("\t", 2)
      blob = info.split.last
      bytes = File.binread(File.join(directory, path))
      raise Invalid, "Source differs from frozen Git blob: #{path}" unless
        Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0".b + bytes) == blob
      { "path" => path, "git_blob" => blob, "sha256" => Digest::SHA256.hexdigest(bytes) }
    end
    actual = Dir.glob(File.join(directory, "**", "*"), File::FNM_DOTMATCH).select { |p| File.file?(p) }
      .map { |p| p.delete_prefix(directory + "/") }.sort
    raise Invalid, "Unexpected source file set" unless actual == entries.map { |r| r.fetch("path") }.sort
    { "role" => role, "source_sha" => sha, "files" => entries,
      "manifest_sha256" => Digest::SHA256.hexdigest(JSON.generate(entries)) }
  end

  def self.verify!
    %w[baseline candidate].each do |role|
      raise Invalid, "Source manifest drift" unless source_manifest(role) == read(File.join(OUT, "#{role}-source.json"))
    end
    read(MANIFEST).each do |row|
      raise Invalid, "Frozen harness drift" unless Digest::SHA256.file(File.join(STAGE, row.fetch("path"))).hexdigest == row.fetch("sha256")
      if row.fetch("path").start_with?(SCRIPTS + "/release_perf_")
        raise Invalid, "Execution driver differs from frozen harness" unless Digest::SHA256.file(File.join(QA, row.fetch("path"))).hexdigest == row.fetch("sha256")
      end
    end
    raise Invalid, "Frozen corpus drift" unless Digest::SHA256.file(File.join(STAGE, CORPUS_PATH)).hexdigest == ReleasePerf202::CORPUS_FILE
  end

  def self.container(role)
    ["docker", "run", "--rm", "--name", "ledger-qa202-final-performance", "--platform", "linux/arm64",
      "--network", "none", "--cpus", "1", "--memory", "2g",
      "-v", "#{OUT}:#{OUT}", "-v", "#{File.join(OUT, 'sources', role)}:/qa202-sdk:ro",
      "-v", "#{ReleasePerf202::VOLUME}:/bundle:ro", "-w", STAGE,
      "-e", "GEM_HOME=/bundle/ruby/3.4.0", "-e", "GEM_PATH=/bundle/ruby/3.4.0",
      "-e", "LEDGER_SDK_ROOT=/qa202-sdk", "-e", "LEDGER_CUCUMBER=12.0.1", ReleasePerf202::IMAGE, "ruby"]
  end

  def self.dependencies
    script = <<~'RUBY'
      require "json"; require "digest"
      rows = Dir.glob("/bundle/**/*", File::FNM_DOTMATCH).sort.filter_map do |p|
        next if File.directory?(p)
        [p.delete_prefix("/bundle/"), Digest::SHA256.file(p).hexdigest]
      end
      puts JSON.generate(files: rows.length, manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(rows)),
        ruby: RUBY_DESCRIPTION, manifest: rows)
    RUBY
    data = JSON.parse(command(*(container("baseline") + ["-e", script])))
    raise Invalid, "Pinned dependencies changed" unless data.fetch("files") == 2356 &&
      data.fetch("manifest_sha256") == ReleasePerf202::DEPENDENCIES && data.fetch("ruby").start_with?("ruby 3.4.12 ")
    data
  end

  def self.prepare
    raise Invalid, "Preparation exists; never overwrite" if File.exist?(OUT)
    raise Invalid, "SDK handoff not clean/frozen" unless command("git", "-C", SDK, "rev-parse", "HEAD").strip == ReleasePerf202::FINAL &&
      command("git", "-C", SDK, "status", "--porcelain").empty?
    FileUtils.mkdir_p(STAGE)
    %w[baseline candidate].each do |role|
      sha = role == "baseline" ? ReleasePerf202::BASELINE : ReleasePerf202::FINAL
      target = File.join(OUT, "sources", role)
      FileUtils.mkdir_p(target)
      archive = command("git", "-C", SDK, "archive", sha, "lib", "reportportal-cucumber-ruby.gemspec")
      _, _, status = Open3.capture3("tar", "-xf", "-", "-C", target, stdin_data: archive)
      raise Invalid, "Source archive unpack failed" unless status.success?
      write(File.join(OUT, "#{role}-source.json"), source_manifest(role))
    end
    helpers = %w[run full_trace isolated parallel parallel_support performance performance_support runtime-support]
      .map { |n| "spec/acceptance/ledger_qa/#{n}.rb" }
    files = helpers + ["script/acceptance/presentation_ledger_developer.rb", CORPUS_PATH] +
      Dir.glob(File.join(QA, "script/acceptance/presentation_ledger_developer/*.{rb,json}")).map { |p| p.delete_prefix(QA + "/") } +
      Dir.glob(File.join(__dir__, "release_perf_*.rb")).map { |p| p.delete_prefix(QA + "/") }
    manifest = files.sort.map do |path|
      target = File.join(STAGE, path)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(QA, path), target)
      { "path" => path, "sha256" => Digest::SHA256.file(target).hexdigest }
    end
    write(MANIFEST, manifest)
    corpus = read(File.join(STAGE, CORPUS_PATH))
    ReleasePerf202.validate_corpus!(corpus)
    raise Invalid, "Frozen corpus file mismatch" unless Digest::SHA256.file(File.join(STAGE, CORPUS_PATH)).hexdigest == ReleasePerf202::CORPUS_FILE
    origins = corpus.fetch("cases").flat_map { |row| row.fetch("origins") }.uniq
    origins.each do |row|
      bytes = File.binread(File.join(QA, row.fetch("path")))
      raise Invalid, "Historical source differs from committed origin" unless Digest::SHA256.hexdigest(bytes) == row.fetch("sha256") &&
        Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0".b + bytes) == row.fetch("git_blob") &&
        command("git", "-C", QA, "rev-parse", "#{row.fetch('git_commit')}:#{row.fetch('path')}").strip == row.fetch("git_blob")
    end
    write(File.join(OUT, "corpus-provenance.json"), file_sha256: ReleasePerf202::CORPUS_FILE,
      ordered_input_sha256: ReleasePerf202::CORPUS, cases: 21, exclusions: [], origins: origins)
    jpeg = "/private/tmp/ledger-qa202-9bf3356/jpeg.jpg"
    raise Invalid, "Historical JPEG mismatch" unless Digest::SHA256.file(jpeg).hexdigest == "8c472e5064d09cd6d7f8aca0ce5da74e4ff29073ac5f8f45ae96093f46bed1a9"
    FileUtils.cp(jpeg, File.join(OUT, "jpeg.jpg"))
    image = JSON.parse(command("docker", "image", "inspect", ReleasePerf202::IMAGE)).first
    raise Invalid, "Wrong pinned image" unless image.fetch("Id") == ReleasePerf202::IMAGE && image.fetch("Architecture") == "arm64" && image.fetch("Os") == "linux"
    dep = dependencies
    write(File.join(OUT, "dependencies.json"), dep)
    write(File.join(OUT, "environment.json"), image_id: image.fetch("Id"), architecture: image.fetch("Architecture"),
      os: image.fetch("Os"), ruby: dep.fetch("ruby"), cucumber: "12.0.1", dependency_volume: ReleasePerf202::VOLUME,
      dependency_sha256: dep.fetch("manifest_sha256"), cpu_limit: "1", memory_limit: "2g", network: "none",
      credentials_forwarded: false, corpus_sha256: ReleasePerf202::CORPUS, timings_started: false)
    %w[baseline candidate].each do |role|
      %w[plain rich].each { |mode| child("validate", role, mode, File.join(OUT, "validation-#{role}-#{mode}.json")) }
    end
    verify!
    write(File.join(OUT, "readiness.json"), status: "READY_FOR_MASTER_EXCLUSIVE_QUIET_WINDOW", final_sha: ReleasePerf202::FINAL,
      timings_started: false, validation_only: true, quiet_conditions: QUIET_CONDITIONS,
      remaining_prerequisites: ["Explicit Master exclusive quiet grant after live agents/browser workloads finish", "Original container quiet criterion and separately retained additional host preflight pass"])
    puts "READY: validated both actual modes and frozen source/corpus/dependencies; no timings collected"
  end

  def self.refresh
    raise Invalid, "Never overwrite prepared harness" if File.exist?(STAGE) || File.exist?(MANIFEST)
    original = read(File.join(OUT, "harness-manifest.json"))
    rows = original.reject { |r| r.fetch("path").start_with?(SCRIPTS + "/release_perf_") }.map do |row|
      path = row.fetch("path")
      source = File.join(OUT, "harness-root", path)
      raise Invalid, "First preparation changed" unless Digest::SHA256.file(source).hexdigest == row.fetch("sha256")
      target = File.join(STAGE, path)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(source, target)
      row
    end
    Dir.glob(File.join(__dir__, "release_perf_*.rb")).sort.each do |source|
      path = source.delete_prefix(QA + "/")
      target = File.join(STAGE, path)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(source, target)
      rows << { "path" => path, "sha256" => Digest::SHA256.file(target).hexdigest }
    end
    write(MANIFEST, rows.sort_by { |r| r.fetch("path") })
    raise Invalid, "Dependencies drift" unless dependencies == read(File.join(OUT, "dependencies.json"))
    %w[baseline candidate].each do |role|
      %w[plain rich].each do |mode|
        %w[validate validate-supplement].each do |action|
          child(action, role, mode, File.join(OUT, "#{REVISION}-#{action}-#{role}-#{mode}.json"))
        end
      end
    end
    verify!
    write(File.join(OUT, "readiness-#{REVISION}.json"), status: "READY_FOR_MASTER_EXCLUSIVE_QUIET_WINDOW", final_sha: ReleasePerf202::FINAL,
      timings_started: false, manifest: MANIFEST, previous_preparation_preserved: true,
      quiet_conditions: QUIET_CONDITIONS, supplementary_speed_gate: false,
      remaining_prerequisites: ["Explicit Master exclusive quiet grant after live agents/browser workloads finish", "Original container quiet criterion and separately retained additional host preflight pass"])
    puts "READY #{REVISION}: no timings; normative gates retained, URL costs diagnostic only, host preflight separately labelled"
  end

  def self.child(action, role, mode, output, receipt = nil)
    verify!
    sha = role == "baseline" ? ReleasePerf202::BASELINE : ReleasePerf202::FINAL
    args = container(role) + [File.join(STAGE, SCRIPTS, "release_perf_child.rb"), action, role, mode, sha,
      File.join(STAGE, CORPUS_PATH), output, receipt || "unused", File.join(OUT, "environment.json")]
    out, err, status = Open3.capture3(*args)
    write(output.sub(/\.json\z/, "-process.json"), argv: args, exit: status.exitstatus, stdout: out, stderr: err,
      timing_requested: !action.start_with?("validate"))
    raise Invalid, "Child failed: #{action}/#{role}/#{mode}; inspect process evidence" unless status.success?
    verify!
    read(output)
  end

  def self.load_sample
    rows = command("docker", "stats", "--no-stream", "--format", "{{.Name}} {{.CPUPerc}} {{.MemUsage}}").lines.map do |line|
      name, cpu, *memory = line.split
      { "name" => name, "cpu_percent" => Float(cpu.delete_suffix("%")), "memory" => memory.join(" ") }
    end
    { "utc" => Time.now.utc.iso8601, "containers" => rows, "total_cpu_percent" => rows.sum { |r| r.fetch("cpu_percent") },
      "host_loadavg" => command("sysctl", "-n", "vm.loadavg").strip,
      "host_ncpu" => Integer(command("sysctl", "-n", "hw.ncpu").strip),
      "host_process_cpu" => command("ps", "-Ao", "pid,comm,pcpu").lines.sort_by { |line| -line.split.last.to_f }.first(20) }
  end

  def self.original_container_quiet?(samples)
    return false unless samples.length == 3
    samples.all? { |s| s.fetch("containers").all? { |r| ALLOWED_CONTAINERS.include?(r.fetch("name")) } &&
      s.fetch("total_cpu_percent") <= 35 } &&
      samples.map { |s| s.fetch("total_cpu_percent") }.minmax.then { |a, b| b - a <= 15 }
  end

  def self.additional_host_quiet?(samples)
    samples.length == 3 && samples.all? do |s|
      Float(s.fetch("host_loadavg").delete("{}").split.first) <= s.fetch("host_ncpu")
    end
  end

  def self.quiet?(samples)
    original_container_quiet?(samples) && additional_host_quiet?(samples)
  end

  def self.observe!(window, label, recent)
    sample = load_sample
    write(File.join(window, "load-#{label}.json"), sample)
    recent << sample
    recent.shift while recent.length > 3
    raise Invalid, "Load unstable during window; samples retained, NOT RUN" unless quiet?(recent)
  end

  def self.fixture(window, label, role, mode, kind, fixtures)
    verify!
    target = File.join(STAGE, "docs/reviews/assets", File.basename(window), label)
    args = container(role) + [File.join(STAGE, SCRIPTS, "release_perf_fixture.rb"), kind,
      "--transport", "offline", "--mode", mode, "--fixtures", fixtures, "--sdk-root", "/qa202-sdk",
      "--cucumber", "12.0.1", "--gem-path", "/bundle/ruby/3.4.0", "--jpeg", File.join(OUT, "jpeg.jpg"), "--output", target]
    out, err, status = Open3.capture3(*args)
    write(File.join(window, "#{label}-process.json"), argv: args, exit: status.exitstatus, stdout: out, stderr: err)
    raise Invalid, "Fixture driver failed: #{label}" unless status.success?
    Dir.glob(File.join(target, "**/process.json")).each do |path|
      process = read(path)
      next if path == File.join(target, "probe.json")
      raise Invalid, "Fixture source guard missing/failed" unless process.dig("source_guard", "passed") == true && !process["timed_out"] && process["signal"].nil?
    end
    audits = Dir.glob(File.join(target, "**/release-mode-proof.json"))
    raise Invalid, "No fixture mode proof" if audits.empty? || audits.any? { |p| read(p)["passed"] != true }
    verify!
    target
  end

  def self.run(receipt_path)
    receipt = read(receipt_path)
    ReleasePerf202.gate!(receipt)
    raise Invalid, "Grant older than 30 minutes" unless (0..1800).cover?(Time.now.utc - Time.parse(receipt.fetch("granted_at_utc")))
    verify!
    window = File.join(OUT, receipt.fetch("quiet_window_id"))
    raise Invalid, "Never rerun/overwrite a window" if File.exist?(window)
    FileUtils.mkdir_p(window)
    write(File.join(window, "authorization.json"), receipt)
    frozen_receipt = File.join(window, "authorization.json")
    results = { "status" => "NOT RUN", "final_sha" => ReleasePerf202::FINAL, "baseline_sha" => ReleasePerf202::BASELINE,
      "frozen21" => "NOT RUN", "F07" => "NOT RUN", "all_presentation" => "NOT RUN", "supplement" => "NOT RUN" }
    results["quiet_conditions"] = QUIET_CONDITIONS
    begin
      raise Invalid, "Dependency bytes drift" unless dependencies == read(File.join(OUT, "dependencies.json"))
      settling = []
      18.times do |i|
        settling << load_sample
        break if quiet?(settling.last(3))
        sleep 10 unless i == 17
      end
      write(File.join(window, "settling.json"), samples: settling, conditions: QUIET_CONDITIONS,
        original_container_criterion_passed: original_container_quiet?(settling.last(3)),
        additional_host_preflight_passed: additional_host_quiet?(settling.last(3)))
      raise Invalid, "Load did not settle; no benchmark started" unless quiet?(settling.last(3))
      recent = settling.last(3)
      write(File.join(window, "start.json"), utc: Time.now.utc.iso8601, timed: true)
      pairs = []
      2.times do |round|
        %w[plain rich].each_with_index do |mode, index|
          pair = {}
          order = (round + index).even? ? %w[baseline candidate] : %w[candidate baseline]
          order.each do |role|
            label = "round#{round + 1}-#{role}-#{mode}"
            observe!(window, "#{label}-before", recent)
            pair[role] = child("measure", role, mode, File.join(window, "#{label}.json"), frozen_receipt)
            observe!(window, "#{label}-after", recent)
          end
          raise Invalid, "Runtime activation mismatch" unless pair.fetch("baseline").dig("activation", "gems") == pair.fetch("candidate").dig("activation", "gems")
          comparison = ReleasePerf202.compare(pair.fetch("baseline"), pair.fetch("candidate"))
          write(File.join(window, "round#{round + 1}-#{mode}-comparison.json"), comparison)
          pairs.concat(comparison)
          unless comparison.all? { |r| r["regression_pass"] && r["renderer_under_2ms"] != false }
            results["frozen21"] = { "status" => "FAIL", "comparisons" => pairs }
            raise Regression, "Frozen21 p95 regression > +10% or renderer >= 2ms"
          end
        end
      end
      results["frozen21"] = { "status" => "PASS", "comparisons" => pairs, "rounds" => 2, "gating" => "Each matched round independently; no favorable-round selection" }
      wall = Hash.new { |h, k| h[k] = [] }
      3.times do |repeat|
        [["baseline", "plain"], ["candidate", "plain"], ["candidate", "rich"]].rotate(repeat).each do |role, mode|
          label = "wall-#{repeat + 1}-#{role}-#{mode}"
          observe!(window, "#{label}-before", recent)
          target = fixture(window, label, role, mode, "wall", "F07")
          process = read(File.join(target, "F07/process.json"))
          raise Invalid, "Invalid F07 workload" unless process["exit"] == 0 &&
            read(File.join(target, "F07/result.json")).dig("native_steps", "passed") == 50
          wall["#{role}-#{mode}"] << process.fetch("seconds")
          observe!(window, "#{label}-after", recent)
        end
      end
      wall = wall.transform_values { |v| { "raw_seconds" => v, "median_seconds" => v.sort[1] } }
      wall_pass = wall.values.all? { |r| r.fetch("median_seconds") <= wall.fetch("baseline-plain").fetch("median_seconds") * 1.10 }
      write(File.join(window, "wall-comparison.json"), results: wall, pass: wall_pass)
      unless wall_pass
        results["F07"] = { "status" => "FAIL", "results" => wall }
        raise Regression, "F07 median regression > +10%"
      end
      results["F07"] = { "status" => "PASS", "results" => wall }
      all_presentation = {}
      %w[plain rich].each do |mode|
        pooled = Hash.new { |h, k| h[k] = [] }
        selection = (1..18).reject { |n| n == 6 }.map { |n| format("F%02d", n) }.join(",")
        [["micro", selection], ["parallel-micro", "F06"]].each do |kind, ids|
          label = "#{kind}-#{mode}"
          observe!(window, "#{label}-before", recent)
          target = fixture(window, label, "candidate", mode, kind, ids)
          timings = Dir.glob(File.join(target, "**/presentation-timings.json"))
          raise Invalid, "No Presentation timing evidence" if timings.empty?
          timings.each do |path|
            data = read(path)
            raise Invalid, "Presentation replay errors" unless data.fetch("replay_errors").empty?
            data.fetch("samples").each { |name, values| pooled[name].concat(values) }
          end
          observe!(window, "#{label}-after", recent)
        end
        summary = pooled.transform_values { |v| { "count" => v.length, "p95_ms" => ReleasePerf202.p95(v) } }
        write(File.join(window, "all-presentation-#{mode}.json"), summary)
        raise Invalid, "Missing FailureCard samples" unless pooled.fetch("FailureCard.format").length == 1050
        unless summary.values.all? { |r| r.fetch("p95_ms") < 2 }
          results["all_presentation"] = { "status" => "FAIL", "mode" => mode, "summary" => summary }
          raise Regression, "Presentation call p95 >= 2ms"
        end
        all_presentation[mode] = summary
      end
      results["all_presentation"] = { "status" => "PASS", "modes" => all_presentation,
        "historical_non_exception_F16c" => "Retained original runner unsupported record; not in frozen21 corpus; no synthetic replacement" }
      supplement = {}
      %w[plain rich].each do |mode|
        pair = {}
        %w[baseline candidate].each do |role|
          label = "supplement-#{role}-#{mode}"
          observe!(window, "#{label}-before", recent)
          pair[role] = child("supplement", role, mode, File.join(window, "#{label}.json"), frozen_receipt)
          observe!(window, "#{label}-after", recent)
        end
        supplement[mode] = pair.transform_values { |data| ReleasePerf202.diagnostic_cost(data) }
      end
      write(File.join(window, "supplement-absolute-cost.json"), supplement)
      results["supplement"] = { "status" => "DIAGNOSTIC_MEASURED", "scope" => "SEPARATE_NOT_CORPUS_REPLACEMENT",
        "blocking_speed_threshold" => nil, "absolute_cost" => supplement }
      verify!
      raise Invalid, "Dependency bytes changed during run" unless dependencies == read(File.join(OUT, "dependencies.json"))
      results["status"] = "PASS"
    rescue Regression => error
      results["status"] = "FAIL"
      results["reason"] = error.message
    rescue StandardError => error
      results["status"] = "NOT RUN"
      results["reason"] = "#{error.class}: #{error.message}"
    ensure
      results["ended_utc"] = Time.now.utc.iso8601
      write(File.join(window, "result.json"), results)
      puts JSON.generate(results)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  case ARGV.shift
  when "prepare" then ReleasePerfDriver202.prepare
  when "refresh" then ReleasePerfDriver202.refresh
  when "run" then ReleasePerfDriver202.run(ARGV.fetch(0))
  else abort "Use prepare (no timing), or run MASTER_RECEIPT.json after an explicit exclusive grant"
  end
end
