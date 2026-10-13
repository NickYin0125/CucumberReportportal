# Current SDK automation lab

A complete, small Cucumber project for **`reportportal-cucumber-ruby` 1.3.0**,
installed from its GitHub release archive or an independently built archive.
The default suite makes real HTTP requests and drives real Chromium
against a deterministic loopback fixture. ReportPortal (RP) is explicitly disabled
until you opt in. No video, mocks-only browser substitute, hidden credentials, or
deployment changes are involved.

## Install As An Independent Consumer

Use Ruby >= 3.1 (validated with 3.4.2), Bundler >= 2.6, and Node.js >= 20/npm.
**Copy this project outside the SDK checkout before setup or execution.** The
SDK gemspec includes `examples/**/*`, even ignored generated files. Never install
dependencies or generate reports under the source example directory. The scripts
refuse to run in that directory; raw Cucumber bypasses that guard.

```sh
SDK=/absolute/path/to/CucumberReportportal
WORK=$(mktemp -d "${TMPDIR:-/tmp}/current-sdk-consumer.XXXXXX")
cp -R "$SDK/examples/current_sdk" "$WORK/project"
cd "$SDK"
gem build reportportal-cucumber-ruby.gemspec --output "$WORK/reportportal-cucumber-ruby-1.3.0.gem"
cd "$WORK/project"
export GEM_HOME="$WORK/gems"
export GEM_PATH="$GEM_HOME:$(ruby -e 'puts Gem.default_path.join(":")')"
export PATH="$GEM_HOME/bin:$(ruby -e 'puts Gem.default_bindir'):$PATH"
export SDK_GEM_ARCHIVE="$WORK/reportportal-cucumber-ruby-1.3.0.gem"
export EXPECTED_SDK_INSTALL_ROOT="$GEM_HOME"
export SDK_SOURCE_ROOT="$SDK"
export RP_ENABLED=false
ruby bin/setup "$SDK_GEM_ARCHIVE"
bundle exec ruby bin/verify
```

`bin/setup` performs a normal `gem install` of the archive, then `bundle install`
using the version-pinned **Gemfile without a path dependency**. A Bundler `path:`
must reference an unpacked project containing a gemspec, never a `.gem` archive.
For a separate developer workflow, `BUNDLE_GEMFILE=/absolute/path/to/the/copied/project/Gemfile.source`
selects `path: ENV.fetch("SDK_SOURCE_ROOT", "../..")`; set `SDK_SOURCE_ROOT` to
your checkout after copying. That does
not validate packaging and is not used by acceptance.

