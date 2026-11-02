# M3C-C Live ReportPortal UI Verification

Status: **LIVE REPORTPORTAL API AND PHYSICAL UI ACCEPTANCE PASS (2026-10-08)**.

This record is reserved for the physical ReportPortal run of the already-frozen
M3C attributes/links implementation. It must not imply GitHub/GitLab, external
CI, or external TMS integration: links target a synthetic immutable fixture
repository and a loopback reference server. ReportPortal itself is the real
local Kubernetes deployment.

## Fixture and Expected Results

The independent source-derived expectation is two peer Feature Suites and five
Scenario items: four passed, one deliberately failed. The failed Scenario must
retain its error action/log. Attribute and link features are enabled together,
identity is `stable_v1`, client joining is disabled, and reporting errors are
fatal. `RP_TEST_CASE_ID` is unset in the primary run so tag IDs remain distinct.

The two Outline rows are separate Examples blocks with distinct IDs and
attribute overrides. The fixture also includes Feature/Rule/Scenario/Examples
tag inheritance, Rule prose, Scenario prose, an ordinary case without an
explicit ID, formatted Examples data, a DataTable and a DocString on actions,
and a second peer suite. Source links use a committed synthetic source snapshot
with a real immutable SHA and the actual Examples row line. CI-style links point
to the local record for this run. TMS links point to encoded synthetic fixture
case references only.

## Live API Evidence

The final physical run is launch **35**, UUID
`9186b85c-fa0c-406d-aaf1-5a1c83369f34`, at
`http://localhost/ui/#superadmin_personal/launches/all/35`. Its terminal status
is `FAILED` with end time `2026-10-08T10:47:12.536Z`; this is expected because
one Scenario deliberately fails. Launches 30–34 are
superseded exploratory runs and are not acceptance evidence. The independent
source expectation and ReportPortal launch statistics agree: 2 peer Suites,
5 Scenarios, 4 passed, 1 deliberately failed. The failed case is Scenario 848;
its failed action 849 retained one matching `error`-level log owned by that
action. Scenario item IDs are 836, 840, 844, 848, and 851. Cucumber 10.2.0 exited 1 as expected for the one
deliberate failure; the live runner itself exited 0 after checking the real API.

The acceptance target is the existing Kubernetes context `docker-desktop`,
namespace `reportportal`, project `superadmin_personal`. API image is
`reportportal/service-api:5.15.2`; UI image is
`reportportal/service-ui:5.15.3`. Pods were Ready (migrations completed).
Credentials came from the established local demo authentication flow; the
short-lived bearer remained in process memory and no token, password, or
authorization header was saved. The product checkout was on
`codex/reporting-experience-v1-2`, HEAD
`d9688b74a177cb359747fcd81e599d3528e9f3c3`; its pre-existing dirty changes
were preserved. The accepted SDK candidate at
`/tmp/m3c-links-20261007-clean` was used read-only. Its 84 `lib/` and `spec/`
source files match the workspace candidate; only `spec/.DS_Store` differs.
No SDK file was changed for this live fixture.

The fixture source snapshot is synthetic Git commit
`83807328b768f7f4fa2e29554b7217c07ff94819` in
`tmp/m3c-live-20261008/sandbox`; it is not the product repository HEAD. The
loopback reference server binds only `127.0.0.1:8873`, verifies the requested
SHA equals the synthetic repository HEAD, and serves source with `git show`
from an exact path allowlist. It escapes source text before highlighting. Its
other routes serve only this run's explicitly labeled local CI-style record
and synthetic TMS case pages. Source, local-run, and encoded `CASE-UI/42`
destinations each returned HTTP 200. These are not claims of external CI/TMS
integration.

The Rule tags `team:identity` and `layer:api` are physically above `Rule:`;
Scenario/Outline tags are below it. The independent API oracle confirms Rule
inheritance, Scenario `owner:scenario-owner`, and staff Examples override
`owner:identity-team`. `tmp/m3c-live-20261008/api-verification.json` records
21/21 passing independent checks against real ReportPortal API items and logs:
exact full business-attribute maps (including raw TMS values and no TMS on the
no-ID profile case), Scenario-only attributes/references, unique Scenario
UUIDs/stable IDs, expected Suite and action parentage, exact Markdown
destinations and Outline row lines 22 and 27, source commit equality, all three
live reference routes, and the retained ERROR-level log under failed action
849. Other sanitized receipts include `handoff.json`,
`items-api.json`, `run-summary.json`, `fixture-repo.json`, and the child
`cucumber.stdout.log`. No authorization material is present.

Commands and results: `ruby examples/m3c_live/run.rb` exited 0 after the real
ReportPortal launch and API count check; its child Cucumber run exited 1 as
expected. `ruby examples/m3c_live/verify_live.rb` exited 0 with 21/21 checks.
Ruby syntax checks passed for the helper scripts. No full RSpec gate was rerun;
the accepted 255-example baseline was not changed.

## Physical UI Acceptance

Master physically reviewed launch 35 in Edge, logged into the real ReportPortal
UI 5.15.3 backed by API 5.15.2. Verdict: **PASS**. The launch overview showed
2 peer Suites, 5 Scenarios, 4 passed, and 1 failed. Each screenshot and DOM
receipt is saved under `tmp/m3c-live-20261008/browser/`.

