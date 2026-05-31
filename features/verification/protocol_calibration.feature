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

  @rich_layout
  Scenario: tc04 data table and rich evidence stay vertically aligned
    When I execute a richly structured step with a verification matrix:
      | buyer | region | product | currency | amount |
      | JPM   | APAC   | Swap    | USD      | 100    |
      | JPM   | APAC   | Option  | USD      | 110    |
      | GS    | EMEA   | Bond    | EUR      | 120    |
      | MS    | AMER   | Equity  | USD      | 130    |
      | UBS   | APAC   | FX      | JPY      | 140    |
      | BNP   | EMEA   | Repo    | EUR      | 150    |
      | CITI  | AMER   | CDS     | USD      | 160    |
      | BARC  | EMEA   | IRS     | GBP      | 170    |
      | BOA   | AMER   | Loan    | USD      | 180    |
      | HSBC  | APAC   | NDF     | CNY      | 190    |
    Then the rich evidence payload should be prepared
