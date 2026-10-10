# Reporting Experience M4-A Verification

## Current Status: READY3 Tester Pass; Master Audit Confirmed

The A10 producer-cancellation regression that failed on READY2 now passes on READY3. All tester acceptance gates below ran against the new candidate `/tmp/m4a-20261010-candidate.FPuOJy`, whose Queue SHA is `2dcab49acbf02993fde1801485b5bd169373eb2ea71991b9668a2e65a662eece`. Cucumber 10 and adapted Cucumber 9 full/seed/security gates, the focused 36-case suite, the installed-gem consumer, and pressure harness passed. Master independently audited the source manifest and receipts and confirmed the results recorded here. The failed READY2 reproductions and intermediate candidates are preserved separately.

The A10 case terminates a producer during snapshot preparation via `Thread.kill`, and also verifies `SystemExit` and a business `RuntimeError` propagate. Every noncommitted path leaves zero reserved records/bytes and zero accepted records; shutdown succeeds and the worker stops. This is a queue-lifecycle invariant, not a whole-process crash-durability claim. No SDK source was changed by the tester.

## Acceptance Snapshot

The final tester snapshot is the fresh, immutable M3-based candidate at `/tmp/m4a-20261010-candidate.FPuOJy`. It was exported from base commit `c9eacad5f1320e84f9660a413ef307d39f48d2de` with only `lib/`, `spec/`, and README overlays. Its source manifest is `/tmp/m4a-20261010-candidate.FPuOJy/tmp/m4a-20261010/candidate-source-manifest.json` (SHA-256 `46d7834a6911b62afc3005272777723d36a3d15b545f0aabc27da2d7f27c73c8`). It records 30 library files and 95 source/README entries. Every library file was hash-compared with the workspace and manifest before execution.

Frozen source identities:

| File | SHA-256 |
| --- | --- |
| `lib/reportportal_cucumber/service/queue_processor.rb` | `2dcab49acbf02993fde1801485b5bd169373eb2ea71991b9668a2e65a662eece` |
| `lib/reportportal_cucumber.rb` | `52b7c8fe46838f734602a54e4ba1c90b921198202565d42068e16fd6339407bd` |
| `spec/reportportal_cucumber/cucumber/m2_evidence_spec.rb` | `0a78a1da835321eb259857a6871e9c8674565e73c3ccb9160201fe3dcbd54cc3` |
| `spec/reportportal_cucumber/cucumber/security_regression_spec.rb` | `d9c42de690c465ff14347ca645240fadd9457e711f435d411eeebf4f4c0e7e7a` |
| `spec/reportportal_cucumber/service/queue_processor_m4a_spec.rb` | `1504b71946135b46f1faef78eea448fdad7e25e2ea38351ce0266ebd77f3f85e` |

Root `Gemfile.lock`, `Rakefile`, `cucumber.yml`, gemspec, and duration-workload files were not overlaid into the candidate; the protected root edits remain outside acceptance. No SDK production file was changed for this verification. Previous candidates and their receipts, including `candidate.jahZ6L`, remain preserved and are not used as acceptance evidence.

## Gates And Runtime

| Gate | Result | Receipt |
| --- | --- | --- |
| Candidate runtime/source and Bundler check | exit 0; Ruby 3.4.2, Bundler 2.6.6, Cucumber 10.2.0; candidate entrypoint/hash verified | `tmp/m4a-20261010/final-gates/runtime.log`, `bundle-check.exit` |
| A10 producer cancellation regression | 1 example, 0 failures; exit 0 | `tmp/m4a-20261010/A10-producer-cancel/ready3.log`, `ready3.exit` |
| Focused A01-A11 suite | 36 examples, 0 failures; exit 0 | `tmp/m4a-20261010/focused36.log`, `focused36.exit` |
| Full RSpec, Cucumber 10 lane | 322 examples, 0 failures; exit 0 | `tmp/m4a-20261010/final-gates/full10.log`, `full10.exit` |
| Seeded full RSpec (`20261010`) | 322 examples, 0 failures; exit 0 | `tmp/m4a-20261010/final-gates/seed10.log`, `seed10.exit` |
| Historical M2/M3 scope | 220 examples, 0 failures; exit 0 | `tmp/m4a-20261010/final-gates/m2m3-10.log`, `m2m3-10.exit` |
| Historical SECURITY 7-file baseline | 89 examples, 0 failures; exit 0 | `tmp/m4a-20261010/final-gates/security-baseline-10.log`, `security-baseline-10.exit` |
| Explicitly approved security fault-injection cases | 2 examples, 0 failures; exit 0 | `tmp/m4a-20261010/security-fault-injection-READY3/run.log`, `run.exit` |

