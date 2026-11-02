# frozen_string_literal: true

@component:identity @team:platform @owner:quality @layer:acceptance @priority:p1 @browser:chromium
Feature: Account recovery in a readable peer suite
  Feature prose stays on the suite; scenario prose and examples stay on cases.

  @layer:api @team:identity
  Rule: Recovery links preserve source and ownership
    Recovery links preserve the team's API ownership boundary.
    @component:recovery @owner:scenario-owner
    Scenario Outline: Recover an account for <persona>
      The recovery instructions remain readable for each account owner.
      Given the recovery payload is
        | field | value |
        | user  | <persona> |
      When the recovery action is checked
      Then the recovery result is <result>

      @tms:CASE-UI/42 @owner:identity-team @browser:webkit
      Examples: staff recovery
        | persona | result |
        | staff   | ready  |

      @tms:CASE-UI/43 @priority:p2
      Examples: guest recovery
        | persona | result |
        | guest   | ready  |

    @tms:CASE-UI/44
    Scenario: Reject a malformed recovery request
      Malformed requests are described without exposing account details.
      Given the recovery payload is
        """json
        {"user":"bad-input","format":"compact"}
        """
      When the recovery action is checked
      Then the recovery result is rejected

    @tms:CASE-UI/45
    Scenario: Preserve a deliberate service error
      The intentional failure remains visible with its original action log.
      When the recovery service fails deliberately
