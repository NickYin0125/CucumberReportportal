# frozen_string_literal: true

require "rspec"
require "yaml"

RSpec.describe "Release workflow security and validation contract" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:ci) { YAML.load_file(File.join(root, ".github/workflows/ci.yml")) }
  let(:validation) { YAML.load_file(File.join(root, ".github/workflows/validate.yml")) }
  let(:release) { YAML.load_file(File.join(root, ".github/workflows/release.yml")) }

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

  it "has full tag/main history with non-persisted credentials and Node24 checkout" do
    jobs = [validation.dig("jobs", "test"), release.dig("jobs", "preflight"), release.dig("jobs", "publish")]
    jobs.each do |job|
      checkout = job.fetch("steps").find { |step| step.fetch("uses", "").start_with?("actions/checkout@") }
      expect(checkout.fetch("uses")).to eq("actions/checkout@v6")
      expect(checkout.fetch("with")).to include("fetch-depth" => 0, "persist-credentials" => false, "ref" => "${{ github.sha }}")
    end
    %w[preflight publish].each do |name|
      runs = release.dig("jobs", name, "steps").filter_map { |step| step["run"] }.join("\n")
      expect(runs).to include("git merge-base --is-ancestor", "refs/remotes/origin/main", "refs/tags/$RELEASE_TAG^{commit}")
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

  it "keeps the Bundler installation config and explicitly selects the packaging Gemfile" do
    env = validation.dig("jobs", "test", "env")
    expect(env.fetch("BUNDLE_GEMFILE")).to eq("${{ github.workspace }}/Gemfile")
    expect(env.fetch("BUNDLE_FROZEN")).to eq("true")
    expect(env).not_to have_key("BUNDLE_IGNORE_CONFIG")
    setup = validation.dig("jobs", "test", "steps").find { |step| step["uses"] == "ruby/setup-ruby@v1" }
    expect(setup.fetch("with")).to include("ruby-version" => "3.3", "bundler-cache" => true)
  end

  it "packages only after complete RSpec and Cucumber success and passes immutable artifact identity" do
    steps = validation.dig("jobs", "test", "steps")
    commands = steps.filter_map { |step| step["run"] }
    expect(commands.index("bundle exec rspec")).to be < commands.index("bundle exec cucumber")
    expect(commands.last).to include("ruby script/release/cli.rb build")
    expect(steps.last.fetch("if")).to include("inputs.release", "github.event_name == 'push'", "github.ref_type == 'tag'")
    download = release.dig("jobs", "publish", "steps").find { |step| step.fetch("uses", "").start_with?("actions/download-artifact@") }
    expect(download.dig("with", "artifact-ids")).to eq("${{ needs.validate.outputs.artifact-id }}")
    expect(steps.last.dig("with", "if-no-files-found")).to eq("error")
    expect(release.to_s).not_to include("gem push", "workflow_dispatch", "workflow_run")
  end
end
