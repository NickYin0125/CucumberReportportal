# frozen_string_literal: true

require "json"

module LedgerQATiming
  SAMPLES = Hash.new { |hash, key| hash[key] = [] }
  LOCK = Mutex.new
  WRAPPERS = []
  REPLAY = Hash.new { |hash, key| hash[key] = [] }

  def self.instrument(target, names, label)
    wrapper = Module.new
    names.each do |name|
      wrapper.define_method(name) do |*args, **keywords, &block|
        LedgerQATiming::LOCK.synchronize do
          calls = LedgerQATiming::REPLAY["#{label}.#{name}"]
          calls << [self, name, args, keywords, block] if calls.length < 16
        end
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          super(*args, **keywords, &block)
        ensure
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
          LedgerQATiming::LOCK.synchronize { LedgerQATiming::SAMPLES["#{label}.#{name}"] << elapsed * 1000 }
        end
      end
    end
    target.prepend(wrapper)
    WRAPPERS << [wrapper, names]
  end
end

if ReportportalCucumber.const_defined?(:Presentation)
  ReportportalCucumber::Presentation.constants(false).each do |name|
    target = ReportportalCucumber::Presentation.const_get(name)
    next unless target.is_a?(Module)
    LedgerQATiming.instrument(target.singleton_class, target.singleton_methods(false), name.to_s)
    LedgerQATiming.instrument(target, target.public_instance_methods(false), "#{name}#")
  end
end

at_exit do
  destination = ENV.fetch("QA_PRESENTATION_TIMINGS")
  # Remove only our observation methods before the actual micro-benchmark.
  # Otherwise nested clocks/sinks are incorrectly charged to the parent call.
  LedgerQATiming::WRAPPERS.each do |wrapper, names|
    names.each { |name| wrapper.send(:remove_method, name) }
  end
  replay, errors = {}, {}
  LedgerQATiming::REPLAY.each do |label, calls|
    samples = []
    calls.each do |receiver, name, args, keywords, block|
      begin
        10.times { receiver.public_send(name, *args, **keywords, &block) }
        50.times do
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          receiver.public_send(name, *args, **keywords, &block)
          samples << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
        end
      rescue StandardError => error
        (errors[label] ||= []) << error.class.name
      end
    end
    replay[label] = samples
  end
  File.write(destination, JSON.generate(schema: "inclusive-presentation-timings/1", unit: "milliseconds",
    note: "Observed real F01-F18 calls retain inclusive instrumented samples separately. Acceptance micro-benchmark replays their actual in-memory inputs after removing all QA wrappers, with 10 warmups and 50 measured calls/input. No input objects or environment values are serialized.",
    observed_instrumented_samples: LedgerQATiming::SAMPLES, samples: replay, replay_errors: errors))
end
