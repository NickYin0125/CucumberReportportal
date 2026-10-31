# Independent Cucumber 12 release acceptance

## Scope and evidence boundaries

This plan answers the requested TC-01 through TC-18 acceptance campaign. It is
not a release sign-off and does not claim that finite tests prove 100% production
reliability. An unsupported input or an unimplemented feature is not a passing
test. The final review must preserve both the requested expectation and the
observed supported contract.

Baseline: commit `e7dae2b2bc7559339a796d657a4e1219e7f6b0aa`, SDK 2.0.0 candidate,
Cucumber 12.0.1. Candidate SHA-256:
`68b1ab8889f1e3448f6809b498c0aa7ff9ef9a03f4f1f5ae6d4e01fe2f6d17b3`.
Legacy resolver comparison uses the existing unmodified SDK 1.3.1 archive.
Any corrected candidate requires a new source/package fingerprint and a rerun
of affected cases; baseline results must not be relabelled as corrected results.

Three independent roles own runtime/media testing, clean-room/resolver testing,
and live RP/protocol/delivery auditing. The coordinating architect reviews their
evidence and any proposed patches. Testers do not modify production code to make
their own acceptance assertions pass. No main merge, tag, release, deployment
change, or removal of existing reports is authorized by this campaign.

## Contract calibration

- ReportPortal wire parentage is verified against the actual request and stored
  parent, not a guessed `parent_item_id` or `itemParentId` JSON field. Statistical
  Scenarios remain `STEP` with `hasStats=true`; action Steps remain nonstatistical.
- Rules are opt-in with `RP_RULE_SUITES=true`. Directory containers are not
  implied by a feature's source path. Missing requested directory grouping must
  be recorded as a product gap, not silently substituted with `codeRef`.
- Arbitrary tags and approved business attributes are different contracts. Test
  inherited tags and explicit attribute mapping independently; do not enable
  unsafe unrestricted metadata export simply to satisfy a fixture.