The final Cucumber 9.2.1/Core 13.0.3 adapted lane, on the same candidate source, passed full 322/0, seeded 322/0, SECURITY 89/0, and focused 36/0. Runtime and child receipts are under `tmp/m4a-20261010/adapted9-ready3/`. Child-audit JSON and exit receipts for full, seed, security, and focused are all green. Full and seed each audited 31 Cucumber children plus two mapped standalone helpers; security audited six Cucumber children plus one standalone helper; focused audited two Cucumber children. No child lacked a receipt, loaded the wrong Cucumber/Core version, or used a different candidate formatter hash. The adapter reuses the verified historical `acceptance/bin/env` behavior for only the standalone `env -u RUBYOPT ...` child commands. Its helper-loaded-file receipts confirm those standalone helpers did not require Cucumber or cucumber-core.

Native Cucumber 9 loads as version 9.2.1, but native no-shim RSpec collection exits 1 with `LoadError: cannot load such file -- cucumber/core/events/test_step_started` (0 examples, 1 collection error). This is the existing Cucumber 9 event-loader compatibility gap; the adapted lane uses the require-only compatibility shim and records its provenance. Native no-shim receipts are `tmp/m4a-20261010/native9-rspec-no-shim/run.log` and `run.exit`; there is no `native9-no-shim/` directory in this candidate. The initial adapted audit attempts that failed solely because the audit compared `/tmp` and `/private/tmp` aliases are retained; the canonicalized re-audits above pass against the same child receipts.

The normally installed gem consumer ran Cucumber 10.2.0/Core 16.2.0 from the installed gem directory, not the source checkout. It verified all 30 packaged `lib/` hashes against the frozen manifest, delivered a plain JSON `rp_log` and a multipart `rp_attach`, and checked each log's `itemUuid` against its actual Gherkin action UUID. Captured request sizes were 179-byte JSON and 584-byte multipart; child exit 0. Evidence: `tmp/m4a-20261010/installed-consumer-READY3/consumer-provenance.json`, `installed-consumer-READY3-run.log`, and `installed-consumer-READY3.exit`.

The blocked-backend pressure run attempted 1,024 producer admissions in waves of 128 (not 1,024 simultaneous producers): 32 accepted, 992 rejected; peak occupancy was 32 records / 272,154 accounted bytes against limits of 32 / 1,048,576 bytes. Nine RSS samples ranged from 40,848 to 65,776 KiB (24,928 KiB span); the backend was then released and the queue drained in nine fake batches. This is one bounded local observation, not an RSS or VM-memory guarantee. Evidence: `tmp/m4a-20261010/blocked-pressure-READY3/run.log`, `run.exit`.

## A01-A12 Evidence And Limits

