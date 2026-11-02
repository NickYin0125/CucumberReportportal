# Getting started

**Version scope:** this guide installs the unpublished SDK **2.0.2** candidate
from a matching maintainer-supplied or locally built archive, not an invented
release URL. Use Ruby `>=3.3` and Cucumber `>=12.0.1, ~>12.0`; see the
[migration guide](migrating-to-2.0.md) when moving from 1.x.

Follow **install the candidate, run one local Scenario, integrate an existing
project, add API/UI evidence, then run in CI**. Steps 1-2 need only Ruby, Bundler
and the gems. Browser tooling, Node, ReportPortal and an SDK source checkout are
not required to consume a supplied archive.

## 1. Install the candidate

From **a directory where you keep projects**, create a fresh consumer project.
Set the archive path to the exact candidate supplied by your maintainer; verify
its checksum and source provenance before installation. There is no assumed
2.0.2 tag, release asset or RubyGems publication.

```sh
export SDK_GEM_ARCHIVE=/absolute/path/to/reportportal-cucumber-ruby-2.0.2.gem
mkdir -p rp-smoke/vendor/cache rp-smoke/features/support rp-smoke/features/step_definitions
cd rp-smoke
cp "$SDK_GEM_ARCHIVE" vendor/cache/reportportal-cucumber-ruby-2.0.2.gem
gem install ./vendor/cache/reportportal-cucumber-ruby-2.0.2.gem --no-document
```

Expected: the candidate archive is in `rp-smoke/vendor/cache`, and RubyGems
installs `reportportal-cucumber-ruby-2.0.2` plus missing dependencies.

Create **`rp-smoke/Gemfile`**:

```ruby
source "https://rubygems.org"

gem "cucumber", "~> 12.0", ">= 12.0.1"
gem "reportportal-cucumber-ruby", "= 2.0.2"
```

From **`rp-smoke/`**:

```sh
bundle install
bundle exec ruby -e 'require "reportportal_cucumber"; puts ReportportalCucumber::VERSION'
```

Expected: Bundler resolves supported Cucumber 12 and the installed or cached
candidate; the version check prints `2.0.2`. Commit `Gemfile.lock` in your
real test project. Existing published archives remain unchanged.

