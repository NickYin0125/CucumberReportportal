# Cucumber 12 independent release acceptance

## Decision

The original 2.0.0 candidate is **rejected**. The corrected candidate is
**accepted within the explicitly tested, supported contracts**, following a
separate implementation patch and independent runtime, real-backend and
clean-room retests. Both identified defects are closed. This is not complete
literal acceptance of every requested assumption or a claim of 100% production
reliability; the applicability limits below remain explicit. No merge, push, tag
or release was performed in this acceptance campaign.

## Findings and corrections

### P1 Text preview NUL caused acknowledged but missing evidence

The original attachment preview copied a literal NUL into `log.message`.
ReportPortal returned HTTP 201 and log IDs, then its persistence task failed with
PostgreSQL SQLState 22021 (`invalid byte sequence for encoding UTF8: 0x00`). The
main reproduction acknowledged 18 records but persisted only 13 logs/files; a
minimal reproduction acknowledged one and persisted none. The local v1 receipt
still reported `complete=true`.

The correction visibly escapes NUL in outbound log text and rendered previews,
without changing attachment bytes, filenames, paths, or source files. Expanded
preview text still obeys the existing byte and line limits. The independent
retest must query the stored logs and compare downloaded attachment hashes; a
successful response alone cannot close this finding.

**Corrected verification: PASS.** The original five NUL attachment forms and a
plain native NUL log persist. The full media case now has 18 acknowledged and
18 persisted/downloaded records. Minimal attachment and plain-log reproductions
each persist one record. Original attachment bytes and download hashes match,
and no known backend NUL error signature appeared during the corrected runs.

Baseline live evidence: `tmp/cucumber12-independent/live/reviewer-C.json`,
`nul-backend-error.txt`, and RP Launches 49 and 62.

### P2 Combined Outline table retained source placeholders

Gherkin 42.0.1 parses both a DocString and DataTable on one Step. Core 20.0.0
supplies only the DocString as the executed Ruby argument. The original renderer
therefore fell back to the raw source table and displayed `<value>` instead of
the current Examples row, despite a successful compatible step definition.
Independent wire and live tests reproduced both argument orders and both rows.

The correction retains the already-compiled table from the public
`test_step_created` event and supplies it to the bounded renderer. It does not
reimplement Gherkin interpolation or expand compiled values a second time.
Executed arguments retain precedence. Only the needed table references are
retained under a mutex, reused across native retry clones, and cleared during
normal or exceptional finalization.

**Corrected verification: PASS.** Both argument orders and both Examples rows
display the compiled table values in item descriptions and rich logs. Native
header-order behavior for a literal `<other>` value is preserved without a
second expansion. Browser review confirms the table and DocString together.

Baseline live evidence: RP Launches 57 and 60; runtime cohort
`audit-20261031T031800740113-8827` preserves the eight failing assertions.

## Package provenance

Baseline source: `e7dae2b2bc7559339a796d657a4e1219e7f6b0aa`, branch
`codex/cucumber-12`.

| Package | SHA-256 |
| --- | --- |
| Original 2.0.0 candidate | `68b1ab8889f1e3448f6809b498c0aa7ff9ef9a03f4f1f5ae6d4e01fe2f6d17b3` |
| Corrected 2.0.0 candidate | `c6bf0aae1fa9bd1e356fa116934cebebd582353afd381ec4b16bf9fc67ca62f3` |
| Unchanged legacy 1.3.1 comparison | `bbec7ce0840ea17ae1d7d6106a2047a92474b970c57131ced8679f7e75e54e12` |

The corrected archive is
`pkg/cucumber12-independent-corrected-20261031-0BKVAS/reportportal-cucumber-ruby-2.0.0.gem`.
Its adjacent manifest verifies all 203 packaged files, including all 37 library
files, against the corrected working tree. The original archive remains intact.
These are local candidates, not public RubyGems releases. Runtime dependencies
and gemspec requirements have not changed in this correction.

## Acceptance matrix

PASS below refers to the stated supported contract, not to every assumption in
the original request. APPLICABILITY and mixed results must not be counted as
unconditional literal acceptance.

