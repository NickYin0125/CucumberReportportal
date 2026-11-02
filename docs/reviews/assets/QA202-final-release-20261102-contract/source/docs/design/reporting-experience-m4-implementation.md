# M4 Delivery Reliability Contract

Status: M4-A/B/C/D ACCEPTED by Master on 2026-10-10 for Ruby 3.4.2 and native
Cucumber 10.2.0. Final full/seed runs are 507/0 each; independent GPT-6.1 Sol
installed-package evaluation is 50/50. Exact package, phase coverage, live
Launch 47 and browser evidence are recorded in
[final acceptance](reporting-experience-m4-acceptance.md).

Historical M4-B scoped checkpoint accepted by Master: 27 focused examples / 0 failures
on `/tmp/m4a-20261010-candidate.ncJi25`, manifest SHA-256
`7e69364b977b73f0a64ca0d80892ac81a3f8599c22313eebd1f0265a137f250f`.
Master audited 100 library/spec entries against the workspace with no mismatch.
This permits M4-C implementation, not final M4/full/live acceptance.

## Invariants

- Keep the official UI topology: Feature SUITE/hasStats=true, Scenario
  STEP/hasStats=true, execution/hook children hasStats=false. CI owns shared
  Launch completion; the test framework owns recording/finalizing video.
- Admission is not delivery. Preserve the existing Boolean DSL and local-drain
  compatibility methods; expose separate immutable reporting receipts.
- Keep M4-A record, accounted-memory, wire-byte and control-waiter limits on
  every path, including shutdown and replay. No whole-run outcome/record cache.
- Never claim exactly-once log delivery: a lost response or crash after server
  acceptance but before a checkpoint creates an explicitly ambiguous outcome.
- Preserve original launch/item UUID, timestamp and attempt ownership. Never
  redirect delayed or replayed evidence to whichever item happens to be active.
- Diagnostics are bounded and sanitized; credentials, raw payloads and local
  paths are not emitted by default. Spool contains sensitive evidence and must
  be protected locally. Existing unrelated dependency/duration edits are out
  of scope and must remain unchanged/uncommitted. A narrow replay-executable
  packaging addition to the gemspec is allowed separately; its existing four
  unrelated development-dependency additions must not enter the M4 commit.

## M4-B: Completion Barrier And Receipts

Provide a monotonic accepted sequence at commit, a cutoff barrier captured at
call time, and immutable receipts identifying cutoff, settled/confirmed,
spooled, failed, ambiguous and pending counts. A later producer must not extend
an earlier barrier. Rejected admissions remain separately visible and prevent
a whole-run report-complete assertion. Receipts must distinguish local
settlement, server acknowledgement and reporting completeness.

Inspect official v1 response shapes: singleton `{id: ...}` and ordered batch
`{responses: [{id: ...}, {message: ..., stackTrace: ...}]}`. Only explicit
success IDs acknowledge entries. Missing/malformed/short responses are
ambiguous; do not silently promote HTTP 2xx to all-record confirmation. Do not
resend confirmed siblings after partial success. V2 acceptance is not proof of
eventual persistence and must be labelled accordingly.

Use one monotonic shutdown/finalization deadline shared by capture closure,
barrier wait, transport/retry/backoff, item/launch finish and worker shutdown.
Do not multiply the timeout per item or join. A timed-out operation must return
within a small scheduling tolerance and report unconfirmed work, not perform
unbounded synchronous fallback I/O. Reporting warnings must not change the
business test result by default; strict reporting mode remains explicit.

Tests B01-B08: continuous later admission; partial success; malformed/short
responses; timeout and zero-timeout; repeated shutdown; retry budget; original
failure preservation; bounded receipt bookkeeping/control waiters.

## M4-C: Durable Spool And Controlled Replay

Replace best-effort spool with versioned transactions: private staging
directory, evidence copies with byte length/SHA-256, metadata/checkpoint,
flush/fsync then atomic same-filesystem publication. Only complete published
transactions are replayable; interrupted staging must not look committed.
Use a cross-process lock, configurable finite disk quota, and bounded streaming
copies (growth cannot bypass quota). Disk-full/quota failures are explicit;
no bypass to an unlimited /tmp fallback. Retain legacy sensitive-diagnostic
redaction assertions, adding stronger tests rather than weakening them.

Default spool quota: 256 MiB (`RP_SPOOL_MAX_BYTES`), a strict positive decimal
integer. Published transactions, attachments, staging residue and checkpoints
all count toward the quota. Use directory mode 0700 and evidence/manifest mode
0600; never include auth configuration in a transaction. Reject symlinked roots
or evidence. Copy in bounded chunks, verify copied bytes, and fsync the commit
and parent directory where the host filesystem supports it. A failed copy must
retain an explicit unavailable-artifact marker rather than fake successful
empty evidence. Do not automatically delete user evidence to create space.

