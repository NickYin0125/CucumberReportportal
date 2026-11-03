# Independent 1.x Selective Backport Acceptance

Status: scoped local ACCEPT for frozen candidate
`68e81d3697965305438be4fa27aa98aeb4baf726`. See
`docs/reviews/2026-11-03-maintenance-1.3.3-final-acceptance.md` for actual results,
measured HTTP cost increases and unchanged limitations. This is not release or
publication authorization; no remote CI result is claimed.

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
FROZEN_SHA=68e81d3697965305438be4fa27aa98aeb4baf726
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
renderer/HTTP payloads. It retains all samples, pooled median/p95 and per-replicate
variation and reports measurements, not
automatic acceptance. A master-requested stop marker named
`STOP_AFTER_CURRENT_CELL` in the run evidence directory preserves the current
cell and prevents subsequent cells; it is not a task pause.

Final fresh real-RP launches are 4085-4088, with complete DOM evidence in the
final report. Inspect `/private/tmp/ledger-qa-token-runner.rb` before reuse;
it obtains existing authorized credentials only in memory and suppresses token
echo. Live scripts must reject any endpoint other than
`http://rp-2607.localhost:18080` and project `superadmin_personal`. Never write the
token, environment dumps, authorization headers or raw credential responses.
Typewords, if necessary: `http://localhost:5567/words`.

Existing adversarial probes are timed separately on the candidate only, without
comparing against unsafe historical passthrough. The completed normal series is
not repeated. This command reuses its exact frozen candidate export:

```sh
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/adversarial_bench.rb --source /Users/nick/Documents/crr-qa-1.3.3/docs/reviews/assets/qa-1.3.3-paired-bench-20261103T120527Z-df3d/candidate-source --frozen-sha "$FROZEN_SHA" --resource-slot-confirmed
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/audit_live.rb --evidence docs/reviews/assets/qa-1.3.3-live-20261103T115435Z-8112 --frozen-sha "$FROZEN_SHA"
/opt/homebrew/opt/ruby/bin/ruby qa/readability_1x/curate_manifest.rb
```

The manifest includes supported `.feature`, shell/YAML files and exact resolved
locks, with per-entry classifications separating old failures from final gates.
It excludes source clones, nested Git stores, packages, caches, native HTML and
generated SDK fault scratch; complete outcome/failure JSON and logs are retained.
It inventories but does not stage, commit or publish. Its own output file is
listed separately when preparing a future curated commit.

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

## Standalone-Isolation Finding

The three failures in the first Freeze-2 Ruby 3.3 attempt are an SDK
standalone-spec isolation defect, not a helper implementation defect or 2.x
dependency contamination. Bundler 2.6.6 sets `BUNDLER_SETUP`; RubyGems 3.5.22
auto-requires it at boot. The old specs' `env -u` list did not unset this flag.
Freeze 3 adds only that explicit child unset in three SDK specs. Canonical full
runs use the ordinary `bundle exec rspec` command with no launcher shim,
monkeypatch, test overlay, hidden filter, or global bootstrap-flag deletion.
`environment_diagnostic.rb` is retained root-cause evidence only and is not
invoked by the matrix. Its controlled before/after comparison is not a full run.
