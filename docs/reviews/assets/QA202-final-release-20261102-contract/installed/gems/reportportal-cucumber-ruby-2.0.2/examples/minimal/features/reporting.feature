Feature: Minimal ReportPortal example
  Scenario: Successful reporting flow
    Given a user exists
    When the user logs in
    Then the login succeeds
