# frozen_string_literal: true

require_relative "isolated"

module LedgerQA
  class ContractGapsRunner < IsolatedRunner
    def select_rows
      rows = [{ id: "F14-authored-logs", source: "@reportportal_live\nFeature: Independent authored log controls\n  Scenario: Literal user logs\n    Given QA authored raw logger controls\n" }]
      unless @options[:sdk_root].include?("baseline")
        rows << { id: "F19-missing-parts", source: "@reportportal_live\nFeature: Independent missing run-context parts\n  Scenario: No optional CI or Git parts\n    Given ledger literal context-with-optional-fields-absent\n" }
      end
      rows
    end

    def child_environment(row, wire, directory)
      env = super
      if row[:id] == "F19-missing-parts"
        %w[GITHUB_REF_NAME CI_COMMIT_REF_NAME BRANCH_NAME RP_SOURCE_COMMIT GITHUB_SHA CI_COMMIT_SHA
           GITHUB_RUN_ID CI_PIPELINE_ID BUILD_NUMBER PARALLEL_TEST_GROUPS].each { |key| env[key] = nil }
      end
      env
    end

    def execute(env, command, directory)
      if (index = command.index("--no-profile"))
        command = command.dup
        command.insert(index + 1, "--require", File.join(ROOT, "spec/acceptance/ledger_qa/contract_gaps_support.rb"))
      end
      super(env, command, directory)
    end
  end
end

exit LedgerQA::ContractGapsRunner.new(ARGV).run if $PROGRAM_NAME == __FILE__
