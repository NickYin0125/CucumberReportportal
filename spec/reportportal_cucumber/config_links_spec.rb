# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Config do
  it "defaults links off and expands the source root without enabling them" do
    config = described_class.new

    expect(config).not_to be_scenario_links_enabled
    expect(config.source_root).to eq(Dir.pwd)
    expect(config.source_url_template).to be_nil
    expect(config.source_commit).to be_nil
    expect(config.ci_run_url).to be_nil
    expect(config.tms_url_template).to be_nil
  end

  it "loads settings through environment, YAML profile, and override precedence" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "reportportal.yml")
      File.write(path, <<~YAML)
        default:
          scenario_links_enabled: false
          source_root: ./yaml-root
        profiles:
          ci:
            scenario_links_enabled: true
            source_commit: abcdef0123456
            ci_run_url: https://ci.example.test/yaml
      YAML

      config = described_class.load(
        profile: "ci", yaml_path: path,
        env: {
          "RP_SCENARIO_LINKS_ENABLED" => "true",
          "RP_SOURCE_URL_TEMPLATE" => "https://code.example.test/{commit}/{path}?line={line}",
          "RP_SOURCE_COMMIT" => "0123456789abcdef",
          "RP_SOURCE_ROOT" => directory,
          "RP_CI_RUN_URL" => "https://ci.example.test/env",
          "RP_TMS_URL_TEMPLATE" => "https://tms.example.test/{id}"
        },
        overrides: { ci_run_url: "https://ci.example.test/override" }
      )

      expect(config).to be_scenario_links_enabled
      expect(config.source_url_template).to eq("https://code.example.test/{commit}/{path}?line={line}")
      expect(config.source_commit).to eq("0123456789abcdef")
      expect(config.source_root).to eq(directory)
      expect(config.ci_run_url).to eq("https://ci.example.test/override")
      expect(config.tms_url_template).to eq("https://tms.example.test/{id}")
    end
  end

  it "ignores invalid optional link scalar types while disabled" do
    config = described_class.new(source_url_template: Object.new, source_root: Object.new)

    expect(config).not_to be_scenario_links_enabled
    expect(config.source_root).to eq(Dir.pwd)
  end

  it "rejects invalid link scalar types generically only when enabled" do
    [
      { source_url_template: Object.new },
      { source_commit: 123 },
      { source_root: [] },
      { ci_run_url: Object.new },
      { tms_url_template: false }
    ].each do |setting|
      expect { described_class.new({ scenario_links_enabled: true }.merge(setting)) }
        .to raise_error(ArgumentError, "Invalid scenario link configuration")
    end
  end

  it "normalizes invalid source roots to a generic error only when links are enabled" do
    expect { described_class.new(scenario_links_enabled: true, source_root: "/private/\0secret") }
      .to raise_error(ArgumentError, "Invalid scenario link configuration")
    expect(described_class.new(source_root: "/private/\0secret").source_root).to eq(Dir.pwd)

    binary_root = "\xFF".b
    expect { described_class.new(scenario_links_enabled: true, source_root: binary_root) }
      .to raise_error(ArgumentError, "Invalid scenario link configuration")
    expect(described_class.new(source_root: binary_root).source_root).to eq(Dir.pwd)
  end

  it "parses the opt-in environment flag" do
    expect(described_class.load(env: { "RP_SCENARIO_LINKS_ENABLED" => "true" }))
      .to be_scenario_links_enabled
    expect(described_class.load(env: { "RP_SCENARIO_LINKS_ENABLED" => "off" }))
      .not_to be_scenario_links_enabled
  end
end
