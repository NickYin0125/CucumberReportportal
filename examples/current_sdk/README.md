# Current SDK API/UI example

A small independent Cucumber project using **`reportportal-cucumber-ruby` 1.3.0**.
It makes real loopback HTTP requests and optionally drives real Chromium against
a deterministic practice page. RP is disabled until you enable it. First-time
users should run the [one-Scenario quick start](../../docs/getting-started.md)
before this larger example.

**Release caveat:** the original published v1.3.0 gem contains sample setup/runtime
scripts that still check for 1.2.0. The updated source example fixes those checks
with one shared version definition. Use **this updated checkout's example files**
with the published 1.3.0 gem; do not copy the stale sample from that original
archive. This documentation change does not replace an already-published release
asset. A subsequent release must package the corrected example.

## Install the consumer

Use Ruby `>=3.1`, Bundler `>=2.6`, and Cucumber `>=9,<11`. Node/npm and the compatible
Playwright CLI/browser are needed for UI, not for the API-only run. The sample pins
Playwright Ruby to 1.62.0; setup derives its CLI version from the installed binding.

Obtain an updated source checkout to copy **only the example**; no SDK build or
root development bundle is needed. From **a directory where you keep projects**:

```sh
git clone --depth 1 https://github.com/NickYin0125/CucumberReportportal.git
```

Expected: a checkout with the corrected `examples/current_sdk/helpers/sdk_version.rb`
version source. If using the change before it is merged, select the branch/commit
containing it; the v1.3.0 tag retains the old sample. If you already have that
checkout, skip the clone and set the path below.

From **any working directory**, replace `sample_source` with that checkout path:

```sh
sample_source=/absolute/path/to/CucumberReportportal
sample_work=$(mktemp -d "${TMPDIR:-/tmp}/current-sdk-consumer.XXXXXX")
cp -R "$sample_source/examples/current_sdk" "$sample_work/project"
curl -fL -o "$sample_work/reportportal-cucumber-ruby-1.3.0.gem" \
  https://github.com/NickYin0125/CucumberReportportal/releases/download/v1.3.0/reportportal-cucumber-ruby-1.3.0.gem
cd "$sample_work/project"
export SDK_GEM_ARCHIVE="$sample_work/reportportal-cucumber-ruby-1.3.0.gem"
export RP_ENABLED=false
ruby bin/setup "$SDK_GEM_ARCHIVE"
```

