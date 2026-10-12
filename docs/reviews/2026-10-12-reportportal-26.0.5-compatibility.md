# ReportPortal 26.0.5 Compatibility Acceptance

## Decision And Version Contract

**Client compatibility: passed for the explicitly pinned Cucumber 9/10 bundles.**
**Production security/availability certification: not granted.** This is a chart
upgrade candidate, not an in-place database migration or a claim of unrestricted GA.

The official release and chart were checked on 2026-10-12:

- [ReportPortal 26.0.5](https://reportportal.io/docs/releases/Version26.0.5/).
- [Official Helm chart 26.8.12](https://github.com/reportportal/kubernetes/releases/tag/reportportal-26.8.12).
- Wrapper chart `1.2.0-rc.2`, `appVersion: 26.0.5`.
- API/migrations `5.15.4`, UI `5.15.5`, authorization/index `5.15.1`, jobs `5.15.2`, analyzer `5.15.5`.
- PostgreSQL `18.4`, RabbitMQ `4.3.4-management`, OpenSearch `3.8.0`.
- Tested SDK: installed **unreleased** `reportportal-cucumber-ruby 1.2.0.pre.1`.

SDK runtime hashes were checked against the current working tree's 36 library
files before native execution. The base commit was `dc5559b`; pre-existing SDK
fixes were uncommitted. This chart-scoped delivery does not silently commit,
release or claim to reproduce those SDK fixes from the base commit alone.
The companion [sanitized manifest](2026-10-12-reportportal-26.0.5-manifest.json)
records the tested runtime hashes and accepted results.

## Physical Environment And Preservation

The new Helm release is `reportportal-latest` in namespace `reportportal-latest`,
on the local Docker Desktop Kubernetes context, Kubernetes `1.34.3`.
Its host is `http://rp-latest.localhost`, project `superadmin_personal`.
The final packaged chart was deployed as revision 3; all ten core pods were Ready,
migrations and the bucket initializer completed, and `helm test` succeeded.

The old `reportportal` release was paused by setting its ten workloads to zero
replicas. All four old PVCs remain Bound with their original UIDs. No old database,
attachment or report volume was deleted, reused by the new release, or migrated.
The old `http://localhost/ui/` endpoint is not expected to work while paused.

The initial pull exhausted Docker's old disk, causing the new PostgreSQL instance
to report `No space left on device`. With user authorization, Docker was stopped,
its disk setting changed to `81920 MiB`, and restarted. Its memory setting remained
`12288 MiB`. Only obsolete/dangling image and build caches were cleaned; report
volumes were not pruned. The new interrupted install was recovered without deleting
PVCs. A subsequent `pg_amcheck` passed **605 relations / 1398 pages**. Final disk
availability was approximately 20.6 GiB, rather than below OpenSearch's disk watermarks.

Single-node OpenSearch reports **yellow** because replica shards have no second
node. Its five primary shards are active; this is not an HA/green-cluster acceptance.

## Regression Results

| Layer | Accepted result | Meaning |
| --- | --- | --- |
| Full RSpec, Cucumber 9.2.1 / expressions 17.1.0 | 655 examples, 0 failures, 0 pending | Complete local suite, including bounded delivery, receipts, spool, retry, privacy, ownership and packaging |
| Full RSpec, Cucumber 10.2.0 / expressions 18.0.1 | 655 examples, 0 failures, 0 pending | Same full suite under the supported native formatter dependency |
| Live native Cucumber, six launch variants per bundle | 12 launches, 58 scenarios, 170 persisted logs | Native JSON/HTML/message outputs and delivery receipts reconciled against fresh RP API data |
| Live finalized Typewords recording, both bundles | 2 launches, 2 intentional failed scenarios, 10 logs | Genuine browser recordings, explicit After Hook ownership, original failure retained |
| Live original-node spool replay | 2 records confirmed, exactly 2 RP logs | Resume checkpoint causes no additional sends; closed original target is refused |
| PNG download | SHA-256 equals original bytes | Multipart binary integrity against the real server |
| MP4 public delivery | GET 200, `video/mp4`, byte-identical SHA-256, Range 206 | Same-origin MinIO route supports media reads and seeking |
| Helm local and production-profile lint | Passed | Both external-secret deployment profiles render successfully |
| Helm readiness test | Succeeded | Packaged release's upstream service health test |

RSpec uses controlled mocks for fault injection; it is not presented as 655 live
network tests. The separate native Cucumber and replay runs use the real new RP
backend. Every accepted native receipt is complete, with zero pending, failed,
ambiguous or spooled records. Business failures are intentional assertions, not
reporting failures: four of the core scenarios plus both recording scenarios fail
by design. Launch statistics match those expected outcomes.

Live coverage includes English/Chinese Feature, Rule, Scenario and Examples
descriptions; feature/rule Background; outline rows and unique UUIDs; escaped
DataTables; DocString fences; stable identities after line and Examples-column
changes; mapped attributes/links; HTTP 200/201/expected 400 exchanges; Typewords
Playwright success/failure, screenshot capture, and finalized recording publication.
Example issue/TMS URLs use `example.org`; their presentation/payload contract is
tested, not the availability of an external issue tracker.

## Real Browser Acceptance

Playwright Ruby `1.62.0` with CLI `1.62.1` drove a real Chromium browser, logged into
the new RP UI, and inspected persisted results without inserting replacement HTML.

- Launch 8 shows two peer suites with counts 5 and 3 and their English/Chinese descriptions.
- Clicking the English suite's **Passed** count lists its scenarios instead of `No results found`.
- The native UI filter still selects `STEP + hasStats:true`; Gherkin actions use `STEP + hasStats:false` beneath them.
- The ordinary scenario's DataTable renders as an actual HTML table, retaining an escaped pipe, a multiline cell and an empty final cell.
- Launch 18's recording is under the same scenario's `AFTER_METHOD` hook and explicit `Finalize and publish testcase recording` child, not a closed failed step.
- Expanding the video log's own long-message control reveals the complete native player and its controls.
- The player loaded a 1280x720, 9.56-second MP4; `currentTime` advanced while playing, then seeking to 4.78 seconds completed. No uncaught RP page errors were observed.

[Table evidence](assets/reportportal-26.0.5-table.png) and
[expanded native player evidence](assets/reportportal-26.0.5-video.png) are genuine
RP UI screenshots. The UI/API acceptance also confirms the selected node ancestry.

Useful local pages while this independent environment is running:

- [Two suites and descriptions](http://rp-latest.localhost/ui/#superadmin_personal/launches/all/8).
- [Rendered table](http://rp-latest.localhost/ui/#superadmin_personal/launches/all/8/181/182/log).
- [Finalized recording](http://rp-latest.localhost/ui/#superadmin_personal/launches/all/18/330/331/log).

## Deployment Correction And Remaining Gates

CloudPirates RabbitMQ initially grants the bootstrap user permissions on `/`, while
RP needs `analyzer`. The wrapper now sets `default_vhost = analyzer` while preserving
RabbitMQ 4.3's `deprecated_features.permit.queue_master_locator = true`. A separate
fresh broker with the exact pinned chart proved automatic `analyzer` permissions.
The already initialized local broker needed an explicit permission repair. This
configuration is not a retrofit for existing broker state; custom vhost settings
must change both the RP connection and RabbitMQ default vhost.

Cucumber 10 with expressions 19 hit a native message-builder `nil.map` failure;
that attempted run is retained as diagnostic evidence, not counted as accepted.
It was rerun with the example's existing expressions `18.0.1` constraint. No SDK
exception was swallowed or type mapping changed to disguise that dependency issue.
Cucumber 11 and arbitrary dependency combinations are not certified here.

The legacy `mc anonymous set public` policy grants anonymous write/delete, not
read-only access. Per the user's explicit exclusion it remains unchanged.
`makePublic=false` and disabling the extension do not revoke existing permissions.
The production **fresh-install** example disables that extension and uses external
Secrets plus TLS. Enabling production video requires a separately verified policy
and evidence-data security review. Same-origin routing is not a general CSP bypass.

The video route is NGINX-specific; Ingress NGINX retirement, a supported controller,
network policy, secret management, backups/restores, retention enforcement and
multi-node capacity/HA remain operator gates. Do not treat the local profile as
production sizing. PostgreSQL/OpenSearch major upgrades require the
[official migration procedure](https://github.com/reportportal/kubernetes/wiki/Migration-v26),
not `helm upgrade --reuse-values` against old volumes.

## Reproduction And Artifact

```sh
helm dependency build ./helm/reportportal-rich-experience
helm lint ./helm/reportportal-rich-experience -f ./helm/reportportal-rich-experience/values-local-latest.yaml
helm lint ./helm/reportportal-rich-experience -f ./helm/reportportal-rich-experience/values-production.example.yaml
bundle exec rspec
helm package ./helm/reportportal-rich-experience -d ./pkg
helm test reportportal-latest -n reportportal-latest --timeout 5m
```

Select the pinned Cucumber bundle for each regression lane; do not let an ambient
Cucumber 11 installation select the runner. Native live runs used an installed gem
in a private consumer, not `-Ilib` source injection. Each process had join disabled,
an explicit endpoint/project, bounded exit flush and a unique launch name. API
credentials were obtained from the new environment and kept out of committed files.

Artifact: `pkg/reportportal-rich-experience-1.2.0-rc.2.tgz`.
SHA-256: `c322202ca7b93b556e2cddef83c65dd34b2b7d09c142f8adfca378d35bf66df9`.
Official dependency archive SHA-256:
`13ed42cc1272ad6992d7dee5c7be3eb09260f30bf49fa3059da57c148b06724f`.

Full private receipts, native reports, source manifests and diagnostic attempts are
under `/private/tmp/reportportal-2605-validation-20261012`. The committed manifest
is sanitized: no OAuth tokens, credentials or raw Kubernetes Secret objects.
No new independent subagent review, GitHub Release upload or production deployment
was performed as part of this chart-only acceptance.
