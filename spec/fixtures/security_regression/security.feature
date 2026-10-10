# frozen_string_literal: true
Feature: Security evidence regression

  Scenario: Public diagnostics stay bounded and redacted
    When I emit synthetic security diagnostics through the public API

  Scenario: Finite transport diagnostics cross real step boundaries
    When I emit a safe finite transport diagnostic
    And I emit a safe finite transport diagnostic
    And I emit a safe finite transport diagnostic
    And I emit a safe finite transport diagnostic
    And I emit a safe finite transport diagnostic
    And I emit a safe finite transport diagnostic
    And I emit a safe finite transport diagnostic

  @security_lifecycle
  Scenario: Capture targets stay bound to the current Cucumber action
    Given I save the first security capture target
    When I probe capture targets during the next step