Expected: normal gem installation, version-pinned Bundler resolution, matching
Node Playwright CLI installation, and Chromium installation. Use a supported Node
runtime (the previous lab used Node 20+). Review the
[Ruby Playwright setup guide](https://playwright-ruby-client.vercel.app/docs/article/getting_started)
if your OS needs browser packages. `bin/setup` can require network access for all
three dependency layers. Existing tools can be reused with `SKIP_BROWSER_SETUP=true`,
an absolute `PLAYWRIGHT_CLI_EXECUTABLE_PATH`, and `PLAYWRIGHT_BROWSERS_PATH`.

**Copy outside the checkout before execution.** Scripts reject running under the
SDK source example directory; generated reports/node_modules there could otherwise
be included by the gemspec's broad examples glob. Raw Cucumber bypasses that guard.
Keep a consumer's artifacts/dependencies in its own copied project.

For **API-only setup**, use this instead of the last setup command, from **the
external consumer copy**:

```sh
SKIP_BROWSER_SETUP=true ruby bin/setup "$SDK_GEM_ARCHIVE"
bundle exec ruby bin/run api
```

Expected: **4 API Scenarios pass**, exit `0`, with native HTML/messages and real
HTTP evidence. The Ruby Playwright gem is resolved but no Node/browser is needed
for this profile. For an offline/cached setup, `GEM_INSTALL_LOCAL=true BUNDLE_LOCAL=true`
requires every Ruby dependency to be available; browser caches are separate.

## Run and inspect

From **the external consumer copy after full UI setup**:

```sh
bundle exec ruby bin/run
bundle exec ruby bin/run api
bundle exec ruby bin/run ui
bundle exec ruby bin/run intentional
bundle exec ruby bin/verify
```

| Command | Expected outcome |
| --- | --- |
| `bin/run` (default `offline`) | 5 Scenarios: 4 API + 1 UI, exit `0` |
| `bin/run api` | 4 API Scenarios, exit `0` |
| `bin/run ui` | 1 deterministic UI Scenario, exit `0` |
| `bin/run intentional` | 1 genuine missing-locator failure, exit `1` |
| `bin/verify` | Verifies passing and intentional-failure runs, exit `0` only when the required outcomes/evidence match |

The runner preserves the native Cucumber exit. `intentional` is not an all-pass
suite. Only the verifier recognizes its precise failed-Step count, original
Playwright TimeoutError, and valid After-hook screenshot as the expected negative
case. It rejects other failures/skipped/undefined/pending steps, forces RP off,
and checks native HTML/messages ownership, compact/color console output, and
spool retention. These are executable expectations, not a claim they ran on your
machine or against your RP service.

Each run prints its unique `artifacts/<profile>/<run>/` path. Open `cucumber.html`
and expand the API action to see request/response Markdown/JSON. For `intentional`,
inspect the original failed Step and **After Hook** PNG plus `failure-routing.json`.
`progress.txt`, `summary.txt`, and `messages.ndjson` are retained. The RP
formatter's distinct `reportportal.txt` destination may be absent; it is not an
RP log stream or receipt. `NO_COLOR=1` disables sample console colors.

`REPORT_DIR=/absolute/external/path` overrides one run's destination and must be
new/empty. `VERIFY_OUTPUT=/absolute/external/path` selects the parent for unique
verification directories. Neither should point inside SDK source.

Additional **external-consumer diagnostics**:

```sh
bundle exec ruby bin/check_fixture
bundle exec ruby bin/check_config
bundle exec ruby bin/check_rerun
bundle exec ruby bin/runtime
```

Expected: fixture HTTP/size contracts, credential-free endpoint policy, safe
rerun/spool preservation, and installed runtime/version/SHA manifest respectively.
`check_rerun` preserves its synthetic spool sentinel. `bin/runtime` can compare
the complete installed `lib/**/*.rb` file inventory against `SDK_SOURCE_ROOT`
when you explicitly set it; do not use that check to equate the published release
with a later edited source tree.

## Enable ReportPortal

Inject `RP_API_KEY` through your secret manager. From **the external consumer
copy**, using your own endpoint/project:

```sh
RP_ENABLED=true RP_ENDPOINT=https://reportportal.example.com \
  RP_PROJECT=your_project bundle exec ruby bin/run api
```

Expected: the **Current SDK examples** Launch (or your `RP_LAUNCH` override)
contains the 4 API Scenarios and their action-owned evidence. Full `offline`
contributes 5 passed Scenarios across two Feature suites. Refresh after batching,
include DEBUG to find deep helper logs, and inspect the expected 400 at INFO.
The optional diagnostic comparison can be ERROR while its separately asserted
expected-rejection Scenario remains PASSED.

For an explicitly selected loopback development RP endpoint, **from the same
external copy**, with its API key already injected:

```sh
RP_ENABLED=true RP_ALLOW_LOCAL_HTTP=true RP_ENDPOINT=http://localhost \
  RP_PROJECT=your_project bundle exec ruby bin/run api
```

Expected: the runner allows loopback HTTP for this opted-in run. Its endpoint
guard requires credential-free HTTPS, or explicit localhost/127.0.0.1 HTTP;
nonloopback HTTP, URL userinfo, queries, and fragments are rejected. This is the
sample runner's policy, not a claim that the SDK enforces the same policy on all
consumers. Use HTTPS for real networks. `RP_ALLOW_LOCAL_HTTP` is sample-specific.

Run `intentional` separately with RP enabled when checking browser-failure
ownership: it deliberately exits `1`, and its screenshot belongs to After, not
the completed failing Step. The PNG follows AppLog's native event route; the
structured `rp_evidence` diagnostic targets the open Hook without attaching
the same PNG twice. A rejected target never silently retargets to another action.
See [best practices](../../docs/best-practices.md) and the
[CI reporting policy](../../docs/ci.md#choose-the-reporting-policy).

## What to reuse in your project

| File | Responsibility |
| --- | --- |
| `features/api.feature`, API steps | Real response contracts, DocString/DataTable/Outline coverage |
| `helpers/api_client.rb` | Actual `Net::HTTP` calls/timeouts and `AppLog.http` observation |
| `features/ui.feature`, UI steps | Accessible Playwright locators and user actions |
| `features/support/env.rb` | Fixture, scoped logger, browser Around lifecycle, After evidence |
| `helpers/world.rb` | Real assertions, original-error preservation, screenshots, cleanup |
| `config/reportportal.yml`, `cucumber.yml` | Safe local/remote settings and distinct formatter outputs |
| `helpers/sdk_version.rb`, `Gemfile`, setup/runtime scripts | One shared consumer SDK version |

The fixture uses an ephemeral loopback port, bounded requests/timeouts, and
bounded shutdown. HTTP severity is diagnostic; `check_equal` raises separately.
Browsers are Scenario-local; the After screenshot happens before Around cleanup.
Cleanup/reporting failures must not replace the original browser exception.
All data is synthetic. Structured redaction does not sanitize arbitrary JSON,
attachments, screenshot pixels, native core failures, or spool contents.

## Optional live Typewords smoke

With Typewords already available at `http://localhost:5567/`, from **the external
consumer copy after browser setup**:

```sh
TYPEWORDS_URL=http://localhost:5567/ bundle exec ruby bin/run live
```

Expected: one navigation/title smoke Scenario, exit `0` if the target matches.
This is not a deterministic Typewords business test and is excluded by default.
It accepts credential-free loopback HTTP URLs only. `TYPEWORDS_SCREENSHOT=true`
adds an opt-in PNG to the title-check Step; review page content before publishing.
The deterministic local practice page is not represented as Typewords.

## Source and packaging verification

This optional **maintainer workflow** builds a current candidate instead of using
the published archive. From **any directory**, set `sdk_source` to the checkout
whose package you want to verify:

```sh
sdk_source=/absolute/path/to/CucumberReportportal
sdk_work=$(mktemp -d "${TMPDIR:-/tmp}/current-sdk-package.XXXXXX")
cp -R "$sdk_source/examples/current_sdk" "$sdk_work/project"
cd "$sdk_source"
gem build reportportal-cucumber-ruby.gemspec --output "$sdk_work/candidate.gem"
cd "$sdk_work/project"
export GEM_HOME="$sdk_work/gems"
export GEM_PATH="$GEM_HOME:$(ruby -e 'puts Gem.default_path.join(":")')"
export PATH="$GEM_HOME/bin:$(ruby -e 'puts Gem.default_bindir'):$PATH"
export SDK_GEM_ARCHIVE="$sdk_work/candidate.gem"
export EXPECTED_SDK_INSTALL_ROOT="$GEM_HOME"
export SDK_SOURCE_ROOT="$sdk_source"
export RP_ENABLED=false
ruby bin/setup "$SDK_GEM_ARCHIVE"
bundle exec ruby bin/verify
```

Expected: setup accepts a candidate with the shared consumer version, and runtime
verification loads that normally installed gem from the isolated GEM_HOME and
checks its source hashes. This proves the candidate packaging lane when it passes;
it does not republish/replace v1.3.0 or prove real RP/video ingestion.

For separate Cucumber lanes, use a fresh external copy/lockfile per lane and set
`CUCUMBER_VERSION='= 9.2.1'` or `'= 10.2.0'` on both setup and verification commands.
Do not reuse a lockfile for another lane accidentally. The sample supports a
`Gemfile.source` for source debugging only; if selected through `BUNDLE_GEMFILE`,
set `SDK_SOURCE_ROOT` to a gemspec-containing checkout. It is not packaging proof.

The [archived 2026-10-12 verification](verification.md) records earlier candidate
runs, toolchain details, HTML backtrace normalization, and limitations. Its older
candidate version/results must not be relabeled as fresh 1.3.0 acceptance.
