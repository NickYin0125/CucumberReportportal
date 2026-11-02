@reportportal_live @ledger_developer @F14
Feature: Ledger literal markup and outline fallback inputs
  Scenario Outline: Escaping matrix
    Given ledger literal <value>
    And ledger records this table:
      | value   |
      | <value> |
    Examples: Literal values
      | value                     |
      | <other>                   |
      | <b>x</b>                  |
      | a \| b                    |
      | back\\slash               |
      | *star*                    |
      | _under_                   |
      | `tick`                    |
      | &amp;                     |
      | # heading                 |
      | 1. item                   |
      | x<script>alert(1)</script> |
      | emoji 🟢                  |
      | CJK 中文                  |
      | first\nsecond             |

  Scenario Outline: Five parameters force description fallback
    Given ledger literal <a><b><c><d><e>
    Examples:
      | a | b | c | d | e |
      | 1 | 2 | 3 | 4 | 5 |

  Scenario Outline: Long parameter forces description fallback
    Given ledger literal <value>
    Examples: Long value
      | value                                     |
      | 12345678901234567890123456789012345678901 |
