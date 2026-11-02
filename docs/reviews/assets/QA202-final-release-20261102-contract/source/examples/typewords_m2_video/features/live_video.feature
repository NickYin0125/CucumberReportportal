Feature: Typewords M2 finalized viewport recording

  Scenario: A failed browser action publishes its finalized testcase recording
    Given I record Typewords dictionary navigation and return to Words
    When I click an intentionally absent Typewords control
