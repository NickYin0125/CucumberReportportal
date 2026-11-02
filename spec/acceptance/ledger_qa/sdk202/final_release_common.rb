# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "fileutils"
require "rbconfig"
require "timeout"
require "time"

module FinalRelease202
  SHA = "8f44c10533eb4d0a8eae1adcc2ed5b63ace155c7"
  QA = File.expand_path("../../../..", __dir__)
  SDK = "/Users/nick/Documents/crr-2.0.2"
  TRIAL = "/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2"
  OUT = File.join(QA, "docs/reviews/assets/QA202-final-release-20261102-contract")
  SOURCE = File.join(OUT, "source")
  GEMHOME = File.join(OUT, "installed")
  ENDPOINT = "http://rp-2607.localhost:18080"
  PROJECT = "superadmin_personal"

  def self.write(path, value)
    path = File.expand_path(path)
    raise "Outside owned evidence" unless path.start_with?(OUT + "/")
    data = JSON.pretty_generate(value) + "\n"
    key = ENV["RP_API_KEY"].to_s
    raise "Credential rejected" if !key.empty? && data.include?(key)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(data) }
  end

  def self.command(*args, chdir: QA, env: {}, seconds: 180)
    output = errors = status = nil
    Open3.popen3(env, *args, chdir: chdir, pgroup: true) do |input, stdout, stderr, child|
      input.close
      readers = [Thread.new { stdout.read }, Thread.new { stderr.read }]
      begin
        Timeout.timeout(seconds) { status = child.value }
      rescue Timeout::Error
        Process.kill("KILL", -child.pid)
        status = child.value
      ensure
        output, errors = readers.map(&:value)
      end
    end
    key = ENV["RP_API_KEY"].to_s
    raise "Credential output rejected" if !key.empty? && [output, errors].any? { |s| s.include?(key) }
    { command: args, exit: status.exitstatus, signal: status.termsig, stdout: output, stderr: errors }
  end

  def self.git(*args)
    r = command("git", "-C", SDK, *args)
    raise "Git read failed" unless r[:exit] == 0
    r[:stdout].strip
  end

  def self.verify
    raise "SDK head moved" unless git("rev-parse", "HEAD") == SHA
    raise "SDK no longer clean" unless git("status", "--porcelain").empty?
    files = git("ls-tree", "-r", SHA, "--", "lib", "examples/current_sdk", "reportportal-cucumber-ruby.gemspec").lines.map do |line|
      info, path = line.chomp.split("\t", 2)
      bytes = File.binread(File.join(SDK, path))
      raise "SDK bytes moved" unless Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0".b + bytes) == info.split.last
      { path: path, blob: info.split.last, sha256: Digest::SHA256.hexdigest(bytes) }
    end
    { sha: SHA, files: files, manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(files)) }
  end

  def self.authenticate
    raise "Wrong endpoint" if ENV["RP_ENDPOINT"] && ENV["RP_ENDPOINT"] != ENDPOINT
    raise "Wrong project" if ENV["RP_PROJECT"] && ENV["RP_PROJECT"] != PROJECT
    ENV["RP_ENDPOINT"], ENV["RP_PROJECT"] = ENDPOINT, PROJECT
    return unless ENV["RP_API_KEY"].to_s.empty?
    ENV["C12_CREDENTIAL_FILE"] = "/private/tmp/reportportal-2607-mYdyRWqN/credentials.json"
    require "/Users/nick/Documents/crr-2.0.1/script/acceptance/cucumber12_live_support"
    ENV["RP_API_KEY"] = Cucumber12Live.token
    ENV.delete("C12_CREDENTIAL_FILE")
  end

  def self.prepare
    resume_export = ARGV == ["--resume-export"]
    raise "Existing evidence destination" if File.exist?(OUT) && !resume_export
    raise "Cannot resume completed preparation" if File.exist?(File.join(OUT, "source-provenance.json"))
    proof = verify
    FileUtils.mkdir_p(SOURCE)
    # Export only package inputs, never another reviewer's verdict documents.
    spec = Gem::Specification.load(File.join(SDK, "reportportal-cucumber-ruby.gemspec"))
    paths = (spec.files + %w[reportportal-cucumber-ruby.gemspec Gemfile Gemfile.lock]).uniq
    unless resume_export
      archive, _, status = Open3.capture3("git", "-C", SDK, "archive", SHA, *paths)
      raise "Source export failed" unless status.success?
      _, _, status = Open3.capture3("tar", "-xf", "-", "-C", SOURCE, stdin_data: archive)
      raise "Source unpack failed" unless status.success?
    end
    paths.each { |p| raise "Export mismatch" unless File.binread(File.join(SOURCE, p)) == File.binread(File.join(SDK, p)) }
    old = command("git", "status", "--porcelain", "--untracked-files=all")
    preserved = old[:stdout].lines.filter_map do |line|
      path = line[3..].strip
      full = File.join(QA, path)
      next if full.start_with?(OUT + "/") || File.directory?(full) || !File.file?(full)
      { path: path, sha256: Digest::SHA256.file(full).hexdigest }
    end
    write(File.join(OUT, "preexisting-files.json"), preserved)
    write(File.join(OUT, "source-provenance.json"), proof.merge(export_paths: paths, ruby: RUBY_DESCRIPTION,
      normative: %w[presentation-ledger-acceptance.md presentation-ledger-owner-decisions.md].map { |n| { path: n, sha256: Digest::SHA256.file(File.join(SDK, "docs/design", n)).hexdigest } },
      performance: "NOT_RUN", browser_operation: "NOT_PERFORMED", resumed_export_after_system_ruby_26: resume_export))
    build = command(RbConfig.ruby, "-S", "gem", "build", "--quiet", "reportportal-cucumber-ruby.gemspec", chdir: SOURCE)
    write(File.join(OUT, "gem-build.json"), build)
    raise "Gem build failed" unless build[:exit] == 0
    package = File.join(SOURCE, "reportportal-cucumber-ruby-2.0.2.gem")
    install = command(RbConfig.ruby, "-S", "gem", "install", "--local", "--ignore-dependencies", "--no-document", "--install-dir", GEMHOME, package)
    write(File.join(OUT, "gem-install.json"), install.merge(package_sha256: Digest::SHA256.file(package).hexdigest))
    raise "Isolated install failed" unless install[:exit] == 0
    root = File.join(GEMHOME, "gems/reportportal-cucumber-ruby-2.0.2")
    proof[:files].select { |r| r[:path].start_with?("lib/") }.each do |r|
      raise "Installed library mismatch" unless Digest::SHA256.file(File.join(root, r[:path])).hexdigest == r[:sha256]
    end
    puts JSON.generate(status: "READY", source_sha: SHA, installed_gem: root, package_sha256: Digest::SHA256.file(package).hexdigest)
  end
end

FinalRelease202.prepare if $PROGRAM_NAME == __FILE__
