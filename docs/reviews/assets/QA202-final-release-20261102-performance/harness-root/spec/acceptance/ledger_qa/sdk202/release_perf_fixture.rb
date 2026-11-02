# frozen_string_literal: true

require_relative "../performance"

module ReleasePerfFixtureAudit
  def execute(env, command, directory)
    if env["LEDGER_EVIDENCE"] && (index = command.index("--no-profile"))
      command = command.dup
      command.insert(index + 1, "--require", File.join(__dir__, "release_perf_mode_support.rb"))
      env = env.merge("QA_RELEASE_EXPECTED_MODE" => @options.fetch(:mode))
    end
    super(env, command, directory)
  end
end

class ReleasePerfWall < LedgerQA::IsolatedRunner
  include ReleasePerfFixtureAudit
end
class ReleasePerfMicro < LedgerQA::TimedRunner
  include ReleasePerfFixtureAudit
end
class ReleasePerfParallel < LedgerQA::TimedParallelRunner
  include ReleasePerfFixtureAudit
end

if $PROGRAM_NAME == __FILE__
  kind = ARGV.shift
  exit({ "wall" => ReleasePerfWall, "micro" => ReleasePerfMicro, "parallel-micro" => ReleasePerfParallel }.fetch(kind).new(ARGV).run)
end
