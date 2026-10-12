# frozen_string_literal: true

module ReportportalCucumber
  module Cucumber
    # Observes actual AfterAll execution on one native Cucumber 9/10 registry.
    # Depends on those versions' private DSL registry/configuration association;
    # attachment is refused unless the event bus matches this formatter's run.
    # BeforeAll runs before formatter construction; an abort there creates no RP launch.
    # Run hooks are not test-step events and are not represented as class-hook items.
    class NativeLifecycle
      # @param cucumber_config [Object]
      # @param formatter [ReportportalCucumber::Cucumber::Formatter]
      # @return [Boolean] Whether native teardown completion can be observed.
      def self.attach(cucumber_config:, formatter:)
        return false unless cucumber_config.respond_to?(:event_bus) && cucumber_config.respond_to?(:dry_run?)
        return false if cucumber_config.dry_run?

        registry = ::Cucumber::Glue::Dsl.instance_variable_get(:@rb_language)
        return false unless registry && registry.respond_to?(:after_all)

        registry_config = registry.instance_variable_get(:@configuration)
        return false unless registry_config&.event_bus.equal?(cucumber_config.event_bus)

        attached = registry.instance_variable_get(:@reportportal_native_lifecycle_formatters)
        if attached
          attached << formatter unless attached.any? { |existing| existing.equal?(formatter) }
          return true
        end
        attached = [formatter]

        observer = Module.new do
          # @return [Object] Native hook return value; original exceptions are re-raised unchanged.
          define_method(:after_all) do
            original = nil
            begin
              result = super()
            rescue Exception => error # Run hooks may also abort with SystemExit/Interrupt.
              original = error
            end

            reporting_error = nil
            attached.each do |observer_formatter|
              begin
                observer_formatter.complete_native_run(error: original)
              rescue Exception => error
                # A sibling formatter's reporting error is not a native hook failure.
                reporting_error ||= error
              end
            end
            raise original if original
            raise reporting_error if reporting_error

            result
          end
        end
        registry.singleton_class.prepend(observer)
        registry.instance_variable_set(:@reportportal_native_lifecycle_formatters, attached)
        true
      end
    end
  end
end
