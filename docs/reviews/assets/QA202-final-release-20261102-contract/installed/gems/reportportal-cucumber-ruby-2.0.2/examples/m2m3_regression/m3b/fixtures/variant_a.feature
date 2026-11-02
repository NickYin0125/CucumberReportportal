Feature: M3B stable identity fixture

  Rule: Stable source fallback group

    @m3b_env_id @tms:CASE-EXPLICIT-42
    Scenario: Explicit payment identity
      Given an M3B case "explicit" with amount "10"

    Scenario: Source fallback identity
      Given an M3B case "fallback" with amount "20"

    Scenario Outline: Dataset identity
      Given an M3B case "<case>" with amount "<amount>"

      Examples:
        | case  | region | amount |
        | alpha | north  | 30     |
        | beta  | south  | 40     |

  @m3b_retry
  Scenario: Retry keeps case identity but separates execution
    When an M3B fail-once action runs
