# frozen_string_literal: true

# Require an explicitly selected bundle so native children cannot choose ambient Cucumber 11.
raise "Set BUNDLE_GEMFILE to a private staging Gemfile before running packaging specs" if ENV["BUNDLE_GEMFILE"].to_s.empty?

require "bundler/setup"
require "digest"
require "fileutils"
require "json"
require "open3"
require "rspec"
require "rubygems/package"
require "tmpdir"
require "yaml"
require "zlib"

RSpec.describe "Installed release packaging" do
  root = File.expand_path("../..", __dir__)
  fixtures = File.join(__dir__, "fixtures")
  chart_relative = "helm/reportportal-rich-experience"
  protected_chart_hashes = {
    "templates/NOTES.txt" => "5915cf19183a822dd403efa24ac9a1d0ca6854dff42aa7c8d584c0f7c2c578c6",
    "templates/_helpers.tpl" => "8922cdb346e13c5a7f1148214289574f3a2ea0d9548ebefdd7cb4901adcaed51",
    "templates/ingress-extension.yaml" => "8457598df3b713523f4936e26690c96814b38e21e4cbfb567194e8a1c2e2ba08",
    "templates/minio-init-job.yaml" => "929da76a3f85440e02b41830846c2d2fb084a8ac4caa6d581a6aadf1c12fdecf",
    "templates/minio-video-bucket-secret.yaml" => "afaaa22c48ea09f20c36acebdb10772b389661ad0c53fd5d3a56f6f0cc3d63a7",
    "values.yaml" => "adf31be615a167bbda76e89d8f95a636a336cb3558bf1ab97f6d75b52b610191"
  }.freeze

  before(:context) do
    @scratch = File.realpath(Dir.mktmpdir("rp-candidate-package-"))
    @source = File.join(@scratch, "source")
    @home = File.join(@scratch, "gems")
    @consumer = File.join(@scratch, "consumer")
    FileUtils.mkdir_p([@source, @home, @consumer])
    @spec = Gem::Specification.load(File.join(root, "reportportal-cucumber-ruby.gemspec"))
    (@spec.files + ["reportportal-cucumber-ruby.gemspec"]).each do |relative|
      destination = File.join(@source, relative)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(File.join(root, relative), destination)
    end

    # Export only the locked runtime dependency closure, never ambient Cucumber 11.
    locked = Bundler.load.specs.to_a
    dependencies = @spec.runtime_dependencies.dup
    exported = {}
    until dependencies.empty?
      dependency = dependencies.shift
      selected = locked.find { |spec| dependency.matches_spec?(spec) }
      raise "Missing locked runtime dependency: #{dependency.name}" unless selected
      next if exported.key?(selected.full_name)

      exported[selected.full_name] = selected
      dependencies.concat(selected.runtime_dependencies)
    end
    bundler = Gem.loaded_specs.fetch("bundler")
    (exported.values + [bundler]).each do |spec|
      if File.file?(spec.cache_file)
        FileUtils.cp(spec.cache_file, @source)
      elsif !spec.default_gem?
        raise "Offline packaging requires cached gem: #{spec.full_name}"
      end
    end

    @clean_env = ENV.keys.grep(/\A(?:BUNDLE(?:R)?_|RP_|CUCUMBER_PROFILE\z|RUBYOPT\z|RUBYLIB\z)/).to_h { |key| [key, nil] }
    @clean_env.merge!("GEM_HOME" => @home, "GEM_PATH" => @home)
    @run = lambda do |*command, directory: @source, environment: {}|
      stdout, stderr, status = Open3.capture3(@clean_env.merge(environment), *command, chdir: directory)
      raise "Candidate command failed (#{status.exitstatus}): #{command.join(' ')}\n#{stdout}\n#{stderr}" unless status.success?

      stdout
    end
    @artifact = File.join(@source, "reportportal-cucumber-ruby-1.2.0.gem")
    @run.call(Gem.ruby, "-S", "gem", "build", "reportportal-cucumber-ruby.gemspec")
    @run.call(Gem.ruby, "-S", "gem", "install", "--local", "--no-document", "--install-dir", @home,
              bundler.cache_file, @artifact)
    @installed = File.join(@home, "gems", "reportportal-cucumber-ruby-1.2.0")
    FileUtils.cp_r(Dir[File.join(fixtures, "*")], @consumer)
    @bundle = File.join(@home, "gems", bundler.full_name, "exe", "bundle")
    @consumer_env = { "BUNDLE_GEMFILE" => File.join(@consumer, "Gemfile"), "BUNDLE_IGNORE_CONFIG" => "1" }
    @run.call(Gem.ruby, @bundle, "lock", "--local", directory: @consumer, environment: @consumer_env)
    @provenance = JSON.parse(@run.call(Gem.ruby, @bundle, "exec", Gem.ruby, "consumer.rb",
                                     directory: @consumer, environment: @consumer_env))
  end

  after(:context) do
    evidence = ENV["RP_PACKAGING_EVIDENCE_DIR"]
    if evidence && @provenance
      FileUtils.mkdir_p(evidence)
      artifacts = [@artifact, @chart_package].compact.select { |path| File.file?(path) }
      artifacts.each { |path| FileUtils.cp(path, evidence) }
      manifest = {
        gem_version: @spec.version.to_s,
        source_git_head: ENV["RP_PACKAGING_SOURCE_HEAD"],
        ruby_version: RUBY_VERSION,
        bundler_version: Gem.loaded_specs.fetch("bundler").version.to_s,
        consumer: @provenance,
        source_sha256: (@spec.files + ["reportportal-cucumber-ruby.gemspec"]).to_h do |relative|
          [relative, Digest::SHA256.file(File.join(@source, relative)).hexdigest]
        end,
        artifact_sha256: artifacts.to_h { |path| [File.basename(path), Digest::SHA256.file(path).hexdigest] }
      }
      File.write(File.join(evidence, "packaging-manifest.json"), JSON.pretty_generate(manifest) + "\n")
    end
    FileUtils.remove_entry(@scratch) if @scratch && File.directory?(@scratch)
  end

  it "has the release identity and verified-origin metadata without a fabricated email" do
    package = Gem::Package.new(@artifact).spec
    expect(package.version.to_s).to eq("1.2.0")
    expect(package.version).not_to be_prerelease
    expect(package.homepage).to eq("https://github.com/NickYin0125/CucumberReportportal")
    expect(package.metadata.fetch("source_code_uri")).to eq(package.homepage)
    expect(package.metadata.fetch("changelog_uri")).to eq("#{package.homepage}/blob/main/CHANGELOG.md")
    expect(Array(package.email)).to be_empty
  end

  it "preserves the four protected development dependencies without making them runtime dependencies" do
    package = Gem::Package.new(@artifact).spec
    expect(package.development_dependencies.map(&:name)).to include("puma", "rackup", "rantly", "sinatra")
    expect(@provenance.fetch("dependencies")).to eq(%w[aws-sdk-s3 cucumber cucumber-cucumber-expressions mime-types])
    expect(Gem::Version.new(@provenance.fetch("cucumber_expressions"))).to be < Gem::Version.new("19.0")
    expect(@provenance.fetch("loaded_gems") & %w[puma rackup rantly sinatra rspec webmock]).to be_empty
  end

  it "excludes development scaffolding and untracked duration experiments from the actual gem" do
    files = Gem::Package.new(@artifact).spec.files
    expect(files.grep(%r{\A(?:features/|spec/|\.github/|Gemfile|Rakefile)})).to be_empty
    expect(files.grep(/duration|clearing_mock_server|\A(?:pkg|tmp)\//)).to be_empty
    expect(files).to include("exe/reportportal-spool", "README.md", "CHANGELOG.md", "LICENSE")
    expect(files).to all(satisfy { |relative| File.file?(File.join(@installed, relative)) })
  end

  it "resolves every local Markdown link from the installed README, including design/operator docs" do
    readme = File.read(File.join(@installed, "README.md"))
    links = readme.scan(/\[[^\]]+\]\(([^\s)]+)(?:\s+"[^"]*")?\)/).flatten
    local = links.reject { |link| link.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|#|//)}i) }
    expect(local.grep(%r{\Adocs/design/}).length).to be >= 6
    local.each do |link|
      destination = File.expand_path(link.split("#", 2).first, @installed)
      expect(destination).to start_with("#{@installed}/")
      expect(File.file?(destination)).to be(true), "Installed README link missing: #{link}"
    end
    expect(File.file?(File.join(@installed, chart_relative, "README.md"))).to be(true)
  end

  it "loads only the installed SDK and a supported Bundler-pinned native Cucumber" do
    expect(@provenance.fetch("version")).to eq("1.2.0")
    expect(@provenance.fetch("gem_root")).to eq(@installed)
    expect(Gem::Version.new(@provenance.fetch("cucumber"))).to be >= Gem::Version.new("9.0")
    expect(Gem::Version.new(@provenance.fetch("cucumber"))).to be < Gem::Version.new("11.0")
    expect(@provenance.fetch("sdk_files")).not_to be_empty
    expect(@provenance.fetch("sdk_files")).to all(start_with("#{@installed}/lib/"))
    stdout = @run.call(Gem.ruby, @bundle, "exec", "cucumber", "--no-profile", "--require", "support",
                       "--format", "progress", "consumer.feature", directory: @consumer, environment: @consumer_env)
    expect(stdout).to include("1 scenario (1 passed)", "ISOLATED_CANDIDATE_NATIVE_OK")
  end

  it "ships an executable spool CLI which works without source-path loading" do
    stdout = @run.call(Gem.ruby, File.join(@home, "bin", "reportportal-spool"), "--help", directory: @consumer)
    expect(stdout).to include("--transaction", "--dry-run", "--execute")
  end

  it "pins the upgraded dependency and broker bootstrap while retaining the legacy video templates" do
    chart = YAML.safe_load_file(File.join(root, chart_relative, "Chart.yaml"))
    expect(chart.fetch("version")).to eq("1.2.0-rc.2")
    expect(chart.fetch("appVersion")).to eq("26.0.5")
    expect(chart.fetch("dependencies")).to eq([
      { "name" => "reportportal", "version" => "26.8.12", "repository" => "https://k8s.reportportal.io/" }
    ])
    protected_chart_hashes.each do |relative, digest|
      expect(Digest::SHA256.file(File.join(root, chart_relative, relative)).hexdigest).to eq(digest)
    end
  end

  it "builds a local candidate chart without fetching dependencies or deploying it" do
    helm = ENV.fetch("HELM_BIN", "/opt/homebrew/bin/helm")
    skip "Helm is unavailable; gem checks still run" unless File.executable?(helm)

    chart_source = File.join(@scratch, "chart")
    FileUtils.cp_r(File.join(root, chart_relative), chart_source)
    @run.call(helm, "package", chart_source, "--destination", @scratch)
    @chart_package = File.join(@scratch, "reportportal-rich-experience-1.2.0-rc.2.tgz")
    entries = {}
    Zlib::GzipReader.open(@chart_package) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each { |entry| entries[entry.full_name] = entry.read if entry.file? }
      end
    end
    packaged_chart = YAML.safe_load(entries.fetch("reportportal-rich-experience/Chart.yaml"))
    expect(packaged_chart.fetch("version")).to eq("1.2.0-rc.2")
    expect(packaged_chart.fetch("appVersion")).to eq("26.0.5")
    protected_chart_hashes.each do |relative, digest|
      expect(Digest::SHA256.hexdigest(entries.fetch("reportportal-rich-experience/#{relative}"))).to eq(digest)
    end
    expect(entries.keys).to include("reportportal-rich-experience/charts/reportportal/Chart.yaml")
  end
end
