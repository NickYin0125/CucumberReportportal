# M4 Regression / Environment Sidecar

Status: FINAL COMBINED IQ5/IQ6 core/security/full/seed/M2M3, actual installed
package and authenticated localhost live API gates PASS on candidate `30uRDE`.
Master relayed Sol's final SCOPED PASS: final-installed 50/0, IQ1-IQ6 closed,
and his own read-only launch 47 API/UI reconciliation complete.
All runs occurred after the final source freeze. Earlier `n3saaM` and `wGrvJf`
results remain historical, not final artifacts. Current receipts remain
immutable. Browser and independent-review results are attributed external
evidence, not sidecar-performed reviews. Master owns final acceptance and the
overview/C aggregate/commit/tag; the tester is finished. Earlier scoped B receipts
remain historical evidence. No production code, root README, protected file,
service, credential or Git ref was changed by this sidecar. Only the two
explicitly authorized historical fixture adaptations were edited.

## Candidate And Gate Tooling

Final candidate `/tmp/m4-20261010-candidate.30uRDE`; manifest SHA
`49607259f627ca6818c37e863ed4bc55a38ab271102a62818cd605135b8c2357`.
All 146 candidate files and all 131 non-document workspace files passed final
hash comparison. Core 211/0, security 89/0, actual installed consumer and
35-library/alias audit PASS, full/seed 507/0 each, named M2/M3 80/0; all matrix
gate and aggregate exits 0. Matrix gates had a finite 240-second outer timeout.
An additional native default-profile `bundle exec cucumber` gate passed
1 scenario / 3 steps, exit 0, with all inherited `RP_*` cleared, unchanged
M3 cucumber.yml and a 180-second outer watchdog. Its unique evidence is
candidate `tmp/m4-20261010/native-default-ci-20261010T152705Z-14652/`.
The legacy log mock lacks an acknowledgement ID, so its output correctly warns
confirmed 0 / spooled 1 / reporting incomplete. This is native CI compatibility,
not actual delivery acceptance; installed/live gates supply that separate proof.
Gate evidence:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/gates/20261010T151830Z-12049/`.
Final package in that directory's `installed-package/reportportal-cucumber-ruby.gem`,
SHA `20a537c3cf708c0bf37191a3759fc962f2b9ce5b64c39c259c95a3ae31e0552e`.
Exact full, installed and live evidence is recorded in the final D and full
verification documents; the frozen candidate's document snapshot is not rewritten.

Historical IQ5-only matrix evidence is
`/tmp/m4-20261010-candidate.n3saaM/tmp/m4-20261010/gates/20261010T151104Z-9515/`:
core 201/0, security 89/0, actual installed consumer plus 35-library audit PASS,
full and seed 497/0 each, named M2/M3 80/0, aggregate exit 0. Its manifest SHA
is `a8b25e9c9b4dfeb7cc742f379abea7ec820c476ab81332cde2692444c640eb44`
(145 audited entries). No live write was made for this pre-IQ6 snapshot.

`tmp/m4-20261010/export-clean-candidate.sh` exports the current `m3` commit,
then overlays only `lib/`, `spec/`, README files, M4 design documents, `exe/`,
and the narrowly allowlisted `examples/m4_delivery_acceptance/` when present.
The example overlay is included in the candidate source manifest; no duration
examples are copied. Root `Gemfile.lock`, `Rakefile`, `cucumber.yml`, and
gemspec always begin from the M3 archive. The gemspec overlay is limited to
the two exact executable-packaging lines (`exe/**/*` and `spec.executables`),
requires both lines plus `M4_GEMSPEC_PACKAGING_APPROVED=1`, and rejects any
other gemspec delta. The four already-dirty development dependencies
(`puma`, `rackup`, `rantly`, `sinatra`) are deliberately ignored and never
copied. The export writes a source/protected-file SHA-256 manifest into the
candidate. Candidate outputs are separate from the workspace.

`tmp/m4-20261010/run-gates.sh` first audits every source-manifest hash and the
four protected base hashes, then checks bundle availability and confirms the
loaded SDK entrypoint is inside the frozen candidate. Both checks fail closed
before test execution. It retains one unique, non-overwriting evidence
directory per invocation, storing commands, output, and exit statuses; all
inherited `RP_*` variables are removed. Gates are `audit`, `core`, `focused`,
`security`, `installed`, `m2m3`, `full`, and `seed`; full/seed refuse to run without an explicit
`M4_C_D_STABILIZED=1`, and exit status aggregates all selected gates while still
running the rest and preserving every receipt. M4 specs are discovered with
portable `find` from inside the candidate, and an empty focus is a failure.

`tmp/m4-20261010/installed-gem-consumer.sh` builds and normally installs the
candidate gem into an isolated gem home, verifies every packaged `lib/` file
and executable source against the frozen manifest, and invokes each installed
CLI's `--help`. It then requires the M4-C candidate driver
`spec/support/m4_installed_gem_consumer.rb` (or an explicit
`M4_INSTALLED_CONSUMER` path inside the candidate) to prove actual request
payloads and UUID ownership from the installed gem. If that driver is absent,
the package/hash/CLI smoke receipts are retained but the gate fails explicitly;
no installed-consumer PASS is claimed from source-path tests or the smoke alone.
All three tooling scripts pass `bash -n`; the exporter was exercised
successfully for the final candidate. Both gate scripts have now actually run
and passed. The installed driver
exercises `--help`, no-I/O default dry-run, closed-UUID refusal, real JSON and PNG
multipart requests, controlled HTTP 503 ambiguity, per-entry acknowledgement
IDs, and resume without resending a confirmed entry. It checks actual loaded
SDK features under the installed gem root against candidate hashes, the
executable source hash, and the actual Cucumber version. The package shell gate
clears stale Ruby/Bundler variables; each CLI child also clears inherited
`RP_*` and Bundler settings before adding mock-only configuration. These are
actual passing assertions, not help-only smoke. The installed SDK is activated
before Cucumber and the consumer runs outside the source cwd, preventing
Cucumber's relative `lib` path from loading candidate files. Every loaded SDK
path remains strictly checked; all 35 library files and both compatibility
aliases were also required from and hash-verified under the installed root.
Global gems were not changed or uninstalled. Ruby/Bundler and `RUBYLIB` state
are cleared for actual installed execution.

After guarding the consumer's direct-entrypoint exit, a workspace-wide
collection-only check completed successfully: `bundle exec rspec --dry-run
--format progress` collected 371 examples with 0 collection failures (0.61s
load time; no examples were executed). The collection ran with inherited `RP_*`
variables removed, which confirms `spec/spec_helper.rb` can require every
support file without triggering the installed consumer or network work. This is
not a test-suite pass.

## M4-B Scoped Tester Checkpoint

The accepted scoped run used a fresh frozen candidate at
`/tmp/m4-20261010-candidate.tmOOYc`, manifest SHA-256
`bb21abfa64951c146b90acb2ac0dc535d2adff1b389b77bc6a62336ae9801bfe`. From the
candidate root, the exact command was:

```sh
/opt/homebrew/opt/ruby/bin/bundle _2.6.6_ exec rspec \
  spec/reportportal_cucumber/cucumber/m4b_completion_integration_spec.rb \
  spec/reportportal_cucumber/transport/deadline_m4b_spec.rb --format progress
