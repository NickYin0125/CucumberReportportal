# SDK 2.0.2 Independent Final Performance QA

Formal result: **NOT RUN**. Release-performance acceptance is not granted.

Candidate: `8f44c10533eb4d0a8eae1adcc2ed5b63ace155c7`.
Accepted comparison baseline: `3f20313c20b25071fbc49b31e1c6bc772bd599e4`.
No SDK edit, merge, tag, release or push is authorized or performed by this reviewer.

## Final Observation

The single authorized V4 attempt stopped at the original container quiet gate,
before any benchmark or F07 execution. The immutable preflight contains 18
samples from **2026-11-02 15:00:18 through 15:03:41 UTC**. No retry occurred,
no service was paused/stopped, and no threshold was relaxed.

| Condition | Required | Observed |
| --- | --- | --- |
| Total background-container CPU | <=35% for 3 consecutive samples | 28.37%-100.69%; only 6/18 <=35%, all isolated; longest qualifying streak 1 |
| Three-sample CPU spread | <=15 percentage points | No eligible triple; final three 34.33%, 50.59%, 29.70%, spread 20.89 points |
| Container allowlist | Only original RP and Typewords containers | PASS: only `rp2607-control-plane` and `typewords-local-typewords-1`; no unexpected containers |
| Host load | Diagnostic only, never a stop condition | 1-minute load 17.84-29.07 on 8 CPUs |

RP container CPU ranged 28.37%-100.68%; Typewords ranged 0%-12.02%.
These observations establish failure of the original preflight, not a measured
SDK performance regression. There is no timing-start file and there are **zero
benchmark samples**. No favorable rounds were selected because none started.

| Requested Measurement | Result | Unchanged Limit |
| --- | --- | --- |
| Frozen21 renderer-only, plain/rich, two rounds | NOT RUN | Each matched p95 <= baseline x 1.10; candidate p95 <2 ms |
| Frozen21 full formatter, plain/rich, two rounds | NOT RUN | Each matched p95 <= baseline x 1.10 |
| F07 wall-time medians | NOT RUN | Median of 3 rotated runs <= baseline x 1.10 |
| F01-F18 Presentation replay including F06 | NOT RUN | Every observed entry-point p95 <2 ms in each mode |
| Supplementary encoded-URL absolute costs | NOT RUN | Diagnostic only; no blocking speed threshold |

Evidence: [raw 18 load samples](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-final-release-20261102-performance/exclusive-v4-20261102T145902Z/settling.json),
[immutable window result](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-final-release-20261102-performance/exclusive-v4-20261102T145902Z/result.json),
[final machine-readable summary](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-final-release-20261102-performance/final-result-v4.json).
The summary records every required result as NOT RUN with null timing metrics,
all source/image/dependency/corpus hashes, and the authorization/harness bindings.

Post-stop verification reconfirmed unchanged frozen source, harness, corpus,
image and all 2,356 dependency files. The SDK remained clean at the final SHA.
See [post-stop proof](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-final-release-20261102-performance/post-stop-proof-v4.json).
The quiet window has ended. Performance acceptance is not granted; any later
isolated attempt requires separate explicit authorization and new evidence paths.
This failed preflight must remain immutable.

## Authorized V4 Window

Master explicitly authorized one exclusive window after all live/browser work
finished and committed to stop local builds/scans/Git packs until this result.
The authorization was recorded at 2026-11-02 14:59:02 UTC in
`master-authorization-v4.json`. V4 binds that receipt to a frozen harness manifest
before timing. No benchmark or F07 execution had started at this proof checkpoint.
Harness tests use doubles and a synthetic clock; untimed actual-SDK validation
is not performance evidence. The completed preflight observations are above.

Preparation is ready: source/corpus/dependency checks passed. The SDK worktree
was independently observed clean at the candidate SHA. Actual untimed validation
passed for all 21 frozen inputs and three supplementary URL inputs on both
baseline and candidate, in both plain and rich. Every recorded resolved/passed
mode matches the request; all sample arrays are empty. Harness tests passed:
12 tests, 59 assertions, zero failures/errors/skips. Earlier preparation records
remain intact; `readiness-v4.json` and `harness-manifest-v4.json` identify the
authorized harness. Root execution files must also match that manifest.

## Required Gates

- Frozen21: renderer-only and formatter redaction-plus-rendering p95, separately
  in actual plain and rich modes, against the accepted baseline. Each matched
  comparison stops on a regression greater than +10%; renderer p95 must be <2 ms.
- Keep the original 21 inputs, their order and weighting, with 10 warmups and
  50 samples per input per boundary per arm. Use two counterbalanced rounds;
  each round must pass independently, with no favorable-round selection.
- F07: 50 real rapid steps, logs and PNGs; rotate baseline/plain, candidate/plain
  and candidate/rich order over three repetitions. Each candidate median must
  stay within +10% of baseline.
- Original G11: F01-F18 actual Presentation-call replay, including four-worker
  F06, must remain <2 ms p95 for every observed entry point in each mode.
  Retain the original runner's explicit unsupported F16c record; do not invent
  a replacement failure or remove any frozen21 input.
