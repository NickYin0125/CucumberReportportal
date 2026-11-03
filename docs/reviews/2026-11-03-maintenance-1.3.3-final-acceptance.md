# Independent Final Acceptance: Maintenance 1.3.3

## Verdict And Scope

**ACCEPT, scoped local acceptance**, frozen SDK
`68e81d3697965305438be4fa27aa98aeb4baf726`, against released 1.3.2
`19174a5ecaf1aa9fb65480f0a21d74ed65c89a8d`. No outstanding blocking finding
was found in independent review or the completed gates below. This accepts the
selective maintenance backport, not a 2.x migration, whole-page WCAG compliance,
network/upload SLA, remote CI result, release, tag or deployment.

No SDK implementation edits, commits, pushes, deployments, service pauses or
new credentials were made by QA. The manager-owned review was not used as an
execution oracle and is not overwritten. Feature push/draft-only remote CI is
a subsequent owner-authorized manager action; publication remains unauthorized.

## Canonical Full Matrix

Evidence: [canonical matrix](assets/qa-1.3.3-candidate-20261103T113932Z-e485/matrix.json).
Every row executed the final committed tests, without overlays, global
`BUNDLER_SETUP` deletion, excludes or omitted files. Unfiltered discovery and
execution match **1878 examples across all 135 files per cell**. The historical
1519 minimum is a guard, not the actual count. Pending and outside-example
errors are zero in every suite.

| Cell | Ruby | Cucumber / Expressions | Full RSpec | Separate Release Isolation | Independent Probes | Full Offline Cucumber |
| --- | --- | --- | --- | --- | --- | --- |
| M1 | 3.1.7p261 | 9.2.1 / 17.1.0 | 1878, 0 failures | 9, 0 failures | 88, 0 failures | 1 scenario / 3 passed steps |
| M2 | 3.1.7p261 | 10.2.0 / 18.1.0 | 1878, 0 failures | 9, 0 failures | 88, 0 failures | 1 scenario / 3 passed steps |
| M3 | 3.3.12 | 9.2.1 / 17.1.0 | 1878, 0 failures | 9, 0 failures | 88, 0 failures | 1 scenario / 3 passed steps |
| M4 | 3.3.12 | 10.2.0 / 18.1.0 | 1878, 0 failures | 9, 0 failures | 88, 0 failures | 1 scenario / 3 passed steps |

Totals: **7512 full SDK examples + 36 separate isolation examples + 352 owned
independent probes**, all passing; four offline scenarios / twelve passed steps.
The release isolation examples are additional, not silently included in 1878.
Bundler is 2.6.6, diff-lcs 1.6.2 and RSpec core 3.13.6. Each cell retains its
exact resolved Gemfile/lock, activated versions, image digest, commands,
preflight, per-file discovery counts and unchanged-source proof.

Genuine Linux jq and shared libraries were validated before execution. Ruby 3.1
uses image `33b5e8c8e1758deef0c66b23dd3165d1a00eb2e6192ed2c784549efbaf921f69`
with jq 1.6; Ruby 3.3 uses
`be5daf6e4acf02ce07fb8db1a3723929ef27653e0f7f3f0694a6ba5536c61a35`
with jq reporting 1.7 (Debian package 1.7.1-6+deb13u4). Ruby, Bundler, git, jq,
helm, Docker/Compose, SDK bounds and isolated dependency selection are checked.
No SDK Gemfile or lockfile was rewritten.

## Independent Behavior And Review

The unchanged red assertions from the rejected first freeze now pass. Owned
probes cover encoded JSON keys/values in paths, query, fragments, malformed URLs,
depths 1-5 and the MAX-1/MAX/MAX+1/5 boundary through direct, HTTP and evidence
channels; repeated plaintext/encoded Bearer and masked-prefix residue; benign
controls; native/plain API originals; raw AppLog and Decision 19 preservation.
Over-depth benign/already-masked inputs are intentionally withheld after the
three-pass inspection budget. This is bounded fail-closed behavior, not extra
decode passes or a promise to preserve every over-encoded benign URL.

