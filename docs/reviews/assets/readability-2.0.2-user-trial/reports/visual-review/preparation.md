# SDK 2.0.2 Independent Visual Review Preparation

Prepared 2026-11-02. Historical pre-handoff checklist, preserved below.

**Gate released:** final handoff received for SHA
`9bf3356cff350d8e2ba11bad1c33aa89881ac456` and Launches
3847/3848/3849/3850/3851/3852. Representative live comparison and 57 captures
were collected on 2026-11-02 before the urgent storage/service pause. Offline
report and inventory completion followed; any live followup remains held for
Master health clearance. Latest supplied source head is
`d1725d3ab9e796c008fe9e80a11ea0ce29bde762`, not independently rerun or verified.
See `visual-review.md`, `validation.json`, and `evidence-manifest.json` for
evidence-bounded outcomes and pending coverage. Pending fields below describe
the original preparation state, not the final report status.

Post-recovery update: explicit UI clearance was received; priority observations
on the existing launches and viewport reset are complete. See
`post-recovery-review.md` for the supplemental evidence and remaining boundaries.

This is the baseline checklist, not a new visual verdict. No 2.0.2 Launch has
been inspected or scored. Public documentation describes expected behavior; it
does not establish that a fix is present in the supplied trial.

## Scope and independence

- Write only inside `/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/`.
- Master creates the trial source and supplies the final SHA and new Launch IDs, including the suite/mode mapping. Do not inspect or execute trial source.
- Baseline content source: only the prior independent [visual-review.md](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.1/reports/visual-review.md). Linked prior reports, manifests, and screenshots have not been opened.
- Current content sources: `/Users/nick/Documents/crr-2.0.2/README.md`, public `docs/best-practices.md`, `docs/configuration.md`, `docs/advanced-reporting.md`, `examples/current_sdk/README.md`, and only Decision 27 (including its scope clarifications) in `docs/design/presentation-ledger-owner-decisions.md`.
- Do not consult other old/fresh API/UI reports, implementation, tests, Git history, or Master's fix claims. File-name discovery is not fix evidence.
- Use an independently created CUA browser tab at `http://rp-2607.localhost:18080`, project `superadmin_personal`, reusing existing authentication. Do not retrieve a password.
- No source edits, tests, commits, pushes, releases, tags, or mutations of RP records.
- The authorized opaque `/private/tmp/rp-trial-env-20261101.rb` launcher is available only if read-only API corroboration becomes necessary. Do not inspect it or print credentials; use only its authorized API child-token route. API data cannot substitute for screenshots.

## Baseline launch mapping

| Old Launch | Role | Mode | New Launch |
| --- | --- | --- | --- |
| 3837 | API example | plain | Pending Master |
| 3838 | UI example | plain | Pending Master |
| 3839 | API example | rich | Pending Master |
| 3840 | UI example | rich | Pending Master |
| 3841 | UI tester | plain | Pending Master |
| 3842 | API tester | plain | Pending Master |

Prior UI build: 5.15.6. Record the current UI build rather than assuming it is
unchanged. Prior captures used verified content viewports **1440 x 1000** and
**1100 x 1000**, DPR **1**. Compare the old and new launches in the actual RP UI
at those sizes, including collapsed and expanded states when relevant.

The prior review found no screenshots in API launches, no HTTP cards/DocStrings
in UI launches, and no DataTables in tester launches. These are baseline coverage
limits, not assumptions about the new runs. Record unavailable new samples
explicitly and do not invent coverage.

## Nine-surface rescore checklist

Use the same scale: 1 unusable, 2 substantial friction, 3 serviceable, 4 strong,
5 exceptional. Judge client content within RP's fixed UI constraints. Each new
score needs an explanation and screenshot evidence, not documentation alone.

| ID | Surface | Old score | Required new visual check | New score |
| --- | --- | --- | --- | --- |
| S01 | Launch list, name, description and attributes | 3/5 | Distinguish suite/mode/purpose; compare all six roles; inspect wrapping at both widths and version repetition separately from run-context configuration. | Pending |
| S02 | Item tree and item names | 4/5 | Inspect Feature/Scenario/Step/Hook hierarchy, Background marker, distinct outline titles, example values, Unicode and literal HTML-like text. | Pending |
| S03 | Step and hook logs | 3/5 | Read passed and failed steps, the non-fatal diagnostic, and expanded After evidence; distinguish failed check from last passed action; inspect passed-log filter interaction. | Pending |
| S04 | Failure messages and stack traces | 2/5 | Inspect All Logs and Stack Trace, collapsed and expanded; check raw markup, meaningful first lines, visible empty values, safe omission context, project frames and accessible full trace. | Pending |
| S05 | HTTP request/response cards | 3/5 | Inspect plain/rich success, expected rejection and available error cases; confirm small response is visible before transport detail, readable MIME and multi-value headers. | Pending |
| S06 | JSON, tables and DocStrings | 4/5 | Inspect expected/actual contract and key delta, JSON attachments, fenced/long content, DataTable header hierarchy, dimensions, numeric/multiline alignment and literal values. | Pending |
| S07 | Attachment names and captions | 3/5 | Check semantic filenames and state captions in rows and opened viewer; preserve visible type/size/dimensions; identify exactly one caption-plus-PNG failure entry under After. | Pending |
| S08 | Screenshots | 4/5 | Open actual successful, Unicode, sequence and failure/before-after images where supplied; judge sharpness, relevant state and surrounding interpretation at both widths. | Pending |
| S09 | Plain versus rich | 2/5 | Compare matched API/UI pairs, successful hierarchy/folding and failure robustness; separate mode effects from caller wording, run metadata and evidence routing. | Pending |

