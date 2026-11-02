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

## Decision 16: Independent CI Stability Investigation

Owner-confirmed on 2026-11-01.

16. 远端 CI 的未改动 1.3.1 基线出现 SIGINT/Spool 和超时失败。是否允许把这些既有 CI 稳定性问题纳入独立排查，必要时另作修复提交？保持全部断言，不推受保护分支、不合并或发布。

Owner answer: 允许独立排查与必要修复（推荐）

This authorizes separately reviewed CI diagnostics and regression coverage,
including narrowly scoped validation-workflow changes under V6. It does not
authorize weakening existing assertions, changing Helm, modifying protected
branches, merging, tagging or publishing. A successful unchanged retry does
not establish the cause of an earlier failure or demonstrate a runtime fix.

## Decision 17: Scoped Console Renderer Replay

Owner-confirmed on 2026-11-01.

Question: S12 要求查看 F04 的 Console View，但 RP UI 5.15.6 对嵌套步骤隐藏该入口。是否允许在新建的独立 QA Launch 中，对同一条 F04 日志做字节完全一致的平铺回放，仅验证 Console 展示？原始测试拓扑和证据保持不变，补充证据会明确标注其范围。

Owner answer: 允许补充平铺回放（推荐）

S12 may use a new, independently owned flat-log QA Launch containing the exact
F04 message bytes. Record the original runtime SHA and Launch/item/log IDs,
message checksum, supplemental IDs and Console screenshot. This is renderer-only
proof: retain the original F04 topology and observations, and do not use the
supplement to certify or change the SDK's item hierarchy, ownership or wire
contract. Markdown-off is not a substitute for Console View. All other
acceptance and no-merge/no-tag/no-publication requirements remain unchanged.

## Decision 18: Scoped F14 API Parameter Ordering

Owner-confirmed on 2026-11-01 after an explanation of the user-visible impact.

Question: 最终审查发现：Cucumber 10 的 F14 基线 API 把参数返回为 e,a,b,c,d，新版为 a,b,c,d,e，但双方发出的参数顺序和值逐字节一致。服务端内部使用无序 Set，API 却声明 List。是否仅对这项 API 读回按完整参数集合（保留重复计数）比较，保留原始差异；所有请求报文仍严格逐字节验收？

Owner answer: 接受这项窄范围调整， 继续

Only the observed Cucumber 10 F14 GET parameter-array ordering difference may be
compared as a complete multiset, preserving duplicate multiplicities. Retain
the original API-order FAIL observations and the independently reviewed server
source explanation. Exact ordered POST parameter bytes must still match.
No parameter name, value, count, identity, topology or other field is excluded.

This is an acceptance-comparison clarification, not an SDK behavior change or
a guarantee of fixed parameter ordering in the ReportPortal UI. The request and
response DTOs declare Lists; server persistence uses a Set. Do not describe the
response contract as an unordered Set. All other acceptance and
no-merge/no-tag/no-publication requirements remain unchanged.

## Post-Release Scope

The owner's final decision on 2026-11-01 approved releases 2.0.1 and 1.3.2.
PR #8 remains an unreleased 2.0.2 draft: synchronize the released 2.0.1
baseline and reconcile Decision 19 before its next review. This synchronization
does not certify or publish the split-redaction candidate.

Decision 19 below is exclusively the released 1.x failure-content contract.
Decisions 20-26 are retained historical WP records, not current release gates
or 2.0.2 acceptance. Their references to two-unit Decision 19 describe its
superseded text, not the current 1.x contract.

## Decision 19: 1.x Failure-Log Content

Owner-confirmed on 2026-11-01.

19. On 1.x, the failure log carries the same text v1.3.1 sent, shown in the
    Ledger failure card. Failure-log redaction is not added in 1.3.2: the 2.x
    redactor omits the whole failure for common inputs (any backslash in the
    message), which hid failures that v1.3.1 showed (Launch 3778 versus
    Launches 3637 and 3731). Decision 15's P1.2 exception is withdrawn on 1.x,
    and G8 on 1.x means "nothing is sent that v1.3.1 would not have sent".
    2.x is unchanged; its whole-failure omission is a separate backlog item.