| Case | Corrected result | Scope and limitation |
| --- | --- | --- |
| TC-01 | APPLICABILITY | Feature/optional Rule parentage and descriptions pass. Source directories are not suites; arbitrary tags are not automatically exported. |
| TC-02 | PASS | Background actions belong to each current Scenario. |
| TC-03 | APPLICABILITY | Separate Outline rows/UUIDs/parameters pass. Inherited Examples attributes require the allowlisted opt-in. |
| TC-04 | Mixed | Both parsed arguments and compiled Outline values render correctly. Core 20.0.0's two-Ruby-argument invocation remains unsupported, also with the SDK disabled. |
| TC-05 | PASS | Undefined/pending are nonpassing, followers skipped, and no removed `strict?` call occurs. |
| TC-06 | PASS | Ambiguity produces failure evidence and closes the Scenario. |
| TC-07 | PASS | Passed/failed/skipped sequence and complete Ruby failure backtrace are retained. |
| TC-08 | APPLICABILITY | Native `log` has the right UUID and timestamp bounds. Kernel `puts` remains terminal-only. |
| TC-09 | PASS with input limits | File, path, bytes, explicit Base64, PNG/text/JSON, NUL preservation and ownership pass. Plain Base64 with an unencoded MIME is literal text; native StringIO/pipe limitations remain. |
| TC-10 | PASS | Failed Scenario remains failed; evidence is on the open After Hook. Corrected real browser-image fixture uses JPEG bytes, name and MIME consistently. |
| TC-11 | PASS within native mapping | Before/After/AfterStep and Around outcomes close correctly. Method hooks retain BEFORE_METHOD/AFTER_METHOD mapping; no fictional Around item is invented. |
| TC-12 | PASS | Global logs/errors and self-owned Launch completion work without a current Scenario. |
| TC-13 | PASS | Separate retry attempts retain identity and end with the final passed outcome. |
| TC-14 | PASS | Exhausted global retry budget closes the final failure without waiting for an absent retry. |
| TC-15 | Supported modes PASS | Fifty rapid Steps reconcile on API v1/v2. `use_same_thread_for_reporting` is not a supported setting; both modes use the queue. |
| TC-16 | PASS under external ownership | Four real parallel_tests worker PIDs share one parent-created Launch; only the orchestrator finishes after all workers. No worker-owned distributed-finish/lock cleanup is claimed. |
| TC-17 | PASS | Fresh Linux ARM64 Ruby 3.3.12 and 3.4.12 install and run Cucumber 12.0.1 with corrected SDK 2.0.0 and runtime-only dependencies. |
| TC-18 | PASS in private candidate index | Actual Bundler resolution selects SDK 1.3.1 for Ruby 3.1.7/Cucumber 9.2.1 and corrected 2.0.0 for Ruby 3.3.12/Cucumber 12.0.1. This is not public RubyGems publication. |

## Regression and hard gates

- **958 RSpec examples, zero failures, zero pending**, plus 7 offline Cucumber
  scenarios and 21 steps passed on the frozen corrected working tree.
- The independent installed-package matrix ran **48 actual CLI processes and
  625 HTTP requests**; 15 explicit black-box checks passed. Its 34 owned Launches
  and 212 items closed; no unhandled background thread exception was observed,
  and ten distinct PNGs had exact expected ownership and hashes.
- Corrected real-RP runs produced **14 Launches, 237 finished items, 208
  persisted logs and 65 byte-verified downloads**. All created UUIDs, including
  nested and retry-hidden items, were queried individually. There were zero
  pending/failed reporting records and zero SDK worker errors in those runs.
- The final campaign-wide readback covers **64 Launches and 857 items**, including
  rejected baseline and earlier harness attempts: zero unfinished Launches/items,
  zero incorrect parents and no manual cleanup.
- Clean-room TC-17/18 completed all **12 provenance/dependency/load-path/CLI
  audits**. Five owned containers and the isolated network were removed. The
  baseline evidence, original packages and ReportPortal/kind were left intact.

