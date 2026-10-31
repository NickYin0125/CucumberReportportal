# frozen_string_literal: true

require_relative "run"

module LedgerQA
  class FullTraceRunner < Runner
    def environment
      super.merge("QA_FAULT_ENTRY" => ENV["QA_FAULT_ENTRY"], "QA_FALLBACK_CAPTURE" => ENV["QA_FALLBACK_CAPTURE"])
    end

    def execute(env, command, directory)
      command = command.dup
      if (index = command.index("--no-profile"))
        command.insert(index + 1, "--backtrace")
        command.insert(index + 2, "--require", File.join(ROOT, "spec/acceptance/ledger_qa/inject_fault.rb")) if env["QA_FAULT_ENTRY"]
      end
      super(env, command, directory)
    end
  end
end

exit LedgerQA::FullTraceRunner.new(ARGV).run if $PROGRAM_NAME == __FILE__
