# frozen_string_literal: true

require "json"
require "open3"
require "fileutils"
require "digest"
require "time"
require_relative "final_wp5_context"

module LedgerFinalWP5
  ROOT = File.expand_path("../../..", __dir__)
  STAMP = LedgerWP5Context.stamp
  LINES = {
    "2.0.1" => { sha: LedgerWP5Context.heads.fetch("2.0.1"), base: "79e5e9cfde4be6d29ca2293e549460c6c71fe87a", rubies: ["3.4"], cucumbers: ["12.0.1"] },
    "1.3.2" => { sha: LedgerWP5Context.heads.fetch("1.3.2"), base: "4ca2f770e0a84e83688f165ba04b4db8ef855cf9", rubies: ["3.3"], cucumbers: ["9.2.1", "10.2.0"] }
  }.freeze
  JPEG = "/Users/nick/Documents/crr-2.0.1/script/acceptance/presentation_ledger_developer/evidence/baseline2-all/media/jpeg.jpg"
  CELLS = [["M1", "1.3.2", "3.1", "9.2.1"], ["M2", "1.3.2", "3.1", "10.2.0"],
           ["M3", "1.3.2", "3.3", "9.2.1"], ["M4", "1.3.2", "3.3", "10.2.0"],
           ["M5", "2.0.1", "3.3", "12.0.1"], ["M6", "2.0.1", "3.4", "12.0.1"]].freeze

  def self.write(path, value)
    FileUtils.mkdir_p(File.dirname(path))
    serialized = JSON.pretty_generate(value) + "\n"
    key = ENV["RP_API_KEY"].to_s
    raise "Refusing credential-bearing artifact" if !key.empty? && serialized.include?(key)
    File.write(path, serialized, perm: 0o600)
  end

  def self.git(root, *args)
    stdout, _stderr, status = Open3.capture3("git", "-C", root, *args)
    raise "Git read failed" unless status.success?
    stdout.strip
  end

  def self.guard(version)
    config = LINES.fetch(version)
    sdk = "/Users/nick/Documents/crr-#{version}"
    raise "Final runtime head changed; stop and realign" unless git(sdk, "rev-parse", "HEAD") == config[:sha]
    paths = git(sdk, "diff", "--name-only", "HEAD", "--", "lib", "Gemfile", "Gemfile.lock", "reportportal-cucumber-ruby.gemspec")
    raise "Runtime has uncommitted changes" unless paths.empty?
    sdk
  end

  def self.execute(qa, label, args, env = {})
    out = File.join(qa, "docs/reviews/assets", STAMP, "driver", label)
    raise "Never replace an earlier execution" if File.exist?(out)
    FileUtils.mkdir_p(out)
    started = Time.now.utc.iso8601
    status = nil
    File.open(File.join(out, "stdout.log"), "w", 0o600) do |stdout|
      File.open(File.join(out, "stderr.log"), "w", 0o600) do |stderr|
        status = system(env, *args, out: stdout, err: stderr)
      end
    end
    write(File.join(out, "process.json"), argv: args, started_at_utc: started,
      finished_at_utc: Time.now.utc.iso8601, exit: $?&.exitstatus, success: status)
    puts "#{label}: #{status ? 'captured' : 'BLOCKED; inspect retained driver logs'}"
    $stdout.flush
    status
  end

  def self.container(qa, sdk, version, ruby, cucumber, entry, tail, live: false, extra: {})
    digits = ruby.delete(".")
    baseline = "/Users/nick/Documents/crr-qa-baseline-#{version == '1.3.2' ? '1.3.1' : '2.0.0'}"
    if live
      volume = dependency_volume(qa, ruby)
      args = ["docker", "run", "--rm", "--add-host", "rp-2607.localhost:host-gateway",
        "-v", "#{qa}:#{qa}", "-v", "#{sdk}:/qa-seed/final:ro", "-v", "#{baseline}:/qa-seed/baseline:ro",
        "-v", "#{volume}:/bundle:ro", "-v", "#{File.dirname(JPEG)}:#{File.dirname(JPEG)}:ro", "-w", qa,
        "-e", "RP_API_KEY", "-e", "RP_ENDPOINT=http://rp-2607.localhost:18080", "-e", "RP_PROJECT=superadmin_personal",
        "-e", "QA_FINAL_SDK_ROOT=#{sdk}", "-e", "QA_FINAL_SOURCE_SHA=#{LINES.fetch(version)[:sha]}",
        "-e", "QA_BASELINE_SDK_ROOT=#{baseline}", "-e", "QA_BASELINE_SOURCE_SHA=#{LINES.fetch(version)[:base]}",
        "-e", "QA_DEPENDENCY_VOLUME=#{volume}"]
      extra.each { |name, value| args.concat(["-e", "#{name}=#{value}"]) }
      stage = "/Users/nick/Documents/crr-qa-2.0.1/spec/acceptance/ledger_qa/final_wp5_container_stage.rb"
      args.concat(["-v", "#{File.dirname(stage)}:/qa-stage:ro", "ruby:#{ruby}-slim", "ruby", "/qa-stage/final_wp5_container_stage.rb",
        File.join(qa, "spec/acceptance/ledger_qa/#{entry}.rb"), *tail])
      return args
    end
    args = ["docker", "run", "--rm", "--add-host", "rp-2607.localhost:host-gateway",
      "-v", "#{qa}:#{qa}", "-v", "#{sdk}:#{sdk}:ro", "-v", "#{baseline}:#{baseline}:ro",
      "-v", "/Users/nick/Documents/New project/.git:/Users/nick/Documents/New project/.git:ro",
      "-v", "#{File.dirname(JPEG)}:#{File.dirname(JPEG)}:ro",
      "-v", "/private/tmp/ledger-matrix-bundles/ruby#{digits}:/bundle:ro", "-w", qa]
    args.concat(["-e", "RP_API_KEY", "-e", "RP_ENDPOINT=http://rp-2607.localhost:18080", "-e", "RP_PROJECT=superadmin_personal"]) if live
    extra.each { |name, value| args.concat(["-e", "#{name}=#{value}"]) }
    args.concat(["ruby:#{ruby}-slim", "ruby", File.join(qa, "spec/acceptance/ledger_qa/#{entry}.rb"), *tail])
    args
  end

  def self.dependency_volume(qa, ruby)
    @dependency_volumes ||= {}
    return @dependency_volumes[ruby] if @dependency_volumes.key?(ruby)
    name = "ledger-qa-#{STAMP.downcase}-ruby#{ruby.delete('.')}"
    image = "ruby:#{ruby}-slim"
    destination = File.join(qa, "docs/reviews/assets", STAMP, "dependency-volumes", "ruby#{ruby.delete('.')}.json")
    existing, _, status = Open3.capture3("docker", "volume", "inspect", name)
    raise "Refusing to reuse an unverified dependency volume" if status.success? && !File.file?(destination)
    unless status.success?
      raise "Dependency volume creation failed" unless system("docker", "volume", "create", name, out: File::NULL)
      bootstrap = <<~'RUBY'
        require "fileutils"; require "digest"; require "json"
        FileUtils.cp_r(Dir.children("/seed").map { |n| "/seed/#{n}" }, "/bundle")
        manifest = ->(root) { Dir.glob(root + "/**/*", File::FNM_DOTMATCH).sort.filter_map { |p| next if File.directory?(p); [p.delete_prefix(root + "/"), Digest::SHA256.file(p).hexdigest] } }
        left, right = manifest.call("/seed"), manifest.call("/bundle")
        abort "Dependency copy mismatch" unless left == right
        puts JSON.generate(file_count: left.length, exact_manifest_equal: true, source_manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(left)), copied_manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(right)))
      RUBY
      stdout, stderr, result = Open3.capture3("docker", "run", "--rm", "-v", "/private/tmp/ledger-matrix-bundles/ruby#{ruby.delete('.')}:/seed:ro", "-v", "#{name}:/bundle", image, "ruby", "-e", bootstrap)
      raise "Dependency copy failed" unless result.success?
      write(destination, JSON.parse(stdout).merge(volume: name, ruby_image: image, source: "Existing cached dependency files; no credential environment passed to staging", stderr: stderr))
    end
    @dependency_volumes[ruby] = name
  end

  def self.live
    abort "BLOCKED: Master must supply RP_API_KEY through environment only" if ENV["RP_API_KEY"].to_s.empty?
    LINES.each do |version, config|
      next if ENV["QA_WP5_LINE"] && ENV["QA_WP5_LINE"] != version
      qa = "/Users/nick/Documents/crr-qa-#{version}"
      sdk = guard(version)
      baseline = "/Users/nick/Documents/crr-qa-baseline-#{version == '1.3.2' ? '1.3.1' : '2.0.0'}"
      raise "Incorrect frozen baseline" unless git(baseline, "rev-parse", "HEAD") == config[:base]
      config[:cucumbers].each do |cucumber|
        ruby = config[:rubies].first
        prefix = "#{STAMP}-c#{cucumber}"
        capture = lambda do |entry, suffix, source, mode, fixtures, batch = 20|
          out = File.join(qa, "docs/reviews/assets/ledger-qa-live/#{prefix}-#{suffix}")
          tail = ["--transport", "live", "--mode", mode, "--fixtures", fixtures, "--sdk-root", source,
            "--cucumber", cucumber, "--gem-path", "/bundle/ruby/#{ruby}.0", "--jpeg", JPEG,
            "--batch-size", batch.to_s, "--output", out]
          ok = execute(qa, "live-#{cucumber}-#{suffix}", container(qa, sdk, version, ruby, cucumber, entry, tail, live: true))
          abort "BLOCKED: capture failed; do not silently skip it" unless ok
          guard(version)
        end
        %w[plain rich].each do |mode|
          [1, 2].each do |repeat|
            capture.call("isolated", "#{mode}-#{repeat}", sdk, mode, "all")
            capture.call("frozen", "supplement-#{mode}-#{repeat}", sdk, mode, "F01,F02,F04,F16c")
            capture.call("framework_shape", "framework-#{mode}-#{repeat}", sdk, mode, "F16b")
            capture.call("contract_gaps", "authored-#{mode}-#{repeat}", sdk, mode, "all")
            capture.call("parallel", "parallel-#{mode}-#{repeat}", sdk, mode, "F06") if version == "2.0.1"
          end
        end
        capture.call("isolated", "baseline", baseline, "plain", "all")
        capture.call("frozen", "supplement-baseline", baseline, "plain", "F01,F02,F04,F16c")
        capture.call("framework_shape", "framework-baseline", baseline, "plain", "F16b")
        capture.call("contract_gaps", "authored-baseline", baseline, "plain", "all")
        capture.call("parallel", "parallel-baseline", baseline, "plain", "F06") if version == "2.0.1"
        capture.call("isolated", "default-batch1", sdk, "default", "F01,F17,F20", 1)
      end
    end
  end

  def self.matrix
    CELLS.each do |cell, version, ruby, cucumber|
      next if ENV["QA_WP5_CELLS"] && !ENV["QA_WP5_CELLS"].split(",").include?(cell)
      qa = "/Users/nick/Documents/crr-qa-#{version}"
      sdk = guard(version)
      directory = File.join(qa, "docs/reviews/assets", STAMP, "matrix", cell)
      source = File.join(directory, "source")
      raise "Never replace a matrix execution" if File.exist?(directory)
      FileUtils.mkdir_p(directory)
      raise "Scratch clone failed" unless system("git", "clone", "--quiet", "--no-hardlinks", "--no-checkout", sdk, source)
      raise "Scratch pin failed" unless system("git", "-C", source, "checkout", "--quiet", "--detach", LINES.fetch(version)[:sha])
      FileUtils.cp_r(File.join(qa, "spec/acceptance/ledger_qa"), File.join(source, "spec/acceptance"))
      FileUtils.cp(File.join(__dir__, "final_wp5_matrix_stage.rb"), File.join(source, "spec/acceptance/ledger_qa/final_wp5_matrix_stage.rb"))
      FileUtils.cp(File.join(__dir__, "final_wp5_local_cell.rb"), File.join(source, "spec/acceptance/ledger_qa/final_wp5_local_cell.rb"))
      if version == "1.3.2"
        File.open(File.join(source, "Gemfile"), "a") { |file| file.puts("\ngem \"cucumber\", \"= #{cucumber}\"") }
        FileUtils.rm_f(File.join(source, "Gemfile.lock"))
      end
      fingerprints = Dir[File.join(source, "lib/**/*.rb")].sort.to_h { |p| [p.delete_prefix(source + "/"), Digest::SHA256.file(p).hexdigest] }
      write(File.join(directory, "provenance.json"), runtime_sha: LINES.fetch(version)[:sha], ruby: ruby, cucumber: cucumber,
        runtime_files: fingerprints, dependency_pin_scope: "Disposable QA scratch only, as acceptance section 2 requires; original worktrees unchanged")
      out = File.join(source, "docs/reviews/assets/qa-cell-evidence")
      chart = "/private/tmp/ledger-final-matrix-20261031T063546Z-62ce39/M6-ruby34-cucumber12/source/helm/reportportal-rich-experience/charts"
      image_file = File.join("/Users/nick/Documents/crr-qa-2.0.1/docs/reviews/assets/ledger-qa-environment", "ruby#{ruby.delete('.')}\u002dimage.txt")
      image = File.file?(image_file) ? File.read(image_file).strip : "ruby:#{ruby}-slim"
      args = ["docker", "run", "--rm", "--cpus", "2", "--memory", "3g", "-v", "#{source}:/qa-seed/source:ro", "-w", "/tmp",
        "-v", "#{directory}:/qa-export", "-v", "/private/tmp/ledger-matrix-bundles/ruby#{ruby.delete('.')}:/qa-seed/bundle:ro",
        "-v", "/private/tmp/ledger-pinned-tools/linux-arm64:/tools:ro", "-v", "#{File.dirname(JPEG)}:/qa-media:ro",
        "-v", "#{chart}:/qa-seed/charts:ro",
        "-e", "QA_CELL=#{cell}", "-e", "QA_CUCUMBER=#{cucumber}", "-e", "QA_EXPORT=/qa-export/source/docs/reviews/assets/qa-cell-evidence", "-e", "QA_HEAD=#{LINES.fetch(version)[:sha]}",
        image, "ruby", "/qa-seed/source/spec/acceptance/ledger_qa/final_wp5_local_cell.rb", "--cell"]
      execute(qa, "matrix-#{cell}", args)
      FileUtils.cp(File.join(out, "result.json"), File.join(directory, "result.json")) if File.file?(File.join(out, "result.json"))
      guard(version)
    end
  end

  def self.probes
    LINES.each do |version, config|
      next if ENV["QA_WP5_LINE"] && ENV["QA_WP5_LINE"] != version
      qa = "/Users/nick/Documents/crr-qa-#{version}"
      sdk = guard(version)
      baseline = "/Users/nick/Documents/crr-qa-baseline-#{version == '1.3.2' ? '1.3.1' : '2.0.0'}"
      ruby = config[:rubies].first
      config[:cucumbers].each do |cucumber|
        prefix = File.join(qa, "docs/reviews/assets", STAMP, "probes", "c#{cucumber}")
        capture = lambda do |entry, label, source, mode, fixtures, extra = {}, kind = nil|
          out = File.join(prefix, label)
          tail = ["--transport", "offline", "--mode", mode, "--fixtures", fixtures, "--sdk-root", source,
            "--cucumber", cucumber, "--gem-path", "/bundle/ruby/#{ruby}.0", "--jpeg", JPEG, "--output", out]
          tail.unshift(kind) if kind
          execute(qa, "probe-#{cucumber}-#{label}", container(qa, sdk, version, ruby, cucumber, entry, tail, extra: extra))
        end
        unless ENV["QA_WP5_PROBE_KIND"] == "faults"
        3.times do |repeat|
          [[baseline, "baseline", "plain"], [sdk, "plain", "plain"], [sdk, "rich", "rich"]].rotate(repeat).each do |source, label, mode|
            capture.call("performance", "wall-#{repeat + 1}-#{label}", source, mode, "F07", {}, "wall")
          end
        end
        fixtures = (1..18).reject { |n| n == 6 }.map { |n| format("F%02d", n) }.join(",")
        %w[plain rich].each do |mode|
          capture.call("performance", "micro-#{mode}", sdk, mode, fixtures, {}, "micro")
          capture.call("performance", "parallel-micro-#{mode}", sdk, mode, "F06", {}, "parallel-micro") if version == "2.0.1"
        end
        end
        next if ENV["QA_WP5_PROBE_KIND"] == "performance"
        entries = {
          "MarkdownText.html" => "F10a", "MarkdownText.inline" => "F10a", "MarkdownText.code" => "F10a",
          "MarkdownText.fence" => "F10c", "MarkdownText.cell" => "F13", "FailureCard.format" => "F04",
          "LedgerJson.format" => "F10d", "AttachmentCaption.format" => "F01", "AttachmentCaption.kind" => "F01",
          "AttachmentCaption.slug" => "F17", "ImageDimensions.read" => "F01", "ImageDimensions.png" => "F01",
          "ImageDimensions.jpeg" => "F17", "Units.bytes" => "F11a", "Units.count" => "F04", "Units.duration" => "F11b",
          "RunContext.build" => "F19a", "RunContext.first" => "F19a", "RunContext.trim" => "F19a",
          "Accent.pill" => "F10a", "Accent.title" => "F10a", "Accent.table_header" => "F13",
          "Accent.details" => "F04", "Accent.guard" => "F10a"
        }
        entries.each do |entry, fixture|
          name = "fault-#{entry.tr('.', '-')}"
          extra = { "QA_FAULT_ENTRY" => entry, "QA_FALLBACK_CAPTURE" => File.join(prefix, "#{name}-fallback.ndjson") }
          capture.call("isolated", name, sdk, "rich", fixture, extra)
        end
        guard(version)
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
case ARGV.fetch(0)
when "live" then LedgerFinalWP5.live
when "matrix" then LedgerFinalWP5.matrix
when "probes" then LedgerFinalWP5.probes
else abort "Use live, matrix or probes"
end
end
