# frozen_string_literal: true

Given("QA202 contract {word}") do |kind|
  message = case kind
            when "regex" then 'expected "ABC" to match /\d+/'
            when "embedded_json" then 'HTTP 500 body: {"message":"a\"b"}'
            when "escaped_json" then 'request failed: "{\"api_key\":\"SECRET123\"}"'
            else raise "Unknown R01 contract companion"
            end
  LedgerDeveloper::Input.record("r01_contract_input", message: message)
  raise message
end
