# Independent 1.x Selective Backport Acceptance

Status: PREPARATION. No candidate has been accepted. Candidate full execution is
forbidden until the master supplies a frozen 40-character SHA.

## Provenance and Ownership

- Read-only implementation: `/Users/nick/Documents/crr-1.3.3`, branch `codex/readability-backport-1.3.3`.
- Owned harness: `/Users/nick/Documents/crr-qa-1.3.3/qa/readability_1x`.
- Owned fresh evidence: `/Users/nick/Documents/crr-qa-1.3.3/docs/reviews/assets/qa-1.3.3-*`.
- Baseline: `/private/tmp/ledger-release-verification-20261101-rQL8pk/source-1.3.2`, SHA `19174a5ecaf1aa9fb65480f0a21d74ed65c89a8d`.
- Existing 2.x harness code is methodology only. Historical results and verdicts are not acceptance evidence.
- No SDK edits, commits, pushes, tags, releases, deployments, new API keys, or service stops.

## Acceptance Gates

1. Decision 19: exact raw failure message and joined frames survive (including
   Windows paths, backslashes, multiline RSpec differences, synthetic credentials,
   invalid encoding and bounded-renderer fallback). Zero FailureRedactor calls.
2. Selective 2.0.1-to-2.0.2 changes only: ERROR/FATAL wholly plain; distinguish
   blank/space/tab/newline assertion values; response body first and protected
   from request preview starvation; repeated headers remain individual values;
   safe shallow key differences; branch/SHA/build description with version
   attributes, no 2.x worker/lifecycle/status/NUL semantics.
3. Stronger existing automatic redaction channels: encoded JSON keys, URL paths
   and queries, malformed URLs, repeated Bearer and `[REDACTED]` prefix residue.
   Raw AppLog remains deliberately unchanged. Only synthetic secrets in fixtures.
4. Four serial FULL RSpec plus default FULL offline Cucumber cells: Ruby 3.1/3.3
   x Cucumber 9.2.1/10.2.0. Report actual examples/failures/pending and actual
   scenarios/steps/statuses. Targeted tests never substitute for full suites.
5. Fresh minimal live RP at final SHA: Cucumber 9/10 x plain/rich, four launches
   total initially. Failure frame/readability, HTTP, attachments, outline, one
   unique PNG/single RP entry, correct After Hook ownership and unchanged status.
   R02 remains NOT FIXED: passed-log filters can hide passed After evidence.
   The plain cell for each Cucumber version also executes the actual packaged
   `examples/current_sdk/test/self_test.rb`, not a reimplementation. Packaged
   consumer bytes, actual check counts, activated SDK and Cucumber are recorded.
   This independently checks the example's failed-check title and hex4 screenshot
   naming, separately from the QA fixture's own hex8 attachment names.
6. Original compound DocString plus DataTable on a single step: Cucumber 9/10
   unsupported, N/A; separate supported argument steps must be used, not a fake.
7. Review frozen diff and runtime: no FailureRedactor activation, 2.x lifecycle,
   status or NUL semantics imported. If rendering changes, inspect relevant DOM
   escaping, folds, contrast and F18 large previews in existing local RP UI.
8. Performance: matched frozen v1.3.2 renderer and benign structured HTTP cases,
   same runtime/dependencies and alternating measurements. Coordinate heavy work
   with master first. Unsafe legacy fast paths are NOT security/performance gates.
9. Local packaging checks only; no automatic 1.3.3 publication this turn.

## Dependency Isolation

`run.rb` clones exact committed source into fresh evidence and mounts it read-only.
`cell.rb` executes a matching container-local copy; library SHA256 values and the
original lock are verified before/after. The separate runtime Gemfile evaluates
the cloned source Gemfile then pins Cucumber exactly, expressions `<19`, diff-lcs
`<2`. Each cell retains the resolved Gemfile/lock, exact activated gems, image
digest, argv, output, counts and status. Cached gems are mounted read-only.
No SDK Gemfile or SDK lock is rewritten. No RP credentials enter offline cells.

