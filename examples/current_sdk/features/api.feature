@api
Feature: Practice API contracts and diagnostic evidence
  Background:
    Given the local API is healthy

  Scenario: Create a practice session from a JSON document
    When I POST this JSON to the practice API:
      """json
      {"word":"persevere"}
      """
    Then the response status is 201
    And the JSON response includes:
      | field | value     |
      | word  | persevere |
      | saved | true      |

  Scenario Outline: Query practice word metadata
    When I GET metadata for "<word>"
    Then the response status is 200
    And the JSON response includes:
      | field  | value    |
      | word   | <word>   |
      | length | <length> |
      | kind   | practice |

    Examples:
      | word      | length |
      | persevere | 9      |
      | focus     | 5      |

  Scenario: Expected validation error is not a business failure
    When I submit an empty practice word expecting status 400
    Then the response status is 400
    And the JSON response includes:
      | field | value         |
      | error | word_required |
    And I record a non-fatal diagnostic comparison
