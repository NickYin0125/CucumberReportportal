# Cucumber 12 Independent Acceptance

Status: local acceptance complete on Ruby 3.4.2/macOS and Ruby 3.3.12/Linux,
with the single Linux Compose-tool exception recorded below. The joined-thread
regression was reproduced and fixed, then passed all three new native CLI cases
and both 929-example full suites. No source edits remain pending in QA scope.
No publication, tag, commit, remote CI execution, or live ReportPortal deployment
is asserted by this report.

## Verification Boundary

- QA changes are limited to `spec/`, `features/`, this report, and new evidence
  JSON. Production, dependency, example, and CI changes belong to other roles.
- Baseline source is immutable v1.3.1 commit
  `4ca2f770e0a84e83688f165ba04b4db8ef855cf9`, exported without checkout/source edits.
- Target dependencies are Cucumber 12.0.1, core 20.0.0, query 16.1.1,
  expressions 20.1.0, messages 34.2.1, and HTML formatter 24.2.0.
- Real Cucumber executables run in subprocesses. An independent TCP HTTP stub
  validates RP authentication, request fields, ownership, UUID uniqueness,
  start/finish order, parent/child timestamps, status values, multipart parts,
  exact bytes, and delivery acknowledgements. Existing WebMock tests remain.
- `parallel_cucumber -n 2` runs real workers. The parent creates the launch,
  waits for both workers, and only then finishes it. Workers never create or
  finish the CI-owned launch, and missing `RP_LAUNCH_UUID` is refused.

## Current Results

Ruby 3.4.2/macOS passed 929 RSpec examples with zero failures and no skips on
the final core. The 25 dedicated CLI cases all passed; six outer BDD cases
also passed. Both runtimes passed default offline Cucumber: 7 scenarios and
21 steps. The refreshed Ruby 3.3.12/Linux full run passed 929 examples with
zero failures and one pending example: `ReportPortal 26.0.7 Compose contract
resolves a real Compose configuration without requiring a daemon or revealing
credentials`, reason `Docker Compose CLI unavailable`. This supersedes the
earlier Linux run's one stale CI-snapshot failure. No SDK test is skipped.
Final full-suite durations were 182.876 seconds native and 164.824 seconds Linux.

The immutable Ruby 3.4.2/Cucumber 10.2.0 baseline passed 889 examples. Initial
missing-chart and obsolete Helm 3.7.1 failures were environmental and were
superseded using the existing locked chart archive and scratch Helm 3.18.4.
No cluster was changed. SHA-verified Helm archives came from `get.helm.sh`:

| Platform | Helm 3.18.4 archive SHA256 |
| --- | --- |
| darwin-arm64 | `041849741550b20710d7ad0956e805ebd960b483fe978864f8e7fdd03ca84ec8` |
| linux-arm64 | `c0a45e67eef0c7416a8a8c9e9d5d2d30d70e4f4d3f7bea5de28241fffa8f3b89` |

The existing locked ReportPortal chart archive SHA256 is
`399d95da23dcc6775acb5010f3f93b42f602ee75cecf7cce012a5d45fa9e0867`.

## Critical Matrix

Expected business failures and injected reporting faults below are successful
verification cases, not failed RSpec/Cucumber harness tests.

| Native case | Expected native exit | RP / verification contract |
| --- | --- | --- |
| Passed with native log and PNG/text | 0 | PASSED, exact bytes, correct step/hook owner, once-only delivery |
| Failed step | 1 | FAILED; subsequent step SKIPPED |
| Undefined step | 1 | FAILED without removed strict mode; next step SKIPPED |
| Pending step | 1 | FAILED without strict mode; next step SKIPPED |
| Ambiguous step | 1 | FAILED without strict mode; next step SKIPPED |
| Explicit skip | 0 | Scenario, action and launch SKIPPED |
| Before / After / AfterStep failure | 1 | Failed native hook and scenario; entire tree finished |
| Around before / after failure | 1 | Native scenario result/error retained; no invented Around HookStep |
| BeforeAll failure | 1 | No scenarios; FAILED launch; native AfterAll still executes |
| AfterAll failure plus delivery fault | 1 | Every native AfterAll executes; original native failure wins |
| Feature / Rule / Background / Outline | 0 | SUITE -> optional Rule SUITE -> stats STEP -> noStats actions |
| Four rows, two Examples; DocString / DataTable | 0 | Expanded values, distinct row identities, exact argument descriptions |
| `--retry 1`, flaky final pass | 0 | Failed/passed attempts, distinct UUIDs, stable testCaseId/uniqueId |
| `--retry 2 --retry-total 1`, flaky final pass | 0 | willBeRetried true/false; final pass does not poison suite/launch |
| Retry-total permanent-failure threshold | 1 | Later failure is not retried after threshold; launch FAILED |
| Two real parallel workers | 0 | One parent-owned launch; distinct trees; parent finishes last |
| Parallel without owned launch | Nonzero | Explicit configuration error; no RP requests |
| Failed / undefined / pending finish HTTP 503 | 1 | Original native business outcome survives strict reporting |
| Final retry pass plus unresolved log delivery | 2 | PASSED business, incomplete reporting; require-complete still fails |
| Unowned joined-thread evidence, require-complete | 2 | No guessed/cross-thread owner; rejected and incomplete receipt |
| Unowned joined-thread evidence, best effort | 0 | Business PASSED, reporting explicitly incomplete |
| Unowned joined-thread evidence plus business failure | 1 | Original FAILED business; reporting remains incomplete |

