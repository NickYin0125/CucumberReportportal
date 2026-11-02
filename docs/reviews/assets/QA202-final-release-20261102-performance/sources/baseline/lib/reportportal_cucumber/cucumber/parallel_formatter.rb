# frozen_string_literal: true

require_relative "formatter"

module ReportportalCucumber
  module Cucumber
    # Workers report items to an existing launch. Only the parent/CI may close
    # that launch, after every worker and its bounded reporting queue has settled.
    class ParallelFormatter < Formatter
      private

      def validate_configuration!
        return unless @config.reporting_requested?
        return if @config.ci_owned_launch?

        raise ConfigurationError,
              "ParallelFormatter requires CI-owned RP_LAUNCH_UUID; the parent must start the launch " \
              "and finish it once all workers complete. Legacy RP_CLIENT_JOIN is not supported."
      end
    end
  end
end
