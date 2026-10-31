# Acceptance criteria — Ledger presentation (reportportal-cucumber-ruby 1.3.2 and 2.0.1)

| | |
| --- | --- |
| Spec under test | `presentation-ledger-proposal.md` (P1–P9 Tier 1, P10 Tier 2) |
| Release lines | 1.3.2 (`maintenance/presentation-ledger-1.3.2`), 2.0.1 (`codex/presentation-ledger-2.0.1`) |
| Baselines | 1.3.1 at `4ca2f77`; the frozen 2.0.0 candidate commit named by the implementer |
| ReportPortal | `http://rp-2607.localhost:18080/ui/`, project `superadmin_personal`, UI 5.15.6 / server 26.0.7 |
| Keywords | **MUST**: a failure blocks release. **SHOULD**: a failure is reported, but doesn't block |

---

## 0. Test-agent brief (the implementer pastes this verbatim)

You are an **independent QA agent**. You didn't write this code, and your job is to find where it fails its spec, with evidence. Assume nothing works until you have seen it work.

**You receive**

- This document and the proposal
- Two feature-branch names with head SHAs, and the baseline SHAs
- The RP endpoint and project, and the name of the environment variable holding the API key (`RP_API_KEY`)
- Launch IDs from the implementer's smoke runs

Treat the implementer's Launch IDs as hints only. Create your own runs for every criterion.

**You may**

- Check out the branches into your own worktrees and run any test or fixture.
- Create new Launches in `superadmin_personal`.
- Read any Launch through the UI or the read API.
- Write **only** under `spec/`, `features/`, `docs/reviews/` and `docs/reviews/assets/` on your own branches: `qa/presentation-ledger-1.3.2` and `qa/presentation-ledger-2.0.1`.

**You must not**

- Edit `lib/`, the gemspec, the Gemfile, the lockfile, Helm files or CI workflows.
- Delete or modify existing Launches.
- Print, commit or screenshot credentials.
- Type passwords into a browser. The owner signs you in.
- Fix product defects. Report them instead.
- Mark a criterion PASS without the evidence named in it.

**Deliverables (one set per release line)**

- **Report:** `docs/reviews/<YYYY-MM-DD>-presentation-ledger-<version>-acceptance.md`, using the template in section 7
- **Evidence:** `docs/reviews/assets/presentation-ledger-<version>-acceptance.json`, holding every check with its inputs, expected and actual values, Launch, item and log IDs, and verdict
- **Screenshots:** `docs/reviews/assets/presentation-ledger-<version>/Sxx-<slug>.png`, named as in section 5
- **Final reply to the implementer:** one verdict line per criterion group, then the defect list sorted by severity

Work in this order: section 2 (runs), section 4 (criteria), section 5 (screenshots), then section 6 (exit). If something blocks a MUST criterion, such as a fixture that can't run, report it as **BLOCKED** with the reason. Never mark it PASS.

---

## 1. Definitions

| Term | Meaning |
| --- | --- |
| *plain* / *rich* | A run with `RP_PRESENTATION` unset or `plain`, versus `RP_PRESENTATION=rich` |
| *message* | The `message` field of one RP log, fetched with `GET /api/v1/superadmin_personal/log?filter.eq.item=<id>` |
| *first line* | Message text up to the first `\n` |
| *strip-tags* | Remove every substring matching `<[^>]+>` |
| *golden* | An exact output string given in the proposal; compare byte for byte, UTF-8, LF line endings |
| *baseline run* | The same fixture run on the baseline commit (1.3.1 or the frozen 2.0.0) |
| *rendered* | What RP shows in the log view at a 1100 × 780 viewport with Markdown mode on (the default) |

---

## 2. Run matrix

