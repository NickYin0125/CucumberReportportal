@reportportal_live @deep_water
Feature: Risk Control Media Evidence
  This feature validates that a second Feature file becomes a second
  top-level SUITE and that rich media evidence remains attached to the
  exact failing Step/Manual Step that produced it.

  Background:
    Given the risk control baseline is loaded

  @intentional_failure @mp4
  Scenario: Capture rich failure evidence
    The failure is intentional: it proves that error state, JSON context,
    and MP4 playback evidence stay bound to the failing Step.

    When the payment capture records a failing screen video

  Scenario Outline: Route risk audit channels
    Example rows should produce independent hasStats Scenario leaves.

    When I route audit message "<channel>" with severity "<severity>"
    Then audit routing metadata should be tracked

    Examples:
      | channel | severity |
      | slack   | info     |
      | pager   | critical |
