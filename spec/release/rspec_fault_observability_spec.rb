# frozen_string_literal: true

require "rspec"
require "yaml"
require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "RSpec fault diagnostic retention" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:validation) { YAML.load_file(File.join(root, ".github/workflows/validate.yml")) }

  def steps(job)
    validation.fetch("jobs").fetch(job).fetch("steps")
  end

  def named_step(job, name)
    steps(job).find { |step| step["name"] == name } || raise("Missing #{job} step: #{name}")
  end

  def prepare(job)
    named_step(job, "Prepare synthetic RSpec fault diagnostics")
  end

  def retention(job)
    named_step(job, "Retain synthetic RSpec fault diagnostics")
  end

  it "keeps the full current RSpec command literal and scopes capture inputs to its step" do
    suite = named_step("test", "Run full RSpec including installed packaging checks")
    expect(suite.fetch("run")).to eq("bundle exec rspec")
    expect(suite.fetch("env")).to eq(
      "DAY2_LOCAL_CAPTURE" => "${{ runner.temp }}/rspec-fault-diagnostics/day2",
      "M4_D_EVIDENCE_DIR" => "${{ runner.temp }}/rspec-fault-diagnostics/m4d"
    )
    expect(steps("test").index(prepare("test"))).to be < steps("test").index(suite)
    expect(prepare("test").fetch("run")).not_to include("GITHUB_ENV")
    cucumber = named_step("test", "Run full offline Cucumber profile")
    expect(cucumber.fetch("run")).to eq("bundle exec cucumber")
    expect(cucumber.fetch("env", {})).not_to have_key("DAY2_LOCAL_CAPTURE")
    expect(cucumber.fetch("env", {})).not_to have_key("M4_D_EVIDENCE_DIR")
  end

  it "hands legacy captures to the unchanged full suite without replacing its original environment or arguments" do
    suite = named_step("legacy", "Run the legacy RSpec suite with explicit test-only fixture normalization")
    expect(suite.fetch("env")).to eq("M4A_CHILD_EVIDENCE_DIR" => "${{ runner.temp }}/legacy-m4a")
    expect(suite.fetch("run").lines.first.chomp).to eq("legacy_args=(")
    expect(suite.fetch("run").lines.last.chomp).to eq('bundle exec rspec "${legacy_args[@]}"')
    expect(suite.fetch("run")).to include(
      'bundle exec rspec "${legacy_args[@]}" --dry-run --format json --out "$RUNNER_TEMP/legacy-discovery.json"',
      'summary.fetch("example_count") == 889', 'ids.uniq.length == 889',
      'summary.fetch("failure_count").zero?', 'summary.fetch("pending_count").zero?'
    )
    expect(steps("legacy").index(prepare("legacy"))).to be < steps("legacy").index(suite)
    expect(named_step("legacy", "Run the full released baseline offline Cucumber profile").fetch("run"))
      .to eq("bundle exec cucumber")
  end

  { "test" => "rspec-fault-diagnostics", "legacy" => "legacy-rspec-fault-diagnostics" }.each do |job, directory|
    it "prepares only #{job}'s synthetic capture directories and exports only the intended legacy inputs" do
      Dir.mktmpdir("workflow-fault-captures-") do |temporary|
        environment_file = File.join(temporary, "github-env")
        File.write(environment_file, "")
        command = prepare(job).fetch("run")
        stdout, stderr, status = Open3.capture3(
          { "RUNNER_TEMP" => temporary, "GITHUB_ENV" => environment_file },
          "/bin/bash", "-e", "-o", "pipefail", "-c", command
        )
        expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
        expect(stdout).to eq("")
        expect(stderr).to eq("")
        expect(Dir.children(temporary)).to contain_exactly(directory, "github-env")
        capture = File.join(temporary, directory)
        expect(Dir.children(capture)).to contain_exactly("day2", "m4d")
        %w[day2 m4d].each do |name|
          path = File.join(capture, name)
          expect(File.directory?(path)).to be(true)
          expect(File.stat(path).mode & 0o777).to eq(0o700)
        end
        expected = job == "legacy" ? [
          "DAY2_LOCAL_CAPTURE=#{capture}/day2\n", "M4_D_EVIDENCE_DIR=#{capture}/m4d\n"
        ] : []
        expect(File.readlines(environment_file)).to eq(expected)
      end
    end

    it "always retains only #{job}'s selected synthetic directory, including spool metadata" do
      upload = retention(job)
      expect(upload.fetch("uses")).to eq("actions/upload-artifact@v6")
      expect(upload.fetch("if")).to eq("always()")
      expect(upload).not_to have_key("continue-on-error")
      expect(upload.fetch("with")).to include(
        "path" => "${{ runner.temp }}/#{directory}/", "include-hidden-files" => true,
        "retention-days" => 7, "if-no-files-found" => "warn"
      )
      name = job == "test" ? 'rspec-faults-ruby-${{ matrix.ruby }}-${{ github.run_attempt }}' :
        'legacy-rspec-faults-ruby-${{ matrix.ruby }}-cucumber-${{ matrix.cucumber }}-${{ github.run_attempt }}'
      expect(upload.dig("with", "name")).to eq(name)
      suite = steps(job).find { |step| step.fetch("run", "").include?("bundle exec rspec") }
      expect(steps(job).index(upload)).to be > steps(job).index(suite)
      expect(upload.dig("with", "path")).not_to match(/\*|\.\.|GITHUB_ENV|workspace|credentials/i)
    end
  end

  it "keeps native console output and avoids inherited RSpec formatting or failure suppression" do
    %w[test legacy].each do |job|
      definition = validation.fetch("jobs").fetch(job)
      expect(definition.fetch("env").keys).not_to include("SPEC_OPTS", "RSPEC_OPTS", "RUBYOPT")
      definition.fetch("steps").each do |step|
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
  end

  it "leaves matrix selection, frozen provenance, existing legacy artifacts, and release upload ordering intact" do
    expect(validation.dig("jobs", "test", "strategy", "matrix")).to eq("ruby" => %w[3.3 3.4])
    expect(validation.dig("jobs", "legacy", "strategy", "matrix"))
      .to eq("ruby" => %w[3.1 3.3], "cucumber" => %w[9 10])
    checkout = steps("legacy").find { |step| step["uses"] == "actions/checkout@v6" }
    expect(checkout.dig("with", "ref")).to eq("4ca2f770e0a84e83688f165ba04b4db8ef855cf9")
    original_upload = named_step("legacy", "Retain the exact legacy dependency resolution")
    expect(steps("legacy").index(original_upload)).to be < steps("legacy").index(retention("legacy"))
    expect(original_upload.dig("with", "path")).not_to include("rspec-fault-diagnostics")
    expect(steps("bundle").last).to include("name" => "Preserve validated release bundle", "id" => "artifacts")
    expect(steps("bundle").last.dig("with", "path")).to eq("${{ runner.temp }}/release-bundle/")
    expect(steps("bundle").filter_map { |step| step["run"] }.last)
      .to include('script/release/cli.rb build "$RELEASE_TAG" "$RELEASE_SHA"')
    expect(steps("bundle").map { |step| step["name"] }).not_to include("Retain synthetic RSpec fault diagnostics")
  end
end
