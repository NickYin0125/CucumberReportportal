@reportportal_live
Feature: ReportPortal Integration Deep Verification
  Scenario: Uploading various types of attachments
    Given a step that generates a text file attachment
    And a step that simulates a UI screenshot "verification_ui.png"
    And a step that generates a small PDF and binary attachment
    When I upload ordered attachments within the same step
    Then all attachments should be ready for ReportPortal inspection

  Scenario: Simulating API test with nested steps
    Given I perform a complex API transaction:
      | action | endpoint  | status |
      | Login  | /auth     | 200    |
      | Order  | /orders   | 201    |
      | Pay    | /payment  | 202    |
    Then the technical log payload should be recorded

  @rp.test_case_id=VERIFY-OUTLINE-ORDER
  Scenario Outline: Tracking scenario outline iterations
    Given I execute a purchase flow for "<user>" with currency "<currency>" and amount "<amount>"
    Then the outline metadata should be prepared for ReportPortal

    Examples:
      | user  | currency | amount |
      | alice | USD      | 10     |
      | bob   | EUR      | 20     |
      | carol | CNY      | 30     |
