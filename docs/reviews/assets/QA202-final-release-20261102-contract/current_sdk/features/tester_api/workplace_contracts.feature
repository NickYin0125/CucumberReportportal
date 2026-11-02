@api @tester_api
Feature: API tester workplace response contracts
  Scenario: Save a practice word at the supported length boundary
    Given the API tester prepares a practice word of 80 characters
    When the API tester submits the prepared practice word
    Then the API tester verifies the creation response

  @intentional_failure
  Scenario: Metadata includes the difficulty required by the consuming application
    When the API tester retrieves metadata for "focus"
    Then the API tester expects the following metadata contract:
      """json
      {"word":"focus","length":5,"kind":"practice","difficulty":"easy"}
      """
