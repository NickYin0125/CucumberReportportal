# SDK 2.0.2 Ledger Final Blocked Addendum

**Overall NOT ACCEPTED. G8 and release remain BLOCKED under the owner's explicit security-fix defer.** A future performance improvement cannot clear this blocker. No broad campaign, live capture, timing, SDK edit, commit or push occurred while preparing this addendum.

## Scope and Preserved Results

| Evidence scope | Disposition |
| --- | --- |
| Prior 9bf live captures, byte-bound to 090b | Historical **27 PASS / 4 PENDING / G11 FAIL**, unchanged; not acceptance of 50b or a later head |
| Prior captured-corpus G8 | PASS within those recorded inputs; not retroactively falsified by newly covered input |
| G11 window 1 at 090b | Preserved FAIL: full-path plain p95 6.055875 to 10.137500 ms, +67.40% |
| Focused window 2 at 50b | **NOT RUN / preparation blocked**. Eighteen load samples failed the stability gate; zero benchmark samples. Quiet released 20:50:05 CST |
| Deferred malformed-URL security coverage | **FAIL independently confirmed offline; overall G8 BLOCKED** |
| 50b or forthcoming test-only follow-up acceptance | Not established. No new live Launch IDs, successful retiming, or full runtime-stream equality claim |

The four presentation gaps remain P1.6, P10.8, P10.10 and P10.11; F18 long attachment/DocString coverage remains missing. They are neither completed nor waived. Master reports a test-only constructor-spy follow-up; its forthcoming commit is not independently bound here.

Window-2 records: [preflight end](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-50b6d4d-20261102/focused-window-2/end.json), [load samples](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-50b6d4d-20261102/focused-window-2/settling.json), [immutable source proof](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-50b6d4d-20261102/focused-window-2/source-proof.json).

## Standalone Security Confirmation

The supplied distinct failing probe was run unmodified against immutable source **50b6d4d1d3b6c61926a023fc96bf291878ab68b0**, in the pinned Ruby image with `--network none`, read-only source/probe mounts and no RP credentials. It exited **1**. This was a correctness observation, not a benchmark.

The valid message URL was redacted, but the synthetic credential marker in the malformed whitespace-bearing frame remained in both the `backtrace` and combined `baseline`. Shared-default and freshly injected redactor results were identical across every result field. The fixture matches the supplied restored failure and contains the malformed frame plus 62 safe frames. This confirms the deferred redaction gap, not a default-policy-reuse regression.

No network probe or RP traffic occurred; no actual RP marker exposure is claimed. The owner explicitly declined expanding the security fix and retained this as a release blocker. The standalone nonzero probe remains separate from passing policy-reuse units; its fixture and failing expectation were not altered.

- [Preserved executable probe](/Users/nick/Documents/crr-qa-2.0.2/spec/acceptance/ledger_qa/sdk202/deferred_malformed_url_probe.rb)
- [Preserved original failure before fixture replacement](/Users/nick/Documents/crr-qa-2.0.2/spec/acceptance/ledger_qa/sdk202/deferred_malformed_url_original_failure.log)
- [Supplied restored standalone failure log](/Users/nick/Documents/crr-qa-2.0.2/spec/acceptance/ledger_qa/sdk202/deferred_malformed_url_probe_failure.log)
- [Independent execution receipt and source hashes](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-50b6d4d-20261102/security-offline-proof/result.json)
- [Independent complete stdout](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-50b6d4d-20261102/security-offline-proof/stdout.json)
- [Independent nonzero-probe diagnostic](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-50b6d4d-20261102/security-offline-proof/stderr.log)

## Frozen Handoff

The [historical check ledger](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-9bf3356-20261102/offline-review/checks.json) remains SHA-256 `19bc83706a044baaa383f40ed3b90595d4fe029074276aee9302ffcbf7d4aa25`. All first-window timing files remain byte-identical to its inventory. Earlier assessment and security-handoff records are retained as historical records; this addendum supplies the later independent local confirmation.

The [freeze manifest](/Users/nick/Documents/crr-qa-2.0.2/docs/reviews/assets/QA202-50b6d4d-20261102/ledger-freeze-manifest.json) covers Ledger-owned new QA artifacts and the explicitly supplied probe/logs. It excludes Master's copied usability-review folders, which this assessor did not read. QA files are handed back for Master scan/commit/push; the independent assessor will make no further writes or executions unless work is explicitly reopened.
