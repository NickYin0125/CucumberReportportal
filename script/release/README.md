# GitHub Release Operations

Normal stable tags invoke `Tag Release`: verify fixed release-line ancestry, run the complete
offline validation, build gem/Chart/checksums/provenance and publish through a draft.
Only the publish job has contents-write permission. No RubyGems push is performed.

## Current candidate boundary

SDK **1.3.3** is prepared, not published by this change. The matching candidate
archive is `reportportal-cucumber-ruby-1.3.3.gem`; the companion Chart remains
`reportportal-rich-experience-1.3.1.tgz` / ReportPortal `26.0.7`. Consume a supplied
or locally built archive using the [example workflow](../../examples/current_sdk/README.md#source-and-packaging-verification),
not an assumed release URL. Candidate packaging is not publication authorization.
No merge, tag, release or deployment is authorized by this candidate work.

This selectively backports 2.0.2 readability and example-redaction improvements
onto released 1.3.2, preserving Decision 19, Ruby >=3.1 / Cucumber >=9,<11 and
the existing 1.x runtime/tooling policy. Historical Ledger opt-in rationale and
QA evidence remain in their original 1.3.2 changelog section, not new 1.3.3 proof.

## Validation and dependency isolation

Every Ruby 3.1/3.3 x Cucumber 9.2.1/10.2.0 cell runs full RSpec, offline Cucumber
and `bundle exec rspec script/release/spec` against this checkout. Each resolves
dependencies in a private runner-temporary Gemfile and retains its exact lockfile
and runtime identity. The tracked Gemfile, lockfile and gemspec stay unchanged.
The all-cells gate keeps the recovery-compatible `validate / test` check name.

Only after that gate succeeds may the separate tag-only bundle job build from a
fresh checkout. Before Ruby setup, it exports `BUNDLE_PATH` and
`BUNDLE_APP_CONFIG` beneath `RUNNER_TEMP`, disables `bundler-cache`, and explicitly
installs the frozen root bundle. This fixes the known release-only dirty-source
failure caused by setup-ruby's `vendor/bundle` cache and local Bundler config.
Never ignore vendor files or relax the clean-source guard to work around it.

The executable isolation regressions use a real offline cached gem and disposable
Git repositories. They verify external dependency/config paths, frozen-lock
bytes, clean source acceptance and rejection of tracked edits/deletions, staged
changes, untracked files and the old `vendor/bundle` layout before artifact output.
All test commits/refs are confined to disposable fixtures, not the working tree.

## Independent SDK and Chart versions

Starting with SDK 1.3.2, the Gem version must match the release tag, but it no
longer needs to match the Helm Chart version. The Chart filename, archive
metadata and `chartVersion` manifest field are checked against the independently
committed `Chart.yaml`. For example, SDK 1.3.3 can accompany unchanged Chart
1.3.1 / ReportPortal 26.0.7. Release titles display both versions.

SDK 1.3.1 and older 1.x bundles retain their original manifest/title format and
identity checks, so historical assets still verify without rebuilding or
overwriting them. Package names, appVersion, digests, tag and commit checks remain
mandatory. The 1.x publisher keeps `latest=false` and fixed maintenance ancestry;
the isolation repair changes neither publication policy nor deployment files and
does not grant permission to publish.

## Recover validated assets

If publication fails after validation and artifact preservation, do not move the
tag or rebuild/replace already published assets. From a trusted `main` checkout:

```sh
gh workflow run release-resume.yml --ref main \
  -f tag=v1.3.0 -f source_run_id=38406093937
```

Replace these example values with the actual tag and completed **Tag Release**
run ID. The recovery workflow checks repository/workflow identity, original tag
SHA and approved release-line ancestry, successful preflight and full-validation jobs, and one
unexpired original artifact. It downloads that exact artifact and checks out the
original source while running repaired publication tooling from `main`.
The publisher verifies package identity, checksums, committed notes and remote
asset bytes before publishing. Mismatched, ambiguous, incomplete or expired input
fails closed; published releases are never silently repaired or overwritten.

GitHub's by-tag API can hide drafts even when authenticated release listing shows
them. The publisher uses paginated authenticated listing after a by-tag 404;
authorization and network failures are not treated as an absent release. Draft
discovery must not create a duplicate or downgrade validation.

Original failed runs remain audit history. A successful recovery run, not a
rewritten tag or retroactively green historical run, is the publication proof.