## Decision 20: Cross-Unit Credential Safety Path

Owner-confirmed on 2026-11-01.

Question: 已复现跨 message/backtrace 边界的凭据泄露风险。是否允许仅在检测到跨边界凭据时保留整体脱敏安全路径，并单独验证其调用数？普通失败仍按 Decision 19 拆分，正常路径保持两次调用；不会放宽任何脱敏规则。

Owner answer: 允许这个受测的安全例外（推荐）

A detected credential spanning redaction-unit boundaries may use the existing
whole-input safety path instead of independent redaction. This narrow path
must have its own security and call-count tests. Ordinary failures still use
Decision 19's two-unit redaction and normal/per-frame call counts. No weaker
filtering or general byte-equivalence waiver is authorized.

## Decision 21: Draft-Only Release-Tooling Integration

Owner-confirmed on 2026-11-01.

Question: WP4 要等你合并 #7，但最终条件又要求 #7 仍为草稿。是否允许将 #7 的功能分支以 merge commit 合入 #6，直接验证组合状态，同时不改任何受保护分支、四个 PR 都保留草稿？

Owner answer: 允许合入功能分支，四个 PR 保持草稿（推荐）

Merge the reviewed `maintenance/release-ancestry-1.x` feature branch into
`maintenance/presentation-ledger-1.3.2` using a merge commit. Resolve only
release-tooling, release-workflow and related-spec conflicts. The combined
state must pass verification; protected branches remain unchanged, all four
PRs remain draft, and no PR merge, tag or publication is authorized.

## Decision 22: Recorded Failure Corpus, Not a Recreated 41-Case Set

Owner-confirmed on 2026-11-01.

The 41-case set doesn't exist as a file; it came from a summary. Don't recreate it. For the no-regression check, use every failure (message plus backtrace) recorded in the committed wp5-ci-final-20261101 captures on the qa/ branches (F01–F20, including all F14 escaping inputs), the frozen F04 62-frame failure, and the WP2 probe corpus. Generate the baseline by running the tested runtime (3f20313 for 2.x, f41888a for 1.x) in its own worktree, and store the outputs with SHA-256. Wherever the baseline didn't return the omission marker, the new output must be byte-identical.

This replaces only the nonexistent 41-case input list. Preserve input
provenance, original captures and all failures. N1 independently continues to
compare against actual v1.3.1 at `4ca2f77`.

## Decision 23: Dated Release-Notes Test Compatibility

Owner-confirmed on 2026-11-01.

Question: WP1 的日期变更触发了既有测试：它强制 CHANGELOG 必须写 Unreleased，因此“只改 CHANGELOG”与“PR #5 CI 绿色”无法同时满足。是否允许另加一个仅测试的提交，让该断言严格接受有效发布日期，并将绑定证明范围明确扩展为 CHANGELOG 与该测试文件？运行时代码仍完全不变。

Owner answer: 允许仅测试的兼容修复并更新证明（推荐）

Keep the original WP1 date-only commit and its proof intact. A separate
test-only commit may make `spec/packaging/presentation_docs_spec.rb` accept
Unreleased or a strictly valid ISO calendar date, with positive and negative
tests. The updated binding must show exactly CHANGELOG and this spec changed
from `173c603`; all runtime, dependency, Helm and workflow bytes remain
unchanged. This does not authorize a release or weaken runtime verification.

## Decision 24: Encoded and Incomplete Cross-Boundary Credentials

Owner-confirmed on 2026-11-01 after a new synthetic security probe.

Question: 新探针发现：不完整 JSON 中的 Unicode 转义凭据名（例如 pass\\u0077ord）跨 message/backtrace 边界时，当前候选守卫未识别，合成凭据值会残留。是否允许进一步加固 Decision 20 的边界识别，覆盖这类编码/不完整输入，并增加回归测试？仍只在检测到跨边界凭据风险时走整体安全路径，正常路径维持两次调用，不放宽脱敏。

Owner answer: 允许安全加固并重新验收（推荐）

