# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Config do
  describe "scenario attributes configuration" do
    it "defaults off with the documented allowlist and no defaults" do
      config = described_class.new

      expect(config.scenario_attributes_enabled?).to be(false)
      expect(config.scenario_attribute_keys).to eq(%w[component team owner layer priority browser tms])
      expect(config.scenario_attributes).to eq([])
    end

    it "loads the settings from environment variables" do
      config = described_class.load(env: {
        "RP_SCENARIO_ATTRIBUTES_ENABLED" => "true",
        "RP_SCENARIO_ATTRIBUTE_KEYS" => "team, custom.key",
        "RP_SCENARIO_ATTRIBUTES" => '{"team":"quality","custom.key":"platform"}'
      })

      expect(config.scenario_attributes_enabled?).to be(true)
      expect(config.scenario_attribute_keys).to eq(%w[team custom.key])
      expect(config.scenario_attributes).to eq(team: "quality", "custom.key": "platform")
    end

    it "loads YAML defaults and a named profile with environment and explicit precedence" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "reportportal.yml")
        File.write(path, <<~YAML)
          default:
            scenario_attributes_enabled: false
            scenario_attribute_keys: [team, owner]
            scenario_attributes:
              team: default
          profiles:
            ci:
              scenario_attributes_enabled: true
              scenario_attributes:
                team: profile
                owner: automation
        YAML

        config = described_class.load(
          profile: "ci", yaml_path: path,
          env: {
            "RP_SCENARIO_ATTRIBUTES_ENABLED" => "false",
            "RP_SCENARIO_ATTRIBUTES" => '{"team":"environment"}'
          },
          overrides: { scenario_attributes_enabled: true, scenario_attributes: { team: "override" } }
        )

        expect(config.scenario_attributes_enabled?).to be(true)
        expect(config.scenario_attributes).to eq(team: "override")
        expect(config.scenario_attribute_keys).to eq(%w[team owner])
      end
    end

    it "supports an explicitly empty allowlist" do
      config = described_class.load(env: { "RP_SCENARIO_ATTRIBUTE_KEYS" => "" })

      expect(config.scenario_attribute_keys).to eq([])
    end

    it "rejects credential aliases regardless of case and separator spelling" do
      ["access_token", "access-token", "accessToken", "ACCESS.TOKEN", "client_secret", "client-secret",
       "refresh_token", "refresh-token", "x-api-key", "x_api_key", "XApiKey"].each do |key|
        expect do
          described_class.load(env: { "RP_SCENARIO_ATTRIBUTE_KEYS" => "safe,#{key}" })
        end.to raise_error(ArgumentError, "Reserved scenario attribute key")
      end

      ["access" + ("_" * 2_048) + "token", "x" + ("-" * 2_048) + "api" + ("_" * 2_048) + "key"].each do |key|
        expect do
          described_class.load(env: { "RP_SCENARIO_ATTRIBUTE_KEYS" => "safe,#{key}" })
        end.to raise_error(ArgumentError) { |error| expect(error.message).not_to include(key) }
      end
    end

    it "rejects malformed structural types and malformed environment JSON generically" do
      [{ scenario_attributes: "not-json" }, { scenario_attributes: 42 }, { scenario_attribute_keys: "retry" }].each do |input|
        expect { described_class.new(input) }.to raise_error(ArgumentError)
      end
      expect { described_class.load(env: { "RP_SCENARIO_ATTRIBUTES" => "{secret" }) }
        .to raise_error(ArgumentError, "Invalid scenario attribute defaults")
      expect { described_class.load(env: { "RP_SCENARIO_ATTRIBUTES" => '"secret"' }) }
        .to raise_error(ArgumentError, "Invalid scenario attribute defaults")
      invalid_encoding = "{\xFF}".b
      expect { described_class.load(env: { "RP_SCENARIO_ATTRIBUTES" => invalid_encoding }) }
        .to raise_error(ArgumentError, "Invalid scenario attribute defaults")
    end
  end
end
