Feature: Typewords M2 live browser acceptance

  Scenario: Word-study navigation and learning view respond to interaction
    Given Typewords is open in a fresh browser context
    When I inspect and use the visible word-study navigation
    Then the word-study interface visibly changes

  Scenario: Manual grouping and structured passing assertion are reported
    When I report a manual diagnostic group and passing assertion
    Then the manual group action is recorded

  @intentional_failure
  Scenario: Missing locator reports caller-owned evidence and preserves the Playwright error
    When I deliberately wait for a missing locator and report browser evidence
