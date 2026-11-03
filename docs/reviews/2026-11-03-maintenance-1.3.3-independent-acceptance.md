# Independent 1.3.3 Selective Backport Acceptance

Historical progress/failure record, retained without relabeling earlier runs.
The final canonical execution and scoped ACCEPT for
`68e81d3697965305438be4fa27aa98aeb4baf726` are in
`2026-11-03-maintenance-1.3.3-final-acceptance.md`.

Status at this historical checkpoint: INCOMPLETE, NOT ACCEPTED. Latest executed Freeze 2:
`1a8db4fd4cdc59985ef49d71d254ba21997aeef1`; awaiting an approved test-only
standalone-isolation fix and new frozen identity. Prior blocked candidate
`b470799d3086a627f521a5755c50f6609064e3cb` remains NOT ACCEPTED. No SDK edits by tester.
No commits, pushes, tags, deployments, publication, new API keys or service stops.

## Freeze 2 Actual Results

Evidence: `assets/qa-1.3.3-candidate-20261103T111945Z-269e`.

| Cell | Full SDK RSpec | Pending | Offline Cucumber | Additional Checks |
| --- | --- | --- | --- | --- |
| M1 Ruby 3.1 / Cuke 9 | 1878, zero failures | 0 | 1 scenario / 3 passed steps | 9 release isolation + 88 independent, all pass |
| M2 Ruby 3.1 / Cuke 10 | 1878, zero failures | 0 | 1 scenario / 3 passed steps | 9 release isolation + 88 independent, all pass |
| M3 Ruby 3.3 / Cuke 9 | 1878, 3 isolation-spec failures | 0 | 1 scenario / 3 passed steps | 88 independent, all pass |
| M4 Ruby 3.3 / Cuke 10 | Master-requested abort before completion | Not claimed | Not claimed | Partial logs retained; not a completed full cell |

M3 is an **SDK standalone-spec isolation defect**, not an SDK helper/runtime
defect or Cucumber 12 contamination. Bundler 2.6.6 sets `BUNDLER_SETUP`, which
RubyGems 3.5.22 auto-requires at startup (`rubygems.rb:1397`). Three SDK specs'
explicit `env -u` lists omit that flag. Re-activation reads the tracked 1.x root
lock instead of the external cell lock. That root lock already contains Cucumber
10.2.0 / gherkin 39.0.0 / messages 32.2.0 / bigdecimal 4.0.1. `RUBYGEMS_GEMDEPS`
is unset, and the bare image environment does not contain old 2.x activation.
The independent diagnostic retains the exact failing child plus the same child
succeeding when only the bootstrap flag is removed.

The master approved D's three-line **test-only** `env -u BUNDLER_SETUP` fix.
No such SDK change was made by this tester. A proposed QA launcher workaround
was never integrated or used in a matrix and was removed; no test overlay or
monkeypatch is accepted. Full retries are held pending the actual frozen tests.

The original double-Bearer assertions are unchanged and all 88 independent
probes passed in M1/M2/M3 at Freeze 2. Prior red evidence is retained below.
Fresh RP launches, packaged consumer checks, DOM/F18 and paired performance
have not started; no Launch IDs are claimed.

## Historical Blocker (First Freeze)

### P1: Plaintext Double-Bearer Credentials Remain In Automatic Evidence

Confirmed on first freeze `b470799` by independent probes, not developer verdicts.
`EvidenceRedactor.redact_text("Authorization: Bearer Bearer SYNTHETIC_SECRET")`
returns `Authorization: [REDACTED] SYNTHETIC_SECRET`. The synthetic credential
also survives structured non-sensitive message values, HttpExchange error
summary/native/plain/rich output, EvidencePresenter diagnostics and failure
evidence. This violates the required stronger automatic-redaction channels.
It is separate from deliberately unchanged raw AppLog and Decision 19 failures.

Relevant SDK implementation: `lib/reportportal_cucumber/automation/evidence_redactor.rb`,
`BEARER_PATTERN` at line 16 and `redact_plain_segment` at lines 507-509.
The key/value replacement can consume only `Bearer Bearer` and leave the final
token; the subsequent single-Bearer regex no longer has a scheme to identify it.

Frozen proof: `assets/qa-1.3.3-candidate-20261103T110859Z-2a3d/M1/evidence/targeted.json`.
The independent 88-example suite has 85 passed, 3 failed, zero pending; the three
failures are duplicate manifestations of this one defect, including one
aggregate checking all eight automatic channels. Depth-boundary and preserved
raw-channel controls pass. This finding blocked the first freeze. Its unchanged
independent checks passed at Freeze 2; final acceptance still requires all gates
on the agreed frozen tests.

## Baseline And Evidence Classification

Baseline SHA: `19174a5ecaf1aa9fb65480f0a21d74ed65c89a8d`, frozen v1.3.2 sources
under `/private/tmp/ledger-release-verification-20261101-rQL8pk/source-1.3.2`.

Canonical targeted baseline:
`assets/qa-1.3.3-baseline-20261103T110602Z-3857/matrix.json`.
Each of four cells executed 46 independent probes: 21 passed, 25 expected
DELTA/SEC failures, zero pending, no out-of-example errors. All 14 preservation
invariants passed per cell. These are TARGETED controls, not full RSpec results.

