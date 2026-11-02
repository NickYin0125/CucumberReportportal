# Independent Visual Review: Ruby Cucumber SDK 2.0.2

**Review complete for the requested existing-launch visual scope.** After explicit post-recovery clearance, the three priority gaps were closed and the temporary viewport reset. See the [post-recovery addendum](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/post-recovery-review.md) for E059-E073, updated coverage and cleanup. Original scores, findings and warnings below are preserved. Historical pending/hold statements below describe the earlier offline completion and are superseded only by that addendum. This report judges rendered evidence, not service health, source correctness, SDK certification, performance or release readiness.

**Original ten issues: 7 fixed, 2 partial, 1 not fixed in the sampled UI. R02 remains not fixed. One new S3 presentation issue is recorded.** The important improvements are readable rich failure summaries, explicit empty actual values, response-first HTTP previews, and a visible missing-key delta. The original successful-image naming problem remains unchanged.

For day-to-day reading in this ReportPortal UI, I now prefer **rich as an explicit opt-in**: its successful HTTP/table hierarchy no longer carries the observed inline-CSS failure penalty. **Keep plain as the general default.** This is a presentation preference, not a recommendation to change ownership, statuses, payloads or release policy.

## Evidence and Provenance

Reviewed independently in an agent-created Edge CUA tab, using existing authentication in `superadmin_personal` at `http://rp-2607.localhost:18080`. Actual content viewports were **1440 x 1000 and 1100 x 1000, DPR 1**. RP UI footer showed **5.15.6**. The 57 original JPEG captures span **2026-11-02 11:55:25-12:04:47 UTC**, before the storage/service incident. No post-outage browser/API inspection was performed during offline completion.

`E###` below means the exact evidence ID `VR20202-E###`. The [evidence index](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/evidence-index.md) links every screenshot. The [manifest](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/evidence-manifest.json) contains capture times, URLs, viewports, qualifications, related record IDs, byte lengths and SHA-256 fingerprints. `L`, `I` and `G` below mean Launch, item and log ID.

| Identity | Evidence Boundary |
| --- | --- |
| Launch-generation head supplied before inspection | `9bf3356cff350d8e2ba11bad1c33aa89881ac456`; handoff identity, not independently verified build provenance. |
| Latest source head supplied during offline completion | `d1725d3ab9e796c008fe9e80a11ea0ce29bde762`; no new launch or rerun inspected for this head. |
| Claimed equivalence between heads | Master states runtime/examples/Gemfile/gemspec are identical, with followup changes limited to CI and one integration assertion. Source/diffs/tests were deliberately not read; equivalence is not certified here. |
| Supplied runtime | Normal gem 2.0.2; Ruby 3.4.2; Cucumber 12.0.1; cucumber-core 20.1.0; Playwright 1.62.0. Visible launch attributes corroborate some versions, not the entire installation. |
| Supplied input provenance | Eight copied independent inputs are SHA-identical; no package.json; fresh local node_modules resolution. These are handoff statements, not independently audited facts. |

| New Launch | Old Baseline | Role / Observed Mode | Visible Passed / Failed |
| --- | --- | --- | --- |
| 3849 | 3837 | API example, plain | 14 / 2 |
| 3850 | 3838 | UI example, plain | 8 / 2 |
| 3851 | 3839 | API example, rich | 14 / 2 |
| 3852 | 3840 | UI example, rich | 8 / 2 |
| 3847 | 3842 | API tester, rich; old tester plain | 1 / 1 |
| 3848 | 3841 | UI tester, rich; old tester plain | 1 / 1 |

All twelve launches were directly visited before the pause. New launch-list evidence is E001/E002; old list is E003/E004. **3843-3846 are excluded from comparables**; a preliminary row happens to appear below the six final rows in E001. The final sample run attribute is `20261102-1952`. New tester mode differs from the old tester mode, so tester observations establish readability, not a controlled mode-only comparison.

The sole independent historical baseline was my own [2.0.1 visual-review.md](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.1/reports/visual-review.md). Permitted public README/docs and Decision 27 supplied expectations only. No other reviewer's reports, implementation/tests, Master's fix claims, Git history or Master raw capture were consulted. Before the outage, read-only item-scoped GETs corroborated identifiers; their saved, minimized [record inventory](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/record-ids.json) contains IDs, statuses, categories and hashes, not raw messages or credentials. A launch-scoped zero-log response was not used to infer missing logs.

## Nine Surface Scores

