@reportportal_live
Feature: ReportPortal Protocol Calibration
  Scenario: tc01 long text api log renders as a debug code block
    When I emit a long formatted API debug log with 500 lines
    Then the long debug log payload should be prepared

  Scenario: tc02 multi mime attachments stay aligned inside one step
    When I upload multiple mime attachments in the same step
    Then the multi mime attachment payload should be prepared

  Scenario: tc03 nested manual steps preserve the scenario tree
    When I perform a nested business flow with manual steps
    Then the nested step hierarchy should be prepared
