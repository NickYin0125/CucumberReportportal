# M4-B Completion Barriers And Receipts

Status: IMPLEMENTED IN WORKSPACE; focused clean-candidate execution passed.
Master source acceptance and the full regression suite remain pending. This is
not M4-C spool acceptance, live RP certification, or a release claim.

## Public Contract

`QueueProcessor` and `Runtime::LogBuffer` expose:

| Method | Meaning |
| --- | --- |
| `flush(timeout:)` | Compatibility Boolean: accepted records through its call-time cutoff locally settled. |
| `shutdown(timeout:)` | Compatibility Boolean with the same local-settlement meaning; zero timeout does not synchronously spool. |
| `flush_receipt(timeout:, deadline: nil)` | Frozen bounded cumulative receipt through the accepted-sequence cutoff captured on entry. |
| `shutdown_receipt(timeout:, deadline: nil)` | Receipt plus worker close/join using one monotonic budget. |
| `reporting_receipt(...)` | Whole-run snapshot; `complete` stays false until finalization finished and all required conditions hold. |

`Formatter` exposes receipt methods for consumers. Existing Boolean methods are
not redefined as remote delivery success. A receipt has only scalar fields:

| Field | Definition |
| --- | --- |
| `cutoff` | Highest accepted monotonically assigned sequence at barrier call time. |
| `settled` | Entries through this cutoff for which local processing ended. |
| `confirmed` | Entries with an explicit v1 log ID acknowledgement. |
| `accepted_awaiting_persistence` | Explicit async/v2 IDs; acceptance is not persistence proof. |
| `spooled` | Entries copied to best-effort local fallback; can overlap `ambiguous`. |
| `failed` | Explicit per-entry server failure or local wire-size rejection. |
| `ambiguous` | Missing/malformed response, transport uncertainty, or lost response. Can also be spooled. |
| `possible_duplicates` | Successful acknowledgement after one or more transport retries; an earlier attempt may have been accepted before its response was lost. |
| `pending` | Cutoff entries not yet locally settled when this immutable snapshot was made. |
| `rejected` | Whole-run admission rejections (including closed-queue rejection). |
| `capture_close_timeouts` | Evidence capture target closure timeouts. |
| `metadata_failures` | Reporting start/finish API failures observed by the formatter. |
| `degraded_evidence` | Video-upload fallback to plaintext rather than an uploaded video link. |
| `local_settled` | No cutoff entries pending at snapshot time and the barrier did not time out. |
| `complete` | Whole-run assertion; requires completed finalization, no pending logs, all entries v1-confirmed, and zero rejection/failure/degradation counts. |
| `timed_out` | The bounded barrier did not locally settle before its budget. |

The queue retains cumulative finite counters, the next accepted sequence, and a
bounded number of active cutoff requests (`MAX_CONTROL_REQUESTS`). Each active
request holds only scalar counters and its queue waiter. It is removed when it
settles or times out. No payload or per-entry outcome map survives local queue
settlement. Receipt values and their `to_h` snapshots are frozen. Cutoff
receipts snapshot the cumulative rejection counter at the moment of the call;
rejections are not assigned accepted sequences and cannot extend a barrier.
`reporting_receipt.rejected` is the final whole-run cumulative value.

## Response Parsing And Retry Ownership

The official v1 response contract is a singleton `{ "id": ... }` or an ordered
batch `{ "responses": [...] }`; batch success objects have an ID, while failure
objects have a message and may have a stack trace. An ID is the only success
signal. Singleton multipart responses are parsed from `responses`, not guessed
from the request entry count. Short arrays retain only unambiguous known
positions and mark missing positions ambiguous; extra elements invalidate
alignment and make all entries ambiguous. Malformed shapes are ambiguous.
Confirmed siblings are never resent after partial success. Only failed and
ambiguous entries are sent to local best-effort spool, annotated with
`deliveryOutcome` for M4-C schema evolution.

The HTTP client is the sole retry owner for log requests. Its configured retry
attempts/backoff share an optional monotonic `ReportingDeadline`; the queue
does not add a second retry loop. A successful retry carries non-wire
`may_duplicate` metadata through `API::LogBatchResult`, incrementing
`possible_duplicates`; the logs are still confirmed by their returned IDs, but
the whole report cannot be called complete. An exhausted lost response remains
ambiguous even when a local spool copy succeeds. Async/v2 IDs increment
`accepted_awaiting_persistence`, not `confirmed`.

## Finalization Budget And Business Result

Formatter finalization creates one monotonic deadline and spends its remaining
time on capture closure, log barriers, log HTTP retry/backoff, item and launch
finish requests, shutdown barrier, and worker join. The queue clears a deadline
after its cutoff settles, so an ordinary deadline-bearing flush cannot poison
subsequent work. Zero timeout captures a cutoff and closes admission promptly,
does not join or synchronously spool, and returns pending counts. Reporting
failures remain warnings by default; only the existing explicit strict setting
can raise through the business execution path.

`reporting_receipt.complete` remains false until finalization itself has
finished. It is also false for any admission rejection, capture-close timeout,
metadata start/finish failure, unconfirmed/ambiguous/spooled log, async
acceptance awaiting persistence, possible duplicate, or degraded MinIO
evidence. Strict reporting failures after a business result is already failed
are logged without replacing that original failed result; explicit strict mode
can still fail a business-passing run when reporting itself fails. No receipt
claims exactly-once delivery or eventual persistence.

Public Cucumber consumer example. Capture the runtime while Cucumber is active;
inspect the final receipt after normal formatter shutdown. `at_exit` is
best-effort on interruption because handler ordering can precede formatter
shutdown:

```ruby
reporter = nil
Before { reporter ||= ReportportalCucumber.current_runtime }
at_exit do
  receipt = reporter&.reporting_receipt
  warn("ReportPortal report incomplete: #{receipt.to_h}") if receipt && !receipt.complete
  # Preserve the business result; reporting completeness is separate.
end
```

`ReportPortal::API#log_batch_result` calls public `#log_batch` and returns a
frozen `LogBatchResult(body:, may_duplicate:)`. This preserves wrappers,
instrumentation, and spies on the historical public method while carrying
successful-retry uncertainty in Ruby metadata, never as a wire field.

## Test Coverage

Queue-specific M4-B cases live in
`spec/reportportal_cucumber/service/queue_processor_m4b_spec.rb`; tester-owned
formatter integration and transport deadline coverage is in separate M4-B
spec files. Focused execution evidence is recorded separately in
[`reporting-experience-m4b-verification.md`](reporting-experience-m4b-verification.md).
The successful-retry duplicate-risk queue case exercises the result metadata
seam; it does not simulate a real HTTP server accepting a request before losing
its response. Wire-level lost-response proof remains a later transport gate.

Official response-shape reference: [ReportPortal Reporting developers guide](https://reportportal.io/docs/developers-guides/ReportingDevelopersGuide/).
