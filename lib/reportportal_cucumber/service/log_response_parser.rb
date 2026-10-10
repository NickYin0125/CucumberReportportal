# frozen_string_literal: true

module ReportportalCucumber
  module Service
    # Parses only the documented v1 acknowledgement shapes; all uncertainty stays explicit.
    module LogResponseParser
      module_function

      # @param body [Object]
      # @param entries [Array<Hash>]
      # @return [Array<Symbol>] Per-entry :confirmed, :failed, or :ambiguous.
      def outcomes(body:, entries:)
        return [] if entries.empty?

        if body.is_a?(Hash) && body["id"].is_a?(String) && !body["id"].empty? && entries.length == 1
          return [:confirmed]
        end

        responses = body.is_a?(Hash) && body["responses"]
        return Array.new(entries.length, :ambiguous) unless responses.is_a?(Array)
        return Array.new(entries.length, :ambiguous) if responses.length > entries.length

        entries.each_index.map do |index|
          response = responses[index]
          if response.nil?
            :ambiguous
          elsif response.is_a?(Hash) && response["id"].is_a?(String) && !response["id"].empty?
            :confirmed
          elsif response.is_a?(Hash) && response["message"].is_a?(String) && !response.key?("id")
            :failed
          else
            :ambiguous
          end
        end
      end

    end
  end
end
