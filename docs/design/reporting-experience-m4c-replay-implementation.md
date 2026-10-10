# M4-C Replay Implementation

Status: implementation and focused verification complete; scoped Master
acceptance and the tester-owned installed-gem consumer run remain outstanding.

## Scope

`Service::SpoolReplay` and `exe/reportportal-spool` consume the approved
`Service::SpoolStore` interface. They do not import legacy NDJSON, create or
finish ReportPortal items/launches, change configuration schemas, or modify
Store/queue ownership. The executable is packaged as a gem executable. The HTTP
client adds GET, and the API adds read-only v1 lookups for launch/item UUIDs.

## Replay Behavior

- `--transaction` is mandatory and selects exactly one published transaction;
  no implicit “latest” selection exists.
- Dry-run is the default (`--dry-run` is available for clarity). It validates
  the selected Store transaction and its checkpoint without credentials,
  API construction, target lookup, checkpoint changes, or HTTP. Its bounded
  summary reports whether the selected profile is configured for async v2.
- Execution requires `--execute`, finite endpoint/project binding equality,
  credentials, and a synchronous v1 configuration. Async v2 is refused because
  asynchronous acceptance does not prove persistence.
- Before any log POST, all entries, path-backed attachments, and per-entry wire
  size are validated. Original launch UUIDs, and item UUIDs when present, must
  resolve through `GET /api/v1/{project}/launch/uuid/{uuid}` and
  `GET /api/v1/{project}/item/uuid/{uuid}` with `IN_PROGRESS` status.
- A single-entry POST is preceded by a durable `in_flight` checkpoint and uses
  one HTTP attempt. Only a parsed v1 ID acknowledgement is checkpointed as
  confirmed. A failed acknowledgement checkpoint stops the run; restart sees
  the durable `in_flight` state as uncertain. The next entry is not sent until
  confirmation persistence succeeds.
- Confirmed entries are skipped. `in_flight` and `ambiguous` entries are
  refused unless `--allow-duplicates` is also supplied. Consent applies only
  to the explicitly selected transaction. Known `failed` entries remain
  eligible for a new attempt without duplicate consent; unknown checkpoint
  schemas are rejected by Store validation and never automatically resent.
- One monotonic `--timeout` budget is passed through lock, GET, POST, and
  checkpoint calls. The Store owns deadline-aware lock and durable checkpoint
  semantics; an unavailable pre-send checkpoint prevents the POST.
- Attachments stay path-backed. Replay matches the stored file by exact logical
  filename, checks the resolved path remains within the transaction directory,
  and passes that path to the multipart transport; it never reads an entire
  binary file into memory.
- Wire entries are reconstructed from the canonical log fields only; spool
  diagnostics and internal attachment metadata are never forwarded to RP.

## G1-G6 Review Decisions

G1: checkpoint replacement must reserve quota for old plus temporary new
checkpoint bytes. If durable confirmation cannot be written, stop before the
next entry; the previous durable `in_flight` marker remains the restart signal.
Global quota and temporary-file accounting are Store responsibilities.

G2: pre-send `in_flight` is durable. On restart it is treated as uncertain,
not pending. No automatic transport retry occurs, confirmed siblings are
skipped, and duplicate consent is a separate explicit option. Definite
HTTP 400/401/403 responses and explicit per-entry v1 rejections are checkpointed
as `failed`, not ambiguous, and can be retried without duplicate consent.

G3: the same monotonic deadline is passed to the transaction lock, lookup,
transport, and checkpoint operations. A timeout or persistence exception is
not summarized as confirmed. Store publication and on-disk residue accounting
remain Store responsibilities.

G4: replay is supported only while each original destination remains open.
Normally finalized targets are expected to be refused; there is no reopen,
retarget, or recreation fallback. The durable transaction remains available for
inspection and an operator can retain it, but this CLI cannot make closed
evidence replayable.

G5: receipt documentation distinguishes formatter `reporting_receipt` from
`Runtime::LogBuffer`/`Service::QueueProcessor` Boolean flush/shutdown and
receipt-returning barrier methods. The public consumer example captures the
formatter in a lexical variable during `Before`, before the runtime thread
context is cleared.

G6: the README documents the spool directory, decimal quota/default, dry-run,
explicit execution, selected-transaction duplicate consent, exits, async-v2
refusal, and legacy NDJSON disposition. It also shows a filesystem-only command
to discover candidate transaction IDs without printing entry contents. CLI
summaries are bounded and exclude credentials, payloads, and local file paths.

## Exit Semantics

Exit 0: dry-run inspection completed regardless of retained records, or
requested synchronous confirmations are durable and no retained entry remains.
Exit 2: execution has a transaction missing/refused, configuration does not
match, a target is closed/missing, or work remains pending/failed/ambiguous.
Exit 1: invalid CLI syntax/options. The CLI never changes the underlying
business test result.

## Verification

Focused specs cover dry-run no-I/O, durable pre-send ordering,
acknowledgement checkpointing, interrupted ambiguity, duplicate consent,
confirmed sibling skips, endpoint/project mismatch, closed targets, async-v2
refusal, official GET paths, and a subprocess dry-run backed by a real Store
transaction. The verification document records the focused results, real-Store
checkpoint/checksum smoke, package export, and remaining installed-gem harness
and broader Store acceptance.
