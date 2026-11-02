# M3C Scenario Attributes Contract

Status: implementation and local mock acceptance **PASS**; later physical
ReportPortal acceptance **PASS (2026-10-08)** is recorded in the
[live verification record](reporting-experience-m3c-live-verification.md).
This slice adds only opt-in business attributes to
statistical Scenario items. It does not change
Suite, action, hook, launch, identity, retry grouping, logging, links, finalization,
or status behavior. With the feature disabled, the existing API normalization
continues to send `attributes: []`.

## Configuration

The defaults are `scenario_attributes_enabled: false`, allowed keys
`component,team,owner,layer,priority,browser,tms`, and an empty attributes list.
The matching environment variables are `RP_SCENARIO_ATTRIBUTES_ENABLED`,
`RP_SCENARIO_ATTRIBUTE_KEYS` (comma-separated), and `RP_SCENARIO_ATTRIBUTES`
(JSON object or array of `{ "key", "value" }` entries). YAML and profile keys
follow the same names. Existing configuration precedence is unchanged. An
explicit empty allowlist is valid. Structural configuration errors such as
malformed JSON fail during configuration loading with a generic error.

## Resolution

`Service::ScenarioAttributes.build(defaults:, tag_scopes:, allowed_keys:,
explicit_id: nil)` returns detached, deeply frozen attributes and safe
diagnostics. Scoped tags are AST-derived for Feature, Rule, Scenario, and the
executed Examples row. Resolution order is defaults, Feature, Rule, Scenario,
Examples; output sorts by key. Identical duplicates collapse. Conflicting valid
values at one scope ignore that key for that scope, preserving a lower-scope
value when one exists. Invalid entries are skipped without suppressing valid
inherited values.

Only allowlisted `@key:value` tags are business attributes. Keys are normalized
lowercase and must be simple ASCII identifiers; operational, system, and
credential names are prohibited. Values are stripped, non-empty valid UTF-8,
at most 512 characters, and contain neither colon nor ASCII control characters.
Invalid tags and values are never included in diagnostics. If source scope data
is unavailable, use defaults and the effective explicit ID only, with a safe
missing-source diagnostic; do not infer scope from flat event tags.

`tms` is derived-only. The formatter passes the exact effective explicit ID it
already selected for identity (environment override first, then its existing
scenario tag selection). Existing `@tms:` identity tags still select the seed
under the unchanged M3B rules. The attribute mapper does not independently
reselect that seed from scoped tags or configured `tms` values. The reported
attribute value is subjected to the ordinary value policy.

## Acceptance Boundary

The local integration captures actual API requests from isolated Cucumber
subprocesses backed only by WebMock. It compares disabled, enabled, and
attribute-mutated fixture runs at the same URI and source-line layout under both
legacy and stable identity modes. Assertions cover attributes on Scenario items
only, identity/name/parameters/retry invariance, inheritance and conflict
resolution, TMS precedence, retry execution UUIDs and attempt-owned logs, and
safe diagnostics. The permissive mock's summaries are not an oracle. These
local mock gates alone do not establish physical ReportPortal or live UI
acceptance; the later physical PASS is recorded separately in the
[live verification record](reporting-experience-m3c-live-verification.md).