Full runs require prepared, digest-pinned tools images. `prepare_images.rb`
builds only on verified existing local Ruby bases and installs genuine Linux jq
with its Debian shared libraries. `preflight.rb` records all required executable
versions/hashes, validates jq ELF/linkage and real filter execution, and rejects
missing tools before any SDK probe or full suite. Source/activated SDK version,
Ruby >=3.1, Cucumber >=9,<11, expressions >=17,<19, exact Cucumber selection,
Bundler 2.6.6 and diff-lcs <2 are checked after isolated resolution and before tests.

The baseline lock actually resolves Cucumber 10.2.0, expressions 18.0.1 and
diff-lcs 1.6.2. The v1.3.2 full-suite minimum is 1519 examples per cell, never a
claimed actual candidate count. Unfiltered discovery and execution counts must
match, including per-file counts. No excludes, overlays or omitted whole files
are allowed; pending examples are not accepted.

## Exact Commands

Run from `/Users/nick/Documents/crr-qa-1.3.3` with the host Ruby:

```sh
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/prepare_images.rb
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/run.rb --phase baseline --scope preflight --cells M1,M2,M3,M4
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/run.rb --phase baseline --scope targeted --cells M4
```

The initial command is deliberately one lean baseline cell, not a full candidate
matrix. Baseline DELTA/SEC failures are observations, not candidate failures.

After the master supplies `FROZEN_SHA` (all 40 hex characters):

```sh
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/run.rb --phase candidate --scope full --cells M1,M2,M3,M4 --source /Users/nick/Documents/crr-1.3.3 --frozen-sha "$FROZEN_SHA"
```

After the full frozen-runtime gates, the four sequential minimal RP launches:

```sh
/opt/homebrew/opt/ruby/bin/ruby /private/tmp/ledger-qa-token-runner.rb /opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/live.rb --source /Users/nick/Documents/crr-1.3.3 --frozen-sha "$FROZEN_SHA" --authorize-live-writes
```

After master confirms a shared-resource benchmark slot (not before):

```sh
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/compare_bench.rb --source /Users/nick/Documents/crr-1.3.3 --frozen-sha "$FROZEN_SHA" --resource-slot-confirmed
```

The paired benchmark alternates baseline/candidate order over three replicates,
checks equal Ruby/dependency activation, uses no network and only benign normal
renderer/HTTP payloads. It reports measurements, not automatic acceptance.

No real-RP launch yet. Inspect `/private/tmp/ledger-qa-token-runner.rb` before use;
it obtains existing authorized credentials only in memory and suppresses token
echo. Live scripts must reject any endpoint other than
`http://rp-2607.localhost:18080` and project `superadmin_personal`. Never write the
token, environment dumps, authorization headers or raw credential responses.
Typewords, if necessary: `http://localhost:5567/words`.

## Depth-Boundary Risk

The released 2.0.2 redactor still leaks four/five-layer percent-encoded JSON
paths after downstream decoding. This was independently reproduced against
redactor/credential-key bytes verified equal to `v2.0.2` (`29ce2a4`), not inferred
from a developer verdict. The protected 2.x tag is untouched. A 1.x fix must pass
MAX-1/MAX/MAX+1/5 checks through URL, HTTP and evidence/diagnostic channels.
Remaining escapes after three inspection passes are intentionally withheld,
including benign or previously masked over-depth inputs; no extra decode pass
is required. Raw AppLog and Decision 19 remain unmodified channels.

## Final Report Fields

Frozen source SHA, independent review findings, four full-cell runtime versions
and actual counts, targeted counts, fresh Launch IDs and item/log ownership,
R02/N/A declarations, relevant DOM evidence, matched performance evidence,
packaging evidence, and complete owned-file list. ACCEPT is prohibited while
any required frozen-runtime gate is missing or a blocking finding remains.
