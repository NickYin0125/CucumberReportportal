# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Runtime::Context do
  let(:context) { described_class.new }

  it "stores the active feature, scenario, and step stack in Thread.current[:rp_context_stack]" do
    feature = described_class::ItemHandle.new(uuid: "feature-1", kind: :feature, name: "Feature", type: "suite", has_stats: false)
    scenario = described_class::ItemHandle.new(uuid: "scenario-1", kind: :scenario, name: "Scenario", parent_uuid: "feature-1", type: "test", has_stats: true)
    step = described_class::ItemHandle.new(uuid: "step-1", kind: :step, name: "Step", parent_uuid: "scenario-1", type: "step", has_stats: false)

    context.register_feature("features/a.feature", feature)
    context.activate_feature("features/a.feature", feature)
    context.start_scenario("features/a.feature:1", scenario)
    context.push_step(step)

    expect(Thread.current[:rp_context_stack].map(&:uuid)).to eq(%w[feature-1 scenario-1 step-1])
    expect(context.current_item_uuid).to eq("step-1")

    context.pop_step(expected_uuid: "step-1")
    context.finish_scenario(expected_uuid: "scenario-1")

    expect(Thread.current[:rp_context_stack].map(&:uuid)).to eq(["feature-1"])
    expect(context.current_item_uuid).to eq("feature-1")
  end
end
