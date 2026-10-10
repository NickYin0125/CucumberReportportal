# M4-A Master Review

Status: MASTER ACCEPTANCE PASS for the scoped M4-A local/mock gates on READY3.
Missing-artifact and asynchronous admission rollback repairs are included.
This is not a full M4, live ReportPortal or unconditional GA approval.
Base: `m3` (`c9eacad5f1320e84f9660a413ef307d39f48d2de`).
Branch: `codex/reporting-experience-m4`.

## Review Gates

| Boundary | Required result |
| --- | --- |
| Admission | Atomic reservations include preparation, pending and in-flight work; supported values are detached without mutating caller inputs |
| Public DSL | No unbounded non-path stream read before admission; rejection is fail-safe and observable |
| Resident memory | Record and accounted-byte peaks stay below caps under a blocked backend; file content is not resident queue memory |
| Wire format | Actual JSON/multipart length, entry count, filename alignment and UTF-8 byte sizes satisfy the same caps during normal flush and exit |
| File race | Growth after sizing cannot cause an oversized HTTP request or leave a multipart tempfile open |
| Control requests | Timed-out flush waiters are removed; callbacks cannot deadlock the queue; closed/dead workers reject writes |
| Regression | M2/M3 topology, attempt ownership, immutable evidence targets and scoped diagnostic security remain intact |
| Provenance | Final tests use a frozen M3-based snapshot without unrelated dirty dependency/duration edits; installed consumer uses the actual packaged gem |

## Findings Disposition

- The original queue had no capacity limit and flushed every remaining record
  as one exit batch. Both are implementation targets, not existing guarantees.
- The original World attachment adapter called an unbounded `read` before the
  queue saw the attachment. Queue-only stream checks are insufficient; the
  public adapter is included in the bounded-admission review.
- Multipart growth must be injected after its own stat check. A pre-grown file
  only proves preflight rejection, not bounded copy or tempfile cleanup.
- Legacy spool tests use a deferred arbitrary `to_s` failure. Supported-input
  snapshots may legitimately remove this mechanism, but any adapted test must
  still exercise the real fallback path and retain all privacy assertions.

The implementation now reserves capacity before bounded supported-value copies,
charges detached snapshots until local completion, rejects changed input, and
keeps all normal/exit/fatal spool work count-bounded. Zero-timeout control calls
do not register waiters. Controlled worker termination has outer cleanup; it is
not a SIGKILL durability claim. Partial evidence admission returns false without
moving evidence to another target. The two adapted security tests inject a real
spool-build failure after a transport failure, retaining the redaction checks.
These dispositions are source review results; their execution evidence is still
required for final acceptance.

The first frozen candidate produced 321 examples / 3 failures. Two historical
M2 assertions assumed a multi-entry exit request despite a one-entry limit;
their mechanics may change to parse singleton JSON and separate multipart while
retaining UUID/attempt/finish-order checks. The third failure is a real product
regression: raw fallback always copied a path, losing record metadata if that
file had disappeared. Repair must retain raw log metadata and explicitly mark
the missing attachment, never invent an empty successful attachment. All three
failures remain retained evidence; the first candidate is not accepted.

READY2 changes only `service/queue_processor.rb`, SHA-256
`67f191f1a81d7f4fc7d3393639ccbf4e893549858f8957efd42bef2a2dbde5de`.
Missing path or ENOENT/ENOTDIR races retain raw record metadata and mark the
attachment `missing: true, unavailable: true`; other copy failures mark it
unavailable. No successful `spooledPath` is emitted for a failed copy. This
preserves the reportable diagnostic, not the unavailable artifact bytes. The
other eight initial production/README hashes remain unchanged. Final tests
must run on a new candidate rather than overwrite the failed first receipts.

The subsequent A10 producer-cancellation case reproduced a second real P1:
termination during preparation skipped a StandardError-only rollback, leaving
one reservation with no published record and blocking worker quiescence.
READY3 uses ensure rollback for every uncommitted exit and brief atomic
bookkeeping regions; preparation and admission waits stay cancellable. Original
unexpected producer exceptions are not replaced. Only QueueProcessor changed,
now SHA-256 `2dcab49acbf02993fde1801485b5bd169373eb2ea71991b9668a2e65a662eece`.
Candidate `caSP4b`'s earlier green gates do not qualify this new source or waive
the retained A10 failure. Final acceptance requires a fresh READY3 candidate.

## Initial Frozen Production Identity

