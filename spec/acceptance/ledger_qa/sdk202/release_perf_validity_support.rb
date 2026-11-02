# frozen_string_literal: true

require "json"

# Functional replay only. This observer never starts a performance stopwatch.
module ReleasePerfUntimedReplay
  OBSERVED = Hash.new(0)
  REPLAY = Hash.new { |h, k| h[k] = [] }
  WRAPPERS = []
  LOCK = Mutex.new

  def self.instrument(target, names, label)
    wrapper = Module.new
    names.each do |name|
      wrapper.define_method(name) do |*args, **kwargs, &block|
        key = "#{label}.#{name}"
        ReleasePerfUntimedReplay::LOCK.synchronize do
          ReleasePerfUntimedReplay::OBSERVED[key] += 1
          calls = ReleasePerfUntimedReplay::REPLAY[key]
          calls << [self, name, args, kwargs, block] if calls.length < 16
        end
        super(*args, **kwargs, &block)
      end
    end
    target.prepend(wrapper)
    WRAPPERS << [wrapper, names]
  end
end

ReportportalCucumber::Presentation.constants(false).each do |name|
  target = ReportportalCucumber::Presentation.const_get(name)
  next unless target.is_a?(Module)
  ReleasePerfUntimedReplay.instrument(target.singleton_class, target.singleton_methods(false), name.to_s)
  ReleasePerfUntimedReplay.instrument(target, target.public_instance_methods(false), "#{name}#")
end

at_exit do
  ReleasePerfUntimedReplay::WRAPPERS.each { |wrapper, names| names.each { |name| wrapper.send(:remove_method, name) } }
  replayed, errors = {}, {}
  ReleasePerfUntimedReplay::REPLAY.each do |label, calls|
    invoked = 0
    calls.each do |receiver, name, args, kwargs, block|
      begin
        10.times { receiver.public_send(name, *args, **kwargs, &block); invoked += 1 }
        50.times { receiver.public_send(name, *args, **kwargs, &block); invoked += 1 }
      rescue StandardError => error
        (errors[label] ||= []) << error.class.name
      end
    end
    replayed[label] = { inputs: calls.length, untimed_invocations: invoked }
  end
  File.write(File.join(ENV.fetch("LEDGER_EVIDENCE"), "presentation-validity.json"), JSON.pretty_generate(
    schema: "untimed-presentation-functional-replay/1", performance_acceptance: "NOT_ASSESSED",
    timing_collection: "DISABLED", timing_samples_collected: 0, observed_calls: ReleasePerfUntimedReplay::OBSERVED,
    replay: replayed, replay_errors: errors,
    note: "Same captured calls and 10+50 invocations per input, but no timing clock or performance sample") + "\n")
end