| ID | Line | Ruby | Cucumber | Mode | Scope |
| --- | --- | --- | --- | --- | --- |
| M1 | 1.3.2 | 3.1 | 9.x | plain | Full RSpec + offline Cucumber + section 3 fixtures (offline stub) |
| M2 | 1.3.2 | 3.1 | 10.x | plain | Same as M1 |
| M3 | 1.3.2 | 3.3 | 9.x | plain | Same as M1 |
| M4 | 1.3.2 | 3.3 | 10.x | plain + rich | Same as M1, plus **live RP** for all fixtures in both modes |
| M5 | 2.0.1 | 3.3 | 12.0.1 | plain | Full RSpec + offline Cucumber + fixtures (offline stub) |
| M6 | 2.0.1 | 3.4 | 12.0.1 | plain + rich | Same as M5, plus **live RP** for all fixtures in both modes |
| B1 | 1.3.1 baseline | 3.3 | 10.x | — | Live RP, every fixture that exists at baseline, for contract comparison |
| B2 | 2.0.0 baseline | 3.4 | 12.0.1 | — | Same as B1 |

Pin Cucumber 9 or 10 for 1.3.2 the way the 2.x `legacy` CI job does: in a scratch copy, append `gem "cucumber", "~> 9.0"` (or `~> 10.0`) to the Gemfile, delete the lock and run `bundle install`. Record `ruby -v`, `Gem.loaded_specs["cucumber"].version` and `ReportportalCucumber::VERSION` for every run.

---

## 3. Fixtures

Reuse the existing acceptance features where they exist. Write new ones under `features/presentation_ledger/` on your QA branch. Unless a row says otherwise, every fixture runs on both lines.

| ID | Content | Source |
| --- | --- | --- |
| F01 | One step attaching `visible-fixture.png` (640 × 360, 5,421 B), `visible-fixture.txt` (2 lines, 71 B) and `visible-fixture.json` (75 B) | Launch 64 fixture |
| F02 | Outline with combined DocString and DataTable, two Examples rows (`TABLE_ONLY_AMBER`, `TABLE_ONLY_BIRCH`), doc-first and table-first | Launches 72/73 fixtures |
| F03 | Outline values with literal angle brackets (`TABLE_ONLY_AMBER <other>`) | Launch 71 fixture |
| F04 | Failing step, skipped follower, After hook attaching `after-failure.jpg` (754 × 790, 36,612 B) | Launch 76 fixture (TC10) |
| F05 | Ten scenarios, one distinct 640 × 360 PNG each | Launch 75 fixture |
| F06 | Four parallel workers with hooks (**2.0.1 only**) | Launch 70 fixture (TC16) |
| F07 | Fifty rapid steps with logs and PNGs | Launch 63 fixture (TC15) |
| F08 | Attachment inputs (file, path, binread, binary, encoded, `plain_base64` negative control) for png/text/json | Launch 74 fixture |
| F09 | Text containing NUL, escaped and native | Launches 66/68 fixtures |
| F10 | `AppLog.assertion`, five cases (table below) | New |
| F11 | `AppLog.http`, six cases (table below) | New |
| F12 | `rp_evidence` with `action:`, `error:` (multi-line `Playwright::TimeoutError`-shaped message), `url:`, `details: {api_key: "SECRET123"}` and two artifacts (PNG, JSON); a second call with an empty action | New |
| F13 | Numeric DataTable (table below) | New |
| F14 | Escaping matrix (table below) | New |
| F15 | Hooks: unnamed Before, After, AfterStep, BeforeAll, AfterAll; a named Before (`Before(name: "Open browser")`) where the Cucumber version supports hook names; an After hook that raises | New |
| F16 | Failure shapes (table below) | New |
| F17 | Unnamed attachments in step `Then the order is confirmed`: PNG, progressive JPEG (SOF2), JSON, text; two PNGs in the same step; one JPEG in an unnamed After hook | New |
| F18 | Large previews: text with 340 lines; JSON with 25 lines; single-line text of 48 KiB | New |
| F19 | Run context (table below) | New |
| F20 | `RP_PRESENTATION=fancy` | New |

**F10 assertions**

| Case | name | expected | actual | passed | details |
| --- | --- | --- | --- | --- | --- |
| a | `Order is accepted` | `"ACCEPTED"` | `"ACCEPTED"` | true | — |
| b | `Payload matches` | 120-character string | same | true | — |
| c | `Intentionally absent Typewords control can be clicked` | `"click succeeds"` | three-line Playwright call log | false | `{api_key: "SECRET123", recording: "Playwright viewport recording is still active"}` |
| d | `Limits` | `{currency: "USD", notional: 5000000}` | `{currency: "USD", notional: 4000000}` | false | 8-key Hash |
| e | `Nested details` | `1` | `2` | false | `{a: {b: [1, 2]}}` |

