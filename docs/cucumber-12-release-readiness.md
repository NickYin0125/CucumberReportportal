# Cucumber 12 CI and release preparation

This is the release/CI maintainer's working record, not acceptance sign-off.
SDK **2.0.0** is unpublished. Helm remains **1.3.1**, ReportPortal remains
**26.0.7**, and no infrastructure changes are part of this SDK migration.
The parent-owned architecture and QA-owned acceptance review remain authoritative
for their respective decisions and test evidence. Existing review files are not
rewritten or re-labelled as Cucumber 12 evidence.

## Source and release boundaries

- Target development checkout: `codex/cucumber-12`; allowed 2.x release ancestry
  is `origin/main` or the explicitly named `origin/codex/cucumber-12`.
- Local `maintenance/1.x` is frozen at released v1.3.1 commit
  `4ca2f770e0a84e83688f165ba04b4db8ef855cf9`. CI uses that full immutable SHA
  until a deliberate reviewed change switches to a published maintenance ref.
- New stable 1.x releases require `origin/maintenance/1.x` ancestry. Only exact
  historical `v1.3.1` at the immutable SHA above may use `origin/main` instead.
  A caller cannot supply a different branch through an environment variable.
- SDK 1.x retains its coupled gem/chart version and old manifest shape/title.
  SDK 2.x verifies the gem against its tag, the chart against `Chart.yaml`, and
  records `chartVersion` separately. Both packages, checksums, notes and the fixed
  ReportPortal appVersion are still verified; independence does not skip checks.
- Release source must match the tag/commit and be clean, including untracked
  files. The user's unrelated untracked research file is preserved. Test release
  preparation in an isolated clean source fixture, never by disabling the guard.
- No new tag is created until local acceptance and independent review complete.
  No tag push, GitHub publication, RubyGems push or deployment is performed here.

### Frozen maintenance publication boundary

The frozen `maintenance/1.x` source still carries v1.3.1's old **main-only** release
workflow/tooling. A tag executes the workflows from its own source commit;
changes on the 2.x branch do not retrofit that branch. The immutable legacy CI
matrix here is compatibility evidence, not an operational future 1.x publisher.

No legacy backport or branch write was made. Before a new 1.x release, the parent
must approve a minimal workflow/tooling-only backport with the required QA-owned
test harness adaptations. Validate the actual maintenance head, including its
Ruby 3.1+ / Cucumber 9/10 combinations, rather than certifying it solely from the
old frozen baseline. Keep legacy runtime/dependency manifests and coupled package
identity intact; do not cherry-pick SDK 2.x dependency/runtime changes. Publication
must remain blocked until that separate backport and validation are complete.

## Planned CI matrix

| Job | Ruby | Cucumber | Source and lock policy | Required commands |
| --- | --- | --- | --- | --- |
| `test` | 3.3 | Locked 12.0.1, required `>=12.0.1, ~>12.0` | Current source SHA; frozen root lockfile | `bundle exec rspec`; `bundle exec cucumber` |
| `test` | 3.4 | Locked 12.0.1, required `>=12.0.1, ~>12.0` | Current source SHA; frozen root lockfile | Same full suites |
| `legacy` | 3.1 | `~>9.0` | Real immutable v1.3.1 SHA; per-row resolved lockfile | All released behavioral cases with the explicit test-only driver below; offline Cucumber |
| `legacy` | 3.3 | `~>9.0` | Same immutable legacy source | Same explicit legacy harness |
| `legacy` | 3.1 | `~>10.0` | Same immutable legacy source | Same explicit legacy harness |
| `legacy` | 3.3 | `~>10.0` | Same immutable legacy source | Same explicit legacy harness |

Within the baseline's tracked files, legacy jobs change only the development
Gemfile/lockfile to select a supported Cucumber major. They do not edit or reuse
the 2.x gemspec. Re-resolution
is necessary because the released lock includes newer development dependencies
that are not all installable on Ruby 3.1. The resolved lock is retained as an
artifact, runtime identities are printed, and production source must remain
unchanged. A declared Ruby range is not the same as an observed matrix result.

### Explicit legacy test-only normalization

The immutable historical `spec/day2/fault_process_spec.rb` contains four literal
`10.2.0` provenance assertions. It remains unchanged on disk. Parent-approved,
QA-owned `spec/fixtures/legacy_fault_process.rb` is fetched separately from the
current reviewed driver SHA into `.ci-driver/`; it is not SDK production code and
is not discovered by the target's default RSpec file pattern.

