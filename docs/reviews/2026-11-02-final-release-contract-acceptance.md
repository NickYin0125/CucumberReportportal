# SDK 2.0.2 Final Release Contract Acceptance

Date: 2026-11-02. Independent contract QA.

**Verdict: ACCEPT for the independently tested nonvisual contract scope at
`8f44c10533eb4d0a8eae1adcc2ed5b63ace155c7`.** No product defect was found in
this scope. This is not the aggregate release verdict: independent visual and
performance gates remain PENDING here. Master owns their aggregation. No merge,
tag, publication, push, staging or commit was performed by this reviewer.

## Authority and Provenance

The normative sources are the final SDK's
`docs/design/presentation-ledger-acceptance.md`, proposal goldens and
`presentation-ledger-owner-decisions.md`, including Decisions 7, 9, 11 and 27.
Other reviewers' verdict reports were not consulted. Existing tests and scripts
were inspected only as methods or fixture inputs.

The SDK worktree remained read-only. Its clean HEAD and Git blob bytes were
checked before staging the source and after execution. Fresh evidence is under
`docs/reviews/assets/QA202-final-release-20261102-contract/`. Package inputs
were exported from the exact SHA, built and installed into an isolated new gem
home. Installed library hashes match the exported final source. The built gem
SHA-256 is
`98e411eb17aee10403de9c7aa08033ea714185ec4f8beb76d10bf68353a06002`.

Runtime: Ruby 3.4.2, arm64-darwin, Cucumber 12.0.1. The precise activated
dependencies and loaded SDK paths are retained per fixture and in
`trial-installed-runtime.json`; the trial runtime's source-byte comparison is
true. Fixture dependencies explicitly select compatible diff-lcs below 2.

Every real reporting request went to
`http://rp-2607.localhost:18080`, project `superadmin_personal`, through the
existing transparent, ownership-guarded local observer. Authentication used the
existing protected local admin credential source to obtain an in-memory OAuth
access token. No API key was created, no credentials were printed or saved,
and no secret-bearing network leak test was performed. Adversarial values are
synthetic; example.test URLs were formatted as evidence, never requested.

## Results

The authoritative machine-readable ledger is `criterion-results-v3.json`:
43 explicit results, 37 PASS, six PENDING, zero FAIL. The accompanying
`plain-rich-comparison-v3.json` retains each paired log's IDs and comparisons.

| Criterion | Result | Evidence |
| --- | --- | --- |
| G8 | PASS | Every persisted message/name/description/attribute scanned; 69 Launch marker queries returned zero. Encoded forms were repeatedly decoded before marker scanning. |
| Original deferred malformed URL | PASS | Original script executed unchanged against final source; checksum, original input and all result fields in `original-deferred-probe.json`. Shared/default and fresh injected policies agree; no synthetic credential residual. |
| Encoded safety | PASS | Fresh 81-case matrix: plain, normalized and Unicode-escaped keys; complete-mask prefixes versus incomplete masks; 1-3 complete encoding layers; path/query/fragment/malformed URLs; Bearer values. Seven output channels per input, default/fresh equivalence and 62-frame preservation. |
| Live security and raw curl | PASS | Launches 4066/4067 contain eight adversarial scenarios each. All 16 failure cards retain the complete contiguous 62 safe frames; only unsafe URL evidence may be withheld. Sixteen ordinary AppLog curl messages read back byte-for-byte, with synthetic values only. |
| Attachment identity/ownership | PASS | Multipart filenames map to the same persisted item UUID, message and level; downloaded SHA-256, byte count and MIME match the actual sent bytes. Includes F01, F04 After JPEG, F12, F18 and all six trials. |
| Finalization | PASS | All 69 newly created Launches and their items have end times and are not IN_PROGRESS. No existing Launch was changed. |
| P1.1-.5, P1.7, P1.10 | PASS | Frozen F04 equals the corrected golden byte-for-byte, including all 62 original tail frames; live F16 title, continuation, empty/long-message and secret shapes; focused framework-fallback coverage. |
| P1.6, P1.8, P1.9 | PENDING | DOM/rendering/screenshot acceptance belongs to the independent browser reviewer. Links supplied before report completion. |
| P8.1-.9 | PASS | Exact assertion, HTTP and evidence goldens; multiline indentation; detail shapes/bounds; heading levels; URL redaction; fresh baseline/current terminal comparison ignoring only timestamps. |
| Decision 27 values/HTTP | PASS | Empty and boundary-whitespace values labeled; missing/extra/changed top-level keys; response-first HTTP sections; each non-sensitive repeated header value retained separately. |
| P10.1-.7, P10.9 | PASS | Unset/default and invalid mode behavior; exact allowed styles/tags; whole ERROR/FATAL messages equal across modes; all rich byte budgets; approved word-order exceptions only; required metadata, native channels and terminal parity. Eight-column F13 has no TH spans; the distinct four-column control correctly has them. |
| P10.8 nonvisual | PASS | Each rich details fence has a blank line before its opener and after its closer; actual DOM component remains with browser reviewer. |
| P10.10-.11 | PENDING | Independent rich rendering and computed-contrast review. |
| F18 / P5.5 | PASS | Exact 100-line and 16-KiB preview markers, preserved full attachment downloads and hashes. |
| Six current_sdk trials | PASS | Original consumer inputs unchanged; isolated installed gem and SDK_REF rebound to final SHA; real runtime logging/API readback; deliberate application failures remain failures. |
| Focused regression | PASS | Nine focused spec files, 362 examples, zero failures, zero pending. Full source runtime matrix is independently corroborated through remote CI. |
| CI | PASS | Connected GitHub API query for final SHA returns successful PR run 41462363187; six matrix cells and gate successful. Push run 41462349016's job readback also has six successful cells and gate. Workflow artifact-bundle job is intentionally skipped, not a test skip. |
| G11 | PENDING | Separate performance owner. No performance measurements were made here. |

