# frozen_string_literal: true

require "rspec"
require "bundler"
require_relative "../tooling"

RSpec.describe "Release dependency isolation" do
  let(:root) { File.expand_path("../../..", __dir__) }
  let(:validation) { YAML.load_file(File.join(root, ".github/workflows/validate.yml")) }
  let(:job) { validation.fetch("jobs").fetch("bundle") }
  let(:steps) { job.fetch("steps") }
  let(:isolation) { steps.find { |step| step["name"] == "Isolate release dependencies before Ruby setup" } }
  let(:install) { steps.find { |step| step["name"] == "Install locked release dependencies outside source" } }

  it "keeps setup-ruby's in-checkout cache out of the release bundle job" do
    setup = steps.find { |step| step["uses"] == "ruby/setup-ruby@v1" }
    expect(setup.dig("with", "ruby-version")).to eq("3.3")
    expect(setup.dig("with", "bundler-cache")).to be(false)
    expect(job.fetch("env")).to include(
      "BUNDLE_GEMFILE" => "${{ github.workspace }}/Gemfile",
      "BUNDLE_FROZEN" => "true"
    )
    expect(job.fetch("env")).not_to have_key("BUNDLE_IGNORE_CONFIG")
    expect(install.fetch("run")).to eq("bundle install --jobs 4")
    expect(isolation.fetch("run")).to include('"BUNDLE_PATH=$RUNNER_TEMP/release-gems" >> "$GITHUB_ENV"',
                                             '"BUNDLE_APP_CONFIG=$RUNNER_TEMP/release-bundle-config" >> "$GITHUB_ENV"')
    expect(steps.index(isolation)).to be < steps.index(setup)
    expect(steps.index(setup)).to be < steps.index(install)
    build = steps.find { |step| step["name"] == "Build verified release bundle" }
    expect(steps.index(install)).to be < steps.index(build)
    expect(job.fetch("needs")).to eq("gate")
  end

  it "uses only GitHub-supported contexts in job-level environments" do
    # runner is available in steps, not while GitHub expands job-level env.
    allowed = %w[github needs strategy matrix vars secrets inputs]
    validation.fetch("jobs").each_value do |entry|
      entry.fetch("env", {}).each_value do |value|
        contexts = value.to_s.scan(/\$\{\{\s*(\w+)\./).flatten
        expect(contexts - allowed).to be_empty
      end
    end
  end

  it "runs these executable regressions on the current matrix, not the frozen legacy driver" do
    current = validation.dig("jobs", "test", "steps")
    regression = current.find { |step| step["run"] == "bundle exec rspec script/release/spec" }
    expect(regression).not_to be_nil
    expect(regression.keys).to contain_exactly("name", "run")
    legacy = validation.dig("jobs", "legacy")
    expect(legacy.to_s).not_to include("script/release/spec", "release-gems", "release-bundle-config")
  end

  context "with real Git status and an offline dependency install" do
    around do |example|
      Dir.mktmpdir("release-isolation-") do |temporary|
        @source_root = File.join(temporary, "source")
        @runner_temp = File.join(temporary, "runner-temp")
        FileUtils.mkdir_p([@source_root, @runner_temp])
        @environment = job.fetch("env").select { |key, _| key.start_with?("BUNDLE_") }.transform_values do |value|
          value.gsub("${{ github.workspace }}", @source_root).gsub("${{ runner.temp }}", @runner_temp)
        end.merge("BUNDLE_USER_HOME" => File.join(@runner_temp, "bundler-user"),
                  "BUNDLE_CACHE_PATH" => File.join(@runner_temp, "offline-cache"))
        environment_file = File.join(@runner_temp, "github-env")
        stdout, stderr, status = Open3.capture3(
          {"RUNNER_TEMP" => @runner_temp, "GITHUB_ENV" => environment_file},
          "/bin/bash", "-e", "-o", "pipefail", "-c", isolation.fetch("run")
        )
        raise "Workflow path initialization failed: #{stdout}\n#{stderr}" unless status.success?
        @environment.merge!(File.readlines(environment_file, chomp: true).to_h { |line| line.split("=", 2) })
        prepare_source
        example.run
      end
    end

    def run_command(*arguments, env: {})
      stdout, stderr, status = Bundler.with_unbundled_env do
        Open3.capture3(@environment.merge(env), *arguments, chdir: @source_root)
      end
      raise "#{arguments.inspect} failed:\n#{stdout}\n#{stderr}" unless status.success?

      stdout
    end

    def prepare_source
      File.write(File.join(@source_root, ".gitignore"), File.read(File.join(root, ".gitignore")))
      File.write(File.join(@source_root, "payload.rb"), "# release fixture\n")
      File.write(File.join(@source_root, "Gemfile"), <<~RUBY)
        source "https://rubygems.org"
        gem "wp4-dependency", "1.0.0"
      RUBY
      # Seed a real cached gem, so the workflow install can run without network access.
      dependency = File.join(@runner_temp, "dependency")
      FileUtils.mkdir_p(File.join(dependency, "lib"))
      File.write(File.join(dependency, "lib/wp4_dependency.rb"), "WP4_DEPENDENCY = true\n")
      specification = Gem::Specification.new do |spec|
        spec.name = "wp4-dependency"
        spec.version = "1.0.0"
        spec.summary = "Offline release regression fixture"
        spec.authors = ["Test"]
        spec.license = "MIT"
        spec.homepage = "https://example.invalid"
        spec.required_ruby_version = ">= 3.3"
        spec.files = ["lib/wp4_dependency.rb"]
      end
      cache = @environment.fetch("BUNDLE_CACHE_PATH")
      FileUtils.mkdir_p(cache)
      Dir.chdir(dependency) do
        Gem::Package.build(specification, false, false, File.join(cache, "wp4-dependency-1.0.0.gem"))
      end
      File.write(File.join(@source_root, "Gemfile.lock"), <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            wp4-dependency (1.0.0)

        PLATFORMS
          ruby

        DEPENDENCIES
          wp4-dependency (= 1.0.0)

        BUNDLED WITH
           #{Bundler::VERSION}
      LOCK

      # All commits and refs belong only to this disposable fixture, never the worktree.
      run_command("git", "init", "--quiet")
      run_command("git", "config", "user.name", "Release fixture")
      run_command("git", "config", "user.email", "release@example.invalid")
      run_command("git", "config", "core.excludesFile", File::NULL)
      run_command("git", "config", "core.hooksPath", File::NULL)
      run_command("git", "add", ".")
      run_command("git", "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Release fixture")
      commit = run_command("git", "rev-parse", "HEAD").strip
      run_command("git", "update-ref", "refs/tags/v2.0.2", commit)
      run_command("git", "update-ref", "refs/remotes/origin/main", commit)
      @source = ReleaseTooling::Source.new(root: @source_root, tag: "v2.0.2", commit: commit)
      @lockfile = File.binread(File.join(@source_root, "Gemfile.lock"))
      # Execute the workflow's install, adding only the test's offline constraint.
      run_command("/bin/bash", "-e", "-o", "pipefail", "-c", "#{install.fetch('run')} --local")
    end

    it "loads installed dependencies outside source while preserving a clean frozen checkout" do
      loaded = run_command("bundle", "exec", "ruby", "-e",
                           'require "wp4_dependency"; puts Gem.loaded_specs.fetch("wp4-dependency").full_gem_path').strip
      expect(File.realpath(loaded)).to start_with(File.realpath(@runner_temp) + File::SEPARATOR)
      run_command("bundle", "config", "set", "--local", "retry", "1")
      expect(File.exist?(File.join(@source_root, "vendor"))).to be(false)
      expect(File.exist?(File.join(@source_root, ".bundle"))).to be(false)
      expect(File.file?(File.join(@environment.fetch("BUNDLE_APP_CONFIG"), "config"))).to be(true)
      expect(File.binread(File.join(@source_root, "Gemfile.lock"))).to eq(@lockfile)
      expect(run_command("git", "status", "--porcelain", "--untracked-files=normal")).to eq("")
      expect { @source.verify_commit! }.not_to raise_error
    end

    {
      "modified tracked source" => ->(directory) { File.write(File.join(directory, "payload.rb"), "# changed\n") },
      "deleted tracked source" => ->(directory) { File.unlink(File.join(directory, "payload.rb")) },
      "an untracked file" => ->(directory) { File.write(File.join(directory, "unexpected.txt"), "unexpected\n") },
      "the old untracked vendor/bundle layout" => lambda { |directory|
        FileUtils.mkdir_p(File.join(directory, "vendor/bundle"))
        File.write(File.join(directory, "vendor/bundle/dependency.rb"), "# cached dependency\n")
      }
    }.each do |description, change|
      it "still rejects #{description} before creating release artifacts" do
        change.call(@source_root)
        output = File.join(@runner_temp, "release-bundle")
        expect { @source.verify_commit! }.to raise_error(ReleaseTooling::Error, /must be clean, including untracked files/)
        expect { ReleaseTooling::Bundle.new(@source, output).build! }
          .to raise_error(ReleaseTooling::Error, /must be clean, including untracked files/)
        expect(File.exist?(output)).to be(false)
      end
    end

    it "still rejects staged changes" do
      File.write(File.join(@source_root, "payload.rb"), "# staged change\n")
      run_command("git", "add", "payload.rb")
      expect { @source.verify_commit! }.to raise_error(ReleaseTooling::Error, /must be clean/)
    end
  end
end