```

Result: 12 examples, 0 failures, exit 0 (11.41 seconds), bounded by a 90-second
outer limit. Immutable command/output/status and manifest-hash receipts are at
`/tmp/m4-20261010-candidate.tmOOYc/tmp/m4-20261010/b-focused/20261010T133020Z-cumulative/`.
Coverage includes actual formatter/Cucumber business-failure preservation,
singleton and batch log acknowledgements, single-PNG multipart delivery,
capture-close and metadata failures, shutdown budgets/repetition/idle worker
stop, barrier cutoff and cumulative receipt counts, the 64-control-waiter bound,
one shared deadline, and confirmed first-chunk handling when a later payload
build fails.

The earlier red run is retained unchanged at
`/tmp/m4-20261010-candidate.g1zq1i/tmp/m4-20261010/b-focused/20261010T132718Z-gated/`
(manifest SHA-256
`5cce02b165edb3811ecf1867d7e03bb318055b0617a8c6f1fdaf3c260282bf82`, 12
examples, 5 failures, exit 1). It captured pre-fix harness/barrier behavior and
is not the final scoped result. The intermediate 11/12 run remains at
`/tmp/m4-20261010-candidate.il9HqK/tmp/m4-20261010/b-focused/20261010T132940Z-master-fix/`.
No full, seeded, security, or installed-consumer gate was run for this
checkpoint, and this scoped receipt does not replace Gibbs's coherent post-fix
three-spec B run or final M4 regression.

Suggested sequence after M4-B has stabilized and Master authorizes packaging:

```sh
M4_GEMSPEC_PACKAGING_APPROVED=1 tmp/m4-20261010/export-clean-candidate.sh
bash tmp/m4-20261010/run-gates.sh /tmp/m4-20261010-candidate.PATH focused security
```

Do not reuse the literal `XXXXXX`; pass the exact candidate path printed by
the exporter. Before M4-B stabilization, use only focused/security gates as
requested by the implementation owner. Native Cucumber 9 remains subject to
the existing event-loader collection limitation; an adapted lane is distinct
evidence and must never be labeled native 9.

## Runtime And Protected Baseline

Observed on 2026-10-10 local time: Ruby 3.4.2, Bundler 2.6.6, Docker Desktop
29.5.2, Docker context `desktop-linux`, Kubernetes context `docker-desktop`.
`bundle check` passes against the current workspace dependencies, but this is
not a clean-candidate resolution or a test result. The annotated `m3` tag object
is `0c2e5c66139688d8dcf60da6a8fac9440108044e`; the exporter dereferences it to
base commit `c9eacad5f1320e84f9660a413ef307d39f48d2de`, also `HEAD`. Workspace `Gemfile.lock`,
`Rakefile`, `cucumber.yml`, and gemspec differ from that base. The first three
are excluded by archive-based export; the gemspec has four unrelated
development-dependency additions plus the two approved executable-packaging
lines. Only those packaging lines enter the final candidate and package.
The exporter refuses undocumented gemspec changes and does not package those
four dependencies.

The final candidate has now run full/seed/security/installed gates. The scoped
B receipt above is historical focused evidence only; final results are recorded
below and in the two final verification documents.

## Read-Only ReportPortal Health And Auth

Docker Desktop is running. Kubernetes `docker-desktop` has the `reportportal`
namespace; API, UI, UAT, PostgreSQL, MinIO, RabbitMQ, jobs, index, analyzer,
and OpenSearch pods were Ready (the migration job Completed). The gateway
Ingress address is `172.19.0.4`; localhost routes are accessible without
starting port-forwarding. Read-only probes returned HTTP 200 for
`http://localhost/api/health` and `http://localhost/ui/`; the auth route
returned its expected HTTP 400 when probed without credentials. The available
RP target is `http://localhost`, project `superadmin_personal`.

