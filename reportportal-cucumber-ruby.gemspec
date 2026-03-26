# frozen_string_literal: true

require_relative "lib/reportportal_cucumber/version"

Gem::Specification.new do |spec|
  spec.name = "reportportal-cucumber-ruby"
  spec.version = ReportportalCucumber::VERSION
  spec.authors = ["Codex"]
  spec.email = ["codex@example.com"]

  spec.summary = "Real-time ReportPortal client and Cucumber formatter for Ruby"
  spec.description = "Streams Ruby Cucumber execution events to ReportPortal launches, items, and logs in real time."
  spec.homepage = "https://example.com/reportportal-cucumber-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/README.md"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      ".github/workflows/*",
      "LICENSE",
      "README.md",
      "examples/**/*",
      "features/**/*",
      "lib/**/*",
      "spec/**/*",
      "Gemfile",
      "Rakefile"
    ]
  end

  spec.bindir = "exe"
  spec.require_paths = ["lib"]

  spec.add_dependency "cucumber", ">= 9.0", "< 11.0"

  spec.add_development_dependency "bundler", ">= 2.6"
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "rspec", ">= 3.13"
  spec.add_development_dependency "webmock", ">= 3.23"
end
