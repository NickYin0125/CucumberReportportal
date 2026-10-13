@duration @clearing_workflow
Feature: Duration Clearing Workflow
  The clearing workflow should prove the long business chain from trade intake
  through validation, netting, margin, and settlement polling.

  Scenario: Clear a duration trade through settlement completion
    Given the duration clearing API is available
    When I submit a duration trade into clearing
    And the trade passes clearing validation
    And the trade is included in netting
    And margin is calculated for the netted batch
    Then settlement polling reaches COMPLETED
    And a CSV settlement report is attached
