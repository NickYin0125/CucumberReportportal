# frozen_string_literal: true

Given("the local API is healthy") do
  response = api.request("GET", "/health", expected_status: 200)
  check_equal("health status", 200, response.code.to_i)
end

When("I POST this JSON to the practice API:") do |document|
  @response = api.request("POST", "/api/practice", body: document, expected_status: 201)
end

When("I GET metadata for {string}") do |word|
  @response = api.request("GET", "/api/practice?#{URI.encode_www_form(word: word)}", expected_status: 200)
end

When("I submit an empty practice word expecting status 400") do
  @response = api.request("POST", "/api/practice", body: JSON.generate(word: ""), expected_status: 400)
end

Then("the response status is {int}") do |expected|
  check_equal("response status", expected, @response.code.to_i)
end

Then("the JSON response includes:") do |table|
  actual = JSON.parse(@response.body)
  table.hashes.each do |row|
    check_equal("JSON field #{row.fetch('field')}", row.fetch("value"), actual.fetch(row.fetch("field")).to_s)
  end
end

Then("I record a non-fatal diagnostic comparison") do
  AppLog.assertion(name: "Optional diagnostic, not a business assertion",
                   expected: "successful creation", actual: "validation rejection", passed: false,
                   details: {business_contract: "400 was expected and asserted separately"})
end
