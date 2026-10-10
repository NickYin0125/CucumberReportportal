# language: en
@m3a @english
Feature: M3A English metadata fixture
  Feature description line one.
  Feature description line two.

  Background: shared English context
    Given the shared M3A feature context

  @english_rule
  Rule: English rule metadata
    Rule description belongs to the case context.

    Background: shared English rule context
      Rule background description.
      Given the shared M3A context

    Scenario: English ordinary case
      Ordinary scenario description.
      Given the shared M3A context
      When I verify the M3A table for "ordinary":
        | key       | value | escaped | newline | trailing |
        | ordinary  | plain | A\|B    | line\nnext |         |
      Then I verify the M3A document:
        """json
        {
          "record": "ordinary",
          "message": "line one\nline two",
          "slash": "path\\leaf",
          "template": "<not-a-parameter>",
          "fence": "```json"
        }
        """

    Scenario Outline: English outlined case <record>
      Outline description for <record>.
      Given the shared M3A context
      When I verify the M3A table for "<record>":
        | key       | value   | escaped | newline | trailing |
        | <record>  | <value> | A\|B    | line\nnext |         |
      Then I verify the M3A document:
        """json
        {
          "record": "<record>",
          "message": "line one\nline two",
          "slash": "path\\leaf",
          "template": "<template>",
          "fence": "```json"
        }
        """

      @block_one
      Examples: English first examples block
        | record | value  | template |
        | alpha  | first  | token-a  |
        | beta   | second | token-b  |

      @block_two
      Examples: English second examples block
        | record | value | template |
        | gamma  | third | token-c  |
        | delta  | fourth | token-d |
