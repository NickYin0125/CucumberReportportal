@ui @tester_ui
Feature: Workday practice checkpoints
  A colleague should be able to follow a saved-word journey from the report.

  Scenario: Correct a typo and save the replacement using the keyboard
    Given I open the local practice page
    When the UI tester saves "handvoer" using Enter
    And the UI tester replaces the word with "handover" using Enter
    Then the practice status is "Saved: handover"
    And the UI tester records the "corrected-word-saved" checkpoint

  @intentional_failure
  Scenario: Recover the last saved word after an accidental refresh
    Given I open the local practice page
    When the UI tester saves "follow-up" using Enter
    Then the practice status is "Saved: follow-up"
    And the UI tester records the "saved-before-refresh" checkpoint
    When the UI tester refreshes the practice page
    Then the UI tester finds the restored word "follow-up"
