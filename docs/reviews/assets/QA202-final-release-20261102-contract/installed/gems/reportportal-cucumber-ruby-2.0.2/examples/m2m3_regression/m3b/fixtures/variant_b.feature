Feature: M3B stable identity fixture

  # Deliberately unrelated line insertion: line-based identity would drift.
  Rule: Stable source fallback group

    @m3b_env_id @tms:CASE-EXPLICIT-42
    Scenario: Explicit payment identity
      Given an M3B case "explicit" with amount "10"

    Scenario: Source fallback identity
      Given an M3B case "fallback" with amount "20"

    Scenario Outline: Dataset identity
      Given an M3B case "<case>" with amount "<amount>"

      Examples:
        | amount | region | case  |
        | 30     | north  | alpha |
        | 40     | south  | beta  |

  @m3b_retry
  Scenario: Retry keeps case identity but separates execution
    When an M3B fail-once action runs
