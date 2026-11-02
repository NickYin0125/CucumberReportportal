# frozen_string_literal: true

When("I record an expected trade rejection") do
  # A deterministic observed-exchange sample, not an HTTP client or assertion.
  AppLog.http(
    method: :post,
    url: "https://clearing.example.test/api/trades?api_key=example-secret",
    request: {
      headers: { "Authorization" => "Bearer example-secret", "Content-Type" => "application/json" },
      body: { trade_id: "T-17", amount: -1, token: "example-secret" }
    },
    response: {
      status: 400,
      headers: { "Content-Type" => "application/json" },
      body: { code: "INVALID_AMOUNT", message: "amount must be positive" }
    },
    duration_ms: 84,
    expected_status: 400
  )
end

Then("I record the diagnostic context") do
  AppLog.debug("Trade diagnostic context", report: true, json: { trade_id: "T-17", dataset: "negative-amount" })
  AppLog.info("Local-only diagnostic", report: false)
end
