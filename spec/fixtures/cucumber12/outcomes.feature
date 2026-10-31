Feature: Native outcomes without removed strict mode
  @qa_pass @qa_around
  Scenario: Passing native media
    Given QA native media
    And QA passes

  @qa_fail
  Scenario: Failed business action
    Given QA fails
    And QA passes

  @qa_undefined
  Scenario: Undefined action
    Given QA has no definition
    And QA passes

  @qa_pending
  Scenario: Pending action
    Given QA is pending
    And QA passes

  @qa_ambiguous
  Scenario: Ambiguous action
    Given QA ambiguous phrase
    And QA passes

  @qa_skip
  Scenario: Explicitly skipped action
    Given QA is skipped
    And QA passes