ERROR/FATAL are wholly plain; whitespace assertions remain distinguishable;
key deltas are shallow and sanitized; response preview precedes request/URL
metadata with repeated headers preserved. Run-context and explicit-value
preservation are covered. Raw failure messages and joined original frames are
preserved, including multiline/raw-tail and zero-FailureRedactor-call checks.

[Fresh final source review](assets/qa-1.3.3-final-source-proof.json) records all
46 library hashes, nine expected changed runtime files and ten protected runtime
files byte-identical to 1.3.2, including formatter/lifecycle, FailureRedactor,
raw AppLog, runtime context/join/buffer and queue/spool. Review found no imported
2.x lifecycle, status or NUL semantics. Helm remains 1.3.1. Freeze 3's difference
from Freeze 2 is only three explicit child `env -u BUNDLER_SETUP` spec additions;
assertions/scripts and runtime/package/example bytes are unchanged.
The [final gate audit](assets/qa-1.3.3-final-gate-audit.json) independently checks
all four execution/discovery ID sets and totals, unchanged original red-probe
file hashes, fully clean final source and identical normal/adversarial dependencies.

## Fresh RP And Installed Consumer

Evidence: [live runtime summary](assets/qa-1.3.3-live-20261103T115435Z-8112/live-summary.json)
and [completed independent audit](assets/qa-1.3.3-live-20261103T115435Z-8112/live-final-audit.json).
Only four fresh launches were written, serially, to
`http://rp-2607.localhost:18080`, project `superadmin_personal`.

| Launch | Cucumber | Mode | Items / Logs | Scenario Outcomes | PNG Entries |
| --- | --- | --- | --- | --- | --- |
| 4085 | 9.2.1 | plain | 16 / 15 | 5 scenarios, 2 intentional failures | 2 |
| 4086 | 9.2.1 | rich | 16 / 15 | 5 scenarios, 2 intentional failures | 2 |
| 4087 | 10.2.0 | plain | 16 / 15 | 5 scenarios, 2 intentional failures | 2 |
| 4088 | 10.2.0 | rich | 16 / 15 | 5 scenarios, 2 intentional failures | 2 |

Native exit 1 and FAILED launches are expected fixture outcomes, not regression
failures. Every launch carries the complete frozen source SHA and its actual
locally built package SHA256. All 46 installed library files match that source.
Every original failure message and every original frame (67 on Cuke 9; 68 on
Cuke 10) survives the downloaded RP log. Outline substitutions remain distinct.
All eight PNG filenames are unique; each has exactly one caption-plus-binary RP
entry under its own failed scenario's **PASSED After hook**, with downloaded
bytes/hash equal to the original. No completed failed Step is retargeted.

The actual installed package's `examples/current_sdk/test/self_test.rb` ran under
both Cucumber 9.2.1 and 10.2.0: **13 checks each, 26 passing**. Packaged example
bytes and activated SDK/Cucumber are recorded. These execute the real failed-check
title, last-passed-action, hex4 filename, one RP queue entry and preserved original
error checks, not the QA fixture's hex8 reimplementation. These self-tests use a
fake page/queue boundary; they are not a claim that full Playwright `bin/verify`
or the example itself ingested a live RP launch. The separate four launches
above prove actual ingestion and attachment ownership.

## Real UI, F18 And Limitations

Authenticated existing Edge session, actual CUA DOM/screenshots, no browser API
credential injection. Each launch has a complete `ui/<launch>-main-complete.json`
showing response-first content, repeated header values, literal DocString and
DataTable input, no executable injected nodes, no automatic HTTP secret and no
ERROR decorative spans/details. Both framework versions and presentation modes
were actually viewed; failure and After screenshots are retained.

