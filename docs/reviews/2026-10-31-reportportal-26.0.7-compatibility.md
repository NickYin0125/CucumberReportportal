# ReportPortal 26.0.7 Deployment And Client Acceptance

Date: 2026-10-31. Branch: `codex/reportportal-26-0-7`.

## Version And Isolation Contract

The wrapper chart is **1.3.1**, its server `appVersion` is **26.0.7**, and its locked
official dependency is **26.10.26**. The Ruby SDK remains **1.3.0**. No GitHub or
RubyGems release was published by this validation.

Official references:
[release notes](https://reportportal.io/docs/releases/Version26.0.7/),
[Compose source](https://github.com/reportportal/reportportal/blob/26.0.7/docker-compose.yml),
[Helm release](https://github.com/reportportal/kubernetes/releases/tag/reportportal-26.10.26).

| Component | Pinned version |
| --- | --- |
| API / database migrations / UI | 5.15.6 |
| Authorization / index | 5.15.2 |
| Jobs | 5.15.3 |
| Analyzer | 5.15.6 |
| PostgreSQL | 18.6 |
| RabbitMQ | 4.4.0-management |
| OpenSearch | 3.9.0 |

The official chart now requires **Kubernetes >=1.35**. Docker Desktop's existing
1.34.3 cluster was not upgraded in place. A separate kind 1.35.8 cluster named
`rp2607` was used, with kubeconfig `~/.kube/rp2607.config`; the global Kubernetes
context was not changed. Existing RP workloads were paused, never deleted. All
eight legacy PVCs retained their original UIDs, and no old PVC was mounted by
the new installation.

Kubernetes endpoint: `http://rp-2607.localhost:18080`.
Compose endpoint during acceptance: `http://localhost:28080`.
Compose uses independent project-scoped named volumes under `reportportal-2607`.
Only one full RP stack was active at a time to avoid local memory pressure.
Compose was stopped after acceptance without deleting reports; the new kind
installation was restored for interactive inspection. Old installations remain
paused, with their data retained.

## Regression And Real Backend Results

The complete RSpec suite passed **887 examples, 0 failures, 0 pending** in 157.56
seconds. The default offline Cucumber profile passed **1 scenario, 3 steps**.
The machine-readable summary accompanies this record in
`assets/reportportal-26.0.7-results.json`.

### Clean Main Publication Checkpoint

After merging the latest consumer-guide updates, clean candidate commit
`a05d7d819714cc7b7d27b0233e4bdb73387873ae` passed **865 RSpec examples, 0 failures,
0 pending** and **1 offline Cucumber scenario / 3 steps**. The earlier 887-example
working-tree check included unpublished Logger preview tests; those draft files
were intentionally excluded, not removed from the existing main test suite.

This clean candidate also repeated real Kubernetes acceptance: synchronous
Launch **8** confirmed **16 scenarios / 48 logs**, including the expected business
failure; asynchronous Launch **9** passed **5 scenarios / 19 persisted logs**.
Attachment bytes were reconciled again. Strict async receipts still correctly
remain locally settled but unconfirmed, with exit 2; API readback is separate.
No Logger formatting changes, SDK version bump, or new release tag is included
in this main publication.

| Real backend run | Native business result | Persisted RP result | Delivery receipt |
| --- | --- | --- | --- |
| Helm sync, Launch 4 | 16 scenarios: 15 passed, 1 deliberately failed | 4 suites, 16 scenarios, 48 logs | Complete; 48 confirmed |
| Helm async, Launch 7 | 5 scenarios passed | 1 suite, 5 scenarios, 19 logs | Locally settled; 19 awaiting persistence confirmation |
| Compose sync, Launch 1 | 16 scenarios: 15 passed, 1 deliberately failed | 4 suites, 16 scenarios, 48 logs | Complete; 48 confirmed |
| Compose async, Launch 2 | 5 scenarios passed | 1 suite, 5 scenarios, 19 logs | Locally settled; 19 awaiting persistence confirmation |
| Compose public `rake rp:regression`, Launch 3 | 7 scenarios: 6 passed, 1 deliberately failed | 7 scenarios with matching statistics | Expected business failure preserved |

Runs were single-process with join disabled. Both full synchronous runs included
`features/deep_water`, `complex_reporting.feature` and `protocol_calibration.feature`.
Async runs used the five scenarios from `complex_reporting.feature`.

The async distinction is intentional: HTTP v2 acknowledgements are **not** durable
SDK confirmations. With `RP_REQUIRE_COMPLETE_REPORTING=true`, the native process
correctly exited 2 and reported `complete=false`, `local_settled=true`; it did not
pretend to confirm persistence. Independent API polling subsequently found every
log. Neither mode had pending, failed, ambiguous, rejected or spooled log records
at local completion.

Each synchronous run downloaded 12 native attachments; each asynchronous run
downloaded 7. JSON, text, PNG, PDF and binary response bytes were SHA-256 compared
against the original files, not merely counted from successful upload responses.
Every persisted log belonged to the expected item. Scenario UUIDs and test-case
identities were distinct across Outline rows, with mapped attributes retained.

The API download route verified against service-api 5.15.6 is
`/api/v1/data/{project}/{dataId}`. Returned log levels are lowercase; assertions
normalize case rather than changing valid outgoing payloads.

## Physical Browser And Recording Acceptance

The browser was logged into both actual installations, not a mocked RP UI.
The following were observed in the new UI build **5.15.6**:

- Four peer Feature suites, with correct 16-scenario statistics.
- Clicking the Portfolio suite's Passed count returned four scenarios, not an
  empty list, with three separate Outline iterations and visible descriptions.
- The real UI contract stayed `SUITE/hasStats:true` -> Scenario
  `STEP/hasStats:true` -> Gherkin/manual `STEP/hasStats:false`. Scenario was not
  changed back into a `TEST` item that the UI would filter out.
- A five-column, ten-row DataTable rendered as an HTML table in the owning Step.
  A JSON DocString rendered as a code block, and Background kept its prefix.
- A real Playwright browser navigated Typewords `/words` -> `/dict-list` ->
  `/words`, then deliberately failed on an absent control. The original timeout
  exception survived unchanged into the After hook.
- Closing the browser context finalized an 8.52-second VP8/WebM recording.
  The **example framework**, not the SDK, converted it with ffmpeg to
  H.264/yuv420p MP4 with `+faststart`, then attached the finished file to an open
  manual node beneath the same Scenario's After hook.
- RP Launch 6 displayed that recording as an inline native video. Play was
  clicked, the recording reached its 8.52-second end, and the timeline was clicked
  to seek back to 2.516 seconds. No attachment renderer crash occurred.

The public video bytes matched the source MP4. A normal GET returned 200 and
`video/mp4`; a byte-range request returned 206. The video uses our same-origin
MinIO Markdown route, not RP's native binary video attachment renderer.

The example's Typewords onboarding tour could mount after network-idle. Its wait
now closes the visible tour and waits for the overlay to disappear; it does not
force clicks or hide a genuine obstruction.

Evidence:
[video playback and seek](assets/reportportal-26.0.7-video.jpg),
[Suite Passed filter](assets/reportportal-26.0.7-suite-passed.jpg),
[DataTable](assets/reportportal-26.0.7-datatable.jpg),
[Compose UI](assets/reportportal-26.0.7-compose.jpg).

Interactive video:
<http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/6/261/262/log>.
Expand **After Hook: After hook**, then **Finalize and publish testcase recording**.
Expand the video's long-log chevron if RP collapses its message.

## Startup, Security And Operations Checks

`helm test` succeeded. Compose `up -d --wait --wait-timeout 600` completed with
healthy long-running services and three successfully completed initialization jobs.
The gateway explicitly waits for bucket initialization, so Compose does not
mistake that successful one-shot exit for a failed application startup.

The one-click regression command now passes `--no-profile`; otherwise the default
offline profile excludes `@reportportal_live` and silently selects no live cases.
Two tests protect this entry point and its refusal of empty RP statistics.

Anonymous policy reconciliation was checked against the real MinIO server:
known-object GET/HEAD and Range succeeded; anonymous list, PUT and DELETE were
403. The stored policy contains only `s3:GetObject`. Thirty-day lifecycle rules
were read back. Compose also exercised `VIDEO_ANONYMOUS_READ=false`: an existing
video HEAD changed to 403, then returned to 200 after restoring read-only access.
The bucket and recording were never deleted.

The original public MinIO/mc image endpoints rejected fresh pulls. Both profiles
therefore use available pinned `bitnamilegacy/minio:2025.7.23-debian-12-r0` and
`bitnamilegacy/minio-client:2025.7.21-debian-12-r0`. These are **archived** builds,
not newly maintained storage releases. Production operators must scan, approve
and mirror them, or substitute an approved compatible object store/client. Local
pull success is not a security certification or an offline registry guarantee.

This is compatibility acceptance, not certification of HA, TLS, Huawei cloud,
disaster recovery, database migration or a new 15-minute endurance run. Single-node
OpenSearch can be yellow because of unassigned replicas. Upstream UI shared-module
version warnings and analyzer model-version warnings were visible but did not
block these tested reporting paths; they are not declared fixed by the SDK.

## Repeat The Supported Checks

Use Helm >=3.18.4. `--kube-version` below is for offline rendering only, never
a way to install onto an unsupported live cluster.

```sh
helm dependency build ./helm/reportportal-rich-experience
helm lint ./helm/reportportal-rich-experience --kube-version 1.35.0
HELM_BIN="$(command -v helm)" bundle exec rspec
bundle exec cucumber
helm package ./helm/reportportal-rich-experience -d ./pkg
```

For a real business regression, provision credentials securely, set `RP_ENDPOINT`,
`RP_PROJECT`, `RP_API_KEY` and the documented MinIO variables, then run
`bundle exec rake rp:regression`. Its intentional failed scenario is expected;
the task verifies the matching RP statistics. Follow
[Compose setup](../../deploy/compose/README.md) or
[Helm setup](../../helm/reportportal-rich-experience/README.md) for deployment.
Never attach old PostgreSQL/OpenSearch volumes or use `down -v` as an upgrade step.
