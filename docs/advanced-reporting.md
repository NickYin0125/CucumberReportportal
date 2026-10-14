# Advanced reporting

Use this reference after [getting started](getting-started.md),
[best practices](best-practices.md), and [CI setup](ci.md). It explains delivery
contracts and optional capabilities; none of these settings is required for the
minimal Scenario or ordinary PNG/JSON/text reporting.

## Report structure

| RP node | Wire type | `hasStats` | Purpose |
| --- | --- | --- | --- |
| Feature | `SUITE` | `true` | Business suite |
| Scenario / executed Examples row | `STEP` | `true` | One statistical test |
| Before / After Hook | `BEFORE_METHOD` / `AFTER_METHOD` | `false` | Hook evidence |
| Given / When / Then | `STEP` | `false` | Action evidence |
| `rp_step` manual group | `STEP` | `false` | Nested business action |

Scenario is deliberately a statistical `STEP`, not `TEST`. The previously
verified RP UI statistics drilldown selected statistical leaves with
`type=STEP&hasStats=true&hasChildren=false`; nonstatistical children carry evidence
without becoming additional tests. Background actions retain their `[Background]`
prefix. Gherkin DataTables/DocStrings become Markdown descriptions and rich Step
logs; every executed Examples row gets its own UUID. See the
[metadata contract](design/reporting-experience-m3a-implementation.md).

## Launch ownership and native run hooks

