@reportportal_live
Feature: M4 reporting delivery acceptance
  Scenario: passing delivery scenario carries table, JSON, and screenshot evidence
    Given the M4 acceptance evidence table
      | check        | result |
      | ownership    | stable |
      | attachment   | png    |
    When I emit the M4 JSON and screenshot evidence
    Then the M4 passing business assertion holds

  Scenario: deliberate business failure remains visible after evidence capture
    Given the M4 acceptance evidence table
      | check      | result |
      | failure    | retained |
    When I emit the M4 JSON and screenshot evidence
    Then the deliberate M4 business failure is raised
