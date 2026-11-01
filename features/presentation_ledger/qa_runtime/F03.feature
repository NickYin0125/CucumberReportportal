@reportportal_live @ledger_developer @F03 
Feature: Ledger developer F03
  Scenario Outline: doc-first
    Given ledger combined "doc-first":
      """
      CONSTANT_DOC
      """
      | key | value |
      | combined | <value> |

    Examples: Table-only substitution
      | value |
      | TABLE_ONLY_AMBER <other> |
      | TABLE_ONLY_BIRCH <other> |

  Scenario Outline: table-first
    Given ledger combined "table-first":
      | key | value |
      | combined | <value> |
      """
      CONSTANT_DOC
      """

    Examples: Table-only substitution
      | value |
      | TABLE_ONLY_AMBER <other> |
      | TABLE_ONLY_BIRCH <other> |