## Original ten-issue checklist

Stable issue IDs below retain the prior impact ranking, not the new outcome.
Old counts: 0 S1, 4 S2, 6 S3, 0 S4. All new verdicts are **pending observation**.

| ID | Old severity and issue | Exact old evidence IDs | Recheck and classification requirement | New verdict |
| --- | --- | --- | --- | --- |
| V01 | S2: Rich styling becomes content in Stack Trace | Launch 3839, scenario 31138, item 31141, log 20407; corroboration Launch 3840, item 31200, log 20476 | Capture rich failure in Stack Trace and All Logs at both widths. First-line signature and diagnostic values must not be displaced by SDK-added HTML/CSS. Inspect available ERROR/FATAL examples; do not imply byte identity from pixels. | Pending |
| V02 | S2: Hook evidence marks the wrong action as failed | Launch 3841, scenario 31209; passed refresh item 31214; failed item 31215, logs 20494/20495; hook 31219, logs 20498/20499/20500/20501 | Capture failed step, passed action and expanded After. Caption/title must identify failed check or failure evidence, not portray a passed browser action as failed. Record one caption-plus-PNG routing separately. Caption improvement is not an R02 ownership fix. | Pending |
| V03 | S2: Empty actual value looks like missing reporting | Launch 3841, scenario 31209, item 31215, assertion 20494, exception 20495 | Capture comparison independently of following exception. Actual empty string must be visible and labeled. Inspect whitespace-only and boundary-whitespace examples if supplied, without substituting or trimming the evidence. | Pending |
| V04 | S2: HTTP preview budget is spent before response | Launch 3837, scenario 30902, item 30904, log 20022; rich Launch 3839, item 31054, log 20253; tester Launch 3842, item 31220, log 20497 | Capture collapsed/expanded plain and rich cards at both widths. Small response body should precede URL/request/headers; MIME should be readable without array syntax. Check readable repeated header values without claiming pixel inspection proves byte preservation. | Pending |
| V05 | S3: Diagnostic-only scope is subordinate to generic failure emphasis | Launch 3837, scenario 30920, item 30925, log 20062; Launch 3839, scenario 31070, item 31075, log 20293 | Capture passed scenario/step and diagnostic preview together. Non-fatal scope must be explicit early, and business assertion distinct. Record any caller-level INFO change as such; do not infer intent from status or credit concealment of a genuine failed assertion. | Pending |
| V06 | S3: Contract comparison makes the reader perform the diff | Launch 3837, item 30991, logs 20174/20175/20176; Launch 3839, item 31141, logs 20405/20406/20407; positive contrast Launch 3842, item 31225, delta attachment log 20507 | Capture a concise missing/extra/changed top-level-key delta above original comparison, with relevant JSON/DocString and attachment still accessible. Specifically find absent difficulty. Do not require or infer a recursive diff. | Pending |
| V07 | S3: Omitted-evidence copy lacks scope and next reference | Launch 3837, item 30991, log 20177; Launch 3839, item 31141, log 20408 | Inspect matching failure and any still-present safe fallback in both modes. Check safe context and useful pointer without weakening redaction or inventing withheld exception details. If no comparable fallback exists, record the evidence gap; absence is not automatically a fix. | Pending |
| V08 | S3: Screenshot names/captions fail out-of-context scan | Launch 3838, item 31003, caption 20194, attachment 20195; Launch 3840, item 31169, caption 20443, attachment 20444; positive contrast Launch 3841, item 31213, attachment 20491 | Capture attachment rows plus opened Unicode, sequence and relevant failure images. Names/captions should identify state/check beyond generic hashes or failure.png. Judge surrounding interpretation, not altered screenshot pixels or RP's generic viewer title. | Pending |
| V09 | S3: Two API examples have same primary title | Launch 3837, scenario items 30908/30914; Launch 3839, scenario items 31058/31064; log N/A | Capture both sibling rows in each mode at both widths. Primary titles should distinguish persevere/focus or the supplied equivalent, while example metadata remains useful. Attribute authored naming separately from SDK interpolation. | Pending |
| V10 | S3: Launch metadata is inconsistent and repetitive | Launches 3837/3838/3839/3840/3841/3842; item/log N/A | Capture all new roles and compare name, mode, purpose description and filterable attributes at both widths. Separate generated version de-duplication from explicit caller metadata and tester naming. Do not attribute run-context changes to rich mode. | Pending |