| Cell | Actual Ruby | Cucumber | Expressions | diff-lcs | Targeted |
| --- | --- | --- | --- | --- | --- |
| M1 | 3.1.7p261 | 9.2.1 | 17.1.0 | 1.6.2 | 46 / 25 expected fail / 0 pending |
| M2 | 3.1.7p261 | 10.2.0 | 18.1.0 | 1.6.2 | 46 / 25 expected fail / 0 pending |
| M3 | 3.3.12 | 9.2.1 | 17.1.0 | 1.6.2 | 46 / 25 expected fail / 0 pending |
| M4 | 3.3.12 | 10.2.0 | 18.1.0 | 1.6.2 | 46 / 25 expected fail / 0 pending |

The original repository baseline lock instead has expressions 18.0.1 with
Cucumber 10.2.0; isolated resolution above deliberately preserves the supported
`<19` range. Exact full resolved locks and activated gems are retained per cell.

Preparatory attempts ending `110020Z-99ef`, `110053Z-c78e`, `110340Z-f06f`, and
`110454Z-fd51` are retained as superseded HARNESS DEVELOPMENT/SETUP, not aggregated
as acceptance runs. The first mode helper used an unsupported configuration key;
it was corrected to `presentation:` with an explicit mode assertion before the
canonical baseline. The older 889 minimum was corrected to 1519 before any full
candidate execution. No filtered SDK suite was called full.

The supplemental adversarial baseline `110731Z-e419` executed 87 probes with 61
expected failures and zero pending. Provisional source snapshots `110732Z-c234`
(87 probes, 2 failures) and `110818Z-886b` (88 probes, 3 failures after stronger
cross-channel aggregation) are PRE-FREEZE DIAGNOSTICS ONLY. They do not replace
the frozen proof or final runtime execution.

## Released 2.x Shared Risk

`assets/qa-1.3.3-depth-reference-2.0.2.json` verifies the redactor and key-policy
bytes equal protected `v2.0.2` / `29ce2a4b5d8ca6b8119de97a7e3ae967bc66ddef`.
The independent exact repro is safe at encoding depths 1-3 and leaks at 4-5
after six downstream decoding passes. No 2.x source/tag was changed. The older
1.3.2 control leaks at depths 1-5, retained in
`assets/qa-1.3.3-depth-baseline-1.3.2.json`.

The provisional and frozen 1.x boundary tests exercise encoded JSON keys,
fully encoded keys/values, path, query, fragment and malformed URL channels.
Remaining percent escapes after the three-inspection-pass budget are
intentionally withheld, including benign/already-masked over-depth inputs.
No extra decode passes or FailureRedactor activation are required.

## Frozen Gates And Master-Requested Stop

The four-cell driver evidence is in
`assets/qa-1.3.3-candidate-20261103T110859Z-2a3d`. After the frozen P1 proof, the
master requested stopping the failed-candidate matrix. The user did not pause
the task. The driver was stopped before
M2; only the isolated M1 full suite is allowed to finish. M2/M3/M4, live and
performance have NOT started. A new freeze is required. Unfiltered M1 discovery found
1828 examples across 134 files with zero pending. Its completed execution matched
1828 examples and per-file counts, with 8 failures and zero pending. All eight
failures are ancestry/recovery cases in the QA image missing `jq`; seven directly
report `jq: command not found`, and the expired-artifact case stops before the
same prerequisite permits the expected API stub call. This is a retained QA
ENVIRONMENT FAILURE, not a green SDK result or a proven SDK regression. The
runner now installs/checks jq in disposable full-test containers and records its
version and binary SHA256. No old-SHA rerun is authorized or started.
The runner requires >=1519 actual examples, identical discovery/execution
per-file counts, no exclusions/overlays and zero pending. Default offline
Cucumber on 1.x passed one scenario/three steps (all three passed), not the 2.x
profile. This one completed cell is not four-cell acceptance.

Fresh live RP, DOM/F18, installed-package checks and matched paired performance
are pending. Live fixture parsing was independently checked in Cucumber 9.2.1
and 10.2.0: five dry-run scenarios each, not real RP acceptance. No Launch IDs yet.
The fixture uses separate supported DocString and DataTable steps; compound
arguments and native global-hook names remain established 1.x N/A boundaries.

R02 remains NOT FIXED: passed After evidence may be hidden by passed-log filters.
No evidence ownership or Hook status change is accepted as a workaround.
Setup microbenchmarks are diagnostics only, not a quiet matched performance pass.

## Owned Files

Harness and exact commands: `qa/readability_1x/README.md` plus `run.rb`, `cell.rb`,
`targeted_spec.rb`, `adversarial_spec.rb`, `run_adversarial.rb`, `depth_probe.rb`,
`live.rb`, `live_cell.rb`, `live.feature`, `live_steps.rb`, `check_fixture.rb`,
`bench.rb`, and `compare_bench.rb`. This report and fresh `assets/qa-1.3.3-*`
logs/JSON/harness snapshots are owned QA evidence. `.gitignore` excludes nested
source clones, `.git` stores and candidate gems; these stay local runner state.
Only curated evidence, manifests and screenshots are eligible for a future QA
commit by the manager. No SDK source or generated dependency cache is included.