**F11 HTTP exchanges**

| Case | Call | Expected level |
| --- | --- | --- |
| a | `POST https://api.example.test/api/orders`, 201, JSON request and response, 84 ms, 4 request headers | INFO |
| b | `GET /words`, 404, 31 ms | WARN |
| c | `GET /words`, 500, `expected_status: 200` | ERROR |
| d | `error:` "Connection refused" | ERROR |
| e | Response body of 40 JSON lines | INFO |
| f | URL `…/orders?token=SECRET123&page=2` | INFO |

F11a uses request headers in this order: `Content-Type: application/json`,
`Accept: application/json`, `X-Request-Id: ledger-42`, `X-Fixture: F11a`;
the response has `Content-Type: application/json`. Its bodies are the Hash
inputs shown in P8, serialized to 55 B and 51 B before Ledger JSON formatting.
The corrected P8 golden includes these header sections and input-byte counts;
P8.4 still requires an exact UTF-8 comparison (Decision 7).

**F13 numeric DataTable.** Columns `account`, `qty`, `price`, `change`, `pct`, `code`, `mixed`, `blank`, with these body cells:

- `qty`: `100`, `1,250`, `12,345,678`
- `price`: `1,234.50`, `0.5`, `98.10`
- `change`: `-12`, `+7`, ` 42 `
- `pct`: `12%`, `0.5%`, `100%`
- `code`: `1.2.3`, `USD 100`, `1e3`
- `mixed`: `10`, `n/a`, `30`
- `blank`: three empty cells

Expected alignment row: `| --- | --: | --: | --: | --: | --- | --- | --- |`.

**F14 escaping matrix** (each value used as a DataTable cell, an Examples value, step text, and an exception message):

`<other>` · `<b>x</b>` · `a | b` · `back\slash` · `*star*` · `_under_` · `` `tick` `` · `&amp;` · `# heading` · `1. item` · `x<script>alert(1)</script>` · `emoji 🟢` · `CJK 中文` · a value with an embedded newline

**F16 failure shapes**

| Case | Shape |
| --- | --- |
| a | `RuntimeError` with a 3-line message |
| b | Error raised inside a gem (for example `JSON.parse("{")`), so no project frames before the step definition |
| c | Non-`Exception` failure (the `extract_error` struct fallback) |
| d | Empty message |
| e | 500-character single-line message |
| f | `raise "api_key=SECRET123 failed"` |

**F19 run context**

| Case | Environment |
| --- | --- |
| a | `RP_RUN_CONTEXT=true`, `GITHUB_REF_NAME=feature/ledger`, `RP_SOURCE_COMMIT=e7dae2b1234567`, `GITHUB_RUN_ID=42`, `PARALLEL_TEST_GROUPS=4` |
| b | As a, plus `RP_ATTRIBUTES=sdk:custom` |
| c | As a, plus `RP_LAUNCH_DESCRIPTION="Given description"` |
| d | `RP_RUN_CONTEXT` unset |

---

## 4. Criteria

Each criterion gives its method (**U** unit/spec, **C** contract comparison through the API, **L** live RP message check through the API, **V** visual in the RP UI, **D** read-only DOM check in the RP UI) and the evidence to keep.