| Contract | Evidence |
| --- | --- |
| A01 Configuration | `config_m4a_spec.rb`: documented defaults and precedence; invalid decimal strings, floats, booleans, nil, malformed values, and policies rejected without echoing input. |
| A02 Record pressure | `queue_processor_m4a_spec.rb`: barrier-controlled blocked backend, concurrent producers, in-flight reservations, and count peak assertions; pressure run above. |
| A03 Byte pressure | Queue specs cover UTF-8, binary bytes, in-flight charges, and path metadata resident-byte accounting; pressure receipts capture byte peak. |
| A04 Ownership | Queue specs cover detached immutable admission snapshots, mutable caller inputs, concurrent growth without copying grown oversized content, and retained UUID/level/time/bytes. M2 ownership cases retain exact evidence count, cross-thread UUID isolation, and finish ordering. |
| A05 Overflow | Queue specs cover reject, block-until-real-capacity-release, finite timeout, reason counters, zero-timeout flush cleanup, and repeated sequential/concurrent timed-out flush waiters. |
| A06 Normal batching | Multipart specs compare exact UTF-8 JSON and mixed-MIME multipart body byte counts, escaped header data, and valid filenames; queue batching verifies bounded FIFO chunks. |
| A07 Shutdown | Queue specs require flush/shutdown to wait across more than three chunks, preserve FIFO, clean up successful idempotent shutdown, and bound timeout fallback spool chunks. |
| A08 Oversized records | Queue/multipart specs assert no HTTP request or retry for an individually oversized record, no trimming, and a bounded spool outcome. |
| A09 Streaming races | Multipart specs spy on `stat` and bounded read sizes, force growth after expected-length stat, and assert `Tempfile#close!` plus captured path removal. World tests cover path streaming, unsupported IO without reads, StringIO cursor preservation, and giant raw text without `expand_path`. |
| A10 Fault lifecycle | Queue specs cover worker death while API is blocked with retained best-effort spool, raising/reentrant callbacks, dead/closed rejection, bounded fatal/timeout spool work, and producer `Thread.kill`/`SystemExit`/business-error cancellation during snapshot preparation. The new cancellation regression passes with zero leaked ledger entries and successful worker quiescence. |
| A11 Public integration | Real Cucumber 10/9 children plus WebMock capture multipart/JSON bodies, actual named Gherkin action and attempt UUID ownership, and partial evidence rejection. Cucumber 10 public child recorded three requests and five logs; Cucumber 9 recorded two requests and four logs. Oversized artifacts were rejected and were not among multipart file parts; the Cucumber 9 extra `rejected_oversized` count is the core failure-event log, not an admitted artifact. |
| A12 Regression | Clean M3-based full and seeded suites, historical M2/M3 and seven-file security gates, adapted Cucumber 9 runtime audits, and a normally installed gem consumer all run against the single manifest-verified candidate. |

Two historical M2 batching assertions were changed with Master approval only: summary JSON and PNG multipart are independently checked before the owning step finish, and concurrent ownership parsing now accepts either singleton JSON or multipart JSON. Every captured log payload is parsed and asserted to be a Hash/Array; there is no parser-error rescue or dropped payload. Exact two evidence records, cross-thread UUID isolation, and finish order remain asserted.

Two historical `security_spool_spec.rb` fallback fault tests were changed with explicit approval only. Unstable `Object#to_s` injection was replaced by one targeted `PayloadBuilder.build_log_batch` fault triggered only after an actual transport failure. Both retain redaction/canary, size, raw-spool, natural-routing, actual-HTTP-attempt, and explicit single-fault-count assertions. The historical pre-fix red run is preserved separately at workspace root `tmp/m4a-20261010/security-fault-injection-red.log` (`2 examples, 2 failures`); it is not a READY3 candidate receipt. The READY3 green receipt is `tmp/m4a-20261010/security-fault-injection-READY3/run.log` and `run.exit`.

The missing-path raw-spool regression asserts the exact original long filename/message, valid item/launch UUID ownership, `missing: true`, `unavailable: true`, and no `spooledPath`. The neighboring `known-good.png` remains a normal non-raw file record under the same launch; the successful HTTP regression separately checks its exact PNG bytes. No fake empty attachment is treated as success.

All API/network results in this run are deterministic WebMock/fake-backend evidence. No live ReportPortal service/browser certification was attempted; that remains deferred to M4-D. Older preliminary/failed candidate receipts are retained for traceability and are not part of the final green results above.
