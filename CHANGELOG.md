# Changelog

## 2.0.1 - Unreleased

### Ledger Presentation

- Failure logs show the exception, feature location and project frames before the full original backtrace.
- Client-built Markdown escapes user markup; attachment captions show kind, size and available dimensions, unnamed files use step-derived names, and JSON previews are compact.
- Hook item names are simplified without changing topology. Native global hooks remain Launch-scoped where observed; their independent Item-name checks are N/A, not fabricated hook items.
- Step-argument logs caption tables and DocStrings, align numeric columns without changing values, and omit the repeated step line. Argument-free steps have no description; Outline descriptions show Examples values on one line.
- Assertion, failure-evidence and HTTP cards preserve diagnostic values, HTTP severity and existing sanitized bounds.
- Opt-in `RP_RUN_CONTEXT=true` adds allowlisted SDK, Cucumber, Ruby and CI metadata plus a default Launch description; explicit attributes and descriptions win.
- Opt-in `RP_PRESENTATION=rich` adds status pills, table-header accents and collapsible evidence to ReportPortal log messages only. Native Cucumber, terminal output, caller text and item metadata remain unchanged.
- Preserve item hierarchy, identities, statuses, timestamps, ownership, log counts and attachment bytes. Presentation faults retain the original baseline with one warning; rich output preserves ERROR first lines and adds at most 1,024 bytes.
- Released as a patch at the owner's request; the two opt-in switches are additive and off by default.


## 2.0.0 - 2026-10-31

### Breaking Changes And Migration

- Start an independent SDK 2.x release line requiring Ruby >=3.3 and Cucumber >=12.0.1, ~>12.0. Preserve released SDK 1.3.1 and its Cucumber >=9,<11 constraints on the frozen maintenance/1.x line; Cucumber 11 remains unsupported.
- Adopt Cucumber 12's event/query lifecycle for hierarchy, hooks, retries, native log messages and attachments. Remove reliance on Cucumber's removed strict mode; undefined, pending and ambiguous results are failures without a strict option.
- Declare directly used base64, cgi and logger gems. Remove the legacy cucumber-expressions <19 compatibility pin; let Cucumber 12 select its compatible dependency family.
- Require an externally owned RP_LAUNCH_UUID for enabled ParallelFormatter workers. CI or a local parent creates and finishes the shared Launch after every worker settles; workers own only their items and evidence. Ordinary single-process runs finish their self-created Launch after reporting settles, with bounded at_exit fallback. No shared Launch coordinator or distributed completion state is introduced.
- Keep existing AppLog, RP-only helpers, evidence ownership, reporting-completeness policies and caller-owned browser/video lifecycles. See the English migration guide in docs/migrating-to-2.0.md before updating a consumer lockfile.

### Evidence Integrity And Independent Acceptance

- Escape literal NUL in log text and bounded previews so ReportPortal can persist them; preserve original attachment bytes, filenames and downloaded hashes.
- Render Scenario Outline tables from native compiled Cucumber data when a Step includes both a DocString and DataTable. Preserve Gherkin interpolation semantics without expanding values twice; clear the bounded-renderer metadata references on finalization.
- Independently validate the corrected runtime with 958 passing RSpec examples, 7 offline Cucumber scenarios / 21 steps, installed-package CLI checks, and fresh Ruby 3.3/3.4 installations. A real Bundler candidate index checks independent 1.x/2.x resolution; it does not imply RubyGems publication.
- Reconcile 14 corrected real-RP Launches, 237 closed items, 208 persisted logs and 65 byte-verified attachment downloads. Retain deliberate failures and explicit applicability limits in docs/reviews/2026-10-31-cucumber-12-independent-acceptance.md; HTTP acknowledgement alone is not a database-persistence guarantee.

### CI And Distribution

- Add locked current-source Ruby 3.3/3.4 validation and separate Ruby 3.1/3.3 x Cucumber 9/10 jobs checked out at immutable released SDK 1.3.1. Legacy resolution never uses the 2.x gemspec.
- Keep Helm 1.3.1 and ReportPortal appVersion 26.0.7 unchanged. For 2.x, record and verify the independent chartVersion from Chart.yaml; retain the original coupled 1.x bundle and manifest contract.
- Constrain stable 1.x release ancestry to maintenance/1.x, with a main exception only for the exact immutable published v1.3.1 commit. Constrain 2.x to main or codex/cucumber-12; reject dirty source, moved tags, unsupported release lines, mismatched identities and changed remote assets.
- These policies are prepared on the updated 2.x source only. Frozen maintenance/1.x still carries its historical main-only publisher; future 1.x publication needs a separately approved workflow/tooling backport and actual maintenance-head validation. No legacy branch changes are made here.
- Distribute the installable 2.0.0 Gem, unchanged companion Helm 1.3.1, SHA-256 checksums and release provenance through GitHub v2.0.0. The tag workflow requires both complete current and legacy CI matrices before publication. RubyGems/private-registry publication, deployment upgrades and maintenance-line backports remain separate operations.

