# Ledger 2.0.1 Evidence Guide

Final sign-off date: 2026-11-01 Asia/Shanghai. Status: **ACCEPT**, with open nonblocking G11/S3 timing and cosmetic findings. This is not release/merge/publication authorization.
[Acceptance report](../2026-11-01-presentation-ledger-2.0.1-acceptance.md) and [84-criterion check index](presentation-ledger-2.0.1-acceptance.json).
All ten owner Decisions are reproduced verbatim in the report. Decisions 9/10 explicitly close P10.6/V7; the original published BLOCKED checkpoint and exact criterion records remain in [history](ledger-qa-owner-closure-history-2.0.1.json).

## Contents
Reports, indexed exact expected/actual checks, all S01-S12 PNGs, UI/DOM/download provenance and QA harness are plain files.
Raw outputs are losslessly compressed, not discarded. Each manifest lists every original path, byte count and SHA256.
[Restoration proof](presentation-ledger-2.0.1-archive-verification.json) hashes the actual decompressed bytes of every archived file.

| Group | Download | Index | Files | Raw bytes | Compressed bytes |
| --- | --- | --- | --- | --- | --- |
| live | [archive](presentation-ledger-2.0.1-live-raw.tar.xz) | [SHA256 manifest](presentation-ledger-2.0.1-live-raw.manifest.json) | 8296 | 628997205 | 6311084 |
| checks | [archive](presentation-ledger-2.0.1-checks-raw.tar.xz) | [SHA256 manifest](presentation-ledger-2.0.1-checks-raw.manifest.json) | 11810 | 683768123 | 8910460 |
| matrix | [archive](presentation-ledger-2.0.1-matrix-raw.tar.xz) | [SHA256 manifest](presentation-ledger-2.0.1-matrix-raw.manifest.json) | 3450 | 277532761 | 3254396 |

`live` retains wire requests, HTTP receipts, per-item API/download snapshots and fresh readbacks, native NDJSON/HTML and stdout for every independent run, including original invalid baseline captures.
`checks` retains offline/fault/performance outputs and original browser JPEG capture bytes; any environment logs and supplied historical failure records are labelled separately.
`matrix` retains full RSpec/Cucumber JSON/stdout, runtime/source provenance and exact scratch dependency text inputs for all completed, failed, invalid or superseded cells.
The long `source/docs/reviews/assets/qa-cell-evidence` prefix in matrix archives is an artifact path only: no copied SDK source tree is included.
SDK mirrors, nested `.git`, caches, Docker config, runtime working copies and temporary gem/chart/package binaries are excluded. Local untracked originals remain available; exclusions are not hidden product changes.

## Restore
From a fresh checkout of this QA branch, run these commands at its repository root:

```sh
tar -xJf docs/reviews/assets/presentation-ledger-2.0.1-live-raw.tar.xz -C .
tar -xJf docs/reviews/assets/presentation-ledger-2.0.1-checks-raw.tar.xz -C .
tar -xJf docs/reviews/assets/presentation-ledger-2.0.1-matrix-raw.tar.xz -C .
```

Entry paths are repository-relative. Report/screenshot links resolve directly; raw source references resolve after extraction.
Original absolute locations in historical provenance are not rewritten. Map `/Users/nick/Documents/crr-qa-2.0.1/` to the checkout root when resolving such artifact paths. Frozen stack frames, authored strings and original process arguments are **data**, not links; preserve those bytes unchanged.
Baseline/SDK source locations refer to the recorded Git commits, not omitted evidence. Inspect them from the repository history without treating copied source caches as deliverables.

To repeat the lossless archive validation without extraction:

```sh
/opt/homebrew/opt/ruby/bin/ruby spec/acceptance/ledger_qa/publication.rb 2.0.1 verify
```

This machine's helper uses the recorded QA root; on another machine, change only that helper's root mapping, not payloads or test expectations.
In the acceptance JSON, each criterion's `check_ids` indexes the full top-level `checks` table. `inputs.captured_source` plus `selection`, SHA256 and native IDs points to exact retained raw input records. No expected/actual assertion values were removed by indexing.

## Provenance And Limitations
Candidate FEATURE head: `e906fada5971cb0e5713006506eaad9be52021e6`. Actual tested runtime head: `ecf8c5aade5b6982f96083cb21c758db56b81b3f`. Baseline: `79e5e9cfde4be6d29ca2293e549460c6c71fe87a`. [Git fingerprints](ledger-qa-doc-only-binding-2.0.1.json) prove the final feature delta is only the two approved design documents; runtime/product tests/dependencies/lock/workflows/Helm are identical. The final six-cell stamp is `final-hooks-20261101`; product counts are 1345/1402 plus 16 QA properties per cell, not a selected subset. No QA commit is represented as the tested feature candidate, and no fresh matrix executions are invented.
[Decision 9 checks](ledger-qa-p106-decision9-2.0.1.json) use exact canonical word equality, raw/code-byte preservation, mutation negatives, and only source-context/line-count validated P10 fold/status annotations and Decision2 positions. No arbitrary inserted text is accepted.
[Decision 10 proof](ledger-qa-v7-decision10-2.0.1.json) compares authentic pre-task CI tag NAMES to fresh current remote names and unchanged protected head SHAs. Historical tag object SHAs are not known and equality is not claimed.
[Fresh standalone package proof](ledger-qa-final-doc-package-2.0.1.json) binds the packaged approved docs to the new feature tree; two pre-existing SDK-shipped review PNGs have explicit unchanged-byte proof. Temporary .gem/source mirrors are not published, and old package/harness attempt records remain labelled historical.
Earlier `final-fixed-20261031` and `final-p88-20261101` matrices are superseded, not final-head proof. Early setup/recorder failures and the interrupted terminal-repair cell are retained without product-failure or PASS claims.
Baselines from `20261031T065500Z` are **UNUSABLE** because they loaded candidate source from Cucumber's current-directory load path. Corrected `20261031T072147Z` captures include loaded-source guards.
F04 uses an API-verified historical 62-frame input replay (Launch 76/item 1365/log 1118), not a naturally generated current stack. No-project, non-Exception and metadata-getter fault shapes are explicitly controlled inputs. Current native stacks are retained separately.
The original final-hook GET audit's 15 retry item mismatches remain intact. Separate direct retry readback verifies API-nested attempt IDs, true parents/UUIDs/lineage, closed states and exact expanded item/log sets; this is not a topology waiver.
Decision 8 applies only to the six named 1.x NUL-preview attachment baseline losses, using submitted baseline wire and complete candidate download. The unchanged native raw-NUL user-log persistence limitation remains explicit. The baseline F16f SECRET123 probe hit is not a candidate secret leak.
Genuine Console screenshots use ordinary native message search, not Markdown-off. UI download proof uses the real saved filename/bytes, not response headers alone. Master's review/archival instructions are not owner waivers.
G11 remains an open S3 SHOULD timing failure; cosmetic Examples metadata wrapping is also S3, while each required key/value chip is one physical line. P2.1/P8.8/P6.1 original S2 evidence and repaired retests are both preserved.
Historical live runners are retained as reviewed commands, including explicitly invalid/superseded versions. Do not blindly re-execute them: they intentionally pin the tested SDK heads, require secure Master-only environment injection, and create new Launches. No credentials are committed.
