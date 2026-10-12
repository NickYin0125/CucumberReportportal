# Changelog

## 1.2.0 - 2026-10-12

### Reporting Experience

- Preserve severity across AppLog's terminal, native Cucumber and ReportPortal routes; support explicit report delivery and bounded, credential-redacted HTTP exchanges.
- Add structured assertion and caller-supplied failure evidence with explicit step/attempt ownership, without owning the browser or replacing the original failure.
- Parse Feature, Rule, Scenario, Background and Examples metadata, including localized keywords, Markdown DataTables and DocStrings.
- Add opt-in stable scenario identities, safe attribute mapping, and source/CI/TMS links while retaining the verified `SUITE -> STEP(hasStats=true) -> STEP(hasStats=false)` UI contract.

### Delivery And Safety

- Bound queued records, bytes and batches; expose completion barriers and receipts that distinguish business results from reporting completeness.
- Add durable spool transactions, artifact validation, quotas, checkpoints and controlled original-target replay, with documented ambiguity and duplication limits.
- Harden context ownership, capture closure, native BeforeAll/AfterAll observation, redaction, attachment collisions, TLS verification and sanitized video-upload degradation.
- Default to independent worker launches; use `RP_LAUNCH_UUID` for CI-owned shared-launch lifecycle rather than treating local file join as a distributed completion barrier.
- Constrain Cucumber to `>=9,<11` and cucumber-expressions to `>=17,<19`, preventing the observed Cucumber 10 native HTML/message incompatibility with expressions 19.

### Examples And Deployment

- Include an independent installed-gem API and Playwright 1.62 example with healthy and intentionally failing scenarios, native report inspection and optional live RP reporting.
- Validate the current runtime against ReportPortal 26.0.5; the companion Helm `1.2.0-rc.2` pins official chart 26.8.12 and includes isolated local/external-Secret deployment profiles and RabbitMQ vhost bootstrap correction.
- The Helm chart remains a deployment candidate. Its legacy public video policy permits anonymous writes/deletes and is not production-safe; the production fresh-install example disables that extension. Publishing the SDK does not certify that policy or an in-place database migration.

### Distribution

- Distribute the installable gem and companion chart through the GitHub `v1.2.0` release. RubyGems.org publication is a separate authenticated step, not implied by a GitHub release.
- No zero-loss/exactly-once, Cucumber 11, complete Ruby-version matrix, or production HA claim is made. Video recording/finalization stays in the caller's framework.

## 1.1.0

- Introduced Triple-Track Smart Logger, MinIO upload degradation and the 30-day video lifecycle initialization policy.

## 1.0.0

- Initial published gem with Cucumber reporting, BDD hierarchy alignment and the optional S3/MinIO Markdown video route.
