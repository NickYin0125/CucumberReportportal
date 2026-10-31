# Migrating to SDK 2.0 and Cucumber 12

**Status:** SDK 2.0.0 is a source candidate, not a published release. No new tag,
GitHub release or RubyGems publication is authorized by these instructions.
Keep the released 1.3.1 archive/lockfile if you need Cucumber 9 or 10 today.

## Compatibility and release lines

| Line | Ruby requirement | Cucumber requirement | Dependency family | CI source |
| --- | --- | --- | --- | --- |
| SDK 1.x, released 1.3.1 | `>=3.1` | `>=9,<11` | Legacy expressions `>=17,<19` | Immutable v1.3.1 commit; local `maintenance/1.x` is frozen there |
| SDK 2.x, candidate 2.0.0 | `>=3.3` | `>=12.0.1, ~>12.0` | Core 20 / Query 16 and compatible Cucumber dependencies | Current `codex/cucumber-12` checkout, eventually approved `main` |

Cucumber 11 is intentionally outside both contracts. The declared dependency
range does not certify every future release. The current lockfile pins Cucumber
12.0.1; the exact planned CI rows and observed checks are in
[release readiness](cucumber-12-release-readiness.md).

The companion chart stays **Helm 1.3.1**, with **ReportPortal 26.0.7** and the
existing locked upstream chart. SDK 2.0.0 does not require new containers,
Kubernetes changes, storage migrations, a database upgrade or an RP redeployment.
Historical deployment evidence remains evidence for its original source/version,
not a fresh Cucumber 12 certification.

## Update dependencies deliberately

