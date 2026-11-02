# SDK 2.0.2 independent API usability recheck checklist

Prepared 2026-11-02 before IDs were available. Execution gate was subsequently opened by Master; the original checklist below is retained as the precheck record. Final live-review dispositions and evidence are in [api-review.md](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/api-review.md). No Cucumber executions were performed by this reviewer.

## Execution gate and boundaries

- Wait for Master's final candidate SHA and the new Launch IDs, identifying plain, rich, and the unchanged copied API-tester cases. Do not substitute old Launches or discover a candidate by guessing which run is newest.
- Record the supplied SHA and the evidence that connects each Launch to that candidate. Recheck public docs if their content changes after preparation; a documented promise is not runtime proof.
- Write all review artifacts only beneath `/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/`. Only the review-directory path has been created; trial source remains Master's responsibility.
- Do not read other reviewers' reports, linked historical evidence, SDK implementation, or implementation tests. Do not modify SDK files or original/copied consumer features, helpers, assertions, or configuration. Do not commit, push, tag, or release.
- Permitted consumer features/helpers can be read after Master prepares the trial to establish scenario identity and unchanged assertion intent. No extra scenario execution or source changes are part of this preparation.
- After the gate, use an own CUA browser tab at `http://rp-2607.localhost:18080`, project `superadmin_personal`, with the existing authenticated session. Inspect native/browser reports through observed UI only. Do not infer displayed behavior from API text.
- Use only read-only RP API calls for exact evidence IDs and persisted content. Invoke the authorized opaque `/private/tmp/rp-trial-env-20261101.rb` launcher for child key injection; never read its contents, credential files, print the key, dump the environment, or capture authorization headers.

## Original findings to recheck

The six findings below come only from my original [API tester report](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.1/reports/api-tester.md). Its linked evidence files have not been opened. Old IDs are anchors from that report, not new verification.

### API01 Automatic exception evidence disappears

Original severity/classification: S2, client output defect; internal cause not established.

Old anchors: plain Launch 3837, scenario 30988, step 30991, comparison 20176, omission 20177; second scenario 30993, step 30996, comparison 20188, omission 20189. Rich Launch 3839, scenario 31138, step 31141, comparison 20407, omission 20408; second scenario 31143, step 31146, comparison 20419, omission 20420. Positive control: own Launch 3842, step 31225, retained exception 20509.

Recheck both original synthetic failures in plain and rich, plus the unchanged own Hash-comparison failure. Confirm actual failed status and useful automatic exception class, message or explicit withholding reason, and safe source/backtrace. Inspect Log View and Stack Trace, not only comparison cards. If safe frames return but the ordinary synthetic message remains withheld, record that limitation explicitly and decide whether the original issue is only partly fixed. Do not count an explicit comparison as restored automatic exception evidence. Do not demand disclosure of unsafe data.

Required evidence: new Launch/scenario/step IDs, comparison and automatic-exception log IDs, persisted log text, default Log View and Stack Trace screenshots. Record exact retained and withheld fields. Status: PENDING.

### API02 Small object comparison clips the actual value

Original severity/classification: S3, RP UI limitation aggravated by multiline client layout.

Old anchors: own Launch 3842, scenario 31223, step 31225, assertion 20508, delta attachment 4956.

Recheck the unchanged four-field expected versus three-field actual object at a recorded viewport, first without expanding the log. Determine whether the missing `difficulty` key is now immediately identifiable and whether actual values still require expansion. Capture before and after expansion. Distinguish a useful new key-summary mitigation from elimination of the original clipping; do not label a clipped actual value fixed without explaining the remaining interaction. Verify values remain available and accurate after expansion.

Required evidence: new Launch/scenario/step/assertion IDs, related attachment ID if present, persisted comparison, paired initial/expanded screenshots. Status: PENDING.

### API03 Passed negative test advertises an assertion failure

Original severity/classification: S3, consumer example/test code, not incorrect status propagation.

Old anchors: plain Launch 3837, scenario 30920, expected-400 HTTP log 20057, step 30925, false assertion 20062; rich Launch 3839, scenario 31070, HTTP log 20288, step 31075, false assertion 20293.

Inspect the equivalent expected-400 scenario in both presentations. Confirm the real assertion still checks the expected business result, the scenario passes, and the HTTP exchange stays INFO. Determine whether the optional observation is now an ordinary diagnostic rather than an ERROR or misleading failure card. Explain any removed or separated demonstration; removing the business assertion is not a fix. Inspect error counters and Log View together.

