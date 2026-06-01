# frozen_string_literal: true

When("the clearing margin calculator evaluates a valid payload") do
  @margin_result = ClearingMarginCalculator.new.evaluate(account: "ACC-9000", currency: "USD")
end

Then("the margin calculation should be accepted") do
  expect(@margin_result).to include(status: "ok")
  expect(@margin_result.fetch(:margin).fetch(:total)).to eq(12_820)
end
