# frozen_string_literal: true

require "spec_helper"
require "cucumber/hooks"
require "cucumber/events"
require "cucumber/core/test/hook_step"
require "cucumber/core"

RSpec.describe ReportportalCucumber::Cucumber::Formatter do
  let(:formatter) { described_class.allocate }
  let(:source) { Struct.new(:keyword, :text, :data_table, :doc_string).new("Given ", "step <x>", nil, nil) }
  let(:descriptor) { ReportportalCucumber::ReportPortal::Models::StepDesc.new(step: source) }

  before { formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new) }

  it "omits descriptions for all fifty argument-free steps" do
    50.times do
      expect(formatter.send(:extract_step_description, { hook: false }, descriptor: descriptor)).to be_nil
    end
  end

  it "emits exactly one argument-only INFO log, with unchanged owner and time, while descriptions keep the header" do
    source.data_table = Struct.new(:rows).new([["value"], ["1"]])
    buffer = double("buffer", emit_log: nil)
    time = Time.utc(2026, 10, 31)
    formatter.instance_variable_set(:@log_buffer, buffer)
    formatter.instance_variable_set(:@launch_uuid, "launch")
    allow(formatter).to receive(:monotonic_timestamp).with(time).and_return(time)
    expect(formatter.send(:extract_step_description, { hook: false }, descriptor: descriptor))
      .to eq("**Given** step &lt;x&gt;\n\n| value |\n| --: |\n| 1 |")
    formatter.send(:emit_step_markdown_log, item_uuid: "step", descriptor: descriptor, timestamp: time)
    expect(buffer).to have_received(:emit_log).once.with(
      item_uuid: "step", launch_uuid: "launch", level: :info, timestamp: time,
      message: "_Data table \u00b7 1 column \u00d7 1 row_\n\n| value |\n| --: |\n| 1 |"
    )
  end

  it "handles formatter-level render failure per message and leaves delivery errors outside its rescue" do
    source.data_table = Struct.new(:rows).new([["value"], ["1"]])
    buffer = double("buffer", emit_log: nil)
    logger = double("logger", warn: nil)
    time = Time.utc(2026, 10, 31)
    formatter.instance_variable_set(:@log_buffer, buffer)
    formatter.instance_variable_set(:@launch_uuid, "launch")
    allow(formatter).to receive(:monotonic_timestamp).and_return(time)
    allow(ReportportalCucumber).to receive(:logger).and_return(logger)
    allow(descriptor).to receive(:to_markdown).and_raise("SECRET123")
    expect(formatter.send(:extract_step_description, { hook: false }, descriptor: descriptor)).to eq(descriptor.baseline_markdown)
    formatter.send(:emit_step_markdown_log, item_uuid: "step", descriptor: descriptor, timestamp: time)
    expect(buffer).to have_received(:emit_log).once.with(hash_including(message: descriptor.baseline_markdown))
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).twice
    allow(buffer).to receive(:emit_log).and_raise(ReportportalCucumber::ReportingError, "delivery")
    expect { formatter.send(:emit_step_markdown_log, item_uuid: "step", descriptor: descriptor, timestamp: time) }
      .to raise_error(ReportportalCucumber::ReportingError, "delivery")
  end

  {
    "before" => ["Before hook", "BEFORE_METHOD"], "after" => ["After hook", "AFTER_METHOD"],
    "after_step" => ["AfterStep hook", "AFTER_METHOD"],
    "before_all" => ["BeforeAll hook", "BEFORE_CLASS"], "before_class" => ["BeforeAll hook", "BEFORE_CLASS"],
    "after_all" => ["AfterAll hook", "AFTER_CLASS"], "after_class" => ["AfterAll hook", "AFTER_CLASS"],
    "around" => ["Hook", "STEP"]
  }.each do |type, (label, wire_type)|
    it "uses the P6 #{type} display name without altering its wire type" do
      event = { hook_type: type, hook: true }
      ["Before hook", "After hook", "AfterStep hook", "BeforeAll hook", "AfterAll hook", "Around hook", "  HOOK  ", "after step HOOK"].each do |base|
        expect(formatter.send(:hook_display_name, event, base)).to eq(label)
      end
      expect(formatter.send(:hook_display_name, event, "Open browser")).to eq("#{label} \u00b7 Open browser")
      expect(formatter.send(:hook_display_name, event, " <named> *hook* ")).to eq("#{label} \u00b7  <named> *hook* ")
      expect(formatter.send(:reportportal_step_type, event)).to eq(wire_type)
    end
  end

  it "restores the original hook name and warns once if name presentation fails" do
    name = +"Before hook"
    allow(name).to receive(:match?).and_raise("SECRET123")
    logger = double("logger", warn: nil)
    allow(ReportportalCucumber).to receive(:logger).and_return(logger)
    expect(formatter.send(:hook_display_name, { hook_type: "before" }, name)).to eq("Before Hook: Before hook")
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end

  context "with native named hooks" do
    before do
      allow(formatter).to receive(:reporting_enabled?).and_return(true)
      formatter.instance_variable_set(:@hook_names, {})
      formatter.instance_variable_set(:@hook_names_mutex, Mutex.new)
    end

    { before: ["Before hook", "BEFORE_METHOD"], after: ["After hook", "AFTER_METHOD"],
      after_step: ["AfterStep hook", "AFTER_METHOD"] }.each do |kind, (label, wire_type)|
      it "keeps the native #{kind} name, including when it resembles an unnamed label" do
        location = ::Cucumber::Core::Test::Location.new("features/support/hooks.rb", 8)
        args = ["hook-#{kind}", location]
        args.insert(1, ::Cucumber::Core::Test::Step.new("business", "Given work", location)) if kind == :after_step
        step = ::Cucumber::Hooks.public_send("#{kind}_hook", *args) {}
        name = +"#{label}"
        hook = Struct.new(:name).new(name)
        created = ::Cucumber::Events.registry.fetch(:hook_test_step_created).new(step, hook)
        started = ::Cucumber::Events.registry.fetch(:test_step_started).new(step)
        formatter.send(:handle_hook_test_step_created, created)
        name.replace("caller mutated")
        2.times do
          expect(formatter.send(:extract_step_name, started)).to eq("#{label} \u00b7 #{label}")
          expect(formatter.send(:reportportal_step_type, started)).to eq(wire_type)
        end
        expect(step.text).to eq(label)
        expect(formatter.instance_variable_get(:@hook_names).values).to all(be_frozen)
      end
    end

    it "retains only named scalar metadata and ignores events after finalization" do
      event = { test_step: { id: "hook" }, hook: { name: "Open browser" } }
      formatter.send(:handle_hook_test_step_created, event)
      expect(formatter.instance_variable_get(:@hook_names)).to eq("hook" => "Open browser")
      [nil, "", "  "].each do |name|
        formatter.send(:handle_hook_test_step_created, event.merge(hook: { name: name }))
        expect(formatter.instance_variable_get(:@hook_names)).to be_empty
      end
      formatter.instance_variable_set(:@finalized, true)
      formatter.send(:handle_hook_test_step_created, event)
      expect(formatter.instance_variable_get(:@hook_names)).to be_empty
    end

    it "falls back once without leaking an exception when native metadata cannot be read" do
      hook = double("hook")
      allow(hook).to receive(:name).and_raise("SECRET123")
      logger = double("logger", warn: nil)
      allow(ReportportalCucumber).to receive(:logger).and_return(logger)
      formatter.send(:handle_hook_test_step_created, { test_step: { id: "hook" }, hook: hook })
      expect(formatter.send(:hook_display_name, { step_id: "hook", hook_type: "before" }, "Before hook"))
        .to eq("Before Hook: Before hook")
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end

    it "keeps concurrent named hooks separate" do
      threads = 8.times.map do |i|
        Thread.new do
          formatter.send(:handle_hook_test_step_created, { test_step: { id: i.to_s }, hook: { name: "Browser #{i}" } })
          formatter.send(:hook_display_name, { step_id: i.to_s, hook_type: "before" }, "Before hook")
        end
      end
      expect(threads.map(&:value)).to eq(8.times.map { |i| "Before hook \u00b7 Browser #{i}" })
    end
  end
end
