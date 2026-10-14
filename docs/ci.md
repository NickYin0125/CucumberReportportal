# CI integration

Keep the same World/logger setup and formatter command used locally. Start with
one Launch per CI job; add shared parallel reporting only when the coordinator
can own its complete lifecycle.

## A serial job

Prepare a runner with Ruby `>=3.1`, Bundler, curl, and a supported project lockfile.
Use your project's normal browser image/setup only for UI jobs. The example
below is **consumer GitLab CI configuration**, not the SDK's own release workflow.
It runs from the checked-out **automation project root**. Inject `RP_API_KEY` as a
masked CI secret; set your RP endpoint/project to real values.

Add to **`.gitlab-ci.yml`**:

```yaml
stages: [test]

cucumber:
  stage: test
  variables:
    RP_ENABLED: "true"
    RP_ENDPOINT: "https://reportportal.example.com"
    RP_PROJECT: "your_project"
    RP_CLIENT_JOIN: "false"
    RP_REQUIRE_COMPLETE_REPORTING: "true"
    RP_SPOOL_DIR: "artifacts/reportportal-spool"
    NO_COLOR: "1"
  before_script:
    - mkdir -p vendor/cache artifacts
    - >-
      curl -fL -o vendor/cache/reportportal-cucumber-ruby-1.3.0.gem
      https://github.com/NickYin0125/CucumberReportportal/releases/download/v1.3.0/reportportal-cucumber-ruby-1.3.0.gem
    - gem install ./vendor/cache/reportportal-cucumber-ruby-1.3.0.gem --no-document
    - bundle install
  script:
    - >-
      RP_LAUNCH="Cucumber pipeline ${CI_PIPELINE_ID} job ${CI_JOB_ID}"
      bundle exec cucumber --no-profile --publish-quiet
      --format progress
      --format html --out artifacts/cucumber.html
      --format message --out artifacts/messages.ndjson
      --format ReportPortal::Cucumber::Formatter --out artifacts/reportportal.out
  artifacts:
    when: always
    expire_in: 7 days
    paths:
      - artifacts/
```

Expected: passing business tests with confirmed complete reporting make the job
successful. A failed Scenario still fails the job with its native outcome; an
otherwise successful run with incomplete required reporting raises
`ReportportalCucumber::ReportingError` (Cucumber exit `2`). HTML/messages and any
retained spool evidence are collected even on failure. `reportportal.out` may
be absent and is not the delivery receipt.

