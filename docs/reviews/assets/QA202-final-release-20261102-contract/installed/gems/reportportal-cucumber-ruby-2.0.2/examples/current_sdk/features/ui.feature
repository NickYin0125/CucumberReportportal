@ui
Feature: Browser interactions with a deterministic local page
  Background:
    Given I open the local practice page

  Scenario: Save a practice word
    When I practice the word "persevere"
    Then the practice status is "Saved: persevere"

  @intentional_failure
  Scenario: Missing locator preserves its Playwright error and screenshot
    When I click the deliberately missing practice button
