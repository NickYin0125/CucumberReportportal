# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe ReportportalCucumber::Service::ScenarioIdentity do
  let(:source) { { scenario_name: "submits order", rule_name: "Checkout", identity_ambiguous: false } }

  describe ".build" do
    it "preserves legacy helper outputs and the original parameter object" do
      parameters = { "b" => 2, "a" => 1 }

      result = described_class.build(code_ref: "features/a.feature:12", parameters: parameters)

      expect(result.test_case_id).to eq("features/a.feature:12[b=2,a=1]")
      expect(result.unique_id).to eq("f835f17b8c0e254d575dd122b2f90500a8cbcbf2")
      expect(result.parameters).to equal(parameters)
      expect(result.strategy).to eq("legacy")
      expect(result.fallback_reason).to be_nil
      expect(result).to be_frozen

      reversed = described_class.build(code_ref: "features/a.feature:12", parameters: { "a" => 1, "b" => 2 })
      expect(reversed.test_case_id).to eq("features/a.feature:12[a=1,b=2]")
      expect(reversed.unique_id).to eq("e3f454a5fec257ffd4eb26f1325673109d04f463")
    end

    it "makes equivalent parameter representations and insertion orders identical" do
      first = described_class.build(
        strategy: "stable_v1", code_ref: "unused", feature_uri: "./features/orders.feature", root: "/repo",
        source: source, parameters: { "b" => 2, "a" => 1 }
      )
      second = described_class.build(
        strategy: "stable_v1", code_ref: "unused", feature_uri: "/repo/features/orders.feature", root: "/repo",
        source: source, parameters: [{ "key" => "a", "value" => 1 }, { "key" => "b", "value" => 2 }]
      )

      expect(second.test_case_id).to eq(first.test_case_id)
      expect(second.unique_id).to eq(first.unique_id)
      expect(first.parameters).to eq([{ "key" => "a", "value" => "1" }, { "key" => "b", "value" => "2" }])
      expect(first.parameters).to be_frozen
      expect(first.parameters.first).to be_frozen
      expect(described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "x.feature", source: source
      ).parameters).to eq([])
      expect(described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "x.feature", source: source, parameters: {}
      ).test_case_id).to eq(described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "x.feature", source: source
      ).test_case_id)
    end

    it "preserves duplicate pairs and sorts empty values" do
      result = described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "x.feature", source: source,
        parameters: [{ "key" => "x", "value" => "" }, { "x" => "" }, { "x" => "" }]
      )

      expect(result.parameters).to eq([
        { "key" => "x", "value" => "" },
        { "key" => "x", "value" => "" },
        { "key" => "x", "value" => "" }
      ])
    end

    it "keeps structured values delimiter-safe and canonicalizes nested hashes without mutating inputs" do
      nested = { b: ["x|y", "z"], a: { second: 2, first: 1 } }.freeze
      result = described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "x.feature", source: source, parameters: { p: nested }
      )
      reordered = described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "x.feature", source: source,
        parameters: [{ p: { a: { first: 1, second: 2 }, b: ["x|y", "z"] } }]
      )
      collision = described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "x.feature", source: source,
        parameters: { p: "{\"a\":1}", q: "x|y" }
      )

      expect(result.test_case_id).to eq(reordered.test_case_id)
      expect(result.parameters.first.fetch("value")).to eq('{"a":{"first":1,"second":2},"b":["x|y","z"]}')
      expect(collision.test_case_id).not_to eq(result.test_case_id)
      expect(nested).to eq(b: ["x|y", "z"], a: { second: 2, first: 1 })
    end

    it "detaches mutable parameter keys and values before freezing the result" do
      hash_key = +"hash-key"
      hash_value = +"hash-value"
      pair_key = +"pair-key"
      pair_value = +"pair-value"

      result = described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "x.feature", source: source,
        parameters: [{ hash_key => hash_value }, { "key" => pair_key, "value" => pair_value }]
      )

      expect([hash_key, hash_value, pair_key, pair_value].map(&:frozen?)).to eq([false, false, false, false])
      [hash_key, hash_value, pair_key, pair_value].each { |string| string << "-changed" }
      expect(result.parameters).to eq([
        { "key" => "hash-key", "value" => "hash-value" },
        { "key" => "pair-key", "value" => "pair-value" }
      ])
      expect(result.parameters).to be_frozen
      expect(result.parameters.all?(&:frozen?)).to be(true)
    end

    it "rejects nested normalized-key collisions, cycles, and unsupported values generically" do
      cyclic = []
      cyclic << cyclic

      [{ a: 1, "a" => 2 }, cyclic, Object.new].each do |value|
        expect do
          described_class.build(
            strategy: "stable_v1", code_ref: "x", feature_uri: "x.feature", source: source, parameters: { p: value }
          )
        end.to raise_error(ArgumentError, "Invalid scenario identity parameters")
      end
    end

    it "uses explicit IDs independently of source location and names" do
      first = described_class.build(
        strategy: "stable_v1", explicit_id: "  case-42 ", code_ref: "a:1", feature_uri: "a.feature",
        source: source
      )
      renamed = described_class.build(
        strategy: "stable_v1", explicit_id: "case-42", code_ref: "b:99", feature_uri: "b.feature",
        source: { scenario_name: "renamed", rule_name: "new rule", identity_ambiguous: true }
      )

      expect(first.test_case_id).to eq(renamed.test_case_id)
      expect(first.unique_id).to eq(renamed.unique_id)
      expect(first.test_case_id).to start_with("rp:stable-v1:")
    end

    it "locks the explicit-ID stable-v1 versioned encoding to literal golden digests" do
      result = described_class.build(
        strategy: "stable_v1", explicit_id: "case-42", code_ref: "ignored", namespace: "team-a",
        parameters: { "b" => 2, "a" => 1 }
      )

      expect(result.test_case_id).to eq(
        "rp:stable-v1:315246fd13a3f09fbc275cfd4b80c9ee4369ee9fbaf9936a7f4e7d01eeeda67d"
      )
      expect(result.unique_id).to eq("2dd1fbb37712faed298cd5bfb934e79d2bbc9409237510b40014e99d6dd7d536")
    end

    it "locks checkout-relative source identity to literal golden digests" do
      result = described_class.build(
        strategy: "stable_v1", code_ref: "ignored", namespace: "release", feature_uri: "./features/orders.feature",
        root: "/repo", source: { scenario_name: "submits order", rule_name: "Checkout" }, parameters: nil
      )

      expect(result.test_case_id).to eq(
        "rp:stable-v1:ca73d73232787b5034a323e929407b3c002ec62570626ed5489f8ec1c2899a9c"
      )
      expect(result.unique_id).to eq("b7c3a0e6a3dfb93ba6558c2e59923705616e9ed6121aaeb4e410385c4df9fd49")
    end

    it "changes identity for source movement, namespace, and parameter dataset/context" do
      base = described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "features/orders.feature", root: "/repo", source: source
      )
      moved = described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "features/renamed.feature", root: "/repo", source: source
      )
      renamed = described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "features/orders.feature", root: "/repo",
        source: { scenario_name: "renamed", rule_name: "Checkout", identity_ambiguous: false }
      )
      namespaced = described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "features/orders.feature", root: "/repo",
        source: source, namespace: "payments"
      )
      other_parameters = described_class.build(
        strategy: "stable_v1", code_ref: "x", feature_uri: "features/orders.feature", root: "/repo",
        source: source, parameters: { currency: "USD" }
      )

      [moved, renamed, namespaced, other_parameters].each do |result|
        expect(result.test_case_id).not_to eq(base.test_case_id)
        expect(result.unique_id).not_to eq(base.unique_id)
      end
    end

    it "falls back for missing or ambiguous source but lets an explicit ID bypass it" do
      missing = described_class.build(strategy: "stable_v1", code_ref: "a:1")
      ambiguous = described_class.build(
        strategy: "stable_v1", code_ref: "a:1", source: source.merge(identity_ambiguous: true)
      )
      explicit = described_class.build(
        strategy: "stable_v1", explicit_id: "id", code_ref: "a:1", source: source.merge(identity_ambiguous: true)
      )
      missing_path = described_class.build(
        strategy: "stable_v1", code_ref: "a:1", source: source, feature_uri: "  "
      )
      explicit_without_path = described_class.build(
        strategy: "stable_v1", explicit_id: "id", code_ref: "a:1", source: nil, feature_uri: nil
      )
      legacy = described_class.build(code_ref: "a:1")

      expect(missing.fallback_reason).to eq(:missing_source)
      expect(ambiguous.fallback_reason).to eq(:ambiguous_source)
      expect(missing_path.fallback_reason).to eq(:missing_source)
      expect(missing_path.test_case_id).to eq(legacy.test_case_id)
      expect(missing.strategy).to eq("legacy")
      expect(missing.test_case_id).to eq(legacy.test_case_id)
      expect(explicit.strategy).to eq("stable_v1")
      expect(explicit.fallback_reason).to be_nil
      expect(explicit_without_path.strategy).to eq("stable_v1")
    end

    it "loads directly with only standard-library and its legacy-helper dependencies" do
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby, "-Ilib", "-e",
        'require "reportportal_cucumber/service/scenario_identity"; abort unless ReportportalCucumber::Service::ScenarioIdentity.build(code_ref: "x").unique_id'
      )

      expect(status).to be_success, stderr
      expect(stdout).to be_empty
    end
  end
end
