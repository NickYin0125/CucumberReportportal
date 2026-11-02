# Post-Recovery Visual Evidence Addendum

Completed 2026-11-02 after explicit permission to resume UI inspection. **All three priority observation gaps are closed for the existing sample records. Original scores, ten issue verdicts, R02 and N01 remain unchanged.** No launches were generated, no direct API calls were made, and no SDK/test/source files or RP records were changed.

The independent review tab revisited only existing launches **3848, 3849 and 3851**. This is not fresh QA of the owner-authorized performance optimization. The assertion that later runtime changes preserve output bytes remains for independent verification elsewhere. The supplied `090b633` documentation-only followup is recorded as handoff information, not independently inspected or certified.

## Completed Observations

| Priority | Exact Existing Records | New Screenshot IDs | Observation |
| --- | --- | --- | --- |
| Expanded full trace | L3851, scenario31842, I31845, G21303 | VR20202-E059, E060, E073 | Expanded All Logs shows RuntimeError, the withheld-message notice, feature/source context, seven focused lines, then a section labelled `Full backtrace`, 88 frames, 81 framework frames not shown above. The rendered full-trace block contains 88 newline-delimited lines; top and final frames are accessible and saved. This closes the failed-capture gap, not a general byte-preservation certification. |
| Expanded plain HTTP 201 | L3849, scenario31593, I31595, G20968 | VR20202-E062/E063 | At 1440 and 1100, response JSON precedes URL, request JSON, six request headers and three response headers. Media types and individual header values are readable; both header blocks remain accessible after expansion. |
| Expected HTTP 400 | L3849, scenario31617, I31620 G21006; separate status assertion I31622 G21008. Rich contrast L3851, scenario31774, I31776 G21207 | VR20202-E064-E066, E072 | The collapsed response shows `{"error":"word_required"}`, `application/json`, 25 B and expected400. The step remains PASSED with no ERROR logs. Expanded plain details show the empty-word request and both header blocks. Rich uses an amber400 badge, not a failed assertion. A separate response-status step remains visible; HTTP status is not treated as proof of the business contract. |
| Before/after refresh image pair | L3848, scenario31609; before checkpoint I31625 G21013/G21014/G21015; After failure I31635 G21026 | VR20202-E067-E071 | The semantic `saved-before-refresh.png` checkpoint shows `follow-up` in the input and `Saved: follow-up`. The paired After-owned PNG shows an empty input and `Ready to practice`. Both actual images were opened at 1100 and 1440. The surrounding failed assertion and After ownership still explain the failure; no screenshot pixels were edited. |

`E###` is shorthand for `VR20202-E###`. Exact capture URLs, times, viewports, file hashes and record associations are in the [combined evidence manifest](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/evidence-manifest.json). All images are linked in the [evidence index](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/evidence-index.md).

### Expanded Trace Evidence

[Expanded top at 1100, E073](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/screenshots/VR20202-E073-3851-fulltrace-expanded-top-1100.jpg) and [final frames at 1440, E060](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/screenshots/VR20202-E060-3851-fulltrace-expanded-end-1440.jpg) are the primary visual evidence. E059 also captures the expanded top at 1440. No claim is made that every frame fits a single image.

**Capture qualification:** E061 requested a full-page screenshot, but RP's internally scrolling log area produced only a 1440x1000 app viewport at the top of the scenario. It is preserved and explicitly not used as proof of the complete backtrace. E058 remains the earlier unsaved ENOSPC attempt; its ID was not reused. The screenshot gap is closed by the successful expanded top/end captures and rendered line-count corroboration, not by relabelling E061 as a full trace.

### Before/After Pair

![Before refresh: saved follow-up, E068](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/screenshots/VR20202-E068-3848-before-refresh-image-1100.jpg)

![After refresh: empty input and Ready to practice, E071](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/screenshots/VR20202-E071-3848-after-refresh-image-1100.jpg)

## Unchanged Findings and Boundaries

- V01-V06 and V09 retain their original evidence-bounded fixed verdicts; V05 remains an example/caller rewrite, not a general failed-diagnostic SDK fix.
- V07 remains partial: source/trace context is accessible, but the explicit pointer to the nearby contract comparison/actual-response attachment is still absent.
- V08 remains not fixed at the original Unicode/sequence targets. The tester's semantic checkpoint is a positive contrast, not a replacement for those unchanged generic captions.
- V10 remains partial. This followup did not change launch naming or purpose metadata.
- R02 remains not fixed, with After ownership and PASSED hook status retained. N01's verbose-caption preview warning is also retained; neither is reclassified by recovery or performance work.
- Whitespace-only/boundary-whitespace assertions, repeated-value headers and FATAL presentation remain unavailable-sample coverage boundaries for these launches. No dedicated fixtures were generated or inspected. Native HTML UI widening was explicitly excluded; the intentional RP-only failure-PNG tradeoff remains documented.
- Existing launch output does not verify a later source head, performance fix, original exception/PNG bytes, benchmark result, or general regression freedom. No outage-based product verdict was added.

## Inventory and Cleanup

There are **72 saved screenshots: 57 original plus 15 post-recovery**, including the qualified E061 attempt. Post-recovery IDs are E059-E073; E058 remains absent. Original screenshot files, `captures.json` and `record-ids.json` are preserved unchanged. The [validation record](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/validation.json) checks all saved image dimensions/markers/hashes and new record associations against the original saved item-scoped inventory.

**Temporary viewport reset completed** at 2026-11-02T12:37:19.983Z. The restored browser reported 1504x710 at DPR 2, rather than the review override. See [viewport-reset.json](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/visual-review/viewport-reset.json). No additional visual observation is required for the three requested priorities. Remaining items above are explicit scope/provenance boundaries, not queued UI checks.
