# frozen_string_literal: true

require_relative "../../../script/acceptance/presentation_ledger_developer/support"

module LedgerQA
  # Only adapts explicit QA fixture inputs at the event boundary. It does not
  # change SDK source or claim the replay is the current native Ruby stack.
  class ReplayFormatter < ReportportalCucumber::Cucumber::Formatter
    def extract_error(event)
      original = super
      @qa_fixture_errors ||= {}
      return @qa_fixture_errors[original.object_id] if @qa_fixture_errors.key?(original.object_id)
      adapted = if ENV["LEDGER_FIXTURE"] == "F04-frozen" && original.message == "INDEPENDENT_FULL_BACKTRACE"
        input = JSON.parse(File.read(ENV.fetch("QA_FROZEN_FAILURE_INPUT")))
        raise "Frozen input has not been independently verified through the read API" unless input["source_api_verified"] && input["frame_count"] == 62
        LedgerDeveloper::Input.record("current_native_backtrace_observation", message: original.message, backtrace: original.backtrace)
        LedgerDeveloper::Input.record("frozen_presentation_input_replay", source_launch_id: input["source_launch_id"], source_log_id: input["source_log_id"],
                                      backtrace_sha256: input["backtrace_sha256"], frame_count: input["frame_count"])
        RuntimeError.new(input.fetch("error_message")).tap { |error| error.set_backtrace(input.fetch("backtrace").split("\n")) }
      elsif ENV["LEDGER_FIXTURE"] == "F16c" && original.message == "QA_NON_EXCEPTION_FALLBACK"
        fields = { result: { status: "failed", message: "Non-Exception failure", backtrace: [] } }
        LedgerDeveloper::Input.record("non_exception_event_adapter", fields: fields, native_status: "failed")
        super(fields)
      else
        original
      end
      @qa_fixture_errors[original.object_id] = adapted
    end
  end
end

Given("QA non-Exception fallback failure") { raise "QA_NON_EXCEPTION_FALLBACK" }
