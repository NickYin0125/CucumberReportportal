@reportportal_live @ledger_developer @F02 
Feature: Ledger developer F02
  Scenario Outline: doc-first
    Given ledger combined "doc-first":
      """
      CONSTANT_DOC
      """
      | key | value |
      | combined | <value> |

    Examples: Table-only substitution
      | value |
      | TABLE_ONLY_AMBER |
      | TABLE_ONLY_BIRCH |

  Scenario Outline: table-first
    Given ledger combined "table-first":
      | key | value |
      | combined | <value> |
      """
      CONSTANT_DOC
      """

    Examples: Table-only substitution
      | value |
      | TABLE_ONLY_AMBER |
      | TABLE_ONLY_BIRCH |

