# frozen_string_literal: true

require "json"
require "tmpdir"
require_relative "../../script/acceptance/presentation_ledger_developer"

RSpec.describe "Developer Ledger source dependency activation" do
  let(:activation) { File.join(LedgerDeveloper::Runner::HOME, "activation.rb") }

  around do |example|
    Dir.mktmpdir("ledger-activation-spec-") do |scratch|
      @scratch = scratch
      @sdk = File.join(scratch, "sdk")
      @cache = File.join(scratch, "cache")
      @global = File.join(scratch, "global")
      FileUtils.mkdir_p([@sdk, @cache, @global])
      installed(@cache, "cucumber-cucumber-expressions", "18.0.1")
      installed(@global, "cucumber-cucumber-expressions", "19.0.1")
      installed(@cache, "cucumber", "10.2.0", "cucumber-cucumber-expressions" => [">= 17", "< 20"])
      sdk
      example.run
    end
  end

  def installed(home, name, version, dependencies = {})
    spec = Gem::Specification.new do |gem|
      gem.name, gem.version, gem.summary, gem.authors = name, version, "Activation regression fixture", ["Test"]
      dependencies.each { |dependency, requirements| gem.add_dependency(dependency, *requirements) }
    end
    FileUtils.mkdir_p([File.join(home, "specifications"), File.join(home, "gems", spec.full_name, "lib")])
    File.write(File.join(home, "specifications", "#{spec.full_name}.gemspec"), spec.to_ruby)
    if name == "cucumber-cucumber-expressions"
      directory = File.join(home, "gems", spec.full_name, "lib", "cucumber")
      FileUtils.mkdir_p(directory)
      File.write(File.join(directory, "cucumber_expressions.rb"), "# Synthetic activation fixture, not Cucumber execution.\n")
    end
  end

  def sdk(cucumber: [">= 9", "< 11"], expressions: [">= 17", "< 19"], ruby: ">= 3.1", extra: {})
    spec = Gem::Specification.new do |gem|
      gem.name, gem.version, gem.summary, gem.authors = "reportportal-cucumber-ruby", "1.3.2", "Selected source fixture", ["Test"]
      gem.required_ruby_version = ruby
      gem.add_dependency("cucumber", *cucumber)
      gem.add_dependency("cucumber-cucumber-expressions", *expressions) if expressions
      extra.each { |dependency, requirements| gem.add_dependency(dependency, *requirements) }
    end
    File.write(File.join(@sdk, "reportportal-cucumber-ruby.gemspec"), spec.to_ruby)
  end

  def child_env
    { "PATH" => ENV["PATH"], "HOME" => @scratch, "GEM_HOME" => @global,
      "GEM_PATH" => @cache,
      "LEDGER_SDK_ROOT" => @sdk, "LEDGER_CUCUMBER" => "10.2.0" }
  end

  def invoke(code = "LedgerDeveloper::Activation.activate!; puts JSON.generate(LedgerDeveloper::Activation.provenance)", env = {})
    Open3.capture3(child_env.merge(env), RbConfig.ruby, "-r", activation, "-e", code, unsetenv_others: true)
  end

  it "reproduces unconstrained global expressions 19 winning over the selected cache's 18" do
    stdout, stderr, status = invoke('gem "cucumber", "10.2.0"; require "cucumber/cucumber_expressions"; puts Gem.loaded_specs.fetch("cucumber-cucumber-expressions").version')
    expect(status.success?).to be(true), stderr
    expect(stdout.strip).to eq("19.0.1")
  end

  it "resolves the selected legacy gemspec before Cucumber and records expressions 18 with its path" do
    stdout, stderr, status = invoke
    expect(status.success?).to be(true), stderr
    result = JSON.parse(stdout)
    expect(result.fetch("cucumber_expressions")).to eq("18.0.1")
    expect(result.fetch("gems").fetch("cucumber-cucumber-expressions").fetch("path")).to start_with(File.realpath(@cache))
    expect(result.fetch("requirements").fetch("cucumber-cucumber-expressions")).to eq(">= 17, < 19")
    expect(result.fetch("sdk_gemspec_sha256")).to eq(Digest::SHA256.file(File.join(@sdk, "reportportal-cucumber-ruby.gemspec")).hexdigest)
  end

  it "applies all selected SDK runtime dependencies, not just the expressions workaround" do
    installed(@cache, "ledger-dependency", "1.0.0")
    installed(@global, "ledger-dependency", "2.0.0")
    sdk(extra: { "ledger-dependency" => ["< 2"] })
    stdout, stderr, status = invoke
    expect(status.success?).to be(true), stderr
    expect(JSON.parse(stdout).fetch("gems").fetch("ledger-dependency").fetch("version")).to eq("1.0.0")
  end

  it "allows the selected Cucumber 9 lane with the same legacy constraints" do
    installed(@cache, "cucumber", "9.2.1", "cucumber-cucumber-expressions" => [">= 17", "< 20"])
    stdout, stderr, status = invoke("LedgerDeveloper::Activation.activate!; puts JSON.generate(LedgerDeveloper::Activation.provenance)", "LEDGER_CUCUMBER" => "9.2.1")
    expect(status.success?).to be(true), stderr
    expect(JSON.parse(stdout)).to include("cucumber" => "9.2.1", "cucumber_expressions" => "18.0.1")
  end

  it "uses a Cucumber 12 source contract without imposing legacy expressions constraints" do
    installed(@cache, "cucumber-cucumber-expressions", "20.1.0")
    installed(@cache, "cucumber", "12.0.1", "cucumber-cucumber-expressions" => [">= 20", "< 21"])
    sdk(cucumber: ["~> 12.0", ">= 12.0.1"], expressions: nil)
    stdout, stderr, status = invoke("LedgerDeveloper::Activation.activate!; puts JSON.generate(LedgerDeveloper::Activation.provenance)", "LEDGER_CUCUMBER" => "12.0.1")
    expect(status.success?).to be(true), stderr
    expect(JSON.parse(stdout).fetch("cucumber_expressions")).to eq("20.1.0")
  end

  it "rejects an unsupported Cucumber before activation" do
    _stdout, stderr, status = invoke("LedgerDeveloper::Activation.activate!", "LEDGER_CUCUMBER" => "12.0.1")
    expect(status.success?).to be(false)
    expect(stderr).to include("Selected SDK requires cucumber", "requested cucumber 12.0.1")
  end

  it "rejects the selected SDK's Ruby minimum before activating dependencies" do
    sdk(ruby: ">= 999")
    _stdout, stderr, status = invoke
    expect(status.success?).to be(false)
    expect(stderr).to include("requires Ruby >= 999")
  end

  it "fails closed when only incompatible expressions remain installed" do
    File.unlink(File.join(@cache, "specifications", "cucumber-cucumber-expressions-18.0.1.gemspec"))
    _stdout, stderr, status = invoke
    expect(status.success?).to be(false)
    expect(stderr).to include("cucumber-cucumber-expressions")
  end

  it "rejects an incompatible already activated gem instead of changing its version silently" do
    _stdout, stderr, status = invoke('gem "cucumber-cucumber-expressions", "19.0.1"; LedgerDeveloper::Activation.activate!')
    expect(status.success?).to be(false)
    expect(stderr).to include("cucumber-cucumber-expressions")
  end

  it "does not infer a dependency contract when the selected source gemspec is missing" do
    File.unlink(File.join(@sdk, "reportportal-cucumber-ruby.gemspec"))
    _stdout, stderr, status = invoke
    expect(status.success?).to be(false)
    expect(stderr).to include("Cannot load selected SDK gemspec")
  end

  it "uses the identical bootstrap in the probe and CLI" do
    expect(LedgerDeveloper::Runner::PROBE).to start_with(LedgerDeveloper::Runner::BOOTSTRAP)
    expect(LedgerDeveloper::Runner::CLI).to start_with(LedgerDeveloper::Runner::BOOTSTRAP)
  end

  it "retains child activation evidence and rejects drift before executing Cucumber" do
    stdout, stderr, status = invoke
    expect(status.success?).to be(true), stderr
    expected = File.join(@scratch, "expected.json")
    report = File.join(@scratch, "activation.json")
    marker = File.join(@scratch, "executed")
    File.write(expected, stdout)
    code = "LedgerDeveloper::Activation.activate!; File.write(#{marker.dump}, 'executed')"
    _stdout, stderr, status = invoke(code, "LEDGER_EXPECTED_ACTIVATION" => expected, "LEDGER_ACTIVATION_REPORT" => report)
    expect(status.success?).to be(true), stderr
    expect(JSON.parse(File.read(report))).to eq(JSON.parse(stdout))
    File.unlink(marker)
    File.write(expected, JSON.generate(JSON.parse(stdout).merge("cucumber_expressions" => "19.0.1")))
    _stdout, stderr, status = invoke(code, "LEDGER_EXPECTED_ACTIVATION" => expected, "LEDGER_ACTIVATION_REPORT" => report)
    expect(status.success?).to be(false)
    expect(stderr).to include("differs from successful probe")
    expect(File.exist?(marker)).to be(false)
    expect(JSON.parse(File.read(report)).fetch("cucumber_expressions")).to eq("18.0.1")
  end

  it "rejects an invalid live runtime before constructing a wire observer or launching fixtures" do
    parent = File.join(LedgerDeveloper::Runner::HOME, "evidence")
    FileUtils.mkdir_p(parent)
    Dir.mktmpdir("activation-spec-", parent) do |scratch|
      output = File.join(scratch, "run")
      runner = LedgerDeveloper::Runner.new(%W[--transport live --authorize-live-writes --fixtures F10a --sdk-root #{@sdk} --cucumber 12.0.1 --output #{output}])
      allow(runner).to receive(:environment).and_return(child_env.merge("LEDGER_CUCUMBER" => "12.0.1"))
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("RP_PROJECT").and_return("never_contacted")
      expect(LedgerDeveloper::Wire).not_to receive(:new)
      expect { expect(runner.run).to eq(2) }.to output(/Runtime probe failed.*\n.*Selected SDK requires/m).to_stderr
      expect(File.file?(File.join(output, "probe.json"))).to be(true)
      expect(File.exist?(File.join(output, "F10a"))).to be(false)
    end
  end

  [nil, "", "{broken", "{}"].each do |report|
    it "retains the original process error for native report #{report.inspect}" do
      File.write(File.join(@scratch, "native.json"), report) unless report.nil?
      process = { exit: 2, signal: nil, timed_out: false, stdout: "", stderr: "NoMethodError: children.map nil\nmessage_builder.rb:144\n" }
      runner = LedgerDeveloper::Runner.new([])
      result = runner.evaluate({ id: "F10a" }, @scratch, process, nil, nil)
      expect(result).to include(execution: "harness_error", exit: 2, child_exit: 2, child_stderr: process[:stderr])
      expect(result.fetch(:error_class)).not_to eq("JSON::ParserError")
      expect(result.fetch(:process_evidence)).to end_with("process.json")
    end
  end

  [{ exit: 2 }, { exit: nil, signal: 9 }, { exit: 0, timed_out: true }].each do |failure|
    it "treats fatal child completion #{failure.inspect} as a harness error even with valid JSON" do
      File.write(File.join(@scratch, "native.json"), "[]")
      process = { signal: nil, timed_out: false, stderr: "original child failure", stdout: "" }.merge(failure)
      result = LedgerDeveloper::Runner.new([]).evaluate({ id: "F10a" }, @scratch, process, nil, nil)
      expect(result).to include(execution: "harness_error", exit: 2, child_exit: process[:exit],
                                child_signal: process[:signal], child_timed_out: process[:timed_out], child_stderr: process[:stderr])
    end
  end

  it "still distinguishes a fully reported intentional failure from a harness error" do
    FileUtils.mkdir_p(File.join(@sdk, "lib"))
    source = File.join(@sdk, "lib", "example.rb")
    File.write(source, "# source fixture\n")
    native = [{ elements: [{ steps: [{ result: { status: "failed", error_message: "INTENTIONAL" } }] }] }]
    File.write(File.join(@scratch, "native.json"), JSON.generate(native))
    File.write(File.join(@scratch, "runtime.json"), JSON.generate(loaded_sdk_files: [source], sdk_source_changed_during_fixture: false, activation: {}))
    runner = LedgerDeveloper::Runner.new(["--sdk-root", @sdk])
    runner.instance_variable_set(:@runtime, { "activation" => {} })
    wire = double(records: [{ method: "POST", path: "/launch", status: 201 }, { method: "PUT", path: "/launch/new/finish", status: 200 }], launches: ["new"], items: {})
    result = runner.evaluate({ id: "intentional", scenarios: 1, failed: 1, error: "INTENTIONAL" }, @scratch, { exit: 1, timed_out: false }, wire, {})
    expect(result).to include(execution: "expected_failure_observed", exit: 0, child_exit: 1)
  end
end
