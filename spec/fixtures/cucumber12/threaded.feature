Feature: Native joined thread reporting never guesses ownership
  @qa_thread_pass
  Scenario: Passing business with unowned child evidence
    Given QA joined thread evidence
    And QA passes

  @qa_thread_fail
  Scenario: Original business failure with unowned child evidence
    Given QA joined thread evidence
    And QA fails
