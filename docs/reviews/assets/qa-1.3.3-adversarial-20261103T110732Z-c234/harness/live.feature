Feature: Independent minimal 1.x final acceptance
  Scenario: HTTP and supported separate arguments
    When independent structured HTTP evidence is recorded
    And independent DocString evidence is recorded
      """
      literal <script>qa_docstring</script> & back\slash
      """
    And independent DataTable evidence is recorded
      | key   | value                    |
      | label | <img src=x onerror=qa()> |
    Then independent attachment previews are recorded

  Scenario Outline: Outline value <value>
    When independent outline value "<value>" is checked
    Examples:
      | value       |
      | literal-one |
      | literal-two |

  @independent_failure
  Scenario Outline: Raw failure with After evidence <case>
    When independent raw business failure "<case>" occurs
    Examples:
      | case  |
      | first |
      | second |
