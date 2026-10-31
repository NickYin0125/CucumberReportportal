# frozen_string_literal: true

require_relative "../../../script/acceptance/presentation_ledger_developer/support"

module LedgerQA
  module HookBusiness
    @attempt = 0
    def self.next_attempt
      @attempt += 1
    end
  end

  class NativeHookFormatter < ReportportalCucumber::Cucumber::Formatter
    def complete_native_run(...)
      super
    ensure
      names = instance_variable_get(:@hook_names)
      LedgerDeveloper::Input.record("hook_metadata_after_complete_native_run", entries: names&.length || 0,
        cache_present: !names.nil?, finalized: !!instance_variable_get(:@finalized))
    end

    def handle_hook_test_step_created(event)
      if ENV["QA_NATIVE_HOOK_CASE"] == "fault" && event.test_step.text.to_s.match?(/\Abefore hook\z/i)
        LedgerDeveloper::Input.record("controlled_hook_name_getter_fault", native_name: event.hook.name,
          test_step_id: event.test_step.id, generic_text: event.test_step.text,
          provenance: "A new event input wraps a faulting name getter. Original Hook/event objects are neither mutated nor replaced on the Cucumber event bus.")
        proxy = Object.new
        def proxy.name
          raise "QA controlled metadata getter failure"
        end
        adapted = Struct.new(:test_step, :hook).new(event.test_step, proxy)
        super(adapted)
      else
        super
      end
    end
  end

  class NativeHookAudit
    def initialize(config)
      formatter = ReportportalCucumber.current_runtime
      config.on_event(:hook_test_step_created) do |event|
        LedgerDeveloper::Input.record("native_hook_descriptor", test_step_id: event.test_step.id,
          generic_text: event.test_step.text, native_name: event.hook.name)
      end
      config.on_event(:test_run_finished) do
        names = formatter.instance_variable_get(:@hook_names)
        LedgerDeveloper::Input.record("hook_metadata_at_test_run_finished", entries: names&.length || 0,
          cache_present: !names.nil?, formatter_class: formatter.class.name)
      end
    end
  end
end

Before(name: "Open browser") { log("QA_NAMED_BEFORE") }
After(name: "Close browser") { log("QA_NAMED_AFTER") }
AfterStep(name: "Inspect step") { log("QA_NAMED_AFTER_STEP") }
Given("QA named hook business step") do
  attempt = LedgerQA::HookBusiness.next_attempt
  LedgerDeveloper::Input.record("native_business_attempt", attempt: attempt)
  raise "QA intentional first retry failure" if ENV["QA_NATIVE_HOOK_CASE"] == "retry" && attempt == 1
  log("QA_NAMED_BUSINESS_PASSED")
end
