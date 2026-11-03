# Presentation proposal v2 — "Ledger" for reportportal-cucumber-ruby 1.3.2 and 2.0.1

| | |
| --- | --- |
| Status | Direction approved by the owner on 2026-10-31. Supersedes the P1–P9 draft in the review doc. |
| Release lines | `maintenance/1.x` (1.3.1 → **1.3.2**), `codex/cucumber-12` (2.0.0 candidate → **2.0.1**) |
| Reviewed against | ReportPortal UI build 5.15.6 / server 26.0.7, project `superadmin_personal`, Launches 4, 6, 63–76 |
| Scope | What the client sends to ReportPortal (log text, captions, descriptions, item names of hooks, optional Launch attributes). Nothing in the RP UI. |
| Companion files | `presentation-ledger-acceptance.md` (acceptance criteria), `implementation-agent-prompt.md` (delegation prompt) |

---

## 1. Decisions

1. **Ledger Tier 1 (clean Markdown) is folded into P1–P9 and is always on** in both release lines.
2. **Ledger Tier 2 (accent layer) is P10**, a separate commit behind `RP_PRESENTATION=plain|rich`. It defaults to `plain` in 1.3.2 and 2.0.1. Flipping the default to `rich` is a later minor-release decision.
3. **No `!!!MARKDOWN_MODE!!!` prefix.** RP 5.15.6 strips it from the text and never uses it to force rendering. Markdown mode is already the viewer default.
4. **Presentation only.** The item tree, statuses, identity, timestamps, evidence ownership and attachment bytes do not change. The one name change is hook display names (P6).
5. **Held back:** dropping `Scenario:` / `Feature:` prefixes, adding Examples values to Scenario names, rewriting `And` / `But`, and escaping Markdown inside item names.

---

## 2. Evidence basis (measured in the live RP page on 2026-10-31)

| Fact | Consequence for the client |
| --- | --- |
| Log text is Roboto Mono Regular 13 px; the font has a single weight, so `**bold**` barely renders | Never rely on bold for hierarchy |
| `##` renders at 16 px, `###` at 14 px, `####` at 13 px (same as body) | Use `##` only; reserve it for failure cards |
| Inline code renders as a green chip (11.7 px) | Chips carry identifiers: files, locations, values |
| Fenced blocks render as grey panels | Raw text: backtraces, payloads, exception messages |
| Table header cells are styled like body cells; column alignment (`--:`) works | Right-align numeric columns; accept plain headers in Tier 1 |
| Messages fold after about eight rendered lines behind an expander | The point must be in the first three lines |
| Log view mode defaults to Markdown when the viewer has stored no choice (`IW(userId) \|\| "markdown"`) | Most testers see rendered Markdown |
| `!!!MARKDOWN_MODE!!!` is stripped (`message.replace(/!!!MARKDOWN_MODE!!!/, "")`); rendering depends only on the viewer's mode | No prefix |
| Item names are rendered as Markdown in nested step headers, but as plain text in list view | Never put markup in names |
| Renderer pipeline: SimpleMDE `markdown()` → sanitiser → html-react-parser | — |
| Kept: `<details>/<summary>`, `<span style>` (colour, font, padding, radius, border; `position` dropped), entities, `<mark>`, `<img>`, `<svg>` | Tier 2 may use `<details>` and styled `<span>` only |
| Stripped: `<script>`, `on*=`, `javascript:` URLs, `<iframe>`, task-list checkboxes | — |
| Kept but dangerous: a `<style>` element and `background-image:url(…)` | Never emit; report upstream (section 9) |
| Unknown tags such as `<other>` are removed together with their content | Escape `<` `>` `&` in Markdown text (P2) |

---

## 3. Ledger rules (Tier 1 — both lines, always on)

### 3.1 Principles

1. **Structure before colour.** RP already colours status with level bars and dots; the client adds hierarchy.
2. **One accent per message.** One glyph (Tier 1) or one pill (Tier 2), never several.
3. **Point first, tail last.** The answer is in the first three lines; long content follows.
4. **Plain text still reads.** Console mode, the API, exports and native Cucumber reports must stay legible.
5. **Never change a value.** Escape, align and fold. Never reformat, round, localise or compute numbers.

### 3.2 Card anatomy

Every client-authored message follows the same order, and omits the parts it doesn't need:

