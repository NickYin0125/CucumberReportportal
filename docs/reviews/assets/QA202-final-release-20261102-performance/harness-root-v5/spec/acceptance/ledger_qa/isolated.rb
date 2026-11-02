# frozen_string_literal: true

require_relative "full_trace"

module LedgerQA
  class IsolatedRunner < FullTraceRunner
    def execute(env, command, directory)
      command = command.dup
      if (index = command.index("-e")) && command[index + 1].include?("LedgerDeveloper::Activation.activate!;")
        guard = <<~'RUBY'
          require "cucumber/load_path";
          $LOAD_PATH.delete("lib");
          qa_source = File.realpath(ENV.fetch("LEDGER_SDK_ROOT"));
          $LOAD_PATH.unshift(File.join(qa_source, "lib"));
          require File.join(qa_source, "lib/reportportal_cucumber");
          qa_loaded = $LOADED_FEATURES.grep(%r{/reportportal_cucumber(?:/|\.rb)});
          abort "QA source isolation failed before Cucumber execution" unless qa_loaded.all? { |path| File.realpath(path).start_with?(qa_source + "/lib/") };
        RUBY
        command[index + 1] = command[index + 1].sub("LedgerDeveloper::Activation.activate!;", "LedgerDeveloper::Activation.activate!; #{guard}")
      end
      process = super(env, command, directory)
      if env["LEDGER_EVIDENCE"] && File.file?(File.join(env["LEDGER_EVIDENCE"], "runtime.json"))
        runtime = JSON.parse(File.read(File.join(env["LEDGER_EVIDENCE"], "runtime.json")))
        selected = File.realpath(@options[:sdk_root])
        expected_version = File.read(File.join(selected, "lib/reportportal_cucumber/version.rb"))[/VERSION\s*=\s*["']([^"']+)/, 1]
        wrong_paths = runtime.fetch("loaded_sdk_files").reject { |path| File.realpath(path).start_with?(selected + "/lib/") }
        passed = wrong_paths.empty? && runtime["sdk_version"] == expected_version && !runtime["sdk_source_changed_during_fixture"]
        proof = { expected_source: selected, expected_version: expected_version, actual_version: runtime["sdk_version"],
                  wrong_source_paths: wrong_paths, source_changed: runtime["sdk_source_changed_during_fixture"], passed: passed }
        write(File.join(env["LEDGER_EVIDENCE"], "source-guard.json"), proof)
        process[:source_guard] = proof
        process[:exit] = 2 unless passed
      end
      process
    end
  end
end

exit LedgerQA::IsolatedRunner.new(ARGV).run if $PROGRAM_NAME == __FILE__
