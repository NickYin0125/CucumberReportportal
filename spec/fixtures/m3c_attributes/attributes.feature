# frozen_string_literal: true

@component:payments @team:platform @owner:feature-owner @priority:low
@unknown:ignored @retry:1 @token:fixture-secret @password:fixture-password
@browser:invalid:colon
Feature: M3C scenario attributes

  @component:checkout @layer:api @priority:normal
  Rule: Checkout API

    @component:scenario @owner:scenario-owner @layer:api
    @priority:scenario-one @priority:scenario-two @tms:CASE-M3C-EXAMPLE
    Scenario Outline: Example row <case>
      Given an M3C attribute case "<case>"

      @component:examples-a @owner:examples-owner @owner:conflicting-owner
      @layer:table @layer:table @priority:high
      Examples: First dataset
        | case  |
        | alpha |

      @component:examples-b @team:examples-team
      @priority:examples-one @priority:examples-two
      Examples: Second dataset
        | case |
        | beta |

    @component:explicit @owner:scenario-owner @m3c_explicit @tms:CASE-M3C-EXPLICIT
    Scenario: Explicit TMS attribute
      Given an M3C attribute case "explicit"

  Rule: Retry behavior

    @component:retry @owner:retry-owner
    @m3c_retry
    Scenario: Retry retains attributes per execution
      When an M3C fail-once action runs
