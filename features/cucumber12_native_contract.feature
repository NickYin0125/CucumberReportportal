@cucumber12_cli
Feature: Native Cucumber 12 HTTP reporting contract
  Scenario Outline: Real CLI business outcomes are not harness failures
    When a native Cucumber 12 process runs the "<tag>" contract case
    Then its native exit is <exit> and ReportPortal scenario status is "<status>"
    And its complete ReportPortal item tree has no wire violations

    Examples:
      | tag          | exit | status  |
      | qa_pass      | 0    | PASSED  |
      | qa_fail      | 1    | FAILED  |
      | qa_undefined | 1    | FAILED  |
      | qa_pending   | 1    | FAILED  |
      | qa_ambiguous | 1    | FAILED  |
      | qa_skip      | 0    | SKIPPED |
