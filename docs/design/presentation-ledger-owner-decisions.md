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

### Decision 4: Cucumber 9 compound arguments

Question: 已实测 Cucumber 9 的解析器拒绝同一步同时包含 DocString 和 DataTable，而 F02/F03 要求两条发布线都跑这类语法。是否允许 1.x 将“原生复合语法”标为 N/A，并用分开的参数步骤验证同样的表格、描述和 Outline 展示；2.x 仍严格验收原生复合语法？

Owner answer: 允许，保留解析失败证据（推荐）

The Cucumber 9 native compound-syntax check alone is N/A. Retain the parser
failure and verify both argument types with separate steps; this does not waive
presentation, ownership, description or Outline checks. SDK 2.x retains native
compound-argument validation.

### Decision 5: Preserve native global-hook topology

Question: 还有一处验收口径需要确认：现有原生 BeforeAll/AfterAll 并不生成独立 Hook Item（2.x 的日志归属 Launch，1.x 的 BeforeAll 甚至早于 formatter 创建）。为遵守“不改变节点拓扑”，是否保留这些行为，将全局钩子的 Item 名称检查标为 N/A，同时继续验证日志/异常与退出闭合，并用单测覆盖已有 class-hook 名称映射？

Owner answer: 保留基线行为并记录 N/A（推荐）

Only native global-hook Item-name checks are N/A. Do not create synthetic Hook
Items or change Launch ownership. Continue validating logs, exceptions and
finalization, and unit-test existing class-hook name mappings. The full Q/A for
Decisions 4 and 5 is also retained in both authoritative design documents.

### Decision 6: Forward target synchronization on the 2.x feature branch

Question: 为消除 2.x 文档冲突，是否允许仅将 PR 目标分支 codex/cucumber-12 同步合并进功能分支，并保留目标分支已发布的 2.0.0 CHANGELOG 内容？不合并 PR、不推受保护分支、不强推、不发布。

Owner answer: 允许仅同步目标分支，并保留正式发布历史（推荐）

This is an operational authorization only. Master may merge the PR target
`codex/cucumber-12` forward into the 2.x feature branch after C8 handoff, retaining
the target's officially published 2.0.0 CHANGELOG history. C8 itself preserves the
frozen historical body; the separately audited synchronization may retain the
legitimate target release prose and date. RSpec checks candidate versions and
contracts rather than pinning a historical-body digest in synthetic PR checkouts.

This does not authorize merging the PR, pushing protected branches, force-pushing,
publication, or a target synchronization on 1.x. It grants no code, topology,
ownership, presentation, or other acceptance waiver. Master owns the authorized
2.x synchronization and records the resulting feature HEAD for final validation.

### Decision 7: Correct contradictory golden examples

Question: 独立 QA 发现验收金样与明确规则有三处冲突：P1 标题下划线未转义；P8 金样遗漏了 F11a 要求的 4 个请求 Header；同一 Hash 报文实际输入长度为 55/51 B，而金样写成 212/148 B。是否按明确规则修正金样，继续逐字节比较，并完整保留 P1 的 62 帧原始基线栈，不放宽帧数要求？

Owner answer: 按规则修正金样，保留严格逐字节验收（推荐）

Golden examples follow the explicit escaping, header and input-byte rules.
Keep byte-for-byte comparison and all 62 original baseline stack frames.

### Decision 8: Six legacy NUL-preview persistence exceptions

Question: 独立 QA 确认：1.x 旧基线有 6 个含 NUL 字符的文本附件未落库，新版则完整保存，且上传字节、MIME 和归属均不变。是否允许仅这 6 项改用旧版实际提交的报文作对照，并要求新版完整读回；其余 G2/G3 仍严格比较 API 基线？另有一条原生 NUL 用户日志在新旧版均未落库，将明确列为既有限制，暂不改变其语义。

Owner answer: 允许这 6 项基线例外，记录既有限制（推荐）

Only 1.x F08's five text attachments and F09's `nul-repro.txt` use the
baseline's submitted per-Item log counts/levels and attachment counts, MIME
types and SHA-256 digests as their comparison source. Preserve the baseline's
missing-persistence evidence; the candidate must fully read back all six files
and their logs. All other G2/G3 comparisons retain the persisted API baseline.
The separately observed native NUL user-log loss is an unchanged 1.x limitation,
not a newly passing case. No payload semantics or attachment bytes are changed
by this decision.

## Historical C0 Checkpoint

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

## Decisions 9-10

9. 独立 QA 发现 P10.6 的 strip-tags 定义（删除所有 <[^>]+>）会把原始 Ruby 堆栈里的 `<top (required)>` 也删除，与 P1 要求完整保留堆栈冲突。是否改为仅剥离客户端生成的展示 HTML，保留代码块、代码片段和用户原文中的尖括号，再严格检查文字顺序（仅沿用已批准的 Rich 样例差异）？

Owner answer: 按此澄清规则，保留原始内容（推荐）

10. V7 的“开始前完整 ls-remote Tag 清单”未保存；我找到了本任务开始前 GitHub CI 的完整 Tag 拉取记录，8 个 Tag 与当前远端清单完全一致，三个受保护分支也均未变。是否允许用该历史 CI 记录与当前 ls-remote 对照作为替代证据，并在报告中注明来源？不会改变“禁止创建 Tag”的要求。

Owner answer: 接受历史 CI 记录作为替代证据（推荐）

## Final Release Preparation Decisions

Decisions 11-14 were owner-confirmed on 2026-11-01.

11. P1 display refinements are approved: displayed frame locations (meta line
    and project-frame block) are capped at 40 characters by eliding middle
    directories; the raw backtrace tail is unchanged. When three frame kinds
    are hidden, the tail caption reads "a, b and c frames not shown above".
    Goldens may be updated for these two rules only.
12. Remote Ruby 3.1 / Cucumber 9 CI is not required for 1.3.2. The local
    four-cell matrix (Ruby 3.1/3.3 x Cucumber 9/10), re-run on the final
    tagged code, is the accepted evidence and is recorded in the release notes.
13. 1.3.2 is published through the release pipeline after a separate,
    approved backport of the 1.x release-ancestry rule. Manual asset upload is
    not used.
14. F2 (intraword underscore escaping in titles) and F3 (Unicode attachment
    slugs) are NOT approved for 1.3.2 / 2.0.1. Current behaviour stays.

Operational clarification: the owner confirmed that only the three named draft
PRs (#5, #6 and the separate WP3 PR) are required. No fourth PR is authorized.

F1 boundary clarification (owner-confirmed on 2026-11-01):

Question: F1 要求显示位置不超过 40 字符；若无目录的 file:line 本身已超过 40，是否允许仅对显示文件名做中间省略，保留扩展名和行号，原始堆栈不变？

Owner answer: 允许显示文件名中间省略（推荐）

## Decision 15: Existing F14 Safety Omission

Owner-confirmed on 2026-11-01.

15. 是否仅对 F14 的 `back\slash` 故障输入保留既有的整条安全省略行为，并将 P1.2 的标题检查记录为明确例外？旧、新 Ledger 对同一真实输入都返回 `[REDACTED] [evidence omitted: unsafe or oversized input]`。其他标题及转义要求仍严格验收，不放宽脱敏。

Owner answer: 保留安全省略，记录这一项例外（推荐）

This exception applies only to the P1.2 title check for this exact F14 failure
input. It does not waive other title, escaping, redaction, wire-equivalence or
regression requirements, and does not authorize weakening the safety filter.
