# SDK 2.0.2 Readability: Blocked Acceptance Checkpoint

## Decision And Scope

**NOT ACCEPTED. Do not merge, tag or publish.** PR #8 remains draft. The owner authorized a performance-only optimization after the first G11 failure, then explicitly declined expanding this round to fix a newly discovered malformed-URL credential-redaction gap. That gap remains a release blocker, not an accepted exception or a passing test.

Current code head: `aa7eef97192b5ba906fe800926d88e26f1c87f18`. Runtime changed last at `50b6d4d1d3b6c61926a023fc96bf291878ab68b0`; the subsequent commit changes only test injection. Neither 1.x nor a protected branch was edited or pushed. No releases/tags were changed.

Docker recovered after the owner's disk cleanup. A graceful restart timed out, then Docker's forced stop/start restored the existing kind containers without reset or volume deletion. The UI returned HTTP 200, the relevant pods became Ready, and authenticated readback of Launch 3849 returned its saved FAILED result. This is recovery evidence, not a production availability certification.

## Commits

All rows belong to `codex/failure-redaction-2.0.2`, after `ee7687d`.

| SHA | Change |
| --- | --- |
| f2bf325c | Record owner Decision 27. |
| ff38ae8b | Preserve safe frames and explicitly label withheld failure messages. |
| 78d34661 | Keep ERROR/FATAL rich messages byte-identical to plain. |
| 77758386 | Make empty and edge-whitespace assertion values visible. |
| ef0feec1 | Show HTTP outcomes before transport details. |
| baa8940a | Summarize top-level JSON-object key differences. |
| 7a2fdb51 | Simplify generated Launch descriptions without removing version attributes. |
| e8d25877 | Consolidate example failure PNG evidence and clarify diagnostics. |
| 82037f43 | Document readability behavior and owner-approved example tradeoffs. |
| 9bf3356c | Isolate release dependencies from the source tree. |
| 2d037abd | Initialize runner paths in a step rather than invalid job-level context. |
| d1725d3a | Update the HTTP integration assertion to outcome-first order. |
| 090b6338 | Add actionable Node and reused-Playwright version checks. |
| 50b6d4d1 | Reuse a frozen default failure-redaction policy; add 20 real-policy safety tests. |
| aa7eef97 | Preserve exact two-unit formatter assertions using real-policy injection. |

## Verification Ledger

| Execution | Result | Limit |
| --- | --- | --- |
| d1725d3, cloud Ruby 3.3 and 3.4 | Each: 1,631 RSpec examples, 0 failures; 9 release-isolation examples, 0 failures; 7 offline Cucumber scenarios / 21 steps, all passed | Prior runtime head, not the performance patch. |
| 090b633, remote checks | 14 SUCCESS, 2 expected bundle SKIPPED | Includes one extra documentation example; no tag publication occurred. |
| 50b6d4d, local automation/presentation | 500 examples, 0 failures | Includes 20 reuse/concurrency/budget/retention tests, not the separate known-security-blocker probe. |
| 50b6d4d, full cloud Ruby 3.3 and 3.4 | Each: 1,652 examples, 2 failures | Both formatter spies assumed per-failure construction; original failed CI is preserved. |
| aa7eef97, local formatter and redactor followup | 88 examples, 0 failures | Overlaps the 500 checks; do not add counts as distinct examples. Both exact arguments and call counts remain. |
| aa7eef97, full remote suites | Pending final collection | Never infer PASS from the focused tests. |
| Deferred malformed-URL probe | Exit 1, BLOCKED | Same leak with shared default and fresh injected policy. Synthetic input only; no RP traffic. |

The first local full matrix on 9bf3356 had a stale HTTP-order assertion failure later corrected by d1725d3. Subsequent local matrix attempts were interrupted or could not start during the disk/Docker incident; they are not successful runs. The complete successful evidence above is explicitly cloud execution.

## Comparable Real RP Trials

The six trials executed an installed Gem built from `9bf3356`, with Ruby 3.4.2, Cucumber 12.0.1 and Playwright Ruby 1.62.0 / CLI 1.62.1. Eight independent tester input files were SHA-identical to the original trial, and no package.json was added. The target was the shipped loopback practice fixture, not a new Typewords or production run.

