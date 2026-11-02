# SDK 2.0.2 Independent UI Re-review: Preparation

Prepared 2026-11-02, approximately 11:49 UTC. This is a preparation record, not a completed re-review or adoption verdict.

## Gate And Independence

- **WAITING:** Master has not supplied the final runtime SHA or new Launch IDs. No live RP checks, API requests, browser interaction, or Cucumber invocation have been performed in this re-review.
- Final runtime SHA, runtime/package identity, plain/rich sample Launch IDs, and Launch ID(s) for the unchanged original tester journeys are pending. None of the 2.0.1 IDs below is new evidence.
- The trial directory did not yet exist during preparation. Only this review's output directory is being populated; no trial source, helper, feature, SDK file, installation, commit, tag, or release is changed.
- Read boundary: own original `ui-tester.md`; new public README/guides; permitted original/new consumer UI features, steps and helpers; Decision 27 and its scope clarifications. Other reviewers' report contents and SDK implementation/tests have not been read. Directory-name discovery is not evidence review.
- The opaque credential launcher has not been opened or executed. Future API inspection is read-only, with credentials injected into a child process only, without printing tokens, headers, environment dumps, or credential-bearing exceptions.
- After the gate opens, use a newly created, independently owned CUA tab at `http://rp-2607.localhost:18080`, reusing the authenticated `superadmin_personal` session. Do not inspect another reviewer's tabs or reports.

## Approved Scope, Not Fixes

[Decision 27](/Users/nick/Documents/crr-2.0.2/docs/design/presentation-ledger-owner-decisions.md:369) governs this recheck.

- **Owner R02 remains not fixed.** Retain the current capture API, After ownership and hook status. A warning about Hide all passed logs is documentation mitigation, not a behavior fix. Do not require Scenario retargeting or a failed After hook.
- **One captioned RP failure PNG is the approved sample policy.** Native HTML no longer receives that failure PNG. The uniquely named local PNG, original business exception/backtrace, and native failure records must still survive. The native omission is an approved routing tradeoff, not a repaired native-evidence feature or a new defect by itself.
- ERROR/FATAL rich decoration and rich backtrace folding are no longer desired under Decision 27. The old preference for rich error folds is not an acceptance criterion. Recheck readability in RP Log View and Stack Trace instead.
- Do not modify original or copied tester features/steps to make the evidence pass. The refresh-persistence scenario remains an intentional business failure, not an SDK defect.

## Original Findings And Recheck Matrix

The sole historical findings source is [my 2.0.1 UI review](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.1/reports/ui-tester.md). All runtime dispositions below are pending; preparation observations must not be reported as verified fixes.

