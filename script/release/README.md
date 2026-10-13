# GitHub Release Operations

Normal stable tags invoke `Tag Release`: verify tag/main ancestry, run the complete
offline validation, build gem/Chart/checksums/provenance and publish through a draft.
Only the publish job has contents-write permission. No RubyGems push is performed.

If publication fails after validation and artifact preservation, do not move the
tag or rebuild/replace already published assets. From a trusted `main` checkout:

```sh
gh workflow run release-resume.yml --ref main \
  -f tag=v1.3.0 -f source_run_id=38406093937
```

Replace these example values with the actual tag and completed **Tag Release**
run ID. The recovery workflow checks repository/workflow identity, original tag
SHA and main ancestry, successful preflight and full-validation jobs, and one
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
