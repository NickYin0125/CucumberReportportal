# frozen_string_literal: true

require "rubygems/request_set"

module LedgerDeveloper
  module Activation
    class Error < StandardError; end

    class << self
      attr_reader :provenance

      def activate!
        path = File.join(ENV.fetch("LEDGER_SDK_ROOT"), "reportportal-cucumber-ruby.gemspec")
        spec = Gem::Specification.load(path)
        raise Error, "Cannot load selected SDK gemspec: #{path}" unless spec && spec.name == "reportportal-cucumber-ruby"
        check_runtime!(spec)
        cucumber = Gem::Version.new(ENV.fetch("LEDGER_CUCUMBER"))
        requirement = spec.runtime_dependencies.find { |dependency| dependency.name == "cucumber" }
        unless requirement && requirement.requirement.satisfied_by?(cucumber)
          raise Error, "Selected SDK requires #{requirement}; requested cucumber #{cucumber}"
        end

        # Resolve all constraints together: activating Cucumber first can select
        # expressions 19 before the legacy SDK's <19 constraint is registered.
        request = Gem::RequestSet.new
        request.remote = false
        spec.runtime_dependencies.each { |dependency| request.gem(dependency.name, *dependency.requirement.as_list) }
        request.gem("cucumber", "= #{cucumber}")
        Gem.loaded_specs.each_value { |loaded| request.gem(loaded.name, "= #{loaded.version}") }
        request.resolve_current
        resolved = request.sorted_requests.map(&:full_spec)
        resolved.each { |dependency| check_runtime!(dependency) }
        resolved.each(&:activate)

        require "json"
        require "digest"
        @provenance = {
          "sdk_gemspec" => File.realpath(path), "sdk_gemspec_sha256" => Digest::SHA256.file(path).hexdigest,
          "sdk" => spec.version.to_s, "ruby" => RUBY_VERSION,
          "required_ruby" => spec.required_ruby_version.to_s,
          "requirements" => spec.runtime_dependencies.to_h { |dependency| [dependency.name, dependency.requirement.to_s] },
          "cucumber" => Gem.loaded_specs.fetch("cucumber").version.to_s,
          "cucumber_expressions" => Gem.loaded_specs.fetch("cucumber-cucumber-expressions").version.to_s,
          "gems" => resolved.sort_by(&:name).to_h do |dependency|
            loaded = Gem.loaded_specs.fetch(dependency.name)
            [loaded.name, { "version" => loaded.version.to_s, "path" => loaded.full_gem_path }]
          end
        }
        if (report = ENV["LEDGER_ACTIVATION_REPORT"])
          text = JSON.pretty_generate(@provenance) + "\n"
          secret = ENV["RP_API_KEY"].to_s
          raise Error, "Credential found in activation evidence; refusing write" if !secret.empty? && text.include?(secret)
          File.write(report, text, mode: "w", perm: 0o600)
        end
        if (expected = ENV["LEDGER_EXPECTED_ACTIVATION"])
          unless JSON.parse(File.read(expected)) == @provenance
            raise Error, "Child dependency activation differs from successful probe; refusing Cucumber execution"
          end
        end
        @provenance
      end

      def check_runtime!(spec)
        return if spec.required_ruby_version.satisfied_by?(Gem.ruby_version) &&
                  spec.required_rubygems_version.satisfied_by?(Gem.rubygems_version)

        raise Error, "#{spec.full_name} requires Ruby #{spec.required_ruby_version} / RubyGems #{spec.required_rubygems_version}; " \
                     "running Ruby #{Gem.ruby_version} / RubyGems #{Gem.rubygems_version}"
      end
    end
  end
end
