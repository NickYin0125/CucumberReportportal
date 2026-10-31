# frozen_string_literal: true

require "rspec"
require "yaml"
require "fileutils"
require "json"
require "open3"
require "shellwords"
require "tmpdir"

RSpec.describe "Release workflow security and validation contract" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:ci) { YAML.load_file(File.join(root, ".github/workflows/ci.yml")) }
  let(:validation) { YAML.load_file(File.join(root, ".github/workflows/validate.yml")) }
  let(:release) { YAML.load_file(File.join(root, ".github/workflows/release.yml")) }
  let(:resume) { YAML.load_file(File.join(root, ".github/workflows/release-resume.yml")) }
  let(:rebuild) { YAML.load_file(File.join(root, ".github/workflows/release-rebuild.yml")) }

  it "keeps packaging source clean without hiding untracked dependency files" do
    steps = validation.dig("jobs", "bundle", "steps")
    setup = steps.find { |step| step["uses"] == "ruby/setup-ruby@v1" }
    expect(setup.fetch("with")).not_to have_key("bundler-cache")
    build = steps.find { |step| step["name"] == "Build verified release bundle" }
    expect(build.fetch("run")).to start_with("ruby script/release/cli.rb build")
    expect(steps.to_s).not_to include("bundle install", "bundle exec", "git clean", "--untracked-files=no")
  end

  it "rebuilds only validated unpublished tags from original source with separate write permissions" do
    expect(rebuild.fetch(true).keys).to eq(["workflow_dispatch"])
    expect(rebuild.fetch("permissions")).to eq("contents" => "read", "actions" => "read")
    expect(rebuild.dig("jobs", "preflight", "if")).to eq("github.ref == 'refs/heads/main'")
    proof = rebuild.dig("jobs", "preflight", "steps").last.fetch("run")
    expect(proof).to include("rebuild_gate.rb", "--paginate --slurp", "jobs?filter=latest",
                            "refs/tags/$RELEASE_TAG^{commit}", "refs/remotes/origin/main")
    expect(rebuild.dig("concurrency", "group")).to eq(resume.dig("concurrency", "group"))
    expect(rebuild.dig("concurrency", "cancel-in-progress")).to be(false)
    expect(rebuild.dig("jobs", "rebuild", "needs")).to eq("preflight")
    expect(rebuild.dig("jobs", "publish", "needs")).to contain_exactly("preflight", "rebuild")
    %w[rebuild publish].each do |name|
      steps = rebuild.dig("jobs", name, "steps")
      checkout = steps.find { |step| step["uses"] == "actions/checkout@v6" }
      expect(checkout.fetch("with")).to include("ref" => "${{ needs.preflight.outputs.source-sha }}",
                                                "persist-credentials" => false, "fetch-depth" => 0)
      expect(steps.to_s).not_to include("bundler-cache", "bundle install", "git tag", "--force")
    end
    expect(rebuild.dig("jobs", "rebuild")).not_to have_key("permissions")
    expect(rebuild.dig("jobs", "publish", "permissions")).to include("contents" => "write")
    download = rebuild.dig("jobs", "publish", "steps").find { |step| step["uses"] == "actions/download-artifact@v7" }
    expect(download.dig("with", "artifact-ids")).to eq("${{ needs.rebuild.outputs.artifact-id }}")
  end

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
    expect(setup.fetch("with")).to include("ruby-version" => "${{ matrix.ruby }}", "bundler-cache" => true)
    expect(validation.dig("jobs", "test", "strategy", "matrix", "ruby")).to eq(%w[3.3 3.4])
  end

  it "packages only after complete RSpec and Cucumber success and passes immutable artifact identity" do
    steps = validation.dig("jobs", "test", "steps")
    commands = steps.filter_map { |step| step["run"] }
    expect(commands.index("bundle exec rspec")).to be < commands.index("bundle exec cucumber")
    gate = validation.dig("jobs", "gate")
    expect(gate.fetch("needs")).to contain_exactly("test", "legacy")
    expect(gate.fetch("if")).to eq("always()")
    expect(gate.fetch("steps").last.fetch("run")).to include('test "$CURRENT_RESULT" = success', 'test "$LEGACY_RESULT" = success')
    artifact_job = validation.dig("jobs", "bundle")
    expect(artifact_job.fetch("needs")).to eq("gate")
    expect(artifact_job.fetch("steps").filter_map { |step| step["run"] }.last).to include("ruby script/release/cli.rb build")
    expect(artifact_job.fetch("if")).to include("inputs.release", "github.event_name == 'push'", "github.ref_type == 'tag'")
    download = release.dig("jobs", "publish", "steps").find { |step| step.fetch("uses", "").start_with?("actions/download-artifact@") }
    expect(download.dig("with", "artifact-ids")).to eq("${{ needs.validate.outputs.artifact-id }}")
    expect(artifact_job.fetch("steps").last.dig("with", "if-no-files-found")).to eq("error")
    expect(validation.fetch(true).dig("workflow_call", "outputs", "artifact-id", "value")).to eq("${{ jobs.bundle.outputs.artifact-id }}")
    expect(release.to_s).not_to include("gem push", "workflow_dispatch", "workflow_run")
  end

  it "allows draft recovery only from main and a completed original tag validation" do
    expect(resume.fetch(true).keys).to eq(["workflow_dispatch"])
    expect(resume.dig("jobs", "preflight", "if")).to eq("github.ref == 'refs/heads/main'")
    expect(resume.fetch("permissions")).to eq("contents" => "read", "actions" => "read")
    run = resume.dig("jobs", "preflight", "steps").last.fetch("run")
    expect(run).to include(".status == \"completed\"", ".event == \"push\"", ".head_sha == $sha",
                          ".head_branch == $tag", ".workflow_id == $workflow", '"validate / test"',
                          '"validate / gate"', '"validate / bundle"',
                          '$tag == "v1.3.1"', '$sha == "4ca2f770e0a84e83688f165ba04b4db8ef855cf9"',
                          '.conclusion == "success"', ".expired == false", "git merge-base --is-ancestor")
    expect(run).not_to include("git tag", "--force")
    expect(resume.dig("concurrency", "cancel-in-progress")).to be(false)
  end

  it "tests real immutable legacy source across supported Ruby/Cucumber cells without altering its gemspec" do
    legacy = validation.dig("jobs", "legacy")
    expect(legacy.dig("strategy", "matrix")).to eq("ruby" => %w[3.1 3.3], "cucumber" => %w[9 10])
    steps = legacy.fetch("steps")
    checkout = steps.find { |step| step["uses"] == "actions/checkout@v6" }
    expect(checkout.dig("with", "ref")).to eq("4ca2f770e0a84e83688f165ba04b4db8ef855cf9")
    driver = steps.find { |step| step.dig("with", "path") == ".ci-driver" }
    expect(driver.fetch("with")).to include("ref" => "${{ github.sha }}", "persist-credentials" => false,
                                             "sparse-checkout-cone-mode" => false)
    drivers = %w[legacy_fault_process.rb legacy_portability.rb legacy_portability_specs.rb]
      .map { |name| "spec/fixtures/#{name}" }
    expect(driver.dig("with", "sparse-checkout").lines.map(&:strip)).to eq(drivers)
    expect(legacy.dig("env", "LEGACY_SOURCE_ROOT")).to eq("${{ github.workspace }}")
    runs = steps.filter_map { |step| step["run"] }.join("\n")
    expect(runs).to include("bundle exec rspec", "bundle exec cucumber", "bundle install --jobs 4",
                           "refs/tags/v1.3.1^{commit}", "git diff --exit-code -- . ':!Gemfile' ':!Gemfile.lock'")
    originals = %w[spec/day2/fault_process_spec.rb spec/reportportal_cucumber/cucumber/world_spec.rb
                   spec/reportportal_cucumber/cucumber/m4a_public_delivery_integration_spec.rb]
    suite = steps.find { |step| step.fetch("run", "").include?("legacy_args=(") }
    normalized = suite.fetch("run")
    arguments = Shellwords.split(normalized.match(/\Alegacy_args=\((.*?)\n\)/m)[1])
    expect(arguments).to eq(["spec", ".ci-driver/spec/fixtures/legacy_fault_process.rb",
      ".ci-driver/spec/fixtures/legacy_portability_specs.rb", "--exclude-pattern",
      "spec/{#{originals.map { |path| path.delete_prefix('spec/') }.join(',')}}"])
    expect(normalized).to include('bundle exec rspec "${legacy_args[@]}" --dry-run --format json',
                                  'bundle exec rspec "${legacy_args[@]}"')
    expect(suite.fetch("env")).to eq("M4A_CHILD_EVIDENCE_DIR" => "${{ runner.temp }}/legacy-m4a")
    audit = steps.find { |step| step["name"] == "Require unchanged baseline production source" }
    expect(audit.fetch("if")).to eq("always()")
    expect(audit.fetch("run")).to include("sha256sum --check .ci-driver/legacy-production.sha256",
                                          *originals, *drivers.map { |path| ".ci-driver/#{path}" })
    artifacts = steps.find { |step| step["uses"] == "actions/upload-artifact@v6" }
    expect(artifacts.fetch("if")).to eq("always()")
    expect(artifacts.dig("with", "include-hidden-files")).to be(true)
    expect(artifacts.dig("with", "path").lines.map(&:strip)).to contain_exactly(
      "Gemfile.lock", *originals, *drivers.map { |path| ".ci-driver/#{path}" },
      ".ci-driver/legacy-production.sha256", "${{ runner.temp }}/legacy-m4a/public-delivery-child.json",
      "${{ runner.temp }}/legacy-m4a/attempt-admissions.ndjson", "${{ runner.temp }}/legacy-discovery.json"
    )
    original = File.read(File.join(root, "spec/fixtures/legacy_fault_process.rb"))
    expect(original).to include("4b2e01d3343dba4d1d902b8cc835e7c29a82893efb87241453783fcb379ced70",
                               'Gem.loaded_specs.fetch("cucumber").version.to_s')
    expect(runs).not_to include('File.write("reportportal-cucumber-ruby.gemspec"', "gem push", "kubectl apply")
  end

  it "executes the exact legacy workflow discovery and rejects the former duplicate-loading command" do
    step = validation.dig("jobs", "legacy", "steps").find { |entry| entry.fetch("run", "").include?("legacy_args=(") }
    command = step.fetch("run")
    originals = {
      "spec/day2/fault_process_spec.rb" => 7,
      "spec/reportportal_cucumber/cucumber/world_spec.rb" => 8,
      "spec/reportportal_cucumber/cucumber/m4a_public_delivery_integration_spec.rb" => 1
    }
    retained = {
      "spec/remaining_spec.rb" => 873,
      ".ci-driver/spec/fixtures/legacy_fault_process.rb" => 7,
      ".ci-driver/spec/fixtures/legacy_portability_specs.rb" => 9
    }
    correct = "spec/{#{originals.keys.map { |path| path.delete_prefix('spec/') }.join(',')}}"
    broken = "{#{originals.keys.join(',')}}"
    expect(command.scan(correct).length).to eq(1)

    Dir.mktmpdir("legacy-discovery-") do |directory|
      originals.merge(retained).each do |relative, count|
        path = File.join(directory, relative)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, <<~RUBY)
          File.open(ENV.fetch("DISCOVERY_LOAD_AUDIT"), "a") { |file| file.puts([Process.pid, #{relative.inspect}].join("\t")) }
          RSpec.describe #{relative.inspect} do
            #{count}.times { |index| it("case \#{index}") {} }
          end
        RUBY
      end

      { "correct" => command, "broken" => command.sub(correct, broken) }.each do |variant, script|
        output = File.join(directory, variant)
        FileUtils.mkdir_p(output)
        audit = File.join(output, "loads.tsv")
        env = { "BUNDLE_GEMFILE" => File.join(root, "Gemfile"), "RUNNER_TEMP" => output,
                "DISCOVERY_LOAD_AUDIT" => audit }
        stdout, stderr, status = Open3.capture3(env, "/bin/bash", "-e", "-o", "pipefail", "-c", script, chdir: directory)
        discovery = JSON.parse(File.read(File.join(output, "legacy-discovery.json")))
        examples = discovery.fetch("examples")
        loads = File.readlines(audit).map { |line| line.strip.split("\t", 2) }.group_by(&:first)
        expect(examples.map { |example| example.fetch("id") }.uniq.length).to eq(examples.length)

        if variant == "correct"
          expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
          expect(examples.length).to eq(889)
          expect(examples.group_by { |example| example.fetch("file_path").delete_prefix("./") }.transform_values(&:length)).to eq(retained)
          expect(loads.length).to eq(2), "discovery and full run must each load their own fixtures"
          loads.each_value { |entries| expect(entries.map(&:last)).to contain_exactly(*retained.keys) }
          expect(stdout).to include("889 examples, 0 failures")
        else
          expect(status.success?).to be(false), "the malformed pattern must stop at the discovery gate"
          expect(examples.length).to eq(905)
          expect(loads.length).to eq(1), "no full run is permitted after duplicate discovery"
          expect(loads.values.first.map(&:last)).to contain_exactly(*originals.keys, *retained.keys)
          expect(stdout).not_to include("905 examples, 0 failures")
        end
      end
    end
  end

  it "uses fixed release-line ancestry checks and rejects all unsupported major tags" do
    [release.dig("jobs", "preflight"), release.dig("jobs", "publish"), resume.dig("jobs", "preflight")].each do |job|
      scripts = job.fetch("steps").filter_map { |step| step["run"] }.join("\n")
      expect(scripts).to include("refs/remotes/origin/maintenance/1.x", "refs/remotes/origin/codex/cucumber-12", "v1.3.1:4ca2f770e0a84e83688f165ba04b4db8ef855cf9", "*) exit 1")
      expect(scripts).not_to include("RELEASE_BRANCH", "ANCESTRY_REF")
    end
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