- The installed Gherkin 42.0.1 parser accepts a DocString and DataTable on the
  same Step, in either order. Cucumber Core 20.0.0's compiler still selects a
  single multiline argument. Separate the Ruby invocation limitation from the
  SDK's responsibility to render both AST contents. Test both a two-argument
  definition with an SDK-disabled control and a compatible definition that can
  execute. The pinned [Gherkin grammar](https://github.com/cucumber/gherkin/blob/v42.0.1/gherkin.berp)
  is authoritative; an open historical issue is not evidence that the parser
  still rejects the syntax. Separate Steps are a workaround, not the same test.
- Native `log`, Ruby `puts`, native `attach`, and SDK `rp_attach` must be tested
  as separate public entry points. Do not patch Kernel or privately invoke
  formatter callbacks to manufacture events. Test an actual File separately
  from an IO without a filesystem path. Base64 input requires an explicit
  encoding contract; byte-preserving binary input is the control.
- Hook names/types must reflect Cucumber's actual emitted lifecycle. Around
  failures must not gain a fictional native Hook event. Global hooks can report
  at Launch scope. A screenshot captured in After belongs to that open Hook,
  not retroactively to a closed business Step.
- `willBeRetried` and RP `retry` serve different lifecycle points. Preserve
  attempts and verify the final RP result rather than asserting that the first
  attempt's start request can predict its future failure.
- `use_same_thread_for_reporting` is not a documented SDK setting. API v1/v2
  selection is not a switch between same-thread and background logging. Test
  supported delivery settings and report this requested mode separately.
- Launch ownership, not process count or the presence of a CI environment
  variable, determines completion responsibility. An ordinary Formatter that
  creates its own Launch closes it after AfterAll/test_run_finished and delivery
  settlement; at_exit is a bounded fallback. Multiple processes with separate
  self-owned Launches each close their own Launch. ParallelFormatter uses an
  externally owned shared Launch UUID: the CI or local parent orchestrator
  starts once, waits for every worker and receipt, and finishes once. A single
  worker given an external Launch UUID must also leave completion to its owner.
  Automatic worker-owned shared completion and join-lock cleanup are not
  silently reintroduced. Abrupt SIGKILL cannot execute Ruby exit hooks.
- SDK 2.0.0 is unpublished. A temporary registry containing both real archives
  can prove Bundler resolution, but cannot prove public RubyGems availability.

## Case matrix

| Case | Independent stimulus | Required evidence |
| --- | --- | --- |
| TC-01 | Deep paths, tagged Feature and Rule, descriptions | Stored parent tree; descriptions; inherited metadata; separate directory/attribute applicability findings |
| TC-02 | Two Scenarios with Background | Each Background action's UUID belongs to its own Scenario |
| TC-03 | Multiple tagged Examples blocks | Distinct row UUIDs/parameters and block-specific inherited attributes |
| TC-04 | Both multiline argument kinds on one Step | SDK-enabled/disabled invocation controls; both AST contents rendered; no fictional two-argument invocation or orphan run |
| TC-05 | Undefined and pending Steps | Nonpassing Scenario, skipped followers, no removed `strict?` calls |
| TC-06 | Ambiguous definitions | Failed action/Scenario and actual exception/backtrace evidence |
| TC-07 | Pass, assertion failure, follower | PASSED/FAILED/SKIPPED, failure log, parent closure |
| TC-08 | Native `log` and plain `puts` | Separate event/terminal evidence; accepted log UUID and start/end time bounds |
| TC-09 | File, binary String, Base64 String; PNG/text/JSON | Exact bytes/MIME/filename, positive and unsupported-input controls, browser preview |
| TC-10 | Failure followed by screenshot in After | Preserved original failure and screenshot under the correct open After Hook |
| TC-11 | Before/After/AfterStep/Around, success and failure | Actual native event types, skipped actions, all affected items closed |
| TC-12 | BeforeAll/AfterAll logging and exceptions | Valid Launch evidence and final run closure without nil-context failures |
| TC-13 | `--retry 2`, fail then pass | Distinct attempts; retry relationship; final passed Scenario and ancestors |
| TC-14 | `--retry 1 --retry-total 1`, multiple failures | Exhausted retry budget terminates; final failed Scenario does not wait forever |
| TC-15 | Fifty rapid Steps and native evidence | Accepted/delivered reconciliation, final barrier and item/Launch completion under supported modes |
| TC-16 | Four actual parallel_tests workers | One orchestrator-owned Launch, four distinct worker PIDs, all receipts/items closed, one final finish |
| TC-17 | Fresh Ruby 3.3 and 3.4 containers | No inherited gem cache; install runtime-only dependencies; actual CLI execution and load-path provenance |
| TC-18 | Two-version candidate registry, `bundle update` | Ruby 3.1/C9 resolves 1.3.1; Ruby 3.3/C12 resolves 2.0.0; lockfiles and actual executions |

## Non-negotiable gates

1. **No hanging items:** enumerate every created UUID, including nonstatistical
   Steps and retry-hidden attempts, not just the default paginated test list.
   Reconcile stored parents, final statuses and end times. A successful HTTP
   response alone is not persistence evidence.
2. **No swallowed worker exceptions:** set `Thread.report_on_exception=true`,
   preserve subprocess stderr and exit status, inspect final receipts, and
   explicitly account for delivery errors. Expected business failures are not
   reporting failures; an incomplete report must not be relabelled complete.
3. **Exact screenshot ownership:** use at least ten distinguishable screenshots
   across sequential/parallel actions. Match expected owner UUID, file metadata,
   downloaded bytes and digest. A file existing somewhere in the Launch is
   insufficient. Visually inspect representative rendered PNGs and an After
   screenshot; label API-only checks accordingly.

## Decision process

Use PASS, FAIL, UNSUPPORTED, or NOT VERIFIED per requested subcase. Use
APPLICABILITY/PARTIAL for a mixed requested case whose supported paths pass but
whose literal expectations include a documented gap; never count that label as
an unconditional PASS. Record safe supported alternatives separately. A red-line
failure blocks release. A genuine
SDK defect gets a reproducible regression test, a bounded implementation patch,
independent retest and affected-suite regression. Product gaps and upstream
limits remain explicit even when supported-path gates pass. The final report
must include commands, source/archive fingerprints, RP Launch links, and the
limitations of local/remote/real-backend evidence.
