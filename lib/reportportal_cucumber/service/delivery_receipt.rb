# frozen_string_literal: true

module ReportportalCucumber
  module Service
    # Immutable bounded summary of delivery through one accepted sequence cutoff.
    class DeliveryReceipt
      FIELDS = %i[
        cutoff settled confirmed accepted_awaiting_persistence spooled failed ambiguous possible_duplicates pending
        rejected capture_close_timeouts metadata_failures degraded_evidence complete local_settled timed_out
      ].freeze

      # @param values [Hash]
      def initialize(**values)
        FIELDS.each { |field| instance_variable_set("@#{field}", values.fetch(field)) }
        freeze
      end

      FIELDS.each do |field|
        # @return [Integer, Boolean]
        define_method(field) { instance_variable_get("@#{field}") }
      end

      # @return [Hash]
      def to_h
        FIELDS.to_h { |field| [field, public_send(field)] }.freeze
      end
    end
  end
end
