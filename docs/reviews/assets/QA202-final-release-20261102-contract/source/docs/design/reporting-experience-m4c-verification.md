# M4-C Aggregate Acceptance

Status: M4-C ACCEPTED as part of the final coherent M4 candidate. This document
is maintained by Master; earlier scoped gates below are historical, not the
final release identity.

## Final Combined Gate

Candidate `/tmp/m4-20261010-candidate.30uRDE`, manifest SHA-256
`49607259f627ca6818c37e863ed4bc55a38ab271102a62818cd605135b8c2357`,
includes the Store, Replay, queue integration, installed executable and only
the two approved gemspec packaging additions. Full and seeded runs each
executed 507 examples with zero failures; focused M4 plus replay API/CLI ran
211/0, historical security 89/0, and the actual installed HTTP consumer passed.

Independent GPT-6.1 Sol evaluated the same gem (SHA-256
`20a537c3cf708c0bf37191a3759fc962f2b9ce5b64c39c259c95a3ae31e0552e`):
50/50 named checks passed, including real Store attachment replay, duplicate
and reserved logical names, safe symlink refusal, concurrent quota, resume,
actionable refusals and unavailable-artifact inspection. Six findings were
fixed by Luna and independently reverified. Final live Launch 47 confirms
original ownership and PNG bytes; Master inspected the same logs in the UI.
See [final acceptance](reporting-experience-m4-acceptance.md) and the
[independent review](reporting-experience-m4-independent-review.md).

## Recorded Gates

- Persistence/core candidate `/tmp/m4a-20261010-candidate.ZKjhM0`:
  101 examples, 0 failures, including M4-A/B, store, replay service/API,
  historical spool security and formatter exception preservation.
  Manifest SHA-256:
  `d504ba2c807796f87b4cffb2275079edbc83b12b5b8e9abedf6580334aa1016e`.
- Earlier replay candidate `/tmp/m4-20261010-candidate-replay-final`:
  31 examples, 0 failures, including the executable integration tests.
  Manifest SHA-256:
  `d9b9768cfae26afb4d921b693cf091576fd77e3e4c61021127175158f7d58f67`.

These two receipts are not a single coherent release result. The first omits
the executable; the second predates the final queue integration. The final
tester must export one candidate containing all library, specification,
executable and approved gemspec packaging changes, then rerun the combined
gate and installed consumer. Collection-only results do not count as execution.

See the [persistence verification](reporting-experience-m4c-persistence-verification.md)
and [replay verification](reporting-experience-m4c-replay-verification.md)
for exact commands, failures retained during development and source identity.

## Review Contract

The store publishes only complete private transactions, charges staging and
old-plus-temporary checkpoint bytes to a finite cross-process quota, validates
attachment length/SHA-256 and rejects unsafe paths. Replay preserves original
UUIDs/timestamps, checkpoints in-flight before sending, skips confirmations,
requires explicit consent for uncertainty and refuses closed/missing targets.
Completed transactions can resume without HTTP even after their targets close.

No exactly-once, SIGKILL zero-loss, global memory or universal release claim is
made. The final M4-D/API/browser/independent gates above supersede the historical
pending state of the earlier scoped candidates.
