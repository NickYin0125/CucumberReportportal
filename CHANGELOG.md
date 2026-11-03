# Changelog

## 1.3.3 - 2026-11-03

### Selective Readability Backport

- Selectively backport SDK 2.0.2 readability and example-redaction improvements onto released 1.3.2. Keep Ruby >=3.1, Cucumber >=9,<11, the 1.x native hook topology and companion Helm 1.3.1 unchanged.
- Keep ERROR/FATAL evidence cards plain even in rich mode. Label empty and whitespace-sensitive assertion strings, and summarize missing, extra and changed top-level JSON keys without claiming a recursive diff.
- Show HTTP response evidence before request evidence and preserve repeated header values. Strengthen the existing bounded automatic HTTP/evidence redaction paths; do not enable FailureRedactor or globally redact raw AppLog text/JSON.
- Intentionally withhold over-depth automatic URL/evidence inputs when the bounded decoding budget is exceeded; do not decode without limit. This 1.x fail-closed hardening addresses the reproduced four/five-layer percent-encoded JSON-path leak beyond released 2.0.2's three-pass guard. It is not a repair of that released 2.x tag or a claim of byte-identical behavior with 2.0.2.
- Consume repeated Bearer prefixes before masking the credential in automatic evidence. Preserve raw AppLog and Decision 19 native failure text; the corresponding released-2.0.2 correction remains a separate follow-up.
- Focus generated run-context descriptions on available branch/commit/build information while retaining allowlisted runtime attributes, explicit-value precedence and the 1.x no-generated-workers policy.
- Use unique PNG names in the current consumer and submit each screenshot through one RP route. R02 remains unfixed: hiding passed logs can hide evidence owned by a passed After Hook. The consolidated PNG route does not also attach that PNG to native HTML; no native HTML deduplication fix is claimed.
- Preserve Decision 19: native 1.x failures retain the original v1.3.1 message and every backtrace frame, including on presentation fallback. No 2.x failure-redaction policy is activated.

### Integration And CI

- Validate the candidate in all four Ruby 3.1/3.3 x Cucumber 9.2.1/10.2.0 cells, with isolated dependency resolutions, retained lockfiles, full RSpec, offline Cucumber and executable release-isolation regressions. A required all-cells gate precedes a separate clean release-bundle job.
- Install locked release dependencies and Bundler configuration outside the checkout, fixing the known vendor/bundle dirty-source failure without relaxing clean-source, ancestry, identity or checksum guards. Keep 1.x publication latest=false and historical 1.3.1 verification unchanged.
- Distribute the Gem, unchanged-version Helm companion, checksums and provenance through GitHub. RubyGems publication and deployment are not performed. The 1.x release does not replace 2.x as GitHub's Latest release.

### Verification

- Runtime `68e81d3697965305438be4fa27aa98aeb4baf726` passed the full local Ruby 3.1.7/3.3.12 x Cucumber 9.2.1/10.2.0 matrix: 1,878 examples per cell, zero failures. Each cell also passed 88 independent probes, nine release-isolation examples and the offline Cucumber profile (one Scenario, three steps).
- Final CI head `69aaedecd10a3ac01d7ad90b96e2db1b60343344` passed both remote four-cell runs: 1,879 examples per cell, zero failures or pending examples, plus the same offline and isolation checks. The extra example tests CI Gemfile creation order; independent package-byte comparison proved no runtime or packaged content changed from the locally accepted head.
- Fresh ReportPortal Launches 4085-4088 cover Cucumber 9/10 in plain/rich modes, with three passed and two intentionally failed Scenarios per Launch. API and browser checks verify complete native failures, escaped step arguments, response-first HTTP, bounded F18 previews and correctly owned, uniquely named PNG evidence. Consumer self-tests use browser doubles and are not a new Playwright business run.
- Independent QA returned scoped ACCEPT; the final report and CI extension are preserved on `qa/readability-1.3.3` at `013fcd5a77511f7e4a3ae6d8018c96815d167abe`. Earlier failed controls and immutable historical reports remain available. This release preparation changes documentation/specs only, not SDK runtime, dependencies, example code or deployment configuration.
- Matched local CPU-side p95: plain failure cards 0.224 -> 0.146 ms; rich failure cards 0.371 -> 0.205 ms. Plain HTTP evidence 1.571 -> 1.815 ms (+15.5%); the owner accepted this measured cost on 2026-11-03. These are not network latency or production-throughput guarantees. R02 and the existing RP code-theme contrast limitation remain disclosed in QA.

