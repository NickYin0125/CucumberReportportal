# -*- encoding: utf-8 -*-
# stub: reportportal-cucumber-ruby 2.0.2 ruby lib

Gem::Specification.new do |s|
  s.name = "reportportal-cucumber-ruby".freeze
  s.version = "2.0.2".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/NickYin0125/CucumberReportportal/blob/main/CHANGELOG.md", "homepage_uri" => "https://github.com/NickYin0125/CucumberReportportal", "source_code_uri" => "https://github.com/NickYin0125/CucumberReportportal" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Codex".freeze]
  s.bindir = "exe".freeze
  s.date = "2026-11-02"
  s.description = "Streams Ruby Cucumber execution events to ReportPortal launches, items, and logs in real time.".freeze
  s.executables = ["reportportal-spool".freeze]
  s.files = ["exe/reportportal-spool".freeze]
  s.homepage = "https://github.com/NickYin0125/CucumberReportportal".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.3".freeze)
  s.rubygems_version = "3.6.3".freeze
  s.summary = "Real-time ReportPortal client and Cucumber formatter for Ruby".freeze

  s.installed_by_version = "3.6.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<cucumber>.freeze, ["~> 12.0".freeze, ">= 12.0.1".freeze])
  s.add_runtime_dependency(%q<base64>.freeze, ["~> 0.2".freeze])
  s.add_runtime_dependency(%q<cgi>.freeze, ["~> 0.4".freeze])
  s.add_runtime_dependency(%q<logger>.freeze, ["~> 1.6".freeze])
  s.add_runtime_dependency(%q<aws-sdk-s3>.freeze, [">= 1.180".freeze])
  s.add_runtime_dependency(%q<mime-types>.freeze, [">= 3.5".freeze])
  s.add_development_dependency(%q<bundler>.freeze, [">= 2.6".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 13.0".freeze])
  s.add_development_dependency(%q<parallel_tests>.freeze, [">= 4.0".freeze])
  s.add_development_dependency(%q<puma>.freeze, [">= 6.0".freeze])
  s.add_development_dependency(%q<rackup>.freeze, [">= 2.2".freeze])
  s.add_development_dependency(%q<rantly>.freeze, [">= 2.0".freeze])
  s.add_development_dependency(%q<sinatra>.freeze, [">= 4.1".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 3.13".freeze])
  s.add_development_dependency(%q<webmock>.freeze, [">= 3.23".freeze])
end
