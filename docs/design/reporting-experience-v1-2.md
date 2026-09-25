# Reporting experience improvement plan

Status: M1 AC01-AC12 verification passed on 2026-09-25 (mock/integration evidence only). This is not live ReportPortal browser certification. Branch: `codex/reporting-experience-v1-2`.
Baseline: `92bebd2`. Existing uncommitted duration-test work is outside this change.

## Goals and scope

Turn evidence into a readable diagnostic story while preserving the current RP contract:
`Launch -> Feature(SUITE, hasStats=true) -> Scenario(STEP, hasStats=true) -> actions/hooks(hasStats=false)`.
No type remapping, dependency upgrade, infrastructure migration, release, or automatic capture of business traffic is part of milestone 1.

The full backlog is in `docs/research/2026-09-23-reportportal-reporting-experience.md`.
The milestones below deliberately distinguish delivered code from future work. A green mock suite is not live RP browser certification.

## Delivery plan

| Milestone | Work | Release gate |
| --- | --- | --- |
| M1: evidence foundations, this branch | Severity-preserving AppLog routing, explicit report delivery, manually recorded HTTP exchanges with credential redaction, bounded path/byte attachment previews, video fallback link | AC01-AC12 below; full RSpec and ordinary Cucumber regression; package load check |
| M2: diagnosis and capture | Structured assertions, opt-in Selenium/Capybara failure bundle, bounded file handling through the native Cucumber track, common privacy policy across all output/spool routes | Correct failed-action/attempt binding before item finalization; failure capture never replaces the original exception; large-file memory test; cross-sink privacy tests |
| M3: BDD navigation and history | Parsed AST metadata, Rule/localization/Examples correctness, scenario attributes, explicit stable identity strategy and migration, source/CI/TMS links | Complex feature fixtures; stable history across equivalent source edits; retries correctly grouped; real Suite filter drill-down |
| M4: delivery integrity | Bounded queue and byte-limited batches even at shutdown, completion barrier for joined processes, clear delivery/spool outcomes, controlled replay | Slow/unavailable backend and interrupted-run tests; bounded RSS; records reconciled with server; documented replay duplication limits |
| M5: release certification | Installed-gem clean room and supported RP/browser matrix, media authentication/retention options, full live browser acceptance | Actual screenshots/recording and playback/seek evidence; no unsupported claim of universal raw-HTML video support |

M2-M4 remain prerequisites for broad automatic capture or production resilience claims. M1 is a reviewed increment, not completion of every research recommendation.

## Structural design

```text
AppLog (thread-local facade)
  CucumberLogger
    report delivery policy: report.nil? ? attach : report
    terminal: concise title, original severity, no HTTP bodies
    ReportContext.with(level) { world.log / world.attach }
      Cucumber event bus -> native formatters
      RP Formatter.attach -> same level and active action UUID -> LogBuffer
    direct rp_log fallback only when RP does not consume that Cucumber route

AppLog.http -> HttpExchange (pure, no HTTP I/O)
  EvidenceRedactor -> request/response snapshot -> bounded Markdown
  CucumberLogger -> the same report routes above

PayloadBuilder attachment preview
  bytes or bounded file read -> UTF-8 -> bounded formatted preview
  original path remains path-backed for Multipart transport
  MP4 external URL -> existing video element + ordinary fallback link
```

### Components and responsibilities

| Component | Contract | Owner |
| --- | --- | --- |
| `Automation::ReportContext` | Scoped thread-local metadata, nested save/restore with `ensure`; no new Cucumber/RP wire fields | Luna developer Mill |
| `Automation::CucumberLogger` / `AppLog` | Preserve legacy calls; accept `report:`; route once per sink; expose `http` | Luna developer Mill |
| `Formatter#attach` | Read level only inside a scoped logger callback; native Cucumber logs remain INFO | Luna developer Mill |
| `Automation::EvidenceRedactor` | Copy/sanitize structured headers/bodies and URL credentials without changing business inputs | Luna developer Helmholtz |
| `Automation::HttpExchange` | Pure rendering and reporting-level classification of an already observed HTTP call | Luna developer Helmholtz |
| Routing/CLI tests | Real formatter and Cucumber process, not only permissive World spies | Luna tester Bohr |
| Exchange/privacy tests | Frozen inputs, negative tests, timeouts, URLs, nested credentials, large Unicode content, standalone requires | Luna tester Dewey |
| PayloadBuilder/docs/integration verification | Bounded attachment previews, video fallback, design/acceptance record, full regression | Luna implementation and verification; Master review |

All four subagents run `gpt-6-luna`, with disjoint write ownership. The master reviews their patches and test assertions before accepting results. Testers must report failures, not silently weaken the contracts.

### Public API

```ruby
# Backward compatible: defaults remain terminal-only.
AppLog.info("Local diagnostic")
AppLog.debug("Portfolio", attach: true, json: portfolio)

# Explicit report delivery independent of a physical file attachment.
AppLog.error("Unexpected result", report: true, json: failure)
AppLog.info("Keep this local", attach: true, report: false)

# Records an existing call; it does not perform, intercept, retry, or assert it.
AppLog.http(
  method: :post,
  url: "https://clearing.example.test/api/trades",
  request: { headers: { "Authorization" => "Bearer token" }, body: trade },
  response: { status: 400, headers: { "Content-Type" => "application/json" }, body: response },
  duration_ms: 84,
  expected_status: 400
)
```

