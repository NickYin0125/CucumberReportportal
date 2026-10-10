# frozen_string_literal: true

@component:profile @team:experience @owner:profile-team @layer:ui @priority:p2 @browser:firefox
Feature: Profile settings in a separate peer suite
  A second suite makes the report topology visible without nesting Rules as nodes.

  @component:preferences
  Scenario: Save a profile preference
    Profile settings keep their own suite-level business context.
    Given the recovery payload is
      | field | value |
      | theme | light |
    When the recovery action is checked
    Then the recovery result is saved