Same scale as the baseline: 1 unusable, 2 substantial friction, 3 serviceable, 4 strong, 5 exceptional. Scores assess representative supplied content within RP's fixed layout constraints, not exhaustive test coverage.

| Surface | Old | New | Visual Basis and Limits | Evidence |
| --- | --- | --- | --- | --- |
| S01 Launch list, names, descriptions, attributes | 3 | **3** | Runtime prose no longer repeats below attributes; tester attributes are populated. Tester names still omit mode and no purpose description is visible. Run-context differences are not a rich-mode effect. | E001-E004 |
| S02 Item tree and names | 4 | **4** | API titles now distinguish persevere/focus. Gherkin hierarchy, Background markers, example values and literal HTML-like names remain readable. No claim of new automatic semantic naming. | E005/E006/E017/E050/E055/E056 |
| S03 Step and hook logs | 3 | **4** | Non-fatal diagnostic scope is explicit; passed refresh, failed check and After evidence are now distinguishable. R02 still reduces discoverability under the passed-log filter. | E010/E011/E022-E026/E031/E042/E044 |
| S04 Failures and stack traces | 2 | **4** | CSS no longer displaces the sampled rich ERROR summaries. Empty actual is visible; withheld-message records retain class and source context. RP still exposes Markdown punctuation and preview fading; complete full-trace retention is not certified. | E012-E016/E020/E021/E023/E024/E039/E040/E054 |
| S05 HTTP request/response cards | 3 | **4** | The 33-byte response and readable media type fit the collapsed preview in both modes and widths; expanded rich transport details remain accessible. Repeated-value header and 400-card rendering were not fully sampled. | E007-E009/E018/E019/E051 |
| S06 JSON, tables and DocStrings | 4 | **4** | Missing difficulty is summarized before original comparison; actual JSON, tester delta, multiline values and DataTable structure remain legible. Rich table headers have stronger hierarchy than plain. | E012/E013/E036/E037/E045-E049/E057 |
| S07 Attachment names and captions | 3 | **3** | Failure captions/names are more semantic, but original successful screenshots still have generic captions/hash names. Verbose failure captions introduce N01. | E025/E026/E032/E033/E036/E037/E041-E043/E053 |
| S08 Screenshots | 4 | **4** | Opened Unicode, sequence and empty failure images are sharp and show relevant states. Interpretation still depends on surrounding evidence; no pixel or byte-identity certification. | E027/E028/E034/E035/E038 |
| S09 Plain versus rich | 2 | **4** | Rich keeps useful success hierarchy/folding while sampled ERROR content is raw-text-safe. Main remaining naming/ownership issues affect both workflows, not just mode. | E007/E009/E014/E015/E018/E020/E021/E036/E037/E039/E040/E045/E046 |

## Original Ten Issues

Verdicts apply to the original scanning problem in the supplied representative records. They do not certify the proposed implementation or every input class. Old severities are retained as identifiers: V01-V04 were S2; V05-V10 were S3.