- Encoded URL costs are supplementary, separately labelled and never substituted
  for frozen21. Report raw samples and absolute p95/median/maximum costs per arm,
  mode and boundary, without a relative-speed gate, <2 ms acceptance limit or
  supplementary PASS/FAIL speed verdict. Unsafe passthrough versus newly correct
  sanitization is not a matched-behavior regression comparison.

The exact normative sources are [acceptance section 4 G11](/Users/nick/Documents/crr-2.0.2/docs/design/presentation-ledger-acceptance.md:195)
(F07 median within +10%, and F01-F18 Presentation-call p95 <2 ms) and
[Owner Decision 25](/Users/nick/Documents/crr-2.0.2/docs/design/presentation-ledger-owner-decisions.md:347)
(same corpus/environment, separate matched renderer-only and inclusive formatter
boundaries, with the more-than-10% stop rule). Neither adds a speed gate to the
supplementary direct encoded-URL probes. The earlier v2 supplementary blocking
threshold was an incorrect scope addition and is removed before any timing;
its prepared source and validation records remain preserved, not silently edited.
Decision 25's Cucumber 9 comparison concerns the separate 1.x line;
this SDK-only 2.0.2 review uses its required Cucumber 12.0.1, not an incompatible
1.x runtime. No 1.x result is certified here.

## Conditions And Evidence

Image: `sha256:316dd4f6b6de632d5ade7bdb78fc33f7e82db8a87785e93a8a2c8d81706d3fe7`;
Linux arm64, Ruby 3.4.12, Cucumber 12.0.1. Dependency volume:
`ledger-qa202-9bf3356-dependencies`, read-only, 2,356 files, manifest SHA-256
`3a015e3a12387b249ede5ebd6cdb5b638eb916c95c036ff4755cefb081e1536b`.
Every execution uses `--network none --cpus 1 --memory 2g`; no credentials are
forwarded. Frozen source snapshots mount read-only and are checked against
Git blobs before and after execution. Staged legacy fixtures write only inside
this reviewer's new evidence directory, not the shared fixture tree.

Baseline runtime/gemspec source manifest SHA-256:
`c751cd9304e8e88016948a1c9948dd36a8975472f16044172c49bf855f9e0382`
(47 files). Candidate manifest SHA-256:
`23dca543c9e679c7a06874c2e6935430929da3947af502cb71edc75fc919777e`
(48 files). Both snapshots were verified against each frozen Git blob.

Frozen corpus file SHA-256:
`d8b2f24a9d531d9114e02ed960ad50618a42c98d8fdfb22308be7ff285421177`.
Ordered input/weight SHA-256:
`a99b8d138ce4b63d63b531698bf33ffcb0b0ca263136ac20517e4c72a1bd1d4f`.
Historical source blobs are verified without using other reviewers' conclusions
or Master's diagnostic performance numbers as the verdict.

The original container quiet criterion is three consecutive eligible samples
<=35% total container CPU, spread <=15 percentage points, with only the two
originally permitted background containers. This remains unchanged.

The separate 1-minute host load <= host CPU count comparison came from the later
third-party `focused_window3.rb` preflight, not original G11/Decision 25 or the
original container criterion. V3 had retained it as an additional execution gate.
Before any timing, Master explicitly clarified: "Host-load<=CPU from later
third-party preflight is NOT a normative owner gate; record it separately as a
diagnostic, not a new release criterion". Accordingly V4 records host load and
the <=CPU comparison as diagnostics only; neither gates execution nor release.
This is an explicit authorized clarification, not a silent condition relaxation.
Master disclosed recent host load approximately 17 on 8 CPUs; actual values are
retained around the run. V3's stricter prepared condition remains preserved in
its original records. Up to 18 settling
attempts are separated by 10 seconds. Load is checked around each execution;
unstable/incomplete evidence yields NOT RUN, never PASS. No automatic retry or
overwrite of an existing window is allowed.

The original SDK202 harness uses `Config.new("rp.presentation" => mode)`, which
does not resolve rich mode. It remains untouched as historical evidence. The new
`release_perf_*` harness uses `Config.new(presentation: mode)` and asserts both
the resolved Config mode and actual FailureCard argument for every frozen input.

Evidence destination:
`docs/reviews/assets/QA202-final-release-20261102-performance/`.
Preparation manifests, actual-mode validation, authorization, conditions, raw
samples, per-input proofs and formal results belong there. Required timing
results remain NOT RUN until independently executed in an authorized stable
window. Earlier failed records are preserved and are not superseded by a green
claim in this report.

All owned files are intentionally uncommitted for Master's serialized secret
scan and staging. [owned-files-final-v4.json](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-final-release-20261102-performance/owned-files-final-v4.json)
is the final exact absolute-path inventory, including frozen source snapshots,
all preserved preparation revisions and the immutable V4 preflight. Earlier
inventories and preflight-readiness summaries remain historical. V4 readiness,
the completed window result and `final-result-v4.json` supersede them without
overwriting them. No shared Git index, commit, or push operation was performed.