The driver requires the original spec's SHA-256 to remain exactly
`4b2e01d3343dba4d1d902b8cc835e7c29a82893efb87241453783fcb379ced70`.
It loads the actual legacy helper/SDK and retains all seven original fault cases,
including all business failures, receipt, request-deduplication, SIGINT and
deadline assertions. Only provenance is normalized: each child's reported
Cucumber version must equal the actual version selected by its active bundle.
The separate runtime probe additionally requires the requested Cucumber 9/10
major and SDK 1.3.1, so a reported version is neither fabricated nor unchecked.

The exact legacy RSpec command is:

```sh
bundle exec rspec spec .ci-driver/spec/fixtures/legacy_fault_process.rb \
  --exclude-pattern spec/day2/fault_process_spec.rb
```

Only the original seven-case file is replaced in test discovery; all seven
behavioral cases remain required. The baseline Gemfile remains `BUNDLE_GEMFILE`, and
`LEGACY_SOURCE_ROOT` names that same immutable checkout. Before/after SHA-256
checks cover `lib/` and the gemspec; a final Git diff checks every other tracked
baseline file except the disclosed Gemfile/lock selection. This audit runs even
when tests fail. The original spec, reviewed driver, production hash manifest and
resolved lockfile are retained as narrowly selected CI artifacts. Production
hashes and behavioral assertions are not relaxed to obtain a green gate.

Each current-source job also builds the existing locked Helm dependency and
lints/templates the deployment profiles without deploying. Every legacy job
builds its own baseline dependency before its full RSpec suite. `gate` requires
both complete matrices to succeed; tag-only `bundle` depends on that gate and
exports the immutable release artifact ID. Publication cannot run on a failed
cell or a cancelled/skipped gate. The recovery workflow requires successful
`preflight`, `validate / gate`, and `validate / bundle` jobs; only immutable
historical v1.3.1 may use the old `validate / test` evidence shape.

## Observed maintainer checks

The following observations apply only to this role's commands, not to all QA work:

| Check | Observation |
| --- | --- |
| Local runtime discovery | Native Ruby 3.4.2; cached `ruby:3.3-slim` image present; native Ruby 3.1/3.3 executables absent |
| `ruby -c script/release/tooling.rb` | Passed syntax check |
| Ruby YAML parse of all four workflows | Passed for `ci.yml`, `validate.yml`, `release.yml`, `release-resume.yml` |
| `git diff --check` | Passed at the initial tooling/workflow checkpoint; repeated before handoff |
| Source identity inspection, without package build/publication | SDK 2.0.0; chartVersion 1.3.1; appVersion 26.0.7; expected distinct gem/chart names |
| Default native `bundle check` | Initially missing Cucumber 12 in the default global gem home; isolated native 3.4.2 bundle subsequently passed frozen `bundle check` |
| Runtime identity probes | Passed for SDK 2.0.0 / Cucumber 12.0.1 and actual SDK 1.3.1 / Cucumber 9.2.1 on native Ruby 3.4.2; use activated gem metadata, not unavailable `cucumber/version` |
| Real shared-checkout cleanliness guard | Rejected the dirty/untracked checkout as expected using existing immutable v1.3.1 identity; no package build or publication attempted |
| Initial release spec run before QA fixture updates | 29 examples, 17 failures from old main-only ancestry fixtures and single-job workflow assumptions; retained as initial evidence, not a final gate result |
| Final release tooling/workflow specs | `bundle exec rspec spec/release --format progress`: 38 examples, 0 failures on native Ruby 3.4.2 with the frozen isolated Cucumber 12 bundle; publication is mocked, not performed |
| Isolated immutable v1.3.1 / Cucumber 9.2.1 / Ruby 3.4.2 RSpec | 889 examples, 13 failures, 1 pending initially: nine local Helm 3.7.1 failures plus four historical tests hard-coding Cucumber 10.2.0 |
| Same Cucumber 9 baseline, correct Helm 3.18.4 | `spec/helm`: 18 examples, 0 failures; all nine old-Helm failures resolved without deployment/source changes |
| Final Cucumber 9 full behavioral suite with the approved explicit driver | 889 examples, 0 failures, no pending; native Ruby 3.4.2, Cucumber 9.2.1, SDK 1.3.1, Helm 3.18.4; original on-disk spec unchanged |
| Same Cucumber 9 baseline, `bundle exec cucumber` | 1 Scenario / 3 Steps passed, exit 0 |
| Baseline source hash audit after normalized full execution | 416 tracked files still match the immutable Git archive exactly; only development Gemfile/lock selection excluded |
| Exact remote CI matrix rows | Not executed remotely; native Ruby 3.1 legacy rows and exact Ruby 3.3 legacy rows were not executed by this role; configuration is not itself a pass |

