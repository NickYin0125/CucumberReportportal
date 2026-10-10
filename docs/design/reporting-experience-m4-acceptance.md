# M4 Final Acceptance

Status: ACCEPTED by Master, 2026-10-10. Implementation and regression execution
were delegated to GPT-6 Luna; independent QA used GPT-6.1 Sol. This is a scoped
milestone checkpoint, not a universal GA or exactly-once guarantee.

## Delivered Contract And Tests

| Phase | Delivered behavior | Concrete regression coverage |
| --- | --- | --- |
| M4-A | Count/accounted-byte queue bounds, complete wire-body limits, bounded reject/block admission, immutable producer snapshots and bounded shutdown | `config_m4a_spec`, `queue_processor_m4a_spec`, `multipart_m4a_spec`, `m4a_public_delivery_integration_spec` |
| M4-B | Fixed accepted cutoff, immutable receipts, partial acknowledgement handling, v2 acceptance distinction, duplicate risk, shared finalization deadline and separate business/report outcomes | `queue_processor_m4b_spec`, `deadline_m4b_spec`, `m4b_completion_integration_spec`, `formatter_strict_m4d_spec` |
| M4-C | Atomic private spool publication, finite cross-process disk quota, streamed checksummed evidence, safe paths, durable per-entry checkpoints and explicit original-target replay CLI | `spool_store_m4c_spec`, `spool_replay_m4c_spec`, `spool_replay_api_spec`, `spool_replay_cli_integration_spec`, actual installed-gem consumer |
| M4-D | Slow/offline/partial response faults, retry policy, real SIGINT, disk-full refusal, strict original-error preservation, live API and browser reconciliation | `delivery_faults_m4d_spec`, `http_status_policy_m4d_spec`, `m4d_reporting_integration_spec`, `m4d_interrupt_spec`, `m4d_fixture_spec` |

All named specifications are under `spec/reportportal_cucumber/`; the installed
driver is `spec/support/m4_installed_gem_consumer.rb`. Assertions retain the
original UUIDs, timestamps, binary bytes and privacy checks rather than merely
checking HTTP status. Earlier failed receipts remain available in the phase
verification documents; they have not been relabeled as passing results.

Independent findings IQ1-IQ6 were fixed and reverified: real Store descriptors
are consumed correctly; logical filenames cannot collide with private storage;
unsafe roots are refused before outside mutations; resume counts reflect actual
checkpoints; invalid settings and missing/corrupt artifacts have distinct safe
diagnostics; dry-run exposes unavailable markers without credentials or HTTP.
Additional tests include `store_feedback_m4d_spec`, `replay_feedback_m4d_spec`,
`store_diagnostics_m4d_spec`, `config_cli_diagnostics_m4d_spec`, and
`replay_unavailable_summary_m4d_spec`.

## Final Frozen Artifact

Candidate: `/tmp/m4-20261010-candidate.30uRDE`.
Manifest SHA-256:
`49607259f627ca6818c37e863ed4bc55a38ab271102a62818cd605135b8c2357`.
Gem SHA-256:
`20a537c3cf708c0bf37191a3759fc962f2b9ce5b64c39c259c95a3ae31e0552e`.
Exact gem: `tmp/m4-20261010/gates/20261010T151830Z-12049/installed-package/reportportal-cucumber-ruby.gem`
inside that candidate. Gem version remains 1.1.0; the requested checkpoint tag
is `m4`, not a newly published RubyGems release.

Master independently compared all 131 non-document manifest files with the
workspace: zero mismatches. Final verification documents are post-run outputs;
they intentionally differ from the frozen candidate's earlier document copies.
SDK, tests, README, executable and live examples remain identical. The installed
gate verifies all 35 SDK library files and the executable; actual consumer loads
are checked under the installed root, not the checkout.

| Gate | Executed result |
| --- | --- |
| M4 focus plus replay API/CLI | 211 examples, 0 failures |
| Historical security/privacy | 89 examples, 0 failures |
| Full RSpec | 507 examples, 0 failures |
| Full RSpec, seed 20261010 | 507 examples, 0 failures |
| Named M2/M3 subset | 80 examples, 0 failures |
| Native default-profile Cucumber | 1 scenario and 3 steps passed |
| Actual installed-gem HTTP/replay consumer | PASS, including confirmed-sibling resume and original PNG bytes |
| Independent Sol installed-package journeys | 50 checks, 50 passed, 0 failed |

