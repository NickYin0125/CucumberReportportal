# Source QA: M3B stable identity migration fixture

This fixture is for the M3B identity acceptance work, not a general-purpose example. The paired Gherkin sources in `spec/fixtures/m3b/` have the same cases and values, but the second inserts an unrelated line and reverses Examples header order. For source fallback comparison, run each variant sequentially by overwriting one temporary feature file at the exact same URI. They exercise an explicit `@tms:` ID, a source-derived case, two dataset rows, and a fail-once native retry.

Use this fixture when investigating identity behavior from a source checkout; it is not part of consumer installation. Keep `RP_IDENTITY_NAMESPACE` identical across workers that should share history. Start with `RP_IDENTITY_STRATEGY=legacy` (the default), compare emitted payloads, and review the [identity migration contract](../../docs/design/reporting-experience-m3b-implementation.md) before opting into `stable_v1`.

In `stable_v1`, `RP_TEST_CASE_ID` and `@tms:` values are identity seeds; ReportPortal receives an opaque `rp:stable-v1:<digest>` `testCaseId`, not the literal TMS value. Do not assume the UI can search by that raw seed. Human-readable [Scenario attributes](../m3c_attributes/README.md) and [links](../m3c_links/README.md) are implemented as separate opt-ins; neither replaces the identity contract. Stable-v1 sorts canonical wire parameters, but does not reorder M3A display names or source Examples/DataTable columns.

Use Cucumber progress/pretty output and give the RP formatter a separate output path. The earlier native HTML/message failure recorded for this fixture lane preceded the SDK's expressions `<19` dependency cap; it is a historical control, not a current prohibition on native reports. Use the supported Bundler resolution described in [getting started](../../docs/getting-started.md). Native `BeforeAll` can abort before formatter construction; it is not evidence for a fabricated `BEFORE_CLASS` item. Local captures verify payloads, while real RP history grouping/retry statistics/UI require their own checks.

From **the SDK source checkout root**, with its development bundle installed:

```sh
bundle exec rspec spec/reportportal_cucumber/service/scenario_identity_spec.rb \
  spec/reportportal_cucumber/cucumber/m3b_formatter_spec.rb \
  spec/reportportal_cucumber/cucumber/m3b_integration_spec.rb
```

Expected: the identity unit/formatter/native integration examples pass for a healthy checkout; these specs do not require a real RP service. The `spec/` fixtures are source QA and are not shipped as consumer prerequisites.