Extend only the Decision 20 safety guard to recognize encoded or incomplete
cross-unit credential syntax. Keep existing redaction policy unchanged and add
explicit regression probes. Ordinary input retains two redact_text calls;
per-entry fallback retains 2 + N calls; detected cross-unit credential risk
uses the separately tested whole-input safety path. Preserve the original
failed observation. No candidate certification or release is authorized by
this approval.

## Decision 25: Comparable G11 Timing Boundaries

Owner-confirmed on 2026-11-01.

Question: 核对旧 G11 脚本后发现，它只计时 FailureCard 渲染，未计入 formatter 中的脱敏；本轮要求计入二者。是否同时保留旧口径对照，并在同一语料、同一环境下重测旧版与新版的“脱敏＋渲染”完整链路，对两种可比口径都执行超过 10% 即停止的规则？不会用排除脱敏后的数字冒充完整链路性能。

Owner answer: 同口径重测并保留历史值（推荐）

Retain the historical renderer-only values and raw evidence. Re-measure the
old and new runtimes on the same corpus and environment for both renderer-only
and complete redaction-plus-rendering paths. Apply the more-than-10% stop
rule separately to each comparable timing boundary; never compare a
renderer-only sample with a complete-pipeline sample or label the former
as inclusive redaction timing. The required Cucumber 9 alternating wall-time
comparison remains unchanged.

## Decision 26: Synchronize the WP1 Feature Head into 2.0.2

Owner-confirmed on 2026-11-01.

Question: PR #5 新增了你批准的日期校验测试提交，而 2.0.2 分支建于该提交之前。是否允许用 merge commit 将 #5 功能分支同步进 #8，仅协调包装测试中的日期断言，避免你先合并 #5 后 #8 再出现冲突？不合并任何 PR、不推受保护分支，仍全部保留草稿。

Owner answer: 允许同步功能分支（推荐）

Merge the PR #5 feature branch into the PR #8 feature branch with a merge
commit, reconciling only the package documentation/date assertions. Preserve
the dated 2.0.1 history, the Unreleased 2.0.2 section and the strict positive
and negative date checks. No runtime edits are authorized by this integration
decision; all four PRs remain draft and protected refs remain untouched.

## Decision 27: 2.0.2 Readability Fixes From the 2.0.1 User Trial

Owner-confirmed on 2026-11-02.

27. SDK 2.0.2 fixes the client issues found in the independent 2.0.1 trial
    (Launches 3837-3842). These amend the Ledger proposal and acceptance
    criteria:

    a. Rich presentation never adds HTML to ERROR or FATAL log messages; they
       are byte-identical to plain. ReportPortal's Stack Trace tab shows these
       messages as raw text. Rich accents remain for TRACE to WARN messages.
       This replaces the rule that allowed a pill on the second line of ERROR
       cards and the rich backtrace fold.
    b. Assertion values that are empty, whitespace-only, or start or end with
       whitespace are shown quoted with a label, for example `"" (empty
       string)`. All other strings are still shown as-is.
    c. HTTP cards show the outcome before transport detail: title, response
       body, URL, request body, request headers, response headers. Headers
       render one `name: value` line per value; the content-type subtitle
       shows the plain media type. No value is changed or dropped.
    d. When both assertion values are JSON objects, one line before the
       comparison names the top-level keys that are missing, extra or
       changed. This is not a general diff.
    e. The generated run-context description no longer repeats versions that
       are already Launch attributes.
    f. The shipped example (examples/current_sdk) and user docs are corrected
       as listed in the 2.0.2 work packages.

    The plain default, redaction, raw evidence bytes, item ownership and
    statuses are unchanged. The 1.x line is not changed.

### R02 Scope Clarification

Owner-confirmed on 2026-11-02 after inspecting the current capture-target API.

Owner answer: 保持现有 API 和 After 归属，仅补充过滤警告，R02 标记未修复（推荐，改动最小）

Do not extend the runtime capture API or move After-hook evidence to a Scenario.
Document the passed-log filter interaction and record R02 as not fixed. All
other work packages continue under Decision 27.
