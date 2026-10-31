# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "rubygems/package"
require "shellwords"
require "socket"
require "time"
require "timeout"
require "uri"

module Cucumber12CleanroomPayload
  module_function

  def write_json(path, value)
    File.write(path, JSON.pretty_generate(value) + "\n")
  end

  def run(label, *argv, expected: 0, timeout: 300)
    puts "$ #{Shellwords.join(argv)}"
    started = Time.now.utc
    stdout = stderr = nil
    status = nil
    Open3.popen3(*argv, pgroup: true) do |input, output, errors, process|
      input.close
      readers = [Thread.new { output.read }, Thread.new { errors.read }]
      begin
        Timeout.timeout(timeout) { status = process.value }
      rescue Timeout::Error
        Process.kill("KILL", -process.pid)
        process.value
        raise "Command exceeded #{timeout}s: #{Shellwords.join(argv)}"
      ensure
        stdout, stderr = readers.map(&:value)
      end
    end
    File.write("/evidence/#{label}.stdout", stdout)
    File.write("/evidence/#{label}.stderr", stderr)
    File.open("/evidence/commands.jsonl", "a") do |file|
      file.puts(JSON.generate(argv: argv, command: Shellwords.join(argv), started_at: started.iso8601,
                              seconds: Time.now.utc - started, exit: status.exitstatus, expected: expected))
    end
    puts stdout
    warn stderr unless stderr.empty?
    raise "#{label}: expected exit #{expected}, got #{status.exitstatus}" unless status.exitstatus == expected
    if (stdout + stderr).match?(/cannot load such file.*(?:base64|logger|mutex_m)|LoadError|Gem::MissingSpec|Gem::LoadError/)
      raise "#{label}: missing-gem/load error"
    end
    stdout
  end

  def baseline
    FileUtils.mkdir_p([ENV.fetch("HOME"), ENV.fetch("GEM_HOME")])
    state = { ruby: RUBY_DESCRIPTION, rubygems: Gem::VERSION, gem_home: Gem.dir, gem_paths: Gem.path,
              environment: ENV.to_h, inputs: Dir["/inputs/*"].sort.to_h { |file| [File.basename(file), Digest::SHA256.file(file).hexdigest] },
              private_gem_home_contents: Dir["/clean/gems/**/*"],
              installed_gems: Gem::Specification.map { |spec| { name: spec.name, version: spec.version.to_s, default: spec.default_gem?, loaded_from: spec.loaded_from } },
              work_files: Dir["/work/{*,.*}"].reject { |path| %w[. ..].include?(File.basename(path)) } }
    write_json("/evidence/before-install.json", state)
    raise "Inherited gems in GEM_HOME" unless state.fetch(:private_gem_home_contents).empty?
    raise "Inherited workspace files/lock" unless state.fetch(:work_files).empty?
    raise "Inherited SDK/Cucumber" if Gem::Specification.any? { |spec| %w[reportportal-cucumber-ruby cucumber].include?(spec.name) }
    raise "Inherited Ruby load configuration" if ENV.key?("RUBYOPT") || ENV.key?("RUBYLIB") || ENV.key?("BUNDLE_GEMFILE")
    run("ruby", "ruby", "--version")
    run("gem-env", "gem", "environment")
    run("gem-list-before", "gem", "list", "--local")
  end

  def toolchain
    # OS build tools only, never bootstrap standard gems or test/development gems.
    run("apt-update", "apt-get", "update", timeout: 180)
    run("apt-toolchain", "apt-get", "install", "--no-install-recommends", "-y", "build-essential", "pkg-config", "libffi-dev", timeout: 300)
  end

  def verify_input_packages!(input = "/inputs")
    expected = JSON.parse(File.read(File.join(input, "package-sha256.json")))
    actual = Dir[File.join(input, "*.gem")].map { |path| File.basename(path) }.sort
    raise "Unexpected staged gem inputs" unless actual == expected.keys.sort
    expected.each do |filename, sha|
      unless filename.match?(/\Areportportal-cucumber-ruby-(?:1\.3\.1|2\.0\.0)\.gem\z/) && sha.match?(/\A[0-9a-f]{64}\z/)
        raise "Invalid staged package manifest"
      end
      raise "Staged package SHA-256 mismatch" unless Digest::SHA256.file(File.join(input, filename)).hexdigest == sha
    end
    expected
  end

  def fixtures
    FileUtils.mkdir_p("features/support")
    File.write("features/pass.feature", <<~FEATURE)
      Feature: Installed consumer
        Scenario: SDK works in a clean runtime
          Given the packaged SDK and Cucumber are active
          Then native logs and attachments work
    FEATURE
    File.write("features/fail.feature", <<~FEATURE)
      Feature: Native failure exit
        Scenario: SDK does not hide failures
          When the consumer intentionally fails
          Then native logs and attachments work
    FEATURE
    File.write("features/support/steps.rb", <<~'RUBY')
      require "reportportal_cucumber"
      require "/inputs/cucumber12_cleanroom_audit"

      Before { log "CLEANROOM_BEFORE" }
      After { log "CLEANROOM_AFTER" }
      Given("the packaged SDK and Cucumber are active") do
        raise "wrong SDK" unless ReportportalCucumber::VERSION == ENV.fetch("SDK_EXPECTED")
        raise "wrong Cucumber" unless Gem.loaded_specs.fetch("cucumber").version.to_s == ENV.fetch("CUCUMBER_EXPECTED")
        raise "formatter did not initialize" unless ReportportalCucumber.current_runtime
        raise "missing World DSL" unless respond_to?(:rp_log) && respond_to?(:rp_attach)
        raise "base64 broken" unless Base64.strict_decode64(Base64.strict_encode64("cleanroom")) == "cleanroom"
        raise "logger broken" unless ReportportalCucumber.logger.is_a?(Logger)
        rp_log("CLEANROOM_WORLD_LOG")
      end
      Then("native logs and attachments work") do
        log "CLEANROOM_NATIVE_LOG"
        attach("cleanroom payload\n", "text/plain", "cleanroom.txt")
        Automation::CucumberLogger.new(self).info("CLEANROOM_AUTOMATION_LOG", attach: true)
      end
      When("the consumer intentionally fails") { raise "CLEANROOM_INTENTIONAL_FAILURE" }
      AfterAll do
        Cucumber12CleanroomAudit.capture("/evidence/cli-#{ENV.fetch('CLI_CASE')}-audit.json")
      end
    RUBY
    FileUtils.cp_r("features", "/evidence/features")
  end

  def cli(prefix)
    fixtures
    { "pass" => 0, "fail" => 1 }.each do |label, code|
      ENV["CLI_CASE"] = label
      output = run("cli-#{label}", *prefix, "cucumber", "--no-profile", "--require", "features/support",
                   "--format", "progress", "--format", "ReportPortal::Cucumber::Formatter", "--out", "/work/rp-#{label}.out",
                   "--format", "message", "--out", "/evidence/#{label}.ndjson", "features/#{label}.feature", expected: code, timeout: 60)
      audit = JSON.parse(File.read("/evidence/cli-#{label}-audit.json"))
      raise "Actual CLI audit failed" unless audit.fetch("errors").empty?
      messages = File.readlines("/evidence/#{label}.ndjson").map { |line| JSON.parse(line) }
      statuses = messages.filter_map { |message| message.dig("testStepFinished", "testStepResult", "status") }
      if code.zero?
        raise "Missing passed scenario" unless output.include?("1 scenario (1 passed)") && statuses.include?("PASSED")
        attachments = messages.filter_map { |message| message["attachment"] }
        raise "Native log not emitted" unless attachments.any? { |entry| entry["body"] == "CLEANROOM_NATIVE_LOG" }
        attachment = attachments.find { |entry| entry["fileName"] == "cleanroom.txt" }
        raise "Native attachment mismatch" unless attachment && attachment["body"] == "cleanroom payload\n" && attachment["mediaType"] == "text/plain"
      else
        raise "Missing native failure" unless output.include?("CLEANROOM_INTENTIONAL_FAILURE") && statuses.include?("FAILED") && statuses.include?("SKIPPED")
      end
    end
    run("spool-help", *prefix, "reportportal-spool", "--help", timeout: 30)
  end

  def install(mode, sdk, cucumber, sha)
    baseline
    raise "Unknown consumer mode" unless %w[install resolve].include?(mode)
    staged = verify_input_packages!
    if mode == "install" && staged["reportportal-cucumber-ruby-#{sdk}.gem"] != sha
      raise "Candidate input hash differs from requested hash"
    end
    ENV["SDK_EXPECTED"] = sdk
    ENV["CUCUMBER_EXPECTED"] = cucumber
    ENV["SDK_SHA256"] = sha
    toolchain
    public_source = ["--clear-sources", "--source", "https://rubygems.org", "--no-document", "--norc"]
    if mode == "install"
      raise "Unexpected install inputs" unless Dir["/inputs/*.gem"].map { |file| File.basename(file) } == ["reportportal-cucumber-ruby-2.0.0.gem"]
      run("install-cucumber", "gem", "install", "cucumber", "--version", "=#{cucumber}", *public_source, timeout: 360)
      run("install-sdk", "gem", "install", "/inputs/reportportal-cucumber-ruby-#{sdk}.gem", "--conservative", *public_source, timeout: 360)
      prefix = []
    else
      raise "Resolver received packaged gems/cache as consumer inputs" unless Dir["/inputs/*.gem"].empty?
      run("install-bundler", "gem", "install", "bundler", "--version", "=2.6.9", *public_source, timeout: 180)
      File.write("Gemfile", <<~GEMFILE)
        source "https://rubygems.org"
        source "http://candidate-index:8808" do
          gem "reportportal-cucumber-ruby"
        end
        gem "cucumber", "=#{cucumber}"
      GEMFILE
      FileUtils.cp("Gemfile", "/evidence/Gemfile")
      raise "Pre-existing lockfile" if File.exist?("Gemfile.lock")
      ENV["BUNDLE_GEMFILE"] = "/work/Gemfile"
      run("bundle-update", "bundle", "_2.6.9_", "update", timeout: 480)
      FileUtils.cp("Gemfile.lock", "/evidence/Gemfile.lock")
      lock = File.read("Gemfile.lock")
      raise "Path or git source in lock" if lock.match?(/^(?:PATH|GIT)$/)
      raise "Wrong selected SDK" unless lock.include?("reportportal-cucumber-ruby (#{sdk})")
      raise "Wrong selected Cucumber" unless lock.include?("cucumber (#{cucumber})")
      raise "Missing private index source" unless lock.include?("http://candidate-index:8808/")
      run("bundle-info", "bundle", "_2.6.9_", "info", "reportportal-cucumber-ruby")
      run("bundle-list", "bundle", "_2.6.9_", "list")
      prefix = ["bundle", "_2.6.9_", "exec"]
    end
    run("installed-audit", *prefix, "ruby", "/inputs/cucumber12_cleanroom_audit.rb", "/evidence/installed-audit.json", timeout: 60)
    cli(prefix)
    run("gem-list-after", "gem", "list", "--local")
    run("disk-usage", "du", "-sk", "/clean", "/work", "/evidence")
    write_json("/evidence/result.json", status: "PASS", mode: mode, ruby: RUBY_DESCRIPTION, sdk: sdk, cucumber: cucumber,
               sdk_sha256: sha, reporting: "RP_ENABLED=false; no ReportPortal/kind access",
               stdlib: "SDK loaded before any explicit standard-gem bootstrap; successful installed and actual CLI audits",
               scope: mode == "resolve" ? "PRIVATE candidate index, not public SDK publication/selection" : "Exact supplied candidate package + public runtime dependencies")
  rescue StandardError, LoadError => error
    write_json("/evidence/result.json", status: "FAIL", mode: mode, ruby: RUBY_DESCRIPTION, sdk: sdk, cucumber: cucumber,
               error: "#{error.class}: #{error.message}", backtrace: error.backtrace)
    warn "DEFECT/FAILURE: #{error.class}: #{error.message}"
    exit 1
  end

  def registry
    verify_input_packages!
    FileUtils.mkdir_p("/registry/gems")
    Dir["/inputs/*.gem"].each { |file| FileUtils.cp(file, "/registry/gems") }
    raise "Private index needs both packages" unless Dir["/registry/gems/*.gem"].size == 2
    run("generate-index", "gem", "generate_index", "--directory", "/registry", "--norc")
    write_json("/evidence/index-manifest.json", scope: "PRIVATE candidate index, not RubyGems publication",
               files: Dir["/registry/**/*"].select { |file| File.file?(file) }.to_h { |file| [file.delete_prefix('/registry/'), { bytes: File.size(file), sha256: Digest::SHA256.file(file).hexdigest }] },
               packages: Dir["/registry/gems/*.gem"].map do |file|
                 spec = Gem::Package.new(file).spec
                 { name: spec.name, version: spec.version.to_s, required_ruby: spec.required_ruby_version.to_s,
                   runtime_dependencies: spec.runtime_dependencies.map { |dep| { name: dep.name, requirement: dep.requirement.to_s } } }
               end)
    server = TCPServer.new("0.0.0.0", 8808)
    write_json("/evidence/ready.json", port: 8808, ruby: RUBY_DESCRIPTION)
    # A bounded worker pool and request timeout keep the private HTTP fixture small.
    4.times.map do
      Thread.new do
        loop { serve_registry_client(server.accept) }
      end
    end.each(&:join)
  end

  def registry_path(target, root = "/registry")
    relative = URI::DEFAULT_PARSER.unescape(target.split("?", 2).first).delete_prefix("/")
    return if relative.include?("\0")

    path = File.realpath(File.expand_path(relative, root))
    path if path.start_with?(File.realpath(root) + "/") && File.file?(path)
  rescue SystemCallError, ArgumentError
    nil
  end

  def serve_registry_client(socket)
    Timeout.timeout(10) do
      request = socket.gets(8193)
      next unless request
      raise IOError, "Oversized HTTP request" if request.bytesize > 8192

      method, target, = request.split(" ")
      raise IOError, "Invalid HTTP request" unless target
      header_bytes = 0
      while (header = socket.gets(8193)) && header != "\r\n"
        header_bytes += header.bytesize
        raise IOError, "Oversized HTTP headers" if header.bytesize > 8192 || header_bytes > 32_768
      end
      path = registry_path(target)
      ok = %w[GET HEAD].include?(method) && path
      body = ok ? File.binread(path) : "not found\n"
      status = ok ? 200 : 404
      entry = { at: Time.now.utc.iso8601, peer: socket.peeraddr[3], method: method, target: target,
                status: status, bytes: body.bytesize, sha256: ok ? Digest::SHA256.hexdigest(body) : nil }
      File.open("/evidence/requests.jsonl", "a") { |file| file.puts(JSON.generate(entry)) }
      socket.write("HTTP/1.1 #{status} #{ok ? 'OK' : 'Not Found'}\r\nContent-Type: application/octet-stream\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n")
      socket.write(body) unless method == "HEAD"
    end
  rescue IOError, SystemCallError, Timeout::Error => error
    warn "registry: #{error.class}: #{error.message}"
  ensure
    socket.close
  end
end

if $PROGRAM_NAME == __FILE__
  mode, *arguments = ARGV
  if mode == "registry"
    Cucumber12CleanroomPayload.registry
  else
    Cucumber12CleanroomPayload.install(mode, *arguments)
  end
end