| ID / Original Severity | Historical Baseline | Preparation Observation | Required Recheck And Classification Boundary |
| --- | --- | --- | --- |
| UI-F01 / S2: passed-hook filter hides failure evidence | Launch 3840, scenario 31197, failed Step 31199, passed After 31200; PNG log 20475 / binary 4950; diagnostic 20476. Error count 4 to 1 when filtered. | Explicit warning now appears in root README, getting-started, best-practices and example README. Owner R02 intentionally remains unresolved. | In the new failure scenario, show After evidence with the filter off; toggle Hide all passed logs on, inspect lost expansion/evidence and error count; toggle off and confirm restoration. Record new Launch/scenario/Step/After/log/binary IDs and screenshots of all states. Final behavior disposition remains not fixed if the approved limitation persists; report docs mitigation separately. |
| UI-F02 / S2: shared local failure.png | Launch 3838, After 31040 and 31050; logs 20232 and 20244; binaries 4942 and 4944. Local overwrite risk was code-supported, not an observed parallel race. | New helper builds scenario/checkpoint slugs plus `SecureRandom.hex(4)` rather than one fixed filename. | Inspect at least two failure captures from the new sample run: distinct retained local paths, valid readable PNGs, descriptive RP names, correct owners and separate binary IDs. Do not claim a parallel stress test or observed overwrite unless actually executed. |
| UI-F03 / S2: headline names successful action | Launch 3840: save 31188, assertion 31189, After 31190, logs 20462/20464. Own Launch 3841: refresh 31214, assertion 31215, After 31219, log 20500. | `check_equal` records `@failed_check`; `ui_action` records the last action only after success. Caption titles identify scenario/checkpoint, with the passed action in details. | Open the new punctuation and unchanged refresh-persistence failures. The headline must name `practice status` or `restored practice word after refresh`, not successful save/refresh. Also check the missing-locator action. Capture failed check and After caption together with IDs. |
| UI-F04 / S3: five ERROR entries for one assertion failure | Own scenario 31209: logs 20494, 20495, 20498, 20499, 20500; one actual failure PNG. | Helper now uses terminal-only `AppLog.error(report: false)` and one RP `rp_attach`; no helper `rp_evidence` or routing JSON attachment. This is consumer code intent, not verified delivery. | Count actual new scenario ERROR logs and explain every row; distinguish assertion, original exception and one captioned PNG. Inspect next-error navigation. Confirm no redundant screenshot explanation/diagnostic rows, no duplicate PNG, original failure preserved and one statistical failed scenario. Judge reduced noise, not an unrealistic one-total-ERROR requirement. Record the approved native-PNG omission separately. |
| UI-F05 / S3: empty actual value looks absent | Own Launch 3841, failed Step 31215, assertion 20494; original exception 20495 says `got ""`. | Public advanced-reporting guide promises `"" (empty string)` and labels for boundary whitespace. No SDK implementation inspected. | Inspect the unchanged refresh-persistence assertion in each supplied presentation mode. The actual field must visibly distinguish the valid empty string from missing instrumentation, while the original exception remains intact. Record assertion and exception IDs and screenshot the rendered comparison. |
| UI-F06 / S3: incompatible Cucumber troubleshooting remedy | Original getting-started table recommended Cucumber >=9,<11 and expressions <19 in a 2.x flow. | New table explicitly recommends >=12.0.1, ~>12.0, removes the legacy expressions pin, assigns 9/10 to 1.x and rejects 11. | Re-read the final document after Master identifies the final runtime/doc state. This is a docs-only recheck: Launch/item/log IDs and RP screenshots are not applicable. No installation success claim follows from the corrected prose. |
| UI-F07 / S3: Node prerequisite/reuse uncertainty | Original example README described a previous Node 20+ lab, not a clear floor or compatibility check. | Main README, getting-started and best-practices now state Node >=20 and the 1.62.0 binding / 1.62.1 CLI pairing. Example README still says a supported runtime / previous lab used Node 20+, and reuse instructions do not show a simple compatibility check. | Re-read final consumer docs and distinguish improvement in central guidance from residual ambiguity at the setup/reuse point. Provisional residual, not a final partly-fixed verdict. No fresh-machine install or upstream compatibility validation has been performed. RP IDs/screenshots are not applicable to the docs claim. |
| UI-F08 / S4: attachment viewer loses filename/owner | Own Launch 3841 checkpoint log 20484 opened under generic ATTACHMENT heading. | Descriptive failure names and captions may help the log card, but no RP viewer fix is assumed. | Open both a named passing checkpoint and a failure PNG in the actual new RP UI. Record filename/context on card versus modal, legibility, owner and binary IDs. A better caption is not a fix to a generic detached viewer heading. Capture card and open viewer. |

## Public Evidence Anchors

