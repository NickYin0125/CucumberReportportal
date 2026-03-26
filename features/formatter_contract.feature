@stubbed
Feature: Formatter contract
  Scenario: Replay fixture events through the formatter
    Given ReportPortal HTTP is stubbed
    When I replay the NDJSON fixture through the formatter
    Then the ReportPortal call sequence is correct
