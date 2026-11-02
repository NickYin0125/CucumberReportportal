# M3B verification record

Status: **PASS (2026-10-07)**. Implementation source remains frozen and approved. Saved local outputs, the correct server-history query, and Master's completed physical UI acceptance pass the M3B gates. The frozen identity contract is documented in [the M3B implementation and migration contract](reporting-experience-m3b-implementation.md).

## Local acceptance

Final clean candidate: `/tmp/m3b-20261007-clean-final`, rebuilt from base `d9688b74a177cb359747fcd81e599d3528e9f3c3` plus 26 approved M3A/M3B paths. The snapshot manifest contains 142 files; three additional gate-generated artifacts make the current directory inventory 145 files. Snapshot, directory, and generated-artifact lists are recorded separately under `tmp/m3b-20261007/`, with SHA-256 values for every snapshot file and copied overlay. Current dirty duration work and root dependency/manifests were excluded. All 67 `lib/` and `spec/` files compare byte-for-byte across the workspace, frozen tested `/tmp/m3b-20261007-clean`, and final candidate. README contains only the previously approved concise M3B configuration/migration note.

Captured final-candidate results: full RSpec **191 examples, 0 failures**; base Cucumber **1 scenario / 3 steps passed**; M3A fixture **8 scenarios / 40 steps passed**; M3B subprocess integration **2 examples, 0 failures**. The separately rerun root M3B focus and isolated Cucumber 9.2.1 M3B focus each passed **2 examples, 0 failures**. Actual outputs and exit statuses are saved under `tmp/m3b-20261007/`. The gem built to `/tmp/m3b-20261007-gemtest/reportportal-cucumber-ruby.gem`, installed under `/tmp/m3b-20261007-gemtest/gemhome`, and loaded `ScenarioIdentity`; activation evidence is in `gem-install-proof.txt`. Existing gemspec warnings were observed; no project dependency or manifest changed.

Captured native Cucumber progress summaries were `5 scenarios (1 flaky, 4 passed)` for the legacy and both stable fixture runs, and `1 scenario (1 passed)` for the environment-ID-only run. The two native attempts for the fail-once scenario produce six statistical Scenario start requests in each full run, alongside one Suite and six action starts.

| ID | Acceptance | Evidence/status |
| --- | --- | --- |
| M3B-01 | Legacy default and literal explicit ID plus legacy parameter suffix. | **PASS locally**: independent subprocess payload checks and clean full RSpec. |
| M3B-02 | Stable identity invariant to line movement and Examples header order at the same URI/root. | **PASS locally and server-hash check**: codeRef moved from lines 6/9/12/21 to 7/10/13/22; stable IDs and returned `testCaseHash` values matched across launches. |
| M3B-03 | Changed datasets remain distinct/reported; stable wire params sort without changing M3A display/column order. | **PASS locally and in Master UI**: alpha/beta remain distinct; the Passed-5 drilldown has five rows and the Examples description retains source column order `[amount, region, case]`. |
| M3B-04 | Ambiguous/unavailable AST warns and falls back to legacy. | **PASS locally** in clean full RSpec. |
| M3B-05 | Environment ID precedence; explicit ID is an opaque digest seed in stable mode. | **PASS locally**. Raw-seed UI search is not guaranteed; M3C human attributes/links are not implemented. |
| M3B-06 | Latest-attempt Suite aggregation; failed then passed yields passed Suite, legacy unchanged. | **PASS locally and live statistics**: both stable launches finished PASSED, each `total 5 / passed 5`; class-hook protocol case passed synthetic unit coverage only. Native `BeforeAll` is not evidence for `BEFORE_CLASS`. |
| M3B-07 | Fresh execution UUIDs and retained, attempt-owned logs. | **PASS locally and live**: each launch retained failed/pass retry items and both marker logs on their corresponding actions. |
| M3B-08 | Real server case hash/history and migration baseline, with no inferred pass from client IDs. | **PASS API and Master UI**: five stable-v1 case groups span launch #1/#2 with matching server `testCaseHash`; clicking the old fallback cell opens launch 28/case 712 and its original log. The incomplete query's 409 is preserved separately; the correct launchId query returns 200. No physical legacy-to-stable baseline comparison is claimed. |

