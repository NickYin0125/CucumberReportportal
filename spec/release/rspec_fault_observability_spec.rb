# frozen_string_literal: true

require "rspec"
require "yaml"
require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "RSpec fault diagnostic retention" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:validation) { YAML.load_file(File.join(root, ".github/workflows/validate.yml")) }
  let(:job) { validation.fetch("jobs").fetch("test") }
  let(:steps) { job.fetch("steps") }

  def named_step(name)
    steps.find { |step| step["name"] == name } || raise("Missing validation step: #{name}")
  end

  it "keeps the full RSpec command literal and scopes capture inputs to its step" do
    suite = named_step("Run full RSpec including installed packaging checks")
    expect(suite.fetch("run")).to eq("bundle exec rspec")
    expect(suite.fetch("env")).to eq(
      "DAY2_LOCAL_CAPTURE" => "${{ runner.temp }}/rspec-fault-diagnostics/day2",
      "M4_D_EVIDENCE_DIR" => "${{ runner.temp }}/rspec-fault-diagnostics/m4d"
    )
    prepare = named_step("Prepare synthetic RSpec fault diagnostics")
    expect(steps.index(prepare)).to be < steps.index(suite)
    expect(prepare.fetch("run")).not_to include("GITHUB_ENV")
    cucumber = named_step("Run full offline Cucumber profile")
    expect(cucumber.fetch("run")).to eq("bundle exec cucumber")
    expect(cucumber.fetch("env", {})).not_to have_key("DAY2_LOCAL_CAPTURE")
    expect(cucumber.fetch("env", {})).not_to have_key("M4_D_EVIDENCE_DIR")
  end

  it "prepares only the two private synthetic capture directories without exporting global inputs" do
    Dir.mktmpdir("workflow-fault-captures-") do |temporary|
      environment_file = File.join(temporary, "github-env")
      File.write(environment_file, "")
      stdout, stderr, status = Open3.capture3(
        { "RUNNER_TEMP" => temporary, "GITHUB_ENV" => environment_file },
        "/bin/bash", "-e", "-o", "pipefail", "-c",
        named_step("Prepare synthetic RSpec fault diagnostics").fetch("run")
      )
      expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
      expect(stdout).to eq("")
      expect(stderr).to eq("")
      expect(Dir.children(temporary)).to contain_exactly("rspec-fault-diagnostics", "github-env")
      capture = File.join(temporary, "rspec-fault-diagnostics")
      expect(Dir.children(capture)).to contain_exactly("day2", "m4d")
      %w[day2 m4d].each do |name|
        path = File.join(capture, name)
        expect(File.directory?(path)).to be(true)
        expect(File.stat(path).mode & 0o777).to eq(0o700)
      end
      expect(File.read(environment_file)).to eq("")
    end
  end

  it "always retains only the selected synthetic directory including spool metadata" do
    upload = named_step("Retain synthetic RSpec fault diagnostics")
    expect(upload.fetch("uses")).to eq("actions/upload-artifact@v6")
    expect(upload.fetch("if")).to eq("always()")
    expect(upload).not_to have_key("continue-on-error")
    expect(upload.fetch("with")).to eq(
      "name" => 'rspec-faults-ruby-3.3-${{ github.run_attempt }}',
      "path" => "${{ runner.temp }}/rspec-fault-diagnostics/",
      "include-hidden-files" => true, "retention-days" => 7, "if-no-files-found" => "warn"
    )
    expect(steps.index(upload)).to be > steps.index(named_step("Run full RSpec including installed packaging checks"))
    expect(upload.dig("with", "path")).not_to match(/\*|\.\.|GITHUB_ENV|workspace|credentials/i)
  end

  it "keeps console output and avoids inherited formatting, runtime budgets or failure suppression" do
    expect(job.fetch("env").keys).not_to include("SPEC_OPTS", "RSPEC_OPTS", "RUBYOPT")
    steps.each do |step|
      expect(step.fetch("env", {}).keys).not_to include("SPEC_OPTS", "RSPEC_OPTS", "RUBYOPT",
                                                        "RP_EXIT_FLUSH_TIMEOUT_MS")
      command = step.fetch("run", "")
      expect(command).not_to match(/SPEC_OPTS|RSPEC_OPTS|--only-failures|--next-failure|--fail-fast|\|\s*tee|\|\|\s*true/)
      next unless command.include?("bundle exec rspec")

      expect(step).not_to have_key("continue-on-error")
      expect(step).not_to have_key("shell")
      expect(step).not_to have_key("if")
      expect(command).not_to include("--format progress", "rspec.json", "2>&1", "> /dev/null")
    end
  end

  it "preserves the approved 1.x CI runtime and last release artifact step" do
    expect(job).not_to have_key("strategy")
    setup = steps.find { |step| step["uses"] == "ruby/setup-ruby@v1" }
    expect(setup.fetch("with")).to eq("ruby-version" => "3.3", "bundler-cache" => true)
    expect(job.dig("outputs", "artifact-id")).to eq("${{ steps.artifacts.outputs.artifact-id }}")
    expect(steps.last).to include("name" => "Preserve validated release bundle", "id" => "artifacts")
    expect(steps.last.fetch("if")).to include("inputs.release", "github.event_name == 'push'", "github.ref_type == 'tag'")
    expect(steps.last.dig("with", "path")).to eq("${{ runner.temp }}/release-bundle/")
    expect(steps.last.dig("with", "if-no-files-found")).to eq("error")
    expect(steps.filter_map { |step| step["run"] }.last)
      .to include('script/release/cli.rb build "$RELEASE_TAG" "$RELEASE_SHA"')
  end
end
