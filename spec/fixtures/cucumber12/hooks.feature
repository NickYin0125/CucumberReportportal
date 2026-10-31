Feature: Native hook failures
  @qa_before_fail
  Scenario: Before raises
    Given QA passes

  @qa_after_fail
  Scenario: After raises
    Given QA passes

  @qa_afterstep_fail
  Scenario: AfterStep raises
    Given QA passes
    And QA passes

  @qa_around @qa_around_before_fail
  Scenario: Around raises before execution
    Given QA passes

  @qa_around @qa_around_after_fail
  Scenario: Around raises after execution
    Given QA passes
