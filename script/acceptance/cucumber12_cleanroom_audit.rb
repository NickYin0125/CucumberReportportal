# frozen_string_literal: true

require "json"
require "digest"
require "rubygems/package"

module Cucumber12CleanroomAudit
  COMMON_ENTRYPOINTS = %w[
    lib/reportportal_cucumber.rb
    lib/reportportal_cucumber/version.rb
    lib/reportportal_cucumber/cucumber/formatter.rb
    lib/reportportal_cucumber/cucumber/world.rb
    exe/reportportal-spool
  ].freeze
  REQUIRED_ENTRYPOINTS = (COMMON_ENTRYPOINTS + ["lib/reportportal_cucumber/cucumber/parallel_formatter.rb"]).freeze

  module_function

  def required_entrypoints(version:)
    version.to_s == "1.3.1" ? COMMON_ENTRYPOINTS : REQUIRED_ENTRYPOINTS
  end

  def entrypoint_checks(root, declared_files:, version: "2.0.0")
    installed_root = File.realpath(root) + "/"
    required_entrypoints(version: version).to_h do |relative|
      path = File.join(root, relative)
      present = File.file?(path)
      inside = present && File.realpath(path).start_with?(installed_root)
      [relative, { declared: declared_files.include?(relative), regular_file: present, within_gem: !!inside,
                   sha256: inside ? Digest::SHA256.file(path).hexdigest : nil }]
    end
  end

  def specification(spec)
    { name: spec.name, version: spec.version.to_s, platform: spec.platform.to_s, default: spec.default_gem?,
      root: spec.full_gem_path, loaded_from: spec.loaded_from, required_ruby: spec.required_ruby_version.to_s,
      dependencies: spec.dependencies.map { |dep| { name: dep.name, type: dep.type, requirement: dep.requirement.to_s } } }
  end

  def capture(path)
    sdk = Gem.loaded_specs.fetch("reportportal-cucumber-ruby")
    cucumber = Gem.loaded_specs.fetch("cucumber")
    errors = []
    errors << "SDK version mismatch" unless sdk.version.to_s == ENV.fetch("SDK_EXPECTED")
    errors << "Cucumber version mismatch" unless cucumber.version.to_s == ENV.fetch("CUCUMBER_EXPECTED")
    sdk_files = $LOADED_FEATURES.grep(%r{/reportportal(?:_cucumber)?/|/reportportal_cucumber\.rb\z})
    installed_root = File.realpath(sdk.full_gem_path) + "/"
    errors << "SDK loaded from outside the installed gem" unless !sdk_files.empty? && sdk_files.all? { |file| File.realpath(file).start_with?(installed_root) }
    errors << "SDK is not in a private GEM_HOME" unless sdk.full_gem_path.start_with?("/clean/gems/")
    dependencies = Gem.loaded_specs.values.flat_map do |spec|
      spec.runtime_dependencies.map do |dep|
        selected = Gem.loaded_specs[dep.name]
        valid = selected && dep.matches_spec?(selected)
        errors << "Unsatisfied activated dependency: #{spec.name} -> #{dep}" unless valid
        { parent: spec.full_name, dependency: dep.name, requirement: dep.requirement.to_s,
          selected: selected&.version&.to_s, satisfied: !!valid }
      end
    end
    installed = Gem::Specification.to_a
    # Bundler's visible specification set is restricted to its bundle; inspect disk too.
    installed_private = Dir["/clean/gems/specifications/*.gemspec"].map { |file| Gem::Specification.load(file) }
    closure = {}
    visit = lambda do |spec|
      return if closure.key?(spec.name)

      closure[spec.name] = spec
      spec.runtime_dependencies.each do |dep|
        child = (installed_private + installed).find { |candidate| dep.matches_spec?(candidate) }
        if child
          visit.call(child)
        else
          errors << "Uninstalled runtime dependency: #{spec.name} -> #{dep}"
        end
      end
    end
    visit.call(sdk)
    installed_private.each do |spec|
      errors << "Non-runtime gem installed: #{spec.full_name}" unless closure.key?(spec.name) || spec.name == "bundler"
    end
    cache_hash = File.file?(sdk.cache_file) ? Digest::SHA256.file(sdk.cache_file).hexdigest : nil
    errors << "Installed SDK cache differs from supplied package" unless cache_hash == ENV.fetch("SDK_SHA256")
    package = Gem::Package.new(sdk.cache_file)
    expected_root = "/clean/expected-sdk-#{sdk.version}"
    package.extract_files(expected_root) unless File.directory?(expected_root)
    payload_hashes = package.spec.files.to_h do |relative|
      expected = File.join(expected_root, relative)
      actual = File.join(sdk.full_gem_path, relative)
      wanted = File.file?(expected) ? Digest::SHA256.file(expected).hexdigest : nil
      found = File.file?(actual) ? Digest::SHA256.file(actual).hexdigest : nil
      errors << "Installed payload differs: #{relative}" unless wanted && wanted == found
      [relative, { packaged: wanted, installed: found }]
    end
    entrypoints = entrypoint_checks(sdk.full_gem_path, declared_files: package.spec.files, version: sdk.version.to_s)
    entrypoints.each do |relative, check|
      unless check.values_at(:declared, :regular_file, :within_gem).all? &&
             check[:sha256] && check[:sha256] == payload_hashes.dig(relative, :packaged)
        errors << "Required installed entrypoint missing, outside gem, undeclared or altered: #{relative}"
      end
    end
    unless sdk.runtime_dependencies.map(&:to_s).sort == package.spec.runtime_dependencies.map(&:to_s).sort
      errors << "Installed gemspec runtime dependencies differ from package"
    end
    if sdk.version.to_s == "2.0.0"
      %w[base64 logger cgi].each do |name|
        errors << "Missing direct standard-gem dependency: #{name}" unless sdk.runtime_dependencies.any? { |dep| dep.name == name }
      end
    end
    standard = %w[base64 logger mutex_m].to_h do |name|
      loaded = Gem.loaded_specs[name]
      [name, { installed: installed.select { |spec| spec.name == name }.map { |spec| specification(spec) },
               activated: loaded && specification(loaded),
               loaded_features: $LOADED_FEATURES.grep(%r{/#{name}(?:/|\.rb\z)}) }]
    end
    data = { ruby: RUBY_DESCRIPTION, ruby_version: RUBY_VERSION, ruby_platform: RUBY_PLATFORM,
             rubygems: Gem::VERSION, bundler: Gem.loaded_specs["bundler"]&.version&.to_s,
             sdk: specification(sdk), cucumber: specification(cucumber), sdk_archive_sha256: cache_hash,
             gem_home: Gem.dir, gem_paths: Gem.path, working_directory: Dir.pwd,
             environment: ENV.to_h.select { |key, _| key.match?(/\A(?:GEM_|BUNDLE|RUBY|HOME\z|RP_)/) },
             load_path: $LOAD_PATH, loaded_features: $LOADED_FEATURES.dup, sdk_loaded_files: sdk_files,
             standard_gems: standard, activated_gems: Gem.loaded_specs.values.map { |spec| specification(spec) },
             installed_private_gems: installed_private.map { |spec| specification(spec) },
             runtime_closure: closure.keys.sort, dependency_checks: dependencies, payload_sha256: payload_hashes,
             entrypoint_checks: entrypoints,
             installed_gemspec: File.read(sdk.loaded_from), errors: errors }
    File.write(path, JSON.pretty_generate(data) + "\n")
    raise errors.join("; ") unless errors.empty?

    data
  end
end

if $PROGRAM_NAME == __FILE__
  # Do not pre-require base64, logger or mutex_m: missing dependencies must surface naturally.
  require "reportportal_cucumber"
  require "cucumber"
  Cucumber12CleanroomAudit.capture(ARGV.fetch(0))
end
