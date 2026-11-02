# M4-A Bounded Delivery Pipeline

Status: IMPLEMENTED; Master accepted the scoped local/mock gates on READY3.
No live RP certification, full M4 completion, release or tag is implied.
Base: annotated `m3`, commit `c9eacad5f1320e84f9660a413ef307d39f48d2de`.
Branch: `codex/reporting-experience-m4`.

## Scope And Boundaries

Bound SDK-owned pending/in-flight log records and request bodies, including
normal interval flush, explicit flush and shutdown. Preserve FIFO order,
message/artifact content, original item/launch/attempt ownership, official
multipart alignment, M2/M3 behavior and scoped diagnostic sanitization.
No new runtime dependency is needed.

The caller owns browser capture, recording finalization and stable artifact
paths. CI/CD owns shared-Launch completion. M4-A does not implement joined-run
coordination, M4-B cutoff receipts/global deadlines, M4-C atomic/quota spool or
replay, M4-D live fault certification, or fix unrelated M3 usability findings.
The dirty duration features and four dependency/profile/task manifests remain
untouched and excluded from clean acceptance snapshots.

## Configuration Contract

| Ruby/YAML key | Environment | Default | Meaning |
| --- | --- | ---: | --- |
| `queue_max_records` | `RP_QUEUE_MAX_RECORDS` | 1000 | All reserved/pending/in-flight records, not just records waiting for the worker |
| `queue_max_bytes` | `RP_QUEUE_MAX_BYTES` | 16777216 | Accounted resident message/attachment/metadata bytes, including a fixed per-record overhead |
| `batch_size_logs` | existing `RP_BATCH_SIZE_LOGS` | 20 | Maximum log entries per request, also during flush/shutdown |
| `batch_max_bytes` | `RP_BATCH_MAX_BYTES` | 8388608 | Complete JSON or multipart request body, including envelopes and binary parts |
| `queue_overflow_policy` | `RP_QUEUE_OVERFLOW_POLICY` | `reject_new` | `reject_new` or `block`, never silently evict accepted records |
| `queue_admission_timeout_ms` | `RP_QUEUE_ADMISSION_TIMEOUT_MS` | 100 | Maximum admission wait for `block`; expiry rejects with diagnostics |

New limits must be strictly positive integers and policy values must be valid;
invalid input raises a generic configuration error without echoing values.
Configuration precedence remains defaults -> YAML/profile -> environment ->
explicit overrides. Existing valid configuration remains compatible.

## Structural Contract

1. Admission checks and capacity reservations are atomic. Capacity is not freed
   merely by moving a record into the worker. Reject known oversized strings
   or byte attachments before SDK copies/normalization. Accepted supported
   values use detached snapshots so caller mutation cannot defeat accounting;
   never freeze or mutate the caller's input. Non-path streams need bounded
   handling or an explicit rejection, not an unbounded read during admission.
2. File-backed attachments keep paths and use bounded previews/streaming. Disk
   file content is not resident queue memory: count path metadata for admission,
   then count stat/file bytes for wire limits. Revalidate during body construction
   so file growth cannot bypass the transport cap. Callers keep paths stable
   until local drain; checksums and durable attachment copies belong to M4-C.
3. `emit_log` returns true only for accepted records, false for rejection. This
   is admission, not a ReportPortal acknowledgement. Return false on closed or
   dead workers rather than retaining inaccessible records. Propagate partial
   evidence-admission failure without retargeting it or replacing a test error.
4. Diagnostics expose immutable, thread-safe counters and current/peak accounted
   occupancy. Rejections have finite reason keys, generic warnings and bounded
   warning frequency; never print log bodies, filenames, URLs or credentials.
   Default reporting failure is fail-safe; explicit fail-on-reporting policy may
   opt into a reporting error. Callbacks execute outside the queue lock.
5. Work units always obey entry count. Split oversized multi-record payloads into
   FIFO sub-batches; never split/truncate one logical log or silently strip its
   attachment. An individually oversized wire record is not sent or retried;
   use the existing best-effort failure spool plus explicit diagnostics. This
   does not certify atomic persistence, disk quota, successful replay or exactly
   once delivery.
6. Pure/shared sizing covers actual JSON serialization, UTF-8 byte lengths,
   escaped headers, boundary framing and path/byte attachment sizes. The common
   HTTP transport also checks actual bodies before any network call, including
   file-growth races. `MultipartHelper.log_batch_bytes(entries:, files:)` is the
   Queue/Transport interface; the RP boundary has fixed length 30.
7. Flush/shutdown use the same bounded work units, never an all-remaining mega
   batch. Keep existing local-drain semantics; do not acknowledge merely the
   first of several chunks. Remove timed-out flush waiters and bound retained
   control requests. Cutoff-based barriers, full report receipts and one unified
   whole-run timeout budget are explicitly M4-B, not claimed here.

The resident-byte accounting is a defined budget, not a byte-exact Ruby RSS
measurement. Caller/native Cucumber allocations, encoder copies, HTTP/S3 and
Ruby VM overhead are separate; test SDK saturation and RSS plateau empirically.
Default overload rejection is intentionally lossy and observable, not zero-loss.
Use `block` for a bounded wait or increase limits deliberately; durable overflow
policies require the later M4-C design.

## Acceptance Cases

| Case | Required observation |
| --- | --- |
| A01 Configuration | Defaults, YAML/profile/env/override precedence; malformed/zero/negative/unknown policy rejected generically |
| A02 Record pressure | Blocked backend + many producers never exceeds reserved/pending/in-flight count cap |
| A03 Byte pressure | Mixed UTF-8/messages/byte files obey accounted-byte cap; inflight remains charged |
| A04 Ownership | Accepted values detached, inputs mutable; original item/launch/attempt, levels, timestamps and bytes retained |
| A05 Overflow | Fast rejection and finite reason/warning counters; block resumes when capacity really releases or times out |
| A06 Normal batching | Count and actual complete body bytes <= configured caps, including mixed MIME and escaped metadata |
| A07 Shutdown | More than three batches drain in FIFO, each bounded; flush does not return after only the first |
| A08 Oversized record | No oversized HTTP call, no local-size retry, no implicit trimming; failure/spool diagnostic explicit |
| A09 Streaming race | No full read for path admission/sizing; file growth stops bounded construction and tempfiles close |
| A10 Fault lifecycle | Dead worker, callback exception and repeated timed-out flushes retain no unbounded queue/control work |
| A11 Public integration | Actual Cucumber/API multipart capture verifies body lengths, Step/attempt attribution and partial admission failure |
| A12 Regression | Clean M3-based full/seed RSpec, M2/M3+security gates, supported-lane qualification and normal installed-gem consumer |

## Ownership And Evidence

Master owns this contract, integration review and final acceptance. Luna queue
and transport implementers have disjoint production write sets; a Luna Tester
owns specs/fixtures and execution evidence. No agent may change protected
duration files, create descendants, operate infrastructure, commit, tag or push.
Freeze a clean candidate from the M3 tree plus permitted overlays before final
gates; record runtime/source identities, actual exits/counts and rejected records.
Retain failed runs and disclose any compatibility adapter. Verification and
Master review records will distinguish local/mock evidence from later live RP
certification; M4-A completion is not M4 or GA completion.

Final local evidence is in [verification](reporting-experience-m4a-verification.md)
and [Master review](reporting-experience-m4a-review.md). READY3's frozen candidate
is `/tmp/m4a-20261010-candidate.FPuOJy`; its full and seeded suites have 322
examples / 0 failures, with the admission-cancellation regression included.
