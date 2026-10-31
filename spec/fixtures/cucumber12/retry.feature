Feature: Native retry lifecycles
  @qa_flaky_alpha
  Scenario: Flaky alpha
    Given QA flaky "alpha"

  @qa_flaky_beta
  Scenario: Flaky beta
    Given QA flaky "beta"

  @qa_permanent
  Scenario: Permanent failure before a later flaky case
    Given QA fails

  @qa_budget_later
  Scenario: Flaky case after a permanent failure
    Given QA flaky "later"