The existing Kubernetes Secret `reportportal-uat-init-password` has a
`password` key. Its value was piped directly into an in-memory local auth
probe and was never printed, written to a file, or added to a command argument.
The established local username is `superadmin`; the UAT token exchange also
uses the existing local `ui` basic-auth flow. Authentication returned HTTP 200.
The short-lived bearer was kept in process memory only and was used for a
read-only `GET /api/v1/superadmin_personal/launch?page.page=1&page.size=1`.
That endpoint returned HTTP 200 and the ReportPortal v1 page shape with top
keys `content` and `page`; the page reported 22 total launch records. A launch
entry exposed `id`, `uuid`, `name`, `status`, `startTime`, `endTime`,
`statistics`, and other metadata; the sampled existing launch was terminal
`FAILED`. No launch/item/log was created or modified.

For a future live M4 invocation, a short-lived bearer can be consumed
privately by the orchestrator from the same Secret-backed auth flow, held in
memory, and passed only as child-process `RP_API_KEY`. Do not print or persist
the bearer, password, authorization headers, or raw auth response. Prefer the
Secret-backed flow over putting a literal in shell history. No credential value
is recorded in this document or the receipts. MinIO video upload is optional
and caller-owned; M4 live evidence should focus on queue/log delivery and
screenshot attachments, with no new video recording requirement.

The initial health pass was GET-only. The subsequently authorized live run now
verifies actual singleton/batch per-entry acknowledgement UUIDs, API item/log
counts and original attachment bytes. `/api/v1/api-docs` returned HTTP 200;
the guessed `/api/v2/api-docs` and `/api/v3/api-docs` routes returned 404. API
pages use `content`/`page`; items expose numeric `id`, original `uuid`, numeric
`parent`, type/stats/status. Log pages omit UUID values, but the documented
`/api/v1/{project}/log/uuid/{UUID}` route successfully reconciles the live
acknowledgement UUIDs to exact numeric log rows. Original data downloads use
`/api/v1/data/{project}/{dataId}`, with exact MIME, byte length and SHA.

