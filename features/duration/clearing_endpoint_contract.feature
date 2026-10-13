@duration @clearing_mock @endpoint_contract
Feature: Clearing mock endpoint contract
  Each clearing mock endpoint is exercised in isolation so duration runs can
  identify which single interface regressed.

  Background:
    Given the clearing mock server base URL is configured

  Scenario: Ingest endpoint accepts a trade batch
    When I submit a valid trade batch to the clearing ingest endpoint
    Then the clearing mock response should be successful
    And the clearing mock response body should be JSON

  Scenario: Validate endpoint accepts a valid trade
    When I submit a valid trade to the clearing validate endpoint
    Then the clearing mock response should be successful
    And the clearing mock response body should be JSON

  Scenario: Validate endpoint rejects an invalid trade payload
    When I submit an invalid trade payload to the clearing validate endpoint
    Then the clearing mock response should be HTTP 400
    And the clearing mock response body should be JSON

  Scenario: Netting endpoint calculates a net exposure
    When I submit a netting request to the clearing netting endpoint
    Then the clearing mock response should be successful
    And the clearing mock response body should be JSON

  Scenario: Margin endpoint calculates margin requirements
    When I submit a margin request to the clearing margin endpoint
    Then the clearing mock response should be successful
    And the clearing mock response body should be JSON

  Scenario: Settlement poll endpoint returns a settlement snapshot
    When I poll the clearing settlement endpoint
    Then the clearing mock response should be successful
    And the clearing mock response body should be JSON
