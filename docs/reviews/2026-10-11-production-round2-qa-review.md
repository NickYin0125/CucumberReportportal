# Final V2 Independent QA Acceptance: PASS Within Scoped Exclusions

Completed 2026-10-12 Asia/Shanghai against the Master-authorized immutable V2 snapshot. No unresolved P1/P2 was independently reproduced in the final scoped acceptance runs. This is not unconditional production/security certification: D4/D10 anonymous policy is explicitly EXCLUDED and unchanged. No developer/reviewer historical passes are substituted for these results. V1 evidence remains historical, not V2 acceptance evidence.

## Provenance

- Source HEAD: `dc5559b0d077ca3dcca78257889c4c8e59d3d3f9`; branch `codex/reporting-experience-m4`.
- Master V2 manifest: `/private/tmp/reportportal-round2-master-20261011/PATCH_READY_V2.json`, SHA256 `966434637c24a2d4ba2068863d18da5c8c11d39642d8a4af74f6e5b6b0d626e9`. Authorized copy: `/private/tmp/reportportal-round2-qa-20261011/v2/PATCH_READY.json`.
- Frozen V2 source: `/private/tmp/reportportal-round2-master-20261011/frozen-source-v2`. All 266 manifest files verified. Own snapshot contains 265 files, deliberately excluding root `Gemfile.lock`; manifest-authorized `config/**/*`, including the join:false auto-discovery sample, is present for tests.
- Fresh V2 `1.2.0.pre.1` package: `/private/tmp/reportportal-round2-qa-20261011/v2/reportportal-cucumber-ruby-1.2.0.pre.1.gem`, SHA256 `3f516dcd5fbcd48b0d260c465ca08f55794e613625d3887d059d15cc3ce8c5a5`. Package has 158 files and excludes root config.
- Preserved V1 package: `/private/tmp/reportportal-round2-qa-20261011/reportportal-cucumber-ruby-1.2.0.pre.1.gem`, SHA256 `9159129a599c2b197548b911c9633f27d899a6d4d47cd50797415083056ac3fc`. V1 gate remains SHA256 `0e6e5916fb2ed620397fd1a170752dafc0fab42c8046db4d54cb7f72c2b63da2`; neither marker nor package was retargeted.
- Normal gem installation, not path-source, into `/private/tmp/reportportal-round2-qa-20261011/v2/gems`. Separate scratch Bundler Gemfiles/locks pin Cucumber 9.2.1 and 10.2.0. Ruby 3.4.2. All 68 captured installed-runtime records match the new 37-file lib/exe manifest and load SDK files exclusively from this gem home. Runtime integrity records include failed attempts; that does not turn those attempts into business passes.
- All 266 current source-manifest hashes and frozen-source hashes still match V2. Root lock, Rakefile, cucumber profile, and ten protected root/duration files match preparation hashes. QA made no production code, git, deployment, policy, descendant-task, or duration changes; this review is the sole production write. Requested model was GPT-6.1 Sol; model identity is not independently introspectable through the harness.

## Fresh Counts

| Independent scope | Fresh result |
| --- | --- |
| Full Cucumber 9 RSpec, entire spec directory | 649 examples, 0 failures, 0 pending, 0 outside-example errors; process 0; 106.641784 s |
| Full Cucumber 10 RSpec, entire spec directory | 649 examples, 0 failures, 0 pending, 0 outside-example errors; process 0; 102.974053 s |
| Own installed-gem queue/TLS adversarial specs | 4 examples/0 failures per lane; both processes 0 |
| Core native consumers | 20 processes, all expected exits; workflow results per run are 5 passed, 2 intentional failures, 1 skipped |
| Native/remote reconciliation | 364 local checks and 140 remote checks; zero failed checks |
| Partial-delivery fault matrix | 8 cases, 32 checks, all true |
| CI late-worker lifecycle | 2 Launches, 6 isolated workers, 20 orchestration checks, all true |
| Required missing-configuration resource matrix | 12 cases, 96 checks, all true |
| Duplicate formatter ownership | 2 lane cases, 28 checks, all true; 48 logs per lane |
| Sequential duplicate/unformatted ownership | 2 lane cases, 38 checks, all true; 96 logs per lane |
| Fresh AfterAll postscript readback | 6 Launch reads, 24 checks, all true |

Counts above are scope-specific, with overlapping checks, not a claimed sum of unique tests. RSpec uses the Bundler-pinned Ruby executable with `-Ilib -Ispec` and `Gem.bin_path('rspec-core','rspec')`; no global wrapper or skipped spec is needed. The first 12-case required-config matrix also passed before the fresh resource-observer repeat; it is retained separately, not counted twice as unique coverage.

## Live Ownership And Bytes

Existing DockerDesktop K8s ReportPortal at `http://localhost`, project `superadmin_personal`, was used with the frozen delivery-acceptance auth helper. Actual deployment versions observed: service-api 5.15.2 and UI 5.15.3. Credentials stayed in memory; authorization headers/passwords were not emitted or stored. Captured-process token-leak flags are all false. No anonymous policy changes were made.

