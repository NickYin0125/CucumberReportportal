# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "rbconfig"

module QA1xPreflight
  BUNDLER_VERSION = "2.6.6"
  TOOLS = {
    "ruby" => ["ruby", "--version"],
    "bundle" => ["bundle", "_#{BUNDLER_VERSION}_", "--version"],
    "git" => ["git", "--version"],
    "jq" => ["jq", "--version"],
    "helm" => ["helm", "version", "--short"],
    "docker" => ["docker", "--version"],
    "docker-compose" => ["docker-compose", "version", "--short"]
  }.freeze

  def self.capture(*argv, **options)
    stdout, stderr, status = Open3.capture3(*argv, **options)
    raise "Preflight command failed: #{argv.inspect}: #{stderr.strip}" unless status.success?

    stdout.strip
  end

  def self.executable(name)
    path = ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { |part| File.join(part, name) }.find { |part| File.file?(part) && File.executable?(part) }
    raise "Preflight missing executable: #{name}" unless path

    File.realpath(path)
  end

  def self.tools(expected_ruby:)
    raise "Preflight requires Linux ARM64" unless RUBY_PLATFORM.include?("linux") && RbConfig::CONFIG.fetch("host_cpu") == "aarch64"
    raise "Wrong Ruby series" unless RUBY_VERSION.start_with?(expected_ruby + ".")
    tools = TOOLS.to_h do |name, argv|
      path = executable(argv.first)
      [name, { path: path, version: capture(*argv), sha256: Digest::SHA256.file(path).hexdigest }]
    end
    raise "Wrong Bundler executable" unless tools.fetch("bundle").fetch(:version) == "Bundler version #{BUNDLER_VERSION}"
    manifest = JSON.parse(File.read("/tools/manifest.json"))
    %w[helm docker docker-compose].each do |name|
      raise "Pinned #{name} bytes changed" unless tools.fetch(name).fetch(:sha256) == manifest.fetch(name).fetch("sha256")
    end
    jq_path = tools.fetch("jq").fetch(:path)
    raise "jq must be a real Linux ELF binary" unless File.binread(jq_path, 4) == "\x7fELF".b
    linkage = capture("ldd", jq_path)
    raise "jq has an unresolved shared library" if linkage.include?("not found")
    libraries = linkage.scan(%r{/[\w+./-]+}).uniq.to_h do |path|
      raise "Missing jq shared library: #{path}" unless File.file?(path)

      resolved = File.realpath(path)
      [path, { resolved: resolved, sha256: Digest::SHA256.file(resolved).hexdigest }]
    end
    filter = '.release.tag == "v1.3.3" and ([.rows[] | select(.passed)] | length == 2)'
    probe = capture(jq_path, "-er", filter, stdin_data: JSON.generate(release: { tag: "v1.3.3" }, rows: [{ passed: true }, { passed: false }, { passed: true }]))
    raise "jq semantic probe failed" unless probe == "true"
    { status: "PASS", ruby: RUBY_DESCRIPTION, platform: RUBY_PLATFORM,
      os_release: File.read("/etc/os-release"), tools: tools, pinned_tools: manifest,
      jq_linkage: linkage, jq_libraries: libraries, jq_filter_probe: probe,
      jq_packages: capture("dpkg-query", "-W", "-f=${Package}=${Version}\n", "jq", "libjq1", "libonig5") }
  end

  def self.sdk(source:, runtime:, expected_version:, cucumber:)
    specification = Gem::Specification.load(File.join(source, "reportportal-cucumber-ruby.gemspec"))
    raise "Cannot load source SDK gemspec" unless specification
    expected_ruby = Gem::Requirement.new(">= 3.1")
    expected_cucumber = Gem::Requirement.new(">= 9.0", "< 11.0")
    expected_expressions = Gem::Requirement.new(">= 17.0", "< 19.0")
    dependencies = specification.dependencies.to_h { |dependency| [dependency.name, dependency.requirement] }
    raise "Source SDK Ruby bounds changed" unless specification.required_ruby_version == expected_ruby
    raise "Source SDK Cucumber bounds changed" unless dependencies.fetch("cucumber") == expected_cucumber
    raise "Source SDK expressions bounds changed" unless dependencies.fetch("cucumber-cucumber-expressions") == expected_expressions
    raise "Source SDK version mismatch" unless specification.version.to_s == expected_version && runtime.fetch("sdk") == expected_version
    raise "Activated SDK is not the isolated source" unless File.realpath(runtime.fetch("sdk_root")) == File.realpath(source)
    gems = runtime.fetch("gems")
    raise "Activated Cucumber differs" unless gems.fetch("cucumber") == cucumber && expected_cucumber.satisfied_by?(Gem::Version.new(cucumber))
    raise "Activated expressions outside 1.x bounds" unless expected_expressions.satisfied_by?(Gem::Version.new(gems.fetch("cucumber-cucumber-expressions")))
    raise "Activated diff-lcs is incompatible" unless Gem::Version.new(gems.fetch("diff-lcs")) < Gem::Version.new("2")
    raise "Activated Bundler differs" unless gems.fetch("bundler") == BUNDLER_VERSION
    { status: "PASS", sdk_version: specification.version.to_s, sdk_root: runtime.fetch("sdk_root"),
      required_ruby: specification.required_ruby_version.to_s,
      cucumber_requirement: dependencies.fetch("cucumber").to_s,
      expressions_requirement: dependencies.fetch("cucumber-cucumber-expressions").to_s,
      activated_cucumber: cucumber, activated_expressions: gems.fetch("cucumber-cucumber-expressions"),
      activated_diff_lcs: gems.fetch("diff-lcs"), activated_bundler: gems.fetch("bundler") }
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    result = QA1xPreflight.tools(expected_ruby: ENV.fetch("QA_RUBY"))
  rescue StandardError => error
    result = { status: "FAIL", error: "#{error.class}: #{error.message}" }
  end
  File.write(ENV.fetch("QA_PREFLIGHT_OUT"), JSON.pretty_generate(result) + "\n")
  puts JSON.generate(result)
  exit(result.fetch(:status) == "PASS" ? 0 : 1)
end
