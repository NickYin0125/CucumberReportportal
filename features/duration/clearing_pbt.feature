@duration @duration_regression @clearing_pbt @pbt
Feature: Clearing Duration Property Bombardment
  Property-based traffic should keep clearing ingest and margin calculation stable under
  boundary strings, huge amounts, and deeply nested trade metadata.

  Scenario: Generated trade JSON survives repeated clearing API bombardment
    Given the clearing duration PBT target is configured
    When I bombard the clearing duration APIs with generated trade JSON
    Then the clearing duration PBT run should finish without unexpected API failures
