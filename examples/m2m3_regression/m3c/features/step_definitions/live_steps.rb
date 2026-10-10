# frozen_string_literal: true

Given("the recovery payload is") do |payload|
  @payload = payload
end

When("the recovery action is checked") do
  raise "recovery payload was not provided" unless @payload
end

Then("the recovery result is {word}") do |expected|
  raise "unexpected recovery result" if expected.empty?
end

When("the recovery service fails deliberately") do
  raise "M3C live acceptance deliberate service error"
end