- [Root README: Node floor](/Users/nick/Documents/crr-2.0.2/README.md:146) and [approved evidence/filter boundaries](/Users/nick/Documents/crr-2.0.2/README.md:165).
- [Getting started: first-report filter guidance](/Users/nick/Documents/crr-2.0.2/docs/getting-started.md:207), [versioned browser prerequisites](/Users/nick/Documents/crr-2.0.2/docs/getting-started.md:223), and [corrected Cucumber remedy](/Users/nick/Documents/crr-2.0.2/docs/getting-started.md:264).
- [Best practices: R02 warning](/Users/nick/Documents/crr-2.0.2/docs/best-practices.md:280) and [alternative single RP-only capture route](/Users/nick/Documents/crr-2.0.2/docs/best-practices.md:330).
- [Advanced reporting: ERROR/rich policy](/Users/nick/Documents/crr-2.0.2/docs/advanced-reporting.md:32), [empty-string representation](/Users/nick/Documents/crr-2.0.2/docs/advanced-reporting.md:42), and [R02/routing scope](/Users/nick/Documents/crr-2.0.2/docs/advanced-reporting.md:295).
- [Example README: remaining prerequisite wording](/Users/nick/Documents/crr-2.0.2/examples/current_sdk/README.md:48), [retained local PNG / native omission](/Users/nick/Documents/crr-2.0.2/examples/current_sdk/README.md:107), and [caption ownership/filter warning](/Users/nick/Documents/crr-2.0.2/examples/current_sdk/README.md:170).
- [Consumer helper: failed-check tracking](/Users/nick/Documents/crr-2.0.2/examples/current_sdk/helpers/world.rb:11), [capture and single RP attachment](/Users/nick/Documents/crr-2.0.2/examples/current_sdk/helpers/world.rb:29), and [unique path generation](/Users/nick/Documents/crr-2.0.2/examples/current_sdk/helpers/world.rb:74).
- [Unmodified original tester journeys](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.1/features/tester_ui/workday_practice.feature:1) and [their step definitions](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.1/features/tester_ui/workday_practice_steps.rb:1).

## Live Review Procedure After Master Handoff

1. Record the supplied final runtime SHA and launch mapping, including presentation mode and the run containing unchanged tester journeys. Confirm copied consumer helpers match the intended final candidate without opening SDK implementation/tests. Keep source/runtime identity distinct from the preparation hashes.
2. Create the independent CUA tab. Navigate explicitly to only the supplied new Launch IDs. Verify scenario totals, outcome and failed Step/After ownership in the UI. Do not use old Launches as proof of the new build.
3. Inspect passing keyboard-correction and saved-before-refresh checkpoints. Open their actual PNG viewers, inspect pixels and context, and correlate UI evidence with targeted read-only item/log records.
4. Inspect punctuation, missing-locator and refresh-persistence failures. Read the original failed Step, expected/actual card, exception/backtrace, After caption and PNG. Check UI readability rather than treating API text as a UI pass.
5. Perform and screenshot the complete Hide all passed logs off/on/off interaction. Record error counts, hook status and whether evidence disappears/reappears. Do not change item status, defect decisions or server settings.
6. Check exact per-owner ERROR/PNG counts and preserved local PNGs/native original failure records. Respect the approved lack of native failure PNG. If original run artifacts are outside the currently permitted read scope, obtain a narrowly scoped artifact handoff before reading them.
7. Re-read docs at the final handoff state. For each of the eight findings, report fixed / partly fixed / not fixed with bounded evidence, or explicitly unverified if the supplied evidence cannot establish a result. Add independently observed new usability issues, not inherited findings from another reviewer.
8. Decide adoption for the bounded everyday serial Cucumber/Playwright use case. Separate open RP limitations, sample-policy choices, docs friction and untested environments. Do not certify fresh installs, retries, parallelism, outages or transport durability from this review.

## Evidence Record Shape

For each runtime check, save under this directory only: check ID, UTC time, supplied runtime SHA, Launch ID, scenario ID, failed/checkpoint Step ID, After ID/status, log ID(s), binary ID(s), presentation mode, UI URL, filter state, observed counts/text, screenshot path(s), and a bounded conclusion. Screenshots must be actually inspected, not merely saved. Planned files are not evidence until created.

Suggested screenshot subjects: launch overview; failed comparison plus original exception; After caption/PNG card; opened checkpoint viewer; opened failure viewer; Hide-passed off/on/restored; plain/rich Stack Trace readability. Read-only API JSON may corroborate identity/counts/ownership but cannot replace the actual UI interactions.

Docs-only findings use exact final file/line references and preparation/final hashes, with RP IDs/screenshots explicitly marked not applicable.

## Pending Handoff And Verdict

Required from Master: final runtime SHA/identity and new Launch IDs with run roles/presentation modes. Also identify the new trial consumer location and permitted run-artifact paths needed to verify local PNG/original failure preservation. No credential material is needed.

**Current result: preparation complete; waiting at the live-check gate. No new Launch/item/log/binary IDs or screenshots collected. No fixed/partly-fixed final classification, no new live issue verdict, and no adoption decision issued.**