First-time installs need network access. `gem install --local` and
`bundle install --local` require **all** dependencies to be cached. For source
development, Bundler `path:` points to a gemspec directory, never a `.gem`.
See the [isolated source-packaging workflow](../examples/current_sdk/README.md#source-and-packaging-verification)
to build a candidate yourself.

Presentation defaults remain `RP_PRESENTATION=plain` and `RP_RUN_CONTEXT=false`.
See [configuration](configuration.md#presentation-and-run-context) for the
independent RP-only rich and allowlisted Launch-context opt-ins.

## 2. Run one Scenario locally

Create these three files inside **`rp-smoke/`**.

**`features/reporting.feature`**:

```gherkin
Feature: Reporting smoke test
  Scenario: Show a useful diagnostic
    Given I add 2 and 3
    Then the sum is 5
```

**`features/support/env.rb`**:

```ruby
require "reportportal_cucumber"

World(ReportportalCucumber::Cucumber::World)

Around do |_scenario, run|
  AppLog.with_logger(Automation::CucumberLogger.new(world: self)) { run.call }
end
```

**`features/step_definitions/reporting_steps.rb`**:

```ruby
Given("I add {int} and {int}") do |left, right|
  @sum = left + right
end

Then("the sum is {int}") do |expected|
  AppLog.info("Sum result", report: true, json: {expected: expected, actual: @sum})
  raise "Unexpected sum: #{@sum}" unless @sum == expected
end
```

From **`rp-smoke/`**:

```sh
mkdir -p artifacts
RP_ENABLED=false bundle exec cucumber --no-profile --publish-quiet \
  --format progress \
  --format html --out artifacts/cucumber.html \
  --format message --out artifacts/messages.ndjson \
  --format ReportPortal::Cucumber::Formatter --out artifacts/reportportal.out
```

Expected: **1 Scenario / 2 steps passed**, exit `0`. The terminal prints a compact
`2026-10-31 14:32:08.125  INFO   Sum result` line. Open `artifacts/cucumber.html`, expand the Then
step, and find the fenced JSON with expected/actual `5`; `messages.ndjson` contains
the same native evidence. `RP_ENABLED=false` deliberately disables RP transport
while leaving native reporting operational.

Each formatter after `progress` has its own `--out`, and its parent directory
exists. The RP formatter does not write an output stream there, so
`reportportal.out` may not exist. It is neither an RP log viewer nor a delivery
receipt. Native `progress` can also echo the Markdown/JSON from `world.log` to
STDOUT; AppLog's one-line summary does not suppress another formatter's output.
`pretty` additionally shows Gherkin text. For a terminal containing only AppLog
summaries, redirect native formatters to separate files as in the
[current SDK runner](../examples/current_sdk/README.md#run-and-inspect).

## 3. Connect ReportPortal and integrate an existing project

For the minimal project, keep the files above. For an existing project, apply the
same installation to its root and merge the `env.rb` snippet into its support
setup. Add one logger scope around each Scenario; if an Around hook already owns
browser setup/teardown, place its `run.call` and teardown inside that scope so
their diagnostics can also use the bound logger.

| File / setting | Change | Why |
| --- | --- | --- |
| `Gemfile`, `Gemfile.lock` | Pin the candidate SDK and a supported Cucumber | Repeatable runtime |
| `features/support/env.rb` | Require the SDK, include its World, bind `AppLog` | Routes helper diagnostics to the executing Scenario |
| `.reportportal.yml` | Add nonsecret endpoint/project/Launch settings | Share safe defaults |
| Secret store / CI variables | Inject `RP_API_KEY` | Keep credentials out of source control |
| `cucumber.yml` or command | Add the RP formatter with a distinct output path | Send native events to RP |
| `.gitignore` | Ignore `artifacts/`, `.reportportal-spool/`, `.reportportal-curl/` | Keep generated evidence private |

Create **`.reportportal.yml` in your project root** (replace the example endpoint
and project with yours):

```yaml
default:
  endpoint: https://reportportal.example.com
  project: your_project
  launch: Ruby Cucumber smoke
  join: false

profiles:
  ci:
    launch: Ruby Cucumber CI
```

`RP_API_KEY` must already be injected through your secret manager or CI settings.
From **your project root**:

```sh
mkdir -p artifacts
RP_ENABLED=true bundle exec cucumber --no-profile --publish-quiet \
  --format progress \
  --format html --out artifacts/cucumber.html \
  --format message --out artifacts/messages.ndjson \
  --format ReportPortal::Cucumber::Formatter --out artifacts/reportportal.out
```

Expected for the minimal Feature: the local result still passes, and the RP
project has a **Ruby Cucumber smoke** Launch containing one Feature suite, one
Scenario test, and the `Sum result` log under its Then step. Reporting is
best-effort by default: a business pass alone does not prove that upload succeeded.
The [CI guide](ci.md#choose-the-reporting-policy) explains how to require completeness.

Configuration is loaded from `.reportportal.yml`, otherwise
`config/reportportal.yml`, relative to the working directory. `RP_CONFIG` selects
another path. Environment variables override YAML. Use the RP base URL in
`endpoint`, not a project-specific `/api/v1/...` URL.

If you prefer a Cucumber command profile, add this line to **`cucumber.yml` in your
project root**:

```yaml
rp: --publish-quiet --format progress --format html --out artifacts/cucumber.html --format message --out artifacts/messages.ndjson --format ReportPortal::Cucumber::Formatter --out artifacts/reportportal.out
```

From **your project root**:

```sh
mkdir -p artifacts
RP_ENABLED=true CUCUMBER_PROFILE=ci bundle exec cucumber --profile rp
```

Expected: Cucumber uses the `rp` command profile, and RP uses the YAML `ci` profile.
These are two settings: `--profile` selects Cucumber options; `CUCUMBER_PROFILE`
explicitly selects RP YAML values. If the environment variable is absent, the SDK
can infer its YAML profile from `-p`/`--profile`. See the
[configuration reference](configuration.md#configuration-files-and-profiles).

### Find your first report

1. Select the RP project, then open the Launch named in your configuration.
2. Open its Feature suite. Each Scenario or executed Examples row counts as one
   test; Given/When/Then and Before/After Hooks do not add statistical tests.
3. Open the Scenario's Log View and expand the relevant Step or Hook to see its
   logs/attachments. Include DEBUG/TRACE in the filter when looking for those levels.
   Turn off **Hide all passed logs** to inspect failure evidence under a passed
   After Hook; that filter hides it even when the Scenario failed or the log is ERROR.
4. Refresh after batching/backend processing. Log visibility can lag behind test
   execution; the default flush interval is one second.
5. Compare the report with native HTML/messages and the final reporting result.
   Business pass/fail and reporting completeness are separate outcomes.

## 4. Add API/UI evidence

Use [best practices](best-practices.md) for client/page-object logging, real
assertions, safe HTTP diagnostics, and correctly owned screenshots. When you need
a runnable browser example, install and copy the
[current SDK example](../examples/current_sdk/README.md), which makes real loopback
HTTP calls and drives Chromium. Browser dependencies are optional additions at
this stage. The main SDK does not install or own browsers.

For this example, **Node >=20** is required. The pinned
`playwright-ruby-client` **1.62.0** declares
`COMPATIBLE_PLAYWRIGHT_VERSION = '1.62.1'` in its
[version source](https://github.com/YusukeIwaki/playwright-ruby-client/blob/1.62.0/lib/playwright/version.rb).
The matching `playwright-core` **1.62.1**
[package manifest](https://github.com/microsoft/playwright/blob/v1.62.1/packages/playwright-core/package.json)
declares `engines.node: ">=20"`, matching the trial's installed
`node_modules/playwright-core/package.json`. This is a browser-example prerequisite,
not a dependency of the minimal Ruby-only Scenario above.

The current example sends its failure screenshot through existing `rp_attach`
as one RP caption-and-PNG entry owned by the open After Hook. Native HTML no
longer includes that failure screenshot. The unique local screenshot file,
original failure exception and native failure records are retained. **R02 remains
unresolved (not fixed)**: the API and After ownership are unchanged, with no
Scenario retargeting or hook-status change. **Hide all passed logs** hides this
evidence if After passed; disable the filter to inspect it. See
[capture choices](best-practices.md#choose-step-evidence-or-after-hook-evidence).

## 5. Configure CI

Follow the [CI guide](ci.md) for a serial job, artifact retention, an optional
complete-reporting gate, and shared-Launch ownership for parallel workers. Keep
the same logger setup and formatter command rather than introducing a second
reporting layer.

## First-run troubleshooting

| Symptom | Check in order |
| --- | --- |
| No Launch appears | Confirm the RP formatter is selected and `RP_ENABLED=true`; check that endpoint/project/key are present, the YAML file is resolved from this working directory, and the runner can reach the RP base URL. Missing required settings keep transport inert and requested reporting incomplete. |
| HTTP 401 / 403 | Confirm the injected key is current and belongs to an identity allowed to write to the configured project. Do not print the token while debugging. |
| Launch exists but logs do not | Check `report: true` and the bound World; open the correct Step/Hook, widen the RP level filter, and refresh after the flush interval. |
| AppLog appears only in the terminal | Ordinary level calls default to terminal-only. Use `report: true`, and keep calls inside the Scenario logger scope. |
| `rp_log` / `rp_attach` missing from native HTML | Those APIs are RP-only. Use AppLog or native Cucumber `log`/`attach` for native evidence. |
| Two formatters try to own STDOUT | Give every additional formatter its own `--out`; create parent directories before the run. |
| ERROR log but a passing Scenario | Add an actual assertion or raise. `AppLog.http` and `AppLog.assertion` are diagnostics. |
| Screenshot appears under After | That is the expected owner for After-hook capture. For Step ownership, capture/publish inside the still-open Step. |
| After failure screenshot is missing in RP | Turn off **Hide all passed logs**: a passed After Hook's evidence is hidden even when its log is ERROR or its Scenario failed. R02 remains unresolved; do not retarget a closed Step or change the Hook's status. |
| Current example has no failure screenshot in native HTML | Intentional RP-only tradeoff: inspect the unique local PNG or the single caption-and-PNG entry under After in RP; original native failure records are retained. |
| Required reporting exits `2` | Inspect missing configuration or the incomplete reporting summary; a failing report is distinct from a failed business Scenario. |
| Unsupported Cucumber / parameter message-builder failure | Use Cucumber `>=12.0.1, ~>12.0` through the project's Bundler environment and remove the legacy expressions `<19` pin. Cucumber 9/10 belongs to SDK 1.x, not this 2.x bundle; Cucumber 11 is unsupported. |

For spool/replay, receipts, video, and history settings, continue to
[advanced reporting](advanced-reporting.md).