The independent subprocess test verifies:

- Legacy-default API `testCaseId` and `uniqueId` against independently reconstructed pre-M3B wire semantics; the model specs separately pin historical helper golden values.
- Stable-v1 test and unique IDs across paired fixture variants with inserted unrelated lines and reversed Examples headers.
- Sorted/canonical parameter identity while preserving all parameter keys and values in the outbound payload, including changed dataset rows as distinct cases.
- Explicit ID use and source-fallback stability for the fixture's tagged and untagged scenarios.
- Environment `RP_TEST_CASE_ID` precedence over the scenario's `@tms:` tag in the actual API payload.
- Unique execution UUIDs for all attempts and stable identity across the same scenario's native retry.
- Retry request marker, attempt-specific logs and finish ordering without asserting mock-server retry group statistics.
- Legacy behavior remains unchanged; local capture is not an oracle for latest-attempt Suite aggregation.
- Stable-v1 outbound Suite finish status is `passed` after fail-then-pass, while the same legacy-mode fixture remains `failed`; this checks client payload behavior, not mock launch statistics.
- Mutable parameter key/value strings remain unfrozen and writable after stable helper execution; the result uses detached frozen canonical copies.
- The process exit behavior with Cucumber progress output and the ReportPortal formatter written separately; no native message/HTML compatibility claim.

The tests must report actual failures rather than loosening expectations. In particular, equal outgoing IDs are only a client-payload observation and do not establish the server's `testCaseHash` or history grouping.

## Live ReportPortal acceptance

Two sequential live launches used the exact same launch name, project, feature URI (`/tmp/m3b-20261007/live-checkout/features/m3b.feature`), identity root, and namespace. Variant A ran first; variant B overwrote the same URI. Both child processes exited 0 and emitted `5 scenarios (1 flaky, 4 passed)`. No Kubernetes resources, services, namespace, or ports were changed. Login token stayed in process memory and was not recorded. Safe server responses and exact query strings are saved in `live-api.json`; actual child statuses are saved in `live-child-runs.json`.

The live command ran from `/tmp/m3b-20261007-clean` using that directory's Gemfile and `--require /tmp/m3b-20261007-clean/lib/reportportal_cucumber.rb`. Step definitions were loaded from `/Users/nick/Documents/New project/spec/fixtures/m3b/support/m3b_steps.rb`, which explains the workspace path in the intentional failure's stack trace. Those fixture contents match the frozen candidates. Live execution loaded source; installed-gem activation was verified separately by the package smoke.

| Launch | Launch URL | RP launch ID / UUID | Server latest-attempt statistics |
| --- | --- | --- | --- |
| #1 | [M3B-20261007-stable-history #1](http://localhost/ui/#superadmin_personal/launches/all/28) | `28` / `220df6e9-d5ab-4d1c-8f37-5a6db307347e` | `total 5 / passed 5`, status `PASSED` |
| #2 | [M3B-20261007-stable-history #2](http://localhost/ui/#superadmin_personal/launches/all/29) | `29` / `16f7472b-94cb-4064-bf1f-bb6c2f123f1f` | `total 5 / passed 5`, status `PASSED` |

Each launch returned one Suite, five latest statistical Scenario rows, and six action rows through the launch item list. The failed retry Scenario is retrievable by its server item ID even though the launch list presents the latest grouped row. The two source code references moved by one line per variant while test identity remained stable. Server-returned `testCaseHash` values matched between launches: explicit `-1225601682`, source fallback `1377043825`, dataset alpha `-1660260562`, dataset beta `1768694274`, and retry `-672233673`. The failed and passed retry Scenario executions shared the retry hash and uniqueId but had fresh UUIDs.

