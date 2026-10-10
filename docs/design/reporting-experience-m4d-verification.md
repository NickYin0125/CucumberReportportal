# M4-D Verification

Status: FINAL COMBINED IQ5/IQ6 D, INSTALLED, FULL/SEED AND LIVE API GATES PASS.
Master relayed Sol's final SCOPED PASS: final-installed 50/0, IQ1-IQ6 closed,
and his own read-only launch 47 API/UI reconciliation complete.
The final candidate was exported after all source freezes; the new authenticated
localhost run and exact API reconciliation completed. Existing code/examples
remain frozen and all earlier red and green receipts remain immutable.
Master owns final acceptance; browser and independent-review results are
attributed external evidence, not sidecar-performed reviews. No commit or tag was made.
Additional native CI passed 1 scenario / 3 steps, exit 0. Its expected legacy
stub warning is retained; this fixture does not prove complete RP delivery.
Master subsequently reported successful live statistics/PASSED-filter browser
review for launch 46; this is attributed human review, not sidecar UI inspection.

## Final Combined Freeze And Gates

Candidate `/tmp/m4-20261010-candidate.30uRDE`; manifest SHA-256
`49607259f627ca6818c37e863ed4bc55a38ab271102a62818cd605135b8c2357`.
Initial and post-live audits verified all 146 candidate files. A separate
workspace comparison verified all 131 non-document files with zero mismatches;
Master independently reported the same result. Final verification documents
are post-run outputs, not changes to the frozen candidate.

| Gate | Actual Result | Exit |
| --- | --- | --- |
| C/B/D core, replay API/CLI, IQ5/IQ6 diagnostics | 211 examples / 0 failures | 0 |
| Historical security/native privacy | 89 / 0 | 0 |
| Actual installed package consumer | JSON/PNG/fault/closed refusal/resume PASS | 0 |
| Installed all-library provenance | 35 libraries including both aliases PASS | 0 |
| Full regression | 507 / 0 | 0 |
| Seed 20261010 | 507 / 0 | 0 |
| Named M2/M3 regression | 80 / 0 | 0 |
| Additional native default-profile CI smoke | 1 scenario / 3 steps passed | 0 |

Aggregate exit 0. Evidence:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/gates/20261010T151830Z-12049/`.
All runs had finite outer limits. Runtime is Ruby 3.4.2, Bundler 2.6.6 and
native Cucumber 10.2.0; no native 9 PASS is claimed.

Final installed package:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/gates/20261010T151830Z-12049/installed-package/reportportal-cucumber-ruby.gem`.
SHA-256 `20a537c3cf708c0bf37191a3759fc962f2b9ce5b64c39c259c95a3ae31e0552e`.
The actual installed consumer ran outside any source cwd with Ruby/Bundler/RP
state cleared, checked actual loaded SDK paths/hashes, and made exactly three
physical log POSTs: JSON 200, PNG 503, then original PNG 200 on explicit resume.
Confirmed JSON was not resent. CLI help, successful no-network inspection,
closed-target refusal, checkpoints and original UUID/byte ownership passed.
No outside-loaded SDK file was skipped, no global gem was uninstalled, and no
help-only or source-consumer result is labeled installed acceptance.

Final production/source hashes (production was read-only to this tester):

| Source | SHA-256 |
| --- | --- |
| Config | `95720923017e2305cc6ae4807574d904b6c402834a8514a18901efcca9655909` |
| Store | `1501cf09a68373e2fbfc9e17085fb27b1f2f1547ae9cfca1aa2a806119640c4b` |
| Queue | `f6895596115226c08117a1a7c3bb35a79ce6b515c17b9a1c11019a4e5b9bee50` |
| Replay | `527013e8d3747a66d136587ec9e8831c71753bf7b8313dff8cf9ab7d2ada472e` |
| Formatter | `4533d0b22c91ef09b6b5240ddbd816927028521500fd13c43108a28968f0be63` |
| HTTP | `6035abef231af83d5eb34029299de9251b068bd0a3bb8a0aa7ed5cca5369ab51` |
| Executable | `3e290599e9edd104f0ac6afada14144abc3403710df641333f5afd38de5c67f5` |
| README | `53d0d2d8655a205030ed37c276ffa4409a8e056f93f6b9a857faf4012ac98178` |

