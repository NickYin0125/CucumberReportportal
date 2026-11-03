# Maintenance 1.3.3: Selective 2.0.2 Backport

Status: implementation and independent acceptance, not a release authorization.
Baseline: released SDK 1.3.2 (`19174a5`). Reference: released SDK 2.0.2
(`29ce2a4`). Implementation branch: `codex/readability-backport-1.3.3`.

## Boundaries

This remains a separate Ruby >=3.1 / Cucumber >=9,<11 maintenance line. Review
the 2.0.1-to-2.0.2 fixes, not the entire difference between the two major lines.
Do not import Cucumber 12 events, result mappings, compound-step support,
dependency requirements or formatter lifecycle changes.

Decision 19 continues to govern native 1.x failure logs: preserve the message
and every backtrace frame v1.3.1 sent, with presentation escaping only and the
original fallback. Do not activate the unused FailureRedactor on this path.
The opt-in HTTP/evidence sanitizers receive the encoded-credential fixes; raw
caller AppLog messages are not newly sanitized.

No topology, retry identity, attachment ownership, explicit description,
attribute inheritance, queue or launch-completion policy change is intended.
Helm remains 1.3.1. This task does not merge protected branches, tag, publish,
deploy, pause services or reinterpret prior QA as a new execution.
The owner authorized pushing the feature branch and opening a draft PR after
acceptance, so the four-cell remote CI can run. This does not authorize merging
or publishing 1.3.3.

## Work And Acceptance

| Slice | Backport | Acceptance |
| --- | --- | --- |
| Automatic sanitization | Malformed and encoded URL components, encoded Bearer and residual mask-prefix secrets | Original synthetic repros plus safe controls; HttpExchange and EvidencePresenter outputs have no residual credential; raw AppLog unchanged |
| Failure readability | ERROR/FATAL plain output in both presentation modes | Complete messages, full-message continuations and every raw frame retained on 1.x; no decorative HTML in Stack Trace |
| Assertions and HTTP | Visible empty/edge whitespace, sanitized top-level key deltas, response-first cards and repeated headers | Exact focused assertions, bounded output and unchanged native/terminal payload boundaries |
| Run context | Generated description emphasizes run/build context | Explicit description and attributes untouched; 1.x does not generate a workers attribute |
| Consumer examples | Correct failed-check title, unique screenshots, one caption-plus-PNG RP entry | Standalone example self-tests, real installed-candidate test and original business error preserved |
| Release readiness | Candidate 1.3.3 metadata, four-cell CI and external release dependency installation | Historical changelog/1.3.1 release validation unchanged; wrong identities/checksums still rejected; no actual publication |

R02 is deliberately not claimed fixed: hiding passed logs can hide evidence
owned by a passed After Hook. The consolidated PNG example does not also
attach that PNG to native Cucumber HTML. Explain both limitations to users.

### Additional Decode-Budget Boundary

Manager review reproduced a shared edge in released 2.0.2: four/five layers of
percent encoding exceed the three-pass detector and can retain a credential in
an automatic URL/evidence path. The 1.x port must fail closed when that bounded
decoding budget is exhausted rather than silently accept residual encoding.
Test below, at and beyond the budget, without introducing unbounded decoding.
The published 2.0.2 tag remains immutable; a 2.x corrective patch is a separate
follow-up, not silently included in this maintenance task.

## Independent Validation

1. Freeze a committed candidate before final acceptance. Record source,
   packaged library and dependency hashes, with separate v1.3.2 controls.
2. Run full RSpec and offline Cucumber in all four cells: Ruby 3.1/3.3 x
   Cucumber 9/10. Report actual counts, versions, failures and any pending cases.
   No filtered suite is described as full regression.
3. Exercise fresh plain/rich live evidence on both Cucumber versions at
   `http://rp-2607.localhost:18080`, project `superadmin_personal`. Check failure
   text/frames, HTTP ordering, attachments and After-hook ownership; verify
   relevant escaping, folds and F18 in the real UI. Use synthetic secrets only.
4. Compound DocString-plus-DataTable and native global-hook item names retain
   their established 1.x N/A boundaries; do not fabricate framework support.
5. Compare matched normal rendering/evidence costs with v1.3.2. Report encoded
   adversarial URL costs separately: unsafe historical passthrough is not a
   valid correctness-equivalent performance baseline. Do not pause services
   without separate permission or turn a noisy diagnostic into a formal pass.
6. Independent reviewer reports findings and ACCEPT/NOT ACCEPT with evidence.
   The manager reviews the diff, resolves blocking defects and checks final
   source identity. Release/promotion requires a subsequent explicit decision.

## Ownership

Security developer owns EvidenceRedactor and its tests; presentation developer
owns renderers/callers/examples and their focused tests; integration developer
owns version/docs/packaging/CI; the independent tester owns QA harness/evidence.
All are requested as `gpt-6.1-sol` with `xhigh` (extra-high) reasoning. The
manager owns integration, scope control and final review. Evidence belongs on
`qa/readability-1.3.3`, not inside the delivered SDK's runtime.
