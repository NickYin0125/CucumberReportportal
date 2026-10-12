# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Runtime::Context do
  let(:context) { described_class.new }

  describe "instance-owned execution state" do
    it "isolates interleaved contexts and refreshes the compatibility mirror for the accessed owner" do
      first = described_class.new
      first_feature = described_class::ItemHandle.new(uuid: "first-feature", kind: :feature)
      first_scenario = described_class::ItemHandle.new(uuid: "first-scenario", kind: :scenario)
      first_step = described_class::ItemHandle.new(uuid: "first-step", kind: :step)
      first.register_feature("same.feature", first_feature)
      first.activate_feature("same.feature", first_feature)
      first.start_scenario("same-scenario", first_scenario)
      first.push_step(first_step)

      second = described_class.new
      second_feature = described_class::ItemHandle.new(uuid: "second-feature", kind: :feature)
      second_scenario = described_class::ItemHandle.new(uuid: "second-scenario", kind: :scenario)
      second_step = described_class::ItemHandle.new(uuid: "second-step", kind: :step)
      second.register_feature("same.feature", second_feature)
      second.activate_feature("same.feature", second_feature)
      second.start_scenario("same-scenario", second_scenario)
      second.push_step(second_step)

      expect(first.current_item).to equal(first_step)
      expect(Thread.current[:rp_context_stack].map(&:uuid)).to eq(%w[first-feature first-scenario first-step])
      expect(Thread.current[:reportportal_cucumber_context_state][:current_scenario_item]).to equal(first_scenario)
      expect(second.current_item).to equal(second_step)
      expect(Thread.current[:rp_context_stack].map(&:uuid)).to eq(%w[second-feature second-scenario second-step])
      expect(first.pop_step(expected_uuid: "second-step")).to be_nil
      second.pop_step(expected_uuid: "second-step")
      second.finish_scenario(expected_uuid: "second-scenario")
      second.finish_feature("same.feature")
      expect(first.current_scenario_item).to equal(first_scenario)
      expect(first.active_parent).to equal(first_step)
      expect(second.current_item).to be_nil
    end

    it "does not accept ownership changes written to compatibility snapshots" do
      step = described_class::ItemHandle.new(uuid: "owned-step", kind: :step)
      context.push_step(step)
      foreign = described_class::ItemHandle.new(uuid: "foreign-step", kind: :step)
      Thread.current[:rp_context_stack].replace([foreign])
      Thread.current[:reportportal_cucumber_context_state][:active_parent] = foreign
      Thread.current[:reportportal_cucumber_context_state][:current_feature_key] = "foreign.feature"
      expect(context.current_item).to equal(step)
      expect(context.active_parent).to equal(step)
      expect(context.current_feature_key).to be_nil
      expect(Thread.current[:rp_context_stack]).to eq([step])
    end

    it "isolates two live helper threads within each context" do
      contexts = [described_class.new, described_class.new]
      ready = Queue.new
      resume = Queue.new
      threads = 2.times.map do |index|
        Thread.new do
          contexts.each_with_index do |owner, owner_index|
            owner.push_step(described_class::ItemHandle.new(uuid: "thread-#{index}-owner-#{owner_index}", kind: :step))
          end
          ready << true
          resume.pop
          contexts.each_with_index do |owner, owner_index|
            expect(owner.current_item_uuid).to eq("thread-#{index}-owner-#{owner_index}")
            owner.pop_step
          end
        end
      end
      2.times { Timeout.timeout(2) { ready.pop } }
      contexts.each { |owner| expect(owner.current_item).to be_nil }
      2.times { resume << true }
      threads.each { |thread| expect(thread.join(2)).not_to be_nil }
    ensure
      2.times { resume << true }
      threads&.each { |thread| thread.join(2) }
    end

    it "preserves fiber-local ownership without using the thread-local mirror as storage" do
      first = Fiber.new do
        context.push_step(described_class::ItemHandle.new(uuid: "fiber-first", kind: :step))
        Fiber.yield
        expect(context.current_item_uuid).to eq("fiber-first")
        context.pop_step
      end
      second = Fiber.new do
        context.push_step(described_class::ItemHandle.new(uuid: "fiber-second", kind: :step))
        Fiber.yield
        expect(context.current_item_uuid).to eq("fiber-second")
        context.pop_step
      end
      first.resume
      second.resume
      expect(context.current_item).to be_nil
      first.resume
      second.resume
    end

    it "removes completed state and sweeps dead helper owners without retaining their threads" do
      100.times do |index|
        context.push_step(described_class::ItemHandle.new(uuid: "completed-#{index}", kind: :step))
        context.pop_step
      end
      expect(context.instance_variable_get(:@thread_states)).to be_empty
      expect(Thread.current[:rp_context_stack]).to be_empty
      expect(Thread.current[:reportportal_cucumber_context_state].values).to all(be_nil)
      20.times do |index|
        Thread.new { context.push_step(described_class::ItemHandle.new(uuid: "dead-thread-#{index}", kind: :step)) }.join
      end
      expect(context.current_item).to be_nil
      entries = context.instance_variable_get(:@thread_states).values
      expect(entries.length).to eq(1)
      expect(entries.first.fetch(:thread)).to be_a(WeakRef)
      expect(entries.first.fetch(:fiber)).to be_a(WeakRef)
    end

    # @return [Array<WeakRef>]
    def finished_context_references
      100.times.map do |index|
        owner = described_class.new
        owner.push_step(described_class::ItemHandle.new(uuid: "collectable-#{index}", kind: :step))
        owner.pop_step
        WeakRef.new(owner)
      end
    end

    # @return [Array<WeakRef, CaptureTarget>]
    def unfinished_context_references
      owner = described_class.new
      item = described_class::ItemHandle.new(uuid: "uncompleted-owner", kind: :step,
                                             metadata: { feature_key: "memory.feature", scenario_key: "memory-scenario" })
      owner.push_step(item)
      target = owner.register_capture_target(item, launch_uuid: "memory-launch", owner: owner)
      [WeakRef.new(owner), WeakRef.new(item), target]
    end

    it "does not retain completed contexts in a long-lived thread-local map" do
      described_class.new
      keys_before = Thread.current.keys.sort
      references = finished_context_references
      3.times { GC.start(full_mark: true, immediate_sweep: true) }
      expect(references.none?(&:weakref_alive?)).to be(true)
      expect(Thread.current.keys.sort).to eq(keys_before)
      expect(Thread.current[:rp_context_stack]).to be_empty
      expect(Thread.current[:reportportal_cucumber_context_state].values).to all(be_nil)
    end

    it "does not retain a dead context through metadata mirrors or its weak capture owner" do
      owner, item, target = unfinished_context_references
      3.times { GC.start(full_mark: true, immediate_sweep: true) }
      expect(owner.weakref_alive?).to be_falsey
      expect(described_class::CaptureTarget.owner_for(target)).to be_nil
      replacement = described_class.new
      expect(replacement.current_item).to be_nil
      3.times { GC.start(full_mark: true, immediate_sweep: true) }
      expect(item.weakref_alive?).to be_falsey
      expect(Thread.current[:rp_context_stack]).to be_empty
      expect(Thread.current[:reportportal_cucumber_context_state].values).to all(be_nil)
    end
  end

  describe "capture publication leases" do
    let(:item) { described_class::ItemHandle.new(uuid: "original-step", kind: :step) }
    let(:target) { context.register_capture_target(item, launch_uuid: "launch-1") }

    it "publishes outside both context locks and revokes in-flight work on bounded close" do
      entered = Queue.new
      resume = Queue.new
      result = Queue.new
      publisher = Thread.new do
        result << context.publish_capture_target(target, launch_uuid: "launch-1") do |original, cancelled|
          expect(original).to equal(item)
          expect(context.instance_variable_get(:@capture_mutex).owned?).to be(false)
          expect(context.instance_variable_get(:@mutex).owned?).to be(false)
          entered << cancelled
          resume.pop
          expect(cancelled.call).to be(true)
        end
      end
      cancelled = Timeout.timeout(2) { entered.pop }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(context.close_capture_targets(timeout: 0.01)).to be(false)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.15
      expect(cancelled.call).to be(true)
      expect(context.close_capture_targets(timeout: 0)).to be(true)
      resume << true
      expect(publisher.join(2)).not_to be_nil
      expect(result.pop).to be(false)
      expect(context.acquire_capture_target(target, launch_uuid: "launch-1")).to be_nil
    ensure
      resume << true if publisher&.alive?
      publisher&.join(2)
    end

    it "includes capture mutex acquisition in the close budget and remembers revocation" do
      target
      mutex = context.instance_variable_get(:@capture_mutex)
      entered = Queue.new
      resume = Queue.new
      holder = Thread.new { mutex.synchronize { entered << true; resume.pop } }
      Timeout.timeout(2) { entered.pop }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(context.close_capture_target(target, timeout: 0.01)).to be(false)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.15
      resume << true
      holder.join(2)
      expect(context.acquire_capture_target(target, launch_uuid: "launch-1")).to be_nil
      expect(context.close_capture_target(target, timeout: 0)).to be(true)
    ensure
      resume << true if holder&.alive?
      holder&.join(2)
    end

    it "releases publication reservations on exceptions and rejects foreign, wrong-launch and stale targets" do
      expect { context.publish_capture_target(target, launch_uuid: "launch-1") { raise "publisher failed" } }
        .to raise_error("publisher failed")
      foreign = described_class.new.register_capture_target(item, launch_uuid: "launch-1")
      expect(context.publish_capture_target(foreign, launch_uuid: "launch-1") { raise "retargeted" }).to be(false)
      expect(context.publish_capture_target(target, launch_uuid: "other") { raise "retargeted" }).to be(false)
      expect(context.close_capture_target_for_item(item, timeout: 0)).to be(true)
      replacement = described_class::ItemHandle.new(uuid: "next-step", kind: :step)
      context.register_capture_target(replacement, launch_uuid: "launch-1")
      expect(context.publish_capture_target(target, launch_uuid: "launch-1") { raise "retargeted" }).to be(false)
    end
  end

  it "stores the active feature, scenario, and step stack in Thread.current[:rp_context_stack]" do
    feature = described_class::ItemHandle.new(uuid: "feature-1", kind: :feature, name: "Feature", type: "SUITE", has_stats: true)
    scenario = described_class::ItemHandle.new(uuid: "scenario-1", kind: :scenario, name: "Scenario", parent_uuid: "feature-1", type: "STEP", has_stats: true)
    step = described_class::ItemHandle.new(uuid: "step-1", kind: :step, name: "Step", parent_uuid: "scenario-1", type: "STEP", has_stats: false)

    context.register_feature("features/a.feature", feature)
    context.activate_feature("features/a.feature", feature)
    context.start_scenario("features/a.feature:1", scenario)
    context.push_step(step)

    expect(Thread.current[:rp_context_stack].map(&:uuid)).to eq(%w[feature-1 scenario-1 step-1])
    expect(context.current_item_uuid).to eq("step-1")
    expect(context.active_parent_uuid).to eq("step-1")

    context.pop_step(expected_uuid: "step-1")
    context.finish_scenario(expected_uuid: "scenario-1")

    expect(Thread.current[:rp_context_stack].map(&:uuid)).to eq(["feature-1"])
    expect(context.current_item_uuid).to eq("feature-1")
    expect(context.active_parent_uuid).to eq("feature-1")
  end

  it "keeps the stack LIFO when an out-of-order finish asks to pop a parent" do
    feature = described_class::ItemHandle.new(uuid: "feature-1", kind: :feature, name: "Feature", type: "SUITE", has_stats: true)
    scenario = described_class::ItemHandle.new(uuid: "scenario-1", kind: :scenario, name: "Scenario", parent_uuid: "feature-1", type: "STEP", has_stats: true)
    step = described_class::ItemHandle.new(uuid: "step-1", kind: :step, name: "Step", parent_uuid: "scenario-1", type: "STEP", has_stats: false)

    context.register_feature("features/a.feature", feature)
    context.activate_feature("features/a.feature", feature)
    context.start_scenario("features/a.feature:1", scenario)
    context.push_step(step)

    expect(context.finish_scenario(expected_uuid: "scenario-1")).to be_nil
    expect(Thread.current[:rp_context_stack].map(&:uuid)).to eq(%w[feature-1 scenario-1 step-1])
  end
end
