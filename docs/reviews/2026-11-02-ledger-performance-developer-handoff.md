# Ledger Performance Optimization Handoff

Final handback: the [blocked addendum](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/2026-11-02-ledger-final-blocked-addendum.md) supersedes the execution plan. Window 2 collected no timings; the separate offline security probe at 50b exited 1. QA files are frozen for Master. The earlier corpus, failed window and scope-limited results below remain preserved.

## Owner Disposition

Owner authorized a separate developer optimization and new independent acceptance after the first G11 stop. The independent tester will not implement the SDK fix. Redaction, full frames, original raw bytes, statuses, ownership and log counts must not be weakened. Nothing from the failed window is waived or overwritten. No independent benchmark rerun until a new candidate SHA and explicit Master authorization.

Current acceptance: **27 captured-corpus criteria PASS, 4 PENDING, G11 FAIL**. Full report: `docs/reviews/2026-11-02-ledger-2.0.2-acceptance.md`. Machine ledger: `docs/reviews/assets/QA202-9bf3356-20261102/offline-review/checks.json` (1,307 checks; 2,438-file inventory). The original check file SHA-256 is `19bc83706a044baaa383f40ed3b90595d4fe029074276aee9302ffcbf7d4aa25`.

Latest owner disposition supersedes the broad campaign plan below: **overall G8 is BLOCKED** by the separately reported malformed-URL local redaction probe. No security fix is authorized; the release remains NOT ACCEPTED even if performance later passes. No RP exposure is claimed. Preserve the distinct failing, nonzero QA probe apart from passing reuse-policy units. See `offline-review/security-blocker-addendum.json` under the evidence root. Ledger has not rerun that probe.

Proceed only with the authorized performance-only optimization. Focused retiming comes first after a new immutable committed head and explicit quiet-window handoff; skip the full new 139-Launch campaign while the global gate is blocked. The behavior oracle is **090b for every recorded case**, requiring exact message/backtrace/file-value and ownership preservation; **3f20313 remains only the historical performance comparator**. No formatting, redaction or raw-byte difference is waived by the optimization authorization. The four pending visual criteria and F18 remain unresolved.

## Exact Performance Inputs

QA root: `/Users/nick/Documents/crr-qa-2.0.2`.

| Input | Location or identity |
| --- | --- |
| Accepted historical source | `3f20313c20b25071fbc49b31e1c6bc772bd599e4` |
| Failed candidate | `090b633842f5b24d46a244f854daf95c9477b9ca` |
| Frozen raw corpus | `docs/reviews/assets/ledger-2.0.2-preparation/failure-corpus.json` |
| Corpus identity | `a99b8d138ce4b63d63b531698bf33ffcb0b0ca263136ac20517e4c72a1bd1d4f` |
| Historical acceptance and harness provenance | `docs/reviews/assets/ledger-2.0.2-preparation/baseline.json` |
| Every original sample and receipt | `docs/reviews/assets/QA202-9bf3356-20261102/quiet-090b-window-1/` |
| Per-input summary, no new execution | `docs/reviews/assets/QA202-9bf3356-20261102/offline-review/per-input-performance.json` |
| Frozen timing helper copies and hashes | `docs/reviews/assets/QA202-9bf3356-20261102/offline-review/window1-harness/` and `handoff-manifest.json` |
| Immutable source exports | `/private/tmp/ledger-qa202-9bf3356/baseline` and `/private/tmp/ledger-qa202-9bf3356/final-090b6338` |
| Immutable image | `sha256:316dd4f6b6de632d5ade7bdb78fc33f7e82db8a87785e93a8a2c8d81706d3fe7` |
| Read-only dependency volume | `ledger-qa202-9bf3356-dependencies` |
| Dependency manifest SHA-256 | `3a015e3a12387b249ede5ebd6cdb5b638eb916c95c036ff4755cefb081e1536b` |

The 21 inputs are F04 (1), F14-negative (14), F15-negative (1), F16a/b/d/e/f (5). Preserve each recorded class/message/frame tuple and its input ID. Do not replace the corpus with only the slow cases or the separate 62-frame golden replay. The corpus includes synthetic security probes, never production credentials.

