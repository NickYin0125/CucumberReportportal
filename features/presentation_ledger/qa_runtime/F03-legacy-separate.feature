@reportportal_live @ledger_developer @F03 
Feature: Ledger developer F03-legacy-separate
  Scenario Outline: doc-first separate argument companion
    Given ledger legacy separate document:
      """
      CONSTANT_DOC
      """
    Given ledger legacy separate table:
      | key | value |
      | combined | <value> |
    Then ledger verifies separate arguments "<value>" in "doc-first" order

    Examples: Table-only substitution
      | value |
      | TABLE_ONLY_AMBER <other> |
      | TABLE_ONLY_BIRCH <other> |

  Scenario Outline: table-first separate argument companion
    Given ledger legacy separate table:
      | key | value |
      | combined | <value> |
    Given ledger legacy separate document:
      """
      CONSTANT_DOC
      """
    Then ledger verifies separate arguments "<value>" in "table-first" order

    Examples: Table-only substitution
      | value |
      | TABLE_ONLY_AMBER <other> |
      | TABLE_ONLY_BIRCH <other> |

