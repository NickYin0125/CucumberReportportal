# frozen_string_literal: true

require_relative "isolated"

module LedgerQA
  class NativeHooksRunner < IsolatedRunner
    def select_rows
      kinds = @options[:sdk_root].include?("baseline") ? %w[native retry] : %w[native retry fault]
      kinds.map do |kind|
        { id: "F15-hooks-#{kind}", hook_case: kind,
          source: "@reportportal_live\nFeature: Independent native named hooks #{kind}\n  Scenario: Scalar hook metadata #{kind}\n    Given QA named hook business step\n",
          origin: kind == "fault" ? "Controlled event-input metadata getter fault, not a naturally faulty Cucumber Hook" : "Ordinary native Cucumber named hooks; retry uses --retry 1 and an intentionally failing first attempt" }
      end
    end

    def child_environment(row, wire, directory)
      super.merge("QA_NATIVE_HOOK_CASE" => row.fetch(:hook_case))
    end

    def execute(env, command, directory)
      if (index = command.index("--no-profile"))
        command = command.dup
        command.insert(index + 1, "--require", File.join(ROOT, "spec/acceptance/ledger_qa/native_hooks_support.rb"))
        command[command.index("ReportPortal::Cucumber::Formatter")] = "LedgerQA::NativeHookFormatter"
        extra = ["--format", "LedgerQA::NativeHookAudit", "--out", File.join(env.fetch("LEDGER_EVIDENCE"), "hooks-audit.out")]
        extra += ["--retry", "1"] if env["QA_NATIVE_HOOK_CASE"] == "retry"
        command.insert(command.length - 1, *extra)
      end
      super(env, command, directory)
    end
  end
end

exit LedgerQA::NativeHooksRunner.new(ARGV).run if $PROGRAM_NAME == __FILE__
