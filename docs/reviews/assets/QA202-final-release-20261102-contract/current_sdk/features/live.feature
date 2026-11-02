@ui @live
Feature: Optional live Typewords smoke check
  Scenario: Open the locally hosted Typewords landing page
    Given I open Typewords
    Then the browser title contains "TypeWords"