| Retry execution | Case URL | Item ID / UUID | Status | Owned marker log |
| --- | --- | --- | --- | --- |
| Launch #1 failed | [API item 718](http://localhost/api/v1/superadmin_personal/item/718) | `718` / `17b54257-172e-434a-b650-63b2acbc7db0` | `FAILED` | action 719, log 276: `M3B_RETRY_ATTEMPT 1` |
| Launch #1 passed | [API item 720](http://localhost/api/v1/superadmin_personal/item/720) | `720` / `c7320925-3be2-4a4e-81e3-2e9160a6e28b` | `PASSED` | action 721, log 278: `M3B_RETRY_ATTEMPT 2` |
| Launch #2 failed | [native retry 1](http://localhost/ui/#superadmin_personal/launches/all/29/722/733/log?logParams=retryId%3D731) | `731` / `1595fa1a-bce4-4937-b536-8160b6248893` | `FAILED` | action 732, log 283: `M3B_RETRY_ATTEMPT 1` |
| Launch #2 passed | [native retry 2](http://localhost/ui/#superadmin_personal/launches/all/29/722/733/log) | `733` / `2e705c39-3c09-498e-ba9c-075d95711cd4` | `PASSED` | action 734, log 285: `M3B_RETRY_ATTEMPT 2` |

The incomplete query `filter.eq.testCaseId=rp:stable-v1:<retry-digest>&page.page=1&page.size=50` returned HTTP 409 / error `40030`; it omitted a required history selector. The deployed service image is `reportportal/service-api:5.15.2`. Its version-matched [TestItemController source](https://github.com/reportportal/service-api/blob/5.15.2/src/main/java/com/epam/ta/reportportal/ws/controller/TestItemController.java) accepts `filter.eq.launchId`, `filter.eq.parentId`, or `filter.eq.id` as history selectors. The corrected query `filter.eq.launchId=29&historyDepth=10&isLatest=false&page.page=1&page.size=100` returned HTTP 200, five Scenario groups across launch #1 and #2, and the failed retry nested under the passed latest row. The exact safe response is in `live-api.json`. This verifies live stable identity history continuity; no legacy live launch was made, so no legacy-to-stable baseline comparison is claimed.

Master's physical UI verdict is **PASS (2026-10-07)**. Launch 29 / Suite 722 shows total 5 / passed 5, and the Passed-5 drilldown contains five rows. The Examples description retains source column order `[amount, region, case]`. Native History contains five rows with Execution #2 / #1 both PASSED in all ten cells.

Clicking the source-fallback old #1 cell opens [launch 28 / Suite 709 / case 712 logs](http://localhost/ui/#superadmin_personal/launches/all/28/709/712/log); the expanded action displays `M3B_CASE {"case":"fallback","amount":"20"}`. This confirms history navigation across the actual codeRef change from line 9 to line 10. Latest retry 733 displays only `M3B_RETRY_ATTEMPT 2` and PASSED. Selecting native retry 1 with `logParams=retryId%3D731` shows FAILED, only `M3B_RETRY_ATTEMPT 1`, and the original intentional exception/stack. Switching back to retry 2 restores PASSED.

The six original screenshots are `tmp/m3b-20261007/master-{launch,passed-filter,history,history-old-case,retry-passed,retry-failed}.jpg`. Master subsequently logged back in and reread [History 29 / 722](http://localhost/ui/#superadmin_personal/launches/all/29/722/history), confirming five rows, Execution #2 / #1, Total 5 and Passed 100%; `master-history-closeout.jpg` records that final confirmation. The History tab remains open as the user-facing deliverable.

## Cucumber 10.2.0 hook limitation

Source inspection of the installed Cucumber 10.2.0 runtime shows `Runtime#run!` calls `fire_before_all_hook` before initializing its report visitor and before compiling features through the filter that emits `test_run_started`. A failing `BeforeAll` therefore aborts before the native reporter's launch/scenario event stream; the hook message type is `BEFORE_TEST_RUN`, not a `BEFORE_CLASS` item. The M3B fixture deliberately has no native `BeforeAll` failure and makes no claim that this live path is fixed. The SDK's synthetic event/protocol unit test covers a `before_class` failure with retry aggregation. Legacy mode's hook behavior remains unchanged.

Overall M3B acceptance is **PASS**, with Master's physical UI verdict recorded above. Coverage remains limited to the recorded gates: no physical legacy-to-stable baseline comparison, no native `BeforeAll` integration fix, focused Cucumber 9.2.1 coverage only, and no native message/HTML compatibility claim. The installed-gem smoke is separate from the source-based live runs.