## Scope And Handoff

No service teardown, port-forward, credential mutation, production
edit, README edit, protected-file edit, or commit was performed. Subsequent
Master authorization allowed only the missing-artifact builder-fault fixture
in `security_regression_spec.rb` and the logical-name Store-file discovery
fixture in `reportportal_chaos_spec.rb`; original assertions were preserved.
The historical Cucumber 9 native collection issue is acknowledged, and no loader
repair is in this sidecar's scope. After explicit live approval, this sidecar
created only its uniquely named M4 launches/items/logs on the existing target.
All failed candidates and failure receipts remain immutable. Master audits
the final candidate manifest and browser evidence.

## Actual D Checkpoint

Final candidate `/tmp/m4-20261010-candidate.30uRDE` ran core 211 / 0,
security 89 / 0, full 507 / 0, seed 20261010 507 / 0, named M2/M3 80 / 0,
actual installed requests/resume and all 35 library/alias provenance checks;
all exits are 0. All 146 source/example/document hashes and protected
candidate hashes passed audit. Runtime is Ruby 3.4.2 / Bundler 2.6.6 / native
Cucumber 10.2.0. Gate path: `gates/20261010T151830Z-12049/` under candidate
`tmp/m4-20261010/`. Exact manifest/package hashes are in
`reporting-experience-m4-full-regression-verification.md`.

Actual JSON/PNG retention, original Gherkin STEP ownership, automatic partial
and ambiguous HTTP-200 console warnings, passing business exit 0, fail-fast
400/401/403/404/422, retry 408/429/502/504, accepted-request response timeout,
bounded physical TCP shutdown, ENOSPC, strict original business-failure
preservation and missing-path raw fallback now pass. Earlier red evidence in
`c1yprK` remains intact. A native SIGINT child exits 2 in 25ms, with confirmed
1 / spooled 2 / pending 0 / complete false and original PNG ownership preserved.
No encoding reset or assertion relaxation is used.

Fresh final [launch 47](http://localhost/ui/#superadmin_personal/launches/all/47) is
FAILED by deliberate business outcome: total 3 / passed 2 / failed 1, exact
14 items / 9 logs. Scenario table/evidence IDs are 1029/1030 and 1034/1035;
original replay action is 1026 under attempt Scenario 1025. All nine actual
acknowledgement UUID lookups and three PNG downloads returned HTTP 200.
The valid shared 80x40 PNG is 327 bytes, SHA-256
`5b7a247dac8fc35737fe3485fd1242dfe15e9505f6b8eaba12c6065a85a4a5d2`.
Completed resume is exit 0/no HTTP; a new unconfirmed transaction on the same
closed targets refuses with exit 2/no POST/unchanged checkpoint. Details and
numeric log IDs 382 through 390 are in `reporting-experience-m4d-verification.md`.
Original data IDs are 19/20/21. API receipt:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/live/run-20261010T152208Z-13322/api-reconcile-20261010T152214Z-13356/receipt.json`.
Read-only health and final source/protected provenance are in candidate
`tmp/m4-20261010/final-health/`; every running pod was Ready, migrations
Succeeded and localhost health/UI were HTTP 200. Protected dirty root hashes
match the original observed values; only approved packaging lines differ in
the candidate gemspec. No native 9 or sidecar browser UI acceptance is claimed.
Master reviewed the older launch 46 statistics, PASSED filtering, JSON/table,
80x40 inline/popup PNG and original replay action. For new launch 47 he reported
successful statistics/PASSED filtering, the real table/fenced JSON/80x40 PNG and
native PNG preview. Master also completed original replay Scenario 1025/action 1026 JSON+PNG
and failed Scenario 1033/Then 1036 original-error/After-hook browser checks.
Master relayed Sol's final SCOPED PASS: final-installed 50/0, IQ1-IQ6 closed,
and read-only launch 47 API/UI reconciled. This supersedes the intermediate
32/0 checkpoint; no independent journey remains pending in this handoff.
Use Scenario LOG pages and expand the action rather than
direct non-statistical STEP LOG URLs. The pre-IQ5 466/0 and pre-IQ6 497/0
receipts and empty/red launches remain unchanged, clearly separate from final proof.