| Issue | Verdict | Old Exact Evidence | New Exact Evidence and Screenshots | Independent Observation |
| --- | --- | --- | --- | --- |
| V01 Rich styling becomes content in Stack Trace | **Fixed** | L3839 I31141 G20407; L3840 I31200 G20476 | L3851 I31845 G21302/G21303; L3852 I31860 G21321 and I31861 G21322. Old E016/E054; new E012-E015/E039/E040. Plain contrast L3849 I31695 G21110/G21111, E020/E021. | Assertion delta, exception class and source context replace the literal inline-CSS obstruction. Raw Markdown remains RP behavior. No sampled FATAL or general byte-identity claim. |
| V02 Hook evidence marks wrong action failed | **Fixed** | L3841 passed I31214; failed I31215 G20494/G20495; After I31219 G20498-G20501 | L3848 passed refresh I31629 G21016; failed I31632 G21023/G21024; After I31635 G21026. Old E030/E031; new E023-E026. | Caption says failure evidence for the restored-word check and separately labels refresh as the last passed browser action. After stays PASSED and owns one caption-plus-PNG ERROR entry. This is not an R02 fix. |
| V03 Empty actual resembles missing reporting | **Fixed** | L3841 I31215 G20494/G20495 | L3848 I31632 G21023/G21024. Old E030; new E023/E024/E025. | The assertion itself shows `actual "" (empty string)` before the following exception. Ordinary expected text remains readable. Whitespace-only and boundary-whitespace variants are not certified; E057 is multiline, not one of those variants. |
| V04 HTTP response hidden below transport detail | **Fixed** | L3837 I30904 G20022; L3839 I31054 G20253; old tester L3842 I31220 G20497 | L3849 I31595 G20968; L3851 I31758 G21178. Old E051; new E007-E009/E018/E019. | The small response body is visible before URL/request/headers in both plain/rich at both widths. `application/json` no longer appears as an array subtitle. Expanded rich header values are readable; repeated-value preservation and raw payload identity are outside this visual claim. |
| V05 Non-fatal diagnostic uses generic failure emphasis | **Fixed in supplied example** | L3837 I30925 G20062; L3839 I31075 G20293 | L3849 I31626 G21012; L3851 I31779 G21211. Old E052; new E010/E011/E022. | Early INFO wording explicitly says diagnostic only/non-fatal and that expected 400 was asserted separately. This is a caller/example rewrite replacing the old diagnostic comparison, not proof of a general SDK repair for failed-but-non-fatal assertions. It does not authorize lowering genuine failure severity. |
| V06 Reader must perform contract diff | **Fixed** | L3837 I30991 G20174-G20176; L3839 I31141 G20405-G20407; positive L3842 I31225 G20507 | L3849 I31695 G21108-G21110; L3851 I31845 G21300-G21302; L3847 I31587 G20959/G20960. Old E016/E049; new E012-E015/E020/E021/E047/E048. | `missing in actual: difficulty` appears above expected/actual. The actual-response JSON and tester-authored delta remain visible. This verifies the sampled missing top-level key, not recursive, extra-key or changed-value diff coverage. |
| V07 Omitted-evidence copy lacks context/reference | **Partial** | L3837 I30991 G20177; L3839 I31141 G20408 | L3849 I31695 G21111; L3851 I31845 G21303. Old E016; new E012-E015/E020/E021. | RuntimeError, withheld-message scope and feature/source location now survive, a substantial improvement over the context-free fallback. No explicit pointer directs the reader to the preceding contract comparison or actual-response.json. The safety trigger and withheld message are not inferred. |
| V08 Generic successful-image names/captions | **Not fixed at original targets** | L3838 I31003 G20194/G20195; L3840 I31169 G20443/G20444; positive L3841 I31213 G20491 | L3850 I31717 G21135/G21136; L3852 I31883 G21345/G21346. Old E053 and permitted baseline; new E032-E038. | Unicode and sequence still use `Page after the last action` plus an `evidence-...png` name. Opened images are useful but do not repair identity outside their step. Improved failure naming in E025/E043 is a neighboring improvement, not a fix for these original records. |
| V09 API outline titles indistinguishable | **Fixed** | L3837 I30908/I30914; L3839 I31058/I31064; logs N/A | L3849 I31601/I31611; L3851 I31762/I31768; logs N/A. Old E050; new E005/E006/E017. | Primary titles include `(persevere)` and `(focus)` while example metadata remains. Credit the supplied authored title pattern, not unverified SDK inference. Plain captured at 1100; rich at both widths. |
| V10 Launch metadata inconsistent/repetitive | **Partial** | L3837-L3842; item/log N/A | L3847/L3848/L3849/L3850/L3851/L3852; item/log N/A. Old E003/E004; new E001/E002. | Repeated runtime descriptions are gone from the visible list; tester mode/runtime attributes now exist. Tester names still omit mode, and purpose descriptions are absent from the list. Run context and presentation are independent settings; no source SHA is visible here. |

## Remaining and New Findings

### R02: After-Owned Failure Evidence Is Still Hidden by the Passed-Log Filter

**Not fixed, retained by owner decision and independently reproduced before the outage.** L3852 scenario31858 has failed item31860, original exception G21321, and PASSED After item31861 owning ERROR caption/PNG G21322. With the filter off, E042/E043 show two ERROR logs and the attached evidence. With it on, **E044 shows one ERROR log and a PASSED After row with paperclip count 1 but no visible child evidence**. This is not an API-only inference and not a service-outage symptom. L3848 I31635 G21026 provides additional count/filter corroboration in E025/E029; E029 alone is not direct After-row proof because the row is below its viewport.

[Filter off, evidence visible: E042](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/screenshots/VR20202-E042-3852-after-collapsed-1100.jpg) | [Filter on, evidence hidden: E044](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/screenshots/VR20202-E044-3852-after-filter-on-1100.jpg)

Do not falsify a passed hook status or move evidence to a closed failed step/Scenario. Document the filter caveat and keep After ownership/API behavior unchanged. Clearer captions resolve V02, not R02.

