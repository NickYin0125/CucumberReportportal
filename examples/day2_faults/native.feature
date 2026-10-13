Feature: Day2 fault process lifecycle
  Scenario: preserve the first business outcome
    When I publish day2 evidence during a business action

  Scenario: do not run a second action after SIGINT
    Then I publish the second day2 marker
