@ui @independent
Feature: Practice page - independent UI journeys
  As a UI automation tester adopting the 2.0.1 client,
  I want step-owned screenshots and clear failure evidence in ReportPortal
  so that I can see what the browser showed at each important moment.

  Background:
    Given I open the local practice page

  Scenario: Save a word with accents, CJK and emoji
    When I practice the word "résumé 中文 ✓"
    Then the practice status is "Saved: résumé 中文 ✓"
    And I keep a screenshot of the page as evidence

  Scenario: The browser blocks an empty submission
    When I submit the practice form without a word
    Then the practice status is "Ready to practice"

  Scenario: Typing is capped at 80 characters
    When I type 100 letters into the practice word field
    Then the practice word field holds 80 characters

  Scenario: Practise several words in a row
    When I practice these words in order:
      | word      | note                 |
      | focus     | short                |
      | persevere | from the docs        |
      | 継続        | Japanese "continue" |
    Then the practice status is "Saved: 継続"
    And I keep a screenshot of the page as evidence

  Scenario Outline: Each saved word is echoed back (<word>)
    When I practice the word "<word>"
    Then the practice status is "Saved: <word>"

    Examples:
      | word          |
      | calm          |
      | O'Brien       |
      | <b>bold</b>   |

  @intentional_failure
  Scenario: Status copy uses the new punctuation style
    When I practice the word "persevere"
    Then the practice status is "Saved: persevere!"