These suites overlap; their example counts must not be added together.
Runtime: Ruby 3.4.2, Bundler 2.6.6, native Cucumber 10.2.0. Native Cucumber 9's
historical loader gap and the full Ruby/Cucumber compatibility matrix are not
certified here. The CI-style Cucumber mock intentionally lacks a success log
ID, so its incomplete-report warning is expected: scenario compatibility is
not proof of remote delivery. Actual acknowledgements are verified separately.

See [full regression](reporting-experience-m4-full-regression-verification.md),
[fault/live verification](reporting-experience-m4d-verification.md), and
[independent QA](reporting-experience-m4-independent-review.md) for exact commands,
source/package identities, outputs and refusal semantics.

## Real ReportPortal Acceptance

Existing local Kubernetes endpoint: `http://localhost`, project
`superadmin_personal`. No infrastructure or credentials were changed.
Launch [47](http://localhost/ui/#superadmin_personal/launches/all/47), UUID
`41b91550-97b8-4f73-81a4-2b20489f8ae4`, contains two suites and three statistical
leaves: two passed, one deliberately failed. The native Cucumber child preserves
the original business failure and exit 1; this is an expected acceptance case.

API reconciliation confirms 14 items, 9 exact acknowledgement/log-row matches,
and 3 downloaded PNGs. Each PNG is 327 bytes, SHA-256
`5b7a247dac8fc35737fe3485fd1242dfe15e9505f6b8eaba12c6065a85a4a5d2`.
Replayed logs remain at original action 1026 under attempt Scenario 1025.
Completed resume sends no HTTP; unconfirmed replay against closed original
targets refuses without POST or checkpoint mutation. Sol separately repeated
read-only reconciliation using the exact installed gem.

Master physically verified the same final run in the browser:

- Clicking the native Suite's Passed count returns exactly Scenario 1028, not an empty list.
- Given step 1029 renders an actual Markdown table; When step 1030 renders syntax-formatted JSON and its PNG.
- The PNG decodes at 80x40 and opens in the native RP attachment preview.
- Original replay action 1026 contains both replay logs and its decoded PNG.
- Failed Scenario 1033 retains the deliberate error under Then 1036, with a passed After hook.

Screenshots are retained under `/tmp/m4-final-ui/launch47-*.jpg`, including
`statistics`, `passed-scenario`, `table-json-png` (table view),
`json-png-visible`, `png-preview`, `replay-original-step`, and `business-failure`.
Use the Scenario log page and expand the nested action; this UI's direct
hasStats-false action URL is not the accepted navigation route.

The immutable live/API receipts are inside the candidate at
`tmp/m4-20261010/live/run-20261010T152208Z-13322/receipt.json` and
`api-reconcile-20261010T152214Z-13356/receipt.json` beneath that run directory.
Independent provenance/verdict is under the workspace's
`tmp/m4-independent-20261010/installed-v4/final-verdict.json`.

## Scope And Git Checkpoint

Only validated M4 library, test, executable, README, design and live-example
changes enter the milestone commit. The gemspec includes only the two approved
executable-packaging additions. Existing Gemfile.lock, Rakefile, cucumber.yml,
four unrelated gemspec development dependencies and untracked duration work
remain untouched and excluded. No reset, stash, amend or broad `git add .` is used.

Create annotated local `m4` on that validated commit; no force-tag, merge,
release upload or remote push is implied. Report the final commit/tag identity
after creation. No more runtime changes are required by the independent gate.

The default reject-new policy is intentionally lossy under overload. Deadline,
disk and process termination can leave unconfirmed work; a lost response can
cause duplicates. No exactly-once or SIGKILL zero-loss promise is made. Replay
is opt-in and refuses closed/missing original targets instead of inventing new
ownership. Caller-owned file-backed sources must stay available and stable until
local settlement. CI owns shared Launch completion; the framework owns videos.
Strict reporting is exception-based, not a substitute for checking completeness.
