# Examples and validation tools

For first-time use, start with [one minimal Scenario](../docs/getting-started.md).
Use the current SDK example for API/UI integration after that works. The other
directories are specialized usage notes, source QA, or historical labs; they do
not all form a single installation path.

## Current consumer examples

| Example | Purpose | Requirements / expected outcome |
| --- | --- | --- |
| [current SDK](current_sdk/README.md) | Independent released-gem consumer with real HTTP + optional Chromium | Ruby/Bundler; Node/browser for UI. Passing suite is 5 Scenarios; intentional failure is separate. Use the updated checkout's sample files, not the stale sample inside the original v1.3.0 archive. |
| [Scenario attributes](m3c_attributes/README.md) | Add allowlisted business tags/defaults | Existing Cucumber project; RP enabled to inspect metadata |
| [Scenario links](m3c_links/README.md) | Source, CI, and TMS description links | Existing Cucumber project; explicit templates/run URL |

[API/UI/logger best practices](../docs/best-practices.md) explains which calls to
reuse. The current SDK's default suite has a deterministic loopback business
fixture; ReportPortal is opt-in. Its native-only API profile needs no browser.

## Source-checkout QA

These are **developer tools**, not installed-gem prerequisites. Install the root
development bundle and run them from the source checkout. Direct GitHub links
are used for source-only files which may be absent from an installed gem.

| Tool | Scope |
| --- | --- |
| [minimal fixture](minimal/features/reporting.feature) | Original RP-only World DSL smoke; loads source `lib/`, so it does not prove independent package installation |
| [reporting-experience fixture](reporting_experience/features/api_evidence.feature) | Synthetic diagnostic/assertion routing; not a real API-client test |
| [M3A fixture](m3a/README.md) | English/Chinese Gherkin metadata and tables |
| [M3B identity fixture](m3b/README.md) | Stable identity migration/source-change/retry QA |
| [Day-2 endurance](https://github.com/NickYin0125/CucumberReportportal/blob/main/examples/day2_endurance/README.md) | Source-only 900-second real-time workload against a clearing mock; optional RP readback |
| [Day-2 faults](https://github.com/NickYin0125/CucumberReportportal/blob/main/examples/day2_faults/README.md) | Source-only bounded fault proxy, queue/spool/replay/interruption QA |

From **the SDK source checkout root**, for the ordinary development checks:

```sh
bundle install
RUBYOPT=-rbundler/setup bundle exec rspec -Ilib -Ispec spec
bundle exec cucumber
```

Expected: offline RSpec/default Cucumber complete successfully for a healthy
checkout. This does not run browser/live RP/duration gates. The normal profile
excludes duration/live tags; select the relevant source harness intentionally.
Do not install browser dependencies or generate reports under packaged
`examples/` directories. Copy consumers outside the checkout or use each QA
tool's documented external evidence directory.

## Historical labs and verification fixtures

| Lab | Why it is retained |
| --- | --- |
| [Typewords M2](typewords_m2/README.md) | Dated live open-Step screenshot/evidence verification; local demo assumptions |
| [Typewords video](typewords_m2_video/README.md) | Dated recording/context-close/transcode/RP-playback lifecycle; local Kubernetes/MinIO assumptions |
| [M4 delivery acceptance](m4_delivery_acceptance/README.md) | Specialized live receipt/replay QA with explicit runner gates |
| [M2/M3 regression archive](https://github.com/NickYin0125/CucumberReportportal/tree/main/examples/m2m3_regression) | Historical candidate regression lanes; source checkout required |
| [M3C live archive](https://github.com/NickYin0125/CucumberReportportal/tree/main/examples/m3c_live) | Historical source/CI/TMS metadata readback; source checkout required |

These labs can include intentional failures, machine-specific paths, explicit
historical runner flags, demo authentication, and old dependency locks. They are
not portable consumers or production secret-management examples. Treat their
results as evidence for the named date/environment, and follow current
[CI](../docs/ci.md), [configuration](../docs/configuration.md), and
[video/storage guidance](../docs/advanced-reporting.md#video-and-external-storage)
for new projects. [Historical evidence index](../docs/design/README.md).
