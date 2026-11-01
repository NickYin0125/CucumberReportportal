@reportportal_live @ledger_developer @F04 @ledger_failure_jpeg
Feature: Ledger developer F04
  Scenario: Failure and skipped follower
    Given ledger deep failure
    Then ledger follower must not execute