Setup installs `playwright-core` at the version derived from
`Playwright::COMPATIBLE_PLAYWRIGHT_VERSION`, then Chromium. The Ruby client is
pinned to **1.62.0**; its compatible CLI in the executed checks was **1.62.1**.
See the [official Ruby getting-started guide](https://playwright-ruby-client.vercel.app/docs/article/getting_started).
Existing tooling may be reused with `SKIP_BROWSER_SETUP=true`, an absolute
`PLAYWRIGHT_CLI_EXECUTABLE_PATH`, and `PLAYWRIGHT_BROWSERS_PATH`. The helper quotes
the CLI path because this Ruby client's driver invocation uses a command string.
For cached/offline installs, `GEM_INSTALL_LOCAL=true BUNDLE_LOCAL=true` requires
the dependencies already to be available. First-time installation needs network
access; the ordinary suite itself does not need an external service.

### Cucumber Compatibility Lanes

The SDK requires Cucumber **>= 9, < 11**, not Cucumber 11. Use a separate consumer
copy/lockfile for each lane:

```sh
CUCUMBER_VERSION='= 9.2.1' ruby bin/setup "$SDK_GEM_ARCHIVE"
CUCUMBER_VERSION='= 9.2.1' bundle exec ruby bin/verify
```

Repeat in another copy with `CUCUMBER_VERSION='= 10.2.0'`. The default is `~> 10.0`.
Do not reuse a lockfile resolved for another lane without explicitly updating it.
The example caps `cucumber-cucumber-expressions` below 19: Cucumber 10.2.0 with
19.x crashes while serializing parameter groups into native HTML/messages.
The SDK also applies this dependency cap. It is not an SDK monkey patch; the upstream
[Cucumber changelog](https://github.com/cucumber/cucumber-ruby/blob/main/CHANGELOG.md)
records the nil-children fix after 10.2.0. Do not solve this by upgrading to
unsupported Cucumber 11.
Native HTML 22.3.0 serializes `<` in Ruby failure backtraces as literal `x3C`.
Acceptance normalizes that known trace-text representation and each formatter's
independent run/start IDs and timestamps; it compares attachment bodies, Step
owners, statuses, original exception type/message, and screenshot bytes unchanged.
Raw NDJSON preserves the original trace; no SDK or Cucumber code is patched.

## Run And Read The Evidence

```sh
bundle exec ruby bin/run                 # offline: 5 scenarios, expected exit 0
bundle exec ruby bin/run api             # 4 API scenarios, expected exit 0
bundle exec ruby bin/run ui              # 1 deterministic UI scenario, exit 0
bundle exec ruby bin/run intentional     # 1 missing-locator scenario, exit 1
bundle exec ruby bin/verify              # validates both exits and evidence
bundle exec ruby bin/check_fixture       # HTTP status and request-size checks
bundle exec ruby bin/check_config        # credential-free endpoint policy checks
bundle exec ruby bin/check_rerun         # two passes, preserving a spool sentinel
bundle exec ruby bin/runtime             # installed path/version/SHA-256 manifest
```

`intentional` is a genuine failing run. `bin/run` returns Cucumber's exit status,
never converts a failure into success. Only `bin/verify` treats **exactly exit 1,
one failed locator step, the original Playwright TimeoutError, and one valid Hook
screenshot** as an expected negative test. Unexpected ordinary-suite failures,
skipped/undefined/pending steps, missing screenshots, or wrong failure counts fail
acceptance. Reports remain available for both runs. RP is forcibly disabled for
this acceptance command, regardless of inherited credentials. Acceptance also
reruns the passing suite with `NO_COLOR=1`, checks the ordinary transcript has
cyan INFO and one-line DEBUG/INFO summaries, and rejects rich JSON/Markdown
request/response bodies leaking into either console transcript.

Each run writes `progress.txt`, `summary.txt`, `cucumber.html`, and `messages.ndjson`
under `artifacts/<profile>/<unique-run>`. The RP formatter is configured with a
distinct `reportportal.txt` output path, but the current formatter does not write
to Cucumber's output stream, so that file may not be created at all. Console
AppLog lines are compact and colored; `NO_COLOR=1` disables their ANSI colors.
`REPORT_DIR=/absolute/external/path` overrides a run's destination;
`VERIFY_OUTPUT=/absolute/external/path` chooses the parent for unique acceptance
run directories. An explicitly supplied `REPORT_DIR` must be new/empty; the runner
refuses to overwrite existing evidence. Verification compares spool inventories
before/after rather than deleting or rejecting evidence from earlier RP runs.
`check_rerun` leaves its synthetic sentinel in place. Treat reports as private.
The RP formatter output is not an RP delivery receipt or a server UI export.

Equivalent direct command, **from the external consumer copy**:

```sh
mkdir -p artifacts/manual
RP_ENABLED=false REPORT_DIR=artifacts/manual bundle exec cucumber \
  --no-profile --publish-quiet --require features --tags 'not @intentional_failure and not @live' \
  --format progress --out artifacts/manual/progress.txt \
  --format summary --out artifacts/manual/summary.txt \
  --format html --out artifacts/manual/cucumber.html \
  --format message --out artifacts/manual/messages.ndjson \
  --format ReportportalCucumber::Cucumber::Formatter --out artifacts/manual/reportportal.txt
```

### Optional Typewords Target

With Typewords already running at `http://localhost:5567/`:

```sh
TYPEWORDS_URL=http://localhost:5567/ bundle exec ruby bin/run live
```

This is a real Chromium navigation/title smoke check, not a deterministic
Typewords business-flow test. It is excluded from the default suite and may fail
when your local app is unavailable or changes. It accepts only credential-free
loopback HTTP URLs. The offline practice page is deliberately not represented as
Typewords. UI failures in either target use the same framework-owned screenshot
hook. Successful live screenshots are opt-in: `TYPEWORDS_SCREENSHOT=true` saves
`typewords.png` and attaches it to the title-check Step. Use `RP_ENABLED=false`
to keep it local; if RP is enabled, this evidence is also forwarded there. Review
the app for personal data first and keep these reports private.

## Project Organization And APIs

- `features/api.feature`: Background, JSON DocString, response DataTable,
  Scenario Outline, 201/200 success, and the expected 400 validation contract.
- `features/ui.feature`: accessible Playwright locators, actual input/click, a
  passing local flow, and a separately tagged missing-locator failure.
- `features/live.feature`: optional Typewords smoke check.
- `features/step_definitions/`: thin intent-level steps; no infrastructure setup.
- `features/support/env.rb`: fixture lifecycle, logger binding, browser setup,
  framework-owned After evidence, and ensure-based cleanup.
- `helpers/`: bounded stdlib fixture, API client, UI action/evidence helpers,
  business assertions, and command guards. No new heavyweight SDK dependency.
- `config/reportportal.yml`, `cucumber.yml`, `bin/`: explicit defaults, profiles,
  setup, exit-preserving runner, runtime provenance, and rerunnable acceptance.

The fixture binds an ephemeral IPv4 loopback port. It accepts one connection at a
time, limits headers to 16 KiB and bodies to 8 KiB, caps each connection at two
seconds, and bounds shutdown. The API client performs actual `Net::HTTP` requests
with open/read/write timeouts. **`AppLog.http` records an observed exchange; it
does not perform the request or assert anything.** The deep client helper also
uses `AppLog.debug(..., report: true)` and `AppLog.info(..., json: ..., report: true)`.
Binding a logger to the scenario World makes those messages follow the currently
executing step without passing the World through every helper. `attach: true`
also enables rich reporting on level methods; an explicit `report:` overrides it.

`expected_status: 400` makes the observed matching 400 an INFO diagnostic.
Without an expectation, a 4xx/5xx is WARN; an explicit status mismatch is ERROR.
Neither diagnostic severity changes Cucumber's result. `AppLog.assertion` also
only records a comparison, even with `passed: false`. `check_equal` deliberately
raises separately to enforce business contracts. The last API scenario proves a
nonfatal diagnostic comparison can be ERROR while its expected-400 contract passes.

### Failure Targets And Attachments

`ui_action` saves the action name and original exception, then uses bare `raise`.
The framework After hook screenshots before the enclosing Around ensure closes
page/context/browser. `AppLog.error(file: ..., report: true)` sends the PNG to
native Cucumber HTML/messages and, when enabled, the RP event pipeline. Structured
`rp_evidence(action:, error:, url:, details:, target:)` adds the RP diagnostic to
the **currently open After Hook**, captured with `rp_capture_target`. The JSON
attachment records the original action, exception class, known Hook target, and
whether RP evidence was accepted (false when RP is disabled).

The failed Gherkin step is already closed when After runs. Do not save its handle
and claim late evidence attached to that step: closed, cross-runtime, or invalid
targets are rejected. Capture/publish inside a still-open action if precise step
attribution is needed; otherwise use the explicitly identified Hook as here.
`rp_evidence` also accepts `artifacts: [{path: screenshot, name: "failure.png",
mime: "image/png"}]` for RP-only publication. This example does not pass the same
PNG twice, because AppLog already routes its native attachment to RP.
`rp_log`/`rp_attach` are RP-only APIs, not replacements for native evidence;
`rp_step(name) { ... }` is available for manual actions but unnecessary here.
Cleanup/evidence errors must not replace the original browser failure. The logger
scope restores in ensure, and AfterAll checks for leakage and stops the fixture.

## Opt In To Real ReportPortal

Only use an endpoint/project/key explicitly authorized for this run. Obtain the
key through your normal approved secret-management process, not from hidden
files, another application's session, or browser storage. Do not put keys in this
project, shell history, screenshots, command-line arguments, or committed YAML.
Supply these variables through your secret manager/CI environment:

```sh
export RP_ENABLED=true
export RP_ENDPOINT=https://reportportal.example.test
export RP_PROJECT=your_project
# RP_API_KEY must already be securely injected; no credential value goes here.
bundle exec ruby bin/run offline
```

For the existing local-development RP service, with an authorized key already
in `RP_API_KEY`, explicit loopback HTTP opt-in is supported:

```sh
RP_ENABLED=true RP_ALLOW_LOCAL_HTTP=true RP_ENDPOINT=http://localhost \
  RP_PROJECT=your_project bundle exec ruby bin/run offline
```

The runner requires all three RP settings and a credential-free HTTPS endpoint,
or `RP_ALLOW_LOCAL_HTTP=true` for **only** `localhost`/`127.0.0.1` HTTP. Non-loopback
HTTP, URL userinfo, query strings, and fragments remain rejected. The opt-in does
not make HTTP encrypted; use HTTPS for production and protect local forwarding.
The SDK permits configurations beyond this example; the sample's HTTPS check is
not a universal SDK policy enforcement claim. `join: false`/`RP_CLIENT_JOIN=false`
is the default. Do not use shared-file legacy join as an exactly-once CI lifecycle
guarantee. For parallel CI, the orchestrator creates one launch, injects its
existing **`RP_LAUNCH_UUID`** into every shard, waits for every shard and reporting
outcome, and finishes that launch exactly once itself. Shards do not finish a
CI-owned launch. Never reuse a stale UUID or combine it with rerun launch creation.

### What To Check In The RP UI

After an authorized RP-enabled run, open your RP UI/project and the newest
**Current SDK examples** Launch (or your `RP_LAUNCH` override). The ordinary
`offline` profile should contribute **5 passed Scenarios across two Feature
suites**, not one test per Gherkin operation. Then:

1. Open the API Feature's Passed count and select an Examples iteration or the
   expected-validation-error Scenario. Expand its Step in Log View; request/response
   Markdown and the API response JSON should be inside that Step.
2. Include DEBUG in the level filter to see `API helper is sending`. The expected
   HTTP 400 is INFO; the explicitly nonfatal diagnostic comparison is ERROR while
   its business Scenario remains PASSED.
3. Run the `intentional` profile separately with RP enabled; its exit `1` is
   deliberate. Open the failed UI Scenario and expand the After Hook to find
   `failure.png` and `failure-routing.json`, alongside the original action/error.
   Click the PNG attachment to preview it. Do not expect that late screenshot in
   the already-closed failed Step.
4. Compare with native HTML/messages in the printed artifact directory. Refresh
   RP after its batching/backend delay; `reportportal.txt` is not a log viewer.

These are **manual acceptance expectations**, not a claim that this task checked
a real RP service. The fresh executable verification below used RP disabled.

`RP_REQUIRE_COMPLETE_REPORTING=true` is a **separate optional reporting gate**,
not a business assertion or proof that the RP UI was checked. The finalized SDK
`reporting_receipt` exposes actual fields including `cutoff`, `confirmed`,
`spooled`, `pending`, `rejected`, `ambiguous`, `possible_duplicates`,
`metadata_failures`, and `complete`; incomplete reporting may fail an otherwise passing run when this gate
is enabled. Local acceptance leaves it false. Delivery retries/ambiguous responses
do not provide an exactly-once delivery guarantee. Retained spool data is not the
same as completed delivery; control private spool access and retention separately.

Structured HTTP and assertion evidence have bounded redaction/preview policies.
Those are not universal sanitizers: **arbitrary AppLog text/JSON, native logs,
attachments, and screenshot pixels can contain secrets or personal data**. Only
synthetic nonsecret fixture data is logged here. Review/redact at the producer
before using a live application; do not assume native HTML is sanitized by RP.
This project does not use MinIO or video. If you separately enable SDK storage,
use authorized least-privilege credentials, HTTPS, peer verification/trusted CA,
private objects, approved public-link policy, and retention controls. Never rely
on development storage defaults or disable TLS verification to fix trust errors.

See [verification.md](verification.md) for freshly executed checks and limitations.