| File | SHA-256 |
| --- | --- |
| README.md | b7a46c8066e26777d9f891c40a0fb8f41df43c28226a2357e2554fc36c16c65f |
| config.rb | f4d507070043837e3f04defd890b6651b8e4d50db226c0fe9130ce21ddec212e |
| cucumber/formatter.rb | 69b3a05c75dac55ea0edf69e32d42ad9ad6c08b42d75a3e8e4227dee4ee62f4f |
| cucumber/world.rb | efd7257c4deac1ee7fb1de6de543cc9f7beeab27c92ddeab6c054d4f680ca171 |
| runtime/log_buffer.rb | d322fb0a78ff1524cf32e5d1fd6c916883d39db4d1abe4627b0c78ca945d28cd |
| service/queue_processor.rb | c3ede1a51d65df962c0565f47826b953f9ae1e3d80bfe62824f259551e92e2d2 |
| transport/multipart_helper.rb | 512ecb0ef472e4109cbaa28f41647db6e36fbbcb1e6d89e293b600d47b462c0c |
| transport/http_client.rb | d93430f4c6d820d8aa76d2412983b81da1beabf2ba3c6917b84742ee65d8bbc8 |
| reportportal/api.rb | 929739dc0e2bf7f05c3b9ee48820b4af8d61974ab9fa317a71fa68ca2c306895 |

## Explicit Non-Claims

Default `reject_new` can reject logs under overload. Boolean admission and local
drain are not server acknowledgements or report completeness receipts. Existing
failure spool is best-effort, not atomic/quota-controlled persistence or replay.
Unified completion deadlines and receipts are M4-B; durable spool is M4-C;
live ReportPortal fault/API/UI reconciliation is M4-D. No zero-loss, exactly-once,
full M4 completion, GA or live browser certification is implied by M4-A.
The accounted queue budget is not a process-wide memory sandbox: native event
parsing/preprocessing, HTML reporting, encoder/S3 buffers and Ruby VM overhead
are separate. Pressure evidence must identify the actual measured workload.
Known M3 F2/F5/F6/F8 P2 and F7 P3 findings are not repaired by this increment.

## Final Evidence

Master independently audited candidate `/tmp/m4a-20261010-candidate.FPuOJy`,
manifest SHA-256 `46d7834a6911b62afc3005272777723d36a3d15b545f0aabc27da2d7f27c73c8`.
All 95 manifest entries match both the workspace and execution copy (94
scoped source/README files plus the ignored `spec/.DS_Store`). All 30 installed library
files also match. The accepted Queue hash is READY3's `2dcab49...`; the other
eight production/README hashes match the initial identity table above.

| Actual gate | Result |
| --- | --- |
| Ruby/Bundler/native Cucumber | 3.4.2 / 2.6.6 / 10.2.0; source identity verified |
| Full and seeded Cucumber 10 suites | 322/0 each; exit 0 |
| Focused M4-A suite | 36/0; exit 0 |
| Historical M2/M3 scope | 220/0; exit 0 |
| Historical seven-file security scope | 89/0; exit 0 |
| Adapted Cucumber 9 full/seed/security/focus | 322/0, 322/0, 89/0, 36/0; child audits exit 0 |
| Installed Cucumber consumer | All 30 library hashes match; JSON 179 bytes and multipart 584 bytes; both action UUIDs match log ownership; exit 0 |
| Blocked-backend pressure | 1,024 attempts in 128-thread waves; 32 accepted, 992 rejected; peaks 32 records / 272,154 accounted bytes within 32 / 1,048,576 limits; exit 0 |

The native unadapted Cucumber 9 suite still has the pre-existing event-file
collection LoadError. Its green lane uses disclosed external test-loader and
standalone-environment adapters, not a product patch or native/unshimmed PASS.
Full/seed audits each confirm 31 actual Cucumber children plus two mapped
standalone helpers, with no source/version mismatch or helper Cucumber load.
The nine observed pressure RSS samples span 40,848-65,776 KiB; this is not a
global VM-memory guarantee. No live API/UI fault certification was performed.

The four protected root manifests retain their original pre-M4 hashes. Existing
duration work stays unmodified and excluded. The SDK, spec and package audits
were performed read-only by Master; actual implementation and testing were
performed by Luna. See [the verification record](reporting-experience-m4a-verification.md)
for receipts, failed attempts and A01-A12 mapping.

No same-scope demonstrated P1 remains after the two repaired regressions.
All known earlier M3 limitations and explicit M4-B/C/D boundaries remain open.
No commit, tag, push, live certification or release was performed or implied.