F18 on all four views: 340-line text previews exactly 100 lines, 48-KiB single-line
text previews exactly 16,384 characters, and JSON previews 27 lines. Rich text/JSON
have real folds; plain mode does not. The folds were actually opened and their
literal escaped script input/JSON inspected. Original downloads match all fixture
bytes/hashes (12,471 / 49,152 / 359 bytes), not only preview footers.

Measured generated badges meet the client criterion: INFO **5.3823:1**, HTTP 201
PASS **5.4364:1**. **RP's unchanged frontend code-block theme is only 2.6529:1**
(`rgb(127,153,58)` on `rgb(233,233,233)`, `inlineStyle=null`). This is an external
frontend-theme readability limitation, separate from SDK-generated badge styling;
the whole page is **not claimed WCAG-compliant**. No SDK CSS workaround was added.

The initial `4088-argument-escaping.json` was partial and is not a DataTable pass.
Use `4088-argument-escaping-complete.json` and all four `*-main-complete.json`
proofs instead. The original mid-card HTTP screenshot is retained; the corrected
`4088-rich-response-first-top.jpg` shows the response at the actual card top.

**R02 remains NOT FIXED.** Actual 4085 filter check leaves the After row visible
but hides its PNG evidence/log with Hide All Passed Logs enabled; filter restored
afterward. Hook ownership/status and native PNG duplication are not changed as
workarounds. Original compound DocString+DataTable and native global-hook item
names remain the established Cucumber 9/10 / 1.x N/A boundaries; separate supported
argument steps were used.

## Matched Performance And Impact

[Original paired series](assets/qa-1.3.3-paired-bench-20261103T120527Z-df3d/comparison.json)
is retained without reruns: matched Ruby 3.3.12/Cuke 10.2.0 and activated
dependencies, same pinned image, no network, one CPU/two GiB, three alternating
baseline/candidate-order repetitions, 1000 measured iterations and 20 excluded
warmups per case/repetition. Pooled values below use 3000 retained samples per
line/case; raw samples and every repetition's median/p95 are retained.

| Case | Median Baseline -> Candidate (ms) | p95 Baseline -> Candidate (ms) | Median Change | p95 Change |
| --- | --- | --- | --- | --- |
| failure plain | 0.056583 -> 0.054375 | 0.224083 -> 0.145958 | -3.90% | -34.86% |
| assertion plain | 0.054000 -> 0.052375 | 0.237750 -> 0.179834 | -3.01% | -24.36% |
| benign HTTP plain | 0.876083 -> 0.921375 | 1.571250 -> 1.814542 | +5.17% | **+15.48%** |
| failure rich | 0.120208 -> 0.057875 | 0.370625 -> 0.204584 | -51.85% | -44.80% |
| assertion rich | 0.058000 -> 0.055291 | 0.232709 -> 0.228375 | -4.67% | -1.86% |
| benign HTTP rich | 1.056417 -> 1.093542 | 1.989167 -> 2.120292 | +3.51% | +6.59% |

HTTP per-repetition variation is material, especially plain repetition 2:

| Case / Metric (ms) | Baseline Repetitions 1 / 2 / 3 | Candidate Repetitions 1 / 2 / 3 |
| --- | --- | --- |
| plain median | 0.895667 / 0.893917 / 0.844542 | 0.953875 / 0.905417 / 0.912500 |
| plain p95 | 1.714375 / 1.541667 / 1.469208 | 1.782959 / **2.620209** / 1.697292 |
| rich median | 1.042792 / 1.088083 / 1.039083 | 1.077291 / 1.062250 / 1.137959 |
| rich p95 | 1.862000 / 2.176000 / 1.897375 | 2.098833 / 1.999541 / 2.339250 |

Independent impact judgment: normal failure/assertion costs were lower in this
sample, but benign HTTP **did get more expensive**. Pooled plain HTTP adds about
0.0453 ms median / 0.2433 ms p95; rich adds 0.0371 / 0.1311 ms. This observed CPU
cost and variation are a non-blocking tradeoff for this scoped maintenance
acceptance, not an all-green performance claim or proof of statistical
insignificance. The agreed gate required matched cost reporting, not a newly
invented latency threshold. No network/upload SLA or universal workload claim
is made, and no causal allocation to an individual change is inferred.

