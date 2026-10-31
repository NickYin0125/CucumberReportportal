# Ledger presentation: owner decisions and implementation checkpoint

Date: 2026-10-31. These decisions supplement, but do not rewrite, the two
original design documents committed unchanged in C0.

## Confirmed baselines

- SDK 1.x: `4ca2f770e0a84e83688f165ba04b4db8ef855cf9`.
- SDK 2.x: `79e5e9cfde4be6d29ca2293e549460c6c71fe87a`.
- Frozen corrected Gem SHA-256:
  `c6bf0aae1fa9bd1e356fa116934cebebd582353afd381ec4b16bf9fc67ca62f3`.
  It was originally built from an uncommitted tree based on `e7dae2b`.
  Reading the actual Gem archive and its original manifest confirmed that all
  203 packaged files match commit `79e5e9c` byte for byte; `e7dae2b` differs
  in five files and is not the corrected baseline. This is a source-content
  attribution, not a claim that the artifact was built after that commit.
- The subsequently published `v2.0.0` remains untouched. Its release-document
  updates are not substituted for the explicitly requested frozen baseline.

## Owner-approved adjustments

### Independent SDK and Chart versions

Owner instruction: "移除这个限制" in response to the finding that 1.x release
tooling required the Gem and Helm versions to match.

SDK 1.3.2 and subsequent releases may use unchanged Chart 1.3.1. The Gem must
still match its release tag. Chart filenames, archive metadata and manifest
`chartVersion` must match the separately committed Chart version. Historical
1.x manifests through 1.3.1 retain their original identity and title so existing
assets still verify unchanged. This does not authorize publication, ancestry
changes, CI workflow changes or a Chart update.

### Trusted table line breaks (P2.3)

Owner approval: "允许客户端生成的 <br>（推荐）"

The raw-angle-bracket property permits only the client's generated `<br>`
line-break token. All angle brackets originating in user data remain escaped.
This is not permission to pass through arbitrary user HTML.

### Rich examples take precedence over strict word order (P10.6)

Owner approval: "按 Rich 样例呈现，调整 P10.6 允许这些差异"

The explicit P10 rich examples may move an attachment's kind before its name,
replace the passed-assertion label with a PASS pill, and use the specified HTTP
status/title presentation. P10.6 must allow these specified decorative changes,
rather than require their plain labels and word order. Evidence values must not
be lost or changed. ERROR first-line equality, byte budgets, channel separation
and the closed HTML/style vocabulary remain mandatory. This is not a blanket
waiver for other missing or reordered evidence.

### Temporary Chart archives in existing tests

Owner approval: "允许测试中的临时打包（推荐）"

Existing isolated regression tests may create and remove temporary Chart
archives. No deliverable Chart, deployment, upload, release or tag is authorized.

## Checkpoint

C0 is committed on both isolated feature branches:
`codex/presentation-ledger-2.0.1` (`9ea7f1f`) and
`maintenance/presentation-ledger-1.3.2` (`eb17e54`).

The owner subsequently authorized the independent-version patch as a separate
commit before C1-C8, pushed immediately to both feature branches. C0 remains a
separate, unchanged commit; the three approved adjustments are appended verbatim
as a Decisions section in both source-of-truth documents. Only draft pull
requests are authorized. No merge, tag, release or publication is authorized.
No presentation implementation or independent acceptance is claimed here.

Developer release-tooling regression on Ruby 3.4.2:
- 2.x feature worktree: 61 examples, 0 failures, 6.65 seconds.
- 1.x feature worktree: 45 examples, 0 failures, 2.50 seconds.

These are focused developer checks, not the full Ruby/Cucumber matrix or an
independent acceptance verdict. Publication calls in these tests are mocked.
Chart files, CI workflows, protected branches, tags and remote releases were
not changed.
