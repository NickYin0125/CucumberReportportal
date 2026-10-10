# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Config do
  describe "identity configuration" do
    it "defaults to legacy and an expanded checkout root" do
      config = described_class.new

      expect(config.identity_strategy).to eq("legacy")
      expect(config.identity_root).to eq(Dir.pwd)
      expect(config.identity_namespace).to be_nil
    end

    it "loads identity values from environment and normalizes the strategy" do
      config = described_class.load(
        env: {
          "RP_IDENTITY_STRATEGY" => "STABLE_V1",
          "RP_IDENTITY_ROOT" => "./checkout",
          "RP_IDENTITY_NAMESPACE" => "team-a"
        }
      )

      expect(config.identity_strategy).to eq("stable_v1")
      expect(config.identity_root).to eq(File.expand_path("./checkout"))
      expect(config.identity_namespace).to eq("team-a")
    end

    it "respects defaults, profile, environment, and explicit override precedence" do
      Dir.mktmpdir do |directory|
        yaml_path = File.join(directory, "reportportal.yml")
        File.write(yaml_path, <<~YAML)
          default:
            identity_strategy: legacy
            identity_namespace: default
          profiles:
            ci:
              identity_strategy: stable_v1
              identity_namespace: profile
        YAML

        config = described_class.load(
          profile: "ci", yaml_path: yaml_path,
          env: { "RP_IDENTITY_NAMESPACE" => "environment" },
          overrides: { identity_namespace: "override" }
        )

        expect(config.identity_strategy).to eq("stable_v1")
        expect(config.identity_namespace).to eq("override")
      end
    end

    it "rejects unsupported strategies before reporting can start" do
      expect { described_class.new(identity_strategy: "future") }
        .to raise_error(ArgumentError, "RP_IDENTITY_STRATEGY must be legacy or stable_v1")
    end
  end
end