An ordinary process starts/finishes its own Launch. A worker supplied with
`RP_LAUNCH_UUID` writes to an existing CI-owned Launch, bypasses local file join,
and never starts/finishes that Launch. CI must collect every actual business exit
and final reporting receipt, handle deadlines/crashes/late workers, and finish the
shared Launch. See the [CI sequence](ci.md#parallel-workers-and-a-shared-launch).

Legacy `RP_CLIENT_JOIN=true` remains a compatibility opt-in for same-host files,
but is deprecated for production shared completion. Its primary can finish before
secondaries; a later worker can split into another Launch after the primary exits.
It is not a distributed barrier. Without an external UUID, the default
`RP_CLIENT_JOIN=false` gives each worker an independent Launch.

In native Cucumber 9/10, `BeforeAll` runs before formatter construction. If it
aborts, the formatter creates no Launch and does not fabricate a class-hook item.
A per-registry observer waits for genuine `AfterAll` before finalization. An
`AfterAll` error becomes a credential-sanitized Launch-level ERROR log while its
original exception retains precedence, including if reporting also fails.
Native run hooks are not `BEFORE_CLASS`/`AFTER_CLASS` test-step nodes.

This native observer uses Cucumber 9/10's private registry/configuration
association; later major versions need separate compatibility work. A complete
receipt never means the business run/teardown passed. Implementation and dated
checks: [M4-B contract](design/reporting-experience-m4b-implementation.md),
[M4-B verification](design/reporting-experience-m4b-verification.md).

## Bounded delivery and finalization

RP calls go through `ReportportalCucumber::Http::Client`; optional S3 uploads use
the AWS transport separately. Launch/item UUIDs are generated before creation and
reused on retries, reducing creation-duplication risk. Retried logs can still
duplicate when an earlier accepted response was lost.

`Runtime::LogBuffer` delegates to a background `Service::QueueProcessor`. Defaults
are 1,000 reserved records, 16 MiB accounted resident data (including 256 bytes
metadata per record), 20 records per batch, and 8 MiB for the **complete serialized
batch body**. Flushing occurs by count, bytes, or interval. Overflow rejects new
records by default and is observable in diagnostics/receipts; `block` opts into a
bounded admission wait (100 ms by default), not unlimited buffering.

Path-backed attachments keep their paths for streaming. `StringIO` uses its full
backing string without changing the cursor; arbitrary non-path IO is rejected
without reading it. Text/JSON path previews use bounded reads. Native AppLog
`file:` attachments still read the file into memory for Cucumber; choose
`rp_attach(path)` for a large RP-only file. Keep source artifacts available until
reporting settles. The default overload policy can lose evidence and is not a
zero-loss guarantee. `sent_batches` counts successful local API calls, not server
log receipts.

Finalization shares one monotonic `RP_EXIT_FLUSH_TIMEOUT_MS` budget (default
5 seconds) across the barrier, transport retries, action/capture closure, item
and Launch finishes, and worker join. It is not a fresh budget per item.
A zero-timeout programmatic shutdown returns immediately without synchronously
spooling outstanding work. See [configuration limits](configuration.md#batching-queue-and-finalization)
and the [queue contract](design/reporting-experience-m4a-implementation.md).

## Delivery receipts and completeness

The formatter's `reporting_receipt` returns an immutable `DeliveryReceipt`.
Retain the reporter while Cucumber is active and inspect/export it after normal
completion, as in the [CI receipt snippet](ci.md#retain-a-final-reporting-receipt).
The formatter does not expose `flush`, `shutdown`, `flush_receipt`, or
`shutdown_receipt`.

On `Runtime::LogBuffer` / `Service::QueueProcessor`, Boolean `flush`/`shutdown`
mean accepted work **locally settled** before return, not complete server delivery.
Their receipt-returning `flush_receipt(timeout:)` / `shutdown_receipt(timeout:)`
capture an accepted sequence cutoff; later producers do not extend it.

| Field | Meaning |
| --- | --- |
| `cutoff` | Accepted sequence through which the barrier/snapshot is accounted |
| `settled` | Records whose local processing settled |
| `confirmed` | Synchronous v1 confirmations |
| `accepted_awaiting_persistence` | v2 async acceptance; not confirmed persistence |
| `spooled` | Retained local evidence, not completed server delivery |
| `failed` | Failed records |
| `ambiguous` | Server acceptance is unknown; a local spool copy may also exist |
| `possible_duplicates` | A retry may have duplicated an earlier accepted attempt |
| `pending` | Accepted records not yet settled |
| `rejected` | Cumulative admission rejections; rejected records have no accepted sequence |
| `capture_close_timeouts` | Actions/evidence capture that did not close in budget |
| `metadata_failures` | Reporting configuration/start/finish failures |
| `degraded_evidence` | Evidence degraded, for example external video reduced to plaintext |
| `local_settled` | Local processing is settled, independently from confirmation |
| `timed_out` | The relevant barrier/finalization budget expired |
| `complete` | Whole reporting contract completed without unconfirmed/lost/degraded evidence or metadata failures |

Counts describe delivery outcomes; do not add all columns to infer a total since
ambiguity/duplication indicators can overlap other outcomes. Rejections are the
cumulative count at a flush/shutdown cutoff and the whole-run total in the final
formatter receipt. Counters/waiters are bounded; the receipt does not retain a
run-long payload/outcome map.

`complete=false` when accepted logs remain unconfirmed, an admission is rejected,
capture fails to close, reporting start/finish fails, or video degrades. A
successful log response after retry is marked `possible_duplicates`; even a
confirmed retry does not justify claiming completeness if duplication is possible.
`RP_REPORTING_ASYNC=true` selects `/api/v2`, whose acceptance is explicitly not
synchronous persistence confirmation.

`RP_FAIL_ON_REPORTING_ERROR=true` propagates synchronous reporting exceptions
when no original business error exists; a log-only background failure can still
leave a passing business exit with `complete=false`. For whole-report gating,
use the separate `RP_REQUIRE_COMPLETE_REPORTING=true` policy described in
[CI](ci.md#choose-the-reporting-policy). Requested reporting with missing endpoint,
project, or key is inert but incomplete (`metadata_failures=1`); explicit
`RP_ENABLED=false` bypasses that reporting requirement.

## Durable spool and controlled replay

Exhausted/uncertain delivery can be retained as private, versioned spool
transactions under `RP_SPOOL_DIR` (default `.reportportal-spool`), subject to the
256-MiB default quota. Existing unversioned NDJSON is inspectable but is not
automatically imported/replayed. Spool is durable local evidence, not server
confirmation; control access and retention as for other test artifacts.

Replay is **transaction-scoped and dry-run by default**. It validates the
selected transaction without credentials/network. Execution requires `--execute`,
the same endpoint/project, and still-open original Launch/item targets. It cannot
reopen/recreate targets. An interrupted `in_flight` record is uncertain;
`--allow-duplicates` explicitly permits possible duplicate delivery for that
transaction. Confirmed entries are never resent. Each entry has one replay HTTP
attempt; a lost response remains ambiguous. Async v2 replay is refused.

From **your automation project root**, with the installed SDK in its bundle,
list committed transaction marker IDs without printing payloads:

```sh
spool_dir="${RP_SPOOL_DIR:-.reportportal-spool}"
for marker in "$spool_dir"/tx-*.ndjson; do
  [ -f "$marker" ] || continue
  printf '%s\n' "${marker##*/}" | sed 's/\.ndjson$//'
done
```

Expected: zero or more `tx-...` candidate IDs. Candidate discovery is not
validation; select one actual ID for dry-run. From **the same project root**:

```sh
bundle exec reportportal-spool --spool-dir .reportportal-spool \
  --transaction TRANSACTION_ID --dry-run
```

Expected: exit `0` for a valid inspection, with no HTTP requests. Replace
`TRANSACTION_ID` with a listed ID. A valid dry-run can still describe unavailable
artifacts: `unavailable_artifacts` is bounded to `0..1000`, and reasons are `[]`
or `["source_unavailable"]`, including confirmed siblings. Such markers have no
replacement source bytes. Recover originals separately; the SDK never fabricates
them. A missing published blob/checksum mismatch is a hard error (exit `2`).

When you have verified the open targets and matching configuration, with
`RP_API_KEY` already injected, **from the same project root**:

```sh
RP_ENDPOINT=https://reportportal.example.com RP_PROJECT=your_project \
  bundle exec reportportal-spool --spool-dir .reportportal-spool \
  --transaction TRANSACTION_ID --execute --timeout 30
```

Expected: exit `0` only when requested confirmations were persisted; exit `2`
when delivery remains refused/pending/failed/ambiguous. CLI syntax errors exit
`1`. The timeout is seconds. Omit `--allow-duplicates` unless you deliberately
accept the specific uncertainty; dry-run does not make a closed target replayable.
Contracts: [persistence](design/reporting-experience-m4c-implementation.md),
[replay](design/reporting-experience-m4c-replay-implementation.md).

## Failure evidence and action ownership

Public World API:

```ruby
rp_capture_target
rp_evidence(action:, error:, url: nil, details: nil, artifacts: [], target: nil)
```

Capture the opaque target inside an open Gherkin Step/Hook/manual Step. It is nil
when reporting is disabled/unavailable or no action is open. Passing it explicitly
allows a helper to retain attribution while the original action remains open;
join helpers before returning from that action. Execution context is isolated
per runtime and thread/fiber. `Thread.current[:rp_context_stack]` and
`Thread.current[:reportportal_cucumber_context_state]` are diagnostic, read-only
snapshots of the most recently accessed context, not authoritative storage.
Modifying them is unsupported and does not change evidence ownership.

`rp_evidence` returns true when all admissions succeed; false covers unavailable
reporting, invalid/foreign/closed targets, rejection, or cancellation. Admission
is not server confirmation. Omitting `target:` chooses only the current open
action. A late call never falls back to a Scenario, Launch, later Step, or Hook.
An After screenshot must deliberately target its open After Hook.

Each artifact accepts `path:` or `bytes:`, plus optional `name:` and `mime:`.
Path-backed artifacts stream; in-memory bytes are limited to 1 MiB. A call accepts
at most 16 artifacts; larger batches are rejected, not truncated. Admissions share
one monotonic exit-timeout budget, and target closure cancels pending admission.
Publication does not hold the context lock while waiting for queue space;
closure/lock acquisition share finalization's budget. Some entries can already be
accepted before a later one fails, so false is not rollback. Closure timeouts and
rejections remain visible as incomplete reporting.

See [UI recipes](best-practices.md#choose-step-evidence-or-after-hook-evidence) for
Step/After capture, a single artifact route, and re-raising the original error.
The [M2 evidence contract](design/reporting-experience-m2-implementation.md)
documents implementation boundaries.

### Diagnostic privacy limits

Failure/assertion diagnostic text is credential-redacted before clipping. Inputs
over 64 KiB, malformed JSON-shaped diagnostics, and URLs that cannot be parsed
safely are replaced with a fixed omission marker. The bounded policy also covers
transport-error warning text and spool exception metadata. It does not sanitize
raw files/video, ordinary AppLog text/JSON, low-level `rp_log`, automatic
Step/manual-Step exception logs/backtraces, or native Cucumber failure payloads.
A safe `rp_evidence` diagnostic followed by re-raising the original error can
therefore still leave that error in separate failure channels. The sanitizer
does not mutate or suppress original failures.

Multipart transport preserves valid MIME/name associations and full attachment
bytes, including collision-safe filenames for image, JSON, text, PDF, and binary
files. Bounded previews are presentation aids, not a replacement for full
evidence review or a universal privacy filter.

### RP-only World helpers

Use these **inside Cucumber Steps/Hooks** when native HTML/messages are not
required; use AppLog/native `log`/`attach` for both report tracks:

```ruby
rp_log("Synthetic business checkpoint", level: :info)
rp_log("Synthetic business checkpoint", "INFO")
rp_attach("artifacts/failure.png", name: "failure.png", mime: "image/png")
rp_attach(JSON.generate({status: "rejected"}), name: "response.json",
          mime: "application/json", message: "Sanitized response")
rp_step("Prepare synthetic data") { rp_log("Data ready") }
```

`rp_log` supports keyword or positional levels and an `attachment:` Hash with
`name`, `bytes`, and `mime`. Optional console mirroring requires
`RP_CONSOLE_MIRROR=true`; `mirror: false` suppresses it for one call. `rp_attach`
accepts `mime:` or its `mime_type:` alias. A String that names an existing file is
treated as a path; otherwise it is treated as bytes. Retain path-backed files
until delivery settles. These helpers do not add native evidence or assert a
business outcome.

## Scenario identity, attributes, and links

Identity remains `legacy` by default. To deliberately pilot stable identities,
**from your automation project root**, with normal RP configuration injected:

```sh
mkdir -p artifacts
RP_IDENTITY_STRATEGY=stable_v1 RP_IDENTITY_ROOT="$PWD" \
  RP_IDENTITY_NAMESPACE="clearing-ci" \
  bundle exec cucumber --no-profile --publish-quiet --format progress \
  --format ReportPortal::Cucumber::Formatter --out artifacts/reportportal.out
```

Expected: Scenario wire IDs use stable-v1 identity generation. Keep namespace/root
policy consistent across workers sharing history. `RP_TEST_CASE_ID` (highest
priority) or explicit tags such as `@tms:` seed opaque
`rp:stable-v1:<digest>` `testCaseId` values; the raw seed is not the wire ID and
raw-TMS UI search is not guaranteed. Migration starts a separate history baseline;
it does not merge/rewrite/backfill server history. Review the
[identity migration contract](design/reporting-experience-m3b-implementation.md).

Business attributes are independently opt-in:
`RP_SCENARIO_ATTRIBUTES_ENABLED=true`. The default allowlist is
`component,team,owner,layer,priority,browser,tms`. Defaults accept a JSON object/list
in `RP_SCENARIO_ATTRIBUTES`; tags use `@key:value`. Feature → Rule → Scenario →
executed Examples scopes inherit values; a later scope overrides an earlier one.
Conflicts for a key within one scope are ignored for that scope. Attributes apply
to Scenario items only. `tms` comes solely from the effective explicit ID,
not from independently reselecting inherited tags or configured `tms` defaults.
See [attribute usage](../examples/m3c_attributes/README.md) and its
[contract](design/reporting-experience-m3c-attributes-implementation.md).

Source/CI/TMS links are separately opt-in:
`RP_SCENARIO_LINKS_ENABLED=true`. They append bounded validated Markdown links to
the existing Scenario description without changing identity, attributes, logs,
or test topology. Source requires `{commit}`, `{path}`, `{line}`, a full commit
ID, and the source root. CI requires an explicit URL; no provider/environment
is autodetected. TMS uses `{id}` from the effective explicit ID rather than the
stable hashed wire ID. Invalid references are skipped without logging their raw
values. See [link usage](../examples/m3c_links/README.md),
[configuration](configuration.md#scenario-identity-and-business-metadata), and the
[links contract](design/reporting-experience-m3c-links-implementation.md).

## Video and external storage

Recording/finalization, console collection, conversion, privacy, and retention
belong to the caller. MP4 multipart attachment does not guarantee inline playback.
Ordinary PNG/JSON/text reporting uses default `reportportal_multipart` and needs
no external video setup. This guide does not certify MP4 delivery under that mode.

Optional `RP_VIDEO_UPLOAD_MODE=minio_markdown` streams caller-finalized video
through path-style S3/MinIO and writes video markup plus an **Open video** link.
Playback still depends on the RP renderer, browser/codec, CSP, and object access
policy. A recording typically becomes complete after BrowserContext close;
publish it under the currently open After/manual Hook node, not the failed
Step's expired handle. Historical recording walkthroughs are indexed under
[examples](../examples/README.md#historical-labs-and-verification-fixtures).

S3 HTTPS peer verification defaults to true. For a private CA, set
`RP_MINIO_SSL_CA_BUNDLE` to a trusted readable PEM bundle; do not disable
verification to resolve trust errors. These settings govern the S3 uploader,
not RP/browser traffic or bucket authorization. Development credentials/endpoints
in configuration are unsuitable for production. An uploaded object, a browser
link, and a playable/safely accessible recording are separate checks.

The **separate companion Chart 1.3.0** pins ReportPortal `26.0.5` and official
chart `26.8.12`; its version is independent of browser playback behavior. It uses
Prefix routes with a configurable controller class and dedicated-bucket
reconciliation. Its intentional internal-network public mode grants only
anonymous `s3:GetObject`, retaining GET/HEAD/Range playback without anonymous
listing/writes/deletes. `makePublic=false` revokes previous grants;
`enabled=false` also revokes unless explicitly opted out. Retention/hard-quota
initialization failures fail the reconciliation Job.

Anonymous known-URL reads are not viewer authentication, content redaction, or
CSP bypass. v1.2.0's historical rc.2 Chart archive does not contain the 1.3.0
policy fixes. For exact deployment scope, retention, TLS, Huawei/private-cloud
operations, and renderer restrictions, follow the
[Helm operator guide](../helm/reportportal-rich-experience/README.md). No deployment
change is needed for the ordinary API/PNG/JSON examples. Local compatibility
does not certify production HA or a particular private-cloud ingress.

## Dated evidence and limitations

Use the [historical index](design/README.md) to distinguish implementation
contracts from recorded checks and source-only QA. Prior acceptance describes
the named candidate/version/environment; it is not proof that every edited
checkout, Ruby version, or RP deployment passes today. Queue overflow, async
acceptance, uncertain retries, and interrupted processes preclude zero-loss or
exactly-once claims. Review [privacy guidance](best-practices.md#keep-private-data-out-at-the-producer)
for ordinary log text, attachment bytes, original exception channels, and debug
replay files.
