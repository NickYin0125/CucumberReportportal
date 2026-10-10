# M3B implementation and migration contract

Status: **PASS (2026-10-07)**. The acceptance contract and implementation source are frozen; local gates, real ReportPortal API gates, and Master's physical UI acceptance passed. M3B is limited to explicit scenario identity strategy and migration behavior. It does not change the reporting topology: `SUITE(hasStats=true) -> STEP(hasStats=true) -> actions/hooks(hasStats=false)`. M3C attributes/links, media, queues, CI shared launch, and deployment changes are out of scope.

## Identity strategies

`RP_IDENTITY_STRATEGY=legacy` is the default. It preserves the exact pre-M3B `testCaseId` and `uniqueId` values and existing parameter behavior: an explicit `RP_TEST_CASE_ID` or `@tms:` value remains the literal base ID, with the legacy parameter suffix when parameters are present. `RP_IDENTITY_STRATEGY=stable_v1` is an explicit opt-in. `RP_IDENTITY_ROOT` defines the checkout root used to make source URIs relative; `RP_IDENTITY_NAMESPACE` is optional and must be held constant across CI workers that should share history.

In `stable_v1`, an explicit ID is a **seed**, not the ReportPortal wire ID. `RP_TEST_CASE_ID` takes precedence over a scenario tag such as `@tms:CASE-42`; either seed is included in identity calculation, but the wire `testCaseId` is the opaque string `rp:stable-v1:<sha256-digest>`, not the literal `CASE-42`. The `uniqueId` is a separate domain-separated SHA-256 digest. Without an explicit seed, use the source URI relative to `RP_IDENTITY_ROOT`, the Rule name, and the source Scenario/Scenario Outline name before Examples substitution. Do not include source line numbers.

Because the explicit seed is not sent as the wire `testCaseId`, users must not assume the ReportPortal UI can find a stable-v1 case by searching for its raw TMS value. That search behavior is unverified; M3C human-readable attributes/links are not implemented by this milestone.

If AST identity cannot be resolved, or the same Rule contains ambiguous duplicate source scenario names, emit a warning and fall back to legacy identity for that case. Do not silently invent a stable source key.

Stable-v1 parameters are sorted by canonical key/value before wire serialization and hashing. Scalar values use their wire strings; nested values use normalized JSON. Canonicalization must not mutate caller-owned inputs. Every reported parameter participates in identity and remains in the ReportPortal parameter payload. This contract does not promise to exclude volatile values. A changed dataset value is a distinct identity. This canonical wire order does not change M3A display names or the source order of Examples/DataTable columns in the existing rendered reporting content.

## History migration

The legacy default is deliberately unchanged so existing installations continue their current history behavior. Enabling `stable_v1` can begin a **new ReportPortal history baseline**: this client does not rewrite, merge, backfill, or migrate prior server records. Rolling back to `legacy` resumes the old identity scheme; it does not merge stable-v1 records into legacy history.

Pilot with explicit IDs and canonical business parameters. Freeze the namespace across workers and environments intended to share history. Line insertion, Gherkin formatting, and Examples header reordering should not change a stable-v1 ID. Renaming a source URI, Rule, or source Scenario name changes fallback identity; use an explicit ID when those names must be freely changed. Identical rows with identical names may be treated as retries by ReportPortal rather than independent cases; provide distinct explicit IDs when they represent distinct cases.

Before rollout, compare captured API requests in both strategies, then validate server-side grouping and history in a real ReportPortal project. Do not infer server behavior from equal client IDs or from the permissive WebMock server's launch statistics.

## Retry-aware Suite outcome

For `stable_v1`, the Suite finish status must aggregate the latest outcome per ReportPortal test-case group, not every execution attempt. A failed attempt followed by a passing retry must not leave the Suite failed. A class-hook failure represented in the SDK protocol remains a Suite-level failure and must still fail the Suite even when all scenario groups' latest attempts pass. The legacy strategy is unchanged. Preserve logs from the original failed attempt, associated only with that attempt; aggregation changes outcome selection, not evidence retention or execution UUID uniqueness.

Cucumber 10.2.0's Ruby `BeforeAll` runs in `Runtime#run!` before the report visitor is initialized and before feature compilation emits `test_run_started`; its message hook type is `BEFORE_TEST_RUN`, not a per-feature `BEFORE_CLASS` event. A native `BeforeAll` exception can abort before launch/scenario events, so this fixture does not claim to verify a reported class-hook item. Class-hook failure behavior is covered only through the SDK's synthetic event/protocol unit lane unless a supported native event path is independently demonstrated.

## Acceptance boundary

The independent local gate compares actual outbound API payloads from subprocess Cucumber runs against two semantically equivalent fixtures written sequentially to the exact same temporary feature URI, with unrelated line insertions and reversed Examples header order. It verifies legacy wire semantics, stable identity invariance, changed-row distinction, canonical wire parameters, environment-ID precedence, execution UUID uniqueness, retry request shape, and retention of the failed-attempt log on its original attempt. Native message/HTML formatters are excluded because the recorded Cucumber 10.2.0 control fails in `MessageBuilder`; use progress/pretty output and keep the ReportPortal formatter output separate.

The local stateful mock can capture request bodies and ordering. It is **not** a certification of server retry grouping, TestCaseHash, history, Suite latest-attempt aggregation, or UI statistics. Live acceptance used two sequential launches across fixture variants, server-returned `testCaseHash` inspection, one native retry grouped under the same test case with fresh execution UUIDs and correctly isolated logs, Suite finish status matching the latest outcome of every RP group, server statistics counting latest attempts only, and Master's in-app UI acceptance. Original failed-attempt logs remained inspectable server-side. Native Cucumber `BeforeAll` is not used as class-hook reporting evidence in this lane. See the [M3B verification record](reporting-experience-m3b-verification.md) for the final evidence and limits: the live run loaded frozen source, the installed-gem smoke was separate, Cucumber 9.2.1 received focused integration coverage only, and no physical legacy-to-stable baseline comparison or native HTML compatibility claim was made.
