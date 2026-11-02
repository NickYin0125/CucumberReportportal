@reportportal_live @F04
Feature: Frozen presentation failure
  Scenario: Failure and skipped follower

    Given independent fail
    Then independent follower stays skipped