Required evidence: new Launch/scenario/step IDs, HTTP and optional diagnostic log IDs (or bounded evidence of absence), scenario status, error-counter and card screenshots. Status: PENDING.

### API04 One HTTP response is logged twice

Original severity/classification: S3, consumer example/test code, not demonstrated duplicate SDK delivery.

Old anchors: plain Launch 3837, step 30904, HTTP 20022 and response snapshot 20023; rich Launch 3839, step 31054, HTTP 20253 and snapshot 20254. Nonduplicating controls: own Launch 3842, steps 31220/31224, HTTP logs 20497/20504.

Inspect one equivalent passing POST exchange per presentation and the unchanged own cases. Count relevant logs under the request action across all applicable levels and pages. Confirm a complete single HTTP card, without another full response snapshot for the same observation. Preserve meaningful separate assertions, input DocStrings, and field deltas; those are not duplicates merely because they share values. Check that simplification did not remove request or response context or move evidence to the wrong action.

Required evidence: new Launch/scenario/action IDs, complete relevant log-ID list, request/response card screenshot, and any duplicate row screenshot. Status: PENDING.

### API05 HTTP preview limits are not operationally specified

Original severity/classification: S3, documentation-only finding; no prior large-payload experiment.

Check the final-candidate getting-started, best-practices, and configuration guides for an explicit HTTP-specific threshold, shared versus per-section budget, truncation marker, and full-body attachment guidance. Distinguish `AppLog.http` from `rp_attach`. Check whether the requested small truncated-output example is actually supplied, rather than silently treating a threshold alone as the entire requested improvement.

Preparation observation, not final disposition: current best-practices states shared 16 KiB / 100 lines across bodies and headers, redaction before clipping, response-first RP ordering, `[preview truncated]`, and no automatic full-body attachment.

Required evidence: final SHA, exact document line references and short excerpts; capture the relevant document UI if a screenshot is needed for the report. Launch/item/log IDs are N/A for the documentation-only finding. Any supplied large-body runtime case is separately identified and requires its own IDs/screenshots; no boundary test is implied by reading docs. Status: PENDING.

### API06 Ambiguous version and internal terminology

Original severity/classification: S4, documentation.

Check the final-candidate guides and README for unexplained `AppLog 1.3.1` and `pre-Ledger baseline`, and for replacement wording that is understandable to an ordinary API tester. Confirm that the SDK candidate version is distinguished from independent Chart/ReportPortal versions. A legitimate infrastructure version is not stale AppLog wording. Follow only permitted public-doc references, not implementation or historical-review links.

Required evidence: final SHA, exact document lines/excerpts and focused term-search results; document UI capture where useful. Launch/item/log IDs are N/A for this documentation-only issue. Status: PENDING.

## Owner constraints and additional checks

- R02 is explicitly unresolved/not fixed by owner Decision 27. Preserve After ownership and passed hook status; a new warning does not fix filtering. If supplied Launches include the screenshot case, record the exact Hook/log/attachment IDs and paired screenshots with `Hide all passed logs` on/off. If not supplied, state runtime verification is outside this API evidence set rather than inventing coverage.
- The current example deliberately replaces the native HTML failure PNG with one RP caption-and-PNG entry under After. Treat this as an approved routing tradeoff, not an accidental regression or a fix to R02. Check the single RP entry, unique retained local PNG, original exception and native failure records where authorized evidence is available. State the native screenshot loss plainly in adoption advice.
- Recheck the documented ERROR/FATAL plain-versus-rich presentation contract on comparable observed messages. Stack Trace must remain usable. Do not claim byte equality from screenshots, or compare whole logs with differing run-specific data as if they were identical inputs.
- Inspect response-first HTTP cards for retained URL, method, expected/actual status, timing, request/response bodies, one header value per line, and readable media type. Expand rich headers to verify they are accessible.
- Inspect supplied empty/whitespace assertion cases and JSON-key summaries if present. Keep unsupported or absent cases explicitly not exercised; do not silently replace immutable tester cases.
- Preserve previously useful behavior: real assertions drive status, request evidence belongs to When and assertions to Then, expected 400 stays INFO, native log/JSON attachment forwarding remains usable, and action/hook items do not inflate test counts.
- Revisit the original minor onboarding friction: arithmetic smoke plus GET recipe still needs adaptation for a meaningful API-only POST/PUT example. Do not turn estimated human setup time into a measured result or claim a fresh installation occurred.
- Log new issues independently with severity, client/example/docs/UI classification, reproducible observed steps, exact evidence IDs, screenshots, user impact and uncertainty. Do not infer internal causes.

