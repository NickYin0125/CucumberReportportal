# Cucumber 12 Release-Line Architecture

Status: locally accepted SDK 2.0.0 candidate on 2026-10-31. Remote CI and external release publication remain separate gates.

## Release Boundary

- `maintenance/1.x` starts at the immutable `v1.3.1` commit, `4ca2f770e0a84e83688f165ba04b4db8ef855cf9`. Its Ruby >= 3.1 and Cucumber >= 9, < 11 contracts remain unchanged. Cucumber 11 is not silently added to the supported legacy range.
- `codex/cucumber-12` prepares SDK `2.0.0`, Ruby >= 3.3, Cucumber >= 12.0.1 and < 13. Existing tags and `main` are not rewritten.
- The SDK and Helm chart are independently versioned. This adapter migration does not require a new ReportPortal deployment: the chart remains 1.3.1 targeting ReportPortal 26.0.7.
- Build and installation verification precede any new stable tag or external release. A green local run is not evidence that a remote Ruby-version matrix has passed.

## Runtime Contract

Use the actual Cucumber 12 event and message implementations as the contract, not assumptions inferred from earlier formatter callbacks. Cucumber 12 uses core 20, query 16, and the unified `Cucumber::Core::Event::Base`; native World `log` and `attach` are delivered through events. The reporting plugin must consume each native record once, preserving both the active step/hook and retry attempt.

ReportPortal's verified wire topology is retained:

```text
Launch (dedicated launch API, not an item type)
  Feature: SUITE, hasStats=true
    Rule: SUITE, hasStats=true (when RP_RULE_SUITES=true and present)
      Scenario / expanded Example: STEP, hasStats=true
        Gherkin action / hook / manual group: hasStats=false
          Logs and attachments
```

"Test" in user-facing documentation is a logical scenario, not permission to change the ReportPortal scenario item to `TEST`. Parentage is expressed through the existing ReportPortal child-item endpoint; no invented `itemParentId` JSON field is introduced.

## Outcomes and Ownership

- Failed, undefined, pending, and ambiguous execution outcomes fail reporting without Cucumber's removed `strict` option. Skipped and interrupted outcomes retain their distinct reporting semantics.
- Failed attempts retain their own UUIDs, logs, and attachments. A final successful retry determines the scenario's effective outcome; earlier attempts must not poison the suite/launch result. Exhausted `--retry-total` must terminate without inventing another attempt.
- Hook evidence must remain on the executing hook or action. Native run-level hooks cannot be assigned fabricated Feature ownership if the runtime emits no such relationship. Teardown errors and original business exceptions remain observable.
- `ParallelFormatter` uses an externally created `RP_LAUNCH_UUID`. Workers own their item trees and queues, but never create or finish the shared launch. The CI/orchestrator waits for every worker and then finishes it. Unsafe automatic distributed completion is not added as part of a runtime upgrade.
- Stable identities, attribute/link sanitization, evidence redaction, bounded admission, delivery receipts, spool persistence, and replay ownership remain existing public contracts.
- Native evidence without resolvable ownership is rejected before media decoding, counted in the delivery receipt, and diagnosed once per formatter. A worker thread does not inherit another thread's active action or global-hook scope. Native HTML/messages reporting belongs on the execution thread; worker-produced RP evidence can use an explicitly captured open target and must finish before that action closes.

## Acceptance Gates

1. Dependency resolution and independent installation of legacy 1.3.1 and target 2.0.0, including rejection of incompatible Cucumber/Ruby versions.
2. Full RSpec and offline Cucumber suites on actual Cucumber 12.0.1+, with no unhandled thread exceptions or weakened assertions.
3. Real Cucumber CLI fixtures for normal/failed/undefined/pending/ambiguous execution, all supported hooks, Background, Rule, Outline with multiple Examples, DataTable, DocString, native logs, and binary attachments.
4. Retry and multi-process tests inspect actual outgoing HTTP payloads, multipart bytes, temporal ordering, distinct attempt UUIDs, and final ownership. HTTP mocks do not substitute for the Cucumber runtime.
5. Release tooling validates both release-line ancestry and independently versioned artifacts. CI covers the real legacy source as well as the new source, rather than forcing incompatible gem constraints into one checkout.
6. Migration documentation distinguishes local evidence, CI configuration, remote CI results, real ReportPortal checks, and deferred release publication.

## Primary Sources

- [Cucumber Ruby 12.0.1 changelog](https://github.com/cucumber/cucumber-ruby/blob/v12.0.1/CHANGELOG.md)
- [Published Cucumber 12.0.1 gem](https://rubygems.org/gems/cucumber/versions/12.0.1)

## Local Architecture Acceptance

The architect reviewed the final source against the [independent QA evidence](../reviews/2026-10-31-cucumber-12-acceptance.md). All 37 SDK Ruby source hashes match the measured final core. The dependency architect separately reviewed the adapter without editing it, found a joined-thread ownership defect, and confirmed its fix with independent bounded probes. No unresolved P1/P2 findings remain in that review scope.

| Gate | Observed result |
| --- | --- |
| Ruby 3.4.2 / Cucumber 12.0.1 | 929 examples, zero failures, zero pending; 7 Cucumber scenarios / 21 steps passed |
| Ruby 3.3.12 / Cucumber 12.0.1 | 929 examples, zero failures, one pending Compose-CLI availability check; 7 Cucumber scenarios / 21 steps passed |
| Immutable 1.3.1 / Cucumber 10.2.0 | 889 examples, zero failures; 1 scenario / 3 steps passed |
| Immutable 1.3.1 / Cucumber 9.2.1 | 889 examples, zero failures with the disclosed version-neutral test driver; 1 scenario / 3 steps passed; production hashes unchanged |
| Native event and outgoing HTTP contracts | 25 dedicated real CLI cases passed, including retries, hooks, binary ownership and two real worker processes |
| Packaging | Legacy and target gems independently built and installed; target archives match all 37 final core files |

This sign-off covers the stated local compatibility boundary, not a fresh live ReportPortal or infrastructure certification. The Linux Compose availability skip is covered by the passing native suite, not represented as an executed Linux check. Coverage scope and the small in-process percentage decline are disclosed in QA's report; no whole-repository or 100% coverage claim is made.

The source, migration guide, release notes, and local packages can now be prepared for review. Do not move `v1.3.1`, merge the incompatible runtime into the legacy line, or publish `v2.0.0` before the approved remote CI matrix passes. The frozen legacy branch needs a separately reviewed CI/release-tooling backport before a future 1.x maintenance publication; testing that baseline from this branch does not retrofit its old publisher.
