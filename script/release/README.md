# GitHub Release Operations

On this updated source line, stable tags invoke `Tag Release`: verify fixed release-line ancestry, run
both complete offline validation matrices, build gem/Chart/checksums/provenance
and publish through a draft.
Only the publish job has contents-write permission. No RubyGems push is performed.

**Preparation only:** SDK 2.0.0 is not released. Do not create/push its tag or run
the publisher before local acceptance and independent review. This change does
not publish any release, move v1.3.1, or change the server/deployment.

## Fixed release lines

| Stable tag | Approved remote ancestry | Version contract |
| --- | --- | --- |
| `v1.x.y` | `origin/maintenance/1.x` | Gem and wrapper Chart must both match the tag; original 1.x manifest/title retained |
| `v2.x.y` | `origin/main` or exactly `origin/codex/cucumber-12` | Gem matches the tag; packaged Chart matches its independently committed `Chart.yaml` version |

### Frozen maintenance publication boundary

`maintenance/1.x` is still frozen at released v1.3.1 and therefore still contains
its **historical main-only release workflow/tooling**. Updating these files on
the 2.x branch does not update the workflow executed by a tag on that separate
source line. Legacy compatibility jobs here validate the real released baseline;
they do not make future 1.x publication operational.

Before a new maintenance release, obtain explicit approval for a minimal
workflow/tooling backport and its necessary QA-owned test harness changes, then
validate the actual maintenance head on Ruby 3.1+ / Cucumber 9 and 10. Do not use
only the frozen baseline's results as evidence for a new patch. Preserve the
legacy gemspec/lock/dependency contract, coupled 1.x package format, historic tags
and server/chart contents; do not backport SDK 2.x runtime/dependency changes.
Publishing that maintenance ref/tag remains a separate authorized operation.

No backport, maintenance-branch edit, commit or push is performed in this task.
The policy below describes the updated tooling's capabilities **once present on
the relevant release source**, not a claim that the frozen branch already has it.

The sole main-ancestry fallback for 1.x is already-published `v1.3.1` at commit
`4ca2f770e0a84e83688f165ba04b4db8ef855cf9`. It permits verification/recovery before
the frozen maintenance branch is published, not new maintenance releases from
main. Other tags or SHAs cannot use this exception. Other major release lines,
prereleases, moved tags, dirty/untracked source and caller-selected release refs
fail closed. `RELEASE_SOURCE_ROOT` selects the source directory during recovery;
it does not change these ancestry rules.

For SDK 2.0.0 the expected packages are
`reportportal-cucumber-ruby-2.0.0.gem` and
`reportportal-rich-experience-1.3.1.tgz`. The manifest's `version` is the SDK
version; new 2.x manifests additionally contain `chartVersion`. Existing 1.x
manifests remain unchanged for byte-for-byte retained-artifact verification.
The chart name, stable version, locked bundled dependency, fixed ReportPortal
`appVersion=26.0.7`, notes, checksums, remote tag and asset bytes remain mandatory
checks. A chart version need not equal the SDK version on 2.x; no identity check
is bypassed.

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

The release CLI remains deliberately strict:

```text
ruby script/release/cli.rb build|publish TAG FULL_COMMIT_SHA OUTPUT_DIRECTORY
```

`build` requires an already-existing unchanged tag, approved remote ancestry and
a clean checkout; it cannot certify the shared uncommitted development tree.
Use QA's isolated real-gem/synthetic-chart fixtures to test preparation now. Do
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