| Review | Physical observation | Evidence |
| --- | --- | --- |
| Launch topology | Two peer Suites; 5 total / 4 passed / 1 failed. | `launch-topology.jpg`, `launch-topology.txt` |
| Passed filter | Recovery Suite Passed=3 returned exactly staff, guest, and malformed-request Scenarios (1–3 of 3), with no empty result. | `passed-filter.jpg`, `passed-filter.txt` |
| Staff details and Rule attributes | Item details showed Rule prose, original Scenario prose, staff Examples table at row 22, inherited `team:identity` / `layer:api`, and Examples overrides `owner:identity-team`, `browser:webkit`, `priority:p1`. Raw TMS `CASE-UI/42` remained distinct from the stable-v1 wire ID. The final screenshot is scrolled so all three actual links are visible; the original DOM receipt is unchanged. | `scenario-references.jpg`, `scenario-references.txt` |
| Source click | ReportPortal opened a real new tab at synthetic commit `83807328b768f7f4fa2e29554b7217c07ff94819`, highlighted row 22, and displayed angle-bracket source text escaped safely. | `source-click.jpg`, `source-click.txt` |
| CI Run click | Opened the local run record for `m3c-live-20261008-893dc87d`, identifying Launch 35 and 5 / 4 / 1 as a local CI-style demo. | `ci-click.jpg`, `ci-click.txt` |
| TMS click | Opened the synthetic fixture page and decoded the path ID as `CASE-UI/42`. | `tms-click.jpg`, `tms-click.txt` |
| Guest details | Guest showed `priority:p2`, inherited `browser:chromium`, `owner:scenario-owner`, and source row 27. | `guest-details.txt` |
| DataTable action | Expanded Given action rendered the two-column `user` / `staff` table and bold Given keyword. | `step-datatable.jpg`, `step-datatable.txt` |
| DocString action | Malformed request Given action rendered its JSON code block. | `step-docstring.jpg`, `step-docstring.txt` |
| No-TMS case | Profile Scenario showed no `tms` attribute and only Source + CI Run references; stable-v1 identity remained present. | `no-tms-details.jpg`, `no-tms-details.txt` |
| Attribute and failure filters | Native Attribute combobox `component:identity` plus Apply returned 2 cases; adding Status=Failed returned exactly the deliberate failure. | `attributes-failed-filter.jpg`, `attributes-filter.txt` |
| Failed action log | Failed Scenario 848 expanded to failed action 849 and its single ERROR stack log. Browser dev errors during validation: `[]`. | `failed-step-log.jpg`, `failed-step-log.txt` |

The final staff Item details page remains open in Edge. The API oracle and UI
inspection agree. This certifies only the local ReportPortal UI/API and the
controlled fixture links; it does not claim GitLab, GitHub, Jira, an external CI
provider, or an external test-management integration.

## Reproduction And Reference Server

The live fixture used the accepted read-only SDK candidate
`/tmp/m3c-links-20261007-clean`, locked Cucumber 10.2.0, the existing local
ReportPortal deployment, and the committed synthetic fixture SHA recorded
above. `run.rb` is an orchestrator, not a sandbox bootstrap. The sandbox has
already been created, populated by copying the two feature files and step file,
and committed as synthetic Git repository
`tmp/m3c-live-20261008/sandbox` at
`83807328b768f7f4fa2e29554b7217c07ff94819`; its matching
`fixture-repo.json` commit/path-allowlist metadata is required. The accepted
candidate and Gemfile must exist at `/tmp/m3c-links-20261007-clean`, the live
local ReportPortal deployment and authorized local demo authentication must be
available, and the reference server must already listen on `127.0.0.1:8873`.
The sandbox working tree was clean at that commit. The version probe in
`run.rb` inherits Bundler settings, so its exact candidate-specific invocation
is `PATH=/opt/homebrew/opt/ruby/bin:$PATH BUNDLE_GEMFILE=/tmp/m3c-links-20261007-clean/Gemfile ruby examples/m3c_live/run.rb`;
the child runner also explicitly uses that candidate Gemfile. This creates a
new live launch and must not be run for the already accepted result. To
reproduce deliberately, start `ruby examples/m3c_live/reference_server.rb --daemon`
only after validating the committed snapshot and manifest, then use the
candidate-specific invocation above. `ruby examples/m3c_live/verify_live.rb`
checks a saved run receipt and live API items, exact attributes/references,
parentage, terminal status/counts, and the failed log. The SDK was unchanged,
so the prior 255-example / 0-failure full RSpec result was not rerun.

The controlled reference server was restored on 2026-10-08 as detached daemon
PID `38343`, owned by the current user and listening only on `127.0.0.1:8873`.
The earlier session-owned PID `34670` ended when its agent session closed.
The daemon uses `Process.daemon`, redirects output to
`tmp/m3c-live-20261008/reference-server.log`, and records its PID in
`reference-server-ready.json`. After the launching shell exited, independent
commands confirmed parent PID `1`, process group `38343`, no controlling
terminal, and HTTP 200 for the unchanged Source, CI Run, and TMS destinations.
The source still highlights line 22 at the same synthetic SHA, the local run
record still identifies launch 35, and TMS still displays `CASE-UI/42`. This
lifecycle receipt is `reference-server-lifecycle-verification.json`; no new
ReportPortal launch or UI acceptance run was needed.

From the workspace root, the detached start command is
`PATH=/opt/homebrew/opt/ruby/bin:$PATH ruby examples/m3c_live/reference_server.rb --daemon`.
For foreground use in a user-owned terminal, omit `--daemon`:
`PATH=/opt/homebrew/opt/ruby/bin:$PATH ruby examples/m3c_live/reference_server.rb`.
Use either command only when port 8873 is free. The server continues to serve
only the SHA-verified, strictly allowlisted synthetic snapshot, this run's
local record, and synthetic TMS pages. Keep it running while the UI remains
open. If it must be stopped later, first check
`lsof -nP -iTCP:8873 -sTCP:LISTEN` and
`ps -p 38343 -o pid=,user=,command=`; send `TERM` only if that same PID still
owns port 8873 and its command is this fixture's `reference_server.rb`. Never
kill by port match alone or stop a replacement process with a reused PID.
