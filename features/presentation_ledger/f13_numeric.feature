@reportportal_live @ledger_developer @F13
Feature: Ledger numeric table rendering inputs
  Scenario: Numeric columns retain their literal values
    Given ledger records this table:
      | account | qty        | price    | change | pct  | code    | mixed | blank |
      | A       | 100        | 1,234.50 | -12    | 12%  | 1.2.3   | 10    |       |
      | B       | 1,250      | 0.5      | +7     | 0.5% | USD 100 | n/a   |       |
      | C       | 12,345,678 | 98.10    | 42     | 100% | 1e3     | 30    |       |
    And ledger records this table:
      | not_numeric | also_not_numeric | invalid_group | unicode_minus |
      | .5          | 1e3              | 1,23          | −12           |
