@reportportal_live @parallel_join
Feature: Multi-process Join Verification
  Scenario: First process-aware verification path
    Given I record the current process identity for join verification
    Then the scenario should be part of a shared launch when run in parallel

  Scenario: Second process-aware verification path
    Given I record the current process identity for join verification
    Then the scenario should be part of a shared launch when run in parallel
