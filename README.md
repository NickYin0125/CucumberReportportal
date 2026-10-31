# reportportal-cucumber-ruby

Report Ruby Cucumber tests to ReportPortal, with readable Feature/Scenario/Step
structure, API request/response diagnostics, and screenshots owned by your tests.
Use the same `AppLog` calls for the terminal, native Cucumber HTML/messages, and
ReportPortal.

**New here?** Follow the five steps below. The
[complete getting-started guide](docs/getting-started.md) runs one Scenario without
a browser or a ReportPortal server before connecting your real project.

| What you need | Requirement |
| --- | --- |
| Ruby | `>= 3.1` |
| Cucumber | `>= 9, < 11` |
| Package | `reportportal-cucumber-ruby` **1.3.1**, from the GitHub release |
| ReportPortal | Your endpoint, project, and API key when enabling remote reporting |
| Browser tooling | Optional; belongs to your UI test project |

The SDK records tests and evidence. Your framework makes HTTP requests, performs
assertions, and owns browser/screenshot/video lifecycles. Logging an ERROR does
not fail a Scenario.

## 1. Install the released gem

Download the `.gem` asset from [v1.3.1](https://github.com/NickYin0125/CucumberReportportal/releases/tag/v1.3.1).
RubyGems.org publication is separate; use the release archive and an exact version
pin rather than assuming a registry install selects this release.

From **your automation project root**:

```sh
mkdir -p vendor/cache
curl -fL -o vendor/cache/reportportal-cucumber-ruby-1.3.1.gem \
  https://github.com/NickYin0125/CucumberReportportal/releases/download/v1.3.1/reportportal-cucumber-ruby-1.3.1.gem
gem install ./vendor/cache/reportportal-cucumber-ruby-1.3.1.gem --no-document
```

Add these entries to that project's `Gemfile`, then run `bundle install` from the
same directory:

```ruby
source "https://rubygems.org"
gem "cucumber", ">= 9", "< 11"
gem "reportportal-cucumber-ruby", "= 1.3.1"
```

Verify, still from **your project root**:

```sh
bundle exec ruby -e 'require "reportportal_cucumber"; puts ReportportalCucumber::VERSION'
```

Expected output: `1.3.1`. Installation may download dependencies; offline setup
requires all of them to be cached. See [installation details](docs/getting-started.md#1-install-the-release).

## 2. Run one minimal Scenario

[Copy the three files in the quick start](docs/getting-started.md#2-run-one-scenario-locally):
a Feature, `features/support/env.rb`, and a step-definition file. They perform
simple arithmetic and publish one structured diagnostic.

From **the quick-start project root**, after creating those files:

```sh
mkdir -p artifacts
RP_ENABLED=false bundle exec cucumber --no-profile --publish-quiet \
  --format progress \
  --format html --out artifacts/cucumber.html \
  --format message --out artifacts/messages.ndjson \
  --format ReportPortal::Cucumber::Formatter --out artifacts/reportportal.out
```

Expected: **1 Scenario / 2 steps passed**, exit `0`, and a `Sum result` diagnostic
inside the Then step in native HTML/messages. No Node, browser, or RP service is
needed. `reportportal.out` is a separate formatter destination and may be absent;
it is not an RP report or delivery receipt.

## 3. Connect an existing Cucumber project

Add to **your project's `features/support/env.rb`**:

```ruby
require "reportportal_cucumber"
World(ReportportalCucumber::Cucumber::World)

Around do |_scenario, run|
  AppLog.with_logger(Automation::CucumberLogger.new(world: self)) { run.call }
end
```

Bind once per Scenario; use `AppLog` from your steps, clients, and page objects.
Inject `RP_ENDPOINT`, `RP_PROJECT`, and `RP_API_KEY` through your normal secret
management, then run the same formatter command with `RP_ENABLED=true`.

Expected in RP: **Launch → Feature → Scenario → Step/Hook → logs and attachments**.
Each Scenario/Examples row counts as one test; its Steps and Hooks carry evidence.
The wire Scenario type is `STEP` with `hasStats=true`, rather than `TEST`.

See the [file-by-file integration recipe](docs/getting-started.md#3-connect-reportportal-and-integrate-an-existing-project)
for configuration, Cucumber profiles, and the first-report checklist.

## 4. Add API and UI evidence as needed

Start with [API, UI, and logger best practices](docs/best-practices.md). For a
runnable HTTP + Chromium project, use the
[current SDK example](examples/current_sdk/README.md) after the minimal Scenario.

| Need | Recommended call | Where it appears |
| --- | --- | --- |
| Local debugging | `AppLog.debug("message")` | Terminal |
| Business checkpoint / small JSON | `AppLog.info("message", report: true, json: payload)` | Terminal summary, native reports, RP |
| Observed HTTP exchange | `AppLog.http(...)` | All three tracks by default; performs no request |
| Expected/actual diagnostic | `AppLog.assertion(...)` | All three tracks by default; performs no assertion |
| Screenshot in native reports and RP | `AppLog.error("failure", report: true, file: path)` | All three tracks |
| RP-only artifact or manual group | `rp_attach(...)` / `rp_step("name") { ... }` | RP |
| Explicit RP failure ownership | `rp_capture_target` + `rp_evidence(...)` | The captured, still-open Step/Hook |

The report tracks require a bound World. Ordinary level methods are
terminal-only unless `report: true` (or legacy `attach: true`) is supplied.
Use one route per artifact to avoid submitting it twice. Publish Step evidence
before that Step closes; an After-hook screenshot belongs to the After Hook.
Keep file-backed evidence until reporting finalization settles.

Example of Step logs and a Gherkin table rendered in ReportPortal:

![Scenario Step logs and table in ReportPortal](docs/reviews/assets/reportportal-26.0.5-table.png)

This existing screenshot comes from the [2026-10-12 compatibility run](https://github.com/NickYin0125/CucumberReportportal/blob/main/docs/reviews/2026-10-12-reportportal-26.0.5-compatibility.md)
on ReportPortal 26.0.5; it illustrates the layout, not a new validation of your
server or the quick-start Scenario.

Terminal summaries include local date/time with milliseconds and aligned levels;
TTY colors are preserved, with no `[APPLOG]` prefix:

```text
2026-10-31 14:32:08.125  INFO   Order submitted
2026-10-31 14:32:09.438  WARN   Retrying request
```

Timestamps are terminal-only; native Cucumber and RP messages stay clean.
For source-checkout previews and the nine parameter combinations, see
[the logger examples](docs/best-practices.md#preview-terminal-and-report-routing).

## 5. Configure CI

[CI guide](docs/ci.md): pin dependencies, preserve the Cucumber exit status,
retain native evidence on failure, and decide whether reporting completeness is
required. Start with **one Launch per job**. For a shared parallel Launch, CI
creates it, injects its `RP_LAUNCH_UUID` into every worker, waits for every worker's
outcome and receipt, and completes it. Workers do not start or finish that Launch.

## Choose the next guide

| Topic | Guide |
| --- | --- |
| Complete minimal project, existing-project integration, first-report troubleshooting | [Getting started](docs/getting-started.md) |
| HTTP clients, Playwright, screenshots, logger levels/routing, safe assertions | [Best practices](docs/best-practices.md) |
| Job setup, artifacts, reporting gates, shared Launch ownership | [CI](docs/ci.md) |
| YAML keys, environment variables, defaults, units, profiles | [Configuration reference](docs/configuration.md) |
| Receipts, bounded queues, durable spool/replay, identities, attributes, links, video | [Advanced reporting](docs/advanced-reporting.md) |
| Current examples versus source QA and historical fixtures | [Examples index](examples/README.md) |
| Deploying the separate ReportPortal stack | [Helm operator guide](helm/reportportal-rich-experience/README.md) / [Compose guide](deploy/compose/README.md) |
| Release changes | [Changelog](CHANGELOG.md) |
| Design contracts and dated verification | [Historical evidence index](docs/design/README.md) |

## ReportPortal deployment from source

The companion Chart **1.3.1** pins ReportPortal **26.0.7** and official chart
**26.10.26**, requiring **Kubernetes >=1.35**. Download SDK and Chart **1.3.1**
from the [v1.3.1 Release](https://github.com/NickYin0125/CucumberReportportal/releases/tag/v1.3.1),
or build the chart from this checkout. The root `docker-compose.yml` provides an isolated
local alternative with the same read-only video policy and retention.
See the deployment guides above for credentials, storage, migration constraints
and the archived MinIO image caveat; this is not production HA certification.
The [26.0.7 compatibility record](https://github.com/NickYin0125/CucumberReportportal/blob/main/docs/reviews/2026-10-31-reportportal-26.0.7-compatibility.md)
documents the real Helm/Compose, attachment and Playwright playback checks.

## Developing the SDK

From **an SDK source checkout**, with Ruby/Bundler installed:

```sh
bundle install
RUBYOPT=-rbundler/setup bundle exec rspec -Ilib -Ispec spec
bundle exec cucumber
```

Expected: RSpec and the default Cucumber suite complete successfully for a healthy
checkout. These are developer checks; consumers do not need the root development
bundle. Browser/live RP/duration checks are separate opt-ins in the
[examples index](examples/README.md).

The gem uses Cucumber, `cucumber-cucumber-expressions` (`>=17,<19`), `mime-types`,
and `aws-sdk-s3` for optional S3 video delivery. Cucumber 11 is unsupported.
Declared Ruby `>=3.1` compatibility is not a claim that every Ruby version was
tested. The historical [v1.3.0 release acceptance](https://github.com/NickYin0125/CucumberReportportal/blob/main/docs/reviews/2026-10-13-v1.3.0-release-acceptance.md)
records the environment and checks for that release.

## License

MIT

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

Terminal summaries use local date/time with millisecond precision and aligned
levels, without the `[APPLOG]` prefix:

```text
2026-10-14 14:32:08.125  INFO   Order submitted
2026-10-14 14:32:09.438  WARN   Retrying request
2026-10-14 14:32:12.016  ERROR  Payment failed
```

Colors remain automatic on a TTY; set `NO_COLOR=1` to disable them. This is a
terminal-only format and does not add timestamps to Cucumber or RP message bodies.
Preview it without Cucumber or an RP connection with
`bundle exec ruby examples/logger_terminal_preview.rb`.

For nine runnable `AppLog.info` parameter combinations, use
`bundle exec ruby examples/logger_parameters_demo.rb`. This defaults to offline
Cucumber HTML/messages reporting. Add `--live` after setting `RP_ENDPOINT`,
`RP_PROJECT`, and `RP_API_KEY` to create a real RP launch; only examples 02-06
should contain report evidence. The script prints its unique launch name and
report directory. `json:` and `file:` do not enable reporting on their own.

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
>>>>>>> codex/reportportal-26-0-7
RUBYOPT=-rbundler/setup bundle exec rspec -Ilib -Ispec spec
bundle exec cucumber
```

Expected: RSpec and the default Cucumber suite complete successfully for a healthy
checkout. These are developer checks; consumers do not need the root development
bundle. Browser/live RP/duration checks are separate opt-ins in the
[examples index](examples/README.md).

The gem uses Cucumber, `cucumber-cucumber-expressions` (`>=17,<19`), `mime-types`,
and `aws-sdk-s3` for optional S3 video delivery. Cucumber 11 is unsupported.
Declared Ruby `>=3.1` compatibility is not a claim that every Ruby version was
tested. The historical [v1.3.0 release acceptance](https://github.com/NickYin0125/CucumberReportportal/blob/main/docs/reviews/2026-10-13-v1.3.0-release-acceptance.md)
records the environment and checks for that release.

## License

MIT
