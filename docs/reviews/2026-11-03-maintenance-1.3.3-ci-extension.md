# Independent CI Extension: Maintenance 1.3.3

## Scoped Verdict

**ACCEPT the CI-only extension** at
`69aaedecd10a3ac01d7ad90b96e2db1b60343344`. No blocking review finding remains.
This supplements, and does not amend, the local ACCEPT for
`68e81d3697965305438be4fa27aa98aeb4baf726` archived in QA commit `1b74b3d`.
The old accepted report and curated manifest remain byte-identical to that commit.
The separate index records their hashes and the full QA commit identity.

Only `.github/workflows/validate.yml` and `spec/release/workflows_spec.rb` differ.
No SDK runtime, packaged content, example, source Gemfile/lock, live or performance
input changed. No live/performance replay, broad local suite replay, SDK edit,
CI rerun, commit, push, tag, release or deployment was performed by this reviewer.
This verdict permits no publication or promotion beyond the existing draft-only
review/CI scope. [PR 9](https://github.com/NickYin0125/CucumberReportportal/pull/9)
was independently checked as OPEN, DRAFT, targeting `maintenance/1.x` at this head.

Evidence directory: `assets/qa-1.3.3-ci-extension-20261103T122728Z`.

## Independent Review And Narrow Execution

The old isolation step exported a private `BUNDLE_GEMFILE` through `GITHUB_ENV`
before creating that file. `ruby/setup-ruby` checks the selected Gemfile even
with `bundler-cache: false`; setup therefore failed before dependency resolution
or SDK tests. The correction leaves the existing source Gemfile selected during
Ruby setup, then creates the isolated manifest before exporting/publishing its
path and running `bundle install` in that same shell.

Review confirms unchanged four-cell coverage, full RSpec/offline/isolation
commands, SDK/dependency constraints, source-integrity checks, read-only
permissions, checkout credential policy, required gate, release guards and
artifact policy. The new regression checks actual file existence at the setup
boundary. The generator regression still evaluates both Cucumber pins and
checks that the private path exists when published. No SDK assertions were
weakened and no test overlay or global Bundler-flag deletion was used.

Independent local execution ran the **entire workflow spec file**, not a full
SDK suite and not the developer's 29-example result:

| Runtime | Selected Cucumber / Expressions | Actual Workflow Examples | Failures / Pending |
| --- | --- | --- | --- |
| Ruby 3.1.7p261, aarch64 Linux | 9.2.1 / 17.1.0 | 15 | 0 / 0 |
| Ruby 3.3.12, aarch64 Linux | 10.2.0 / 18.1.0 | 15 | 0 / 0 |

Both use Bundler 2.6.6 and diff-lcs 1.6.2, retained resolved locks, preflight and
actual RSpec JSON. A separate owned ordering probe executed the real old/new
pre-setup shell and new manifest generator without gem installation: old setup
selected a nonexistent private manifest; corrected setup selected the existing
source Gemfile and only published the private manifest after creation.

## Package And Input Byte Identity

`local-extension.json`, `package-baseline.json` and `package-candidate.json`
record the exact two-file diff and equality of:

- All **212 `gemspec.files`** entries, their source bytes and actual extracted package payload bytes.
- The gemspec source, complete packaged specification metadata/YAML and metadata SHA256.
- All **46 library files**, also checked against the original independently accepted library manifest.
- Deterministically built complete gem archives under the same RubyGems/image and common `SOURCE_DATE_EPOCH=1793705935`.

Both deterministic archives have SHA256
`4de2d59070ea0206ba2d06751cbd37a38370362970bd3098ca987fb1342ebaa0`.
This is a controlled baseline-versus-CI archive comparison, not a claim that its
hash equals the original timestamp-varying live-run archives. Source/package
metadata and delivered bytes are identical, so the prior live, consumer and
performance evidence remains scoped to the unchanged inputs. No new performance
claim is made for the remote Ruby 3.3.13/x86 environment.

The original report SHA256 remains
`4c0c93a0b66d93447cd349b555ba01e4d2153d689cacfba5dfb5027a71a609ca`.
The historical 1,878-per-cell local results, owner-approved HTTP cost tradeoff,
R02, RP code-theme contrast limitation and released-2.x depth risk are not
rewritten or reinterpreted by this extension.

## Actual Remote Receipts

Raw complete logs, API run/job/step receipts, exact four runtime/lock artifacts
per successful run, source-dependency hashes and checkout commit receipts are
retained. Counts below are parsed from actual logged command groups and checked
against successful API step conclusions, not copied from manager/developer counts.

| Actual Run | Head | Full Matrix Total | Required Gate | Packaging |
| --- | --- | --- | --- | --- |
| [PR 41635045671](https://github.com/NickYin0125/CucumberReportportal/actions/runs/41635045671) | 69aaede | 7516, 0 failures/pending | success | skipped |
| [Push 41635035639](https://github.com/NickYin0125/CucumberReportportal/actions/runs/41635035639) | 69aaede | 7516, 0 failures/pending | success | skipped |

The following counts and versions were independently verified **in each run**:

| Cell | Actual Ruby, x86_64 Linux | Cucumber / Expressions | Full RSpec | Separate Isolation | Full Offline Cucumber |
| --- | --- | --- | --- | --- | --- |
| Ruby 3.1 / Cuke 9 | 3.1.7p261 | 9.2.1 / 17.1.0 | 1879, 0 failures/pending | 9, 0 failures/pending | 1 scenario / 3 passed steps |
| Ruby 3.1 / Cuke 10 | 3.1.7p261 | 10.2.0 / 18.1.0 | 1879, 0 failures/pending | 9, 0 failures/pending | 1 scenario / 3 passed steps |
| Ruby 3.3 / Cuke 9 | 3.3.13 | 9.2.1 / 17.1.0 | 1879, 0 failures/pending | 9, 0 failures/pending | 1 scenario / 3 passed steps |
| Ruby 3.3 / Cuke 10 | 3.3.13 | 10.2.0 / 18.1.0 | 1879, 0 failures/pending | 9, 0 failures/pending | 1 scenario / 3 passed steps |

All eight cells activate SDK 1.3.3, Bundler 2.6.6 and diff-lcs 1.6.2. Exact
Gemfile/lock bytes and SHA256 values are retained, not inferred from the version
table. Remote original Gemfile, Gemfile.lock and gemspec hashes match the frozen
CI source; the unchanged-tracked-source step succeeds in every cell. The count
increase from 1878 to 1879 is the one new workflow example, not a runtime change.

The PR actually checked out merge commit
`e061a5f5c76b53e21daf230fb7a6e9055950530c`; GitHub commit/tree receipts prove its
complete tree equals the CI head's tree. Push jobs checked out the full CI head
directly. Thus the PR's synthetic merge identity is recorded rather than
misrepresented as a literal branch-head checkout.

Per successful run: **7516 full examples + 36 separate isolation examples**,
four offline scenarios / twelve passed steps. Across the two runs this is 15032
full examples + 72 isolation examples and eight offline scenarios / 24 steps.
These are distinct remote executions, not replacements for historical local counts.

## Preserved Failure And Parser Classification

The earlier [PR 41634520578](https://github.com/NickYin0125/CucumberReportportal/actions/runs/41634520578)
and [push 41634383995](https://github.com/NickYin0125/CucumberReportportal/actions/runs/41634383995)
both used head `68e81d3`. Their retained actual setup logs contain:

```text
Error: $BUNDLE_GEMFILE is set to /home/runner/work/_temp/runtime/Gemfile but does not exist
```

All four full-RSpec steps were skipped in each failed run. They provide no
remote SDK-example execution or passing count; this was a CI bootstrap-order
failure, not evidence against the already executed local SDK tests. The local
old-order probe preserves the corresponding expected failure control.

Receipt attempt 1 failed because this `gh` CLI labels every text line
`UNKNOWN STEP` despite valid API step metadata. Its parser snapshot, failure
log and explicit receipt-harness-failure classification are retained. Attempt 2
parses the actual `Run bundle exec rspec`, `Run bundle exec cucumber` and
`Run bundle exec rspec script/release/spec` groups and cross-checks API results.
This parser correction did not rerun CI/tests or modify any SDK assertion.

## New Curated Files And Reproduction

The separate `ci-extension-manifest.json` lists only new extension files, their
sizes and SHA256 values, plus the immutable historical report/manifest hashes.
Include that index itself separately. Source exports, extracted package trees,
gem archives, Git stores and dependency caches are not eligible for staging.
No earlier accepted report or manifest is modified/restaged.

Owned new methodology: `qa/readability_1x/ci_extension.rb`, `ci_receipts.rb`,
`ci_inventory.rb`; this report; the indexed files under the evidence directory.
Developer/manager verdicts were not used as independent test results.

Exact commands, already executed; no further test/CI runs are needed:

```sh
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/ci_extension.rb
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/ci_receipts.rb /Users/nick/Documents/crr-qa-1.3.3/docs/reviews/assets/qa-1.3.3-ci-extension-20261103T122728Z
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/ci_inventory.rb /Users/nick/Documents/crr-qa-1.3.3/docs/reviews/assets/qa-1.3.3-ci-extension-20261103T122728Z
```

The receipt helper uses only read-only `gh` operations through the inspected
existing `gh_safe.rb` child credential wrapper. Credentials were never printed,
written to evidence or injected into a browser. Manager owns any subsequent
curated commit/push; this independent extension makes no release authorization.