## 1.3.1 - 2026-10-31

### Readable Logger And Runnable Examples

- Add local date/time with milliseconds and aligned severity to AppLog terminal summaries, retaining TTY colors and NO_COLOR behavior while removing the redundant APPLOG prefix.
- Keep native Cucumber and ReportPortal message bodies unchanged: report routing, JSON formatting and step ownership are unaffected by the terminal timestamp.
- Add terminal preview and nine-parameter Cucumber demos, including opt-in live RP delivery; retain compact summaries, explicit report:false precedence and secret-safe output.
- Align the independent installed-gem API/Playwright consumer with SDK 1.3.1 and the updated terminal assertions. Demo artifacts belong to the caller's working directory, not the installed gem directory.

### ReportPortal 26.0.7 Deployment

- Upgrade the companion Chart to 1.3.1 with ReportPortal 26.0.7 and locked official chart 26.10.26. Retain the upstream Kubernetes >=1.35 requirement; SDK and Chart release versions are 1.3.1.
- Add an isolated Docker Compose stack with the matching released service versions, successful migration/bucket initialization barriers, loopback-only routing, read-only video access and retention.
- Preserve anonymous GET/HEAD/Range video playback while checking denial of list/upload/delete and explicit read revocation. Document the pinned archived MinIO images and production mirror/scan requirement.
- Validate actual Helm and Compose backends, synchronous/asynchronous reporting semantics, native attachment bytes, UI statistics navigation and real Playwright recording playback.
- Fix the source live-regression task to bypass the default offline profile, and wait for the Typewords onboarding overlay without forcing UI clicks.
- Preserve the latest consumer guides. Distribute Gem and Chart archives, checksums and build provenance through GitHub v1.3.1; RubyGems publication, in-place historical-data migration and production HA certification remain separate operations.

## 1.3.0 - 2026-10-13

### Day-2 Security And Operations

- Release companion Helm Chart 1.3.0, retaining ReportPortal 26.0.5 and locked upstream chart 26.8.12; the chart and server versions are independent.
- Replace MinIO's unsafe anonymous `public` preset with object-read-only `s3:GetObject`. Preserve HEAD/Range video playback while denying anonymous listing, writes and deletes.
- Reconcile existing policies when `makePublic=false` or the video extension is disabled, without deleting recordings. Permission-inspection failures fail closed.
- Reconcile one stable 30-day current/noncurrent retention rule and a 4 GiB hard video quota on an explicitly configured 8 GiB MinIO volume. Document server-level incomplete-upload cleanup and physical-capacity monitoring separately.
- Use controller-neutral Prefix Ingress routes; validate a separate local Traefik deployment and document Huawei private-cloud controller, TLS, storage and backup prerequisites without claiming production certification.

### Regression And Distribution

- Preserve binary Multipart sources during metadata validation: older JSON parsers can retag their input as UTF-8, breaking non-ASCII log plus binary attachment requests on Ruby 3.3. Add a byte/encoding regression guard.
- Add opt-in, single-process duration and fault harnesses: an accepted 900-second run confirmed 811 logs, 750 seeded trade/margin pairs and CSV integrity; a separate real-RP proxy matrix passed 14 fault cases.
- Keep these repository QA harnesses and their mock dependencies outside the installed production gem. Preserve original evidence and documented retry ambiguity; this is not an exactly-once or zero-loss guarantee.
- Add validated GitHub CI and tag-driven release packaging for the gem, locked Helm chart and SHA-256 checksums. RubyGems.org/private-registry publication remains a separate operation.
- Apart from the version identifier and this Multipart compatibility fix, SDK runtime behavior is unchanged. Video recording stays caller-owned; anonymous video reads remain an intentional internal-network policy. No historical-report migration, Huawei live deployment, production HA or M5 certification is implied.

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
