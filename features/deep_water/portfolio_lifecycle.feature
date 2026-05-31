@reportportal_live @deep_water
Feature: Portfolio Lifecycle Reporting
  This feature stresses Feature Description propagation with a realistic
  multi-step onboarding flow. It should become one top-level ReportPortal
  SUITE beside the other deep-water feature.

  Background:
    Given the portfolio reporting workspace is initialized

  Scenario: Onboard a structured portfolio
    The Scenario Description should be visible from ReportPortal item details.
    It also includes a DocString and a DataTable so the Ruby formatter must
    preserve business semantics instead of flattening everything to strings.

    When I submit the onboarding payload:
      """json
      {
        "account": "JPM-PRIME",
        "region": "APAC",
        "desk": "structured-credit",
        "limits": {
          "currency": "USD",
          "notional": 5000000
        }
      }
      """
    And I validate the portfolio exposure matrix:
      | account   | region | product | currency | exposure |
      | JPM-PRIME | APAC   | Swap    | USD      | 100      |
      | JPM-PRIME | APAC   | Option  | USD      | 110      |
      | JPM-PRIME | EMEA   | Bond    | EUR      | 120      |
      | JPM-PRIME | AMER   | Equity  | USD      | 130      |
      | JPM-PRIME | APAC   | FX      | JPY      | 140      |
      | JPM-PRIME | EMEA   | Repo    | EUR      | 150      |
      | JPM-PRIME | AMER   | CDS     | USD      | 160      |
      | JPM-PRIME | EMEA   | IRS     | GBP      | 170      |
      | JPM-PRIME | AMER   | Loan    | USD      | 180      |
      | JPM-PRIME | APAC   | NDF     | CNY      | 190      |
    Then the portfolio reporting payload should be accepted

  @rp.test_case_id=DEEP-PORTFOLIO-OUTLINE
  Scenario Outline: Price multi currency portfolios
    Each Examples row must become a distinct ReportPortal Scenario leaf
    with stable parameters and no UUID collision.

    When I price portfolio "<portfolio>" in "<region>" with risk "<risk>"
    Then the scenario outline payload should be tracked

    Examples:
      | portfolio | region | risk   |
      | alpha     | APAC   | low    |
      | beta      | EMEA   | medium |
      | gamma     | AMER   | high   |
