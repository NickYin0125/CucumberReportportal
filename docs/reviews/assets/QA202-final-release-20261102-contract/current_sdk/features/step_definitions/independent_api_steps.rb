# frozen_string_literal: true

# Steps written by an independent consumer of SDK 2.0.1. They reuse the
# example's observed API client, so every request carries AppLog.http evidence.

When(/^I POST the raw body (.+) expecting status (\d+)$/) do |payload, status|
  @response = api.request("POST", "/api/practice", body: payload, expected_status: status.to_i)
end

When("I POST a word of {int} letters expecting status {int}") do |count, status|
  word = "a" * count
  AppLog.info("Generated oversized word", report: true, json: {length: word.length, limit: 80})
  @response = api.request("POST", "/api/practice", body: JSON.generate(word: word), expected_status: status)
end

When("I send {word} to {string} expecting status {int}") do |method, path, status|
  @response = api.request(method, path, expected_status: status)
end

Then("the response body matches this JSON exactly:") do |document|
  expected = JSON.pretty_generate(JSON.parse(document))
  actual = JSON.pretty_generate(JSON.parse(@response.body))
  attach(actual, "application/json", "actual-response.json")
  check_equal("metadata contract", expected, actual)
end

Then("the saved word equals this text:") do |text|
  actual = JSON.parse(@response.body).fetch("word")
  log("Comparing the saved word with a #{text.lines.count}-line expectation")
  check_equal("saved word", text.to_s, actual)
end
