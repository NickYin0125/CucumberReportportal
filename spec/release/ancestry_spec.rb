# frozen_string_literal: true

require "rspec"
require_relative "../../script/release/tooling"

RSpec.describe "Release ancestry with isolated Git repositories" do
  let(:repository_root) { File.expand_path("../..", __dir__) }
  let(:version) { "1.3.2" }
  let(:tag) { "v#{version}" }
  let(:commands) { ReleaseTooling::Commands.new }
  let(:source) { ReleaseTooling::Source.new(root: @root, tag: tag, commit: @release_commit, commands: commands) }
  let(:legacy_commit) { "4ca2f770e0a84e83688f165ba04b4db8ef855cf9" }

  before do
    @scratch = Dir.mktmpdir("release-ancestry-")
    @root = File.join(@scratch, "source")
    FileUtils.mkdir_p(@root)
    git("init", "--quiet", "--initial-branch=main", "--template=")
    git("config", "user.name", "Release fixture")
    git("config", "user.email", "release-fixture@example.invalid")
    write_release("1.3.0")
    @main_commit = commit("Main baseline")
    git("update-ref", "refs/remotes/origin/main", @main_commit)
    git("checkout", "--quiet", "-b", "maintenance/1.x")
    write_release(version)
    @release_commit = commit("Maintenance release #{version}")
    git("update-ref", "refs/remotes/origin/maintenance/1.x", @release_commit)
    git("tag", tag)
  end

  after { FileUtils.remove_entry(@scratch) }

  def git(*arguments)
    commands.run("git", "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false", *arguments, chdir: @root).strip
  end

  def commit(message)
    git("add", ".")
    git("commit", "--quiet", "-m", message)
    git("rev-parse", "HEAD")
  end

  def write_release(release_version)
    File.write(File.join(@root, "reportportal-cucumber-ruby.gemspec"), <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = "reportportal-cucumber-ruby"
        spec.version = "#{release_version}"
        spec.summary = "Isolated release fixture"
        spec.authors = ["Test"]
      end
    RUBY
    File.write(File.join(@root, "CHANGELOG.md"), "## #{release_version}\n\n- Release fixture.\n")
    chart = File.join(@root, ReleaseTooling::Source::CHART)
    FileUtils.mkdir_p(chart)
    File.write(File.join(chart, "Chart.yaml"), <<~YAML)
      apiVersion: v2
      name: reportportal-rich-experience
      version: #{release_version}
      appVersion: "26.0.7"
    YAML
  end

  def workflow_guards
    %w[release release-resume].flat_map do |name|
      workflow = YAML.load_file(File.join(repository_root, ".github/workflows/#{name}.yml"))
      %w[preflight publish].map do |job|
        step = workflow.dig("jobs", job, "steps").find { |entry| entry.fetch("run", "").include?("git merge-base --is-ancestor") }
        ["#{name}/#{job}", step.fetch("run")]
      end
    end
  end

  def run_guard(name, script, controller_ref: "refs/heads/main", controller_commit: @main_commit,
                controller_sha: controller_commit, release_tag: tag, api_env: {})
    env = { "RELEASE_TAG" => release_tag, "RELEASE_SHA" => @release_commit }
    if name == "release-resume/preflight"
      # Only GitHub API responses are simulated; execute the entire recovery guard.
      git("checkout", "--quiet", "--detach", controller_commit)
      FileUtils.rm_f([File.join(@scratch, "outputs"), File.join(@scratch, "api-calls")])
      env.merge!("GITHUB_SHA" => controller_sha, "GITHUB_REF" => controller_ref,
                 "SOURCE_RUN_ID" => "77", "GITHUB_REPOSITORY" => "owner/repo",
                 "RUNNER_TEMP" => @scratch, "GITHUB_OUTPUT" => File.join(@scratch, "outputs"),
                 "FIXTURE_API_LOG" => File.join(@scratch, "api-calls"),
                 "FIXTURE_RUN" => JSON.generate("status" => "completed", "event" => "push", "head_sha" => @release_commit,
                                                "head_branch" => release_tag, "workflow_id" => 5, "run_attempt" => 1),
                 "FIXTURE_JOBS" => JSON.generate([{ "jobs" => [{ "name" => "preflight", "conclusion" => "success" },
                                                              { "name" => "validate / test", "conclusion" => "success" }] }]),
                 "FIXTURE_ARTIFACTS" => JSON.generate("artifacts" => [{ "id" => 9, "name" => "release-bundle-77-1", "expired" => false }]))
      env.merge!(api_env)
      script = <<~BASH + script
        gh() {
          printf '%s\n' "$*" >> "$FIXTURE_API_LOG"
          case "$*" in
            *workflows/release.yml*) printf '%s\n' 5 ;;
            *jobs\?*) printf '%s\n' "$FIXTURE_JOBS" ;;
            *artifacts\?*) printf '%s\n' "$FIXTURE_ARTIFACTS" ;;
            *actions/runs/77) printf '%s\n' "$FIXTURE_RUN" ;;
            *) return 1 ;;
          esac
        }
      BASH
    end
    Open3.capture3(env, "bash", "--noprofile", "--norc", "-e", "-o", "pipefail", "-c", script, chdir: @root)
  ensure
    git("checkout", "--quiet", "--detach", @release_commit) if name == "release-resume/preflight"
  end

  def expect_guards(accepted:)
    workflow_guards.each do |name, script|
      out, err, status = run_guard(name, script)
      expect(status.success?).to eq(accepted), "#{name}: #{out}\n#{err}"
    end
  end

  context "with a recovery controller" do
    let(:guard) { workflow_guards.to_h.fetch("release-resume/preflight") }

    def expect_recovery(accepted:, **options)
      out, err, status = run_guard("release-resume/preflight", guard, **options)
      expect(status.success?).to eq(accepted), "#{out}\n#{err}"
      if accepted
        expect(File.read(File.join(@scratch, "outputs"))).to eq("source-sha=#{@release_commit}\nartifact-id=9\n")
      else
        expect(File.exist?(File.join(@scratch, "outputs"))).to be(false)
      end
    end

    it "runs complete 1.x recovery from maintenance/1.x without requiring the controller on main" do
      expect(git("rev-parse", "refs/remotes/origin/main")).not_to eq(@release_commit)
      expect_recovery(accepted: true, controller_ref: "refs/heads/maintenance/1.x", controller_commit: @release_commit)
    end

    it "retains complete 1.x recovery from the trusted main controller" do
      expect_recovery(accepted: true)
    end

    %w[refs/heads/feature-only refs/heads/maintenance/1.x-suffix refs/tags/maintenance/1.x].each do |ref|
      it "rejects #{ref} even when its commit is approved maintenance ancestry" do
        expect_recovery(accepted: false, controller_ref: ref, controller_commit: @release_commit)
        expect(File.exist?(File.join(@scratch, "api-calls"))).to be(false)
      end
    end

    it "does not let a main controller borrow maintenance ancestry" do
      expect_recovery(accepted: false, controller_commit: @release_commit)
      expect(File.exist?(File.join(@scratch, "api-calls"))).to be(false)
    end

    it "does not let a maintenance controller borrow main ancestry" do
      File.write(File.join(@root, "controller.txt"), "Feature-only controller\n")
      foreign = commit("Unapproved maintenance controller")
      git("update-ref", "refs/remotes/origin/main", foreign)
      expect_recovery(accepted: false, controller_ref: "refs/heads/maintenance/1.x", controller_commit: foreign)
      expect(File.exist?(File.join(@scratch, "api-calls"))).to be(false)
    end

    %w[main maintenance/1.x].each do |branch|
      it "rejects a #{branch} controller whose checkout differs from GITHUB_SHA" do
        expect_recovery(accepted: false, controller_ref: "refs/heads/#{branch}",
                        controller_commit: @release_commit, controller_sha: @main_commit)
        expect(File.exist?(File.join(@scratch, "api-calls"))).to be(false)
      end
    end

    %w[v1.3.2-rc.1 v1.03.2 v1.3 v1.3.2;false].each do |invalid_tag|
      it "rejects the unstable or malformed #{invalid_tag} tag from maintenance" do
        git("tag", invalid_tag, @release_commit)
        expect_recovery(accepted: false, controller_ref: "refs/heads/maintenance/1.x",
                        controller_commit: @release_commit, release_tag: invalid_tag)
        expect(File.exist?(File.join(@scratch, "api-calls"))).to be(false)
      end
    end

    it "still rejects a moved tag against the original run when dispatched from maintenance" do
      git("tag", "--delete", tag)
      git("tag", tag, @main_commit)
      expect_recovery(accepted: false, controller_ref: "refs/heads/maintenance/1.x", controller_commit: @release_commit)
      expect(File.read(File.join(@scratch, "api-calls"))).to include("actions/runs/77")
    end

    it "still rejects expired original artifacts when dispatched from maintenance" do
      artifacts = { "artifacts" => [{ "id" => 9, "name" => "release-bundle-77-1", "expired" => true }] }
      expect_recovery(accepted: false, controller_ref: "refs/heads/maintenance/1.x", controller_commit: @release_commit,
                      api_env: { "FIXTURE_ARTIFACTS" => JSON.generate(artifacts) })
      expect(File.read(File.join(@scratch, "api-calls"))).to include("actions/runs/77/artifacts")
    end

    context "with a 2.x tag on an approved 2.x source ref" do
      let(:version) { "2.0.1" }

      before { git("update-ref", "refs/remotes/origin/codex/cucumber-12", @release_commit) }

      it "retains recovery from the trusted main controller" do
        expect_recovery(accepted: true)
      end

      it "rejects recovery through the maintenance controller before any API requests" do
        expect_recovery(accepted: false, controller_ref: "refs/heads/maintenance/1.x", controller_commit: @release_commit)
        expect(File.exist?(File.join(@scratch, "api-calls"))).to be(false)
      end
    end
  end

  it "accepts a clean 1.3.2-shaped maintenance commit absent from main on every release path" do
    expect(git("rev-parse", "refs/remotes/origin/main")).not_to eq(@release_commit)
    expect(source.identity.fetch("version")).to eq("1.3.2")
    expect { source.verify_commit! }.not_to raise_error
    expect_guards(accepted: true)
  end

  it "rejects a commit present only on a feature branch" do
    git("checkout", "--quiet", "-b", "feature-only")
    git("update-ref", "refs/heads/maintenance/1.x", @main_commit)
    git("update-ref", "refs/remotes/origin/maintenance/1.x", @main_commit)
    expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /outside approved release ancestry/)
    expect_guards(accepted: false)
  end

  it "does not accept a new 1.x release from main alone" do
    git("update-ref", "refs/remotes/origin/main", @release_commit)
    git("update-ref", "refs/remotes/origin/maintenance/1.x", @main_commit)
    expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /outside approved release ancestry/)
    expect_guards(accepted: false)
  end

  it "rejects a moved tag, including recovery against the original validated run" do
    git("tag", "--delete", tag)
    git("tag", tag, @main_commit)
    expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /tag moved/)
    expect_guards(accepted: false)
  end

  it "rejects a checkout that differs from the release commit" do
    git("checkout", "--quiet", "--detach", @main_commit)
    expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /Checkout does not match/)
  end

  %i[tracked staged untracked].each do |kind|
    it "rejects #{kind} source changes before build or publication" do
      path = kind == :untracked ? "untracked.txt" : "CHANGELOG.md"
      File.write(File.join(@root, path), "Dirty fixture\n")
      git("add", path) if kind == :staged
      output = File.join(@scratch, "bundle")
      expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /must be clean/)
      expect { ReleaseTooling::Bundle.new(source, output).build! }.to raise_error(ReleaseTooling::Error, /must be clean/)
      expect { ReleaseTooling::Publisher.new(source, output, repository: "owner/repo").publish! }
        .to raise_error(ReleaseTooling::Error, /must be clean/)
      expect(File.exist?(output)).to be(false)
    end
  end

  it "restricts the historical main fallback to the exact tag and immutable commit pair" do
    historical = ReleaseTooling::Source.new(root: @root, tag: "v1.3.1", commit: legacy_commit)
    expect(historical.ancestry_refs).to eq(%w[refs/remotes/origin/maintenance/1.x refs/remotes/origin/main])
    [["v1.3.1", @release_commit], ["v1.3.2", legacy_commit], ["v1.3.0", legacy_commit]].each do |release_tag, sha|
      candidate = ReleaseTooling::Source.new(root: @root, tag: release_tag, commit: sha)
      expect(candidate.ancestry_refs).to eq(%w[refs/remotes/origin/maintenance/1.x])
    end
    historical.ancestry_refs.clear
    expect(historical.ancestry_refs).to eq(%w[refs/remotes/origin/maintenance/1.x refs/remotes/origin/main])
  end

  context "with the actual immutable v1.3.1 source in an isolated repository" do
    let(:version) { "1.3.1" }

    before do
      git("fetch", "--quiet", "--no-tags", repository_root, legacy_commit)
      git("checkout", "--quiet", "--detach", legacy_commit)
      git("tag", "--delete", tag)
      git("tag", tag, legacy_commit)
      @release_commit = legacy_commit
      @main_commit = legacy_commit
      git("update-ref", "refs/remotes/origin/main", legacy_commit)
    end

    it "accepts historical main ancestry without changing manifest identity, title or asset names" do
      expect { source.verify_commit! }.not_to raise_error
      code = <<~RUBY
        require #{File.join(repository_root, "script/release/tooling.rb").inspect}
        source = ReleaseTooling::Source.new(root: ARGV[0], tag: "v1.3.1", commit: ARGV[1])
        puts JSON.generate(identity: source.identity, notes: source.notes, assets: source.asset_names)
      RUBY
      out, err, status = Open3.capture3({ "RUBYOPT" => nil, "RUBYLIB" => nil }, Gem.ruby, "-e", code, @root, legacy_commit)
      expect(status.success?).to be(true), err
      metadata = JSON.parse(out)
      expect(metadata.fetch("identity")).to eq("tag" => "v1.3.1", "commit" => legacy_commit, "version" => "1.3.1", "appVersion" => "26.0.7")
      expect(metadata.fetch("notes")).to start_with("# SDK and Helm 1.3.1\n")
      expect(metadata.fetch("assets")).to eq(%w[reportportal-cucumber-ruby-1.3.1.gem reportportal-rich-experience-1.3.1.tgz release-manifest.json SHA256SUMS])
      expect_guards(accepted: true)
    end

    it "does not allow a different commit to borrow the v1.3.1 main fallback" do
      @release_commit = git("rev-parse", "refs/remotes/origin/maintenance/1.x")
      git("checkout", "--quiet", "--detach", @release_commit)
      git("tag", "--delete", tag)
      git("tag", tag)
      @main_commit = @release_commit
      git("update-ref", "refs/remotes/origin/main", @release_commit)
      git("update-ref", "refs/remotes/origin/maintenance/1.x", git("rev-parse", "#{@release_commit}^"))
      expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /outside approved release ancestry/)
      expect_guards(accepted: false)
    end

    it "still rejects the immutable historical commit outside both approved refs" do
      @main_commit = git("rev-parse", "refs/remotes/origin/maintenance/1.x")
      git("update-ref", "refs/remotes/origin/main", @main_commit)
      expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /outside approved release ancestry/)
      expect_guards(accepted: false)
    end
  end

  context "with a 2.x release" do
    let(:version) { "2.0.1" }

    it "keeps the same fixed refs as the 2.x reference tooling" do
      expect(source.ancestry_refs).to eq(%w[refs/remotes/origin/main refs/remotes/origin/codex/cucumber-12])
    end

    %w[main codex/cucumber-12].each do |branch|
      it "retains the reference 2.x ancestry rule for origin/#{branch}" do
        git("update-ref", "refs/remotes/origin/#{branch}", @release_commit)
        expect { source.verify_commit! }.not_to raise_error
        expect_guards(accepted: true)
      end
    end

    it "does not substitute maintenance ancestry for either approved 2.x ref" do
      expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /outside approved release ancestry/)
      expect_guards(accepted: false)
    end
  end
end
