# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Config do
  let(:uuid) { "01234567-89ab-4cde-8123-456789abcdef" }

  it "defaults to independent launches, best-effort completion and authenticated MinIO TLS" do
    config = described_class.new
    expect(config).not_to be_join
    expect(config).not_to be_ci_owned_launch
    expect(config).not_to be_require_complete_reporting
    expect(config.minio_ssl_verify_peer).to equal(true)
    expect(config.minio_ssl_ca_bundle).to be_nil
  end

  it "distinguishes requested reporting from deliberately disabled reporting" do
    requested = described_class.load(profile: nil, env: {}, yaml_path: File::NULL)
    disabled = described_class.load(profile: nil, env: { "RP_ENABLED" => "false", "RP_REQUIRE_COMPLETE_REPORTING" => "true" }, yaml_path: File::NULL)
    expect(requested).to be_reporting_requested
    expect(requested).not_to be_enabled
    expect(requested.missing_reporting_options).to eq(%w[RP_ENDPOINT RP_PROJECT RP_API_KEY])
    expect(disabled).not_to be_reporting_requested
    expect(disabled).not_to be_enabled
  end

  %i[endpoint project api_key].each do |missing|
    it "reports the missing #{missing} option label without exposing configured values" do
      options = { endpoint: "https://example.test/?token=CONFIG_PRIVATE", project: "CONFIG_PRIVATE", api_key: "CONFIG_PRIVATE" }
      config = described_class.new(**options.merge(missing => "  "), require_complete_reporting: true)
      expect(config).to be_reporting_requested
      expect(config).not_to be_enabled
      expect(config.missing_reporting_options).to eq([described_class::REQUIRED_REPORTING_OPTIONS.fetch(missing)])
      expect(config.missing_reporting_options).to be_frozen
      expect(config.missing_reporting_options.join).not_to include("CONFIG_PRIVATE")
    end
  end

  it "recognizes complete requested configuration without requiring transport construction" do
    config = described_class.new(endpoint: "https://example.test", project: "demo", api_key: "synthetic")
    expect(config).to be_reporting_requested
    expect(config).to be_enabled
    expect(config.missing_reporting_options).to eq([])
  end

  it "auto-discovers safe shipped defaults and rerun configuration in a normal clone" do
    sample = File.expand_path("../../config/reportportal.yml", __dir__)
    allow(described_class).to receive(:detect_profile_from_argv).and_return(nil)
    Dir.mktmpdir do |clone|
      clone = File.realpath(clone)
      FileUtils.mkdir_p(File.join(clone, "config"))
      sample_copy = File.join(clone, "config", "reportportal.yml")
      FileUtils.cp(sample, sample_copy)
      Dir.chdir(clone) do
        expect(described_class.default_yaml_candidates.find { |path| File.file?(path) }).to eq(sample_copy)
        default = described_class.load(profile: nil, env: {})
        rerun = described_class.load(profile: "rerun_config", env: {})
        expect(default).not_to be_join
        expect(rerun).not_to be_join
        expect(rerun).to be_rerun
        expect(default.launch_description).to eq("Local ReportPortal verification from reportportal-cucumber-ruby")
        expect(described_class.load(profile: nil, env: { "RP_CLIENT_JOIN" => "true" })).to be_join
      end
    end
  end

  it "loads the explicit CI-owned UUID and completeness policy from environment" do
    config = described_class.load(env: { "RP_LAUNCH_UUID" => uuid, "RP_REQUIRE_COMPLETE_REPORTING" => "true" }, yaml_path: File::NULL)
    expect(config.launch_uuid).to eq(uuid)
    expect(config).to be_ci_owned_launch
    expect(config).to be_require_complete_reporting
  end

  it "keeps legacy exception strictness separate from completeness strictness" do
    config = described_class.load(env: { "RP_FAIL_ON_REPORTING_ERROR" => "true", "RP_REQUIRE_COMPLETE_REPORTING" => "false" }, yaml_path: File::NULL)
    expect(config).to be_fail_on_reporting_error
    expect(config).not_to be_require_complete_reporting
  end

  it "requires an explicit boolean to opt into completeness" do
    expect { described_class.load(env: { "RP_REQUIRE_COMPLETE_REPORTING" => "" }, yaml_path: File::NULL) }
      .to raise_error(ArgumentError, "RP_REQUIRE_COMPLETE_REPORTING must be a boolean")
    expect(described_class.new(require_complete_reporting: " FALSE ")).not_to be_require_complete_reporting
  end

  ["", "not-a-uuid", "../launch", 123, "01234567-89ab-4cde-8123-456789abcdef/finish"].each do |invalid|
    it "rejects malformed CI launch identifiers without reflecting their values: #{invalid.inspect}" do
      expect { described_class.new(launch_uuid: invalid) }.to raise_error(ArgumentError, "RP_LAUNCH_UUID must be an existing launch UUID")
    end
  end

  [{ rerun: true }, { rerun_of: "other" }].each do |options|
    it "rejects CI-owned launch UUID with launch-creation options #{options.keys}" do
      expect { described_class.new(**options, launch_uuid: uuid) }.to raise_error(ArgumentError, /cannot be combined/)
    end
  end

  it "loads dotted YAML options with profile and environment precedence" do
    Dir.mktmpdir do |dir|
      ca = File.join(dir, "ca.pem")
      File.write(ca, "test CA fixture")
      yaml = File.join(dir, "reportportal.yml")
      File.write(yaml, <<~YAML)
        default:
          rp.launch.uuid: #{uuid}
          rp.require.complete.reporting: false
          rp.minio.ssl.verify.peer: false
          rp.minio.ssl.ca.bundle: #{ca}
        profiles:
          ci:
            rp.require.complete.reporting: true
            rp.minio.ssl.verify.peer: true
      YAML
      config = described_class.load(profile: "ci", env: {}, yaml_path: yaml)
      expect(config.launch_uuid).to eq(uuid)
      expect(config).to be_require_complete_reporting
      expect(config.minio_ssl_verify_peer).to equal(true)
      expect(config.minio_ssl_ca_bundle).to eq(ca)
      override = described_class.load(profile: "ci", env: { "RP_MINIO_SSL_VERIFY_PEER" => "false", "RP_REQUIRE_COMPLETE_REPORTING" => "false" }, yaml_path: yaml)
      expect(override.minio_ssl_verify_peer).to equal(false)
      expect(override).not_to be_require_complete_reporting
    end
  end

  { "true" => true, " TRUE " => true, "1" => true, "false" => false, "0" => false }.each do |raw, expected|
    it "parses MinIO TLS #{raw.inspect} as a real boolean" do
      config = described_class.load(env: { "RP_MINIO_SSL_VERIFY_PEER" => raw }, yaml_path: File::NULL)
      expect(config.minio_ssl_verify_peer).to equal(expected)
    end
  end

  [nil, "", "maybe", 2, {}].each do |invalid|
    it "rejects ambiguous MinIO TLS settings #{invalid.inspect}" do
      expect { described_class.new(minio_ssl_verify_peer: invalid) }.to raise_error(ArgumentError, /must be a boolean/)
    end
  end

  ["", "missing-ca.pem", "ca\0.pem", 12, {}].each do |invalid|
    it "rejects unusable CA bundle paths #{invalid.inspect}" do
      expect { described_class.new(minio_ssl_ca_bundle: invalid) }.to raise_error(ArgumentError, /readable CA bundle path/)
    end
  end

  it "loads a trusted CA bundle from environment" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "ca.pem")
      File.write(path, "fixture CA")
      config = described_class.load(env: { "RP_MINIO_SSL_CA_BUNDLE" => path }, yaml_path: File::NULL)
      expect(config.minio_ssl_ca_bundle).to eq(path)
      expect(config.minio_ssl_verify_peer).to equal(true)
    end
  end
end