Use **fixed** only when representative comparable UI evidence resolves the
original scanning problem. Use **partial** when an improvement leaves material
friction or differs across applicable samples. Use **not fixed** when the problem
remains. Missing comparable evidence stays pending/unverified rather than being
silently classified as fixed; disclose it in the final coverage statement.

## Owner Decision 27 boundaries

- ERROR/FATAL must gain no rich decoration; TRACE through WARN may keep accents. Pixel review can establish visible readability, not a general byte-equality guarantee.
- Empty/boundary whitespace labels, response-first HTTP order, plain media-type subtitles, one header line per value, top-level JSON key delta, and non-repetitive generated descriptions are expectations to test, not accepted fix claims.
- **R02 remains not fixed by owner decision.** Retain current API, After ownership and hook status. Inspect the same After evidence with `Hide all passed logs` off and on, recording the filter state in each capture. Do not recommend failing a passed hook or relocating evidence to a closed step/Scenario as a visual workaround.
- **The native HTML failure PNG is intentionally removed** in the current example in exchange for one RP caption-and-PNG entry under open After. Treat this as an adoption/routing tradeoff, not an accidental native screenshot regression. Do not claim independent native HTML verification in this RP-only review.
- Keep original exception/failure visibility, redaction, original screenshot evidence, ownership and statuses. Describe what the UI shows; do not certify data integrity from screenshots.
- Do not conflate V02's misleading caption with R02's unresolved ownership/filter behavior. A caption may improve while R02 remains not fixed.

## Screenshot and evidence protocol

1. Wait for new Launch IDs, their suite/mode mapping and final full SHA. Record them verbatim as Master-supplied identity, not as an independently verified build provenance claim.
2. Open an independent CUA tab using the existing authenticated session. Do not reuse another reviewer's tab. Do not inspect new launches before the handoff.
3. Verify actual content viewport width, height and DPR before each capture. Use 1440 x 1000 and 1100 x 1000, DPR 1 when supported; disclose deviations rather than relabeling resized rasters.
4. Revisit the relevant old 3837-3842 UI surfaces and the matched new launches. Navigate using actual rendered controls; verify the intended view is open before capturing.
5. Save real rendered screenshots under this folder's `screenshots/`. Use stable evidence IDs `VR20202-E001`, `VR20202-E002`, and so on, only when captures actually exist. No generated, reconstructed or API-only visual evidence.
6. For every capture record ID, relative file path, capture time, URL, old/new role, Launch/scenario/item/log IDs where available, tab, expanded state, filters, viewport, DPR and any hover/overlay or capture limitation. An unavailable ID is `unknown`, never guessed.
7. Each of the ten verdicts cites exact new Launch/item/log IDs (or justified N/A), old baseline IDs and relevant screenshot IDs. Each surface score cites screenshot IDs. New issues receive separate IDs and severity, without renumbering the original ten.
8. Use read-only API corroboration only if needed for exact IDs or availability. Keep visual observations and API-derived claims distinct. No password/token output or secret-bearing screenshots.
9. Record invalid/intermediate captures as excluded, with reason; do not silently treat them as proof. Restore any viewport override at the end.

## Final report deliverables

- Nine old/new surface scores with concise visual justification and coverage limitations.
- All original ten issue verdicts with exact record and screenshot evidence IDs, plus any new independently observed issues.
- Separate explicit R02 not-fixed entry and the intentional RP-only failure-PNG adoption tradeoff.
- Plain/rich preference grounded in matched rendered evidence, distinguishing default recommendation from opt-in benefits and caller/run-context effects.
- Adoption notes for successful diagnostics, failure readability, semantic evidence names, After filter discoverability, screenshot routing and native-report expectations.
- Screenshot manifest and only files inside the owned directory. No SDK certification, release approval or implementation assertions.

## Handoff gate

Final SHA: **not supplied**.

New Launch IDs and mapping: **not supplied**.

2.0.2 browser inspection: **not started**.

Screenshots captured for this review: **0**.

Next action: wait for Master to supply the above identity fields, then begin the
independent visual comparison. No new score or fixed/partial/not-fixed verdict
has been inferred from documentation.
