Feature: Compiled Outline values retain literal angle brackets
  Scenario Outline: Doc-first <case_key>
    Given I show combined "doc-first":
      """
      CONSTANT_DOC
      """
      | key      | value   |
      | combined | <value> |

    Examples:
      | case_key | value                    |
      | amber    | TABLE_ONLY_AMBER <other> |
      | birch    | TABLE_ONLY_BIRCH <other> |

  Scenario Outline: Table-first <case_key>
    Given I show combined "table-first":
      | key      | value   |
      | combined | <value> |
      """
      CONSTANT_DOC
      """

    Examples:
      | case_key | value                    |
      | amber    | TABLE_ONLY_AMBER <other> |
      | birch    | TABLE_ONLY_BIRCH <other> |