## Final Live ReportPortal Result

Existing target `http://localhost`, project `superadmin_personal`.
Read-only health: all running Kubernetes pods Ready, migrations Succeeded,
health/UI HTTP 200. Existing Secret-backed auth stayed in memory; no credential
value or authorization header was printed or stored. No service, port-forward,
infrastructure or credential was changed.

Launch [47](http://localhost/ui/#superadmin_personal/launches/all/47), UUID
`41b91550-97b8-4f73-81a4-2b20489f8ae4`, name
`M4 delivery acceptance 2026-10-10T15:22:08Z f1833c`, is deliberately FAILED.
Exact statistics: total 3 / passed 2 / failed 1. Two actual native scenarios ran
and the deliberate original assertion/message remained visible with exit 1.
The controlled replay attempt is the third statistical leaf.

| Ownership | Numeric IDs |
| --- | --- |
| Controlled Feature -> replay Scenario attempt 1 -> original action | 1024 -> 1025 -> 1026 |
| Native Feature -> passing Scenario | 1027 -> 1028 |
| Passing table / JSON+PNG evidence / assertion / After hook | 1029 / 1030 / 1031 / 1032 |
| Native Feature -> failed Scenario | 1027 -> 1033 |
| Failed table / JSON+PNG evidence / original error / After hook | 1034 / 1035 / 1036 / 1037 |

Table and evidence Gherkin STEP items have `hasStats=false`; Scenario STEP
items have `hasStats=true`. JSON and PNG use the same exact active STEP UUID:
passing `eddeb036-c1eb-4e8d-9fe0-823da2157823`, failed
`84269156-e187-4041-8d82-e3fe2032bccf`. Replay action UUID is
`c80c4380-82e0-46db-a29b-bc915933053a`, under original Scenario UUID
`d9f0e07f-0ec7-4e79-b6f2-3904695303d6`, attempt 1. No replacement or retargeting.

Exact API inventory: 14 items / 9 logs, including the two ordinary After hooks
and two automatic table logs. All nine real per-entry 2xx acknowledgement UUIDs
were individually fetched via `/api/v1/superadmin_personal/log/uuid/{UUID}`;
each HTTP-200 result matched its exact numeric log row, item, epoch-ms time,
message and binary metadata. Paginated rows omit UUID; equivalence is proven
by those lookups, not inferred from counts.

| Log | Owner STEP | Content | Acknowledgement UUID |
| --- | --- | --- | --- |
| 382 | 1029 | Passing table | `b6073c24-7f7d-4bc0-8b3a-cbb8e0891169` |
| 383 | 1030 | Passing fenced pretty JSON | `cdb11f9e-87a1-495c-abef-02e9fd1d6f3f` |
| 384 | 1030 | Passing PNG, data 19 | `380420cd-5d6b-498e-97fa-001782b37c7e` |
| 385 | 1034 | Failed table | `bcc6e5f9-933d-4613-a33f-9e9f7f0e2c3f` |
| 386 | 1035 | Failed fenced pretty JSON | `73eeb341-dfb9-4b0c-999b-4605fbb2bdac` |
| 387 | 1035 | Failed-scenario PNG, data 20 | `dec581ce-2c4c-4d86-81b9-cfefd963ab5b` |
| 388 | 1036 | Original business error | `f1bff765-f63d-43b3-bf01-29b6a5133dbc` |
| 389 | 1026 | Original replay JSON | `29b68d6e-043b-4480-8b6c-c485cb18670e` |
| 390 | 1026 | Original replay PNG, data 21 | `34223366-4383-40a3-8d16-7130acf5c4ef` |

Original PNG data 19/20/21 each downloaded HTTP 200 as image/png, 327 bytes,
SHA-256 `5b7a247dac8fc35737fe3485fd1242dfe15e9505f6b8eaba12c6065a85a4a5d2`.
The CRC/raster-tested shared asset is 80x40 RGB. All message hashes, original
UUIDs and exact times are retained in the API receipt. Open-target replay
confirmed 2/exit 0. Completed resume after closure was exit 0 with zero HTTP.
A new unconfirmed transaction bound to the same closed original targets was
exit 2, no POST, unchanged checkpoint. Launch finishing preserved FAILED.

Live receipt:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/live/run-20261010T152208Z-13322/receipt.json`.
API receipt (15 read-only GETs, all HTTP 200):
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/live/run-20261010T152208Z-13322/api-reconcile-20261010T152214Z-13356/receipt.json`.
Health/source/protected provenance:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/final-health/`.

User-facing Scenario LOG review URLs (expand the named action):

- [Passing Scenario](http://localhost/ui/#superadmin_personal/launches/all/47/1027/1028/log), table 1029 and evidence 1030.
- [Failed Scenario](http://localhost/ui/#superadmin_personal/launches/all/47/1027/1033/log), table 1034, evidence 1035 and error 1036.
- [Original replay attempt](http://localhost/ui/#superadmin_personal/launches/all/47/1024/1025/log), expand action 1026.

Master observed that direct non-statistical STEP LOG URLs stay blank in this
UI, while the Scenario LOG with expanded action works. This is navigation
guidance, not a claimed product regression. Master owns new-launch UI review;
the sidecar claims API/byte evidence only.

## Final Tester Handoff

The tester's final combined matrix, actual installed consumer, healthy
authenticated live run and exact API/byte reconciliation are complete on
candidate `30uRDE`. Exact package/manifest identities and Scenario LOG URLs
above were handed to Master; source, package, runtime, protected hashes and
all red receipts remain immutable. No code changes are needed for this handoff.

Master reported actual launch 47 browser verification: two suites, total 3 /
passed 2 / deliberate failed 1; the native Suite PASSED filter showed only
Scenario 1028; its real Given table, fenced pretty JSON and 80x40 PNG were
visible; clicking the PNG opened the native preview without crashing. These
are attributed human checks, not sidecar browser claims. Screenshots:
`/tmp/m4-final-ui/launch47-statistics.jpg`,
`/tmp/m4-final-ui/launch47-passed-scenario.jpg`,
`/tmp/m4-final-ui/launch47-table-json-png.jpg`,
`/tmp/m4-final-ui/launch47-json-png-visible.jpg`,
`/tmp/m4-final-ui/launch47-png-preview.jpg`.
Master subsequently completed original replay Scenario 1025 LOG review:
action 1026 retained its JSON and decoded PNG. Failed Scenario 1033 visibly
retained its original error on FAILED Then STEP 1036 and a passed After hook.
Additional screenshots:
`/tmp/m4-final-ui/launch47-replay-original-step.jpg` and
`/tmp/m4-final-ui/launch47-business-failure.jpg`.

Master relayed Sol's final report: SCOPED PASS, final-installed 50/0 with
IQ1-IQ6 closed, plus his own read-only launch 47 API/UI reconciliation. This
supersedes the intermediate 32/0 checkpoint; no independent journey remains
pending in this handoff. These are attributed external results and do not
replace the tester's own retained installed/API evidence. Master owns the final
acceptance overview, C aggregate, Git commit and tag. The tester is finished;
no further source, candidate or service changes are part of this handoff.

## Additional Native CI Gate

Executed from frozen `30uRDE`, with all inherited `RP_*` cleared:

```sh
/opt/homebrew/opt/ruby/bin/bundle _2.6.6_ exec cucumber
```

Unchanged M3 default profile excludes `@reportportal_live`. Actual native
Cucumber 10 result: 1 scenario passed, 3 steps passed, exit 0; process elapsed
0.74s, Cucumber-reported 0.050s, no watchdog used (180-second outer limit).
No duration overlay, live write, source modification or assertion change.
Evidence (command, run.log, exit, receipt and 14 input-file hashes):
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/native-default-ci-20261010T152705Z-14652/`.
Cucumber.yml SHA is the protected M3 baseline
`3abbe0bf2c241fd8f0694ec7c7088f1ce06486479b46aad0b244df15eca48428`.
Read-only Git blob comparison confirmed all 14 native inputs match M3 exactly,
with zero mismatches; `m3-input-audit.json` is retained in the same directory.

The existing formatter-contract fixture returns HTTP 200 with
`responses:[{message:ok}]`, lacking a log acknowledgement ID. Its automatic
warning is therefore truthful: confirmed 0 / spooled 1 / pending 0 /
reporting incomplete. The scenario asserts formatter call sequence and PNG
presence, not remote confirmation. That scope is not widened into a delivery
PASS; installed-consumer and real launch 47 evidence separately prove actual
acknowledgements, UUID ownership and exact bytes. The legacy fixture was not edited.

## IQ5 Matrix (Pre-IQ6)

Candidate `/tmp/m4-20261010-candidate.n3saaM`, manifest SHA-256
`a8b25e9c9b4dfeb7cc742f379abea7ec820c476ab81332cde2692444c640eb44`,
145 audited entries. Core 201/0, security 89/0, installed actual JSON/PNG consumer
and all-library provenance PASS, named M2/M3 80/0, full 497/0 and seeded 497/0.
All individual exits and aggregate exit were 0, with finite 240-second gate
limits. Evidence:
`/tmp/m4-20261010-candidate.n3saaM/tmp/m4-20261010/gates/20261010T151104Z-9515/`.
No new live launch or final package handoff occurred after Master's IQ6 hold.

## Pre-IQ5 Freeze And Gates

Candidate: `/tmp/m4-20261010-candidate.wGrvJf`.
Manifest SHA-256:
`83c33df5cf5a0ac1329f33a904e9b20322a3a53e580e2221f61926c6fd812225`.
All 143 source/example/document entries and protected candidate hashes passed
audit before execution. Final workspace comparison found zero differences in
all 127 lib/spec/exe/example files. Verification documents are post-run outputs;
the candidate and its earlier document snapshots remain immutable.

| Gate | Actual Result | Exit |
| --- | --- | --- |
| C/B/D core plus replay CLI/API | 170 examples / 0 failures | 0 |
| Historical security/native privacy | 89 / 0 | 0 |
| Actual installed package consumer | JSON/PNG/fault/closed refusal/resume PASS | 0 |
| Installed library/alias provenance | All 35 libraries and both aliases PASS | 0 |
| Full regression | 466 / 0 | 0 |
| Seed 20261010 | 466 / 0 | 0 |
| Named M2/M3 regression | 80 / 0 | 0 |

Exact gate evidence:
`tmp/m4-20261010/gates/20261010T145527Z-4150/` inside that candidate.
Ruby 3.4.2, Bundler 2.6.6 and native Cucumber 10.2.0 were verified.
Native Cucumber 9 acceptance is not claimed.

Package:
`tmp/m4-20261010/gates/20261010T145527Z-4150/installed-package/reportportal-cucumber-ruby.gem`.
SHA-256 `55808c8882864ace4d963fe34c961afbdc6e71b10a613e2418be007014a7d1e1`.
The installed consumer makes exactly three real loopback log POSTs:
JSON 200, PNG 503, then the original PNG 200 after explicit duplicate opt-in.
The confirmed JSON is not resent. Default inspection exits 0 without HTTP;
closed original targets exit 2 without POST. Actual loaded SDK paths/hashes,
all packaged libraries, compatibility aliases and CLI source are verified under
the installed root, not inferred from Gem::Specification alone.

Pre-IQ5 production hashes, unchanged by this sidecar:

| Source | SHA-256 |
| --- | --- |
| Formatter | `4533d0b22c91ef09b6b5240ddbd816927028521500fd13c43108a28968f0be63` |
| Replay | `a9e8c968e24a78a5ea324bcd20fbd27cee1b095e62e21ac51c2769b798a3d330` |
| Queue | `f6895596115226c08117a1a7c3bb35a79ce6b515c17b9a1c11019a4e5b9bee50` |
| Store | `873978d57f4e63b401ad1cc6338ac9abf9e484cb4c9d3844617192f2bd0f7944` |
| HTTP | `6035abef231af83d5eb34029299de9251b068bd0a3bb8a0aa7ed5cca5369ab51` |
| Executable | `8bc6360f056aa3f38eb748eb7207a60bd67596e8530a797f770c59725d30addc` |

## Native Interruption And Asset

New `m4d_interrupt_spec.rb` physically signals only its own native Cucumber
child after the actual multipart request marker. Final core child completed in
25ms after one SIGINT, exited 2 (Cucumber 10's native first-INT trap), used no
watchdog, and retained the original JSON plus PNG under the original Gherkin
STEP UUID. Its truthful receipt is cutoff/settled 3, confirmed 1 (the native
SystemExit diagnostic), spooled 2, ambiguous 2, pending 0, complete false.
Automatic incomplete console warning agrees with the receipt. No fake Kernel
exit, encoding reset, zero-loss promise, or SIGKILL durability claim is used.
Final combined receipt:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/gates/20261010T151830Z-12049/core/d-children/m4d-interrupt-20261010-12071-v76ge7/`.
The actual final child elapsed 25.137ms after SIGINT and used no watchdog.
The older pre-IQ5 receipt remains at
`core/d-children/m4d-interrupt-20261010-4182-3uksj2/` under its historical gate.
The first fixture red, which had not accounted for Cucumber's diagnostic log,
remains in candidate `S59zlJ`; scoped corrected green remains in `1MViVr`.

The live example uses a shared stdlib-generated 80x40 RGB PNG, 327 bytes,
SHA-256 `5b7a247dac8fc35737fe3485fd1242dfe15e9505f6b8eaba12c6065a85a4a5d2`.
New `m4d_fixture_spec.rb` checks every chunk CRC, exact IHDR fields, IEND,
decompressed scanline lengths/filter bytes and every raster pixel. Local image
rendering succeeded. Existing unit-test opaque binary bytes were not changed
and no SDK attachment conversion was added.

## Pre-IQ5 Live ReportPortal Result

Existing target: `http://localhost`, project `superadmin_personal`; no service,
port-forward, infrastructure, credential or global gem was changed.
Authentication used the existing Secret-backed flow in memory only.

Launch [46](http://localhost/ui/#superadmin_personal/launches/all/46):
UUID `238c43c8-bc86-4a36-a6cb-a02fd8bf958c`,
name `M4 delivery acceptance 2026-10-10T14:58:03Z a729ba`, status FAILED.
Exact statistics: total 3, passed 2, failed 1. The two native scenarios ran;
their deliberate original assertion was visible and Cucumber exited 1. The
third statistical leaf is the separately controlled original replay attempt.

| Ownership | Numeric IDs |
| --- | --- |
| Controlled Feature -> replay Scenario attempt 1 -> original action | 1010 -> 1011 -> 1012 |
| Cucumber Feature -> passing Scenario | 1013 -> 1014 |
| Passing table -> JSON/PNG evidence -> assertion -> After hook | 1015 / 1016 / 1017 / 1018 |
| Cucumber Feature -> failed Scenario | 1013 -> 1019 |
| Failed table -> JSON/PNG evidence -> deliberate error -> After hook | 1020 / 1021 / 1022 / 1023 |

All table/evidence/action STEP items have `hasStats=false`; both Scenario STEP
items have `hasStats=true`. JSON and PNG share the exact evidence UUID:
passing `5dd64a7f-7d85-43a1-8304-fc6eba49186c`, failed
`712eeb1b-01d1-45b8-83c2-61eaf8a703c1`. Original replay action UUID is
`04842b7c-592a-4037-af4c-ded65a08363c`, under Scenario UUID
`a53c45a4-c6cf-4e9a-9133-f3963f9a9c10`, attempt 1. No replacement STEP was made.

API reconciliation: exactly 14 items and 9 logs. The additional two items are
the ordinary After hooks. Logs include two automatic table logs, two fenced
pretty JSON logs, two scenario PNG logs, the original business error, and two
replay logs. All nine POST entries have distinct actual 2xx acknowledgement
UUIDs. Paginated reads omit the UUID field, but each acknowledged UUID was then
queried using `GET /api/v1/superadmin_personal/log/uuid/{UUID}`: all nine
HTTP-200 results matched the exact numeric log row, owner, time, message and
binary metadata. No UUID equivalence is inferred merely from counts.

| Log | Owner STEP | Content | Actual Acknowledgement UUID |
| --- | --- | --- | --- |
| 373 | 1015 | Passing table | `228e1d2d-9570-4e3b-bada-d009532bfe8e` |
| 374 | 1016 | Passing fenced JSON | `09d27b82-f5eb-4754-8ac2-92b66bbeff55` |
| 375 | 1016 | Passing PNG, data 16 | `b0a551bb-ec88-4605-87b9-9ee1ca78e292` |
| 376 | 1020 | Failed table | `97a0b7fb-2914-439e-8eb5-c5b4bf2ff332` |
| 377 | 1021 | Failed fenced JSON | `4b937887-58a2-49f4-a921-c538f04bcc22` |
| 378 | 1021 | Failed-scenario PNG, data 17 | `7189be34-7e2c-4b32-855b-21803d0ea517` |
| 379 | 1022 | Original business assertion/error | `7a334f27-b976-494c-bdf3-68fd6e1d49db` |
| 380 | 1012 | Original replay JSON | `88bbc320-5008-4455-ae76-2b907a9d6f80` |
| 381 | 1012 | Original replay PNG, data 18 | `d56b0d24-4d15-4fbf-a921-a687a4da678c` |

All three original PNG downloads via `/api/v1/data/superadmin_personal/{id}`
returned HTTP 200, image/png, 327 bytes and the exact valid fixture SHA above.
Every log's epoch-ms time, original item UUID, message SHA and actual API
numeric ID is retained in the reconciliation receipt.

Open-target replay confirmed 2 and exited 0. After finishing the original
child/parent tree and launch, completed resume exited 0 with zero HTTP calls.
A separate new unconfirmed transaction bound to those same closed original
UUIDs exited 2 explicitly, made no POST, and preserved its checkpoint.

Live receipt:
`/tmp/m4-20261010-candidate.wGrvJf/tmp/m4-20261010/live/run-20261010T145803Z-5114/receipt.json`.
Stronger UUID/API reconciliation receipt:
`api-reconcile-20261010T150012Z-5700/receipt.json` under that live directory;
15 read-only requests, all HTTP 200. The earlier count/bytes-only reconciliation
receipt is retained at `api-reconcile-20261010T145824Z-5232/`.

Browser-review URLs, supplied for Master rather than claimed inspected here:

- Passing Scenario: `http://localhost/ui/#superadmin_personal/launches/all/46/1013/1014/log`.
- Failed Scenario: `http://localhost/ui/#superadmin_personal/launches/all/46/1013/1019/log`.
- Original replay attempt: `http://localhost/ui/#superadmin_personal/launches/all/46/1010/1011/log`.

## Retained Attempts

Empty live attempts 44 and 45 are terminal FAILED. They ran zero native cases
because the protected M3 default profile excludes `@reportportal_live`; no
invalid PNG was uploaded. Their private receipts remain under candidate
`LF0BhD/tmp/m4-20261010/live/` and `live-no-profile/`. A PATH shim was not selected
ahead of Bundler's own executable path. Master authorized the actual example's
`--no-profile` argument and explicit exactly-two-scenario check instead. The
protected cucumber.yml was never edited. Candidate `ZFBoP9` is superseded by
the valid shared asset and its CRC/raster test in the final freeze.

Earlier installed reds remain in candidates `gQFMuo` and `LF0BhD`: the first
required globally newest Cucumber before package activation, and the next
ran from a source cwd where Cucumber adds relative `lib` to its load path.
The fixture now activates the installed package first and runs from a private
non-source cwd. No outside-loaded file assertion was removed or skipped, and
no global gem was uninstalled. Every final loaded SDK/alias path is verified.

## Historical Source Blockers (Resolved)

The following failures belong only to their named older candidates. The final
Formatter/Queue/Store fixes passed the unchanged meaningful assertions in
candidate `30uRDE`; no source blocker remains in the final executed matrix.

Fresh candidate `/tmp/m4-20261010-candidate.c1yprK`, manifest SHA-256
`5d084fa161d9f794f2e608a8816fe72afeebd068f51d22926b9d9a5cc7ef6586`:
core 160 examples / 1 failure, exit 1; security 89 / 1, exit 1.
Immutable receipts are at
`tmp/m4-20261010/gates/20261010T143431Z-96339/` inside that candidate.
The 138-file source inventory and protected hashes passed before execution;
runtime is Ruby 3.4.2 / Bundler 2.6.6 / native Cucumber 10.2.0.

Actual candidate source hashes:

| Source | SHA-256 |
| --- | --- |
| Store | `873978d57f4e63b401ad1cc6338ac9abf9e484cb4c9d3844617192f2bd0f7944` |
| Queue | `18fde205885cbdfbc34074c3fd2de4b6355606ae2f4ecd719e58df5d69731e50` |
| Formatter | `3f944e79afc741e2c8aac6aaaad85f061530414fcdd0bb005c9a90c2b5f60201` |
| HTTP | `6035abef231af83d5eb34029299de9251b068bd0a3bb8a0aa7ed5cca5369ab51` |
| Replay | `5e611ca366d240fe7b1624d90cc5b96d39fdf4a8ceda3ed707c4a8a9ac739097` |
| Executable | `8bc6360f056aa3f38eb748eb7207a60bd67596e8530a797f770c59725d30addc` |

The PNG binary-IO and five fail-fast outcome failures from the prior candidate
are now green without resetting global encoding, changing bytes, or weakening
pending-state assertions. Partial and ambiguous HTTP 200 children preserve the
passing business exit 0, automatically warn once, retain the exact original
PNG SHA-256 and action/Scenario/Feature ownership, and spool 1 / 2 entries.

Then-failing exact examples:

1. `cucumber/m4d_reporting_integration_spec.rb[1:4]`: strict reporting masks an
   executed deliberate business assertion. The fixture now injects PUT 503 only
   on the actual named When action after execution, never before-hooks or suites.
   Captured `business_executed=true`, `business_failure=true`, both fault bodies
   have `status=failed`, but native Cucumber returns 2 instead of business exit 1.
   Its stderr starts `HTTP 503 (ReportportalCucumber::Transport::HTTPClient::Error)`;
   the progress output lacks the ordinary completed business-failure summary.
   The default strict=false case preserves exit 1 and the original message.
   Passing strict opt-in and an explicit early Before-hook failure each correctly
   return Cucumber's actual exit 2 with its captured reporting-error cause.
   The harness does not synthesize an exit status for rescued exceptions.
2. `cucumber/security_regression_spec.rb[1:4]`: raw fallback remains empty for
   the deleted path after the actual HTTP failure and injected builder fault.
   All original privacy, UUID, time, binary artifact and unavailable-marker
   assertions remain intact. Binary Store IO alone did not repair this path.
   `QueueProcessor#raw_spool` calls `PayloadBuilder.normalize_attachment`, whose
   `normalize_attachment_path` rejects the missing path before Store receives it.
   A non-network diagnostic on this exact candidate independently reproduces
   `ArgumentError: Attachment file does not exist`; direct Store publication of
   the same missing-file descriptor succeeds. Receipt:
   `tmp/m4-20261010/missing-raw-probe/result.json` (probe exit 1).

The strict child is retained at
`core/d-children/m4d-public-metadata-20261010-96368-bqsv6x/` under the latest gate.
Both source paths were subsequently fixed by their implementation owners and
passed in the final fresh candidate. No production source was edited by the tester.

## Actual Core Receipts

Prior candidate `/tmp/m4-20261010-candidate.jKX6o1`, manifest
`d14d7f9b2f55049a532bc336a03ed11f409b27450f64c52cbb899efde9fcc7d5`:
core 145 / 11, exit 1; security 89 / 1, exit 1; receipts
`gates/20261010T142938Z-94481/`. Four core failures concern binary Store IO,
five concern failed HTTP outcomes checkpointed as ambiguous, and two concern
the initially overbroad strict fixture. That fixture's mechanics were corrected,
then actual post-business strict masking was independently reproduced above.
Intermediate public-fixture diagnostics remain at candidate `dTwvDt`,
`public-checkpoint-20261010T143356Z-96081/`; their four failures include corrected
status-case/nested-matcher mechanics and a missing explicit early hook.

`/tmp/m4-20261010-candidate.NhxwgF`, manifest SHA-256
`eb20e6114cdaf9f92d59bd35dae6eadf77c1f2f1323fd0147072a482375fac84`:
core C/B/A plus replay CLI/API: 85 examples, 0 failures, exit 0.
Security: 89 examples, 1 failure, exit 1. Receipts:
`tmp/m4-20261010/gates/20261010T141531Z-89274/` inside that candidate.
The preceding source-audit wrapper failure (empty Bash array under nounset) is
retained at `gates/20261010T141520Z-89215/`; no tests ran in that attempt.

`/tmp/m4-20261010-candidate.mnuIOu`, manifest SHA-256
`a2831a1e2098a7024f44e2758288856e0b3d7387ac96526608e28892e6cbe1d6`:
core: 99 examples, 4 failures, exit 1; security: 89 examples, 1 failure, exit 1.
Receipts: `tmp/m4-20261010/gates/20261010T141804Z-90341/`.
Runtime: Ruby 3.4.2, Bundler 2.6.6, native Cucumber 10.2.0, candidate SDK entrypoint.
All manifest source/protected-file hashes passed audit before execution.

The four core failures are Noether's transport/replay target-lookup tests:
HTTP 404 and 422 were each sent five times instead of once, plus two original
target GET 404 cases retried five times. Noether's subsequently frozen HTTP
source is `6035abef231af83d5eb34029299de9251b068bd0a3bb8a0aa7ed5cca5369ab51`;
the old candidate remains red evidence, not final proof for that new source.

## Historical Security Finding (Resolved)

The historical fixture deleted a PNG after real HTTP transport failure and
expected a raw fallback. With Master's narrow authorization, the fixture now
injects a real payload-builder exception for that missing PNG after the HTTP
failure. The test name describes that mechanism. No original assertion was
removed: privacy, native artifact metadata, UUIDs, timestamps, attachment bytes,
and missing/unavailable markers remain required; ordinary mode remains non-raw.

The historical injected child had no raw records. Investigation receipts are at
`candidate.mnuIOu/tmp/m4-20261010/security-investigation/spool-fallback/`.
The observed child reported builder faults and 37 normal spool records, but
zero raw records. `QueueProcessor#raw_spool` calls `normalize_attachment`, which
calls `normalize_attachment_path` and raises for the deleted source before
Store can record unavailable metadata. A direct Store probe published the
same missing-file marker successfully. That fallback path was subsequently
repaired by the Queue owner. Every original
assertion was retained and final security passed 89/0.

## Executed D Coverage

New `service/delivery_faults_m4d_spec.rb` covers queue outcomes across
408/429/502/504 retry success and duplicate risk; 400/401/403/404/422 one-attempt
failure; partial HTTP 200 sibling retention; real accepted-POST/response-timeout
ambiguity; one 80ms shutdown deadline with physical TCP; offline connection
attempts; and ENOSPC publication failure. The short socket timeout is explicitly
stubbed before constructing the actual client because Config's integer timeout
minimum remains one second. Physical sockets use an explicit loopback allowlist.

New `cucumber/m4d_reporting_integration_spec.rb` runs actual Cucumber children,
checks the automatic final incomplete warning for partial/ambiguous HTTP 200
with business exit 0, verifies PNG bytes and original parentage, preserves an
already-failed assertion with strict reporting false and true, and tests strict
opt-in reporting failure for otherwise-passing business. The formatter object
is captured at instantiation; no optional consumer summary prints the warning.
All these D cases executed and passed in the final coherent core, full and
seeded gates, including strict already-failed-business exit 1 preservation.
The physical TCP, offline, retry/status, deadline, partial sibling and ENOSPC
cases are green without changing their outcome assertions or opaque bytes.

The guarded live example now builds controlled Feature SUITE -> Scenario STEP
with stats -> original action STEP without stats, finishes child before parent,
and preserves the deliberate Cucumber failure as launch FAILED. It uses proper
Cucumber formatter `--out` arguments, fenced pretty JSON on the original action,
completed replay resume with exit 0/no HTTP, and a separate unconfirmed
transaction for closed-target refusal. Final live API reconciliation passed
for launch 47 above; new-launch browser acceptance remains Master's work.

Master also reported C Store/replay symbol-file integration, entry-index binding,
confirmed-sibling summary, symlink-root lock side effects, and reserved-name
collision findings. The implementation owners repaired those paths before the
final freeze, and the fresh combined candidate passed actual installed, live,
full and seeded acceptance. Existing localhost health returned HTTP 200 and all
running ReportPortal Kubernetes pods were Ready. Only owned M4 data was created;
no infrastructure or credential was changed.
