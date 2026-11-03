# frozen_string_literal: true

require "rspec"
require "yaml"
require "open3"

RSpec.describe "Release workflow security and validation contract" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:ci) { YAML.load_file(File.join(root, ".github/workflows/ci.yml")) }
  let(:validation) { YAML.load_file(File.join(root, ".github/workflows/validate.yml")) }
  let(:release) { YAML.load_file(File.join(root, ".github/workflows/release.yml")) }
  let(:resume) { YAML.load_file(File.join(root, ".github/workflows/release-resume.yml")) }

  it "shares the same full validation for PRs, branches and tags with read-only defaults" do
    [ci, validation, release].each { |workflow| expect(workflow.fetch("permissions")).to eq("contents" => "read") }
    expect(ci.dig("jobs", "test", "uses")).to eq("./.github/workflows/validate.yml")
    expect(release.dig("jobs", "validate", "uses")).to eq(ci.dig("jobs", "test", "uses"))
    expect(release.dig("jobs", "validate", "needs")).to eq("preflight")
    expect(release.dig("jobs", "publish", "needs")).to contain_exactly("preflight", "validate")
    # Psych's YAML 1.1 parser treats the bare GitHub key `on` as true.
    expect(ci.fetch(true).fetch("push")).to eq("branches" => ["**"])
    expect(release.fetch(true)).to eq("push" => { "tags" => ["v*"] })
    expect(ci.fetch(true)).not_to have_key("pull_request_target")
    expect(validation.fetch(true).keys).to eq(["workflow_call"])
  end

  it "limits write permissions to tag publication and never inherits PR secrets" do
    [ci, validation, release].each do |workflow|
      workflow.fetch("jobs").each do |name, job|
        expect(job).not_to have_key("secrets")
        expect(job.fetch("permissions", {})).not_to include("contents" => "write") unless workflow == release && name == "publish"
      end
    end
    publish = release.dig("jobs", "publish")
    expect(publish.fetch("permissions")).to eq("contents" => "write")
    expect(publish.fetch("if")).to include("github.event_name == 'push'", "github.ref_type == 'tag'")
    expect(publish.fetch("steps").last.dig("env", "GITHUB_TOKEN")).to eq("${{ secrets.GITHUB_TOKEN }}")
  end

  it "has full release-line history with non-persisted credentials and Node24 checkout" do
    jobs = [validation.dig("jobs", "test"), validation.dig("jobs", "bundle"), release.dig("jobs", "preflight"), release.dig("jobs", "publish")]
    jobs.each do |job|
      checkout = job.fetch("steps").find { |step| step.fetch("uses", "").start_with?("actions/checkout@") }
      expect(checkout.fetch("uses")).to eq("actions/checkout@v6")
      expect(checkout.fetch("with")).to include("fetch-depth" => 0, "persist-credentials" => false, "ref" => "${{ github.sha }}")
    end
    %w[preflight publish].each do |name|
      runs = release.dig("jobs", name, "steps").filter_map { |step| step["run"] }.join("\n")
      expect(runs).to include("git merge-base --is-ancestor", "refs/remotes/origin/main", "refs/tags/$RELEASE_TAG^{commit}",
                             "refs/remotes/origin/maintenance/1.x", "refs/remotes/origin/codex/cucumber-12",
                             "v1.3.1:4ca2f770e0a84e83688f165ba04b4db8ef855cf9", "*) exit 1")
    end
  end

  it "does not cancel publication or collide caller and reusable concurrency groups" do
    expect(ci.dig("concurrency", "cancel-in-progress")).to be(true)
    expect(ci.dig("concurrency", "group")).to include("github.event_name", "github.event.pull_request.number || github.ref")
    expect(release.dig("concurrency", "cancel-in-progress")).to be(false)
    expect(release.dig("concurrency", "group")).to eq("tag-release-${{ github.ref }}")
    expect(validation).not_to have_key("concurrency")
  end

  it "sets an executable Linux Helm path and registers the repository before locked build" do
    steps = validation.dig("jobs", "test", "steps")
    runs = steps.filter_map { |step| step["run"] }.join("\n")
    expect(runs).to include('helm_bin="$(command -v helm)"', 'test -x "$helm_bin"', 'echo "HELM_BIN=$helm_bin" >> "$GITHUB_ENV"')
    expect(runs.index("helm repo add reportportal https://k8s.reportportal.io/")).to be < runs.index("helm repo update")
    expect(runs.index("helm repo update")).to be < runs.index("helm dependency build")
    expect(runs).to include("sha256sum --check", "helm lint", "helm template", "values-local-latest.yaml", "values-production.example.yaml", "values-huawei.example.yaml")
    expect(steps.find { |step| step["uses"] == "azure/setup-helm@v5" }.dig("with", "version")).to eq("v3.18.4")
  end

  it "resolves all four exact maintenance cells outside source without ignoring Bundler config" do
    job = validation.dig("jobs", "test")
    expect(job.fetch("strategy")).to eq("fail-fast" => false, "matrix" => {
      "ruby" => %w[3.1 3.3], "cucumber" => %w[9.2.1 10.2.0]
    })
    expect(job.fetch("env")).to include("BUNDLE_FROZEN" => "false", "CUCUMBER_VERSION" => "${{ matrix.cucumber }}")
    expect(job.fetch("env")).not_to have_key("BUNDLE_IGNORE_CONFIG")
    steps = job.fetch("steps")
    isolation = steps.find { |step| step["name"] == "Isolate matrix dependencies before Ruby setup" }
    expect(isolation.fetch("run")).to include("BUNDLE_GEMFILE=$RUNNER_TEMP/runtime/Gemfile",
                                             "BUNDLE_PATH=$RUNNER_TEMP/runtime-gems",
                                             "BUNDLE_APP_CONFIG=$RUNNER_TEMP/runtime-bundle-config")
    setup = steps.find { |step| step["uses"] == "ruby/setup-ruby@v1" }
    expect(setup.fetch("with")).to eq("ruby-version" => "${{ matrix.ruby }}", "bundler" => "2.6.6", "bundler-cache" => false)
    resolution = steps.find { |step| step["name"] == "Resolve the exact matrix runtime without changing source" }
    expect(resolution.fetch("run")).to include('File.write(ENV.fetch("BUNDLE_GEMFILE")', "eval_gemfile", 'ENV.fetch("CUCUMBER_VERSION")',
                                               "bundle install --jobs 4", 'echo "BUNDLE_FROZEN=true" >> "$GITHUB_ENV"')
    expect(resolution.fetch("run")).not_to include('File.open("Gemfile"', 'rm_f("Gemfile.lock")')
    expect(steps.index(isolation)).to be < steps.index(setup)
    expect(steps.index(setup)).to be < steps.index(resolution)
    provenance = steps.find { |step| step["name"] == "Record the exact matrix runtime" }
    expect(provenance.fetch("run")).to include('ReportportalCucumber::VERSION == "1.3.3"', 'cucumber == ENV.fetch("CUCUMBER_VERSION")',
                                               "RUBY_DESCRIPTION", "Bundler::VERSION", "runtime/runtime.json", "source-dependencies.sha256")
    retain = steps.find { |step| step["name"] == "Retain the exact matrix dependency resolution" }
    expect(retain.fetch("if")).to eq("always()")
    expect(retain.fetch("uses")).to eq("actions/upload-artifact@v6")
    expect(retain.fetch("with")).to include("path" => "${{ runner.temp }}/runtime/", "include-hidden-files" => true,
                                          "if-no-files-found" => "error", "retention-days" => 7)
    expect(retain.dig("with", "name")).to include("matrix.ruby", "matrix.cucumber", "github.run_attempt")
    unchanged = steps.find { |step| step["name"] == "Require unchanged tracked source" }
    expect(unchanged.fetch("if")).to eq("always()")
    expect(unchanged.fetch("run")).to include("git diff --exit-code", 'sha256sum --check "$RUNNER_TEMP/runtime/source-dependencies.sha256"')
  end

  it "packages only after complete RSpec and Cucumber success and passes immutable artifact identity" do
    steps = validation.dig("jobs", "test", "steps")
    commands = steps.filter_map { |step| step["run"] }
    expect(commands.index("bundle exec rspec")).to be < commands.index("bundle exec cucumber")
    expect(commands).to include("bundle exec rspec script/release/spec")
    expect(commands.join).not_to include("script/release/cli.rb build")
    gate = validation.dig("jobs", "gate")
    expect(gate.fetch("needs")).to eq("test")
    expect(gate.fetch("name")).to eq("test")
    expect(gate.fetch("if")).to eq("always()")
    expect(gate.fetch("steps")).to eq([{
      "name" => "Require every maintenance matrix cell", "env" => { "MATRIX_RESULT" => "${{ needs.test.result }}" },
      "run" => 'test "$MATRIX_RESULT" = success'
    }])
    bundle = validation.dig("jobs", "bundle")
    expect(bundle.fetch("needs")).to eq("gate")
    expect(bundle.fetch("if")).to include("inputs.release", "github.event_name == 'push'", "github.ref_type == 'tag'")
    expect(bundle.dig("env", "BUNDLE_GEMFILE")).to eq("${{ github.workspace }}/Gemfile")
    expect(bundle.dig("env", "BUNDLE_FROZEN")).to eq("true")
    expect(bundle.fetch("env")).not_to have_key("BUNDLE_IGNORE_CONFIG")
    bundle_steps = bundle.fetch("steps")
    expect(bundle_steps.filter_map { |step| step["run"] }.last).to include("ruby script/release/cli.rb build")
    expect(validation.dig(true, "workflow_call", "outputs", "artifact-id", "value")).to eq("${{ jobs.bundle.outputs.artifact-id }}")
    expect(bundle.dig("outputs", "artifact-id")).to eq("${{ steps.artifacts.outputs.artifact-id }}")
    download = release.dig("jobs", "publish", "steps").find { |step| step.fetch("uses", "").start_with?("actions/download-artifact@") }
    expect(download.dig("with", "artifact-ids")).to eq("${{ needs.validate.outputs.artifact-id }}")
    expect(bundle_steps.last.dig("with", "if-no-files-found")).to eq("error")
    expect(release.to_s).not_to include("gem push", "workflow_dispatch", "workflow_run")
  end

  it "allows main recovery and limits the exact maintenance controller to 1.x tags" do
    expect(resume.dig("jobs", "preflight", "if"))
      .to eq("github.ref == 'refs/heads/main' || (github.ref == 'refs/heads/maintenance/1.x' && startsWith(inputs.tag, 'v1.'))")
    expect(resume.dig("jobs", "publish", "needs")).to eq("preflight")
    checkout = resume.dig("jobs", "preflight", "steps").first
    expect(checkout.fetch("with")).to include("ref" => "${{ github.sha }}", "fetch-depth" => 0, "persist-credentials" => false)
  end

  it "fails the required gate for failed, cancelled, skipped or missing matrix results" do
    command = validation.dig("jobs", "gate", "steps").first.fetch("run")
    %w[success failure cancelled skipped].push("").each do |result|
      _out, _err, status = Open3.capture3({ "MATRIX_RESULT" => result }, "/bin/bash", "-e", "-c", command)
      expect(status.success?).to eq(result == "success"), "Gate accepted unexpected result #{result.inspect}"
    end
  end

  it "checks stable tags and the controller checkout against its fixed trusted remote before source or API lookup" do
    run = resume.dig("jobs", "preflight", "steps").last.fetch("run")
    expect(run).to include('test "$(git rev-parse HEAD)" = "$GITHUB_SHA"', 'case "$GITHUB_REF" in',
                          "refs/heads/main)", "refs/heads/maintenance/1.x)", '[[ "$RELEASE_TAG" == v1.* ]] || exit 1',
                          'git merge-base --is-ancestor "$GITHUB_SHA" refs/remotes/origin/main',
                          'git merge-base --is-ancestor "$GITHUB_SHA" refs/remotes/origin/maintenance/1.x')
    expect(run.index('[[ "$RELEASE_TAG" =~')).to be < run.index('case "$GITHUB_REF" in')
    expect(run.index('case "$GITHUB_REF" in')).to be < run.index('source_sha=')
    expect(run.index('source_sha=')).to be < run.index('workflow_id=')
  end

  it "requires a completed original tag validation and retained immutable artifacts for draft recovery" do
    expect(resume.fetch(true).keys).to eq(["workflow_dispatch"])
    expect(resume.fetch("permissions")).to eq("contents" => "read", "actions" => "read")
    run = resume.dig("jobs", "preflight", "steps").last.fetch("run")
    expect(run).to include(".status == \"completed\"", ".event == \"push\"", ".head_sha == $sha",
                          ".head_branch == $tag", ".workflow_id == $workflow", '"validate / test"',
                          '.conclusion == "success"', ".expired == false", "git merge-base --is-ancestor")
    expect(run).not_to include("git tag", "--force")
    expect(run).to include("refs/remotes/origin/maintenance/1.x", "refs/remotes/origin/codex/cucumber-12",
                          "v1.3.1:4ca2f770e0a84e83688f165ba04b4db8ef855cf9", "*) exit 1")
    expect(resume.dig("concurrency", "cancel-in-progress")).to be(false)
  end

  it "rechecks the original tag and release ancestry in the recovery source before publication tooling runs" do
    steps = resume.dig("jobs", "publish", "steps")
    guard = steps.find { |step| step["working-directory"] == "release-source" }
    expect(guard.fetch("env")).to eq("RELEASE_TAG" => "${{ inputs.tag }}", "RELEASE_SHA" => "${{ needs.preflight.outputs.source-sha }}")
    expect(guard.fetch("run")).to include('test "$(git rev-parse HEAD)" = "$RELEASE_SHA"',
                                         "refs/tags/$RELEASE_TAG^{commit}", "refs/remotes/origin/maintenance/1.x",
                                         "v1.3.1:4ca2f770e0a84e83688f165ba04b4db8ef855cf9")
    checkout = steps.find { |step| step.dig("with", "path") == "release-source" }
    setup = steps.find { |step| step["uses"] == "ruby/setup-ruby@v1" }
    expect(steps.index(checkout)).to be < steps.index(guard)
    expect(steps.index(guard)).to be < steps.index(setup)
  end

  it "reuses original immutable artifacts and source rather than rebuilding an existing tag" do
    job = resume.dig("jobs", "publish")
    expect(job.fetch("needs")).to eq("preflight")
    expect(job.fetch("permissions")).to eq("contents" => "write", "actions" => "read")
    steps = job.fetch("steps")
    source_checkout = steps.find { |step| step.dig("with", "path") == "release-source" }
    expect(source_checkout.fetch("with")).to include("ref" => "${{ needs.preflight.outputs.source-sha }}",
                                                     "fetch-depth" => 0, "persist-credentials" => false)
    download = steps.find { |step| step.fetch("uses", "").start_with?("actions/download-artifact@") }
    expect(download.fetch("with")).to include("run-id" => "${{ inputs.source_run_id }}",
                                               "artifact-ids" => "${{ needs.preflight.outputs.artifact-id }}")
    expect(steps.last.dig("env", "RELEASE_SOURCE_ROOT")).to eq("${{ github.workspace }}/release-source")
    expect(steps.last.fetch("run")).to include("script/release/cli.rb publish")
    expect(steps.filter_map { |step| step["run"] }.join).not_to include(" build ", "gem push", "--clobber")
  end
end