### G — Global

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| G1 | MUST | The item tree is identical to the baseline for every fixture that exists at baseline: type, `hasStats`, parent path, status, `retry`, `testCaseId`, `uniqueId`, `codeRef`, `parameters`, attributes (P9 off), names. The only allowed name differences are P6 hook names | **C** · normalised JSON diff of `item?filter.eq.launchId` for B1/B2 against M4/M6 plain and rich, with UUIDs and times removed |
| G2 | MUST | Per item, the number of logs and each log's level are identical to the baseline | **C** · count table per item |
| G3 | MUST | Attachment count, `contentType` and SHA-256 of bytes are identical to the baseline. File names are identical except for unnamed attachments (P5) | **C** · download through `GET /api/v1/data/superadmin_personal/<id>` and hash |
| G4 | MUST | Determinism: running F01–F18 twice in the same mode gives byte-identical messages, descriptions and names | **L** · diff of the two runs |
| G5 | MUST | No message contains `!!!MARKDOWN_MODE!!!` | **L** · `filter.cnt.message` search, which must return 0 |
| G6 | MUST | Plain mode adds no HTML tags. The only tags allowed in plain messages are those the baseline already sends (`<br>` in table cells, `<video …>` / `<source …>` in `minio_markdown` video mode) | **L** · regex `<\/?[a-zA-Z]` over every plain message, with each hit classified |
| G7 | MUST | No message in any mode contains `<style`, `url(`, `position:`, ` class=`, ` id=`, `<img`, `<svg`, `javascript:`, or `\son[a-z]+=` | **L** · regex scan of every message |
| G8 | MUST | No log message, description, name or attribute in any run contains `SECRET123` | **L** · `filter.cnt.message=SECRET123` per Launch returns 0; scan of descriptions and attributes |
| G9 | MUST | If any Presentation formatter raises, that message falls back to the baseline format, one warning is logged, and the scenario's status is unchanged | **U** · stub each `Presentation::*` entry point to raise, on both lines |
| G10 | MUST | Full RSpec and offline Cucumber pass on M1–M6, with no new skips or pendings beyond those documented at baseline | **U** · counts, durations, failures = 0 |
| G11 | SHOULD | F07 wall time is within +10% of the baseline (median of 3 runs); each Presentation call is below 2 ms at p95 in a micro-benchmark of F01–F18 messages | **U** · timings |
| G12 | MUST | Native Cucumber messages and the HTML report contain no Tier 2 markup in rich mode, and are identical between plain and rich | **U** · `--format message` NDJSON diff between plain and rich |

### P1 — Failure card

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| P1.1 | MUST | F04's ERROR message equals the proposal's P1 golden. Its tail lines are byte-identical to lines 2–63 of the baseline message | **L** · diff |
| P1.2 | MUST | Titles follow the rules: F16c `## ✗ <message>`; F16d `## ✗ RuntimeError`; F16e cut to 200 characters ending in `…`; F14 markup escaped by `inline` | **L** |
| P1.3 | MUST | The tail caption's counts equal the real number of framework, runner and total frames | **L** · count lines in the tail |
| P1.4 | MUST | At most 8 project frames, then the feature frame. F16b shows the first 3 framework frames instead | **L** |
| P1.5 | MUST | F16a puts message lines 2–3 in a `text` fence under the meta line, and the frames block is captioned `_Project frames_`. The caption is absent when there is no continuation | **L** |
| P1.6 | MUST | The F14 exception messages render literally: the rendered title contains `x<script>alert(1)</script>` as text, and the DOM has no `<script>` or `<b>` element from it | **D** |
| P1.7 | MUST | On 1.3.2, F16f's message is redacted (G8). On 2.0.1, redaction is unchanged | **L** |
| P1.8 | MUST | Rendered (screenshot S01): the title and meta line show above RP's fold without expanding | **V** |
| P1.9 | MUST | The Stack trace tab shows the card's title first (S02) | **V** |
| P1.10 | SHOULD | Two separate runs of F04 produce identical message text up to the tail caption | **L** |

### P2 — Escaping

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| P2.1 | MUST | For every F03/F14 value, the rendered DataTable cell `textContent` (whitespace-trimmed) equals the Gherkin value, with an embedded newline shown as a line break | **D** · table of value against rendered text (S04) |
| P2.2 | MUST | In raw messages, `<`, `>` and `&` from data appear as entities outside code spans and fences, and literally inside them | **L** |
| P2.3 | MUST | Your own property spec, with at least 1,000 generated strings per method, passes. `cell`, `inline` and `html` contain no raw `<` or `>`; `cell` has no unescaped `\|` or newline; `code` and `fence` never close early; no method raises | **U** |
| P2.4 | MUST | Item names are not escaped: they are byte-identical to the baseline (G1) | **C** |

