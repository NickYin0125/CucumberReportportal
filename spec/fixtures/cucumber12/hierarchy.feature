Feature: Feature Rule and expanded examples
  Background:
    Given QA feature background

  Scenario: Outside rule
    Given QA passes

  Rule: Native rule suite
    Background:
      Given QA rule background

    Scenario Outline: Expanded <name>
      Given QA document for "<name>":
        """json
        {"name":"<name>","value":"A|B"}
        """
      And QA table for "<name>":
        | name   | value      |
        | <name> | line\nnext |

      Examples: First data set
        | name  |
        | alpha |
        | beta  |

      Examples: Second data set
        | name  |
        | gamma |
        | delta |
