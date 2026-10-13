# Changelog

## 1.3.0 - 2026-10-13

### Day-2 Security And Operations

- Release companion Helm Chart 1.3.0, retaining ReportPortal 26.0.5 and locked upstream chart 26.8.12; the chart and server versions are independent.
- Replace MinIO's unsafe anonymous `public` preset with object-read-only `s3:GetObject`. Preserve HEAD/Range video playback while denying anonymous listing, writes and deletes.
- Reconcile existing policies when `makePublic=false` or the video extension is disabled, without deleting recordings. Permission-inspection failures fail closed.
- Reconcile one stable 30-day current/noncurrent retention rule and a 4 GiB hard video quota on an explicitly configured 8 GiB MinIO volume. Document server-level incomplete-upload cleanup and physical-capacity monitoring separately.
- Use controller-neutral Prefix Ingress routes; validate a separate local Traefik deployment and document Huawei private-cloud controller, TLS, storage and backup prerequisites without claiming production certification.

### Regression And Distribution

- Add opt-in, single-process duration and fault harnesses: an accepted 900-second run confirmed 811 logs, 750 seeded trade/margin pairs and CSV integrity; a separate real-RP proxy matrix passed 14 fault cases.
- Keep these repository QA harnesses and their mock dependencies outside the installed production gem. Preserve original evidence and documented retry ambiguity; this is not an exactly-once or zero-loss guarantee.
- Add validated GitHub CI and tag-driven release packaging for the gem, locked Helm chart and SHA-256 checksums. RubyGems.org/private-registry publication remains a separate operation.
- The SDK runtime is unchanged apart from its version identifier. Video recording stays caller-owned; anonymous video reads remain an intentional internal-network policy. No historical-report migration, Huawei live deployment, production HA or M5 certification is implied.

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