The three hard gates pass for the corrected supported paths. Expected business
failures and exit-code probes remain visibly FAILED/INTERRUPTED; they were not
relabelled as successful tests to make the report green.

## Launch ownership

Ownership, not process count or a CI environment variable, determines completion.
An ordinary process closes its self-created Launch after native AfterAll and
test_run_finished settle reporting; at_exit is the bounded fallback. Independent
processes creating separate Launches each finish their own. Workers supplied an
external UUID leave completion to the CI or local parent orchestrator, including
when there is only one worker. Workers still close their own items and delivery
queues. SIGKILL cannot execute exit hooks.

Baseline live probes verified an AfterAll log preceding Launch finish, an
interrupted self-owned run preserving exit code 7, and a single external-UUID
worker leaving the Launch open until its owner completed it. Four real
parallel_tests worker processes also shared one Launch, with one final finish
after every worker receipt. This is not an SDK distributed-finish protocol.

## Evidence interpretation

The three independent reviewers own runtime/media checks, clean-room/resolver
checks, and live backend/protocol checks. A separate implementation agent made
the fixes; the coordinating reviewer examined the changes and browser behavior.

The baseline live audit queried every owned UUID, including earlier harness
attempts: 50 Launches and 620 items were closed, with zero incorrect parents and
no manual cleanup. That successful lifecycle audit does **not** erase the
missing-evidence defect.

An initial browser capture was mistakenly saved with a `.png` extension although
the capture API returned JPEG bytes. The bytes were preserved, but that fixture's
declared MIME was wrong; it is not proof of PNG handling. Corrected browser
captures use `.jpg` and `image/jpeg`. Separately, ten distinguishable synthetic
640x360 PNGs exercise PNG decoding, byte preservation and exact Step ownership.
The supplied After-hook screenshot is an actual RP browser capture, not a claim
that this campaign drove a failed Playwright application and recorded its screen.

API v1 acknowledgements and API v2 acceptance are not independent database
audits. `complete` remains a client delivery receipt, not a guarantee against a
subsequent backend storage failure. Final evidence must reconcile API readback
and attachment hashes rather than infer persistence from HTTP success.

## Reproduction and visual evidence

Runtime commands and evidence are in
`tmp/cucumber12-independent/runtime/corrected-c6bf0aae/reviewer-a-corrected-handoff.json`.
Use `script/acceptance/cucumber12_blackbox_README.md` for explicit archive/hash
inputs. The installed audit is separate from default RSpec discovery; default
RSpec includes only portable harness guards.

Real-backend evidence is in
`tmp/cucumber12-independent/live/corrected-c6bf0aae-20261031T033152Z/final-review.json`.
It records the corrected package hash, all 203 installed file checks, per-worker
load paths, wire records, persisted records and downloaded hashes. Clean-room
commands and the independent verifier are documented in
`script/acceptance/cucumber12_cleanroom.md`; the corrected run is
`tmp/cucumber12-independent/cleanroom/20261031T033142Z-6ff82b/`.

The coordinating reviewer physically inspected the Suite Passed filter, native
PNG/JSON previews, [corrected NUL log](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/66/1160/1162/log),
[combined Outline table](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/72/1295/1296/log)
and [After Hook JPEG](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/76/1363/1364/log).
Screenshots under `tmp/cucumber12-independent/ui/` include
`corrected-nul-step.jpg`, `corrected-combined-outline.jpg`,
`corrected-after-hook-owner.jpg` and `corrected-after-jpeg-preview.jpg`.

See [the visual review handoff](2026-10-31-cucumber-12-ui-aesthetics-handoff.md)
for the complete corrected Launch list and the distinction between synthetic
PNG cards, real browser captures and deliberate negative controls.

## Follow-up boundaries

The acceptance fixes have not been merged or released. Remote CI has not been
rerun on this uncommitted correction; the previous branch CI result applies only
to its previous commit. The generic NUL mitigation is a candidate for a separate
maintenance/1.x backport, not a reason to merge Cucumber 12 implementation into
the legacy release line. Cosmetic changes should start from a committed
functional baseline in an isolated worktree and preserve these regression gates.