### N01: Verbose Consolidated Failure Caption Hides Its Provenance and File Metadata

**New S3, presentation friction rather than missing evidence.** L3852 I31861 G21322; E041 at1440 and E042 at1100 show the collapsed caption. Scenario/check wording, last passed action and repeated Playwright exception/call log consume the preview before the After-ownership explanation and filename/type/dimensions. E043 expansion reveals those fields. The thumbnail is already visible; the original exception remains separately visible on I31860. Do not exaggerate this into loss of the failure or PNG.

[Collapsed: E042](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/screenshots/VR20202-E042-3852-after-collapsed-1100.jpg) | [Expanded: E043](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/screenshots/VR20202-E043-3852-after-expanded-1100.jpg)

Prefer a concise failure-evidence title, then the After-capture explanation and short semantic filename/type/dimensions, followed by last passed action and the full diagnostic detail. Preserve one caption-plus-PNG record, original PNG bytes, exception, severity and ownership. The current long derived filename is more informative than failure.png but need not repeat the entire scenario and action.

## Preference and Adoption

**RP-focused preference: rich opt-in; general default: plain.** New rich success cards provide compact HTTP emphasis, header folding and stronger table headings (E007/E009/E036/E037 versus E018/E045/E046). The prior decisive drawback, CSS taking over the raw failure preview, is absent in the sampled rich ERROR records (E014/E015/E039/E040 versus E016/E054). Plain remains a dependable lower-decoration baseline. Neither mode fixes arbitrary caller text, launch intent, screenshot identity or After-filter discoverability automatically.

- Adopt response-first summaries and the top-level missing-key cue; retain original request/response data, comparison and attachments. A 201 or expected 400 is not a substitute for the business assertion.
- Supply explicit non-fatal wording only when the caller knows the diagnostic scope. The new INFO example is clearer, but it is not a blanket policy for lowering ERROR severity.
- Keep empty-string labels and raw-text-safe failure summaries. Retain safe class/location context when a message is withheld, and add a safe nearby-evidence pointer without exposing withheld content.
- Improve the unchanged Unicode/sequence filenames and captions at the caller level. Do not annotate or alter actual screenshot pixels to compensate for weak surrounding context.
- **Native HTML failure PNG removal is intentional per owner direction:** one RP caption-plus-PNG under open After is the chosen tradeoff. This RP-only review confirms representative RP evidence, not native HTML contents. Teams relying on native HTML failure screenshots must accept that changed expectation explicitly; it is not reported as an accidental regression.
- Explain R02 in the adoption notes and keep the passed-log filter off when locating After evidence. Simplify N01's caption without changing ownership or status.

## Validation and Pending Coverage

Offline validation passed for **57/57 screenshots, 4,428,090 bytes**: sequential IDs; no missing/empty/unindexed files; valid JPEG start/end markers; dimensions readable by the local image tool and matching capture metadata; SHA-256 for each file; cited new log IDs linked to their saved item/launch IDs. Original `captures.json`, `record-ids.json` and screenshot bytes were not changed during offline completion. See [validation.json](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/validation.json). Hashes are local integrity fingerprints, not proof of build provenance or equality to the original PNG attachments.

Coverage is surface-based, not a claim that every record or every mode/width combination was opened. In the saved categorized inventory, API launches have no screenshot records; UI launches have no HTTP/DocString records; testers have no DataTable records; no FATAL records were supplied. Category inventory is corroboration, not visual proof for content not opened.

The attempted E058 expanded exception/full-trace capture failed twice with ENOSPC and produced no saved file. It is excluded. Focused source frames are visible in existing screenshots, but complete-frame retention is not certified. E057 was correctly classified as a multiline All Logs comparison, not boundary-whitespace evidence. E029 is supporting filter evidence only; E044 is the decisive saved comparison.

Still unverified or incomplete: whitespace-only/boundary-whitespace assertion variants; repeated-value header presentation; fully expanded plain HTTP and expected-400 card captures; a new opened tester before-refresh image pair; native HTML output; full trace capture; final-head rerun and source-equivalence verification. These gaps do not become defects, fixes or outage-based verdicts.

**No further browser/API work until Master health clearance.** Temporary viewport reset was not confirmed before the urgent stop and remains a cleanup item only if the review tab/session survives; the browser was not accessed merely to reset it during the hold. No SDK/source/test changes, test executions, commits, pushes, tags, releases, RP-record edits or data deletion were performed. All review files remain inside the owned visual-review directory.
