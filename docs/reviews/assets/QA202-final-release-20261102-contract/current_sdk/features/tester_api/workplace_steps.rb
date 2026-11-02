# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module ApiTesterWorkplaceSteps
  def api_tester_exchange(method, path, body: nil, expected_status:)
    uri = URI("#{CurrentSDK::FIXTURE.url}#{path}")
    request = Net::HTTP.const_get(method.capitalize).new(uri)
    request["Content-Type"] = "application/json"
    request.body = body unless body.nil?
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = begin
      Net::HTTP.start(uri.host, uri.port, nil, open_timeout: 2, read_timeout: 3, write_timeout: 3) do |http|
        http.request(request)
      end
    rescue StandardError => error
      AppLog.http(method: method, url: uri.to_s, error: error, expected_status: expected_status)
      raise
    end
    AppLog.http(method: method, url: uri.to_s,
                request: {headers: request.to_hash, body: request.body},
                response: {status: response.code.to_i, headers: response.to_hash, body: response.body},
                duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2),
                expected_status: expected_status)
    response
  end

  def api_tester_compare(name, expected, actual)
    passed = expected == actual
    AppLog.assertion(name: name, expected: expected, actual: actual, passed: passed)
    raise "#{name}: expected #{expected.inspect}, got #{actual.inspect}" unless passed
  end
end

World(ApiTesterWorkplaceSteps)

Given("the API tester prepares a practice word of {int} characters") do |length|
  @api_tester_word = "a" * length
  log("Boundary contract: a practice word of exactly #{length} characters must be accepted.")
end

When("the API tester submits the prepared practice word") do
  @api_tester_response = api_tester_exchange("POST", "/api/practice",
                                             body: JSON.generate(word: @api_tester_word), expected_status: 201)
end

Then("the API tester verifies the creation response") do
  api_tester_compare("API tester creation status", 201, @api_tester_response.code.to_i)
  api_tester_compare("API tester saved word contract", {"word" => @api_tester_word, "saved" => true},
                     JSON.parse(@api_tester_response.body))
end

When("the API tester retrieves metadata for {string}") do |word|
  @api_tester_response = api_tester_exchange("GET", "/api/practice?#{URI.encode_www_form(word: word)}",
                                             expected_status: 200)
end

Then("the API tester expects the following metadata contract:") do |document|
  api_tester_compare("API tester metadata status", 200, @api_tester_response.code.to_i)
  expected = JSON.parse(document)
  actual = JSON.parse(@api_tester_response.body)
  # A contract delta answers a different question from the HTTP response preview.
  attach(JSON.pretty_generate(missing_fields: expected.keys - actual.keys,
                              unexpected_fields: actual.keys - expected.keys),
         "application/json", "api-tester-contract-delta.json")
  api_tester_compare("API tester consumer metadata contract", expected, actual)
end
