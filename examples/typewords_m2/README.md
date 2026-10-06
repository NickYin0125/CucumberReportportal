# Typewords M2 live acceptance

This optional example exercises the M2 reporting API with a real Ruby Cucumber run and official Playwright Ruby/Node clients. It does not add Playwright to the ReportPortal gem's runtime dependencies. Run it from this folder with Ruby 3.1+ and Node.js installed.

## Isolated setup

The gemspec packages files under `examples/**/*`, so keep installed packages and browser binaries outside this folder. From the repository root:

```bash
mkdir -p tmp/m2-typewords-live/node tmp/m2-typewords-live/browsers
npm --prefix tmp/m2-typewords-live/node install --no-save --no-package-lock --no-audit --no-fund playwright-core@1.62.1
PLAYWRIGHT_BROWSERS_PATH="$PWD/tmp/m2-typewords-live/browsers" \
  tmp/m2-typewords-live/node/node_modules/.bin/playwright-core install chromium
```

Install the isolated Ruby bundle from this folder:

```bash
bundle install
```

Point the Ruby binding at the isolated official Playwright CLI. The `/tmp` alias avoids a Playwright Ruby subprocess parsing issue when the workspace path contains spaces:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
EXPECTED_M2_ROOT="$REPO_ROOT/tmp/m2-typewords-live"
if [ -L /tmp/m2-typewords-live ]; then
  if [ "$(readlink /tmp/m2-typewords-live)" != "$EXPECTED_M2_ROOT" ]; then
    printf 'Refusing to replace /tmp/m2-typewords-live; point it to %s manually.\n' "$EXPECTED_M2_ROOT" >&2
    exit 1
  fi
elif [ -e /tmp/m2-typewords-live ]; then
  printf '/tmp/m2-typewords-live exists and is not the expected symlink; inspect it before proceeding.\n' >&2
  exit 1
else
  ln -s "$EXPECTED_M2_ROOT" /tmp/m2-typewords-live
fi
```

## Run

From this folder (the example directory):

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
PATH=/opt/homebrew/opt/ruby/bin:$PATH \
PLAYWRIGHT_CLI_EXECUTABLE_PATH=/tmp/m2-typewords-live/node/node_modules/.bin/playwright-core \
M2_EVIDENCE_DIR="$REPO_ROOT/tmp/m2-typewords-live" \
bundle exec ruby run.rb
```

On this machine, put Homebrew Ruby first on `PATH`; the system Ruby is too old for the locked Bundler/Cucumber dependencies.

The runner uses `http://localhost:5567/words`, ReportPortal at `http://localhost`, and project `superadmin_personal` by default. It obtains a short-lived API token in memory using the local demo login defaults; override with `RP_USERNAME`, `RP_PASSWORD`, or `RP_API_KEY` as appropriate. It never writes or prints the token. The Cucumber process is expected to exit nonzero because one scenario deliberately re-raises a real `Playwright::TimeoutError`; the runner treats only that one failed scenario as expected and verifies its evidence against the ReportPortal API.

The first scenario dismisses the first-visit tour only inside its disposable browser context, opens the dictionary picker, and verifies `/dict-list`, its heading, and the visible CET-4 entry. It does not select a dictionary or write settings. The second scenario reports the observed `Words` navigation link and `/words` path inside a manual `rp_step`. The final scenario captures a caller-owned PNG and console excerpt for an intentionally absent button, reports evidence against the open Gherkin step, and re-raises the original Playwright error. An After hook then probes the closed handle and records the expected `false` result.

The example's Around hook binds `AppLog` to `Automation::CucumberLogger` for the scenario scope, as required for `AppLog.assertion` entries to be emitted to the active Cucumber/ReportPortal item. The runner also supports read-only reconciliation of an already-finished launch with `RP_EXISTING_LAUNCH_ID=<id>` and `RP_LAUNCH=<exact-name>`; this reuses the existing native result files and does not start another Cucumber run.

Generated evidence, HTML/terminal reports, formatter output, and `result-manifest.json` are written only under `tmp/m2-typewords-live/`. The manifest includes run/dependency versions, launch and failed-item identifiers, log IDs, the intentional exception class, late-evidence result, redaction check, and PNG digest/signature check. The completed 2026-10-05 live acceptance is recorded in [the M2 verification record](../../docs/design/reporting-experience-m2-verification.md), final Launch25 (`typewords-m2-20261005T021139-b16ae5`). The harness does not automate visual review; future acceptance runs still require a separate human check of ReportPortal's UI and attachment preview.
