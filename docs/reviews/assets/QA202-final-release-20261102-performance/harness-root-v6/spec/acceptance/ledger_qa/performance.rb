# frozen_string_literal: true

require_relative "parallel"

module LedgerQA
  module TimedChild
    def execute(env, command, directory)
      if env["LEDGER_EVIDENCE"] && (index = command.index("--no-profile"))
        command = command.dup
        command.insert(index + 1, "--require", File.join(ROOT, "spec/acceptance/ledger_qa/performance_support.rb"))
        env = env.merge("QA_PRESENTATION_TIMINGS" => File.join(env.fetch("LEDGER_EVIDENCE"), "presentation-timings.json"))
      end
      super(env, command, directory)
    end
  end
  class TimedRunner < IsolatedRunner
    include TimedChild
  end
  class TimedParallelRunner < ParallelRunner
    include TimedChild
  end
end

if $PROGRAM_NAME == __FILE__
  kind = ARGV.shift
  runner = { "wall" => LedgerQA::IsolatedRunner, "micro" => LedgerQA::TimedRunner,
    "parallel-micro" => LedgerQA::TimedParallelRunner }.fetch(kind)
  exit runner.new(ARGV).run
end