### P3 — Raw text stays raw

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| P3.1 | MUST | No prefix (G5) | **L** |
| P3.2 | MUST | Multi-line exception text (P1.5) and evidence error text (P8.5) are inside `text` fences | **L** |
| P3.3 | MUST | AppLog / `rp_log` user text is byte-identical to the baseline | **C** |
| P3.4 | MUST | With Markdown mode off (S11) and in Console view (S12), F01, F04, F10 and F11 messages are legible: no tag fragments in plain mode, and fences and chips visible as characters | **V** |

### P4 — Outline descriptions

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| P4.1 | MUST | F02 row descriptions end with exactly `` `value` = `TABLE_ONLY_AMBER` · _Examples: Table-only substitution · line 12_ `` (and the BIRCH / line 13 equivalent) | **L** |
| P4.2 | MUST | Fallback to the escaped table with `Examples: <name> · line N` when there are more than 4 parameters, a value over 40 characters, or a value with a newline (cover each with an F14-style fixture) | **L** |
| P4.3 | MUST | Rendered list view (S05): each row's value chip sits directly under the name, on one line at 1100 px | **V** |
| P4.4 | MUST | Scenario names and `parameters` are unchanged (G1) | **C** |

### P5 — Attachments

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| P5.1 | MUST | F01 captions in plain mode are exactly: `` `visible-fixture.png` · PNG · 640 × 360 · 5.3 KB ``; `` `visible-fixture.txt` · Text · 2 lines · 71 B `` followed by its fence; `` `visible-fixture.json` · JSON · 75 B `` followed by the 5-line Ledger JSON golden | **L** |
| P5.2 | MUST | F04's After-hook caption is `` `after-failure.jpg` · JPEG · 754 × 790 · 36 KB ``. F17's progressive JPEG has correct dimensions. F08's `plain_base64` PNG shows kind `PNG` with **no** dimensions, and its bytes are unchanged | **L** + **C** |
| P5.3 | MUST | A caller message (F12, `rp_attach(message:)`) comes first, then a blank line, then the meta line. No message starts with `Attachment:` | **L** |
| P5.4 | MUST | `rp_evidence` artifacts end with ` · failure evidence`, and no message starts with `Failure evidence:` | **L** |
| P5.5 | MUST | F18: the 340-line text ends with `_Preview · first 100 lines · full file attached_`; the 48 KiB text ends with `_Preview · first 16 KB of 48 KB · full file attached_`. JSON over the preview limit isn't pretty-printed | **L** |
| P5.6 | MUST | F17 names, numbered per owning item in emission order and independent of batching (run F17 with the smallest and the default log batch size): first PNG `then-the-order-is-confirmed.png`, second PNG `then-the-order-is-confirmed-1.png`, After-hook JPEG `after-hook.jpg`. Explicitly named attachments keep their names | **L** + **C** |
| P5.7 | MUST | Bytes unchanged (G3) | **C** |
| P5.8 | MUST | Rendered (S06): captions visible next to the thumbnails; the preview modal opens; the download file name equals the attachment name | **V** |

### P6 — Hook names

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| P6.1 | MUST | F15 names match the proposal's P6 table on Cucumber 9 and 10 (1.3.2) and 12.0.1 (2.0.1). Named hooks are tested where the version supports them; otherwise mark N/A with the reason | **L** |
| P6.2 | MUST | Hook item types are unchanged (G1) | **C** |
| P6.3 | MUST | F04's After-hook JPEG is still a child log of the After hook item, not of any step | **C** |
| P6.4 | MUST | Rendered (S07): hooks read `Before hook` / `After hook` | **V** |

