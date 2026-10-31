# frozen_string_literal: true

require "json"

module LedgerDeveloper
  ROOT = File.expand_path("../../..", __dir__)
  BASELINES = { "1" => "4ca2f77", "2" => "79e5e9c" }.freeze
  TEXT = "Visible synthetic plain-text acceptance fixture.\nSecond line retained.\n".freeze
  JSON_TEXT = JSON.generate(source: "independent acceptance", synthetic: true, values: [1, true, nil]).freeze
  CALL_LOG = "Timeout 1200ms exceeded.\nCall log:\n  - waiting for get_by_role(\"button\", name=\"M2 video intentionally absent control\", exact=True)".freeze
  ESCAPES = ["<other>", "<b>x</b>", "a | b", "back\\slash", "*star*", "_under_", "`tick`", "&amp;",
             "# heading", "1. item", "x<script>alert(1)</script>", "emoji \u{1F7E2}", "CJK \u4E2D\u6587", "first\nsecond"].freeze

  def self.feature(id, body, tags: "")
    "@reportportal_live @ledger_developer @#{id[0, 3]} #{tags}\nFeature: Ledger developer #{id}\n#{body}"
  end

  def self.single(id, step, tags: "")
    feature(id, "  Scenario: #{id}\n    Given #{step}\n", tags: tags)
  end

  # Definitions are templates, not auto-discovered .feature files. In particular,
  # default legacy discovery must never parse the compound templates in F02/F03.
  def self.catalog
    rows = []
    add = lambda do |id, source, **metadata|
      rows << { id: id, source: source, negative: false, scenarios: 1, failed: 0,
                origin: "presentation-ledger-acceptance.md section 3", limitations: [] }.merge(metadata)
    end
    add.call("F01", single("F01", "ledger visible media"), media: :png,
             origin: "Launch 64; cucumber12_live_features/support/env.rb visible fixture")
    %w[F02 F03].each do |id|
      parts = %w[doc-first table-first].to_h do |order|
        doc = "      \"\"\"\n      CONSTANT_DOC\n      \"\"\"\n"
        table = "      | key | value |\n      | combined | <value> |\n"
        values = %w[AMBER BIRCH].map { |color| "      | TABLE_ONLY_#{color}#{id == 'F03' ? ' <other>' : ''} |\n" }.join
        body = "  Scenario Outline: #{order}\n    Given ledger combined \"#{order}\":\n" +
          (order == "doc-first" ? doc + table : table + doc) +
          "\n    Examples: Table-only substitution\n      | value |\n#{values}\n"
        [order, body]
      end
      add.call(id, feature(id, parts.values.join), scenarios: 4, cucumber12: true,
               native_parser_sources: parts.transform_values { |body| feature(id, body) },
               origin: "Launches #{id == 'F02' ? '72/73' : '71'}; C12 combined native selected DocString",
               limitations: ["Generated feature line numbers differ from the historical line-12 golden; original data is unchanged."])
    end
    add.call("F04", feature("F04", "  Scenario: Failure and skipped follower\n    Given ledger deep failure\n    Then ledger follower must not execute\n", tags: "@ledger_failure_jpeg"),
             negative: true, failed: 1, media: :jpeg, error: "INDEPENDENT_FULL_BACKTRACE",
             origin: "Launch 76 TC10; same message and JPEG bytes, new support stack locations")
    body = (1..10).map { |i| "  Scenario: Distinct PNG #{i}\n    Given ledger screenshot #{i}\n" }.join
    add.call("F05", feature("F05", body), scenarios: 10, media: :png, origin: "Launch 75; C12 deterministic 640x360 testcards")
    add.call("F06", single("F06", "ledger literal parallel worker"), unsupported:
             "Four-worker shared-launch orchestration remains in cucumber12_live.rb TC16. This bounded rendering runner does not claim parallel coverage; 1.x has no ParallelFormatter.")
    body = "  Scenario: Fifty rapid steps\n" + (1..50).map { |i| "    Given ledger rapid record #{i}\n" }.join
    add.call("F07", feature("F07", body), media: :png, origin: "Launch 63 TC15; 50 logs, PNGs on first ten steps")
    { "F08" => %w[file path binread binary encoded], "F08-negative" => %w[plain_base64] }.each do |id, forms|
      body = %w[png text json].product(forms).map do |kind, form|
        "  Scenario: #{kind} #{form}\n    Given ledger media \"#{kind}\" as \"#{form}\"\n"
      end.join
      add.call(id, feature(id, body), scenarios: forms.length * 3, negative: id.end_with?("negative"), media: :png,
               origin: "Launch 74 native input forms; PNG=IndependentCucumber12.png(71), text/JSON match prior runtime-support.rb",
               limitations: ["Native file/path behavior is observed, not patched by this harness."])
    end
    add.call("F09", single("F09", "ledger NUL inputs"), origin: "Launches 66/68; exact minimal NUL payload and native log, plus literal escaped control")
    %w[a b c d e].each do |letter|
      add.call("F10#{letter}", single("F10#{letter}", "ledger assertion #{letter}"), negative: %w[c d e].include?(letter))
    end
    %w[a b c d e f].each do |letter|
      add.call("F11#{letter}", single("F11#{letter}", "ledger HTTP #{letter}"), negative: %w[b c d].include?(letter))
    end
    add.call("F12", single("F12", "ledger failure evidence"), negative: true, media: :png)
    %w[F13 F14].each do |id|
      path = File.join(ROOT, "features/presentation_ledger/#{id == 'F13' ? 'f13_numeric' : 'f14_escaping'}.feature")
      add.call(id, File.read(path), scenarios: id == "F14" ? 16 : 1, source_path: path,
               limitations: id == "F13" ? ["Gherkin trims surrounding cell whitespace: change ' 42 ' compiles to '42'."] : [])
    end
    body = ESCAPES.each_index.map { |i| "  Scenario: Escaping exception #{i}\n    Given ledger escaping failure #{i}\n" }.join
    add.call("F14-negative", feature("F14", body), scenarios: ESCAPES.size, failed: ESCAPES.size,
             negative: true, error: "RuntimeError")
    add.call("F15", single("F15", "ledger literal hooks", tags: "@ledger_hooks"),
             limitations: ["Legacy BeforeAll/AfterAll execute but do not imply native RP global hook items."])
    add.call("F15-global", single("F15", "ledger literal global hooks"), native_global_hooks: true,
             limitations: ["Cucumber 9 native BeforeAll has no World log context (undefined method log for nil). Global RP hook reporting is only exercised on Cucumber 12."])
    add.call("F15-named", single("F15", "ledger literal named hook"), named_hooks: true,
             limitations: ["Executed only when the installed native DSL declares the name keyword; no compatibility shim."])
    add.call("F15-negative", single("F15", "ledger literal failing After", tags: "@ledger_after_failure"),
             negative: true, failed: 1, error: "LEDGER_INTENTIONAL_AFTER_FAILURE")
    %w[a b d e f].each do |letter|
      error = { "a" => "LEDGER_MULTI_LINE", "b" => "JSON::ParserError", "d" => "RuntimeError", "e" => "L" * 50, "f" => "api_key=" }.fetch(letter)
      add.call("F16#{letter}", single("F16#{letter}", "ledger failure shape #{letter}"), negative: true, failed: 1, error: error)
    end
    add.call("F16c", single("F16c", "ledger literal non Exception"), negative: true, unsupported:
             "Ruby raise requires an Exception. The formatter struct fallback needs an isolated unit test owned by the implementation/spec author, not a fake native Cucumber result.")
    add.call("F17", feature("F17", "  Scenario: Unnamed attachment emission order\n    Then the order is confirmed\n", tags: "@ledger_unnamed_after"), media: :progressive,
             limitations: ["Bundled deterministic 2x2 progressive JPEG or explicit --progressive-jpeg; SOF2 is verified. Run with --batch-size 1 and 20 separately."])
    body = "  Scenario: Large previews and DocString media types\n    Given ledger large previews\n"
    [["json", JSON.pretty_generate(source: "declared", values: [1, true, nil])],
     ["", JSON.generate(source: "detected", values: [1, true, nil])],
     ["text/markdown", "# User Markdown\n<other> stays raw"], ["", "CONSTANT_DOC"],
     ["json", JSON.pretty_generate((1..23).to_h { |n| ["line#{n}", n] })]].each do |type, value|
      body += "    And ledger document:\n      \"\"\"#{type}\n" + value.lines.map { |line| "      #{line.chomp}\n" }.join + "      \"\"\"\n"
    end
    add.call("F18", feature("F18", body))
    %w[a b c d].each { |letter| add.call("F19#{letter}", single("F19#{letter}", "ledger literal run context #{letter}")) }
    add.call("F20", single("F20", "ledger literal invalid presentation"), negative: true, presentation: "fancy")
    rows
  end

  def self.legacy_companion(row)
    id = row.fetch(:id)
    raise ArgumentError, "Only F02/F03 have legacy companions" unless %w[F02 F03].include?(id)
    body = %w[doc-first table-first].map do |order|
      doc = "    Given ledger legacy separate document:\n      \"\"\"\n      CONSTANT_DOC\n      \"\"\"\n"
      table = "    Given ledger legacy separate table:\n      | key | value |\n      | combined | <value> |\n"
      values = %w[AMBER BIRCH].map { |color| "      | TABLE_ONLY_#{color}#{id == 'F03' ? ' <other>' : ''} |\n" }.join
      "  Scenario Outline: #{order} separate argument companion\n" +
        (order == "doc-first" ? doc + table : table + doc) +
        "    Then ledger verifies separate arguments \"<value>\" in \"#{order}\" order\n" +
        "\n    Examples: Table-only substitution\n      | value |\n#{values}\n"
    end.join
    companion_id = "#{id}-legacy-separate"
    row.reject { |key, _| %i[cucumber12 native_parser_sources].include?(key) }.merge(
      id: companion_id, source: feature(companion_id, body), legacy_companion_of: id,
      origin: "Owner decision 4: explicitly separate argument steps, not native compound grammar",
      limitations: ["Same data and Outline rows, deliberately different step tree; never a replacement for native compound coverage on 2.x."]
    )
  end
end
