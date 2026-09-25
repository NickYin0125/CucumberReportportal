# ReportPortal reporting experience: research and improvement backlog

Date: 2026-09-23. Repository baseline: `main` at `92bebd2`, with existing local changes preserved.

Scope: source inspection and primary-source research, not a new live browser certification. Recommendations below are proposals, not features implemented by this document. Current upstream documentation may describe features newer than the deployed ReportPortal UI; browser acceptance must pin server, UI, Cucumber, and browser versions.

## Recommendation

Improve the report as a diagnostic story, not as a larger collection of log strings. A tester should be able to follow business intent, identify the failing action, inspect its evidence, and compare the same case across runs without reconstructing the story manually.

Keep the existing mapping implemented by this library:

```text
Launch
  Feature                      SUITE, hasStats=true
    Scenario / Example row     STEP,  hasStats=true
      Gherkin / business action STEP,  hasStats=false
        Logs and evidence
      Before / After hook      BEFORE_METHOD / AFTER_METHOD, hasStats=false
```

Do not change Scenario back to API type `TEST` merely to match a business label. The current mapping is the integration contract to protect in browser tests. ReportPortal documents non-statistical nested items as expandable log containers; extra organizational depth is not automatically better navigation. [Reporting developer guide](https://reportportal.io/docs/developers-guides/ReportingDevelopersGuide/)

## What other reporting systems teach us

| System | Documented interaction | Implication for this library |
| --- | --- | --- |
| ReportPortal | Severity filters, error navigation, attachment previews, Markdown mode, and item details are existing controls. | Preserve severity and supply well-structured evidence rather than reproducing these controls inside enormous messages. [Log view](https://reportportal.io/docs/work-with-reports/LogLevel/) |
| Serenity BDD | Readers move from a story to a test step and then inspect HTTP request details. | Keep business step names readable; place protocol evidence beneath the action. [API reporting tutorial](https://serenity-bdd.github.io/docs/tutorials/rest) |
| Allure | Its documented HTTP exchange format supports a request/response viewer; it also recognizes specific trace attachments. | Model an exchange as structured data internally, but render it using RP-supported Markdown and attachments. Allure-specific MIME types do not create an RP viewer. [Attachments](https://allurereport.org/docs/attachments/) |
| Playwright | Selecting an action narrows network and console evidence; traces connect actions to snapshots and timing. | Bind evidence to action and attempt IDs, not merely the current global context. Full trace navigation needs a compatible viewer. [Trace Viewer](https://playwright.dev/docs/trace-viewer) |
| Cucumber | Messages provide a structured protocol for execution and reporting data. | Reuse parsed syntax and execution identifiers instead of reparsing feature text with regular expressions. [Messages](https://github.com/cucumber/messages) |

These are interaction patterns to adapt, not evidence that RP supports every component from another reporting product.

## Findings in the current implementation

| Evidence | Consequence |
| --- | --- |
| `Automation::CucumberLogger#emit_reportportal_log` suppresses direct RP delivery when the RP formatter consumes the Cucumber event bus; `Formatter#attach` converts `text/x.cucumber.log+plain` to INFO. | AppLog DEBUG and ERROR lose their severity on this path, weakening filtering and failure navigation. |
| `CucumberLogger#log` defaults to `attach: false` and returns before either report route. | A normal-looking logger call can be terminal-only without the caller realizing it. |
| `CucumberLogger#emit_cucumber_attachment` uses `File.binread`. | Large video files take the whole-file memory path through AppLog, even though direct attachment paths support streaming. |
| `PayloadBuilder#attachment_preview` requires `:bytes`; JSON previews have no byte limit and text previews only limit lines. | The same JSON gets a different preview when supplied as a path; very large or single-line content can overwhelm the log view. |
| Feature descriptions and outline metadata still use feature-file scanning; `split_table_row` uses a plain pipe split. | Localized syntax, escaped pipes, empty cells, and complex Rules/Examples need stronger guarantees. Existing AST-backed step rendering should be extended, not discarded. |
| `build_test_case_id` falls back to file-and-line plus parameters; `build_unique_id` serializes parameters without canonical ordering. | Harmless source movement or parameter-order changes can fragment history or retry identity. |
| Scenario creation passes descriptions and parameters but does not pass general scenario attributes. | Existing tags are not a complete bridge to component/owner/layer filters and dashboards. |
| The transport masks Authorization in debug cURL, but there is no common content-redaction stage. | Request bodies, cookies, query strings, attachments, and spool data need a shared privacy policy before richer automatic capture. |
| `QueueProcessor` has unbounded pending records; flush/shutdown drain all pending records as one batch. Launch finalization has no worker-completion barrier for joined processes. | Missing, delayed, or prematurely finalized evidence remains a report-trust risk, not only a backend concern. |

Relevant implementation files: `lib/reportportal_cucumber/automation/cucumber_logger.rb`, `lib/reportportal_cucumber/cucumber/formatter.rb`, `lib/reportportal_cucumber/service/payload_builder.rb`, `lib/reportportal_cucumber/service/queue_processor.rb`, and `lib/reportportal_cucumber/runtime/join.rb`.

## Prioritized improvements

### 1. P0: Preserve severity and exactly-once routing within the logger

Carry level, timestamp, message identity, target item, and attempt through an internal structured record. Render independently to terminal, Cucumber, and RP without emitting duplicate RP logs. Do not add undocumented fields to Cucumber or RP wire schemas.

Acceptance: one DEBUG and one ERROR call appear once each at their original level in RP and under the same step in the Cucumber report. Reporting-disabled mode remains usable. An expected HTTP 400 in a passing negative test is not automatically labeled an unexpected ERROR; actual assertion failures are.

### 2. P0: Make evidence delivery observable and bounded

Add queue count/byte limits, capped batches even during shutdown, and explicit delivered/spooled/failed counts. Distinguish an HTTP acknowledgment from server-side visibility. Add safe spool recovery with documented duplicate-handling limits and completion coordination for joined launches.

Acceptance: a slow or unavailable RP cannot cause unbounded memory growth; a completed test run cannot silently claim all reporting succeeded when data was only spooled. Finalization waits for the defined reporting completion condition within a bounded deadline. Do not advertise unconditional zero loss under force-kill or storage failure.

### 3. P0: Redact before distributing evidence

Introduce one configurable policy for headers, cookies, query parameters, JSON paths, terminal output, cURL artifacts, Cucumber reports, RP logs, and spool files. Keep original business request objects untouched. Screenshots and videos require capture-time masking or explicit retention/access policies; text redaction alone cannot sanitize them.

Acceptance: seeded credentials never occur in any generated artifact. Make authenticated media access an enterprise option instead of requiring public buckets. Same-origin routing should satisfy the site's security policy, not disable it. Signed URL expiry and artifact retention must be documented together.

### 4. P1: Turn API logging into an exchange, not two JSON dumps

Add an opt-in API exchange abstraction and adapters for the HTTP clients consumers use. A compact summary should show method, sanitized URL, status, elapsed time, attempt, and correlation ID. Attach redacted request/response headers and bodies separately. Include a reproducible cURL artifact with placeholders for removed secrets.

Render initially with native nested steps, Markdown, and JSON/text attachments. A custom tabbed network inspector is a separate viewer project. Never instrument the reporter's own RP/S3 traffic recursively.

Acceptance: from `When I submit a trade`, a tester can inspect `POST /trades [201, 84 ms]`, its request, its response, and its assertion without searching unrelated logs. Timeouts still produce an exchange record even without a response.

### 5. P1: Add focused assertion summaries

Provide a structured validation helper that reports assertion name, JSON path, expected value, actual value, and a concise difference. Put the primary failure in one stable ERROR message and large redacted bodies in separate diagnostic evidence. Preserve the test framework's original exception and result.

Acceptance: a margin mismatch identifies `$.margin.required`, expected `100.00`, and actual `125.00` immediately. The reader does not need to compare two 500-line payloads manually. Optional expected/actual/difference screenshots can use ordinary image attachments; a draggable comparison viewer would require additional UI support.

### 6. P1: Capture a UI failure bundle under the correct action

Provide opt-in Selenium/Capybara integration for screenshot, URL, locator/action description, browser metadata, and available console evidence. Associate video and any network/DOM artifacts with the immutable failing item and attempt IDs. Capture while the item is open or use an explicitly tested deferred-finish protocol; simply remembering a UUID is not enough if late writes are rejected.

Acceptance: evidence from a failed click is not accidentally attached to a subsequent After hook or retry. Evidence genuinely produced by a failing hook stays on that hook. Evidence-capture failure cannot replace the original test failure. Capture policies should favor failure/retry evidence rather than recording every successful action indefinitely; Playwright documents configurable failure/retry retention as a useful precedent. [Evidence options](https://playwright.dev/docs/test-use-options)

### 7. P1: Finish AST-based BDD presentation

Expand the existing AST lookup to descriptions, Rules, localized keywords, Backgrounds, and Examples. Prefer executed/substituted values for step text, DataTables, and DocStrings. Keep source intent and actual execution data distinguishable. Preserve hook context without fabricating per-feature execution of once-per-run hooks.

Acceptance: two features with Rules, localized syntax, escaped pipes, empty cells, multiple Examples blocks, and substituted DocStrings display correctly. Each Example has its own execution UUID. Gherkin tables render as Markdown tables with intact columns, not Ruby hash strings. Use compatible fixtures inspired by the official [Cucumber compatibility kit](https://github.com/cucumber/compatibility-kit).

### 8. P1: Stabilize history while making Examples readable

Separate display labels from execution UUIDs, test-case identity, and retry identity. Prefer explicit stable case IDs and stable business dataset keys; canonicalize parameters without ambiguous delimiter encoding. Keep volatile timestamps and request IDs in logs or attributes rather than identity-bearing parameters. Treat any identity algorithm change as a migration, since it can split existing history.

This matters because RP uses test-case identity for history and includes parameters in identity derivation. [Test case ID](https://reportportal.io/docs/work-with-reports/TestCaseId/)

Acceptance: a case's history survives inserting unrelated lines and reordering equivalent parameter keys. Distinct datasets remain distinct. Scenario retry attempts preserve RP's grouping fields; HTTP retries are diagnostic nested actions, not extra scenario executions. [Retry grouping contract](https://reportportal.io/docs/developers-guides/RetriesReporting/)

### 9. P1: Turn tags into useful navigation

Map an allowlisted tag convention to scenario-level attributes such as component, owner, test layer, priority, and browser. Support deliberate inheritance with overrides. Add source-at-commit, CI job, and TMS links where the target renderer supports links; do not guess numeric UI routes from UUIDs.

RP's component health reporting depends on attributes on test items, so launch-only metadata is insufficient for this use case. [Component health check](https://reportportal.io/docs/dashboards-and-widgets/ComponentHealthCheck/)

Acceptance: a tester can filter failed API tests for a particular component and reach the responsible source/CI context. Distinguish business tags from operational Cucumber tags rather than publishing everything blindly.

### 10. P1: Make rich evidence predictable and lightweight

Use the same bounded preview policy for byte-backed and file-backed JSON, text, CSV, and logs. Limit both bytes and lines; stream full artifacts separately. Supply a truncation explanation and the full redacted attachment. For videos, retain the S3/MinIO route but add a normal fallback link, capture label, duration when available, and a verified browser-compatible encoding profile. Do not label every video `UI Failure Playback` if it is non-failure evidence.

Acceptance: a large JSON file and equivalent bytes get equivalent bounded previews without reading everything into memory. MP4 loads, plays, and seeks on the supported RP/browser matrix, or a clear fallback appears. Preserve streaming through AppLog as well as direct `rp_attach`. Treat HTML video rendering as deployment-specific: RP's attachment documentation does not establish universal MP4 playback support. [Attachment behavior](https://reportportal.io/docs/work-with-reports/LogLevel/)

### 11. P2: Reduce logging ceremony and noise

Evolve the ambiguous `attach:` switch toward explicit report delivery and evidence options, retaining backward compatibility. Offer opt-in installed-gem hook setup with `Around`/`ensure`, per-target verbosity, and a generated formatter profile with non-conflicting output streams. Display the validated launch URL and reporting summary in the terminal.

For polling and retries, record state changes and a final summary rather than flooding INFO with identical responses; keep detailed attempts at DEBUG/TRACE or as a bounded attachment.

Acceptance: a clean consumer can get terminal, HTML, and RP logging without copying repository-local support files. `AppLog` does not silently lose report delivery, cross threads, or print huge JSON to the terminal unless explicitly requested. Hundreds of polls remain understandable without concealing failures.

### 12. P1: Make presentation a release acceptance contract

Maintain a small, version-pinned browser suite in addition to payload/unit tests. Use a real installed gem, mixed UI/API features, one expected failure, an outline, a scenario retry, and a delayed evidence upload. Mock tests protect protocol behavior; browser tests protect the visible experience.

Acceptance includes: Suite status-count drill-down returns scenarios; totals count scenarios rather than nested actions; severities and parentage are correct; DataTables and substituted DocStrings are readable; evidence is not duplicated; retry history is navigable; video either plays/seeks or uses the documented fallback; sensitive values are absent. A duration run must measure server-visible record counts and memory, not merely elapsed time or successful API traffic.

## Proposed reader experience

Illustrative content, not a claim that a new RP widget already exists:

```text
Feature: Trade clearing
  Scenario: Reject insufficient margin [dataset=low-balance]
    Given an eligible portfolio
      Portfolio table and setup summary
    When I submit the trade
      POST /trades [201, 84 ms]
        Request headers/body; response headers/body
      POST /margin [200, 2.4 s]
        Expected vs actual validation
    Then the rejection is visible
      ERROR: expected rejection banner; element not found
      Screenshot; URL/locator/browser context
      Video preview with fallback link
```

The labels are presentation content. Additional API calls remain non-statistical nested actions; the scenario remains the statistics leaf.

## Suggested implementation sequence

1. Repair severity/routing and establish privacy and delivery-integrity gates before increasing automated capture.
2. Deliver the API exchange and assertion experience plus a correctly bound UI failure bundle. These have the largest immediate effect on diagnosis.
3. Complete AST, stable identity, and metadata navigation; add large-evidence preview consistency and simpler consumer setup.
4. Gate each increment with real UI acceptance. Consider a custom network/trace viewer only if native Markdown and attachments prove insufficient.

Suggested internal separation: an immutable evidence record containing context and identity; a privacy/size policy; independent terminal/Cucumber/RP renderers; and the existing transports. Preserve native protocol schemas and keep optional browser/HTTP adapters outside the core dependency path.

No runtime implementation, dependency update, deployment change, or fresh E2E claim is part of this research deliverable.