Upgrade the automation project's Ruby before resolving the new bundle.
[Cucumber 12.0.1 requires Ruby >=3.3](https://rubygems.org/gems/cucumber/versions/12.0.1).
Remove its old Cucumber/expressions constraints rather than overriding the SDK gemspec.
The 2.x SDK explicitly declares `base64`, `cgi` and `logger`; do not rely on their
incidental availability as Ruby standard gems or another gem's dependencies.
Let Cucumber 12 resolve its compatible Core, Query, Expressions and Messages
family. In particular, do not retain the 1.x expressions `<19` workaround.

Until an approved 2.0.0 archive is actually released, a **local source-validation
Gemfile**, in a separate consumer project, can contain:

```ruby
source "https://rubygems.org"

gem "cucumber", "~> 12.0", ">= 12.0.1"
gem "reportportal-cucumber-ruby", "= 2.0.0", path: ENV.fetch("SDK_SOURCE")
```

Set `SDK_SOURCE` to the absolute candidate checkout containing the gemspec, not
to a `.gem` file. From that consumer project's root:

```sh
bundle update cucumber reportportal-cucumber-ruby
bundle exec ruby -e 'require "reportportal_cucumber"; puts "Ruby=#{RUBY_VERSION} SDK=#{ReportportalCucumber::VERSION} Cucumber=#{Gem.loaded_specs.fetch("cucumber").version}"'
```

Expected for the current candidate: SDK `2.0.0`, Cucumber `12.0.1`, Ruby `>=3.3`.
Inspect and commit the resulting consumer lockfile only after its own tests pass.
Source validation is not an installed-gem packaging check. After an approved
release exists, replace `path:` with its exact version and use the verified
archive installation workflow from the [getting-started guide](getting-started.md),
substituting only an actually published version. Do not assume a registry install
can fetch the candidate.

## Native log and attach

Keep the SDK require and World inclusion in `features/support/env.rb`. Native
Cucumber 12 calls inside a running Step or Hook are event-driven:

```ruby
Given("I capture a diagnostic") do
  log("Request completed")
  attach("safe diagnostic text", "text/plain", "diagnostic.txt")
  attach(File.binread("artifacts/screenshot.png"), "image/png", "screenshot.png")
end
```

The PNG must already exist and belongs to the test framework. The formatter
consumes Cucumber's log/attachment events; consumers must not call formatter
callbacks or patch Cucumber's runtime internals. Native log messages report at
INFO unless an SDK helper explicitly supplies another level. Binary attachments
must preserve their bytes and MIME type.

Use `AppLog.info(..., report: true)` when you want the existing terminal/native/RP
routing and structured diagnostics. Keep its per-Scenario logger binding from
the [quick start](getting-started.md#3-connect-reportportal-and-integrate-an-existing-project).
`rp_log` and `rp_attach` remain RP-only helpers. Choose one route per evidence item,
not both a native call and an RP helper for the same item. Logging ERROR does not
perform an assertion or fail the Scenario.

Publish evidence while its owning Step/Hook is open. An After-hook screenshot
belongs to that Hook, not to an already-closed failed Step. Keep file-backed
evidence until final reporting settles; retain redaction, secret handling and
caller-owned browser/video cleanup.

### Threaded native evidence boundary

Call native `log` and `attach` on the **Step/Hook execution thread**. Starting a
worker and joining it does not transfer that native ownership. Return the
worker's results or artifact bytes to the execution thread when evidence is
needed in both native HTML/messages and ReportPortal:

```ruby
result = Thread.new do
  { message: "Worker diagnostic", bytes: "safe diagnostic text" }
end.value

log(result.fetch(:message))
attach(result.fetch(:bytes), "text/plain", "worker-diagnostic.txt")
```

For failure evidence that must be submitted **from a worker**, capture its target
on the execution thread while the owning action is still open. Pass that target
explicitly to `rp_evidence`, check its Boolean admission result, and join the
worker before the Step/Hook ends. This RP-only path does **not** bridge evidence
into native HTML/messages. The following body belongs inside an open Step/Hook;
replace the synthetic error with the actual original worker failure:

```ruby
target = rp_capture_target
worker = Thread.new do
  error = RuntimeError.new("Worker request failed")
  admitted = rp_evidence(action: "worker request", error: error, target: target)
  [error, admitted]
end

error, admitted = worker.value
warn("Worker evidence was not admitted") unless admitted
raise error
```

The example preserves the original business error rather than replacing it with
a reporting exception. An admitted record is not proof of server delivery; the
final receipt still governs completeness. Do not publish after the captured
action closes or use an explicit RP-only call as a promise of native HTML output.
For an artifact needed in both tracks, prefer returning it for the owner-thread
native path instead of sending the same artifact again through both routes.

Unowned native evidence is rejected visibly, not silently counted as complete:

| Business result and reporting policy | Cucumber exit/result |
| --- | --- |
| Business passed; unowned evidence rejected; `RP_REQUIRE_COMPLETE_REPORTING=true` | Exit `2`, reporting incomplete |
| Business passed; same rejection; best-effort reporting | Exit `0`, warning and incomplete reporting |
| Original business failure, regardless of that reporting rejection | Exit `1`, original business failure preserved |

## Remove strict mode

Remove `--strict`, `--no-strict` and old strict-mode configuration from Cucumber
profiles and wrappers. Do not reintroduce removed Cucumber methods to change
status mapping. SDK 2.x uses native outcome events:

| Native outcome | ReportPortal outcome |
| --- | --- |
| Passed | `PASSED` |
| Failed, undefined, pending or ambiguous | `FAILED` |
| Skipped | `SKIPPED` |
| Interrupted/aborted execution | `INTERRUPTED` |

This is unrelated to `RP_REQUIRE_COMPLETE_REPORTING` and
`RP_FAIL_ON_REPORTING_ERROR`, which govern delivery completeness and synchronous
reporting errors. Keep real business assertions and preserve Cucumber's exit code.

Retries remain Cucumber-owned (`--retry` and `--retry-total`). Attempt completion
uses `willBeRetried`; a failed attempt scheduled for retry is not an independent
final Launch failure. Each attempt's evidence must remain with that attempt.
The QA acceptance checks, not this guide, establish which cases were observed.

## Optional Rule hierarchy

Rule suites are opt-in. The default `RP_RULE_SUITES=false` keeps the existing
**Feature -> Scenario** hierarchy stable. To group Scenarios under their Gherkin
Rule, enable it for the same formatter command:

```sh
RP_RULE_SUITES=true bundle exec cucumber --format ReportPortal::Cucumber::Formatter
```

The hierarchy becomes **Feature -> Rule -> Scenario**. Rules with duplicate
names remain distinct by their source line. Each Scenario/Examples row is still
the statistical test: its wire type remains `STEP` with `hasStats=true`; adding a
Rule suite does not add another statistical test or change Step/Hook ownership.

## Parallel Launch ownership

For SDK 2.x, an enabled `ReportPortal::Cucumber::ParallelFormatter` requires a
CI-owned `RP_LAUNCH_UUID`. It does not elect a primary process, start a shared
Launch, finish a shared Launch, or provide a distributed completion barrier.
Legacy file join is not a substitute for this contract.

The parent CI process must create exactly one Launch, inject its original UUID
and the same endpoint/project into every worker, retain each worker's status and
receipt, wait for every worker (including failed/missing/timed-out workers), then
finish the Launch. A numeric UI ID is not the UUID. Do not combine a supplied UUID
with `RP_RERUN`/`RP_RERUN_OF` or reuse an already-finished Launch.

Once the parent has injected an open `RP_LAUNCH_UUID`, **each worker** can run:

```sh
mkdir -p artifacts
RP_ENABLED=true RP_CLIENT_JOIN=false RP_REQUIRE_COMPLETE_REPORTING=true \
  bundle exec cucumber --no-profile --publish-quiet \
  --format progress \
  --format ReportPortal::Cucumber::ParallelFormatter --out artifacts/reportportal.out
```

Use unique output/receipt/spool paths per worker. The command deliberately does
not create or finish the Launch. Preserve the genuine worker exit code when
collecting artifacts; a complete worker receipt does not prove that the parent
finished the Launch. See the [CI ownership sequence](ci.md#parallel-workers-and-a-shared-launch).

For independent per-process Launches, use `ReportPortal::Cucumber::Formatter`
with `RP_CLIENT_JOIN=false` and no supplied UUID instead. This intentionally
creates separate reports, not a coordinated shared Launch.

## Verify before adoption

Run `bundle exec rspec` and `bundle exec cucumber` from the source checkout, then
test an independently installed candidate gem in a clean consumer environment.
Check real HTTP payloads for hierarchy IDs, timestamps, native/binary evidence,
hook ownership, all nonpassing statuses, retries and parallel parent ownership.
Mocked HTTP checks do not certify a live RP service, a browser recording or an
infrastructure upgrade. Record exact runtimes and commands; see
[release readiness](cucumber-12-release-readiness.md) for planned versus observed
evidence and the separate acceptance review.

For rollback, restore the previous consumer Gemfile/lockfile and the immutable
1.3.1 archive together with a compatible Ruby/Cucumber environment. Do not move a
release tag or change the 2.x gemspec to force Cucumber 9/10 into that release line.
