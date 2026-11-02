# M3A: localized Gherkin metadata and runtime arguments

Status: M3A accepted within documented scope (Master UI verdict: PASS, 2026-10-07). Verification details, live links, evidence, and accepted limitations are recorded in [the M3A verification record](reporting-experience-m3a-verification.md).

M3A adds AST-backed feature/scenario metadata and Cucumber's actual compiled step arguments to the existing reporting topology. It does not change case naming or identity strategy (M3B), or add attributes/links (M3C).

## Public metadata contract

`ReportportalCucumber::Cucumber::AstMetadata.new(ast_lookup: nil)` exposes:

| Method | Contract |
| --- | --- |
| `feature(uri:)` | Cached metadata for the feature, including feature description and localized AST structure. |
| `scenario(uri:, location_line:)` | Metadata for the concrete Scenario/Scenario Outline and its containing Rule, descriptions, and Examples row. Rule context is folded into Scenario description; it does not create another RP item. |
| `step(test_step)` | Metadata from the source AST step node, rather than matching only by rendered step text. This keeps duplicate text in a Background and Scenario attributed to the correct source node. |

Rich action previews/`StepDesc` are bounded to UTF-8 text and formatter fences; original Feature and Scenario AST descriptions are not bounded or placeholder-substituted. A missing file, unavailable lookup, or unmatched node degrades to existing identity/name behavior and does not stop test execution. Metadata is memoized by source identity/line without conflating Examples rows.

Runtime action names and rich action details use Cucumber's compiled test-step text and actual DataTable/DocString argument, so outline placeholders are substituted before publication. DataTables preserve column order and trailing empty cells and correctly decode escaped pipes, newlines, and backslashes. DocStrings preserve media type, embedded backticks, and JSON string escapes. Feature/scenario descriptions come from the official AST, including localized syntax, Rules, Backgrounds, and multiple Examples blocks.

The item topology remains `SUITE(hasStats=true) Feature -> STEP(hasStats=true) Scenario -> STEP(hasStats=false) action`. Hooks retain their established placement and lifecycle. Background is represented by its executing action steps, not a new report item. Action logs flush before item finish. Existing stats count only the eight statistical Scenario items in these fixtures, never nested actions.

## Acceptance cases

| ID | Scenario | Required evidence |
| --- | --- | --- |
| M3A-01 | English Feature, Rule, Feature Background, Rule Background, ordinary Scenario and Outline | AST descriptions and source-node attribution are correct; no extra Rule item. |
| M3A-02 | Two English Examples blocks with four rows total | Five English Scenario items including the ordinary case; row values remain associated with their case. |
| M3A-03 | Simplified Chinese Feature, Rule, Feature Background, Rule Background, Scenario and Outline | Localized AST descriptions and source-node attribution are correct; no extra Rule item. |
| M3A-04 | Two Chinese outline rows | Three Chinese Scenario items including the ordinary case. |
| M3A-05 | Runtime DataTable and DocString on outline cases | Actual substituted action name/arguments are reported; no unresolved outline placeholders; one rich log per action. |
| M3A-06 | Escapes and unusual argument formatting | Five columns retain header order and the final empty value; escaped pipe, newline, backslash, JSON DocString, and embedded backticks survive. |
| M3A-07 | Duplicate Background/Scenario step text and hook lifecycle | Background-origin marking distinguishes duplicate step text; established hook lifecycle and topology remain unchanged. |
| M3A-08 | Full fixture run through subprocess and stateful mock API | Two Suites, eight statistical Scenarios, unique UUIDs, correct parent UUIDs, logs before finish, and launch total exactly eight. |
| M3A-09 | Bounded UTF-8/fences, missing-AST fallback, and regression suite | Rich action previews are bounded; original AST descriptions are not. Missing/unavailable AST metadata fails safely; full RSpec and ordinary Cucumber remain green. |

## Verification record

Fixture command: `bundle exec ruby examples/m3a/run.rb`. Focused integration: `bundle exec rspec spec/reportportal_cucumber/cucumber/m3a_integration_spec.rb`. Final local regression, live API results, Master UI PASS, and accepted limitations are in [the M3A verification record](reporting-experience-m3a-verification.md). M3B and M3C remain out of scope. Do not commit, tag, push, redeploy, or change Kubernetes state as part of this work.
