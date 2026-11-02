# GitHub Release Operations

On this updated source line, stable tags invoke `Tag Release`: verify fixed release-line ancestry, run
both complete offline validation matrices, build gem/Chart/checksums/provenance
and publish through a draft.
Only the publish job has contents-write permission. No RubyGems push is performed.

**SDK 2.0.2 promotion:** the owner authorized release after independent acceptance
on 2026-11-02. Contract, browser and performance reviewers accepted runtime
`8f44c105`; bind release-metadata edits to those unchanged runtime bytes and wait
for final CI before merging and tagging. The tag workflow must then pass its own
validation and publication checks. Do not move existing tags, publish to
RubyGems, change 1.x or upgrade the deployment as part of this operation.

The previously published SDK 2.0.0 has its own
[independent acceptance](../../docs/reviews/2026-10-31-cucumber-12-independent-acceptance.md).
That historical approval does not authorize a Ledger candidate release.

## Fixed release lines

| Stable tag | Approved remote ancestry | Version contract |
| --- | --- | --- |
| `v1.0.0` through `v1.3.1` | `origin/maintenance/1.x` | Retained historical bundle format: Gem and Chart match the tag |
| `v1.3.2` and later 1.x | `origin/maintenance/1.x` | Gem matches the tag; Chart has its independently committed version |
| `v2.x.y` | `origin/main` or exactly `origin/codex/cucumber-12` | Gem matches the tag; packaged Chart matches its independently committed `Chart.yaml` version |

### Frozen maintenance publication boundary

The immutable v1.3.1 CI baseline retains its **historical main-only release
workflow/tooling**. It is not the current maintenance-head claim: SDK 1.3.2 was
released separately with independent SDK/Chart identities. Updating files on
the 2.x branch never updates the workflow executed by a tag on that separate
source line. Legacy compatibility jobs here validate v1.3.1, not a new 1.x patch.

Before a new maintenance release, obtain explicit approval for any necessary
workflow/tooling backport and QA-owned test harness changes, then validate the
actual maintenance head on Ruby 3.1+ / Cucumber 9 and 10. Do not use
only the frozen baseline's results as evidence for a new patch. Preserve the
legacy gemspec/lock/dependency contract, historical package formats, historic tags
and server/chart contents; do not backport SDK 2.x runtime/dependency changes.
Publishing that maintenance ref/tag remains a separate authorized operation.

The historical migration task did not backport or publish maintenance changes.
Ledger development uses separate feature branches; their C8 commits/pushes do not
authorize promotion into release ancestry, a tag, a merge or publication.
The policy below describes the updated tooling's capabilities **once present on
the relevant release source**, not a claim that the frozen branch already has it.

The sole main-ancestry fallback for 1.x is already-published `v1.3.1` at commit
`4ca2f770e0a84e83688f165ba04b4db8ef855cf9`. It permits verification/recovery before
the frozen maintenance branch is published, not new maintenance releases from
main. Other tags or SHAs cannot use this exception. Other major release lines,
prereleases, moved tags, dirty/untracked source and caller-selected release refs
fail closed. `RELEASE_SOURCE_ROOT` selects the source directory during recovery;
it does not change these ancestry rules.

For SDK 2.0.2 the expected packages are
`reportportal-cucumber-ruby-2.0.2.gem` and
`reportportal-rich-experience-1.3.1.tgz`. The manifest's `version` is the SDK
version; new 2.x and SDK 1.3.2+ manifests additionally contain `chartVersion`.
Existing 1.x manifests through SDK 1.3.1 remain unchanged for byte-for-byte
retained-artifact verification. For example, SDK 1.3.2 can accompany unchanged
Chart 1.3.1; its title is `SDK 1.3.2 / Helm 1.3.1`.
The chart name, stable version, locked bundled dependency, fixed ReportPortal
`appVersion=26.0.7`, notes, checksums, remote tag and asset bytes remain mandatory
checks. A chart version need not equal the SDK version on 2.x or 1.3.2+; each
artifact still has its own identity checks. No Chart or workflow is changed by
this version-policy update.

SDK 2.0.1 Ledger rationale (historical):

Released as a patch at the owner's request; the two opt-in switches are additive and off by default.

## Validation and candidate packaging

`validate.yml` tests the current locked source on Ruby 3.3/3.4, and the real
immutable v1.3.1 checkout on Ruby 3.1/3.3 with Cucumber 9/10. Only development
Gemfile/lock selection changes among baseline tracked files. A separate,
QA-authored SHA-guarded driver retains all seven native fault cases while
comparing provenance with the actual selected runtime instead of four historic
`10.2.0` literals; the original baseline spec is not edited. Production hashes
and the original/driver files are audited and retained explicitly. The `gate` job requires every
cell; tag-only `bundle` runs after that gate and preserves one immutable artifact
ID. Helm lint/template/dependency checks never deploy anything.

### 2.x release dependency isolation

The tag-only `bundle` job installs its locked dependencies under
`$RUNNER_TEMP/release-gems`, with Bundler's local configuration under
`$RUNNER_TEMP/release-bundle-config`. It deliberately disables `setup-ruby`'s
`bundler-cache` in that job: cache mode sets a local `vendor/bundle` path inside
the checkout, overriding an environment-only path change. The current test
matrix keeps its cache; the immutable legacy job and drivers are unchanged.
`BUNDLE_FROZEN=true` and the explicit source Gemfile remain mandatory. No ignore
rule, clean-source check, tag/ancestry check or artifact verification is relaxed.

The executable regressions use disposable Git repositories and a real offline
gem install to prove that dependencies and configuration stay outside the source,
the lockfile stays unchanged, and tracked edits, staged edits, deletions and
untracked files (including the old `vendor/bundle` layout) still fail closed.
They run as a separate required step in the current Ruby 3.3/3.4 matrix:

```sh
bundle exec rspec script/release/spec spec/release
```

### Historical failure diagnosis (WP4)

All three downloaded failed-job logs show `setup-ruby` installing/restoring gems
under the checkout's `vendor/bundle`, followed by `Build verified release bundle`
failing with `Release source must be clean, including untracked files`. That
directory is not ignored by any of the three tagged sources; `.bundle/` and the
locked Helm dependency archive are ignored. The logs do not print Git status,
but the unignored dependency tree is sufficient to reproduce the rejection.

| Tag | Failed run | Actual failing job/step |
| --- | --- | --- |
| v2.0.0 | [41166822749](https://github.com/NickYin0125/CucumberReportportal/actions/runs/41166822749) | `validate / bundle`, release build after a dependency-cache hit |
| v2.0.1 | [41311746972](https://github.com/NickYin0125/CucumberReportportal/actions/runs/41311746972) | `validate / bundle`, release build after a dependency-cache hit |
| v1.3.2 | [41312720332](https://github.com/NickYin0125/CucumberReportportal/actions/runs/41312720332) | `validate / test`, release build after 1,519 passing RSpec examples and one passing Cucumber scenario / three steps |

The v1.3.2 job restored a fallback cache, installed its locked Cucumber 10.2.0
dependencies and cleaned stale gems before passing its tests. Its job name does
not indicate a test failure. This diagnosis does not change the 1.x workflow.

GitHub metadata records [v2.0.1](https://github.com/NickYin0125/CucumberReportportal/releases/tag/v2.0.1)
as published at `2026-11-01T13:39:59Z` and
[v1.3.2](https://github.com/NickYin0125/CucumberReportportal/releases/tag/v1.3.2)
at `2026-11-01T13:49:49Z`. Both release authors and all four asset uploaders are
`NickYin0125`; both failed tag workflows skipped `publish`. These were therefore
owner-account publications outside those failed workflows, not successful
`github-actions` publications. The owner authorized recovery from clean local
worktrees against the same immutable tags using the existing build/publish tools.
The retained local recovery bundles have all four published asset SHA-256 values
identical to GitHub's asset digests, including these provenance manifests:

| Bundle | Commit | Manifest SHA-256 |
| --- | --- | --- |
| 2.0.1 | `ef38224b28b451dc4cc94ac314906ac4ecee459a` | `68e46598113ec29154d77bb3e97f584db29d123036587b3792884a1973685ae7` |
| 1.3.2 | `19174a5ecaf1aa9fb65480f0a21d74ed65c89a8d` | `f9a75135395102454a2376c185ff4e9c905977ee5313bc32c8fac24527d29366` |

This corroborates owner-authorized local bundle recovery, not a successful cloud
tag pipeline. The retained evidence does not include the exact publisher shell
invocation; account metadata alone cannot distinguish a CLI from a UI upload.
Existing tags/assets are untouched by this investigation.

The first WP4 candidate placed `runner.temp` in job-level `env`, where GitHub
does not permit the `runner` context; run `41439805953` was rejected before any
job started. The corrected workflow exports the two paths through `GITHUB_ENV`
in a shell step before Ruby setup. A regression test executes that exact step
and rejects unsupported job-level contexts. This follows GitHub's
[context availability rules](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#context-availability).

The release CLI remains deliberately strict:

```text
ruby script/release/cli.rb build|publish TAG FULL_COMMIT_SHA OUTPUT_DIRECTORY
```

`build` requires an already-existing unchanged tag, approved remote ancestry and
a clean checkout; it cannot certify the shared uncommitted development tree.
Use QA's isolated real-gem/synthetic-chart fixtures to test release preparation. Do
not delete/stage unrelated user files or disable cleanliness to make a build pass.
After gates and an approved commit, use a clean isolated source checkout for real
tagged packaging, with output outside the source checkout. `publish` additionally requires GitHub credentials and is not a
preparation command. Nothing invokes `gem push` or changes infrastructure.

See [readiness and observed local checks](../../docs/cucumber-12-release-readiness.md)
and [consumer migration](../../docs/migrating-to-2.0.md). Historical acceptance
files retain their original evidence and version scope.

## Recover original validated artifacts

If publication fails after validation and artifact preservation, do not move the
tag or rebuild/replace already published assets. From a trusted `main` checkout:

```sh
gh workflow run release-resume.yml --ref main \
  -f tag="$RELEASE_TAG" -f source_run_id="$VALIDATED_RUN_ID"
```

Set these variables to the actual tag and completed **Tag Release**
run ID. The recovery workflow checks repository/workflow identity, original tag
SHA and approved source ancestry, successful preflight and full-validation jobs, and one
unexpired original artifact. It downloads that exact artifact and checks out the
original source while running repaired publication tooling from `main`.
New releases require `validate / gate` and `validate / bundle` success. The old
`validate / test` job shape is accepted only for the exact immutable published
v1.3.1 tag/SHA, not as a way around the new matrix. Earlier recovery operations
remain recorded in their original release/acceptance history; they are not
retroactively relabelled as this dual-line workflow.
The publisher verifies package identity, checksums, committed notes and remote
asset bytes before publishing. Mismatched, ambiguous, incomplete or expired input
fails closed; published releases are never silently repaired or overwritten.

GitHub's by-tag API can hide drafts even when authenticated release listing shows
them. The publisher uses paginated authenticated listing after a by-tag 404;
authorization and network failures are not treated as an absent release. Draft
discovery must not create a duplicate or downgrade validation.

Original failed runs remain audit history. A successful recovery run, not a
rewritten tag or retroactively green historical run, is the publication proof.
