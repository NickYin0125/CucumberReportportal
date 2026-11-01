# frozen_string_literal: true

require "json"
require "open3"
require "digest"
require "fileutils"
require "rubygems/package"
require "time"
require_relative "final_wp5_context"

stamp = LedgerWP5Context.stamp
heads = LedgerWP5Context.heads.to_h { |version, head| [version, [head, version == "2.0.1" ? "79e5e9cfde4be6d29ca2293e549460c6c71fe87a" : "4ca2f770e0a84e83688f165ba04b4db8ef855cf9"]] }
heads.each do |version, (head, baseline)|
  qa = "/Users/nick/Documents/crr-qa-#{version}"
  sdk = "/Users/nick/Documents/crr-#{version}"
  directory = File.join(qa, "docs/reviews/assets", stamp, "repository")
  FileUtils.mkdir_p(directory)
  output = File.join(directory, "#{ARGV.fetch(0, 'before')}.json")
  raise "Never replace repository observations" if File.exist?(output)
  records = []
  capture = lambda do |criterion, *args|
    stdout, stderr, status = Open3.capture3({ "RP_API_KEY" => nil }, *args, chdir: sdk)
    records << { criterion: criterion, argv: args, exit: status.exitstatus, stdout: stdout, stderr: stderr }
    raise "Repository observation failed" unless status.success?
    stdout
  end
  raise "Runtime head changed" unless capture.call("V1", "git", "rev-parse", "HEAD").strip == head
  capture.call("V2", "git", "diff", baseline, head, "--", "Gemfile.lock")
  capture.call("V6", "git", "diff", "--stat", baseline, head, "--", "helm/", ".github/workflows/")
  capture.call("V6", "git", "diff", "--name-only", baseline, head, "--", "helm/", ".github/workflows/")
  capture.call("V8", "git", "log", "--reverse", "--format=%H %s", "#{baseline}..#{head}")
  capture.call("V4", "git", "diff", baseline, head, "--", "CHANGELOG.md")
  capture.call("V5", "git", "diff", baseline, head, "--", "docs/configuration.md", "docs/advanced-reporting.md")
  refs = capture.call("V7", "git", "ls-remote", "https://github.com/NickYin0125/CucumberReportportal.git",
    "refs/heads/main", "refs/heads/maintenance/1.x", "refs/heads/codex/cucumber-12", "refs/tags/*")
  package = nil
  unless ARGV.first == "after"
    filename = "reportportal-cucumber-ruby-#{version}.gem"
    path = File.join(directory, filename)
    capture.call("V3", "/opt/homebrew/opt/ruby/bin/gem", "build", "reportportal-cucumber-ruby.gemspec", "--output", path)
    gem = Gem::Package.new(path)
    gem.verify
    package = { filename: filename, bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest,
      version: gem.spec.version.to_s, verified: true, source_sha: head, published: false, retained_locally_only: true,
      spec_files: gem.spec.files }
  end
  old = JSON.parse(File.read(File.join(qa, "docs/reviews/assets/ledger-qa-v7-decision10-#{version}.json")))
  initial_heads = { "refs/heads/main" => "75cb090a7852c56285010af17cde9ad55df1284b",
    "refs/heads/maintenance/1.x" => "4ca2f770e0a84e83688f165ba04b4db8ef855cf9",
    "refs/heads/codex/cucumber-12" => "f2e68f112ad28604f4395710f10f595246f6dc00" }
  observed = refs.lines.map(&:split).to_h { |sha, ref| [ref, sha] }
  data = { schema: "wp5-final-head-repository/1", version: version, checked_at_utc: Time.now.utc.iso8601,
    runtime_sha: head, baseline_sha: baseline, records: records, package: package,
    protected_heads_expected: initial_heads, protected_heads_actual: observed.slice(*initial_heads.keys),
    decision10_historical_tag_names: old.fetch("current_tag_names"),
    current_tag_names: observed.keys.grep(%r{\Arefs/tags/}).reject { |ref| ref.end_with?("^{}") }.map { |ref| ref.delete_prefix("refs/tags/") }.sort,
    historical_source: "docs/reviews/assets/ledger-qa-v7-decision10-#{version}.json",
    historical_source_sha256: Digest::SHA256.file(File.join(qa, "docs/reviews/assets/ledger-qa-v7-decision10-#{version}.json")).hexdigest,
    files: %w[lib/reportportal_cucumber/version.rb CHANGELOG.md docs/configuration.md docs/advanced-reporting.md helm/reportportal-rich-experience/Chart.yaml].to_h { |file| [file, File.read(File.join(sdk, file))] } }
  if version == "2.0.1"
    data[:official_200_changelog] = capture.call("V4", "git", "show", "f2e68f112ad28604f4395710f10f595246f6dc00:CHANGELOG.md")
  end
  File.write(output, JSON.pretty_generate(data) + "\n", perm: 0o600)
  puts JSON.generate(version: version, runtime_sha: head, output: output, package_version: package && package[:version])
end