## Evidence and final disposition rules

For every runtime observation, record candidate SHA/provenance, presentation, Launch ID, scenario ID, action/hook ID, log ID(s), attachment ID(s), UI URL, capture time, viewport, level filters, passed-log filter, expansion state and screenshot path. Save authorized API response snapshots only inside this review folder; never include credentials. Evidence of absence requires complete relevant pagination/filter scope, not a single screenshot.

Each original issue receives one final label: FIXED, PARTLY FIXED, or NOT FIXED, with residual limitations. Until evidence is sufficient, retain PENDING or NOT VERIFIED rather than forcing a green result. Keep documentation-only evidence distinct from runtime evidence and mark inapplicable IDs N/A.

The final adoption decision is independent: adopt, limited adoption with explicit safeguards, or do not adopt for the evaluated API workflow. Base it on diagnostic trust, remaining severity, evidence discoverability and native/RP tradeoffs. No delivery completeness, privacy, fresh-install, retry, parallelism or boundary certification is implied by this usability recheck.

## Preparation inputs

Substantive review inputs read: own original report; SDK README; getting-started, best-practices and configuration in full; public advanced-reporting presentation/report-structure and failure-evidence/helper sections; Decision 27 and its R02/WP2 clarifications. A heading/keyword scan of public migration documentation was also used. No linked historical reports, old evidence files, consumer source, SDK implementation, or implementation tests have been read for this preparation.

These are pre-final local document snapshots, not Master's final candidate attestation. SHA-256 fingerprints at preparation:

| Input | SHA-256 |
| --- | --- |
| Original api-tester.md | `143535de22602c46f698d0eb6cdaa7d3a2c836535beac1bd1f7a8d7cfe98f475` |
| SDK README.md | `799e2323488d71db1b5141c4a2fd36062e3bbdcd842cb392c7dec50458cac690` |
| docs/getting-started.md | `66c7998f38187bb1eb07576a674ca5bfd805bc76b2dd9b006fcac76d633ef7d2` |
| docs/best-practices.md | `b8ec747475724f84fdc44668bd9fdbfde20ca31d6b1ccc9e4419d3b19d8d5739` |
| docs/configuration.md | `a409779b60f8d1e2ae3083197fe573b85f581b7320f9ebbf77db0272ef7a7389` |
| docs/advanced-reporting.md | `e2f30fa1d04ea4cbaaccde7d6a7fbf941ad764014b3fa2a3bf6b80d9688d2725` |
| docs/design/presentation-ledger-owner-decisions.md (whole-file fingerprint; substantive read limited to Decision 27) | `67083c3b911ca86be1ffcba7565832c800bd7302c41519301d94cb46b840fa56` |

## Handoff fields

- Live-capture SHA supplied by Master: `9bf3356cff350d8e2ba11bad1c33aa89881ac456`.
- Subsequent final source head: `d1725d3ab9e796c008fe9e80a11ea0ce29bde762`. Master attests runtime/examples/Gemfile/gemspec unchanged; only CI and one integration assertion changed. No independent implementation inspection or new-head execution is claimed.
- Plain Launch ID: 3849; rich Launch ID: 3851.
- Unchanged copied API-tester Launch ID: 3847.
- Narrow R02 check: UI plain Launch 3850.
- Candidate-to-Launch provenance: Master attestation plus observed attributes/runtime paths; no independent archive-to-SHA attestation.
- Live inspection: completed for the report's stated scope; native HTML UI blocked by browser URL policy.
- Original dispositions: API01/API02 partly fixed; API03/API04/API05/API06 fixed, with stated limits.
- New observation: N01 small HTTP request body hidden behind generic log expansion; no proven new regression.
- Adoption: limited adoption with retained native/local evidence; not unconditional approval as sole failure record.
- Offline completion: original evidence preserved and validated; report conclusions unchanged. No API/browser/capture activity resumed after the pause, and live follow-up remains gated on Master's health clearance. No conclusion about the reported outage or its recovery is made.