### P7 — Step arguments

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| P7.1 | MUST | F03's step log equals the proposal's P7 golden (no `**Keyword**` line, both captions) | **L** |
| P7.2 | MUST | F13's alignment row equals `\| --- \| --: \| --: \| --: \| --: \| --- \| --- \| --- \|`. Spot checks: `.5`, `1e3`, `1,23` and the U+2212 minus sign are not numeric | **L** + **U** |
| P7.3 | MUST | Descriptions keep the full form (header line, table, DocString) for argument steps. Steps without arguments have an empty or absent description (all 50 steps of F07) | **L** |
| P7.4 | MUST | DocString captions: `_Doc string · JSON_` (detected and declared), `_Doc string · text/markdown_` (declared), `_Doc string_` (none). JSON bodies follow Ledger JSON | **L** |
| P7.5 | MUST | Rendered (S08): numeric columns are right-aligned | **V** |

### P8 — Cards

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| P8.1 | MUST | F10c equals the proposal's failed-assertion golden (with `api_key` redacted); F10a equals the passed one-liner golden | **L** |
| P8.2 | MUST | F10b (expected over 60 characters) has no `expected` chip. F10d renders expected and actual as Ledger JSON, and details as a `_Details_` JSON fence (more than 6 keys). F10e renders nested details as a JSON fence | **L** |
| P8.3 | MUST | The multi-line actual keeps every line, with continuation lines indented exactly 10 spaces | **L** |
| P8.4 | MUST | F11a equals the INFO HTTP golden. F11b starts with `## ⚠ GET /words → 404 · 31 ms`. F11c starts with `## ✗` and its meta line contains `` expected `200` ``. F11d's meta line contains `` error `Connection refused` `` | **L** |
| P8.5 | MUST | F12 equals the evidence golden shape: title, meta line (class, URL, evidence names), fenced message, details. The empty action gives `## ✗ Failure evidence` | **L** |
| P8.6 | MUST | No INFO-level message in any fixture starts with `## ` | **L** · regex over all INFO messages |
| P8.7 | MUST | F11f's URL is redacted in both the title path and the meta chip | **L** |
| P8.8 | MUST | Terminal output (stdout) of F10–F12 is byte-identical to the baseline, ignoring timestamps | **U** |
| P8.9 | MUST | Oversized details still yield today's omission marker, and the size bounds are unchanged | **U** |

### P9 — Run context

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| P9.1 | MUST | F19d: no new attributes and no generated description (G1) | **C** |
| P9.2 | MUST | F19a attributes are exactly: `sdk:<version>`, `cucumber:<version>`, `ruby:<RUBY_VERSION>`, `git.branch:feature/ledger`, `git.sha:e7dae2b`, `ci.build:42`, plus `workers:4` on **2.0.1 only** | **L** · `GET launch/<id>` |
| P9.3 | MUST | F19b: `sdk:custom` wins, and there is no duplicate `sdk` key | **L** |
| P9.4 | MUST | F19c's description is `Given description`. F19a's description equals the template, with missing parts omitted | **L** |
| P9.5 | MUST | Rendered (S10): chips appear in the Launch list | **V** |

### P10 — Tier 2 accent layer

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| P10.1 | MUST | The default is plain: with no env var, no message contains `<details`, `<summary` or `<span style` | **L** |
| P10.2 | MUST | F20 logs exactly one warning and produces plain output | **U** + **L** |
| P10.3 | MUST | Closed vocabulary in rich runs: the only tags are `<details>`, `</details>`, `<summary>`, `</summary>`, `<span style="…">`, `</span>`, and plain mode's allowed tags (G6). Every `style` value equals exactly `PILL;<TONE>`, `TITLE` or `TH` from the proposal | **L** · regex extraction, compared against the token list |
| P10.4 | MUST | For every ERROR-level log, the first line is byte-identical between the plain and rich runs of the same fixture | **L** |
| P10.5 | MUST | Byte budget: rich message ≤ plain message + 1,024 bytes, for every log | **L** |
| P10.6 | MUST | strip-tags(rich) contains every word of the plain message in the same order, and no `<` or `>` remains outside text that was already in plain | **L** |
| P10.7 | MUST | Descriptions, names, Launch description and attributes, native Cucumber messages and terminal output are identical between plain and rich | **C** + **U** |
| P10.8 | MUST | Inside every `<details>`, a blank line precedes and follows each fence, and the rendered DOM shows `details > pre > code` for those fences | **L** + **D** |
| P10.9 | MUST | `TH` spans appear only on tables with at most 6 columns. F13 (8 columns) has none | **L** |
| P10.10 | MUST | Rendered rich (S03, S06, S08, S09): pills, sans titles and folds are visible; summaries readable; expanding a fold shows its content | **V** |
| P10.11 | SHOULD | Rendered pill contrast (from `getComputedStyle`) is at least 4.5:1 for every tone | **D** |