Both arms used Ruby 3.4.12, Cucumber 12.0.1, cucumber-core 20.0.0, expressions 20.1.0 and exactly matching activated dependency versions. Docker was network-disabled, one CPU, 2 GiB. No RP credential was forwarded. The historical probe's mutable image tag is not proof of image identity; fresh matched arms use the pinned image above.

## Measurement and Profiling Logistics

The historical renderer boundary is `FailureCard.format` with arguments captured from an actual `Formatter#emit_error_log` call. The full boundary calls that formatter method, including error extraction, redaction and rendering, ending in a no-op log sink; it excludes network transport. Each input has 10 warmups and 50 measurements per boundary. P95 is nearest rank `ceil(0.95*n)-1`, pooled over 1,050 observations per mode/boundary. Each raw array contains successive 50-sample blocks in corpus order.

Plain renderer p95: 1.002333 to 0.868958 ms. Plain full-path p95: **6.055875 to 10.137500 ms (+67.40%)**. The timer stopped after 11.988506 seconds, at 20:23:24 CST. No rich, F07, or remaining Presentation measurements followed. The redaction/full path, not the renderer alone, is the diagnostic area; this is not yet a root-cause attribution.

Existing-sample ranking points first to corpus indices 12 and 13 (zero-based, F14-negative): candidate per-input full-path p95 12.3760 and 12.2632 ms, versus baseline 6.8009 and 7.4780 ms. These are diagnostic slices, not separate acceptance thresholds or a substitute corpus. Input IDs and all slices are in `per-input-performance.json`.

Developer profiling, when dispatched by Master, belongs in a separate developer output directory, never this QA window. Follow `Formatter#emit_error_log`, `FailureRedactor#redact`, and the underlying `EvidenceRedactor` calls, including cross-unit credential detection. Keep any profiler overhead out of acceptance samples. Use real raw tuples, not hand-sanitized renderer arguments. Preserve fallback behavior and cross-boundary credential protection, not merely the six displayed-message cases.

The first-window command was `/opt/homebrew/opt/ruby@3.4/bin/ruby spec/acceptance/ledger_qa/sdk202/quiet.rb --master-quiet-approved`. **Do not rerun it**: it is pinned to 090b/window-1 and refuses existing output. New acceptance needs a new SHA-bound export, a new exclusive output folder/receipt, and a fresh quiet-window authorization. Retain the original helper copies unchanged. The container command line, activation proofs and all raw stdout/stderr are in the first-window `*-process.json` files.

Independent retiming will compare accepted 3f20313 and the new candidate in both plain/rich modes at both boundaries. Either comparable p95 over +10% means STOP AND ASK again. If those gates pass, complete F07 median-of-three (+10%) and all Presentation p95 (<2 ms), including the preserved F01-F18 and parallel observation harness. No post-hoc discard, weighting change, same-candidate tune/retry, or replacement of the failed window.

## Explicit Remaining Acceptance

| Criterion | Required proof and existing anchors |
| --- | --- |
| P1.6 | Literal script/b exception-title DOM, not API escaping alone. Existing plain 3898 logs 21504/21513 and rich 3927 logs 21589/21598. |
| P10.8 | Expand long body/preview folds and save direct `details > pre > code` DOM. HTTP 3981 has long bodies; 3918/log 21545 already has saved expanded-header proof. F18 long attachment/DocString plain/rich pair is the named missing fixture for the new candidate. |
| P10.10 | Complete S06 media (3882/3911), S08 numeric tables (3896/3925), and assertion/evidence S09 (3884/3913 and 3895/3924). Existing S01/S02/S03 and HTTP S09 are retained. ERROR/FATAL must remain plain under Decision 27. |
| P10.11 | Save computed amber 404 and red 500 WARN colors from 3981 (logs 21711/21715), plus blue media from 3911. Only green 201 was persisted before the disk outage. No fabricated ERROR/FATAL pill requirement. |
| G11 | Failed first gate remains FAIL. Retest only a new candidate; rich/F07/all-Presentation gates remain unexecuted. |

The new optimization changes runtime, so old 090b captures cannot automatically certify its behavior. Master will authorize fresh acceptance coverage. Recheck the six redaction cases, cross-unit secrets, every full tail, 53 ERROR/FATAL mode pairs, attachment bytes, native records and ownership, including R02's retained After scope. R02 remains not fixed; native failure-PNG routing is only the explicit WP2 exception. No other reviewers' reports were used for this handoff.
