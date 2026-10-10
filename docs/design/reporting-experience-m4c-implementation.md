# M4-C Durable Spool Store

Status: IMPLEMENTATION IN PROGRESS. This document describes the C-owned store
and its integration points; it is not a test or release acceptance claim.

## Public Store Surface

`ReportportalCucumber::Service::SpoolStore.new(config:)` uses the configured
spool directory and finite `spool_max_bytes` quota. Its public methods are:

- `persist(entries:, files:, outcome:, diagnostics: {}, deadline: nil)` returns
  a transaction ID only after the versioned directory and atomic publication
  marker are durable. Safe bounded `SpoolStore::Error` reasons describe refusal.
- `transactions` returns frozen IDs whose marker, transaction directory,
  manifest, checkpoint, entries digest, and attachment metadata validate.
- `load_transaction(id:)` returns a frozen hash with `manifest`, `checkpoint`,
  canonical RP-wire `entries`, path-backed `files`, `id`, and private
  transaction `directory`. Internal spool diagnostics are not wire entries.
- `with_transaction(id:, deadline: nil) { |transaction| ... }` holds an
  exclusive transaction lock and supplies that validated snapshot.
- `update_checkpoint(id:, states:, deadline: nil)` atomically replaces the
  complete per-entry checkpoint. Confirmed acknowledgement IDs cannot regress
  or change. Checkpoints are bound to transaction ID and entries SHA-256.

Each attachment file descriptor has a logical `name`, `mime`, validated
absolute `path` when present, and `entry_index`. Unavailable attachments remain
visible with `unavailable: true` and a safe reason; they are not replayable
empty files. Wire entries contain only launch/item UUID, original timestamp,
message, level, and optional filename.

## Durability And Limits

The default quota is 268435456 bytes (`RP_SPOOL_MAX_BYTES`), configured as a
strict positive decimal integer. A cross-process quota lock covers bounded
stream writes, publication, and checkpoint replacement. Usage includes staging,
published files, attachments, and old-plus-temporary checkpoint bytes. Payload
copies are limited to 64 KiB chunks. Transaction directories are mode 0700 and
files mode 0600. Entries, manifests, checkpoints, and attachment copies are
fsynced before publication; a hard-linked root `*.ndjson` compatibility marker
is created last and is the commit marker. Staging without a marker remains
quota-charged but is not listed as a transaction.

An expired deadline refuses further writes and may leave non-replayable staging
residue, which remains charged. Ordinary queue persistence uses the configured
finite reporting timeout when no caller deadline exists. There is no temporary
directory quota bypass. A missing/unreadable source file is committed only as
an explicit unavailable marker; changed, unsafe, quota-exceeding, or failed
publication evidence does not count as durably spooled.

Initial definite failures are `pending`; initial ambiguous delivery is
`ambiguous`. Replay must durably mark `in_flight` before its one HTTP attempt.
After restart, `in_flight` becomes `ambiguous`; only an explicit duplicate
consent policy may replay it. Store persistence does not itself send or replay
logs and does not promise exactly-once delivery.

The queue uses this store for ordinary and raw diagnostic fallback records.
Raw fallback is reserved for payload-builder failure and uses the same quota,
transaction validation, and publication path. Store failures do not trigger a
second persistence location. Fatal worker settlement spools only its remaining
unsettled work, then releases the complete originally charged batch.

Formatter finalization emits one bounded `reporting=incomplete` warning when
the final whole-run receipt is incomplete. The warning includes business
passed/failed and receipt counts only; it excludes payloads, paths, and auth
data, and logger failure cannot replace the business result. `RP_ENABLED=false`
suppresses this reporting warning.

## Deliberate Boundaries

This store does not manage replay consent, target eligibility, endpoint/project
matching at execution time, CLI behavior, or server reconciliation. Replay
implementation and installed-consumer testing are separate work. Admission
before atomic publication is not a durability guarantee against SIGKILL.
