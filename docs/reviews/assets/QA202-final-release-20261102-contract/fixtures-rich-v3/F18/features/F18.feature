@reportportal_live @ledger_developer @F18 
Feature: Ledger developer F18
  Scenario: Large previews and DocString media types
    Given ledger large previews
    And ledger document:
      """json
      {
        "source": "declared",
        "values": [
          1,
          true,
          null
        ]
      }
      """
    And ledger document:
      """
      {"source":"detected","values":[1,true,null]}
      """
    And ledger document:
      """text/markdown
      # User Markdown
      <other> stays raw
      """
    And ledger document:
      """
      CONSTANT_DOC
      """
    And ledger document:
      """json
      {
        "line1": 1,
        "line2": 2,
        "line3": 3,
        "line4": 4,
        "line5": 5,
        "line6": 6,
        "line7": 7,
        "line8": 8,
        "line9": 9,
        "line10": 10,
        "line11": 11,
        "line12": 12,
        "line13": 13,
        "line14": 14,
        "line15": 15,
        "line16": 16,
        "line17": 17,
        "line18": 18,
        "line19": 19,
        "line20": 20,
        "line21": 21,
        "line22": 22,
        "line23": 23
      }
      """
