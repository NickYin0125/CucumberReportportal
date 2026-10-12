# reportportal-cucumber-ruby

Real-time ReportPortal reporting for Ruby Cucumber, with readable BDD structure,
contextual API diagnostics, caller-owned UI evidence, and explicit delivery receipts.
The SDK reports your tests; it does not run HTTP assertions, own your browser, or
decide when screenshots and recordings should be captured.

### What You See In ReportPortal

```text
Launch
  Feature                       SUITE, hasStats=true
    Scenario / Examples row     STEP, hasStats=true (one statistical test)
      Before / After Hook       BEFORE_METHOD / AFTER_METHOD, hasStats=false
      Given / When / Then       STEP, hasStats=false
        Manual business group   STEP, hasStats=false
          Logs and attachments
```

Scenario is a test in business terms, but its wire type is deliberately `STEP`,
not `TEST`. The verified ReportPortal UI statistics drilldown filters statistical
leaves with `type=STEP&hasStats=true&hasChildren=false`; non-statistical children
carry evidence without becoming additional test results. Background steps retain
their `[Background]` prefix, and DataTables/DocStrings become Markdown descriptions
and rich step logs. Each executed Examples row gets its own item UUID.

Use `AppLog` for terminal, native Cucumber HTML/messages, and RP logging; use
`rp_attach`, `rp_step`, and explicit capture targets for RP-specific evidence.
Delivery uses bounded batching, HTTP backoff, exit barriers, and durable spool
transactions. These safeguards make incomplete reporting observable, not a
zero-loss or exactly-once promise.

