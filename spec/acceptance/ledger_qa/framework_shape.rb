# frozen_string_literal: true

require_relative "isolated"

module LedgerQA
  class FrameworkShapeRunner < IsolatedRunner
    def select_rows
      super.map do |row|
        row.merge(id: "F16b-framework-replay", unsupported: nil,
          source: "@reportportal_live @F16\nFeature: Controlled framework-only error input\n  Scenario: Explicit event input replay\n    Given QA controlled framework-only event failure\n",
          origin: "Controlled event-input replay, not a naturally generated JSON.parse stack. Original native F16b capture is retained separately.",
          limitations: ["The real raised error is recorded before adapting its formatter input. No frozen F04 input is read or changed."])
      end
    end

    def execute(env, command, directory)
      if (index = command.index("--no-profile"))
        command = command.dup
        command.insert(index + 1, "--require", File.join(ROOT, "spec/acceptance/ledger_qa/framework_shape_support.rb"))
        command[command.index("ReportPortal::Cucumber::Formatter")] = "LedgerQA::FrameworkShapeFormatter"
      end
      super(env, command, directory)
    end
  end
end

exit LedgerQA::FrameworkShapeRunner.new(ARGV).run if $PROGRAM_NAME == __FILE__
