# frozen_string_literal: true

require "rspec/core"
require "json"

module LedgerQADeadlineFixture
  def write(path, data, *args, **keywords)
    if RSpec.current_example&.description&.start_with?("shares one final deadline") &&
       File.basename(path.to_s) == "runner.rb" && data.is_a?(String)
      original = data
      data = data.sub(/def complete_native_run\(error: nil\)\n(.*?)\n(\s*)end/m) do
        body, indent = Regexp.last_match(1), Regexp.last_match(2)
        "def complete_native_run(error: nil)\nqa_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)\nbegin\n#{body}\nensure\n($qa_completion_seconds ||= []) << Process.clock_gettime(Process::CLOCK_MONOTONIC) - qa_started\nend\n#{indent}end"
      end
      data = data.sub("elapsed: Process.clock_gettime", "qa_completion_seconds: ($qa_completion_seconds || []), elapsed: Process.clock_gettime")
      raise "Independent deadline instrumentation did not match the fixture" if data == original
    end
    super(path, data, *args, **keywords)
  end
end
File.singleton_class.prepend(LedgerQADeadlineFixture)

module LedgerQADeadlineObservation
  def native_case(...)
    result = super
    if RSpec.current_example&.description&.start_with?("shares one final deadline")
      row = { source: self.class.metadata[:file_path], ruby: RUBY_DESCRIPTION,
              cucumber: Gem.loaded_specs.fetch("cucumber").version.to_s,
              total_seconds: result["elapsed"], completion_seconds: result["qa_completion_seconds"],
              exit: result["exit"], receipts: result["receipts"],
              original_exception_preserved: result["run_exception_identity"] && result["hook_exception_identity"],
              overall_bound_seconds: 0.5, finalization_budget_seconds: 0.05,
              original_assertions_unchanged: true }
      File.open(ENV.fetch("QA_DEADLINE_EVIDENCE"), "a") { |file| file.puts(JSON.generate(row)) }
    end
    result
  end
end

RSpec.configure do |config|
  config.before(:context) do
    self.class.prepend(LedgerQADeadlineObservation) if self.class.instance_methods.include?(:native_case)
  end
end
