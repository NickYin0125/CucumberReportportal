@reportportal_live @triple_track
Feature: Triple Track Smart Logger
  AppLog should route deep business diagnostics to terminal, Cucumber HTML, and ReportPortal.

  Scenario: Deep business helper routes margin payload logs
    When the clearing margin calculator evaluates a valid payload
    Then the margin calculation should be accepted
