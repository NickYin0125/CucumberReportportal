Feature: Readable API evidence
  Show a compact terminal summary and structured report evidence without making
  an external business request. Enable the RP formatter to send the same evidence
  to ReportPortal.

  Scenario: Explain an expected rejected trade
    When I record an expected trade rejection
    Then I record the diagnostic context