1. **Title line:** a glyph, then what happened.
2. **Meta line:** chips for where, what type, how big, joined by ` · `.
3. **Body:** a fenced block or table holding the evidence itself.
4. **Tail:** the long remainder (full backtrace, headers, large payloads). It's plain in Tier 1 and folded in Tier 2.

### 3.3 Headings are reserved for failures

Only ERROR- and WARN-level cards start with `## `: the failure card, a failed assertion, failure evidence, and an HTTP exchange at WARN or ERROR. INFO messages never use headings, so a 50-step report doesn't fill with large type.

### 3.4 Glyphs and separators

| Glyph | Meaning | Used in |
| --- | --- | --- |
| `✓` | passed / OK | Passed assertion, INFO HTTP exchange |
| `✗` | failed | Failure card, failed assertion, failure evidence, ERROR HTTP exchange |
| `⚠` | warning | WARN HTTP exchange |
| `→` | flow (from → to) | Feature line → raise site; method path → status |
| ` · ` | separator (space, U+00B7, space) | Meta lines, captions |
| `×` | dimensions and table shape (U+00D7) | `640 × 360`, `2 columns × 1 row` |

No emoji. No box-drawing characters. No other glyphs.

### 3.5 Units and wording

| Item | Rule | Examples |
| --- | --- | --- |
| Bytes | Below 1,024 → `N B`. Otherwise KB or MB (base 1,024): one decimal below 10, rounded integer from 10 up, trailing `.0` dropped | `75 B`, `5.3 KB`, `36 KB`, `1.2 MB` |
| Dimensions | `W × H` with spaces | `640 × 360` |
| Durations | Integer milliseconds below 1 s, else seconds with one decimal | `84 ms`, `1.4 s` |
| Counts | Correct singular/plural | `1 row`, `2 columns`, `62 frames` |
| Case | Sentence case; no `Label:` prefixes such as `Attachment:` or `Outcome:` | — |

### 3.6 Escaping — one helper, `ReportportalCucumber::Presentation::MarkdownText`

| Method | Does | Use for |
| --- | --- | --- |
| `html(text)` | `&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;` | Markdown text outside code |
| `cell(text)` | `html`, backslash-escape active inline Markdown punctuation, CR/LF → `<br>`; byte bound as today | Table cells |
| `inline(text)` | `html`, backslash-escape `` \ ` * _ [ ] \| ~ ``; escape a leading `#`, `>`, `-`, `+` or `N.`; newlines → space | Titles and caption text built from data |
| `code(text)` | Inline code span with a dynamic backtick delimiter (as `HttpExchange#inline_code`); control characters → space; empty → `(empty)`; **no** entity escaping | Chips |
| `fence(text, lang)` | Dynamic fence (as `StepDesc#safe_fence`: backticks, then tildes, at most 32 characters) | Blocks |

**Rule:** never entity-escape inside code spans or fences. Markdown shows entities there literally.

Table cells preserve literal punctuation, including emphasis, code-span and link
delimiters, as required by acceptance P2.1. Intraword underscores, such as those
in `TABLE_ONLY_AMBER`, are already literal in GFM and stay unchanged. This does
not change item names or user-authored log messages.

**User-authored text is not escaped:** AppLog / `rp_log` text and a caller-supplied attachment message keep today's behaviour.

### 3.7 Ledger JSON (shared by P5, P7, P8)

1. Pretty-print with `JSON.pretty_generate`.
2. Working bottom-up, collapse any array or object whose members are all scalars and whose one-line form fits within 72 columns, including indentation. One-line forms are `[1, true, null]` and `{ "currency": "USD", "notional": 5000000 }`, with a space inside the braces and after `,` and `:`.
3. Never reorder keys or change number formatting.
4. The result must be deterministic and parse back to the same value.

### 3.8 Channels

