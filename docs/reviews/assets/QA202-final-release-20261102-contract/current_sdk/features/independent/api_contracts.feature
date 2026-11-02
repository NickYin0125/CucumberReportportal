@api @independent
Feature: Practice API - independent consumer contract checks
  As an API automation tester adopting the 2.0.1 client,
  I want request/response evidence, tables and JSON in ReportPortal
  so that I can diagnose a failed contract without re-running it.

  Background:
    Given the local API is healthy

  Scenario: Save a word that uses accents, CJK and emoji
    When I POST this JSON to the practice API:
      """json
      {"word": "résumé 中文 ✓"}
      """
    Then the response status is 201
    And the JSON response includes:
      | field | value       |
      | word  | résumé 中文 ✓ |
      | saved | true        |

  Scenario: Metadata length counts characters, not bytes
    When I GET metadata for "naïve"
    Then the response status is 200
    And the JSON response includes:
      | field  | value |
      | word   | naïve |
      | length | 5     |

  Scenario Outline: Reject a practice payload that has no usable word (<case>)
    When I POST the raw body <payload> expecting status 400
    Then the response status is 400
    And the JSON response includes:
      | field | value         |
      | error | word_required |

    Examples:
      | case            | payload          |
      | empty string    | {"word": ""}     |
      | whitespace only | {"word": "   "}  |
      | number          | {"word": 42}     |
      | missing field   | {}               |
      | JSON array      | ["persevere"]    |

  Scenario: Reject a word longer than 80 characters
    When I POST a word of 81 letters expecting status 400
    Then the response status is 400

  Scenario: Malformed JSON gets a request error, not a server crash
    When I POST the raw body {"word": "unterminated expecting status 400
    Then the response status is 400
    And the JSON response includes:
      | field | value                   |
      | error | invalid_json_or_request |

  Scenario: Routing errors use the right status codes
    When I send DELETE to "/api/practice" expecting status 405
    Then the response status is 405
    When I send GET to "/api/unknown" expecting status 404
    Then the response status is 404

  @intentional_failure
  Scenario: Metadata contract matches the published example exactly
    When I GET metadata for "focus"
    Then the response body matches this JSON exactly:
      """json
      {
        "word": "focus",
        "length": 5,
        "kind": "practice",
        "difficulty": "easy"
      }
      """

  @intentional_failure
  Scenario: Saved word echoes the submitted text verbatim
    When I POST this JSON to the practice API:
      """json
      {"word": "line one"}
      """
    Then the saved word equals this text:
      """
      line one
      line two
      """