The initial Cucumber 9 RSpec run above is **not** a green untouched-baseline
claim. Its four remaining failures check only a historical literal `10.2.0`,
after the genuine business-failure/receipt assertions have passed on 9.2.1. The
explicit parent-approved driver above is used for the final normalized run;
no baseline spec or reported runtime is silently changed. The initial pending
Compose check reflects a temporary PATH not exposing the Docker plugin, not a
live deployment test; the final run explicitly includes that executable.

Native commands from temporary directories explicitly select the Homebrew Ruby
3.4.2 path and Bundler 2.6.6: the default shell outside this project otherwise
selected system Ruby/Bundler. These bootstrap failures are not counted as tested
Ruby 3.1/3.3 matrix cells. Exact logs and the resolved Cucumber 9 lockfile are under
`/private/tmp/rp-role4-legacy9-8l0dG7/`; this temporary path is not a release asset.
The normalized full run is `normalized-rspec.log`; the original failure evidence
is `rspec.log`. The reviewed driver used for the green normalized run has SHA-256
`c0dd7c7f6e172ccaec0e57596784cb4f35a08c16bd612fe8661f8846667de7d9`.
The original frozen fault spec retains the SHA recorded above. The test-only
differences are guarded baseline helper loading, a distinct group label, and the
selected-version provenance assertion; the seven behavioral cases are retained.

The final release-spec command used `BUNDLE_GEMFILE` set to the source root's
Gemfile, `BUNDLE_PATH=/private/tmp/reportportal-cucumber12-bundle-ruby342`,
`BUNDLE_IGNORE_CONFIG=1` and `BUNDLE_FROZEN=true`. Its `gh` publication behavior
uses fixtures/stubs exclusively; no credentialed publisher or remote release ran.

No remote CI run is claimed. Full native/container suite evidence, coverage and
the outbound HTTP acceptance matrix belong to the QA-owned acceptance review.
Do not infer that live ReportPortal, browser, duration/fault, Compose, Kubernetes
or production upgrades were retested from these offline checks.

## QA handoff contract

QA owns `spec/**`. The release tooling fixtures need these specific checks:

- For synthetic 1.x sources, stub the fixed maintenance ancestry and
  `git status --porcelain --untracked-files=normal`; confirm the old manifest,
  coupled package names, release title and immutable-artifact recovery still work.
- Add a real-gem/synthetic-chart 2.0.0 fixture with chart 1.3.1, separate
  `chartVersion`, distinct names/title, deterministic bytes, and rejection of
  changed chart name/version/appVersion, notes, hashes or remote asset bytes.
- Reject moved tags, foreign release refs, unsupported major tags, tracked and
  untracked dirty source. Main fallback for a synthetic 1.x SHA must fail;
  only the exact historical v1.3.1 tag/SHA may qualify.
- Assert current Ruby 3.3/3.4 matrix, legacy Ruby 3.1/3.3 x Cucumber 9/10 matrix,
  immutable legacy checkout, frozen current lock, runtime identity checks,
  read-only defaults, no inherited PR secrets, and nonpersisted credentials.
- Assert `gate` depends on both matrices; `bundle` depends on the successful
  gate; reusable artifact output comes from `bundle`; publish/resume consumes
  exact retained artifact IDs without rebuilding or overwriting assets.
- Assert the preflight/publish/recovery shell and Ruby tooling agree on fixed
  release refs and the single immutable historical exception. Recovery keeps
  trusted `main` tooling, original source SHA, run identity and retention checks.

## Remaining release gates

Release-specific tooling/workflow and normalized Cucumber 9 checks above are
green. **The local acceptance gate is accepted.** The authoritative
[final QA report](reviews/2026-10-31-cucumber-12-acceptance.md) records the post-fix
results: Ruby 3.4.2 passed 929 examples with zero failures/pending; Ruby 3.3.12
ran 929 examples with zero failures and one pending Compose-CLI availability
check only. Both passed 7 offline Cucumber scenarios / 21 steps. All 25 native CLI
cases passed, no unhandled thread exceptions were observed, and both rebuilt and
installed gems matched all 37 core source hashes. The joined-thread regression
is resolved; exact coverage, package hashes and verification limits remain in
the QA-owned report and evidence, not duplicated or superseded here.

**Remote CI has not run. Stable-tag publication remains blocked until the
required remote CI matrices pass.** `v2.0.0` notes and local validation artifacts
are prepared only; no new stable tag is created or claimed, and no release is
published. Inspect the final diff and use an approved clean committed source for
any later tagged release bundle. Tag creation/push and publication remain
separately authorized operations. The already published v1.3.1 tag is retained
unchanged, not recreated or moved.
Future 1.x publication additionally requires the separately approved maintenance
backport described above; this 2.x source preparation alone does not enable it.