Native `AroundHook` has no separate event identity or start/end lifecycle in
core 20. Its error is asserted on the actual native case result and scenario
diagnostic, not fabricated hook timing. Native run-level hook errors similarly
retain launch ownership rather than invented Feature parents.

## Coverage And Packaging

Coverage uses Ruby stdlib `Coverage`, not a new dependency. It is restricted to
loaded SDK `lib` files. Baseline and candidate in-process RSpec, child CLI, and
observed process-union measurements are reported separately; none is total
repository coverage or a 100% code-coverage claim. Instrumentation measured
34 files; the current repository has 37 `lib` Ruby files.

| Measurement | Baseline | Candidate |
| --- | --- | --- |
| In-process RSpec only | 4843/5131, 94.387% | 4929/5244, 93.993% |
| Observed parent/child process union | 4867/5131, 94.855% | 4976/5244, 94.889% |
| Candidate acceptance child CLI only | Not directly comparable | 3078/5051, 60.938% |

The observed union increased slightly. The isolated RSpec-process percentage
declined by 0.394 percentage points because important new native execution
paths are exercised in subprocesses. The child cohorts differ: baseline
instrumentation followed inherited child bootstraps; candidate child metrics
cover the acceptance CLI/BDD cohort. This is not an equivalent whole-repository
coverage threshold or proof that every new branch is tested.

Build/install checks use isolated GEM_HOME consumers and the actual built gem.
They verify SDK 2.0.0, Ruby >= 3.3, Cucumber >= 12.0.1 and < 13, stdlib runtime
dependencies, absence of the legacy expressions cap, installed-source loading,
and rejection of incompatible Cucumber 11/13 local consumer resolutions.
Ruby 3.2 rejection is a built-gem requirement assertion, not an executed Ruby
3.2 runtime. SDK 2.0.0 and Helm 1.3.1 remain independently versioned.
The offline 11/13 consumer attempts return exit 7 because those gems are not
present in the isolated installation. The artifact's requirement checks
independently reject 9/10/11/12.0.0/13 and accept 12.0.1+; the negative attempts
are not claimed as a remote resolver matrix with those alternative gems installed.

Release tests retain historical 1.x manifests, fixed ancestry, dirty-source
refusal, moved-tag refusal, and read-only published retries. They reject wrong
source/package chart identity even after checksums are recomputed. The explicit
SHA-guarded legacy fault driver retains all seven historical behavioral cases;
only the hardcoded Cucumber 10.2.0 provenance assertion is version-neutralized.
It does not modify baseline production or hide the reported runtime version.

## Evidence

- [Acceptance, coverage, packaging provenance and native matrix](assets/cucumber-12-acceptance-2026-10-31.json)
- [Real native envelopes, requests, exact multipart bytes and receipts](assets/cucumber-12-acceptance-2026-10-31-wire.json)
- Native package: `/tmp/rp-cucumber12-qa-final929/packaging/reportportal-cucumber-ruby-2.0.0.gem`
- Native gem SHA256: `df68ba8ccb1e55c7e7e672efc4db16fd9304edc68351533a5e9ee27433e82c76`
- Native chart SHA256: `0007f3cb2f453a280e3e7e03abe3f4985e20b566ae14a8af2d6a4c2574d632ec`
- Linux package: `/tmp/rp-cucumber12-qa-linux-final/packaging/reportportal-cucumber-ruby-2.0.0.gem`
- Linux gem SHA256: `d62b03e96a94a50dbac97165f24474312e37b849cd41ffa06bc2a7c21b961b3b`
- Linux chart SHA256: `cc4186b8b65ce82633e653280aa2d6d992654bd9982ef9051f5f43183a79c102`
- Rebuilt packages are audited against all 37 current core source hashes, not an earlier archive.

Both chart packages are named `reportportal-rich-experience-1.3.1.tgz` beside
their respective gems. Different raw build timestamps produce different archive
hashes; the release tooling's separately tested canonical build is not replaced
by these QA consumer archives. Both isolated installed gems match current core
37/37. The current formatter SHA256 is
`dedb71c0ee875e45403b82bc1a0da83d687f5db25316ad1106ae9ddda6a9c4e2`.

Normal cases have no wire violations. Controlled finish-503 cases deliberately
leave server items unacknowledged and can trigger strict parent-finish refusals;
those are expected injected-reporting failures, not clean-delivery claims.
No unhandled thread-exception signatures occurred in the final native transcript
or final Linux transcript, or any of the native run's 31 saved CLI/BDD execution
records. The separate native packaging evidence refresh passed 11/11 examples
and retained the actual negative-consumer exit diagnostics.

## Reproduction

```sh
export BUNDLE_GEMFILE="$PWD/Gemfile"
export BUNDLE_IGNORE_CONFIG=1
export BUNDLE_PATH=/tmp/reportportal-cucumber12-bundle-ruby342
export HELM_BIN=/tmp/darwin-arm64/helm
bundle exec rspec
bundle exec cucumber
ruby spec/support/cucumber12_baseline.rb /tmp/rp-cucumber12-baseline-repeat
```

The baseline helper always exports the immutable SHA, not the current HEAD.
It also clears the candidate `BUNDLE_PATH`; a separately installed baseline
bundle can be selected with `RP_QA_BASELINE_BUNDLE_PATH`.
Coverage child bootstraps use paths in temporary directories without spaces.
Remote CI and the unexecuted legacy Ruby-version matrix remain separate from
the local results above. Raw IO/Hash attachment behavior inherited from upstream
Cucumber is outside this SDK acceptance change.
