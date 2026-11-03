# Current SDK API/UI example

A small independent Cucumber project targeting **`reportportal-cucumber-ruby` 1.3.3**
and **Cucumber 9/10**.
It makes real loopback HTTP requests and optionally drives real Chromium against
a deterministic practice page. RP is disabled until you enable it. First-time
users should run the [one-Scenario quick start](../../docs/getting-started.md)
before this larger example.

Use the SDK 1.3.3 Gem from the
[v1.3.3 GitHub release](https://github.com/NickYin0125/CucumberReportportal/releases/tag/v1.3.3)
or a matching explicitly selected local candidate archive. RubyGems registry
publication is not performed by this release process. The shared SDK version
definition keeps setup/runtime checks aligned.
Older published archives and their dated evidence are unchanged.

## Install the consumer

Use Ruby `>=3.1`, Bundler `>=2.6`, and Cucumber `>=9,<11`. Node/npm and the compatible
Playwright CLI/browser are needed for UI, not for the API-only run. The sample pins
Playwright Ruby to 1.62.0; setup derives its CLI version from the installed binding.

Use the `v1.3.3` checkout for sample files.
Obtain the release archive and checksums from the linked release or build it with the
[source-packaging workflow](#source-and-packaging-verification).
Verify the selected archive before installation.

From **any directory**, set absolute checkout and archive paths. Install in a
disposable gem directory instead of changing global gems or Bundler settings:

```sh
sample_source=/absolute/path/to/CucumberReportportal
export SDK_GEM_ARCHIVE=/absolute/path/to/reportportal-cucumber-ruby-1.3.3.gem
sample_work=$(mktemp -d "${TMPDIR:-/tmp}/current-sdk-consumer.XXXXXX")
cp -R "$sample_source/examples/current_sdk" "$sample_work/project"
cd "$sample_work/project"
export GEM_HOME="$sample_work/gems"
export GEM_PATH="$GEM_HOME:$(ruby -e 'puts Gem.default_path.join(":")')"
export PATH="$GEM_HOME/bin:$(ruby -e 'puts Gem.default_bindir'):$PATH"
export BUNDLE_IGNORE_CONFIG=1
unset BUNDLE_PATH BUNDLE_GEMFILE
export EXPECTED_SDK_INSTALL_ROOT="$GEM_HOME"
export RP_ENABLED=false
ruby bin/setup "$SDK_GEM_ARCHIVE"
```

Expected: normal gem installation, version-pinned Bundler resolution, matching
Node Playwright CLI installation, and Chromium installation. UI setup requires
**Node >=20** for the pinned `playwright-core` 1.62.1 CLI, paired with
`playwright-ruby-client` 1.62.0. Review the
[Ruby Playwright setup guide](https://playwright-ruby-client.vercel.app/docs/article/getting_started)
if your OS needs browser packages. `bin/setup` can require network access for all
three dependency layers. Existing tools can be reused with `SKIP_BROWSER_SETUP=true`,
an absolute `PLAYWRIGHT_CLI_EXECUTABLE_PATH`, and `PLAYWRIGHT_BROWSERS_PATH`.
Before reusing a CLI, check the Node version and compare these two CLI versions:

```sh
node --version
bundle exec ruby -rplaywright/version -e 'puts "Required CLI: #{Playwright::COMPATIBLE_PLAYWRIGHT_VERSION}"'
"$PLAYWRIGHT_CLI_EXECUTABLE_PATH" --version
```

The required and installed CLI versions must match exactly (1.62.1 for this
example); a different working Playwright installation is not automatically
compatible. Its matching Chromium must also exist in `PLAYWRIGHT_BROWSERS_PATH`.
If they differ, use a supported Node version, clear the old CLI override, and
install the pinned CLI/browser rather than silently reusing the mismatch:

```sh
unset SKIP_BROWSER_SETUP PLAYWRIGHT_CLI_EXECUTABLE_PATH
ruby bin/setup "$SDK_GEM_ARCHIVE"
```

The npm install explicitly uses `--prefix` with the consumer's working directory,
so it cannot select a parent project's `package.json`. No `package.json` is needed
or shipped by this example.

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
Playwright TimeoutError, unchanged passed After hook, and valid local screenshot
as the expected negative case. It rejects other failures/skipped/undefined/pending steps, forces RP off,
and checks exact evidence counts/owners, native HTML/messages agreement,
compact/color console output, and spool retention. It also runs the example's
self-tests, including one captioned PNG at the RP queue boundary with After
ownership, without connecting to RP. These are executable expectations, not a
claim they ran on your machine or against your RP service.

Each run prints its unique `artifacts/<profile>/<run>/` path. Open `cucumber.html`
and expand the API action to see request/response Markdown/JSON. For `intentional`,
inspect the original failed Step in native HTML and the local PNG in the report
directory. Failure PNG names contain the scenario slug, failed checkpoint and a
random suffix, for example `save-a-practice-word-practice-status-a1b2c3d4.png`.
Native HTML/messages deliberately do **not** contain the failure screenshot.
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
bundle exec ruby test/self_test.rb
```

Expected: fixture HTTP/size contracts, credential-free endpoint policy, safe
rerun/spool preservation, installed runtime/version/SHA manifest, and example
self-tests respectively.
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
The optional diagnostic-only observation is INFO and explicitly non-fatal; its
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
the completed failing Step. One direct `rp_attach` call emits an ERROR entry
containing the scenario/failed-check caption and PNG. The last **passed** browser
action appears in its details, not its title. The terminal summary uses
`AppLog.error(report: false)` and creates no extra RP/native record. There is no
`rp_evidence` call, native failure attachment, or `failure-routing.json` entry.
This RP-only screenshot route is intentional: native HTML/messages retain the
original exception and backtrace but no failure PNG. With RP disabled or absent,
the PNG remains a local file and no RP evidence is emitted.

**R02 is not fixed.** Evidence remains owned by the current open After hook,
whose status stays PASSED. RP's **Hide all passed logs** hides this After-hook
evidence even though the screenshot entry is ERROR. Turn that filter off to see
it. The example does not retarget the Scenario or closed failed Step, extend the
capture API, or change hook status.
See [best practices](../../docs/best-practices.md) and the
[CI reporting policy](../../docs/ci.md#choose-the-reporting-policy).

## Presentation opt-ins

The default is `RP_PRESENTATION=plain` and `RP_RUN_CONTEXT=false`. After configuring
RP as above, run from the external consumer copy to opt in:

```sh
RP_PRESENTATION=rich RP_RUN_CONTEXT=true bundle exec ruby bin/run api --rp
```

Only client-built RP log cards gain rich accents/folds. Native HTML/messages,
terminal output, user AppLog text, item names/descriptions and Launch metadata
remain free of those accents. Run context separately adds allowlisted metadata;
explicit attributes and descriptions win. No worker attribute is generated on 1.x.

Invalid presentation values warn once and fall back to plain. Entire ERROR/FATAL messages,
evidence values, ownership and attachment bytes remain unchanged. See the
[configuration reference](../../docs/configuration.md#presentation-and-run-context)
and [presentation boundaries](../../docs/advanced-reporting.md#presentation).
This command is an opt-in usage example, not a claim of live RP validation.

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

This optional **maintainer workflow** builds a current candidate instead of consuming
a supplied archive. From **any directory**, set `sdk_source` to the checkout
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
export BUNDLE_IGNORE_CONFIG=1
unset BUNDLE_PATH BUNDLE_GEMFILE
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
it does not publish 1.3.3, replace older releases, or prove real RP/video ingestion.

For separate Cucumber lanes, use a fresh external copy/lockfile per lane and set
`CUCUMBER_VERSION='= 9.2.1'` or `'= 10.2.0'` on both setup and verification commands.
Do not reuse a lockfile for another lane accidentally. The sample supports a
`Gemfile.source` for source debugging only; if selected through `BUNDLE_GEMFILE`,
set `SDK_SOURCE_ROOT` to a gemspec-containing checkout. It is not packaging proof.

The [archived 2026-10-12 verification](verification.md) records earlier candidate
runs, toolchain details, HTML backtrace normalization, and limitations. Its older
candidate version/results must not be relabeled as fresh 1.3.3 acceptance.
