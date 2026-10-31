# frozen_string_literal: true

module ReportportalCucumber
  module Cucumber
    # Cucumber 12 emits run-hook results before test_run_finished, including
    # caught AfterAll failures. These hooks have no feature/scenario association.
    class NativeLifecycle
      # @param cucumber_config [Object]
      # @param formatter [ReportportalCucumber::Cucumber::Formatter]
      # @return [Boolean] Whether native run-hook events can be observed.
      def self.attach(cucumber_config:, formatter:)
        return false unless cucumber_config.respond_to?(:on_event) && cucumber_config.respond_to?(:event_bus)
        return false if cucumber_config.respond_to?(:dry_run?) && cucumber_config.dry_run?

        attached = cucumber_config.event_bus.instance_variable_get(:@reportportal_native_lifecycle_formatters)
        if attached
          attached << formatter unless attached.any? { |existing| existing.equal?(formatter) }
          return true
        end
        attached = [formatter]
        cucumber_config.event_bus.instance_variable_set(:@reportportal_native_lifecycle_formatters, attached)

        cucumber_config.on_event(:test_run_hook_started) do |event|
          attached.each { |observer| observer.start_native_run_hook(hook: event.hook) }
        end
        cucumber_config.on_event(:test_run_hook_finished) do |event|
          attached.each { |observer| observer.finish_native_run_hook(result: event.test_result) }
        end
        cucumber_config.on_event(:test_run_finished) do |event|
          reporting_error = nil
          attached.each do |observer|
            begin
              observer.__send__(:handle_test_run_finished, event)
            rescue Exception => error
              # Settle every sibling before propagating a reporting policy error.
              reporting_error ||= error
            end
          end
          raise reporting_error if reporting_error
        end
        true
      end
    end
  end
end
