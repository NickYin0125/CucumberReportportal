# frozen_string_literal: true

# Deep business helper used by black-box Cucumber validation.
class ClearingMarginCalculator
  # @param account [String]
  # @param currency [String]
  # @return [Hash]
  def evaluate(account:, currency:)
    payload = {
      account: account,
      currency: currency,
      status: "ok",
      margin: {
        initial: 12_500,
        variation: 320,
        total: 12_820
      }
    }

    AppLog.info("Margin Payload", attach: true, json: payload)
    payload
  end
end
