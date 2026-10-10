# M3 And Security Checkpoint, 2026-10-10

## Status

**MASTER ACCEPTANCE: PASS for the M3 checkpoint and scoped F1/F3/F4 repair.**
Luna Tester completed final candidate6 regression and installed-gem acceptance;
Hume independently returned SCOPED PASS on the byte-identical READY5 SDK.
No demonstrated same-scope P1/security P2 remains. This is not an unconditional
GA approval: the non-security findings listed below are still open.

## Checkpoint Scope

The annotated checkpoint tag is `m3`, on `codex/reporting-experience-v1-2`, following
the existing `milestone1` and `m2` checkpoints. It captures M3 AST/description
metadata, opt-in identity migration, Scenario business attributes and reference
links, plus the F1/F3/F4 diagnostic-security patch and its regression tests.
It is a milestone checkpoint, not a new gem version or GA release.

The checkpoint includes the reviewed SDK, specs/fixtures, applicable examples,
README and design/verification records. Unvalidated duration features and their
Gemfile.lock, Rakefile, cucumber.yml and gemspec changes remain in the working
tree, excluded from the tag. No unrelated work is reverted, staged, or removed.
Historical failed snapshots and receipts remain evidence, not converted to PASS.
The live runners in `examples/m3c_live` and `examples/m2m3_regression` preserve
their historical sandbox/snapshot prerequisites; they are not portable clean-room
setup instructions or newly rerun live evidence.

## Required Gates

- Frozen candidate source matches the staged SDK and regression specs.
- Cucumber 10.2 full RSpec, randomized seed 20261010, focused security, and
  M2/M3 native integration pass on the final candidate.
- Cucumber 9.2 compatibility gate runs with actual child-runtime provenance;
  disclose its existing test-loader adapter and native collection limitation.
- Normally installed gem consumer validates source provenance and public APIs.
- Independent review closes demonstrated F1/S1/S2/S3 and F3/F4 boundaries,
  including natural ordinary/fallback spool, warning and artifact metadata.
- Tag points to the committed validated tree; publication and remote reference
  verification preserve the current branch and existing tags.

## Known Limitations

F2 (relative source identity from subdirectory working directories), F5 (no-RP
World setup/documentation), F6 (Examples prose), F8 (literal outline placeholders
in Markdown) remain separate P2 findings. F7 (installed design-document links)
remains P3. This checkpoint does not declare these fixed or waive them as
production-safe. They remain visible follow-up work alongside M4 planning.

Diagnostic sanitization is scoped, not universal PII filtering. Ordinary AppLog
and legacy rp_log, raw file/video bytes, automatic Step/manual-step errors and
backtraces, and native Cucumber core failure payloads retain their documented
behavior. Original test errors are not mutated or suppressed. Privacy canaries
are synthetic and verified offline, never sent to the live RP deployment.

## Evidence

Final source: `/tmp/m2m3-regression-20261010-candidate6`. Its source-manifest
SHA-256 is `422f20ee3b794ccc652742d1f9aa29b1b436d30dbce7ff4f937c3e34ff3d3263`.
The inventory has 91 entries, including ignored `spec/.DS_Store`; the 90 versioned
README/lib/spec files match the workspace, execution copy and installed gem.
The four dirty duration/dependency manifests retain their pre-run hashes.

| Final gate | Actual result |
| --- | --- |
| Cucumber 10.2 focused security | 89 examples, 0 failures |
| Cucumber 10.2 full RSpec | 290 examples, 0 failures |
| Cucumber 10.2 seed 20261010 | 290 examples, 0 failures |
| Cucumber 10.2 M2/M3 integration | 220 examples, 0 failures |
| Cucumber 9.2 adapted full/focused/integration | 290/0, 89/0, 220/0 |
| Installed gem Cucumber consumer | 3 scenarios / 10 steps passed; 55 logs, 3 multipart batches |
| Independent review | SCOPED PASS; all 30 SDK files match reviewer5 and final6 |

The full and integration child-runtime audits each cover 31 actual processes:
29 native Cucumber children and 2 standalone children. The focused audit covers
6 processes. Cucumber 9's unadapted spec collection still raises the pre-existing
event-file LoadError; its green full-suite result uses an external require-only
test-loader adapter, not a product patch or native/unshimmed PASS.

Candidate5's 290/2 failure came from incomplete fault-injection coverage caused
by variable log batching. Candidate6 adds real Step boundaries for deterministic
coverage of every transport-error branch; all privacy and protocol assertions
remain intact and READY5 SDK bytes are unchanged. Both receipts are retained.

Detailed receipts and source hashes are in
[security verification](reporting-experience-security-verification-20261010.md);
the independent conclusion and earlier HOLDs are in
[security review](reporting-experience-security-independent-review-20261010.md).
Earlier live M2/M3 and browser evidence stays in the 2026-10-09 regression
records and is not claimed as rerun by this offline security continuation.

Master's Git gate checks the staged and committed versioned source against the
final candidate, excludes the unfinished duration work, and verifies the remote
branch and peeled `m3` tag against the resulting commit. Publication results are
reported after those operations; this record does not pre-claim remote success.
