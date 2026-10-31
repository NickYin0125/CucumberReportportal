# frozen_string_literal: true

# Require an explicitly selected bundle so native children cannot choose an ambient legacy Cucumber.
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
  chart_payload_files = %w[
    templates/NOTES.txt templates/_helpers.tpl templates/ingress-extension.yaml
    templates/minio-init-job.yaml templates/minio-bucket-config.yaml
    templates/minio-video-bucket-secret.yaml files/reconcile-video-bucket.sh values.yaml values.schema.json
    README.md OPERATIONS.md HUAWEI_PRIVATE_CLOUD.md values-huawei.example.yaml values-traefik-controller-local.yaml
  ].freeze
  protected_chart_hashes = chart_payload_files.to_h do |relative|
    [relative, Digest::SHA256.file(File.join(root, chart_relative, relative)).hexdigest]
  end.freeze

  before(:context) do
    @scratch = File.realpath(Dir.mktmpdir("rp-candidate-package-"))
    @source = File.join(@scratch, "source")
    @home = File.join(@scratch, "gems")
    @consumer = File.join(@scratch, "consumer")
    @built_artifacts = []
    @rejected_resolutions = []
    FileUtils.mkdir_p([@source, @home, @consumer])
    @spec = Gem::Specification.load(File.join(root, "reportportal-cucumber-ruby.gemspec"))
    (@spec.files + ["reportportal-cucumber-ruby.gemspec"]).each do |relative|
      destination = File.join(@source, relative)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(File.join(root, relative), destination)
    end

    # Export only the locked runtime dependency closure, never an ambient legacy Cucumber.
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
    @artifact = File.join(@source, "#{@spec.full_name}.gem")
    @run.call(Gem.ruby, "-S", "gem", "build", "reportportal-cucumber-ruby.gemspec")
    @built_artifacts << @artifact
    @run.call(Gem.ruby, "-S", "gem", "install", "--local", "--no-document", "--install-dir", @home,
              bundler.cache_file, @artifact)
    @installed = File.join(@home, "gems", @spec.full_name)
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
      artifacts = @built_artifacts.select { |path| File.file?(path) }
      artifacts.each { |path| FileUtils.cp(path, evidence) }
      manifest = {
        gem_version: @spec.version.to_s,
        source_git_head: ENV["RP_PACKAGING_SOURCE_HEAD"],
        ruby_version: RUBY_VERSION,
        bundler_version: Gem.loaded_specs.fetch("bundler").version.to_s,
        consumer: @provenance,
        rejected_resolutions: @rejected_resolutions,
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
    expect(package.version.to_s).to eq("2.0.0")
    expect(package.version).not_to be_prerelease
    expect(package.homepage).to eq("https://github.com/NickYin0125/CucumberReportportal")
    expect(package.metadata.fetch("source_code_uri")).to eq(package.homepage)
    expect(package.metadata.fetch("changelog_uri")).to eq("#{package.homepage}/blob/main/CHANGELOG.md")
    expect(Array(package.email)).to be_empty
  end

  it "enforces the Ruby minimum and rejects legacy or future-major Cucumber resolutions in the built artifact" do
    package = Gem::Package.new(@artifact).spec
    expect(package.required_ruby_version.satisfied_by?(Gem::Version.new("3.2.9"))).to be(false)
    %w[3.3.0 3.4.2].each do |version|
      expect(package.required_ruby_version.satisfied_by?(Gem::Version.new(version))).to be(true)
    end
    cucumber = package.runtime_dependencies.find { |dependency| dependency.name == "cucumber" }
    %w[9.2.1 10.2.0 11.0.0 12.0.0 13.0.0].each do |version|
      expect(cucumber.requirement.satisfied_by?(Gem::Version.new(version))).to be(false), version
    end
    %w[12.0.1 12.0.2 12.9.9].each do |version|
      expect(cucumber.requirement.satisfied_by?(Gem::Version.new(version))).to be(true), version
    end
    ["= 11.0.0", "= 13.0.0"].each_with_index do |requirement, index|
      rejected = File.join(@scratch, "rejected-#{index}")
      FileUtils.mkdir_p(rejected)
      File.write(File.join(rejected, "Gemfile"), "source 'https://rubygems.org'\ngem 'reportportal-cucumber-ruby', '= 2.0.0'\ngem 'cucumber', '#{requirement}'\n")
      stdout, stderr, status = Open3.capture3(@clean_env.merge("BUNDLE_GEMFILE" => File.join(rejected, "Gemfile"),
                                                              "BUNDLE_IGNORE_CONFIG" => "1"),
                                            Gem.ruby, @bundle, "lock", "--local", chdir: rejected)
      expect(status.success?).to be(false)
      expect(stdout + stderr).to match(/cucumber/i)
      expect(File.exist?(File.join(rejected, "Gemfile.lock"))).to be(false)
      (@rejected_resolutions ||= []) << { cucumber: requirement, exit: status.exitstatus, stdout: stdout, stderr: stderr }
    end
  end

  it "preserves the four protected development dependencies without making them runtime dependencies" do
    package = Gem::Package.new(@artifact).spec
    expect(package.development_dependencies.map(&:name)).to include("puma", "rackup", "rantly", "sinatra")
    expect(@provenance.fetch("dependencies")).to eq(%w[aws-sdk-s3 base64 cgi cucumber logger mime-types])
    expect(package.runtime_dependencies.map(&:name)).not_to include("cucumber-cucumber-expressions")
    expect(Gem::Version.new(@provenance.fetch("cucumber_expressions"))).to be >= Gem::Version.new("18.0")
    expect(Gem::Version.new(@provenance.fetch("cucumber_expressions"))).to be < Gem::Version.new("21.0")
    expect(@provenance.fetch("loaded_gems") & %w[puma rackup rantly sinatra rspec webmock]).to be_empty
  end

  it "excludes repository-only QA harnesses and development scaffolding from the actual gem" do
    files = Gem::Package.new(@artifact).spec.files
    expect(files.grep(%r{\A(?:features/|spec/|\.github/|Gemfile|Rakefile)})).to be_empty
    expect(files.grep(/duration|clearing_mock_server|\A(?:pkg|tmp)\//)).to be_empty
    expect(files.grep(%r{\Aexamples/day2_(?:endurance|faults)/})).to be_empty
    expect(files).to include("exe/reportportal-spool", "README.md", "CHANGELOG.md", "LICENSE")
    expect(files).to all(satisfy { |relative| File.file?(File.join(@installed, relative)) })
  end

  it "ships the user guides and resolves their local links from the installed gem" do
    guides = %w[
      README.md docs/getting-started.md docs/best-practices.md docs/ci.md
      docs/configuration.md docs/advanced-reporting.md examples/README.md
    ]
    guides.each do |guide|
      path = File.join(@installed, guide)
      expect(File.file?(path)).to be(true), "Installed guide missing: #{guide}"
      links = File.read(path).scan(/\[[^\]]+\]\(([^\s)]+)(?:\s+"[^"]*")?\)/).flatten
      local = links.reject { |link| link.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|#|//)}i) }
      local.each do |link|
        destination = File.expand_path(link.split("#", 2).first, File.dirname(path))
        expect(destination).to start_with("#{@installed}/")
        expect(File.file?(destination)).to be(true), "Installed #{guide} link missing: #{link}"
      end
    end
    expect(File.file?(File.join(@installed, chart_relative, "README.md"))).to be(true)
  end

  it "pins the independent consumer to the packaged SDK version" do
    gemfile = File.join(@installed, "examples/current_sdk/Gemfile")
    script = <<~RUBY
      dsl = Bundler::Dsl.new
      dsl.eval_gemfile(ARGV.fetch(0))
      dependency = dsl.dependencies.find { |item| item.name == "reportportal-cucumber-ruby" }
      puts JSON.generate(version: CurrentSDK::SDK_VERSION, requirement: dependency.requirement.to_s)
    RUBY
    consumer = JSON.parse(@run.call(Gem.ruby, "-rbundler", "-rjson", "-e", script, gemfile))
    expect(consumer.fetch("version")).to eq(@spec.version.to_s)
    expect(consumer.fetch("requirement")).to eq("= #{@spec.version}")
  end

  it "runs the packaged logger demo without writing inside the installed gem" do
    demo = File.join(@installed, "examples/logger_parameters_demo.rb")
    transcript = @run.call(Gem.ruby, @bundle, "exec", Gem.ruby, demo, directory: @consumer,
                           environment: @consumer_env.merge("NO_COLOR" => "1"))
    expect(transcript).to include("Mode: offline", "Cucumber exit: 0")
    expect(transcript.lines.grep(/\A\d{4}-\d{2}-\d{2} .*  INFO   /).length).to eq(9)
    directory = transcript.match(/^Reports: (.+)$/).captures.first
    expect(directory).to start_with(File.join(@consumer, "tmp", "logger-parameters-"))
    expect(File.file?(File.join(directory, "report.html"))).to be(true)
    expect(File.exist?(File.join(@installed, "tmp"))).to be(false)
  end

  it "loads only the installed SDK and a supported Bundler-pinned native Cucumber" do
    expect(@provenance.fetch("version")).to eq(@spec.version.to_s)
    expect(@provenance.fetch("gem_root")).to eq(@installed)
    expect(Gem::Version.new(@provenance.fetch("cucumber"))).to be >= Gem::Version.new("12.0.1")
    expect(Gem::Version.new(@provenance.fetch("cucumber"))).to be < Gem::Version.new("13.0")
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

  it "pins the dependency and compares the approved chart payload with packaged source" do
    chart = YAML.safe_load_file(File.join(root, chart_relative, "Chart.yaml"))
    expect(chart.fetch("version")).to eq("1.3.1")
    expect(chart.fetch("appVersion")).to eq("26.0.7")
    expect(chart.fetch("dependencies")).to eq([
      { "name" => "reportportal", "version" => "26.10.26", "repository" => "https://k8s.reportportal.io/" }
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
    @chart_package = File.join(@scratch, "reportportal-rich-experience-1.3.1.tgz")
    @built_artifacts << @chart_package
    entries = {}
    Zlib::GzipReader.open(@chart_package) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each { |entry| entries[entry.full_name] = entry.read if entry.file? }
      end
    end
    packaged_chart = YAML.safe_load(entries.fetch("reportportal-rich-experience/Chart.yaml"))
    expect(packaged_chart.fetch("version")).to eq("1.3.1")
    expect(packaged_chart.fetch("appVersion")).to eq("26.0.7")
    protected_chart_hashes.each do |relative, digest|
      expect(Digest::SHA256.hexdigest(entries.fetch("reportportal-rich-experience/#{relative}"))).to eq(digest)
    end
    expect(entries.keys).to include("reportportal-rich-experience/charts/reportportal/Chart.yaml")
  end
end