### F16c Scope

**Native F16c remains N/A: Ruby `raise` requires an Exception.** Its original
unsupported classification is preserved in this report and the supplemental
scope receipt. The explicitly named event-adapter replay passes a non-Exception
field shape into the formatter after a real Exception has failed the scenario.
It is supplementary UNIT/protocol evidence only, not evidence that Ruby or
Cucumber natively raised a non-Exception. No native outcome was fabricated and
the replay does not waive other P1 checks.

### Comparison Precision

Native channel comparison removes event UUIDs and clock fields, not evidence
values; complete original NDJSON is retained. P10.7 compares all its required
metadata and additionally item types, statuses, parameters and code references.
Server-generated `auto:` uniqueIds, absent from both outgoing requests, are not
treated as P10.7 presentation data. Their original request/response records are
retained; this is not a new G1 waiver or a baseline identity certification.

Terminal timestamps and Cucumber duration lines alone are normalized, including
timestamps immediately after progress marks. The timestamp-sensitive initial
comparison is retained. F12's native rp_evidence routing emits no terminal line;
its complete plain/rich native process output is also equal after clock removal.

The initial assessment files without a version suffix are retained, not erased.
Their false positives came from checker assumptions: decorative Markdown
underscores in word comparison, contrast annotations mistakenly parsed as CSS,
the four-column F13 control confused with the eight-column case, extra
server-generated uniqueIds, literal label wording, and progress-prefixed
timestamps. Versioned v2/v3 assessments use the same captured runs; no product
source, captured evidence or criterion was weakened to obtain PASS.

## Fresh Browser Handoff

| Target | Launch / Item / Log | URL |
| --- | --- | --- |
| F14 script literal, plain | 4024 / 32919 / 22182 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4024/32897/32918/32919/log |
| F14 script literal, rich | 4045 / 33061 / 22278 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4045/33039/33060/33061/log |
| F14 b-tag literal, plain | 4024 / 32901 / 22173 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4024/32897/32900/32901/log |
| F18, plain | 4026 / 32975 / 22216-22219 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4026/32973/32974/32975/log |
| F18, rich | 4047 / 33117 / 22312-22315 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4047/33115/33116/33117/log |
| F04 frozen, plain | 4041 / 33027 / 22246 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4041/33025/33026/33027/log |
| F04 frozen, rich | 4062 / 33169 / 22342 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4062/33167/33168/33169/log |
| PASS palette | 4059 / 33158 / 22336 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4059/33156/33157/33158/log |
| FAIL palette, WARN-level HTTP 500 | 4064 / 33177 / 22355 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4064/33175/33176/33177/log |
| WARN palette | 4053 / 33140 / 22330 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4053/33138/33139/33140/log |
| INFO palette | 4061 / 33166 / 22339-22341 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4061/33164/33165/33166/log |
| Rich INFO HTTP | 4054 / 33143 / 22331 | http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/4054/33141/33142/33143/log |

Six final-runtime trial Launches: API plain **4016**, UI plain **4017**, API rich
**4018**, UI rich **4019**, independent API **4022**, independent UI **4023**.
Every item/log link and message checksum, including these trials, is indexed
in `launch-item-log-index-v3.json`.

## Preserved Attempts and Boundaries

The first preparation invocation selected system Ruby 2.6, stopping after source
export; preparation resumed with explicit Ruby 3.4.2 after verifying identical
export bytes. An initial fixture child had a local diff-lcs/RSpec activation
conflict before any Launch was created. The corrected activation is recorded.

The next attempt captured F01 Launch 4020 and completed F04 Launch 4021, but its
GET readback hit one connection-open timeout. Original attempt files remain.
Launch 4021 was recovered with GET-only requests from its captured UUIDs, with
no rerun or mutation. Bounded current captures are in the v3 directories. The
only supplementary executions were the explicitly recorded P1/F13/invalid/default
mode and synthetic security cases; no unbounded campaign was run.

All live generation is finished. No browser was operated for acceptance,
screenshots or performance; requested unchanged automated UI trial suites did
execute their own headless browser inputs. Browser and performance reviewers
may proceed using this complete handoff. Existing QA evidence was not replaced,
and the original trial directory's input files remain byte-identical.

The exact owned file list and provenance hashes are in `owned-files.json` and
`evidence-sha256.json`. The protected-value/JWT/base64 secret scan result is in
`secret-scan.json`. Files are intentionally left uncommitted for Master's
serialized scan/staging/commit process. Only owned scripts, this report, and
the named owned asset directory are eligible; never stage the whole worktree.

`preservation-check-v2.json` verifies the original historical QA files unchanged.
The first broad hash comparison also included this reviewer's then-unfinished
fixture script and the concurrently edited browser-review script. Those
authorized working files are explicitly excluded from the historical-file
check; the initial observation remains intact. No other reviewer's verdict
content was inspected.
