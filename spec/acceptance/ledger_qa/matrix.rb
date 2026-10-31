# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "digest"

module LedgerQAMatrix
  ROOT = File.expand_path("../../..", __dir__)
  ASSETS = File.join(ROOT, "docs/reviews/assets")
  CELLS = [["M1", "1", "3.1", "9.2.1"], ["M2", "1", "3.1", "10.2.0"],
           ["M3", "1", "3.3", "9.2.1"], ["M4", "1", "3.3", "10.2.0"],
           ["M5", "2", "3.3", "12.0.1"], ["M6", "2", "3.4", "12.0.1"]].freeze
  def self.record(path, value)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(value) + "\n")
  end

  def self.command(out, label, *args)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status = nil
    File.open(File.join(out, "#{label}.log"), "w") do |log|
      Open3.popen2e(*args) do |input, output, process|
        input.close
        IO.copy_stream(output, log)
        status = process.value
      end
    end
    result = { argv: args, exit: status.exitstatus, seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - start }
    puts "#{label}: #{result[:exit]}"
    $stdout.flush
    result
  end

  def self.cell
    out = ENV.fetch("QA_OUT")
    FileUtils.mkdir_p(out)
    result = { cell: ENV.fetch("QA_CELL"), ruby: RUBY_DESCRIPTION, commands: [], source_head: ENV.fetch("QA_HEAD") }
    begin
      Dir.chdir(ROOT)
      ENV["BUNDLE_IGNORE_CONFIG"] = "1"
      ENV["BUNDLE_SILENCE_ROOT_WARNING"] = "1"
      ENV["CUCUMBER_PUBLISH_QUIET"] = "true"
      ENV["CUCUMBER_PUBLISH_ENABLED"] = "false"
      ENV.delete("RP_ENABLED")
      ENV["NO_COLOR"] = "1"
      unless File.executable?("/usr/bin/gcc") && File.executable?("/usr/bin/git")
        result[:commands] << command(out, "apt-update", "apt-get", "update", "-qq")
        result[:commands] << command(out, "apt-tools", "apt-get", "install", "-y", "--no-install-recommends", "git", "ca-certificates", "curl", "gcc", "make", "libc6-dev", "libffi-dev")
      end
      result[:commands] << command(out, "safe-checkout", "git", "config", "--global", "--add", "safe.directory", ROOT)
      if Gem::Specification.find_all_by_name("bundler", "2.6.6").empty?
        result[:commands] << command(out, "bundler-install", "gem", "install", "bundler", "-v", "2.6.6", "--no-document")
      end
      gemfile = File.join(ROOT, "Gemfile")
      ENV["BUNDLE_GEMFILE"] = gemfile
      ENV["BUNDLE_PATH"] = "/bundle"
      ENV["BUNDLE_FROZEN"] = "false"
      result[:commands] << command(out, "bundle", "bundle", "_2.6.6_", "install", "--local")
      unless result[:commands].last[:exit] == 0
        result[:commands] << command(out, "bundle-network", "bundle", "_2.6.6_", "install")
      end
      raise "Dependency resolution blocked" unless result[:commands].last[:exit] == 0
      result[:commands] << command(out, "runtime", "bundle", "exec", "ruby", "-e", "require 'json'; require 'reportportal_cucumber'; puts JSON.generate(ruby: RUBY_DESCRIPTION, cucumber: Gem.loaded_specs.fetch('cucumber').version.to_s, sdk: ReportportalCucumber::VERSION)")
      result[:runtime] = JSON.parse(File.read(File.join(out, "runtime.log")))
      ENV["PATH"] = "/tools:#{ENV.fetch('PATH')}"
      ENV["HELM_BIN"] = "/tools/helm"
      ENV["DOCKER_CONFIG"] = File.join(out, "docker-config")
      FileUtils.mkdir_p(File.join(ENV["DOCKER_CONFIG"], "cli-plugins"))
      FileUtils.ln_sf("/tools/docker-compose", File.join(ENV["DOCKER_CONFIG"], "cli-plugins/docker-compose"))
      ENV["QA_DEADLINE_EVIDENCE"] = File.join(out, "deadline-observations.ndjson")
      result[:commands] << command(out, "rspec", "bundle", "exec", "rspec", "--require", "./spec/acceptance/ledger_qa/deadline_probe.rb", "spec", "spec/acceptance/ledger_qa/properties.rb", "--format", "progress", "--format", "json", "--out", File.join(out, "rspec.json"))
      result[:commands] << command(out, "cucumber", "bundle", "exec", "cucumber", "--format", "progress", "--format", "json", "--out", File.join(out, "cucumber.json"))
      result[:commands] << command(out, "fixtures", RbConfig.ruby, File.join(ROOT, "spec/acceptance/ledger_qa/isolated.rb"),
        "--transport", "offline", "--mode", "plain", "--fixtures", "all", "--sdk-root", ROOT,
        "--cucumber", ENV.fetch("QA_CUCUMBER"), "--gem-path", "/bundle/ruby/#{RbConfig::CONFIG.fetch('ruby_version')}",
        "--jpeg", "/qa-media/jpeg.jpg", "--output", File.join(out, "fixtures"))
      result[:rspec] = JSON.parse(File.read(File.join(out, "rspec.json"))).fetch("summary") if File.file?(File.join(out, "rspec.json"))
      if File.file?(File.join(out, "cucumber.json"))
        elements = JSON.parse(File.read(File.join(out, "cucumber.json"))).flat_map { |f| f.fetch("elements", []) }
        steps = elements.flat_map { |s| s.fetch("steps", []) }
        result[:cucumber] = { scenarios: elements.length, steps: steps.length, statuses: steps.group_by { |s| s.dig("result", "status") }.transform_values(&:length) }
      end
      result[:status] = result[:commands].last(3).all? { |r| r[:exit] == 0 } ? "PASS" : "FAIL"
    rescue StandardError => error
      result[:status] = "BLOCKED"
      result[:reason] = "#{error.class}: #{error.message}"
    ensure
      record(File.join(out, "result.json"), result)
    end
  end

  def self.driver
    stamp = ENV.fetch("QA_STAMP", Time.now.utc.strftime("%Y%m%dT%H%M%SZ"))
    results = []
    CELLS.each do |id, line, ruby, cucumber|
      next if ENV["QA_CELLS"] && !ENV["QA_CELLS"].split(",").include?(id)
      root = "/Users/nick/Documents/crr-qa-#{line == '1' ? '1.3.2' : '2.0.1'}"
      cell_root = File.join(root, "docs/reviews/assets/ledger-qa-runs", stamp, id)
      source = File.join(cell_root, "source")
      FileUtils.mkdir_p(cell_root)
      head = Open3.capture2("git", "-C", root, "rev-parse", "HEAD").first.strip
      raise "Fresh scratch checkout required" if File.exist?(source)
      raise "QA scratch clone failed" unless system("git", "clone", "--quiet", "--no-hardlinks", root, source)
      FileUtils.cp_r(File.join(root, "spec/acceptance/ledger_qa"), File.join(source, "spec/acceptance"))
      # Acceptance section 2 requires disposable dependency pins. These are
      # runtime scratch files, never edits to either QA or feature worktree.
      if line == "1"
        File.open(File.join(source, "Gemfile"), "a") { |file| file.puts("\ngem \"cucumber\", \"= #{cucumber}\"") }
        FileUtils.rm_f(File.join(source, "Gemfile.lock"))
      end
      out = File.join(source, "docs/reviews/assets/qa-cell-evidence")
      FileUtils.mkdir_p(out)
      record(File.join(cell_root, "source-provenance.json"), source_head: head, scratch_source: source,
        dependency_pin: line == "1" ? cucumber : "committed lock", source_lib_sha256: Dir[File.join(source, "lib/**/*.rb")].sort.to_h { |p| [p.delete_prefix(source + "/"), Digest::SHA256.file(p).hexdigest] })
      chart = "/private/tmp/ledger-final-matrix-20261031T063546Z-62ce39/M6-ruby34-cucumber12/source/helm/reportportal-rich-experience/charts"
      image_file = "/Users/nick/Documents/crr-qa-2.0.1/docs/reviews/assets/ledger-qa-environment/ruby#{ruby.delete('.')}-image.txt"
      image = File.file?(image_file) ? File.read(image_file).strip : "ruby:#{ruby}-slim"
      args = ["docker", "run", "--rm", "--name", "independent-ledger-qa-#{id.downcase}-#{stamp.downcase}", "--cpus", "2", "--memory", "3g",
              "-v", "#{source}:#{source}", "-w", source,
              "-v", "/private/tmp/ledger-matrix-bundles/ruby#{ruby.delete('.')}:/bundle",
              "-v", "/private/tmp/ledger-pinned-tools/linux-arm64:/tools:ro",
              "-v", "/Users/nick/Documents/crr-2.0.1/script/acceptance/presentation_ledger_developer/evidence/baseline2-all/media:/qa-media:ro",
              "-v", "#{chart}:#{source}/helm/reportportal-rich-experience/charts:ro",
              "-e", "QA_CELL=#{id}", "-e", "QA_CUCUMBER=#{cucumber}", "-e", "QA_OUT=#{out}", "-e", "QA_HEAD=#{head}",
              image, "ruby", File.join(source, "spec/acceptance/ledger_qa/matrix.rb"), "--cell"]
      puts "FULL_MATRIX_START #{id} #{head}"
      $stdout.flush
      command(out, "container", *args)
      path = File.join(out, "result.json")
      FileUtils.cp(path, File.join(cell_root, "result.json")) if File.file?(path)
      results << (File.file?(path) ? JSON.parse(File.read(path)) : { cell: id, status: "BLOCKED", reason: "Container did not produce a result" })
      record(File.join(ASSETS, "ledger-qa-matrix-#{stamp}.json"), results)
      puts JSON.generate(results.last.slice("cell", "status", "runtime", "rspec", "cucumber", "reason"))
    end
  end
end

ARGV.include?("--cell") ? LedgerQAMatrix.cell : LedgerQAMatrix.driver