| Lane/scope | Fresh Launch ID | Actual GET outcome | Confirmed receipt/remote logs |
| --- | --- | --- | --- |
| C9 API/Playwright workflow | 68 | FAILED: 5 passed, 2 expected failures, 1 skipped | 78/78, complete; 20 attachments |
| C10 API/Playwright workflow | 74 | FAILED: 5 passed, 2 expected failures, 1 skipped | 78/78, complete; 20 attachments |
| C9 hooks pass / teardown / business+teardown | 70 / 71 / 73 | PASSED / FAILED / FAILED | 3/3 / 4/4 / 5/5, complete |
| C10 hooks pass / teardown / business+teardown | 75 / 76 / 77 | PASSED / FAILED / FAILED | 3/3 / 4/4 / 5/5, complete |
| C9 CI-owned workers | 69 | FAILED: 2 passed, 1 intentional business failure | workers 3+4+3 = 10/10, complete |
| C10 CI-owned workers | 72 | FAILED: 2 passed, 1 intentional business failure | workers 3+4+3 = 10/10, complete |
| C9 duplicate formatters | 78 / 79 | Both PASSED, two scenarios each | 24/24 each, complete |
| C10 duplicate formatters | 82 / 83 | Both PASSED, two scenarios each | 24/24 each, complete |
| C9 sequential duplicate formatters | 97 / 98 / 99 / 100 | All PASSED, two scenarios each | 24/24 each, complete |
| C10 sequential duplicate formatters | 101 / 102 / 103 / 104 | All PASSED, two scenarios each | 24/24 each, complete |

Harmless real loopback GET/POST calls produced the expected 200/400 contracts. Real Playwright opened `http://localhost:5567/`, captured a successful readable page, and independently produced the expected missing-locator `Playwright::TimeoutError`, preserving the original failure and attaching its screenshot to the original action. Diagnostic HTTP/assertion ERROR evidence did not falsely fail the passed API scenario.

Each core workflow's 20 remote attachments was downloaded and reconciled by MIME, size, SHA256, and owning item. Six different collision payloads exercise equal PNG/log filenames and punctuation-normalized JSON filenames. Native attachment and explicit-evidence routes each contain all six exact payload hashes once: 12 distinct remote binary IDs per Launch, not six, with original bytes preserved. Five ordinary JSON/log/PNG/PDF/binary fixtures also retain exact bytes. JSON is 83,610 bytes; the original simple PNG fixture is 68 bytes. Native HTML embedded messages are decoded and compared to the message sink, rather than accepting raw encoded-text scans alone. All ten escaped, malformed, embedded, nested, oversized, header/query synthetic credential probes reached native/console/RP evidence without leaking canaries in text or downloaded binaries.

Duplicate and sequential cases reconcile every outgoing log's item UUID to the actual item-start response and its Launch UUID, then independently join fresh API log item IDs to item UUIDs and actual Launch IDs. All 288 accepted targeted ownership log entries match. Nested LIFO restoration, other-instance context isolation, and final cleanup are true. Each lane also ran two duplicate-formatted native invocations followed by a third unformatted invocation in the same process: native exits `[0,0,0]`, actual formatter counts `[2,2,0]`, zero HTTP activity from the third invocation, native logs preserved, and all four previous immutable receipts unchanged. No stale formatter owns the unformatted run.

CI starts and finishes the supplied-UUID Launch. Two workers start concurrently and exit before the late third process is started. Launch GET stays IN_PROGRESS after both early exits and after late exit; workers issue no Launch start/finish mutations. Every item-start uses the supplied UUID. CI finishes only after all fresh receipts; final statistics and ten persisted log owners reconcile.

For real native AfterAll failure, Launches 71 and 76 are actual API FAILED while their sole business scenario remains PASSED, native process exits 2, and each has exactly one Launch-owned ERROR reason: `Native AfterAll failed (RuntimeError): ROUND2_INTENTIONAL_TEARDOWN_FAILURE`. Fresh postscript GETs confirm this, not merely a submitted failed finish payload. No fake failed Scenario or global class-hook item was added. UI business statistics correctly remain Passed 100%; that percentage is not the Launch status. V1 Launches 54/58 were separately re-read and preserved but are not V2 proof.

Required reporting with implicit enablement and missing endpoint/project/key is transport-inert, runs business and AfterAll, exits 2, and returns incomplete cutoff 0 plus one configuration metadata failure and missing-option diagnostics. Observed API/log-buffer/queue constructor counts are zero and the loopback sees no request. Original business failure still exits 1; original teardown failure still exits 2. Explicit `RP_ENABLED=false` intentionally exits 0 with reporting off. Best-effort partial receipt exits 0, strict partial receipt exits 2, strict+business exits 1, and strict+teardown exits 2 in both lanes.

## Own UI And Evidence