| Channel | Tier 1 | Tier 2 (P10) |
| --- | --- | --- |
| RP log messages | Yes | Yes, when `RP_PRESENTATION=rich` |
| RP item descriptions | Yes | Never |
| Native Cucumber `log`/`attach` messages and HTML report | Yes (as today's Markdown) | Never |
| Terminal summaries | Unchanged | Never |
| Item names | Only P6 hook names change | Never |

---

## 4. Proposals P1–P9 (Tier 1 folded in)

Each proposal below lists the problem, the exact output, the rules, and the code to change. Paths are identical on both lines unless noted.

### P1 · Failure card with project frames first

**Problem.** In Launch 76, the only ERROR log is 10,086 characters over 63 lines. It has no exception class, 56 cucumber / cucumber-core frames, absolute `/Users/…` paths and per-run folders, so the same failure never produces the same text twice.

**Output (Launch 76 fixture):**

````markdown
## ✗ RuntimeError: INDEPENDENT\_FULL\_BACKTRACE

`features/audit.feature:5` → `runtime-support.rb:65`

```text
runtime-support.rb:65     IndependentCucumber12.inner_failure
runtime-support.rb:59     IndependentCucumber12.deep_failure
runtime-support.rb:136    block in <top (required)>
features/audit.feature:5  independent fail
```

_Full backtrace · 62 frames · 56 framework and 2 runner frames not shown above_

```text
/Users/…/runtime-support.rb:65:in 'IndependentCucumber12.inner_failure'
… all 62 original lines, byte-for-byte as today …
```
````

**Rules**

- **Title.** `## ✗ <Class>: <first non-empty message line>`, run through `inline`, at most 200 characters (end with `…` when cut). If the error isn't an `Exception` (the `extract_error` struct fallback), use `## ✗ <message>`. If the message is empty, use `## ✗ <Class>`.
- **Message continuation.** Any further message lines go into a `text` fence directly under the meta line. When this block exists, caption the frames block `_Project frames_`.
- **Frame classes.**
    - *Framework:* the path contains `/gems/`, or starts with `RbConfig::CONFIG["rubylibdir"]`.
    - *Runner:* the line starts with `-e:` or `<internal:`.
    - *Project:* everything else.
    - *Feature frame:* matches `\.feature:\d+`.
- **Shown frames.** At most 8 project frames in original order, then the feature frame last. With no project frames, show the first 3 framework frames instead.
- **Location display.**
    - If the path is under `Dir.pwd + "/"`, strip that prefix.
    - Else if it contains `/features/`, start from `features/`.
    - Else use the basename.
    - Append `:line`. Pad the location column to the longest location plus 2 spaces. The method is the text inside `in '…'` or `` in `…' ``, without the quotes.
- **Meta line.** `` `<feature location>` → `<first project location>` ``. Omit the half that doesn't exist.
- **Tail.** The caption counts frames and hidden classes. The raw backtrace follows unchanged, absolute paths included, so search and existing evidence still match.
- **Redaction.** The whole message goes through `Automation::EvidenceRedactor#redact_text` as 2.0 does today. **On 1.3.2 this is new:** 1.x `emit_error_log` doesn't redact. Note it in the changelog.
- **Level and count.** Exactly one ERROR log per failure, as today. Empty input still yields `Step failed`.

**Code.** `Cucumber::Formatter#emit_error_log` delegates to a new `Presentation::FailureCard`.

**Not changed.** Log count, level, timestamp, target item. No attachment is added.

### P2 · Escape markup in client-built Markdown

**Problem.** In Launch 71, the raw cell `TABLE_ONLY_AMBER <other>` renders as `TABLE_ONLY_AMBER` because RP drops the unknown tag. Baseline Launches 57/60 hid raw `<value>` placeholders the same way.

**Output.** `| combined | TABLE_ONLY_AMBER &lt;other&gt; |`. RP's renderer was checked to show this as `TABLE_ONLY_AMBER <other>`.

**Rules.** Use `MarkdownText.cell` for every client-built table cell and `inline` for titles and captions built from data. Never escape inside code or fences.

**Code.**

- `ReportPortal::Models::StepDesc#escape_markdown_cell` and `#header_line`
- `Formatter#parameter_description_table` and the P4 one-liner
- `Service::EvidencePresenter`
- `Automation::HttpExchange` titles

### P3 · Keep raw text raw

**Rules**

- Send no prefix.
- Fence these, so RP never reinterprets them as Markdown: exception message continuations (P1), evidence error messages (P8), and HTTP bodies and headers (already fenced).
- AppLog / `rp_log` / native log text renders as the user wrote it.

**Code.** No new module; this is a review checklist for P1, P5, P7 and P8.

### P4 · One-line Outline row descriptions

**Problem.** In Launches 72 and 73, each Outline row shows `Examples: …`, `Example row: 12` (a feature-file line, not a row) and a one-cell table: five lines in list view.

**Output:**

```markdown
`value` = `TABLE_ONLY_AMBER` · _Examples: Table-only substitution · line 12_
```

**Rules**

- Pairs are `` `<key>` = `<value>` `` built with `code()`, in Examples column order, joined by ` · `.
- With no Examples name, use `_Examples · line N_`.
- **Fallback** to today's table, escaped per P2, when there are more than 4 parameters, a value longer than 40 characters, or a value containing a newline. In the fallback, use `Examples: <name> · line N` instead of `Example row: N`.
- Scenario description and `Rule:` lines stay first, as today.
- Item names and RP `parameters` are unchanged.

**Code.** `Formatter#extract_scenario_description`, `#parameter_description_table`.

### P5 · Attachment captions and default names

**Problem.** Every caption is `Attachment: <filename>`, and RP's Attachments gallery shows no name. Unnamed attachments are called `attachment.png`, `attachment-1.png`. The JSON preview spends 5 lines on `[1, true, null]`. The truncation note says "Full log is attached" even for JSON.

**Output (Launch 64 fixture):**

````markdown
`visible-fixture.png` · PNG · 640 × 360 · 5.3 KB
````

````markdown
`visible-fixture.json` · JSON · 75 B

```json
{
  "source": "independent acceptance",
  "synthetic": true,
  "values": [1, true, null]
}
```
````

_The object keeps its lines because one member is a container; only the scalar array collapses (section 3.7)._

**Rules**

- **Meta line.** `` `<name>` · <Kind> [· W × H] [· N lines] · <size> ``.
- **Kind** comes from the *declared* MIME, never from content:

  | MIME | Kind |
  | --- | --- |
  | `image/png` | PNG |
  | `image/jpeg` | JPEG |
  | `image/gif` | GIF |
  | `image/webp` | WebP |
  | `image/svg+xml` | SVG |
  | `application/json`, `*+json` | JSON |
  | `text/plain` | Text |
  | `text/csv` | CSV |
  | `text/html` | HTML |
  | `application/xml`, `text/xml` | XML |
  | `application/pdf` | PDF |
  | `video/mp4` | MP4 |
  | `video/webm` | WebM |
  | `application/zip` | ZIP |
  | anything else | File |

- **Dimensions** only when the declared MIME is `image/png` or `image/jpeg` and the signature matches.
    - PNG: width and height from IHDR bytes 16–23.
    - JPEG: scan SOF0–3, 5–7, 9–11 and 13–15 markers within the first 64 KiB.
    - On any failure, omit the dimensions. Never decode the image or alter bytes.
- **Lines** only for text and JSON whose whole content fits in the preview window.
- **Size** is `bytes.bytesize` or `File.size(path)`, formatted per 3.5.
- **Caller message.** When the caller supplies one (`rp_attach(message:)`, AppLog, `rp_log`), it comes first, then a blank line, then the meta line. The client's own `Attachment: <name>` defaults are removed.
- **`rp_evidence` artifacts** get the meta line plus ` · failure evidence`, instead of `Failure evidence: <name>`.
- **Preview** for text and JSON stays bounded at 16 KiB / 100 lines. JSON uses Ledger JSON.
- **Truncation note** is `_Preview · first 100 lines · full file attached_` when cut by lines, or `_Preview · first 16 KB of 48 KB · full file attached_` when cut by bytes.
- **Default names** for unnamed attachments: `<slug>.<ext>`, where the slug comes from the owning item's display name.
    - Lower-case it, turn runs of anything outside `[a-z0-9]` into `-`, trim `-`, and keep at most 48 characters. Use `attachment` if the result is empty.
    - Number default names **per owning item, in emission order**: `<slug>.<ext>`, then `<slug>-1.<ext>`, `<slug>-2.<ext>`. Keep the counter in the formatter so the result doesn't depend on how logs are batched. The existing per-batch `unique_filename` stays as a safety net.
    - Explicit names always win. The `plain_base64` negative control in Launch 74 keeps its literal bytes and its declared kind.

**Code**

- `Service::PayloadBuilder#enrich_log_message`, `#attachment_preview`, `#pretty_json`, `#default_attachment_name`
- `Formatter#handle_attach_called`, `#extract_attachment_message`, `#build_attachment` (pass the target item's name for the slug), `#report_evidence`

### P6 · Hook names without the echo

**Problem.** Hooks show as `Before Hook: Before hook` and `After Hook: After hook`. AfterStep falls through to `Hook: …`.

| Hook type | Unnamed | Named `Open browser` |
| --- | --- | --- |
| before | `Before hook` | `Before hook · Open browser` |
| after | `After hook` | `After hook · Open browser` |
| after_step | `AfterStep hook` | `AfterStep hook · Open browser` |
| before_all / before_class | `BeforeAll hook` | `BeforeAll hook · Open browser` |
| after_all / after_class | `AfterAll hook` | `AfterAll hook · Open browser` |
| other | `Hook` | `Hook · Open browser` |

**Rules**

- A hook is unnamed when its base text matches `/\A\s*(before|after|after\s*step|before\s*all|after\s*all|around)?\s*hook\s*\z/i`. Otherwise the base text is the name, kept as written.
- Item types (`BEFORE_METHOD`, `AFTER_METHOD`, `BEFORE_CLASS`, `AFTER_CLASS`) and ownership are unchanged.

**Code.** `Formatter#hook_display_name`. Update any harness or spec that asserts the old labels in the same commit.

### P7 · Step-argument logs: captions, aligned numbers, no repeated step line

**Problem.** Each DataTable / DocString log repeats the step line shown directly above it. Numbers are left-aligned. Every step sends a description, even without arguments; Launch 63 sends 50 that only repeat the name.

**Output (Launch 71 fixture):**

````markdown
_Data table · 2 columns × 1 row_

| key | value |
| --- | --- |
| combined | TABLE_ONLY_AMBER &lt;other&gt; |

_Doc string_

```
CONSTANT_DOC
```
````

**Output (Launch 4 portfolio fixture, numeric column):**

```markdown
_Data table · 5 columns × 10 rows_

| account | region | product | currency | exposure |
| --- | --- | --- | --- | --: |
| JPM-PRIME | APAC | Swap | USD | 100 |
```

**Rules**

- **Log vs description.**
    - The log (`emit_step_markdown_log`) drops the `**Keyword** text` line and adds the captions.
    - The item description keeps today's form (header line, table, DocString), with P2 escaping and numeric alignment.
    - Steps with no DataTable or DocString send **no** description.
- **Numeric column.** A column is numeric when it has at least one non-empty body cell, and every non-empty body cell (after `strip`) matches `\A[+-]?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?%?\z`. Its alignment cell is `--:`; others stay `---`. The header row is never tested.
- **Captions.**
    - Table: `_Data table · C column(s) × R row(s)_`, where R counts body rows.
    - DocString: `_Doc string · JSON_` (declared or detected JSON), `_Doc string · <media type>_` (other declared type), or `_Doc string_`.
- **DocString body.** JSON uses Ledger JSON. Today's truncation markers and limits are unchanged.

**Code.** `StepDesc#to_markdown` gains `mode: :log | :description`. `Formatter#extract_step_description` returns `nil` unless `rich?`, and `#emit_step_markdown_log` uses log mode.

### P8 · Assertion, evidence and HTTP cards

**Problem.**

- The Expected/Actual table flattens newlines and squeezes `Expected` to a few characters.
- `**Outcome:** FAIL` uses bold that doesn't render.
- `rp_evidence` joins its summary with ` | `.
- The HTTP `### Request` / `### Response` headings are 14 px, barely above body text.

**Failed assertion (ERROR):**

````markdown
## ✗ Assertion failed · Intentionally absent Typewords control can be clicked

```text
expected  click succeeds
actual    Timeout 1200ms exceeded.
          Call log:
            - waiting for get_by_role("button", name="M2 video intentionally absent control", exact=True)
```

_Details_ `api_key` = `[REDACTED]` · `recording` = `Playwright viewport recording is still active`
````

**Passed assertion (INFO), one line:**

```markdown
✓ Assertion passed · Order is accepted · expected `ACCEPTED`
```

**Failure evidence (ERROR):**

````markdown
## ✗ Missing Typewords control while recording

`Playwright::TimeoutError` at `http://localhost:5567/words` · evidence `failure.png`, `response.json`

```text
Timeout 1200ms exceeded.
Call log:
  - waiting for get_by_role("button", name="M2 video intentionally absent control", exact=True)
```

_Details_ `api_key` = `[REDACTED]`
````

**HTTP exchange, INFO:**

````markdown
✓ POST /api/orders → 201 · 84 ms

_Response_ · `application/json` · 51 B

```json
{ "orderId": "ORD-20261031-0042", "status": "ACCEPTED" }
```

`https://api.example.test/api/orders`

_Request_ · `application/json` · 55 B

```json
{ "account": "JPM-PRIME", "side": "BUY", "notional": 5000000 }
```

_Request headers · 4_

```text
Content-Type: application/json
Accept: application/json
X-Request-Id: ledger-42
X-Fixture: F11a
```

_Response headers · 1_

```text
Content-Type: application/json
```
````

**HTTP exchange, WARN or ERROR:** the same body; the title becomes `## ⚠ GET /words → 404 · 31 ms` or `## ✗ GET /words → 500 · 31 ms`. With `expected_status`, the meta line adds `` · expected `200` ``. With `error:`, it adds `` · error `<text>` ``.

**Rules**

- **Expected / actual block.**
    - Labels are `expected  ` and `actual    ` (10 columns). Continuation lines are indented 10 spaces.
    - Strings are shown as-is. Other values use Ledger JSON.
- **Details.**
    - A Hash with at most 6 scalar values, each at most 80 characters, renders as chip pairs.
    - Anything else renders as `_Details_` followed by a Ledger JSON fence.
- **Passed assertion.** Add `` · expected `<value>` `` only when it renders on one line within 60 characters. A details line follows if details were given.
- **Evidence card.**
    - Title is `## ✗ <action>`, or `## ✗ Failure evidence` when the action is empty.
    - The meta line has the error class, `at <url>` and `evidence <names>`, each part only when present.
    - The message goes in a `text` fence.
- **HTTP.**
    - Title path is the redacted path plus query. The meta line is the full redacted URL.
    - `_Request headers · N_` and `_Response headers · N_` are each followed by a `text` fence when there are headers.
    - Content type comes from the headers when present.
    - The status is the code only.
    - Body sizes measure input bytes (a String's bytes, or JSON serialization of a Hash), not the formatted preview. F11a's Hash inputs are 55 B and 51 B; their Ledger JSON previews are 62 B and 56 B.
- **Bounds.** Existing sanitisation, redaction and size bounds are unchanged (`SUMMARY_LIMIT`, `DETAILS_LIMIT`, `VALUE_LIMIT`, HTTP 16 KiB / 100 lines). The returned `summary:` used by the terminal is unchanged.

**Code**

- `Service::EvidencePresenter.assertion` (new Markdown) and `.failure` (new `card:` field; keep `summary:` / `details:`)
- `Formatter#report_evidence` (use `card:`)
- `Automation::HttpExchange#to_markdown`
- `Automation::CucumberLogger#http` and `#assertion` (unchanged routing)

### P9 · Run context on the Launch (opt-in)

**Problem.** Launches 63–76 have empty descriptions and, except Launch 70, no attributes.

**Switch.** `RP_RUN_CONTEXT=true` (config key `run_context`), default `false`.

**Attributes added:**

| Key | Value | Present |
| --- | --- | --- |
| `sdk` | `ReportportalCucumber::VERSION` | Always |
| `cucumber` | `Gem.loaded_specs["cucumber"].version` | Always |
| `ruby` | `RUBY_VERSION` | Always |
| `workers` | `PARALLEL_TEST_GROUPS` | 2.0.1 only, when set |
| `git.branch` | `GITHUB_REF_NAME`, else `CI_COMMIT_REF_NAME`, else `BRANCH_NAME` | When found |
| `git.sha` | `RP_SOURCE_COMMIT`, else `GITHUB_SHA`, else `CI_COMMIT_SHA` (first 7 characters) | When found |
| `ci.build` | `GITHUB_RUN_ID`, else `CI_PIPELINE_ID`, else `BUILD_NUMBER` | When found |

Values are trimmed to 128 characters. Explicit `RP_ATTRIBUTES` keys win on conflict.

**Description**, only when `RP_LAUNCH_DESCRIPTION` is empty: `Cucumber 12.0.1 · Ruby 3.4.2 · 4 workers · codex/cucumber-12@e7dae2b`. Parts that are missing are left out.

**Code.** `Config` (new key, env var and doc), `Formatter#handle_test_run_started`.

---

## 5. P10 · Ledger Tier 2 accent layer (separate commit)

**Switch.** `RP_PRESENTATION=plain|rich` (config key `presentation`), default `plain`. An invalid value warns once and falls back to `plain`.

**Closed vocabulary.** Rich output may add only:

- `<details><summary>…</summary>` … `</details>`
- `<span style="…">` using the exact token strings below

Anything else is a defect: classes, ids, other tags, `url(`, `position`, images, SVG, `<style>`.

**Tokens (exact strings):**

```text
PILL  = display:inline-block;padding:0 7px;border-radius:9px;font:600 10.5px/1.7 system-ui,-apple-system,Segoe UI,sans-serif;letter-spacing:.04em
PASS  = color:#276E50;background:#E6F5EE   (contrast 5.4:1)
FAIL  = color:#B23B3B;background:#FBEAEA   (5.0:1)
WARN  = color:#8A5A00;background:#FFF3D6   (5.4:1)
INFO  = color:#0F6C7A;background:#E3F4F7   (5.4:1)
TITLE = font:600 13.5px/1.5 system-ui,-apple-system,Segoe UI,sans-serif;color:#2B2B2D
TH    = font:600 10.5px system-ui,-apple-system,Segoe UI,sans-serif;letter-spacing:.06em;text-transform:uppercase;color:#6B6B6D
```

A pill is `<span style="PILL;TONE">LABEL</span>`.

**Where rich applies (RP log messages only):**

| Card | Rich change |
| --- | --- |
| P1 failure card | The tail becomes `<details><summary>Full backtrace · 62 frames · 56 framework and 2 runner frames not shown above</summary>`, a blank line, the fence, a blank line, `</details>` |
| P5 attachment | The kind becomes an INFO pill: `<pill INFO>PNG</pill> ` followed by `` `visible-fixture.png` · 640 × 360 · 5.3 KB ``. A preview longer than 20 lines is folded: `<details><summary>Preview · 84 lines</summary>` |
| P7 step arguments (log only) | Header cells of tables with at most 6 columns are wrapped in `<span style="TH">`. A DocString longer than 20 lines is folded: `<details><summary>Doc string · JSON · 48 lines</summary>` |
| P8 passed assertion | `<pill PASS>PASS</pill> <span style="TITLE">Order is accepted</span>` followed by `` · expected `ACCEPTED` `` |
| P8 INFO HTTP | `<pill PASS or INFO>201</pill> <span style="TITLE">POST /api/orders</span> · 84 ms`. Status tones: 2xx PASS, 3xx INFO, 4xx WARN, 5xx FAIL |
| P8 any HTTP | Headers are always folded (`<details><summary>Request headers · 4</summary>`). Bodies longer than 12 lines are folded |
| P8 WARN/ERROR HTTP, failed assertion, evidence | The first line is unchanged. A status pill may lead the meta line (second line) |

**Invariants**

1. The **first line of every ERROR-level message is byte-identical** in `plain` and `rich`.
2. Rich never touches item descriptions, item names, Launch description or attributes, native Cucumber messages, terminal output, or AppLog user text.
3. **Byte budget:** rich is at most plain + 1,024 bytes per message.
4. **Strip-tags legibility:** removing all tags from rich output leaves every plain-text word of the card in order, and no tag fragments.
5. A blank line always precedes and follows a fence inside `<details>` (required for SimpleMDE to parse it).

---

## 6. Guardrails (unchanged contract)

| Contract item | Status in 1.3.2 / 2.0.1 |
| --- | --- |
| Feature/Rule `SUITE`, statistical Scenario `STEP`, nonstatistical action Steps, hook types | Unchanged |
| Native hook ownership; After-hook evidence stays on the After hook | Unchanged |
| Timestamps, retry identity, `testCaseId`, `uniqueId`, `codeRef`, `parameters` | Unchanged |
| Item names | Unchanged except P6 hook names |
| Log count and level per item | Unchanged |
| Attachment bytes, count and MIME | Unchanged (P5 changes only default names of unnamed attachments) |
| Redaction | Unchanged on 2.0.1; added to the failure log on 1.3.2 (P1) |
| Preview limits (16 KiB / 100 lines; StepDesc 16 KiB / 100 lines / 32 columns) | Unchanged |
| No content guessing (Launch 74 `plain_base64` control) | Unchanged |
| Launch creation/finish ownership, statuses | Unchanged |

---

## 7. Versioning

| Line | From | To | Branch base | Notes |
| --- | --- | --- | --- | --- |
| 1.x | 1.3.1 (`maintenance/1.x` @ `4ca2f77`) | **1.3.2** | `maintenance/1.x` | Ruby ≥3.1, Cucumber ≥9,<11. No `workers` attribute (no ParallelFormatter). P1 adds redaction parity. Helm chart stays 1.3.1, appVersion 26.0.7 |
| 2.x | 2.0.0 candidate (`codex/cucumber-12`, frozen) | **2.0.1** | The committed frozen 2.0.0 baseline | Ruby ≥3.3, Cucumber ~>12.0 ≥12.0.1. Keep the 2.0.0 CHANGELOG section intact; add 2.0.1 above it. 2.x chartVersion unchanged |

Files to update on each line: `lib/reportportal_cucumber/version.rb`, `Gemfile.lock` (the gem's own `PATH` entry), `CHANGELOG.md`, `examples/current_sdk/helpers/sdk_version.rb`, the README compatibility table and install snippets, `docs/configuration.md` (`RP_PRESENTATION`, `RP_RUN_CONTEXT`), `docs/advanced-reporting.md` (new "Presentation" section), and version assertions in `spec/packaging/*`.

**SemVer note.** Tier 1 is presentation-only. P9 and P10 are opt-in additions, which strict SemVer would number 1.4.0 / 2.1.0. The owner chose patch releases; record that rationale in the CHANGELOG.

**Changelog draft (same text on both lines, adjusted for the version):**

```markdown
## 1.3.2 - Unreleased   (2.0.1 on the 2.x line)

### Ledger presentation

- Failure logs open with the exception class, message, feature line and project frames; the full original backtrace follows unchanged. (1.3.2 also redacts credentials in this log, matching 2.x.)
- Client-built Markdown escapes `<`, `>` and `&`, so values such as `<other>` are no longer dropped by ReportPortal's renderer.
- Attachment captions show name, kind, dimensions and size; unnamed attachments are named after their step; JSON previews are compact.
- Hook items read `Before hook` / `After hook` (plus the hook name when given) instead of `Before Hook: Before hook`.
- Step-argument logs caption DataTables and DocStrings, right-align numeric columns and no longer repeat the step line; steps without arguments send no description.
- Outline rows describe their Examples values on one line.
- Assertion, failure-evidence and HTTP logs use one card layout with an aligned expected/actual block.
- Opt-in `RP_RUN_CONTEXT=true` adds SDK, Cucumber, Ruby and CI attributes and a one-line Launch description.
- Opt-in `RP_PRESENTATION=rich` adds collapsible sections, status pills and table-header styling to ReportPortal log messages only.
- No change to item hierarchy, identity, statuses, timestamps, ownership or attachment bytes.
- Released as a patch at the owner's request; the two opt-in switches are additive and off by default.
```

---

## 8. Not in scope

- RP UI changes: fonts, table header CSS, code-block colours, gallery captions, the per-viewer Markdown toggle.
- Item name prefixes (`Scenario:`, `Feature:`, `[Background]`) and the other held-back items in section 1.
- Publishing: no tags, GitHub releases, RubyGems pushes or Helm publication.

## 9. Upstream note for ReportPortal (not client work)

In RP UI 5.15.6, the log renderer's output keeps a `<style>` element and `background-image:url(…)` in inline styles. A log message could therefore restyle the whole page or make every viewer's browser fetch an outside URL. This was observed in the render function, not with a stored log. File it upstream with a minimal reproduction made in a disposable project.


## Decisions

Decisions 1-8 were owner-confirmed on 2026-10-31; Decisions 9-10 on 2026-11-01.
The following questions and answers are reproduced
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

9. Question: 独立 QA 发现 P10.6 的 strip-tags 定义（删除所有 <[^>]+>）会把原始 Ruby 堆栈里的 `<top (required)>` 也删除，与 P1 要求完整保留堆栈冲突。是否改为仅剥离客户端生成的展示 HTML，保留代码块、代码片段和用户原文中的尖括号，再严格检查文字顺序（仅沿用已批准的 Rich 样例差异）？

   Owner answer: 按此澄清规则，保留原始内容（推荐）

10. Question: V7 的“开始前完整 ls-remote Tag 清单”未保存；我找到了本任务开始前 GitHub CI 的完整 Tag 拉取记录，8 个 Tag 与当前远端清单完全一致，三个受保护分支也均未变。是否允许用该历史 CI 记录与当前 ls-remote 对照作为替代证据，并在报告中注明来源？不会改变“禁止创建 Tag”的要求。

    Owner answer: 接受历史 CI 记录作为替代证据（推荐）

