@reportportal_live @F02
Feature: Outline description golden companion
  Scenario Outline: Frozen row descriptions
    Given ledger records this table:
      | key | value |
      | combined | <value> |
    # Physical row anchors are part of the P4 input.
    # Compound arguments are covered separately under Decision 4.
    # Keep Examples data on lines 12 and 13.
    Examples: Table-only substitution
      | value |
      | TABLE_ONLY_AMBER |
      | TABLE_ONLY_BIRCH |