| Trial | Previous | New | Passed / intentional failed |
| --- | --- | --- | --- |
| API plain | 3837 | 3849 | 14 / 2 |
| UI plain | 3838 | 3850 | 8 / 2 |
| API rich | 3839 | 3851 | 14 / 2 |
| UI rich | 3840 | 3852 | 8 / 2 |
| Independent API | 3842 | 3847 | 1 / 1 |
| Independent UI | 3841 | 3848 | 1 / 1 |

Total: 56 scenarios, 46 passed and 10 intentional failures; no IN_PROGRESS items in the collected final trials. Preliminary Launches 3843-3846 included tester folders through broad tag profiles and are retained but excluded from comparison. The new independent tester mode is rich versus the old plain tester mode; that is not a controlled mode-only comparison.

Runtime/sample-code identity was bound through 090b633, with its README-only followup explicitly excluded. **The 50b6d4d runtime optimization is not a new execution of these Launches.** Fresh final-runtime live acceptance is not claimed while the security blocker remains open.

## Finding Dispositions

Verdicts describe sampled user experience, not release certification. Original source severities and dissent remain in the copied reports. `E###` means visual evidence `VR20202-E###`.

| Finding | Re-review disposition | Evidence / boundary |
| --- | --- | --- |
| R01 | Partly fixed, API and visual | 3851 / 31845 / 21303; E012-E015. Class and frames survive, some messages remain withheld. |
| R02 | Not fixed, UI and visual; owner-deferred | E042 off / E044 on; PASSED After still owns failure PNG. |
| R03 | Fixed, UI | Unique Scenario/checkpoint filenames; 3848 / 31635 / 21026. |
| R04 | Fixed, UI and visual | E023-E026 distinguish failed restored-word check from passed refresh. |
| R05 | Fixed in example, UI | One caption-plus-PNG entry in After; original comparison and exception remain separate. |
| R06 | Fixed, API | 3849 / 31595 / 20968 and 3851 / 31758 / 21178: one HTTP exchange. |
| R07 | Fixed in sampled empty string, UI and visual | E023-E025 show explicit empty actual; broader variants separately covered by Ledger checks. |
| R08 | Partly fixed, API | Key summary helps, but RP still requires expansion for complete actual JSON. |
| R09 | Fixed in supplied example, API and visual | E010-E011 / E022: explicitly diagnostic INFO observation. |
| R10 | Fixed documentation gap, API | Shared HTTP bounds and full-body route documented; no large-body user experiment claimed. |
| R11 | Fixed, API | Public guide terminology corrected. |
| R12 | Fixed, UI | 2.x troubleshooting identifies the correct Cucumber line. |
| R13 | Fixed documentation gap, UI | Followup at 090b633: Node >=20 and exact CLI compatibility checks. No fresh-machine installation certification. |
| R14 | Not fixed at original targets, UI and visual | E032-E038; generic successful-image captions and RP viewer chrome remain. |
| R15 | Fixed in sampled setup, Master | No package.json; local npm prefix and installed CLI checked. |
| R16 | Fixed in sampled UI, visual | E012-E015 / E039-E040; Ledger also verifies 53 ERROR/FATAL pairs byte-identical. |
| R17 | Fixed in sampled UI, visual | E007-E009 / E018-E019, plus post-recovery plain HTTP and expected-400 captures. |
| R18 | Fixed top-level missing-key case, visual | E012-E015 / E047-E048; not a recursive diff engine. |
| R19 | Fixed authored example titles, visual | E005-E006 / E017 distinguish persevere and focus. |
| R20 | Partly fixed, visual | E001-E004: runtime prose duplication removed; purpose/mode naming still caller-dependent. |

Additional S3 observations: a small request body still needs row expansion after response-first ordering; a long consolidated PNG caption can hide ownership/file metadata until expanded. Neither is evidence loss. API reviewer recommends limited adoption with native/local evidence retained; UI reviewer remains conditional; visual reviewer now prefers rich opt-in while keeping plain default.

## Visual Scores

