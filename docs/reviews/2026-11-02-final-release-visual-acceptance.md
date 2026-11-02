# Final release visual acceptance - reportportal-cucumber-ruby 2.0.2

Verdict: ACCEPT, independent visual scope only. Date: 2026-11-02. No open defect or blocker in the six rows below. This is not a verdict on the separate contract, security, performance, or publication gates.

Candidate: `8f44c10533eb4d0a8eae1adcc2ed5b63ace155c7`, branch `codex/failure-redaction-2.0.2`, runtime patch `f2976d8f563ff2aada816f821dcb539f6e8dc9da`.

The SDK is read-only and was clean at setup. The independent visual reviewer read the acceptance document, proposal and owner decisions in full without consulting prior reviewer reports or verdicts. Decision 27 and the R02 ownership clarification are applied. Browser setup uses the existing authenticated ReportPortal at `http://rp-2607.localhost:18080`, project `superadmin_personal`, UI 5.15.6, viewport 1100 x 780. No password was entered.

## Results

| Criterion | Status | Evidence |
| --- | --- | --- |
| P1.6 MUST | PASS | Launch 4045, items 33061/33043, logs 22278/22269. Exact rendered titles contain literal `x<script>alert(1)</script>` and `<b>x</b>`. Both scoped rendered log containers contain zero script and zero b elements. `P16-script-literal` / `P16-bold-literal` DOM and screenshots. |
| P1.8 MUST | PASS | Plain frozen F04, Launch 4041/item 33027/log 22246. Title y=527..568.5 and meta y=588.5..609, visible above the untouched RP fold at 1100 x 780. `S01-f04-plain-untouched-fold` and `P18-visibility.json`. |
| P1.9 MUST | PASS | Same original F04 log in Stack Trace; the first message line is the failure-card title. Rich counterpart Launch 4062/item 33169/log 22342 is also title-first raw text. `S02-f04-plain-stack-trace` / `S02-f04-rich-stack-trace`. |
| P10.8 MUST | PASS | All 19 emitted details fences in the selected fresh F18/HTTP inputs have blank lines before/after fences, exact `details > pre > code` DOM, and code text identical to raw input fences. All 19 were opened through UI controls. F18 Launch 4047/item 33117/logs 22312-22315 and item 33122/log 22320; HTTP 4054/33143/22331, 4050/33131/22327, 4064/33177/22353-22358. `visual-check-results.json` records each fold separately. |
| P10.10 MUST | PASS | Rich PNG/Text/JSON captions and opened preview modal: 4061/33166/22339-22341 (`S06`). Numeric 8-column table, right-aligned numeric cells without header accents; 4-column table with four styled headers: 4076/items 33242-33243/logs 22437-22438 (`S08`). PASS pill/sans title: 4059/33158/22336. Readable opened F18/HTTP summaries, failed-assertion values and key delta, failure evidence: `S18` / `S09`. Decision 27 ERROR/FATAL cases remain plain, including 4065/33180/22362-22363 and Rich F04 (`S03-f04-rich-all-logs`). |
| P10.11 SHOULD | PASS | Computed non-error decorative pill contrast: PASS 5.4364:1, FAIL 5.0420:1, WARN 5.3747:1, INFO 5.3823:1. All exceed 4.5:1. Opaque computed colors and ancestor opacity=1; exact RGB pairs and IDs are in `visual-check-results.json`. FAIL-tone 500 is a WARN-level log, not ERROR. |

## Evidence

Evidence root: `docs/reviews/assets/QA202-final-release-20261102-visual/`. Each screenshot has its original JPEG bytes plus a same-name JSON with URL, viewport, candidate, focused Launch/item/log IDs, DOM, computed styles, and screenshot SHA-256. `capture-index.json` binds those IDs to source snapshot/result and raw-message SHA-256 hashes. `visual-input-manifest-final.json` retains the exact inspected messages and source bindings; no other-review verdict fields were used. `source-sha256.txt` binds the six relevant SDK presentation sources, and README records normative document hashes.

F18 coverage includes the 340-line attachment's 100-line preview, the 25-line JSON preview, and the 25-line JSON DocString. The single-line 48 KiB text and oversized JSON emit no details fold because their previews are single-line; their 16 KiB previews and full-file notes remain in the captured DOM and raw manifest. This is not an exemption for an emitted fold. The HTTP inventory covers request/response headers and 40/99/100/101-line response bodies.

All 31 ERROR/FATAL pairs in the inspected input manifest are byte-identical between plain and Rich; exact hashes and pair IDs are retained. This is supporting evidence for Decision 27 in this scope, not a substitute for the contract agent's complete inventory.

Screenshots were inspected directly as well as through DOM. Markdown mode was on, level All, and Hide All Passed Logs unchecked. The browser viewport override was reset after the final capture. Browser/live-generation workload has stopped; only lightweight local evidence processing followed.

## Decisions And Limits

Decision 27 is applied, not waived: "Rich presentation never adds HTML to ERROR or FATAL log messages; they are byte-identical to plain." The older forced Rich backtrace fold/ERROR accents are superseded. Stack Trace intentionally shows raw Markdown title-first.

R02 remains unresolved, not fixed. The approved existing API, After ownership and hook status are preserved. A passed After Hook's evidence can still be hidden by Hide All Passed Logs. This report neither moves evidence nor claims the filter limitation was repaired.

The supplied frozen F04 leaf URL and the UI's own leaf link showed breadcrumbs without log controls. Navigating via Scenario -> Log view exposed the original item-owned log without replay or topology changes; both the initial empty-route observation and successful original-log evidence are retained. This is not a blocker for the scored rendered criteria.

`S18-previews-closed.json` is an incomplete first helper invocation; its original screenshot is retained but the pair is not used to pass a row. Use `S18-previews-closed-valid` and the opened-fold captures. `S09-http-tones-folds-open` records a partially opened state after an input timeout; `S09-http-all-folds-open` verifies all 12 folds opened. `S03-f04-rich-decision27` captured the retained Stack Trace tab; the actual All Logs evidence is `S03-f04-rich-all-logs`. No original artifact was overwritten or deleted to conceal these observations.

The independent visual reviewer generated no additional Launches, used no alternate RP/Docker instance, made no SDK or old-Launch changes, performed no performance/load work, and consulted no other reviewer report or verdict. New files remain unstaged and uncommitted for Master's serialized secret scan and commit. No merge, tag, push or publication was performed.
