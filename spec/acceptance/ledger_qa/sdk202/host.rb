# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "fileutils"
require "base64"

module Ledger202Host
  ROOT = File.expand_path("../../../..", __dir__)
  FINAL = "9bf3356cff350d8e2ba11bad1c33aa89881ac456"
  BASE = "3f20313c20b25071fbc49b31e1c6bc772bd599e4"
  STAMP = "QA202-9bf3356-20261102"
  OUTPUT = File.join(ROOT, "docs/reviews/assets", STAMP)
  SOURCE = "/private/tmp/ledger-qa202-9bf3356"
  DEPENDENCIES = "/private/tmp/ledger-matrix-bundles/ruby34"
  VOLUME = "ledger-qa202-9bf3356-dependencies"
  IMAGE = "sha256:316dd4f6b6de632d5ade7bdb78fc33f7e82db8a87785e93a8a2c8d81706d3fe7"
  FIXTURES = "F01,F04,F10,F11,F12,F13,F14,F15-negative,F16a,F16b,F16d,F16e,F16f,F17,F19,F20"

  def self.read_command(*args)
    out, _, status = Open3.capture3(*args)
    raise "Read command failed: #{args.first}" unless status.success?
    out.strip
  end

  def self.write_new(path, value)
    FileUtils.mkdir_p(File.dirname(path))
    text = JSON.pretty_generate(value) + "\n"
    key = ENV["RP_API_KEY"].to_s
    raise "Credential in evidence" if !key.empty? && text.include?(key)
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(text) }
  end

  def self.verify_source(role)
    sha = role == "baseline" ? BASE : FINAL
    dir = File.join(SOURCE, role)
    entries = read_command("git", "-C", ROOT, "ls-tree", "-r", sha, "--", "lib", "reportportal-cucumber-ruby.gemspec").lines.map do |line|
      info, path = line.chomp.split("\t", 2)
      blob = info.split.last
      data = File.binread(File.join(dir, path))
      raise "Source bytes differ from final Git blob" unless Digest::SHA1.hexdigest("blob #{data.bytesize}\0".b + data) == blob
      { path: path, git_blob: blob, sha256: Digest::SHA256.hexdigest(data) }
    end
    { role: role, source_sha: sha, files: entries, manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(entries)) }
  end

  def self.setup
    raise "Wrong branch" unless read_command("git", "-C", ROOT, "branch", "--show-current") == "qa/presentation-ledger-2.0.2"
    raise "Preparation destination exists" if File.exist?(File.join(OUTPUT, "environment.json")) || File.exist?(SOURCE)
    %w[baseline candidate].each do |role|
      dir = File.join(SOURCE, role)
      FileUtils.mkdir_p(dir)
      archive, _, status = Open3.capture3("git", "-C", ROOT, "archive", role == "baseline" ? BASE : FINAL, "lib", "reportportal-cucumber-ruby.gemspec")
      raise "Git archive failed" unless status.success?
      _, _, unpack = Open3.capture3("tar", "-xf", "-", "-C", dir, stdin_data: archive)
      raise "Source staging failed" unless unpack.success?
      write_new(File.join(OUTPUT, "#{role}-source.json"), verify_source(role))
    end
    # Only public dependency files are staged; no credential environment enters this child.
    existing = system("docker", "volume", "inspect", VOLUME, out: File::NULL, err: File::NULL)
    raise "Unexpected existing dependency volume" if existing
    raise "Volume creation failed" unless system("docker", "volume", "create", VOLUME, out: File::NULL)
    copy = <<~'RUBY'
      require "fileutils"; require "digest"; require "json"
      FileUtils.cp_r(Dir.children("/seed").map { |n| "/seed/#{n}" }, "/bundle")
      manifest = ->(root) { Dir.glob(root + "/**/*", File::FNM_DOTMATCH).sort.filter_map { |p| next if File.directory?(p); [p.delete_prefix(root + "/"), Digest::SHA256.file(p).hexdigest] } }
      a, b = manifest.call("/seed"), manifest.call("/bundle")
      abort "Dependency copy mismatch" unless a == b
      puts JSON.generate(files: b.length, manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(b)), ruby: RUBY_DESCRIPTION)
    RUBY
    out, _, status = Open3.capture3("docker", "run", "--rm", "--network", "none", "--cpus", "1", "-v", "#{DEPENDENCIES}:/seed:ro", "-v", "#{VOLUME}:/bundle", IMAGE, "ruby", "-e", copy)
    raise "Dependency staging failed" unless status.success?
    dep = JSON.parse(out)
    jpeg = File.binread("/Users/nick/Documents/crr-2.0.1/script/acceptance/presentation_ledger_developer/evidence/baseline2-all/media/jpeg.jpg")
    raise "JPEG bytes differ" unless Digest::SHA256.hexdigest(jpeg) == "8c472e5064d09cd6d7f8aca0ce5da74e4ff29073ac5f8f45ae96093f46bed1a9"
    File.binwrite(File.join(SOURCE, "jpeg.jpg"), jpeg)
    image = JSON.parse(read_command("docker", "image", "inspect", IMAGE)).first
    write_new(File.join(OUTPUT, "environment.json"), source_sha: FINAL, baseline_sha: BASE, image_id: image.fetch("Id"),
      architecture: image.fetch("Architecture"), os: image.fetch("Os"), dependencies: dep, dependency_volume: VOLUME,
      cpu_limit: "1", memory_limit: "2g", performance_authorized: false, native_png_scope: "WP2 RP-only screenshot; original failure records unchanged")
    puts JSON.generate(status: "IMMUTABLE_INPUTS_PREPARED", image_id: image.fetch("Id"), dependency_files: dep["files"], performance: "HOLD")
  end

  def self.run(role, mode, kind, label, fixtures = nil, baseline_label = nil)
    raise "Unsupported selection" unless %w[baseline candidate].include?(role) && %w[plain rich default].include?(mode) &&
      %w[standard frozen framework supplement contract].include?(kind) && label.match?(/\A[A-Za-z0-9_-]+\z/)
    raise "Missing child credential" if ENV["RP_API_KEY"].to_s.empty?
    verify_source(role)
    proof = JSON.parse(File.read(File.join(OUTPUT, "environment.json")))
    raise "Image mismatch" unless proof.fetch("image_id") == IMAGE
    path = File.join(OUTPUT, label)
    raise "Never overwrite an execution" if File.exist?(path) || File.exist?(path + "-process.json")
    args = ["docker", "run", "--rm", "--cpus", "1", "--memory", "2g", "--add-host", "rp-2607.localhost:host-gateway",
      "-v", "#{ROOT}:#{ROOT}", "-v", "#{SOURCE}/#{role}:/qa202-sdk:ro", "-v", "#{SOURCE}/jpeg.jpg:/qa202-jpeg.jpg:ro",
      "-v", "#{VOLUME}:/bundle:ro", "-w", ROOT, "-e", "RP_API_KEY", "-e", "RP_ENDPOINT=http://rp-2607.localhost:18080",
      "-e", "RP_PROJECT=superadmin_personal", "-e", "QA202_SOURCE_SHA=#{role == 'baseline' ? BASE : FINAL}"]
    args.concat(["-e", "QA202_BASELINE_CAPTURE=#{File.join(OUTPUT, baseline_label)}"]) if baseline_label
    args.concat([IMAGE, "ruby", File.join(__dir__, "live.rb"), kind, "--transport", "live", "--mode", mode,
      "--sdk-root", "/qa202-sdk", "--cucumber", "12.0.1", "--gem-path", "/bundle/ruby/3.4.0", "--jpeg", "/qa202-jpeg.jpg",
      "--fixtures", fixtures || FIXTURES, "--output", path])
    stdout, stderr, status = Open3.capture3(*args)
    write_new(path + "-process.json", command: args, exit: status.exitstatus, stdout: stdout, stderr: stderr, performance_timing: "NOT_COLLECTED")
    puts stdout
    verify_source(role)
    abort "STOP: retained execution requires inspection" unless status.success?
  end
end

if $PROGRAM_NAME == __FILE__
  command = ARGV.shift
  if command == "setup"
    Ledger202Host.setup
  elsif command == "run"
    Ledger202Host.run(*ARGV)
  else
    abort "Use setup or run ROLE MODE KIND NEW_LABEL [FIXTURES] [BASELINE_LABEL]; no performance mode exists"
  end
end