Own Edge tab `148296599` viewed fresh V2 Launch 74's actual Passed drilldown, five passed scenario rows, formatted JSON preview and JSON attachment viewer, and the real Typewords PNG viewer. It also viewed Launch 76's Launch-owned native AfterAll ERROR reason. Five screenshots and paired accessibility observations are in `/private/tmp/reportportal-round2-qa-20261011/v2/evidence/ui-own-v2-*`; these are not Master screenshots or V1 UI proof.

![Fresh V2 formatted JSON viewer](/private/tmp/reportportal-round2-qa-20261011/v2/evidence/ui-own-v2-json-viewer.png)
![Fresh V2 Typewords PNG viewer](/private/tmp/reportportal-round2-qa-20261011/v2/evidence/ui-own-v2-png-viewer.png)

Final ledger: [evidence-rollup.json](/private/tmp/reportportal-round2-qa-20261011/v2/evidence/evidence-rollup.json), SHA256 `1c32a96dd2aa44a474eb5bbe29a721949245f60f666484d8feec719f087cd148`. Fresh [artifact-manifest.json](/private/tmp/reportportal-round2-qa-20261011/v2/evidence/artifact-manifest.json) inventories 1,180 evidence artifacts by byte size/SHA256, digest `5377365914f9b7b68fd41cc007033626d9770b60a461565639fd4b06d3bd06ec`; manifest and rollup exclude their own cyclic entries. Harness hashes, both package hashes, source/runtime hashes, full counts, Launch UUIDs, receipts, ownership joins, API readbacks, downloads, and UI observations are retained. A separate new inventory records 1,023 V1 artifacts without changing V1's old ledger; all 887 original V1 inventory records remain hash-identical.

Provenance clarification: [reconciliation.json](/private/tmp/reportportal-round2-qa-20261011/v2/evidence/reconciliation.json) is a **historical pre-UI native/API reconciliation capture**. Its retained limitation `CUA manual drilldown/image/JSON verification pending until performed` describes that earlier capture phase, not current acceptance. The later sealed final rollup explicitly has `own_fresh_ui_complete: true`. The supplemental [final UI acceptance postscript](/private/tmp/reportportal-round2-qa-20261011/v2/final-ui-acceptance-postscript.json) records `current_ui_pending: false`, all five completed screenshot/accessibility pairs with verified SHA256/byte sizes, own tab identity, fresh Launch 74 drilldown/JSON/PNG evidence, and fresh Launch 76 AfterAll ERROR evidence. It is outside the sealed 1,180-artifact inventory. Reconciliation, final rollup, artifact manifest, screenshots, and original checksums were not overwritten or regenerated.

## Retained Attempts And Limits

- V1: normal offline gem install lacked mime-types cache; first C9 offline bundle resolution lacked dependencies; normal cached install/network scratch resolution succeeded. Initial RSpec wrappers exited 127, and C9 split Core-event import attempts ran zero examples: NOT PASS. A deliberately partial C9 run was 591 examples/7 C10-hardcoded assertion failures, not a full pass. C10's two 608/0 full runs are V1 only, not V2 counts.
- V1: the first eight workflows hit the harness Playwright executable path-with-spaces failure; all were rerun under new labels. Own adversarial stderr restoration and initial six-versus-twelve collision-route expectation errors were corrected with retained failed attempts. Browser availability and credential executable-path errors, incomplete initial reconciliation, and the independently reproduced inactive-required-reporting exit-0 P2 remain historical evidence. The accepted duplicate-formatter P2 came from independent review; V2 is independently verified here.
- V2: initial normal local gem install exited 2 for absent dependency cache; first C9 offline Bundler resolution exited 6, then normal cached install and scratch network resolution succeeded. No SDK or package payload edits were made to repair harness setup.
- V2: initial C10 duplicate fixture with the `{string}` parameter hit Cucumber message-builder `nil.map`, exit 2; the same no-RP-formatters control also exited 2. Both attempts and initial fixture are retained. Literal portable step registrations reran both lanes with all ownership assertions, not a skipped gate. Initial C9 duplicate success remains supplemental; final selected results use the fresh portable labels.
- V2: first sequential harness failed on an unnecessary Enumerator `flatten` before the unformatted run; this partial run is NOT PASS. Later auth/readback attempts timed out while existing PostgreSQL briefly reported 0/1 Ready; it recovered without QA deployment action. Two captured wrapper retries lacked `/usr/local/bin/kubectl` in the harness PATH; fresh retries succeeded after correcting only own scratch PATH. Initial partial reconciliation files are retained separately, as are all captured stderr/process records. Authentication failures before consumers started are not claimed as native executions.
- Queue deadline/capture revocation and TLS verification/default boolean behavior are installed-gem unit/adversarial evidence, not live TLS infrastructure certification. No live MP4, extra video, long-duration/load expansion, policy mutation, or deployment changes are included. The final acceptance is limited to this local environment, supported Ruby/Cucumber lanes, and expressly stated exclusions.