**Start here:** [complete API and Playwright example](examples/current_sdk/README.md).
For an existing framework, follow [Usage](#usage), [Test Organization](#test-organization),
and [Reporting Experience](#reporting-experience).

| Your goal | Read next |
| --- | --- |
| Run real API/UI examples and inspect their evidence | [Example project](examples/current_sdk/README.md) |
| Understand where each log appears | [Log routing](#reporting-experience) |
| Find Scenarios, DEBUG logs, and attachments in RP | [RP inspection checklist](#inspect-logs-in-reportportal) |
| Keep UI failures and screenshots correctly attributed | [Failure evidence](#failure-evidence-api) |
| Share a Launch across isolated CI workers | [CI-owned Launch contract](#ci-owned-launches-and-legacy-local-join) |
| Diagnose an incomplete report or retry retained evidence | [Receipts](#configuration) and [controlled replay](#durable-spool-and-controlled-replay) |

## Installation

Gem **1.2.0** is distributed as an installable archive in the
[GitHub release](https://github.com/NickYin0125/CucumberReportportal/releases/tag/v1.2.0).
RubyGems.org publication is separate; do not assume an unversioned registry install
selects this release. The companion chart remains **1.2.0-rc.2**
(`appVersion: 26.0.5`, official chart `26.8.12`), not production security/HA
certification. See [the changelog](CHANGELOG.md) for scope and limitations.

Requirements: Ruby `>= 3.1`, Bundler, and Cucumber `>= 9, < 11`.
The latest independent acceptance used Ruby 3.4.2 with Cucumber 9.2.1 and 10.2.0;
the declared Ruby range is not a claim that every Ruby version was exercised.
Playwright is an optional dependency of your UI test project, not of this SDK.

Download the release archive and install it:

```bash
curl -fL -o reportportal-cucumber-ruby-1.2.0.gem \
  https://github.com/NickYin0125/CucumberReportportal/releases/download/v1.2.0/reportportal-cucumber-ruby-1.2.0.gem
gem install ./reportportal-cucumber-ruby-1.2.0.gem --no-document
```

Alternatively, build the same version from the tagged checkout:

```bash
mkdir -p pkg
gem build reportportal-cucumber-ruby.gemspec \
  --output pkg/reportportal-cucumber-ruby-1.2.0.gem
gem install ./pkg/reportportal-cucumber-ruby-1.2.0.gem --no-document
```

Pin the installed release in your automation project's Gemfile:

```ruby
source "https://rubygems.org"
gem "cucumber", ">= 9", "< 11"
gem "reportportal-cucumber-ruby", "= 1.2.0"
```

```bash
bundle install
bundle exec ruby -e 'require "reportportal_cucumber"; puts ReportportalCucumber::VERSION'
```

The SDK itself constrains cucumber-expressions to `>=17,<19`. Bundler can use
the locally installed release. `bundle install --local` is an
offline alternative only when **all** required dependencies are already cached.
For SDK development, `path:` must point to the source directory containing the
gemspec, never to a `.gem` archive or an unpacked directory without a gemspec.
Do not remove the version pin or assume RubyGems.org publication is configured.
The example's independent installation exposed a Cucumber 10.2.0 message-builder
failure with expressions 19.x. The gem dependency cap protects native HTML/messages;
it is not an SDK monkey patch. The
[upstream changelog](https://github.com/cucumber/cucumber-ruby/blob/main/CHANGELOG.md)
records the nil-group-children fix in Cucumber 11, which is outside this SDK's
supported range. See the [example verification](examples/current_sdk/verification.md)
for the exact tested dependency combinations.

## Usage

In your project's `features/support/env.rb`, load the DSL and bind a logger around
each scenario. `with_logger` restores the previous thread/fiber-local logger with
`ensure`, including on failures:

```ruby
require "reportportal_cucumber"
World(ReportportalCucumber::Cucumber::World)

Around do |_scenario, run|
  AppLog.with_logger(Automation::CucumberLogger.new(world: self)) { run.call }
end
```

Start locally with `RP_ENABLED=false`: native Cucumber reports and AppLog still
work without an RP connection. To enable RP, provide your existing endpoint,
project, and API key through your secret manager or shell environment; never
commit a real token to YAML. For example, from this SDK checkout:

```bash
RP_ENABLED=true \
RP_ENDPOINT=https://reportportal.example.com \
RP_PROJECT=demo \
RP_API_KEY="$RP_API_KEY" \
RP_LAUNCH="Ruby Cucumber Demo" \
bundle exec cucumber --no-profile examples/minimal/features \
  --require examples/minimal/features \
  --format ReportPortal::Cucumber::Formatter
```

Configuration is read from `.reportportal.yml` or `config/reportportal.yml` in the
current working directory, or the path in `RP_CONFIG`. Environment variables
override YAML. Keep credentials out of source-controlled configuration:

```yaml
default:
  endpoint: https://reportportal.example.com
  project: demo
  launch: Ruby Cucumber Demo
  launch_description: API and browser regression
  launch_mode: DEFAULT
  launch_attributes:
    - key: build
      value: "0.1"
    - value: smoke
  batch_size_logs: 2
  join: false
```

Use `CUCUMBER_PROFILE` to select an RP YAML profile. Cucumber's own `-p` profiles
select command-line options; keep the two configuration layers explicit:

```bash
CUCUMBER_PROFILE=ci bundle exec cucumber --format ReportPortal::Cucumber::Formatter
```

Give each additional formatter its own `--out`; only one formatter should own
STDOUT. Creating the output directory is the caller's responsibility:

```bash
mkdir -p tmp
bundle exec cucumber --no-profile features \
  --format progress \
  --format html --out tmp/report.html \
  --format message --out tmp/messages.ndjson \
  --format ReportPortal::Cucumber::Formatter --out tmp/reportportal-formatter.log
```

`progress` keeps the terminal compact while AppLog prints concise summaries.
Choose `pretty` instead when you also want Gherkin text and native `world.log`
content echoed locally. Pretty may print the full Markdown JSON; AppLog's compact
summary cannot suppress another formatter's output.
The RP formatter's `--out` reserves a separate output destination; the formatter
does not write a log stream there, and the file may not exist. Inspect RP logs in
the RP UI, use AppLog/console mirror locally, and read the final reporting receipt
for delivery status rather than treating that path as a report.

Legacy `rp_log` does not write native Cucumber HTML evidence. To mirror these
RP-only calls to STDOUT, opt in to `[RP-MIRROR]` output:

```bash
RP_CONSOLE_MIRROR=true bundle exec cucumber --no-profile features \
  --format progress \
  --format ReportPortal::Cucumber::Formatter --out tmp/reportportal-formatter.log
```

Both keyword and positional log levels are supported:

```ruby
rp_log(JSON.pretty_generate(response), level: :info)
rp_log(JSON.pretty_generate(response), "INFO")
```

## Test Organization

Keep business intent in features, assertions in step definitions, and reusable
HTTP/browser operations in helpers or page objects. A practical layout is:

```text
automation/
  Gemfile
  cucumber.yml                    # Local, API, UI, and RP execution profiles
  .reportportal.yml               # Non-secret reporting settings
  features/
    api/                          # Contract and negative-response scenarios
    ui/                           # User journeys and failure-evidence scenarios
    step_definitions/             # Thin business assertions and orchestration
    support/
      env.rb                      # World, AppLog Around scope, configuration
      hooks.rb                    # Browser setup, evidence capture, cleanup
  lib/
    clients/                      # Make HTTP calls; AppLog.http observes results
    pages/                        # Playwright locators and user actions
    workflows/                    # Domain helpers; log without passing World around
  tmp/                            # HTML, messages, screenshots, receipts (gitignored)
```

- Tag scenarios `@api`, `@ui`, and `@expected_failure` so a healthy smoke run and
  deliberate failure demonstration are separate, explicit commands.
- Use Background for common business prerequisites, Scenario Outline for data
  variants, and `rp_step` only for meaningful sub-actions, not every Ruby call.
- Bind one AppLog per scenario. Give every browser scenario its own context and
  close it in `ensure`; never share pages through globals.
- Assert the observed outcome with your test framework. Logging an ERROR or
  `AppLog.assertion(passed: false)` alone does not fail a Cucumber scenario.
- Capture failure evidence before its Step closes. An After hook can publish
  evidence to that hook, but cannot revive a closed Step target.
- Retain file-backed artifacts until final reporting settles; do not remove a
  queued screenshot immediately after `rp_attach` returns.

The [current SDK example](examples/current_sdk/README.md) implements this separation
with real local HTTP calls and Playwright, including an optional Typewords target.
Start with its passing suite, then deliberately run its failure profile to inspect
the original error and screenshot placement.

### Inspect Logs In ReportPortal

Open your RP UI, select the configured project and Launch, then:

1. Open the Feature suite or its Passed/Failed count. The rows are Scenarios and
   Examples iterations, not the individual Given/When/Then operations.
2. Open a Scenario's Log View and expand the relevant Step or Hook. API request/
   response Markdown, DataTables, JSON, and attachments belong to that action.
3. Include DEBUG/TRACE in the log-level filter when inspecting `AppLog.debug` or
   `AppLog.trace`; INFO-only filters can hide valid logs.
4. Click a JSON or PNG attachment to inspect it. Bounded previews are not the full
   artifact; the file remains available independently of preview length.
5. Compare the business result with the final reporting receipt. A complete
   receipt means the requested synchronous delivery was confirmed, not that
   every test passed. A passing test can still have an incomplete report.

Logs are batched asynchronously: visibility can lag by the flush interval plus
network/backend processing. Refresh the UI rather than assuming it streams updates
automatically. Native HTML/messages let you inspect evidence when RP is unavailable.

## Configuration

The main environment variables are listed below. The example project provides
safe local/remote profiles; configuration defaults do not create an RP account
or token.

| Setting | Default | Practical meaning |
| --- | --- | --- |
| `RP_ENABLED` | `true` | Reporting is requested; missing credentials keep transport inert but produce an incomplete receipt. Use `false` intentionally for local-only runs. |
| `RP_CLIENT_JOIN` | `false` | Separate workers create separate Launches unless CI supplies `RP_LAUNCH_UUID`. |
| `RP_BATCH_SIZE_LOGS` / `RP_FLUSH_INTERVAL` | `20` / `1.0` seconds | Batch by count or interval, subject to the byte limit. |
| `RP_QUEUE_MAX_RECORDS` / `RP_QUEUE_MAX_BYTES` | `1000` / `16777216` | Bound reserved records and accounted resident data. |
| `RP_BATCH_MAX_BYTES` | `8388608` | Bound the complete serialized HTTP batch body. |
| `RP_QUEUE_OVERFLOW_POLICY` | `reject_new` | Rejections are visible in diagnostics/receipts; `block` waits for a bounded admission interval instead. |
| `RP_EXIT_FLUSH_TIMEOUT_MS` | `5000` | One shared exit/finalization budget, not a new timeout for every item. |
| `RP_REQUIRE_COMPLETE_REPORTING` | `false` | Opt in to a separate incomplete-report failure after business execution and teardown. |
| `RP_IDENTITY_STRATEGY` | `legacy` | Preserve existing history unless deliberately migrating to `stable_v1`. |
| `RP_MINIO_SSL_VERIFY_PEER` | `true` | Verify optional S3 upload peers; it does not govern RP/browser access policies. |

- `RP_ENABLED` (`false` intentionally keeps the formatter inert; missing endpoint/project/API key prevents transport and leaves requested reporting incomplete)
- `RP_ENDPOINT`
- `RP_PROJECT`
- `RP_API_KEY`
- `RP_LAUNCH`
- `RP_LAUNCH_UUID` (existing CI-owned launch; YAML `launch_uuid`)
- `RP_LAUNCH_DESCRIPTION`
- `RP_LAUNCH_MODE`
- `RP_ATTRIBUTES` (launch attributes, for example `build:0.1,smoke`)
- `RP_RERUN`
- `RP_RERUN_OF`
- `RP_REPORTING_ASYNC`
- `RP_BATCH_SIZE_LOGS`
- `RP_BATCH_MAX_BYTES`
- `RP_QUEUE_MAX_RECORDS`
- `RP_QUEUE_MAX_BYTES`
- `RP_QUEUE_OVERFLOW_POLICY`
- `RP_QUEUE_ADMISSION_TIMEOUT_MS`
- `RP_FLUSH_INTERVAL`
- `RP_FAIL_ON_REPORTING_ERROR`
- `RP_REQUIRE_COMPLETE_REPORTING` (separate opt-in completeness gate; YAML `require_complete_reporting`)
- `RP_CONFIG` (YAML profile path; environment variables override YAML values)
- `RP_SPOOL_DIR`
- `RP_SPOOL_MAX_BYTES`
- `RP_EXIT_FLUSH_TIMEOUT_MS` (one shared monotonic shutdown/finalization budget)
- `RP_CLIENT_JOIN` (default `false`; YAML `join`)
- `RP_CLIENT_JOIN_LOCK_FILE_NAME`
- `RP_CLIENT_JOIN_SYNC_FILE_NAME`
- `RP_CLIENT_JOIN_FILE_WAIT_TIMEOUT_MS`
- `RP_CONSOLE_MIRROR`
- `RP_DEBUG_CURL_MODE`
- `RP_DEBUG_CURL_DIR`
- `RP_HTTP_OPEN_TIMEOUT`, `RP_HTTP_READ_TIMEOUT`, `RP_HTTP_WRITE_TIMEOUT` (seconds)
- `RP_HTTP_RETRY_ATTEMPTS`, `RP_HTTP_RETRY_BASE_INTERVAL`, `RP_HTTP_RETRY_MAX_INTERVAL`
- `RP_VIDEO_UPLOAD_MODE` (default `reportportal_multipart`; optional `minio_markdown` is subject to the rollout restrictions below)
- `RP_MINIO_ENDPOINT`
- `RP_MINIO_PUBLIC_BASE_URL`
- `RP_MINIO_BUCKET`
- `RP_MINIO_ACCESS_KEY_ID`
- `RP_MINIO_SECRET_ACCESS_KEY`
- `RP_MINIO_REGION`
- `RP_MINIO_SSL_VERIFY_PEER` (default `true`; YAML `minio_ssl_verify_peer`)
- `RP_MINIO_SSL_CA_BUNDLE` (trusted CA bundle path; YAML `minio_ssl_ca_bundle`)

### CI-owned launches and legacy local join

For shared CI reporting, CI must create one launch, pass its original UUID as
`RP_LAUNCH_UUID` to every worker, collect every worker's business exit status and
final reporting receipt, and finish that launch only after all workers have
completed. Workers use that UUID for items/logs, bypass local file join, and
neither start nor finish the launch. A worker receipt is not a cross-process
aggregate or proof that CI finalized the launch. CI owns late workers, missing
receipts, crashed workers, deadlines, and original business-failure precedence;
this gem is not a distributed scheduler.

Supply a UUID-shaped string for an already-open launch in the configured
endpoint/project. Environment values override YAML. Do not combine
`RP_LAUNCH_UUID` with `RP_RERUN`/`RP_RERUN_OF`: launch creation and rerun ownership
belong to CI, and this conflicting configuration is rejected.

Local join defaults to `false`; without an externally owned UUID, each worker
creates and finishes its own independent launch. Legacy `RP_CLIENT_JOIN=true`
remains an explicit compatibility opt-in but is deprecated for
production shared completion. It is same-host file coordination only: the primary
can finish before secondaries, and a later worker can split into another launch
after the primary exits. Do not use it as a CI completion barrier. Without an
externally owned UUID, `RP_CLIENT_JOIN=false` creates independent worker launches.

### External video TLS and rollout boundary

MinIO/S3 HTTPS verifies the server certificate by default. For a private CA,
provide a trusted PEM bundle through `RP_MINIO_SSL_CA_BUNDLE`; the corresponding
YAML keys are listed above. Do not disable verification in production. These
settings are for the optional S3 uploader, not the ReportPortal HTTP client or
browser playback access policy.

Keep `RP_VIDEO_UPLOAD_MODE=reportportal_multipart` for the default
pilot's ordinary image/JSON/text uploads. This guide does not upload or certify
MP4 attachments under that mode. The Helm anonymous public/write/delete and public-to-private revocation
findings (D4/D10) are deliberately unresolved in this patch. TLS verification
does not repair bucket permissions; external playback remains gated on a
separate effective-policy review. No deployment or bucket policy is changed.

Log delivery is bounded by default: at most 1,000 reserved records and 16 MiB
of accounted resident data (including 256 bytes of metadata allowance per
record), with requests limited to 20 entries and 8 MiB of complete serialized
body. Queue overflow rejects new logs and is visible in
`Formatter#reporting_diagnostics`; `RP_QUEUE_OVERFLOW_POLICY=block` opts into a
bounded admission wait (100 ms by default). Configure positive integer limits
in YAML or with the corresponding `RP_*` variables. File-backed attachments
retain their paths for streaming. `StringIO` contributes its complete backing
string without changing its cursor; other non-path IO sources are explicitly
rejected without reading them. The default rejection policy is intentionally
observable but lossy under overload, not a zero-loss guarantee. The
`sent_batches` diagnostic counts successful local API calls, not ReportPortal
log receipts.

`Runtime::LogBuffer#flush` and `#shutdown` (backed by
`Service::QueueProcessor`) retain Boolean compatibility and mean only that
accepted work locally settled before the call returned. The receipt-returning
`flush_receipt(timeout:)` and `shutdown_receipt(timeout:)` methods are also on
those classes; `Cucumber::Formatter` exposes only `reporting_receipt`. Use that
formatter method for the final frozen `DeliveryReceipt`. Its `cutoff`
is the accepted sequence captured when the barrier began; producers accepted
later do not extend it. Receipt fields include `settled`, v1 `confirmed`,
v2 `accepted_awaiting_persistence`, `spooled`, `failed`, `ambiguous`,
`possible_duplicates`, `pending`, and `rejected`. For a flush/shutdown receipt,
`rejected` is the cumulative rejection count observed at that cutoff call;
rejections have no accepted sequence and do not extend the cutoff. In
`reporting_receipt`, it is the whole-run cumulative total. `ambiguous` may also
be represented in the local spool; a spool copy does not make server
acceptance known. Async v2 acceptance is explicitly not proof of persistence.

`local_settled` is separate from `complete`. Whole-report `complete` is false
when any accepted log remains unconfirmed, an admission was rejected, evidence
capture did not close in time, a reporting start/finish call failed, or video
upload degraded to plaintext. `RP_FAIL_ON_REPORTING_ERROR` opts into propagating
reporting exceptions from synchronous formatter calls when there is no original
business failure. This is an exception-based opt-in, not a complete-report
policy: a background log-only failure can leave a passing run at exit `0` with
`complete=false`, even when strict reporting is enabled. Consumers requiring
reporting completeness must inspect the final `reporting_receipt`. Strict
reporting does not replace or mask an original business exception.
`RP_REQUIRE_COMPLETE_REPORTING=true` separately opts into enforcing the final
whole-run receipt rather than only synchronous exceptions; it defaults to
`false`. CI must still collect each worker receipt and actual process exit,
preserve original business failures, and distinguish an incomplete report from
a failed business test. On an otherwise passing native run, an incomplete final
receipt raises `ReportportalCucumber::ReportingError` (Cucumber exit `2`); original
business/run-hook errors are not replaced by that reporting error. It does not
turn spooling or async acceptance into server confirmation. If reporting is
requested (the default) but endpoint, project or API key is missing, no API,
Join, queue worker or network resources are created. The receipt is
`complete=false` with `metadata_failures=1`; `reporting_diagnostics` exposes
`reporting_requested` and `missing_configuration` option names, never values.
Required mode still runs business code and genuine `AfterAll` before raising
the configuration reporting error on an otherwise successful run. Best-effort
mode remains exit `0`, and explicit `RP_ENABLED=false` bypasses this gate.
The receipt
uses cumulative bounded counters and a bounded number of
active cutoff waiters; it does not retain per-log payloads or a run-long
outcome map. Shutdown/finalization shares one monotonic budget across its
barrier, transport retries, capture closure, item/launch finishes, and worker
join. A zero-timeout shutdown returns immediately and does not synchronously
spool outstanding work.

HTTP retries remain enabled, but a successful log response after a retry is
marked in `possible_duplicates`: an earlier attempt may have reached
ReportPortal before its response was lost. Such a record can be confirmed and
flagged as possibly duplicated; the whole-run receipt will not claim `complete`.

A Cucumber consumer can retain the reporter while Cucumber is active and inspect
the reporting result after normal formatter completion, without changing the
business result:

```ruby
reporter = nil

Before do
  reporter ||= ReportportalCucumber.current_runtime
end

at_exit do
  receipt = reporter&.reporting_receipt
  warn("ReportPortal report incomplete: #{receipt.to_h}") if receipt && !receipt.complete
  # Preserve the process/business exit status; reporting completeness is separate.
end
```

The runtime can be cleared after a normal Cucumber run, so retain the reporter
in the lexical `reporter` variable in `Before`. The formatter exposes
`reporting_receipt`; it does not expose `flush`, `shutdown`, `flush_receipt`, or
`shutdown_receipt`. During interruption, `at_exit` ordering is best-effort and
can precede formatter shutdown; the receipt may still be pending.

### Native run-hook accounting

In native Cucumber 9/10, `BeforeAll` executes before formatter construction. If
it aborts, this formatter creates no launch and does not fabricate a class-hook
item. A per-registry observer waits for the real `AfterAll` execution before
finalizing reporting. An `AfterAll` error is recorded as a credential-sanitized
launch-level ERROR log; the original hook/business exception is preserved,
including when reporting fails. Native run hooks are not represented as
`BEFORE_CLASS`/`AFTER_CLASS` test-step items.

CI-owned workers still never finish the shared launch: CI must combine their
actual process outcomes and final receipts before finalizing it. A complete
delivery receipt does not mean the business run or teardown passed. Sequential
native runtimes and duplicate formatter configurations now pass source-level
native Cucumber 9.2.1 and 10.2.0 subprocess regressions, including event-bus isolation,
original hook-exception precedence and strict reporting-completeness faults.
The observer depends on Cucumber 9/10's private DSL registry/configuration
association. The 2026-10-12 independent candidate acceptance exercised installed
gems, native Cucumber 9.2.1/10.2.0, duplicate/sequential runtimes, and real RP
AfterAll-failure Launch readback. This does not certify native class-hook items,
other Ruby versions, or every ReportPortal deployment.

See the [M4-B implementation contract](docs/design/reporting-experience-m4b-implementation.md)
and [M4-B verification record](docs/design/reporting-experience-m4b-verification.md)
for the receipt schema and acceptance evidence.

### Durable spool and controlled replay

New failures are stored as private, versioned spool transactions under
`RP_SPOOL_DIR` (default `.reportportal-spool`). `RP_SPOOL_MAX_BYTES` defaults to
`268435456` bytes and must be a positive decimal integer. Existing unversioned
NDJSON remains available for inspection but is not imported or replayed
automatically. Spool data may contain sensitive test evidence; protect and
retain the directory accordingly.
`RP_CONFIG` supplies YAML defaults/profile values; environment variables
override those values. For replay, `--spool-dir` explicitly selects the spool
root. `RP_EXIT_FLUSH_TIMEOUT_MS` is shared across finalization rather than
multiplied per item. `RP_FAIL_ON_REPORTING_ERROR` is the exception-based strict
opt-in described above, not a requirement that every log be confirmed.

Replay is transaction-scoped and dry-run by default. Dry-run reads and validates
the selected transaction without credentials or HTTP requests. Execution
requires an explicit `--execute`, checks that the original launch and item are
still open, and refuses endpoint/project mismatches. It does not reopen or
recreate ReportPortal targets. A previously interrupted `in_flight` entry is
uncertain; `--allow-duplicates` explicitly consents to possible duplicate
delivery for this selected transaction only. Confirmed entries are never sent
again. Each entry receives one HTTP attempt, so a lost response remains
ambiguous rather than being retried automatically. Async v2 replay is not
confirmed and is refused.

Successful dry-run inspection does not mean the transaction is replayable.
Its `unavailable_artifacts` count is bounded to `0..1000` and includes known
unavailable markers on confirmed siblings; `unavailable_artifact_reasons` is
either `[]` or `["source_unavailable"]`, without artifact names or paths.
These markers have no replayable source bytes; retain the transaction and
recover original evidence separately. Replay never fabricates replacement
bytes. A missing published blob or checksum mismatch remains a hard error
(exit `2`), not a successful unavailable-marker inspection.

To discover transaction IDs without printing evidence contents, list the
committed marker filenames. This shows candidates only; the selected
transaction is still fully validated by the dry-run command, and malformed
committed transactions are reported as errors rather than treated as clean.

```bash
spool_dir="${RP_SPOOL_DIR:-.reportportal-spool}"
for marker in "$spool_dir"/tx-*.ndjson; do
  [ -f "$marker" ] || continue
  printf '%s\n' "${marker##*/}" | sed 's/\.ndjson$//'
done
```

```bash
reportportal-spool --spool-dir .reportportal-spool --transaction TRANSACTION_ID --dry-run
RP_ENDPOINT=https://reportportal.example RP_PROJECT=project RP_API_KEY=... \
  reportportal-spool --spool-dir .reportportal-spool --transaction TRANSACTION_ID \
  --execute --timeout 30
```

Exit `0` means dry-run inspection completed or requested confirmations were
persisted; execute exits `2` if evidence remains refused, pending, failed, or
ambiguous; invalid CLI syntax exits `1`. A dry-run never sends data.

### Scenario identity migration

Scenario identity remains `legacy` by default. To pilot stable identities, opt in
explicitly and keep the namespace fixed across CI workers that should share
history:

```bash
RP_IDENTITY_STRATEGY=stable_v1 \
RP_IDENTITY_ROOT="$PWD" \
RP_IDENTITY_NAMESPACE="payments-ci" \
bundle exec cucumber features --format ReportPortal::Cucumber::Formatter
```

In `stable_v1`, `RP_TEST_CASE_ID` and `@tms:` values seed an opaque
`rp:stable-v1:<digest>` ReportPortal `testCaseId`; the raw seed is not the wire
ID, and UI search by the raw TMS value is not guaranteed. The default `legacy`
strategy preserves existing IDs and histories. Stable-v1 starts a separate
history baseline; it does not rewrite, merge, or backfill server history. Review
the [M3B migration contract](docs/design/reporting-experience-m3b-implementation.md)
before opting in.

### Scenario business attributes (M3C)

Scenario attributes are opt-in; set `RP_SCENARIO_ATTRIBUTES_ENABLED=true` to
publish allowlisted business values on Scenario items only. The default keys are
`component,team,owner,layer,priority,browser,tms`; defaults are an empty JSON
object/list, for example `RP_SCENARIO_ATTRIBUTES='{"component":"payments"}'`.
Tags use `@key:value` and inherit from Feature, Rule, Scenario, then the executed
Examples row. A later scope overrides an earlier value; conflicting values for
one key in the same scope are ignored for that scope. `tms` is derived only from
the effective explicit test-case ID (`RP_TEST_CASE_ID` first, otherwise the
existing scenario ID tag selection). Existing `@tms:` identity tags still work;
the attribute mapper does not independently reselect the ID from inherited
tags or configured defaults. See the [usage example](examples/m3c_attributes/README.md)
and [M3C implementation contract](docs/design/reporting-experience-m3c-attributes-implementation.md).

### Scenario source, CI, and TMS links (M3C)

Scenario references are separately opt-in and default to disabled. Set
`RP_SCENARIO_LINKS_ENABLED=true` to append configured Source, CI Run, and TMS
Markdown links to the existing Scenario description. Configure source links with
`RP_SOURCE_URL_TEMPLATE`, `RP_SOURCE_COMMIT`, and `RP_SOURCE_ROOT`; the template
uses `{commit}`, `{path}`, and `{line}`. Configure an explicit run URL with
`RP_CI_RUN_URL`, and a TMS template with `{id}` using
`RP_TMS_URL_TEMPLATE`. No CI provider or environment variables are detected
automatically. See the [links example](examples/m3c_links/README.md) and
[M3C links contract](docs/design/reporting-experience-m3c-links-implementation.md).

Links are description-only metadata. This does not add ReportPortal link fields,
logs, or test items, and does not affect scenario identity or the separate
business-attribute setting. The implementation uses bounded, validated URLs;
invalid references are skipped without including their raw values in diagnostics.
This repository's local request-capture tests do not certify a live ReportPortal
UI deployment.

## DSL

Use these methods in Cucumber World/step definitions. They route to RP only;
use AppLog or native `log`/`attach` when local HTML/messages are also required:

```ruby
rp_log("business checkpoint")

rp_attach("tmp/screenshot.png",
  name: "screenshot.png",
  mime: "image/png",
  message: "screenshot after login")

rp_attach(JSON.generate({ account: "A-17", status: "ok" }),
  name: "response.json", mime: "application/json", message: "Sanitized response")

rp_step("Prepare data") do
  rp_log("seed user")
end
```

An `rp_log(..., attachment:)` hash supports `name`, `bytes`, and `mime`.
`rp_attach` accepts an existing file path, File/Tempfile, StringIO, or byte string;
arbitrary non-path IO objects are refused without reading them. Path-backed
multipart streams the file and avoids reading the whole artifact in the Step.
Keep the file available until the reporting barrier settles.

### Triple-Track Smart Logger

Deep business helpers can call the thread/fiber-local `AppLog` proxy without a
World argument. With a bound World, it routes a diagnostic to the terminal,
Cucumber event bus (HTML/messages), and active ReportPortal formatter.

```ruby
AppLog.info("Margin payload", report: true, json: { status: "ok" })
AppLog.error("Payment failed", report: true, file: "tmp/failure.png")
AppLog.debug("Local diagnostic") # Terminal only by default.
```

For ordinary log methods, `attach: false` is terminal-only when `report:` is
omitted. Legacy `attach: true` still enables reporting; explicit `report:` takes
precedence. The `json:` payload becomes Markdown fenced JSON in reports, while
AppLog's own terminal output stays a single summary line. Another STDOUT formatter
may echo `world.log`; this is not a duplicate RP log submission.

The existing small logger scenario can be run from the repository:

```bash
RP_ENDPOINT=http://localhost \
RP_PROJECT=superadmin_personal \
RP_API_KEY="$TOKEN" \
RP_LAUNCH="triple-track-smart-logger-$(date +%Y%m%d%H%M%S)" \
bundle exec cucumber -P features/triple_track/triple_track_logger.feature \
  --format ReportPortal::Cucumber::Formatter --out tmp/triple-track-rp.log \
  --format html --out tmp/triple-track-report.html
```

Attachment ownership and presentation:

- `rp_attach` uses the current active Step/Hook or manual nested Step.
- JSON produces a bounded pretty-printed fenced preview; valid MIME metadata and
  the original file bytes are preserved.
- Text/log previews are bounded to 100 lines and 16 KiB; the full file is retained.
- Images, JSON, text, PDF, and binary files use RP multipart with matching JSON
  filenames and binary part filenames, including collision-safe names.
- Video capture/finalization belongs to your framework. MP4 multipart upload does
  not guarantee inline playback. Optional `minio_markdown` uploads to S3/MinIO and
  writes video markup plus an Open video link; it is **not** enabled by this guide
  and remains subject to the policy/renderer restrictions below.

## Reporting Experience

| Call | Terminal | Native Cucumber HTML/messages | ReportPortal |
| --- | --- | --- | --- |
| `AppLog.info("message")` | Compact summary | No | No |
| `AppLog.info("message", report: true, json: payload)` | Summary, not full JSON | Markdown JSON via the bound World | Same evidence at the active action when enabled |
| `AppLog.error("failure", report: true, file: path)` | Summary and filename | Log plus file attachment | Native-event forwarding when enabled |
| `AppLog.http(...)` / `AppLog.assertion(...)` | Compact diagnostic | Report by default | Report by default when enabled; does not assert business success |
| `rp_log(...)` / `rp_attach(...)` | Only optional `rp_log` console mirror | No | RP-only evidence |
| Native `log(...)` / `attach(...)` | Depends on the chosen formatter | Yes | Forwarded by the RP formatter; plain native logs use INFO |

The AppLog report tracks require a bound World; without one, the proxy is a
terminal logger, not a hidden global report collector. With a native RP formatter,
AppLog forwards through the Cucumber event bus rather than submitting the same
evidence twice.

`AppLog` keeps the existing terminal-only default. Use `report: true` to send a
message through Cucumber and the active RP formatter without requiring a physical
file attachment. `report: false` overrides `attach: true`; omitting `report:` keeps
the legacy `attach:` behavior. DEBUG and ERROR retain their levels in RP; plain
Cucumber `log` messages remain INFO.

Bind a logger in your consumer project's `features/support/env.rb`:

```ruby
require "reportportal_cucumber"

Around do |_scenario, run|
  AppLog.with_logger(Automation::CucumberLogger.new(world: self)) { run.call }
end
```

The scope restores the previous thread/fiber-local logger even when the scenario
raises. Native Cucumber reporting also works when the RP formatter is not enabled.

```ruby
AppLog.debug("Margin inputs", report: true, json: { account: "A-17", amount: 100 })
AppLog.info("Local diagnostic", report: false)

# Record an already observed exchange; this helper performs no HTTP request.
AppLog.http(
  method: :post,
  url: "https://clearing.example.test/trades",
  request: { headers: { "Authorization" => "Bearer token" }, body: { amount: -1 } },
  response: { status: 400, body: { code: "INVALID_AMOUNT" } },
  duration_ms: 84,
  expected_status: 400
)
```

`AppLog.http` defaults to report delivery, prints only a concise terminal summary,
and reports Request/Response Markdown with bounded body/header previews. It
redacts common credential headers, URL credentials, and structured sensitive keys
before rendering. An explicitly expected 400 is INFO; an unexpected status or
transport error is ERROR; an unspecified 4xx/5xx is WARN. These levels do not
replace test assertions or change a scenario's result.

Cucumber's `pretty` formatter may also echo the native `world.log` content to the
terminal. The compact summary guarantee applies to AppLog's own output, not to
other formatters independently rendering the same evidence.

The HTTP helper's redaction is not a universal PII filter. Existing `rp_log`,
ordinary `AppLog` messages/JSON, raw files, screenshots, and videos are not
automatically sanitized by that helper. Review artifacts before uploading them.
Failure-evidence and assertion diagnostic text is separately credential-redacted
before clipping; inputs above 64 KiB, malformed JSON-shaped diagnostics, and URLs
that cannot be parsed safely are replaced with a fixed omission marker. This
bounded policy also applies to transport-error warning text and spool exception
metadata. It does not sanitize raw file/video bytes, ordinary `AppLog`
messages/JSON, legacy `rp_log` content, arbitrary attachment contents, automatic
Step/manual-step exception or backtrace logs, or native Cucumber core failure
payloads. If a framework publishes safe `rp_evidence` and then re-raises the
original browser error, separate legacy failure logs may still carry it; this
sanitizer does not mutate or suppress that error. The HTTP helper does not
automatically attach complete HTTP bodies when its preview is truncated.

RP text/JSON attachment previews are bounded to 16 KiB and 100 lines for both
paths and bytes; the full attachment remains available. Path-backed previews use
bounded reads. The native Cucumber `AppLog(file:)` route still reads the file into
memory, so prefer direct `rp_attach(path)` for large RP-only artifacts. External
video logs include an ordinary **Open video** link alongside the video markup;
playback still depends on the deployed RP renderer, browser, codec, and access policy.

### Failure Evidence API

Capture the active Step target while that Step is open. `rp_capture_target`
returns an opaque handle, or `nil` when reporting is disabled or there is no open
action. Pass it explicitly when evidence is produced by a helper thread; the
handle remains valid only while its original action is open.

Execution state is isolated per reporting context and thread/fiber.
`Thread.current[:rp_context_stack]` and
`Thread.current[:reportportal_cucumber_context_state]` are diagnostic, read-only
snapshots of the most recently accessed context, not authoritative storage.
Directly modifying these mirrors is unsupported and does not change ownership;
use the public DSL and explicit capture-target APIs to route evidence.

```ruby
target = rp_capture_target # Capture inside the open Gherkin Step.
begin
  perform_risky_action
rescue StandardError => error
  rp_evidence(action: "Submit order", error: error, target: target)
  raise
end
```

The API signatures are:

```ruby
rp_capture_target
rp_evidence(action:, error:, url: nil, details: nil, artifacts: [], target: nil)
```

`rp_evidence` returns `true` when all evidence admissions succeed and `false` when
reporting is unavailable, the target is invalid/foreign/closed, or any admission
is rejected or cancelled. Queue admission is not server confirmation. Omitting
`target:` uses only the currently open action. It never falls back to a Scenario,
Launch, later Step, or hook when the original Step has closed; a rejected late
call does not retarget evidence.

Each artifact is a hash with either `path:` or `bytes:`, and optional `name:` and
`mime:`. Path-backed artifacts remain paths for streaming upload, so large files
do not need to be read into memory by the caller. In-memory `bytes:` artifacts
are limited to 1 MiB and larger values are rejected. The tester owns screenshot,
console, and video capture and decides which binary artifacts to provide.

Each `rp_evidence` call accepts at most 16 artifacts. Larger batches are rejected,
not silently truncated. All admissions in a call share one monotonic
`RP_EXIT_FLUSH_TIMEOUT_MS` budget rather than multiplying the wait per artifact.
Target closure cancels pending admissions; publication does not hold the context
lock while waiting for queue space. Finalization includes lock acquisition and
capture closure in its shared budget. Rejected evidence and closure timeouts
remain visible as incomplete reporting. Some entries may already have been
accepted when a later admission fails; a `false` return does not roll them back.

### Caller-Owned Browser Failure Evidence

`AppLog.assertion` records a redacted, bounded diagnostic comparison; it does not
raise or affect Cucumber pass/fail. Browser capture remains entirely caller-owned.
For example, with Playwright Ruby 1.62, a consumer can keep a screenshot and
console excerpt when a locator fails, report them, and re-raise the original error:

```ruby
require "fileutils"

target = rp_capture_target # Save attribution while the Gherkin Step is open.
begin
  page.get_by_role("button", name: "Submit").click
rescue Playwright::TimeoutError => error
  FileUtils.mkdir_p("tmp")
  screenshot = "tmp/submit-failure.png"
  begin
    page.screenshot(path: screenshot) # Explicit caller-owned capture.
  rescue StandardError
    screenshot = nil # A secondary capture failure must not replace the locator error.
  end
  begin
    console_excerpt = page.console_messages.last(20).map(&:text).join("\n")
    AppLog.assertion(
      name: "Submit button is actionable",
      expected: "click succeeds",
      actual: error.message,
      passed: false,
      details: "Console:\n#{console_excerpt}"
    )
    artifacts = screenshot ? [{ path: screenshot, name: "submit-failure.png" }] : []
    rp_evidence(
      action: "Submit order", error: error, url: page.url,
      details: "Console:\n#{console_excerpt}",
      artifacts: artifacts, target: target
    )
  rescue StandardError
    # Reporting failures must not replace the original Playwright error.
  end
  raise
end
```

This consumer-side example adds no Playwright dependency and does not
automatically inspect pages, capture screenshots, or record video.

Run the deterministic sample without RP (no external business request):

```bash
mkdir -p tmp
bundle exec cucumber examples/reporting_experience/features \
  --require examples/reporting_experience/features \
  --format pretty --format html --out tmp/reporting-experience.html
```

To also report it to your configured RP project, set `RP_ENDPOINT`, `RP_PROJECT`,
and `RP_API_KEY`, then append:

```bash
--format ReportPortal::Cucumber::Formatter --out tmp/reporting-experience-rp.log
```

The structural plan and acceptance gates are in
`docs/design/reporting-experience-v1-2.md`. This increment does not change the
Scenario statistics type or claim a native RP network-inspector component.

## Design Notes

- RP requests go through `ReportportalCucumber::Http::Client`; optional S3 uploads
  use the separate AWS SDK transport.
- `RP_REPORTING_ASYNC` selects `/api/v2` instead of `/api/v1`. Async acceptance is
  not a synchronous persistence confirmation.
- Launch/item UUIDs are generated before creation and reused on retries. This
  reduces duplicate creation risk; log retries may still duplicate accepted logs.
- `Runtime::LogBuffer` delegates bounded batching to a background
  `Service::QueueProcessor`, flushing by count, bytes, or interval.
- Retryable HTTP/network failures use exponential backoff; exhausted delivery
  can be recorded as a durable spool transaction, subject to the disk quota.
- CI-owned shared Launches bypass local file join. Explicit legacy join uses
  file locks and a sync file, not a distributed completion protocol.
- `ReportPortal::Models::StepDesc` renders Gherkin semantics as Markdown;
  `Transport::MultipartHelper` validates metadata/file associations and MIME types.
- `Transport::MinioUploader` is the optional path-style S3 video uploader, with
  TLS verification and sanitized fail-safe degradation.
- `RP_DEBUG_CURL_MODE=true` logs reproducible transport commands. Multipart
  replay files are written to `RP_DEBUG_CURL_DIR`. These files may contain full
  test evidence: restrict permissions/retention and do not enable them by default
  in a production secret-bearing run.

## Testing

Use Ruby >=3.1 and the locked Bundler environment, including native child
processes. Cucumber is supported at `>=9,<11`; selecting it only in the parent
does not prevent an unbundled child from activating ambient Cucumber 11.

```bash
RUBYOPT=-rbundler/setup bundle exec rspec -Ilib -Ispec spec
bundle exec cucumber
```

For the Homebrew Ruby environment used in this review, prepend
`/opt/homebrew/opt/ruby/bin` to `PATH`. Packaging verification builds and installs
the gem in a private consumer without source-path loading. The historical
[candidate operator guide](docs/design/production-candidate-packaging-20261011.md)
documents the isolated test procedure and its no-live-service boundary.

The 2026-10-12 candidate acceptance ran the full suite separately
against Cucumber 9.2.1 and 10.2.0: **655 examples, 0 failures, 0 pending per lane**,
including the six latest-Helm contract checks.
It also exercised installed-gem API/Playwright consumers, real RP log/attachment
ownership and byte reconciliation, CI-owned late workers, and native teardown
failures. These are recorded results for that candidate, not an automatic promise
that an edited checkout or another deployment passes.

Coverage includes payload/identity/attribute/link mapping, HTTP backoff/fail-fast,
bounded batching, durable spool/replay, capture closure and receipts, formatter
ownership/lifecycle, privacy controls, TLS handshakes, attachment collisions,
disabled reporting, rerun, and independent package installation.

Run the [current example's acceptance commands](examples/current_sdk/README.md)
for end-user workflow checks without running the SDK's historical duration/chaos
experiments. The example separates healthy smoke scenarios from deliberate failures.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Two formatters cannot both write STDOUT | Give RP, HTML, and message formatters distinct `--out` files; create their parent directories. |
| AppLog is terminal-only | Bind a World with `Around`/`with_logger` and set `report: true` (or legacy `attach: true`). |
| `rp_log` appears in RP but not HTML | This is the RP-only DSL; use AppLog or native `world.log` for both report tracks. |
| No DEBUG/TRACE messages in RP | Widen the UI log-level filter and refresh after the flush interval. |
| ERROR evidence but the Scenario passed | Logging is diagnostic, not an assertion; explicitly assert or raise in your step. |
| An After hook cannot use an earlier capture target | The Step has closed. Capture/report while it is open, or intentionally attach to the current Hook. |
| A passing run has an incomplete receipt | Inspect rejected/pending/spooled/ambiguous/degraded evidence and metadata failures; business and reporting outcomes are separate. |
| Required mode exits `2` with no HTTP traffic | Requested RP configuration may be missing; inspect option names in diagnostics without printing their values. |
| Shared Launch finishes too early | Use CI-owned `RP_LAUNCH_UUID`; do not rely on legacy file join as a completion barrier. |
| Playwright cannot launch | Install the compatible Node CLI and Chromium; SDK installation does not install browsers. |
| Cucumber 11 was selected | Pin the SDK and supported Cucumber range, and run parent/child processes through the same Bundler environment. |
| Replay refuses a transaction | Dry-run first; targets must still be open, endpoint/project must match, and original artifact checksums must validate. |

## Kubernetes / Helm

Chart `1.2.0-rc.2` pins ReportPortal `26.0.5` independently of the Ruby SDK version.
The chart operator guide includes isolated local deployment and an external-Secret
production example with the legacy public video extension disabled. The following historical
setup is a demo, **not a production-safe profile**: its public bucket policy can
grant anonymous writes/deletes, and `makePublic=false` does not revoke a prior
policy. Do not enable that legacy public policy in production without a separate security review.

The repository contains an umbrella chart wrapping the official ReportPortal
chart, a MinIO initialization job, and a same-origin `/automation-videos` Ingress
route. Its historical demo route preserves the bucket path without rewriting;
same-origin routing satisfies the deployed browser access constraints but does
not secure object storage. The `public` bucket policy is not read-only, and
disabling initialization does not revoke an existing policy.

See the [Helm operator README](helm/reportportal-rich-experience/README.md) for
version-specific deployment and migration instructions; the security restrictions above still apply.
Do not treat a successful video demo, TLS verification, or chart package build
as production authorization. No Helm deployment or bucket-policy changes are
needed to run the API/PNG/JSON examples in this README.

## Runtime Dependencies

- `cucumber`: the runtime event bus and formatter integration (`>= 9, < 11`).
- `cucumber-cucumber-expressions`: the existing Cucumber parameter parser, now
  directly constrained to `>=17,<19` for native Cucumber 9/10 HTML/message compatibility.
- `aws-sdk-s3`: compatible S3/MinIO transport for the optional external-video
  route; ordinary image/JSON/text uploads do not use that route.
- `mime-types`: infer content types and appropriate attachment extensions.

The rest uses Ruby's standard library where practical: `Net::HTTP`, `JSON`,
`Time`, `SecureRandom`, `Base64`, `File`, `Mutex`, and `Queue`. HTTP assertion
libraries and `playwright-ruby-client` belong to the consuming automation project.
Install the Node CLI/browser version compatible with your Playwright Ruby gem;
follow the [Playwright Ruby setup guide](https://playwright-ruby-client.vercel.app/docs/article/getting_started).

## Known Limitations

- Legacy file join is same-host only and does not coordinate whole-run completion;
  use the CI-owned `RP_LAUNCH_UUID` contract for cross-worker shared reporting.
- Only legacy local join lets its primary finish the launch; CI-owned UUID workers
  never finish it. CI must finalize after collecting all outcomes and receipts.
- Native Cucumber 9/10 integration uses a private registry association; later
  major versions require separate compatibility work.
- Stable identity, business attributes, and links are opt-in. Identity migration
  creates a new history baseline; it cannot merge or rewrite backend history.
- Browser failure capture, recording finalization, and data privacy remain
  caller-owned. Diagnostic redaction is bounded, not a universal PII filter.
- Queue overload can reject evidence. Receipts expose loss/ambiguity; spooling
  does not mean server delivery, and replay cannot target a finished item/Launch.
- Inline MP4 rendering depends on the RP renderer, codec, browser, and storage
  policy; the unresolved Helm anonymous-permission findings remain a rollout gate.

## License

MIT
