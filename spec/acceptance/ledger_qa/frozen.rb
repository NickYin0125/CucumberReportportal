# frozen_string_literal: true

require_relative "isolated"

module LedgerQA
  class FrozenRunner < IsolatedRunner
    def run_row(row)
      id = { "F04" => "F04-frozen", "F16c" => "F16c-adapted", "F01" => "F01-supplement" }.fetch(row[:id], row[:id])
      id += "-golden" if row[:id].start_with?("F02")
      super(row.merge(id: id, logical_fixture: row[:id]))
    end

    def select_rows
      selected = super
      outline = selected.find { |row| row[:id] == "F02" }
      selected = selected.map do |row|
        if row[:id] == "F04"
          row.merge(source: File.read(File.join(ROOT, "features/presentation_ledger/f04_frozen.feature")),
            origin: "Explicit replay of the API-verified 62-frame original Launch 76 input; native stack recorded separately")
        elsif row[:id] == "F16c"
          row.merge(unsupported: nil, failed: 1, error: "QA_NON_EXCEPTION_FALLBACK",
            source: "@reportportal_live @F16\nFeature: Non-Exception event adapter\n  Scenario: Struct fallback\n    Given QA non-Exception fallback failure\n",
            origin: "Native failed status with explicitly adapted non-Exception message/backtrace event fields")
        elsif row[:id] == "F02" && @runtime.fetch("cucumber").to_i >= 12
          row.merge(source: row.fetch(:native_parser_sources).fetch("doc-first").gsub("\n\n    Examples:", "\n    Examples:"), scenarios: 2)
        else
          row
        end
      end
      if outline && @runtime.fetch("cucumber").to_i >= 12
        selected << outline.merge(id: "F02-table-first", source: outline.fetch(:native_parser_sources).fetch("table-first").gsub("\n\n    Examples:", "\n    Examples:"), scenarios: 2)
      elsif outline
        source = "@reportportal_live @F02\nFeature: Outline description golden companion\n  Scenario Outline: Frozen row descriptions\n    Given ledger records this table:\n      | key | value |\n      | combined | <value> |\n    # Physical row anchors are part of the P4 input.\n    # Compound arguments are covered separately under Decision 4.\n    # Keep Examples data on lines 12 and 13.\n    Examples: Table-only substitution\n      | value |\n      | TABLE_ONLY_AMBER |\n      | TABLE_ONLY_BIRCH |\n"
        selected << outline.merge(id: "F02-description-only", cucumber12: false, source: source, scenarios: 2,
          origin: "Decision 4 separate-argument description companion; native compound parse probes remain separate")
      end
      selected
    end

    def execute(env, command, directory)
      if command.last.to_s.end_with?("features/presentation_ledger/qa_runtime/F04-frozen.feature")
        directory = File.join(ROOT, "docs/reviews/assets/qa-frozen-working")
        FileUtils.mkdir_p(File.join(directory, "features"))
        File.write(File.join(directory, "features/audit.feature"), File.read(File.join(ROOT, "features/presentation_ledger/f04_frozen.feature")))
        command = command.dup
        command[-1] = "features/audit.feature"
        command.insert(command.index("--no-profile") + 1, "--require", File.join(ROOT, "spec/acceptance/ledger_qa/runtime-support.rb"))
        env = env.merge("LEDGER_FIXTURE" => "F04-frozen", "QA_FROZEN_FAILURE_INPUT" => File.join(ROOT, "docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json"))
      end
      if command.last.to_s.end_with?("features/presentation_ledger/qa_runtime/F16c-adapted.feature")
        env = env.merge("LEDGER_FIXTURE" => "F16c")
      end
      if command.last.to_s == "features/audit.feature" || command.last.to_s.end_with?("features/presentation_ledger/qa_runtime/F16c-adapted.feature")
        command = command.dup
        command.insert(command.index("--no-profile") + 1, "--require", File.join(ROOT, "spec/acceptance/ledger_qa/replay_support.rb"))
        command[command.index("ReportPortal::Cucumber::Formatter")] = "LedgerQA::ReplayFormatter"
      end
      super(env, command, directory)
    end
  end
end

exit LedgerQA::FrozenRunner.new(ARGV).run if $PROGRAM_NAME == __FILE__
