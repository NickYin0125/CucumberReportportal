# frozen_string_literal: true

require_relative "../../../script/acceptance/presentation_ledger_developer/support"

module LedgerQA
  class FrameworkShapeFormatter < ReportportalCucumber::Cucumber::Formatter
    FRAMES = [
      "/qa/gems/controlled-one/first.rb:11:in 'Framework.one'",
      "/qa/gems/controlled-two/second.rb:22:in 'Framework.two'",
      "/qa/gems/controlled-three/third.rb:33:in 'Framework.three'",
      "/qa/gems/controlled-four/fourth.rb:44:in 'Framework.four'",
      "-e:7:in 'runner'", "<internal:kernel>:90:in 'require'"
    ].freeze

    def extract_error(event)
      original = super
      return original unless original.message == "QA_FRAMEWORK_REPLAY"
      @qa_framework_errors ||= {}
      @qa_framework_errors[original.object_id] ||= begin
        LedgerDeveloper::Input.record("natural_native_error_observation", message: original.message,
          backtrace: original.backtrace, note: "Not the no-project test input; native Ruby includes project step-definition frames.")
        LedgerDeveloper::Input.record("controlled_framework_only_event_input", error_class: "RuntimeError",
          message: "Controlled framework-only replay", backtrace: FRAMES, frame_count: 6,
          framework_count: 4, runner_count: 2, project_count: 0,
          provenance: "Explicit synthetic formatter input; not a naturally generated stack and not the frozen F04 input.")
        RuntimeError.new("Controlled framework-only replay").tap { |error| error.set_backtrace(FRAMES) }
      end
    end
  end
end

Given("QA controlled framework-only event failure") { raise "QA_FRAMEWORK_REPLAY" }
