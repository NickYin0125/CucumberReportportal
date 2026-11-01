# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Config, "run context" do
  def load_config(**options)
    described_class.load(**{ profile: nil, env: {}, yaml_path: File::NULL }.merge(options))
  end

  def with_yaml(data)
    Dir.mktmpdir do |directory|
      path = File.join(directory, "reportportal.yml")
      File.write(path, YAML.dump(data))
      yield path
    end
  end

  it "defaults to disabled and exposes a boolean reader and predicate" do
    expect(described_class::DEFAULTS[:run_context]).to equal(false)
    expect(described_class.new.run_context).to equal(false)
    expect(load_config).not_to be_run_context
    expect(described_class.new(run_context: true).run_context).to equal(true)
    expect(described_class.new("run_context" => true)).to be_run_context
    expect(described_class::ENV_KEY_MAP["RP_RUN_CONTEXT"]).to eq(:run_context)
  end

  {
    true => true, false => false,
    "true" => true, " TRUE " => true, "1" => true, " yes " => true, "On" => true,
    "false" => false, " FALSE " => false, "0" => false, " no " => false, "Off" => false
  }.each do |value, expected|
    it "normalizes #{value.inspect} consistently from every source" do
      expect(described_class.new(run_context: value).run_context).to equal(expected)
      expect(described_class.load_env("RP_RUN_CONTEXT" => value)).to eq(run_context: expected)
      expect(load_config(env: { "RP_RUN_CONTEXT" => value }).run_context).to equal(expected)
      expect(load_config(overrides: { "run_context" => value }).run_context).to equal(expected)
      with_yaml("default" => { "run_context" => value }) do |path|
        expect(load_config(yaml_path: path).run_context).to equal(expected)
      end
      with_yaml("profiles" => { "ci" => { "rp.run.context" => value } }) do |path|
        expect(load_config(profile: "ci", yaml_path: path).run_context).to equal(expected)
      end
    end
  end

  [nil, "", " ", "maybe", "PRIVATE_INVALID_VALUE", 0, 1, [], {}].each do |value|
    it "rejects ambiguous #{value.inspect} consistently without reflecting the value" do
      message = "RP_RUN_CONTEXT must be a boolean"
      expect { described_class.new(run_context: value) }.to raise_error(ArgumentError, message)
      expect { described_class.load_env("RP_RUN_CONTEXT" => value) }.to raise_error(ArgumentError, message)
      expect { load_config(env: { "RP_RUN_CONTEXT" => value }) }.to raise_error(ArgumentError, message)
      expect { load_config(overrides: { run_context: value }) }.to raise_error(ArgumentError, message)
      with_yaml("default" => { "rp.run.context" => value }) do |path|
        expect { load_config(yaml_path: path) }.to raise_error(ArgumentError, message)
      end
      with_yaml("profiles" => { "ci" => { "run_context" => value } }) do |path|
        expect { load_config(profile: "ci", yaml_path: path) }.to raise_error(ArgumentError, message)
      end
    end
  end

  %w[run_context rp.run.context RP_RUN_CONTEXT].each do |key|
    it "maps #{key} in YAML defaults, nested profiles and legacy top-level profiles" do
      with_yaml("default" => { key => true }, "profiles" => { "ci" => { key => false } }, "local" => { key => false }) do |path|
        expect(load_config(yaml_path: path)).to be_run_context
        expect(load_config(profile: "ci", yaml_path: path)).not_to be_run_context
        expect(load_config(profile: "local", yaml_path: path)).not_to be_run_context
      end
    end
  end

  it "preserves explicit false through defaults, profile, environment and override precedence" do
    with_yaml("default" => { "run_context" => false }, "profiles" => { "ci" => { "rp.run.context" => true } }) do |path|
      expect(load_config(yaml_path: path)).not_to be_run_context
      expect(load_config(profile: "ci", yaml_path: path)).to be_run_context
      expect(load_config(profile: "ci", env: { "RP_CONFIG" => path, "RP_RUN_CONTEXT" => "off" }, yaml_path: nil)).not_to be_run_context
      expect(load_config(profile: "ci", yaml_path: path, env: { "RP_RUN_CONTEXT" => "false" }, overrides: { run_context: " ON " })).to be_run_context
      expect(load_config(profile: "ci", yaml_path: path, env: { "RP_RUN_CONTEXT" => "true" }, overrides: { run_context: false })).not_to be_run_context
    end
  end

  it "honors auto-discovered YAML and an argv-selected profile" do
    with_yaml("default" => { "run_context" => false }, "profiles" => { "ci" => { "run_context" => true } }) do |path|
      allow(described_class).to receive(:default_yaml_candidates).and_return([path])
      allow(described_class).to receive(:detect_profile_from_argv).and_return("ci")
      expect(load_config(yaml_path: nil)).to be_run_context
    end
  end

  [false, true].each do |enabled|
    it "does not enhance or mutate explicit launch metadata with run_context=#{enabled}" do
      attributes = [{ "key" => "sdk", "value" => "custom", "system" => true }.freeze, { "value" => "smoke" }.freeze].freeze
      original = Marshal.load(Marshal.dump(attributes))
      config = load_config(
        env: { "RP_RUN_CONTEXT" => enabled.to_s, "RP_LAUNCH_DESCRIPTION" => "Given description",
               "GITHUB_REF_NAME" => "feature/ledger", "GITHUB_RUN_ID" => "42", "PARALLEL_TEST_GROUPS" => "4" },
        overrides: { launch_attributes: attributes }
      )
      expect(config.run_context).to equal(enabled)
      expect(config.launch_description).to eq("Given description")
      expect(config.launch_attributes).to eq([{ key: "sdk", value: "custom", system: true }, { value: "smoke" }])
      expect(attributes).to eq(original)
      expect(load_config(env: { "RP_RUN_CONTEXT" => enabled.to_s }).launch_description).to be_nil
      expect(load_config(env: { "RP_RUN_CONTEXT" => enabled.to_s }).launch_attributes).to eq([])
    end
  end
end