### V — Versions and repository hygiene

| ID | Level | Requirement | Method · evidence |
| --- | --- | --- | --- |
| V1 | MUST | `ReportportalCucumber::VERSION` is `1.3.2` / `2.0.1` | **U** |
| V2 | MUST | The `Gemfile.lock` diff against the baseline touches only the gem's own `PATH` entry | `git diff` |
| V3 | MUST | `gem build` produces `reportportal-cucumber-ruby-1.3.2.gem` / `-2.0.1.gem` | **U** |
| V4 | MUST | `CHANGELOG.md` starts with the new section, including the SemVer rationale line. On 2.x, the `2.0.0 - Unreleased` section is unchanged below it | `git diff` |
| V5 | MUST | `docs/configuration.md` documents `RP_PRESENTATION` and `RP_RUN_CONTEXT`, and `docs/advanced-reporting.md` has a Presentation section | Read |
| V6 | MUST | No changes under `helm/` or `.github/workflows/`. The 1.x chart is still `1.3.1` / appVersion `26.0.7` | `git diff --stat` |
| V7 | MUST | `main`, `maintenance/1.x` and `codex/cucumber-12` heads are unchanged; no tags were created | `git ls-remote` before and after |
| V8 | MUST | Commits follow the C0–C8 sequence, and P10 is isolated in its own commit | `git log` |

---

## 5. Visual protocol and screenshot set

**Setup.** RP UI signed in by the owner. Viewport 1100 × 780. Markdown mode on (the default) unless the shot says otherwise. Log level filter "All". Take screenshots only in Launches you created.

**Rules**

- DOM checks are **read-only**: query `textContent` or `getComputedStyle`; never modify the page for evidence.
- Each screenshot's evidence entry records the line, mode, Launch ID, item ID, URL and viewport.

| Shot | Fixture | Mode | View | Criteria |
| --- | --- | --- | --- | --- |
| S01 | F04 | plain | All logs, failed step expanded, fold untouched | P1.8 |
| S02 | F04 | plain | Stack trace tab | P1.9 |
| S03 | F04 | rich | All logs, fold expanded, `<details>` opened | P10.10 |
| S04 | F03 + F14 | plain | Step log with the escaped table | P2.1 |
| S05 | F02 | plain | Suite list view | P4.3 |
| S06 | F01 | plain, then rich | Step expanded with all three captions | P5.8, P10.10 |
| S07 | F15 | plain | Scenario log view showing hook rows | P6.4 |
| S08 | F13 | plain, then rich | Step log with the numeric table | P7.5, P10.9 |
| S09 | F10 + F11 + F12 | plain, then rich | Steps expanded with the cards | P8.x, P10.10 |
| S10 | F19a | — | Launch list showing attribute chips | P9.5 |
| S11 | F01 + F04 | plain | Markdown mode switched off, then restored | P3.4 |
| S12 | F04 | plain | Console view | P3.4 |

---

## 6. Severity and exit

| Severity | Definition | Blocks release? |
| --- | --- | --- |
| S1 | Wire contract (G1–G3, P2.4, P4.4, P6.2/6.3, P10.7), secret exposure (G8, P1.7, P8.7), forbidden token (G7), or a failure caused by presentation (G9) | Yes |
| S2 | Any other MUST criterion fails | Yes |
| S3 | A SHOULD criterion fails, or a cosmetic issue outside the criteria | No; report it |

**Exit:**

- Every MUST criterion is PASS (or N/A with a stated reason) on both lines, with no open S1 or S2 defects.
- Every screenshot S01–S12 exists for both lines. Checks that depend on F06 are N/A on 1.3.2.
- Only the owner can waive a criterion, in writing, quoted in the report.

