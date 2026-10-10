# frozen_string_literal: true

@component:payments @team:platform
Feature: M3C scenario link presentation
  Original feature prose remains byte-for-byte visible.

  | field | value |
  | mode  | links |

  @layer:checkout
  Rule: Checkout links
    Rule description remains before generated references.

    @tms:CASE-OUTLINE-42
    Scenario Outline: Link example <case>
      Scenario-specific outline prose remains unchanged.

      | outline | preserved |

      Given an M3C link case "<case>"

      Examples: First rows
        | case  |
        | alpha |

      Examples: Second rows
        | case |
        | beta |

  Rule: Retry links
    @tms:CASE-RETRY-7 @m3c_link_retry
    Scenario: Flaky retry link
      Retry Scenario prose remains unchanged.

      When an M3C link fail-once action runs

    @m3c_link_explicit @tms:CASE-TAG-SHOULD-LOSE
    Scenario: Explicit TMS selection
      Explicit Scenario prose remains unchanged.

      Given an M3C link case "explicit"
