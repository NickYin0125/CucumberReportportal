# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Service::ScenarioAttributes do
  subject(:result) do
    described_class.build(defaults: defaults, tag_scopes: scopes, allowed_keys: keys, explicit_id: explicit_id)
  end

  let(:defaults) { { "component" => "base", "team" => "quality" } }
  let(:scopes) { { feature: [], rule: [], scenario: [], examples: [] } }
  let(:keys) { %w[component team owner tms] }
  let(:explicit_id) { nil }

  def values(attributes)
    attributes.to_h { |entry| [entry.fetch("key"), entry.fetch("value")] }
  end

  it "inherits defaults and applies scoped overrides from broad to narrow" do
    allow_scopes = {
      feature: ["@component:feature", "@owner: Ada"],
      rule: ["@component:rule"], scenario: ["@component:scenario"],
      examples: ["@component:row"]
    }
    resolved = described_class.build(defaults: defaults, tag_scopes: allow_scopes, allowed_keys: keys)

    expect(values(resolved.attributes)).to eq("component" => "row", "owner" => "Ada", "team" => "quality")
    expect(resolved.attributes.map { |entry| entry.fetch("key") }).to eq(%w[component owner team])
  end

  it "ignores conflicting values within a scope independent of tag order" do
    variants = [%w[@component:first @component:second], %w[@component:second @component:first]]
    outputs = variants.map do |tags|
      described_class.build(defaults: defaults, tag_scopes: { feature: tags }, allowed_keys: keys)
    end

    expect(outputs.map { |entry| values(entry.attributes) }.uniq).to eq([{ "component" => "base", "team" => "quality" }])
    expect(outputs.map(&:diagnostics).flatten.map { |entry| entry[:reason] }).to all(eq(:conflict))
  end

  it "omits conflicting defaults with three values and duplicates in every ordering" do
    entries = [
      { "browser" => "one" }, { "browser" => "two" },
      { "browser" => "three" }, { "browser" => "one" }
    ]
    outputs = entries.permutation.map do |permutation|
      resolved = described_class.build(defaults: permutation, tag_scopes: {}, allowed_keys: ["browser"])
      [values(resolved.attributes), resolved.diagnostics]
    end

    expect(outputs.uniq.length).to eq(1)
    expect(outputs.first).to eq([{}, [{ reason: :conflict, scope: :default, key: "browser" }]])
  end

  it "treats Hash defaults as maps and Array entries as explicit pair records" do
    map_result = described_class.build(
      defaults: { "key" => "from-map", "value" => "also-map" }, tag_scopes: {},
      allowed_keys: %w[key value]
    )
    record_result = described_class.build(
      defaults: [{ "key" => "key", "value" => "from-record" }], tag_scopes: {},
      allowed_keys: %w[key value]
    )

    expect(values(map_result.attributes)).to eq("key" => "from-map", "value" => "also-map")
    expect(values(record_result.attributes)).to eq("key" => "from-record")
  end

  it "canonicalizes configured and tagged keys consistently" do
    resolved = described_class.build(
      defaults: { " OWNER " => "default" }, tag_scopes: { scenario: ["@OWNER:tagged"] },
      allowed_keys: [" Owner "]
    )

    expect(values(resolved.attributes)).to eq("owner" => "tagged")
  end

  it "deduplicates repeated tags, ignores unknown keys, and rejects unsafe values" do
    result = described_class.build(
      defaults: defaults,
      tag_scopes: { scenario: ["@component: base ", "@component:base", "@unknown:hidden", "@team:bad:value", "@team:line\nbreak"] },
      allowed_keys: keys
    )

    expect(values(result.attributes)).to eq("component" => "base", "team" => "quality")
    expect(result.diagnostics.map { |entry| entry[:reason] }).to contain_exactly(:invalid_value, :invalid_value)
  end

  it "retains the lower valid value when multiple candidates are invalid" do
    resolved = described_class.build(
      defaults: { "team" => "inherited" },
      tag_scopes: { scenario: ["@team:", "@team:bad:value", "@team:bad\nvalue", "@team:valid"] },
      allowed_keys: keys
    )

    expect(values(resolved.attributes)).to eq("team" => "valid")
    expect(resolved.diagnostics.map { |entry| entry[:reason] }).to contain_exactly(:invalid_value, :invalid_value, :invalid_value)
  end

  it "enforces the value length boundary without truncating Unicode" do
    valid = "界" * 512
    resolved = described_class.build(
      defaults: {}, tag_scopes: { scenario: ["@owner:#{valid}", "@team:#{valid}x"] }, allowed_keys: keys
    )

    expect(values(resolved.attributes)).to eq("owner" => valid)
    expect(resolved.diagnostics).to include(hash_including(reason: :invalid_value, key: "team"))
  end

  it "reports missing source while retaining only defaults and selected explicit tms" do
    resolved = described_class.build(defaults: defaults.merge("tms" => "ignored"), tag_scopes: nil,
                                     allowed_keys: keys, explicit_id: " selected-id ")

    expect(values(resolved.attributes)).to eq("component" => "base", "team" => "quality", "tms" => "selected-id")
    expect(resolved.diagnostics).to include(hash_including(reason: :missing_source, scope: :scenario))
  end

  it "omits invalid explicit IDs and reports no raw input" do
    resolved = described_class.build(defaults: {}, tag_scopes: {}, allowed_keys: keys,
                                     explicit_id: "sensitive:value")

    expect(resolved.attributes).to be_empty
    expect(resolved.diagnostics).to eq([{ reason: :invalid_value, scope: :explicit_id, key: "tms" }])
  end

  it "validates custom allowlists and permits an explicit empty allowlist" do
    expect(described_class.normalize_allowed_keys([:custom_key])).to eq(["custom_key"])
    expect(described_class.normalize_allowed_keys([])).to eq([])
    %w[retry api_key ImmediateAutoAnalysis].each do |reserved|
      expect { described_class.normalize_allowed_keys([reserved.downcase]) }
        .to raise_error(ArgumentError, "Reserved scenario attribute key")
    end
    expect { described_class.normalize_allowed_keys(["Bad Key"]) }
      .to raise_error(ArgumentError, "Invalid scenario attribute allowlist")
    expect { described_class.normalize_allowed_keys([" Owner ", :owner]) }
      .to raise_error(ArgumentError, "Invalid scenario attribute allowlist")
    expect { described_class.normalize_allowed_keys(["\xFF".b]) }
      .to raise_error(ArgumentError, "Invalid scenario attribute allowlist")
  end

  it "rejects separator-normalized credential aliases through the helper with generic errors" do
    ["access__token", "ACCESS---TOKEN", "x___api---key", "client____secret", "refresh---token"].each do |key|
      expect do
        described_class.normalize_allowed_keys(["safe_business_key", key])
      end.to raise_error(ArgumentError) { |error| expect(error.message).not_to include(key) }
    end
    long_separator_alias = "x-api" + ("_" * 2_048) + "-key"
    expect do
      described_class.normalize_allowed_keys(["safe_business_key", long_separator_alias])
    end.to raise_error(ArgumentError) { |error| expect(error.message).not_to include(long_separator_alias) }
    expect(described_class.normalize_allowed_keys(["safe_business_key"])).to eq(["safe_business_key"])
  end

  it "rejects malformed structural inputs with generic errors" do
    expect { described_class.build(defaults: "secret", tag_scopes: {}, allowed_keys: keys) }
      .to raise_error(ArgumentError, "Invalid scenario attribute defaults")
    expect { described_class.build(defaults: {}, tag_scopes: [], allowed_keys: keys) }
      .to raise_error(ArgumentError, "Invalid scenario attribute tag scopes")
  end

  it "returns deeply frozen detached copies without freezing caller input" do
    defaults_input = { "owner" => +"Mina" }
    tag_input = +"@team:platform"
    tags_input = { scenario: [tag_input] }
    resolved = described_class.build(defaults: defaults_input, tag_scopes: tags_input, allowed_keys: keys)

    expect(defaults_input["owner"]).not_to be_frozen
    expect(tag_input).not_to be_frozen
    expect(resolved.attributes).to be_frozen
    expect(resolved.attributes.first).to be_frozen
    expect(resolved.attributes.first.values).to all(be_frozen)
    expect(resolved.diagnostics).to be_frozen

    defaults_input["owner"].replace("Changed")
    tag_input.replace("@team:changed")
    expect(values(resolved.attributes)).to eq("owner" => "Mina", "team" => "platform")
  end

  it "handles invalid UTF-8 in values without exposing the value" do
    invalid = "@owner:".b + "\xFF".b
    resolved = described_class.build(defaults: {}, tag_scopes: { scenario: [invalid] }, allowed_keys: keys)

    expect(resolved.attributes).to be_empty
    expect(resolved.diagnostics).to eq([{ reason: :invalid_value, scope: :scenario, key: "owner" }])
  end
end
