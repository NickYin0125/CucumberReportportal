# frozen_string_literal: true

require_relative "lib/reportportal_cucumber/version"

Gem::Specification.new do |spec|
  spec.name = "reportportal-cucumber-ruby"
  spec.version = ReportportalCucumber::VERSION
  spec.authors = ["Codex"]

  spec.summary = "Real-time ReportPortal client and Cucumber formatter for Ruby"
  spec.description = "Streams Ruby Cucumber execution events to ReportPortal launches, items, and logs in real time."
  spec.homepage = "https://github.com/NickYin0125/CucumberReportportal"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "LICENSE",
      "README.md",
      "CHANGELOG.md",
      "docs/*.md",
      "docs/design/*.md",
      "docs/reviews/assets/*.png",
      "deploy/compose/*.md",
      "helm/reportportal-rich-experience/*.md",
      "examples/**/*",
      "exe/**/*",
      "lib/**/*"
    ].select do |path|
      # Repository QA harnesses require features/specs and development dependencies.
      File.file?(path) && !path.match?(%r{\Aexamples/day2_(?:endurance|faults)/})
    end.sort
  end

  spec.bindir = "exe"
  spec.executables = Dir["exe/*"].map { |path| File.basename(path) }
  spec.require_paths = ["lib"]

  spec.add_dependency "cucumber", "~> 12.0", ">= 12.0.1"
  # Declare directly used standard gems instead of relying on another gem's dependencies.
  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "cgi", "~> 0.4"
  spec.add_dependency "logger", "~> 1.6"
  spec.add_dependency "aws-sdk-s3", ">= 1.180"
  spec.add_dependency "mime-types", ">= 3.5"

  spec.add_development_dependency "bundler", ">= 2.6"
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "parallel_tests", ">= 4.0"
  spec.add_development_dependency "puma", ">= 6.0"
  spec.add_development_dependency "rackup", ">= 2.2"
  spec.add_development_dependency "rantly", ">= 2.0"
  spec.add_development_dependency "sinatra", ">= 4.1"
  spec.add_development_dependency "rspec", ">= 3.13"
  spec.add_development_dependency "webmock", ">= 3.23"
end