Implement controlled opt-in replay (dry-run by default) with an exclusive
transaction lock, validated schema and safe relative paths, symlink/traversal
rejection, attachment checksums and bounded metadata/record sizes. Keep original
UUIDs/timestamps. Persist per-entry confirmations atomically before continuing;
do not replay acknowledged entries. Replaying uncertain entries requires an
explicit allow-duplicates decision. Endpoint/project binding must prevent
accidental cross-environment replay. Expired/missing/closed RP targets must
produce useful failure rather than silently recreate a tree. No credentials
are stored in manifests. Provide a usable standalone executable and README.

Tests C01-C09: atomic publication/crash residue; disk quota including concurrent
writers; disk full; attachment growth/missing/corruption; path/symlink attacks;
checkpoint resume; ambiguous confirmation window; endpoint/project mismatch;
installed-package CLI dry-run/execute and original ownership.

Independent QA's operator-recovery gate also requires bounded, actionable
diagnostics: identify invalid limit options without echoing their values,
distinguish a missing published artifact from altered bytes, and expose locally
known unavailable-artifact counts with the fixed `source_unavailable` reason
during dry-run. Inspection remains credentialless and HTTP-free; exit 0 means
inspection succeeded, not that every artifact is replayable. Missing published
blobs or checksum failures remain hard refusals, and execution must never invent
empty replacement evidence.

`RP_FAIL_ON_REPORTING_ERROR` retains its exception-based compatibility scope;
it is not a policy that fails every incomplete reporting receipt. A log-only
background delivery failure can leave the business process successful while
the receipt is incomplete. Consumers enforcing full reporting completeness must
inspect that receipt explicitly. Preserve the original business exception.

### Store / Replay Interface

`Service::SpoolStore.new(config:)` owns persistence, validation and quota.
`persist(entries:, files:, outcome:, diagnostics: {}, deadline: nil)` returns a
transaction ID only after complete publication, otherwise raises a bounded
safe error. `transactions` lists only versioned published IDs.
`load_transaction(id:)` returns validated `manifest`, `checkpoint`, `entries`
and path-backed `files` plus the private transaction `directory`.
`with_transaction(id:, deadline: nil) { |transaction| ... }` holds an exclusive
replay lock and validates before yielding. `update_checkpoint(id:, states:,
deadline: nil)` atomically updates the per-entry states. Checkpoint states are
objects with `state` (pending, in_flight, confirmed, ambiguous or failed) and
an optional acknowledged `id`; in_flight on restart means uncertain.

Separate the short global quota lock from the transaction replay lock: do not
hold the global writer lock across network calls. Atomic checkpoint replacement
must account for old plus temporary new bytes and stop on failed persistence;
durable pre-send in_flight is required before each POST. A published attachment
manifest includes safe relative path, logical filename, MIME, length and SHA-256.
Missing artifacts have explicit unavailable metadata and cannot be replayed as
empty successful files. Writer and reader share the same finite schema, entry
and metadata limits; never publish a transaction the reader cannot validate.

The CLI is `reportportal-spool`: `--spool-dir DIR --transaction ID` defaults
to dry-run; `--execute` opts into sending and `--allow-duplicates` opts into
uncertain-entry replay for that selected transaction. Dry-run needs no RP
credential and performs no HTTP operation. Exit 0 means the requested inspection
or synchronous confirmations completed; exit 2 means retained/refused/incomplete
work; invalid CLI syntax exits 1. Execution uses one HTTP attempt per entry and
an overall `--timeout SECONDS` budget, validates original endpoint/project, and
checks the original UUID targets through the unified HTTP client. Closed or
missing targets are refused without recreating the tree. Legacy unversioned
NDJSON is retained but not automatically imported or replayed.

## M4-D: Fault Matrix And Real RP Reconciliation

Use deterministic local fault injection for slow responses, offline/408/429/
502/504, 400/401/403, mixed acknowledgements, interrupted shutdown and disk
failure. Exercise public Cucumber and installed-package entry points, not only
private methods. Full M4, M2/M3 and security regression runs require source and
runtime provenance and retained failure receipts.

Against the existing local Kubernetes ReportPortal, run a small uniquely named
launch containing passing and failing scenarios, Markdown table/JSON evidence,
an attachment, and a controlled spooled/replayed record when supported by the
server. Reconcile exact admitted identifiers/counts, item ancestry and artifact
bytes via API, then inspect the same run in the browser. Do not reuse old live
evidence or label mock results as live. If services/credentials are unavailable,
document the actual blocker and do not issue a final acceptance/tag.

Tests D01-D06: deterministic fault matrix; public business/report-result split;
full/seed regression; installed consumer; live API ownership reconciliation;
browser evidence on that exact launch.

## Final Independent Gate

An independent GPT-6.1 Sol tester evaluates the packaged SDK from a QA user's
perspective: discoverability, usable configuration, incomplete-report warnings,
safe replay and meaningful failures. Luna implements/tests fixes; Master reviews
the final diff and evidence. Re-run affected gates and full regression after
feedback. Commit only validated M4 scope, then create annotated `m4` on that
commit, preserving all unrelated dirty files.

Official response reference:
[Reporting developers guide](https://reportportal.io/docs/developers-guides/ReportingDevelopersGuide/).