---

## 7. Report template

```markdown
# Ledger presentation acceptance — <version>

Verdict: ACCEPT | REJECT | BLOCKED. Date, tester, branch and head SHA, baseline SHA, RP version.

## Runs
| Run | Ruby | Cucumber | Mode | RSpec (examples/failures/pending) | Cucumber (scenarios/steps) | Launch IDs |

## Results by criterion
| ID | Level | Verdict (PASS/FAIL/N/A/BLOCKED) | Evidence (log/item IDs, file, screenshot) | Note |

## Defects
| # | Severity | Criterion | Fixture | Expected | Actual | Evidence |

## Screenshots
S01 … S12, with Launch and item IDs.

## Waivers
Owner-approved waivers only, quoted.
```


## Decisions

Owner-confirmed on 2026-10-31. The following questions and answers are reproduced
word for word. These decisions take precedence over conflicting text above;
the independent tester must assess against them.

1. Question: 还有一处验收冲突需要确认：规范要求表格换行生成 <br>，P2.3 却禁止任何原始尖括号。是否允许唯一例外：由客户端生成的 <br>，用户输入的尖括号仍必须转义？

   Owner answer: 允许客户端生成的 <br>（推荐）

2. Question: Rich 样例会把 PNG 移到文件名前、把“Assertion passed”换成“PASS”，但 P10.6 要求所有原文字词顺序不变。你希望以哪项为准？

   Owner answer: 按 Rich 样例呈现，调整 P10.6 允许这些差异

3. Question: 现有完整回归测试会在临时目录调用 Helm 打包，与你要求“不得打包 Helm”冲突。是否允许仅运行这些现有隔离测试，不生成交付 Chart、不部署、不上传？

   Owner answer: 允许测试中的临时打包（推荐）

4. Question: 已实测 Cucumber 9 的解析器拒绝同一步同时包含 DocString 和 DataTable，而 F02/F03 要求两条发布线都跑这类语法。是否允许 1.x 将“原生复合语法”标为 N/A，并用分开的参数步骤验证同样的表格、描述和 Outline 展示；2.x 仍严格验收原生复合语法？

   Owner answer: 允许，保留解析失败证据（推荐）

5. Question: 还有一处验收口径需要确认：现有原生 BeforeAll/AfterAll 并不生成独立 Hook Item（2.x 的日志归属 Launch，1.x 的 BeforeAll 甚至早于 formatter 创建）。为遵守“不改变节点拓扑”，是否保留这些行为，将全局钩子的 Item 名称检查标为 N/A，同时继续验证日志/异常与退出闭合，并用单测覆盖已有 class-hook 名称映射？

   Owner answer: 保留基线行为并记录 N/A（推荐）

6. Question: 为消除 2.x 文档冲突，是否允许仅将 PR 目标分支 codex/cucumber-12 同步合并进功能分支，并保留目标分支已发布的 2.0.0 CHANGELOG 内容？不合并 PR、不推受保护分支、不强推、不发布。

   Owner answer: 允许仅同步目标分支，并保留正式发布历史（推荐）

7. Question: 独立 QA 发现验收金样与明确规则有三处冲突：P1 标题下划线未转义；P8 金样遗漏了 F11a 要求的 4 个请求 Header；同一 Hash 报文实际输入长度为 55/51 B，而金样写成 212/148 B。是否按明确规则修正金样，继续逐字节比较，并完整保留 P1 的 62 帧原始基线栈，不放宽帧数要求？

   Owner answer: 按规则修正金样，保留严格逐字节验收（推荐）

8. Question: 独立 QA 确认：1.x 旧基线有 6 个含 NUL 字符的文本附件未落库，新版则完整保存，且上传字节、MIME 和归属均不变。是否允许仅这 6 项改用旧版实际提交的报文作对照，并要求新版完整读回；其余 G2/G3 仍严格比较 API 基线？另有一条原生 NUL 用户日志在新旧版均未落库，将明确列为既有限制，暂不改变其语义。

   Owner answer: 允许这 6 项基线例外，记录既有限制（推荐）