| Surface | Old | New |
| --- | ---: | ---: |
| Launch metadata | 3 | 3 |
| Tree and names | 4 | 4 |
| Step/hook logs | 3 | 4 |
| Failures/traces | 2 | 4 |
| HTTP cards | 3 | 4 |
| JSON/tables/DocStrings | 4 | 4 |
| Attachment labels | 3 | 3 |
| Screenshots | 4 | 4 |
| Plain/rich comparison | 2 | 4 |

Visual report: 7 original issues fixed, 2 partial, 1 not fixed; 72 validated captures after recovery. API: 4 fixed, 2 partial. UI: 6 fixed, 2 not fixed. These are separate source counts, not a combined defect count.

## Acceptance And Performance

The first independent Ledger report covers 139 Launches (3853-3991): P1 9 PASS/1 PENDING, P8 9 PASS, P10 8 PASS/3 PENDING, and G8 PASS only for that captured set. Missing DOM criteria remain P1.6, P10.8, P10.10 and P10.11, including F18 coverage. The later offline security probe blocks the overall safety verdict; the historical corpus result does not override it.

G11 window 1: matched plain renderer p95 1.002333 to 0.868958 ms; matched redaction-plus-rendering p95 6.055875 to 10.137500 ms, **+67.40%, FAIL**. Stop was honored; no rich/F07 timings followed. Historical accepted renderer-only p95 1.612125 ms is retained and is not misrepresented as a full-path baseline.

G11 window 2 at performance runtime 50b6d4d: **NOT RUN**. Eighteen bounded load samples over 200 seconds did not meet the original stability preflight; peak background container CPU was 280.07%. No timing samples were collected. This is preparation blockage, not a new measured regression or a performance PASS. No automatic rerun or adjusted threshold was used.

## Pipeline And Open Items

Historical v2.0.0/v2.0.1/v1.3.2 workflow failures came from dependencies installed under unignored vendor/bundle contaminating a checkout required to be clean. The 2.x workflow now keeps dependency/config paths outside the checkout and initializes them in a valid runner step. The existing source/tag/package/checksum guards remain. Actual future tag publication has not been exercised because publishing is forbidden in this task.

Existing v2.0.1 and v1.3.2 releases were recovered through the authorized local build/publish route under the owner's account, not github-actions. Their four asset digests match stored recovery evidence; the exact old shell command was not retained. See the SDK branch's script/release/README.md. No existing release or tag was edited.

Open: deferred credential-redaction blocker; a valid independent retiming window; remaining Ledger DOM/F18 checks and final-runtime live proof; final full CI collection. R02 and RP native HTML/PNG tradeoffs remain as explicitly authorized. The owner reviews next; this checkpoint does not authorize release.

## Evidence Index

- [Independent Ledger acceptance](2026-11-02-ledger-2.0.2-acceptance.md)
- [Original failed performance window](assets/QA202-9bf3356-20261102/quiet-090b-window-1/matched-plain-comparison.json)
- [Unexecuted performance-fix window](assets/QA202-50b6d4d-20261102/focused-window-2/end.json)
- [Deferred executable security probe](../../spec/acceptance/ledger_qa/sdk202/deferred_malformed_url_probe.rb)
- [Original failing security-test log](../../spec/acceptance/ledger_qa/sdk202/deferred_malformed_url_original_failure.log)
- [Standalone failing-probe log](../../spec/acceptance/ledger_qa/sdk202/deferred_malformed_url_probe_failure.log)
- [Exact copied user-trial manifest](assets/readability-2.0.2-user-trial/manifest.json)
- [API review](assets/readability-2.0.2-user-trial/reports/api-review/api-review.md)
- [UI review](assets/readability-2.0.2-user-trial/reports/ui-review/ui-review.md)
- [Visual review](assets/readability-2.0.2-user-trial/reports/visual-review/visual-review.md)
- [Post-recovery visual addendum](assets/readability-2.0.2-user-trial/reports/visual-review/post-recovery-review.md)

Copied reports preserve their original bytes and original absolute local links. Use the adjacent copied screenshot folders and manifests when browsing the QA branch on GitHub. No independent verdict was rewritten to produce a PASS.