The project must already have the [version-pinned Gemfile and integration setup](getting-started.md#3-connect-reportportal-and-integrate-an-existing-project).
Retain/commit its `Gemfile.lock`. Cache approved dependencies or place the release
archive/dependencies in your internal package mirror for an offline runner; a
first-time `bundle install --local` cannot fetch missing gems. Set
`RP_ENABLED=false` for a deliberate native-only job and omit the completeness
requirement there. Keep artifacts private according to your CI access policy.

Do not append `|| true` to Cucumber or replace its exit code with a later upload
command's result. When piping to `tee`, use a shell that supports `pipefail` and
preserve the Cucumber status explicitly. Prefer the direct command above and the
CI system's always-run artifact collection.

## Choose the reporting policy

| Policy | Configuration | Result |
| --- | --- | --- |
| Native-only | `RP_ENABLED=false` | Tests/native reports run; no RP transport is requested |
| Best-effort RP | RP enabled; both gates false (default) | Tests determine the outcome; reporting can be incomplete and must be inspected separately |
| Synchronous reporting exceptions | `RP_FAIL_ON_REPORTING_ERROR=true` | Can propagate synchronous reporter errors; does not enforce confirmation of every background log |
| Required whole report | `RP_REQUIRE_COMPLETE_REPORTING=true` | Checks the final whole-run receipt after genuine teardown; can fail an otherwise successful run |

Enable required reporting once the job has reliable RP access and its artifacts
are retained. It runs business tests and genuine `AfterAll` even when required
connection settings are missing. An original business/run-hook exception has
precedence over an incomplete-reporting error. The receipt's `complete` field is
about reporting, not whether your tests/teardown passed.

## Retain a final reporting receipt

The SDK exposes `reporting_receipt` on its active formatter; it does not
automatically create a JSON receipt file. If CI needs one, add this
**consumer-owned support file**, `features/support/reporting_receipt.rb`:

```ruby
require "fileutils"
require "json"

reporter = nil

Before do
  reporter ||= ReportportalCucumber.current_runtime
end

at_exit do
  begin
    if reporter
      path = ENV.fetch("RP_RECEIPT_PATH", "artifacts/reporting-receipt.json")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(reporter.reporting_receipt.to_h))
    end
  rescue StandardError => error
    warn("Reporting receipt export failed: #{error.class}")
  end
end
```

Load the SDK in your `env.rb` as usual. `RP_RECEIPT_PATH` is an environment variable
used by **this snippet**, not a built-in SDK option. Set a unique path for each
parallel worker. The retained reporter remains inspectable after the global
runtime is cleared on normal completion; the counter-only receipt excludes log
payloads. Export errors do not overwrite the process's existing outcome.

Expected on a normal run: the JSON file appears after Cucumber finalization and
can be retained alongside HTML/messages. Interruptions/aborts can leave a pending
receipt because `at_exit` ordering is best-effort. A `BeforeAll` failure can occur
before formatter construction; a crashed/SIGKILLed worker can produce no file.
Treat missing/incomplete worker receipts as missing reporting evidence rather
than fabricating success. See the [receipt schema](advanced-reporting.md#delivery-receipts-and-completeness).

## Parallel workers and a shared Launch

Use separate Launches if you do not yet have a coordinator: the default
`RP_CLIENT_JOIN=false` lets each process create/finish its own Launch. Do not use
legacy file join as a distributed completion barrier.

For a shared Launch, **CI owns this sequence**:

1. Create one Launch on the configured RP endpoint/project and retain its original
   UUID. Do not use its numeric UI ID as `RP_LAUNCH_UUID`.
2. Inject that UUID, the same endpoint/project, and credentials into every shard.
   Give each shard distinct HTML/messages/receipt/spool paths.
3. Execute the shards and collect every actual exit status and final receipt.
4. Handle late workers, missing/crashed workers, and the coordinator deadline.
5. Finish the Launch only after all workers have settled; choose the final
   business status from the worker results and keep reporting completeness
   visible separately.

For an already-created Launch with its UUID supplied by CI, a **worker command
from that worker's project root** is:

```sh
mkdir -p artifacts
RP_ENABLED=true RP_CLIENT_JOIN=false RP_REQUIRE_COMPLETE_REPORTING=true \
  bundle exec cucumber --no-profile --publish-quiet \
  --format progress \
  --format html --out artifacts/cucumber.html \
  --format message --out artifacts/messages.ndjson \
  --format ReportPortal::Cucumber::Formatter --out artifacts/reportportal.out
```

`RP_LAUNCH_UUID` must already be injected. Expected: the worker writes items/logs
to that open Launch and **does not start or finish it**. UUID workers bypass local
file join. Do not combine `RP_LAUNCH_UUID` with `RP_RERUN`/`RP_RERUN_OF`, reuse a
stale UUID, or assume a worker's complete receipt proves the coordinator finished
the shared Launch. This SDK supplies the worker contract; it is not a distributed
scheduler or a ready-made Launch coordinator.

The [advanced guide](advanced-reporting.md#launch-ownership-and-native-run-hooks)
describes native hook ordering and the corresponding design contracts.

## SDK development and release CI

The repository's [GitHub CI workflow](https://github.com/NickYin0125/CucumberReportportal/blob/main/.github/workflows/ci.yml)
and [shared validation workflow](https://github.com/NickYin0125/CucumberReportportal/blob/main/.github/workflows/validate.yml)
are **source-checkout developer workflows**. They render/lint the companion Helm
profiles, run the offline RSpec suite (including installed-gem packaging checks),
and execute the default Cucumber suite. Browser/live RP/duration checks are
separate opt-ins; a green offline run does not claim those were performed.

Stable `vX.Y.Z` release tags validate already-merged source, require matching gem
and wrapper Chart versions, and package a gem, chart, checksums, and provenance.
They do not publish to RubyGems.org or deploy a Kubernetes stack. See the
[source-checkout release operator guide](https://github.com/NickYin0125/CucumberReportportal/blob/main/script/release/README.md) and
[changelog](../CHANGELOG.md) for maintainers.