**Owner acceptance, 2026-11-03:** the owner explicitly accepted the measured
plain HTTP p95 increase from **1.57 to 1.81 ms (+15.5%) as acceptable**. This records
the owner's rounded approval wording; the exact retained measurement remains
1.571250 to 1.814542 ms (+15.48%). Raw data and CPU-only/scoped measurement limits
are unchanged. No further optimization or performance reruns were requested or
performed, and this approval does not create a network/upload SLA.

### Separate Existing Adversarial Inputs

[Candidate-only timing](assets/qa-1.3.3-adversarial-bench-20261103T120927Z-a036/timing.json)
reuses only existing probe inputs, the same frozen export/image and all 46
verified library hashes. One bounded series: 1000 iterations / 20 warmups per
case, reused EvidenceRedactor instance; fixture encoding and safety checks are
outside the measured direct call. Before/after checks prove no residual synthetic
secret after six downstream decodes and unchanged inputs. Raw samples retained.

| Existing Input / Direct Operation | Median (ms) | p95 (ms) |
| --- | --- | --- |
| JSON path depth 2 / redact_url | 0.063584 | 0.149875 |
| JSON path depth 3 / redact_url | 0.078791 | 0.228959 |
| JSON path depth 4 / redact_url | 0.041916 | 0.146083 |
| JSON path depth 5 / redact_url | 0.042750 | 0.156667 |
| duplicated plaintext Bearer / redact_text | 0.016792 | 0.025542 |

These are not complete HTTP/evidence/network timings or a comparison against
unsafe old passthrough. The normal paired series was not rerun to seek a pass.
No new corpus, SDK fix, unrelated load scenario or service stop was introduced.

## Retained Controls And Remaining Risk

[Historical record](2026-11-03-maintenance-1.3.3-independent-acceptance.md) retains
the first freeze's **NOT ACCEPT**: three owned red checks expose one repeated-Bearer
leak; its completed M1 ran 1828 full examples with eight missing-jq QA environment
failures. The master-requested stop was not a user task pause. Freeze 2 retains
its three genuine standalone-spec isolation defects (not old 2.x contamination
or an SDK helper defect), and incomplete M4 is not counted as full. Final matrix
used the three committed spec env-unsets and no QA monkeypatch.

Canonical targeted v1.3.2 baseline remains 46 probes per cell, 21 passed / 25
expected DELTA/SEC failures / zero pending, with all 14 preservation invariants
passing. It is not a fabricated full baseline execution. Failed/superseded
harness setup attempts are retained and separately classified.

**Released 2.0.2 still has the shared depth-4/5 encoded JSON-path risk**, reproduced
independently against verified released redactor/key-policy bytes. Its tag was
not touched and these 1.x results do not claim that 2.0.2 covers the guard. The
three-pass residual-escape fix is intentionally 1.x-only in this acceptance.

## Owned Curated Files

Complete file paths, byte sizes, SHA256 values, ownership and per-entry evidence
classifications are in `assets/qa-1.3.3-curated-manifest.json`; include that manifest
itself separately when staging a future QA commit. Primary methodology is
`qa/readability_1x/README.md`; all exact full/live/normal/adversarial/audit commands
are recorded there and in retained command JSON. The manager review is inventoried
with its separate ownership, not as independent execution proof.

The whitelist includes `.feature`, required shell/YAML files, Gemfiles/resolved
locks and curated logs/JSON/screenshots. Nested source clones, Git stores, gems,
caches, native HTML and packages remain excluded local runner state. Do not stage
the whole multi-GB evidence working directory or turn an SDK clone into a gitlink.
Generated SDK fault scratch is also local-only; complete full-run outcome/failure
JSON and logs, including the earlier red attempts, remain curated.