HTTP helper defaults to `report: true`; existing six level methods keep the legacy default. `report: false` overrides `attach: true`. `report: nil` uses the legacy flag. No whole-body JSON is printed in the HTTP terminal summary.

HTTP evidence uses native RP Markdown, not an invented network-viewer MIME type. It shows Request and Response sections, sanitized headers/body, status and elapsed time, and an optional error. It stays under the calling action rather than creating extra statistical items. Consumers may wrap a call with existing `rp_step` to create a separate nested action.

Level selection is a reporting convention, not a replacement for test assertions: supplied transport error or explicit status mismatch -> ERROR; explicitly expected 400 -> INFO; unspecified 4xx/5xx -> WARN; otherwise INFO.

### Privacy boundary

Redact before formatting/truncation. Handle common credential keys case-insensitively, recursive objects/arrays, JSON-encoded bodies, URL userinfo, and repeated sensitive query parameters. Never mutate inputs. Expose configurable sensitive keys on the redactor for extension.

This milestone does NOT claim general PII detection or sanitization of arbitrary prose, screenshots, videos, existing `rp_log`, or raw attachment files. No automatic HTTP-client instrumentation is enabled. Full cross-sink policy and authenticated media remain separate gates.

### Context and lifecycle

The level bridge uses synchronous Cucumber callbacks and scoped metadata, not a process-global level. Every scope restores the previous value even on exception. Keep the active item UUID in the existing runtime stack; never use a launch UUID as a substitute for an available action UUID.

Do not claim asynchronous/out-of-thread event delivery is supported by this bridge. No change to scenario attempt identity, process joining, or finalization order belongs to M1.

### Attachment rendering

Preview content is capped at 16 KiB and 100 lines, excluding a small fixed Markdown wrapper/truncation notice. File reads request at most the byte budget plus one detection byte. Binary/media content is not read for a text preview. Convert invalid UTF-8 safely and use a fence longer than any embedded backtick run.

Small JSON is pretty-printed. Oversized JSON uses a clearly truncated snippet rather than attempting to parse a partial document. Preserve the full attachment transport; previews are not a substitute for it. Path-backed attachments remain path-backed. Large byte-backed JSON should not be reformatted into another unbounded copy merely for display.

Video logs retain the configured same-origin/external source. Add a normal clickable fallback alongside the video element so a renderer that strips or cannot play HTML video still has an actionable artifact link. This does not certify codecs, CSP, authorization, seek support, or remote availability.

## Executable acceptance criteria

| ID | Acceptance | Verification |
| --- | --- | --- |
| AC01 | Legacy `attach: false` is terminal-only; `attach: true` reports; `report: true` enables reporting; `report: false` suppresses it | PORO/World and logger specs |
| AC02 | AppLog DEBUG/ERROR arrive once each in RP at their original level and correct Step UUID; ordinary `world.log` remains INFO | Real Formatter callback and Cucumber subprocess against stateful mock |
| AC03 | Nested scopes restore the enclosing level; raised callbacks clear/restore context; two threads cannot cross-route metadata | Concurrency and exceptional cleanup specs |
| AC04 | Native Cucumber reporting works with no RP active; standalone helper requires work without loading RP/Cucumber | No-RP World tests and subprocess load checks |
| AC05 | HTTP summary contains method, sanitized URL, status and timing, but no bodies; Markdown contains Request/Response sections | Helper and actual logger integration specs |
| AC06 | Expected 400 is INFO; unexpected status or transport error is ERROR; unspecified server error is WARN; logging does not alter test status | Pure helper specs |
| AC07 | Sensitive headers, nested JSON keys, JSON strings and duplicate URL credentials are absent after rendering; deeply frozen inputs remain unchanged | Independent adversarial privacy specs |
| AC08 | Large HTTP Markdown previews are bounded and valid UTF-8 with an explicit truncation marker | Long-line, multiline and Unicode tests |
| AC09 | Small file-backed JSON and equivalent bytes produce equivalent inline previews; path remains a path without full read | PayloadBuilder specs with bounded-read spy |
| AC10 | Oversized file/byte previews obey byte and line caps; complete file/bytes remain available for attachment delivery | PayloadBuilder specs |
| AC11 | Video markup includes a safe, escaped fallback link; no binary read occurs just to generate a video preview | PayloadBuilder specs |
| AC12 | Full RSpec, ordinary Cucumber regression and built-gem load pass; no unrelated work is removed and no new runtime dependency is needed | Luna final integration checks; Master review |

M1 verifies that local native Cucumber HTML carries the exchange under the correct Gherkin step and that the stateful RP mock receives evidence at the expected step UUID. Remaining live release gates, NOT mock-proven in M1: ReportPortal's UI displays evidence under the intended item; actual RP severity controls and Suite filters work; the supported UI renderer renders Markdown; the real video plays/seeks or displays a usable fallback. Record these as pending until physically exercised.

## Review and evidence

M1 is complete for AC01-AC12 based on mock/local verification; live ReportPortal UI/browser acceptance remains deferred. See [the M1 verification record](reporting-experience-m1-verification.md) for commands, evidence and remaining gates. No push, merge, tag or release is authorized by this plan alone.