## 1.3.2 - Unreleased

### Ledger Presentation

- Failure logs show the exception, feature location and project frames before the full original backtrace. Preserve the failure content v1.3.1 sent, applying only Markdown/HTML escaping for the Ledger card.
- Client-built Markdown escapes user markup; attachment captions show kind, size and available dimensions, unnamed files use step-derived names, and JSON previews are compact.
- Hook item names are simplified without changing topology. Native global hooks remain Launch-scoped where observed; their independent Item-name checks are N/A, not fabricated hook items.
- Preserve explicit native Before/After/AfterStep names through Cucumber's hook-created event, retaining retry labels and clearing scalar metadata on finalization.
- Step-argument logs caption tables and DocStrings, align numeric columns without changing values, and omit the repeated step line. Argument-free steps have no description; Outline descriptions show Examples values on one line.
- Assertion, failure-evidence and HTTP cards preserve diagnostic values, HTTP severity and existing sanitized bounds.
- Keep structured HTTP and assertion bodies in their baseline format for native Cucumber and terminal formatters; apply Ledger cards only to the RP route.
- Opt-in `RP_RUN_CONTEXT=true` adds allowlisted SDK, Cucumber, Ruby and CI metadata plus a default Launch description; explicit attributes and descriptions win. No workers attribute is generated on 1.x.
- Opt-in `RP_PRESENTATION=rich` adds status pills, table-header accents and collapsible evidence to ReportPortal log messages only. Native Cucumber, terminal output, caller text and item metadata remain unchanged.
- Preserve item hierarchy, identities, statuses, timestamps, ownership, log counts and attachment bytes. Presentation faults retain the original baseline with one warning; rich output preserves ERROR first lines and adds at most 1,024 bytes.
- Released as a patch at the owner's request; the two opt-in switches are additive and off by default.

### Fixes And Known Limitations

- Fixed: preserve the complete original v1.3.1 failure message and every backtrace frame, including backslashes, multiline assertion diffs, Windows paths and escaped JSON. Presentation faults or display limits restore the exact v1.3.1 message instead of withholding content.
- Fixed: Text attachments whose preview contained a NUL byte were rejected by ReportPortal and silently lost. Previews now escape NUL, so these attachments persist with unchanged bytes.
- Known limitation: A native Cucumber log message containing a NUL byte is still not persisted on 1.x. SDK 2.x escapes it.

### Verification

- Runtime commit `df072ba0e6f603e66ba87e0b29c75fcc334a8e43` passed the full local Ruby 3.1.7/3.3.12 x Cucumber 9.2.1/10.2.0 four-cell matrix: 1,519 examples per cell (6,076 total), with zero failures or pending examples. Offline Cucumber passed one scenario and three steps in every cell. The first attempt's missing-jq environment failure is retained in the evidence; all four cells were rerun in full after correcting the test environment.
- Live F01, F04, F14 and F14-negative passed reporting acceptance in plain and rich modes on Cucumber 9 and 10 (Launches 3807-3826, including the frozen 62-frame F04). Original-input replays in Launches 3827-3830 preserved all 14 F14-negative messages and complete backtraces from actual v1.3.1 Launch 3778: 56/56 byte-identical comparisons. Intentionally failing fixtures retained their expected failed business status and completed reporting.
- Independent QA at `qa/presentation-ledger-1.3.2` commit `4abd436e322069a62f5f3a3de355b5c66260b9f8` passed P1.1-P1.10 and G8 under Decision 19: 715/715 checks, with no scoped defects. The report includes API readbacks, UI evidence and additional boundary controls in Launches 3831-3836. These are scoped presentation and failure-content results, not a claim of broader production certification.
- Both remote CI checks passed at the tested runtime; remote CI covers Ruby 3.3 with Cucumber 10, while the complete local matrix supplies Ruby 3.1 and Cucumber 9 coverage. This release-note correction changes no runtime, dependencies or tests relative to `df072ba0`.


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
