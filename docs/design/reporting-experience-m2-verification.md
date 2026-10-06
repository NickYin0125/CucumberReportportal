# M2 verification record

Branch: `codex/reporting-experience-v1-2`.

## Bounded redaction closeout: 2026-10-06

- Reproduced and fixed a clipping-order privacy bug in generated diagnostic text. Oversized JSON detail strings and JSON-formatted exception messages could be clipped inside a quoted sensitive value before fallback redaction, leaking the value prefix to assertion/evidence output and 503 spool records.
- The compatible `EvidenceRedactor` fallback now recognizes quoted keys (including JSON-escaped nested keys), JSON whitespace around separators, and clipped quoted values containing escapes or ending in a dangling escape. It fails closed over the ambiguous remainder of the bounded prefix. Existing presenter materialization, output, structure, and value budgets remain in force; this does not parse or duplicate the full oversized input and is not a universal PII or binary-artifact sanitizer.
- Added regressions for clipped JSON, escaped nested JSON and quoted values, the exact details limit, exception summaries, terminal/native Cucumber/ReportPortal output, and spool persistence after a stubbed 503. Existing concise nonsensitive payloads and byte ceilings remain covered.
- Fresh closeout checks on 2026-10-06: targeted redactor/assertion/evidence RSpec, 35 examples / 0 failures; full `bundle exec rspec`, 140 examples / 0 failures; ordinary `bundle exec cucumber`, 1 scenario and 3 steps passed; `git diff --check`, passed.
- Captured command output: [`edge-repro.log`](../../tmp/m2-closeout-20261006/edge-repro.log) records the additional pre-fix leaks; [`targeted-rspec.log`](../../tmp/m2-closeout-20261006/targeted-rspec.log), [`rspec.log`](../../tmp/m2-closeout-20261006/rspec.log), [`cucumber.log`](../../tmp/m2-closeout-20261006/cucumber.log), and [`diff-check.log`](../../tmp/m2-closeout-20261006/diff-check.log) record the passing closeout checks.
- This is a local regression closeout only. It does not replace the historical Launch25/26 live acceptance evidence below, claim a new browser run, or assert a new Master UI review.

## Clean staged-tree final gate: 2026-10-06

- Master source rereview approved the current patch, including dangling escapes, CR/LF JSON whitespace, and compatibility coverage.
- Tested the exported staged candidate tree `5e603ea5d786405f10400e4d0d0485dd2bb85a9a` at `tmp/m2-closeout-20261006/candidate-tree/`, not the dirty working tree. The export is a plain directory rather than a Git worktree; direct content-hash and executable-mode comparison matched all 121 files with zero mismatches. A stubbed Cucumber test generated one spool artifact in the export; it was preserved outside the candidate at `tmp/m2-closeout-20261006/candidate-spool-generated.ndjson`, and the final candidate file-count/hash check returned to 121/121.
- In that candidate directory, `bundle check` passed without installing dependencies; `bundle exec rspec` passed with 140 examples / 0 failures; ordinary `bundle exec cucumber` passed with 1 scenario and 3 steps.
- `gem build` produced `candidate.gem` outside the candidate and local installation into an external gem home succeeded. Because that isolated install intentionally omitted dependencies, a normal RubyGems activation attempt could not resolve Cucumber. Loading the installed gem's `lib` directly then succeeded, and a packaged-presenter smoke check found no canary and stayed within the 16 KiB details limit. No candidate source was changed.
- Final normal-entry check ran from `/Users/nick/Documents`, outside both source directories, with `GEM_HOME` set to the candidate install and `GEM_PATH` including the already-installed dependency gem paths; bundler environment variables and `RUBYOPT` were unset. `gem 'reportportal-cucumber-ruby', '= 1.1.0'` plus `require 'reportportal_cucumber'` activated specifically from the candidate gem path. The public `rp_evidence` World API and `AppLog.assertion` were present; assertion and failure diagnostics contained no canary and stayed within the 16 KiB limits (largest captured assertion channel 139 bytes; failure details 22 bytes). No dependency duplicates were installed.
- Candidate gate logs are outside the export: [`candidate-tree-identity.log`](../../tmp/m2-closeout-20261006/candidate-tree-identity.log), [`candidate-bundle-check.log`](../../tmp/m2-closeout-20261006/candidate-bundle-check.log), [`candidate-rspec.log`](../../tmp/m2-closeout-20261006/candidate-rspec.log), [`candidate-cucumber.log`](../../tmp/m2-closeout-20261006/candidate-cucumber.log), [`candidate-gem-build.log`](../../tmp/m2-closeout-20261006/candidate-gem-build.log), [`candidate-gem-install.log`](../../tmp/m2-closeout-20261006/candidate-gem-install.log), [`candidate-gem-activation-attempt.log`](../../tmp/m2-closeout-20261006/candidate-gem-activation-attempt.log), [`candidate-gem-load.log`](../../tmp/m2-closeout-20261006/candidate-gem-load.log), and the final [`candidate-gem-activation-with-deps.log`](../../tmp/m2-closeout-20261006/candidate-gem-activation-with-deps.log). The dependency-empty activation failed as expected because Cucumber was absent; direct package loading passed, followed by the successful normal RubyGems activation with existing dependencies.
- This validates only the named staged tree. The current uncommitted working tree is not claimed to equal a future commit or tag; commit/tag/push remain for Master.

The 2026-09-25 section below is the original local/mock-backed implementation baseline. The live acceptance gate was subsequently completed on 2026-10-05 against the local Docker Desktop Kubernetes deployment; Launch25 is the sole final live run.

## Final live acceptance: 2026-10-05

- Environment: Kubernetes context `docker-desktop`, Ready node `desktop-control-plane`; ReportPortal Helm deployment in namespace `reportportal`, app version `26.0.3`. `http://localhost` was verified through Docker Desktop -> ingress-nginx -> ReportPortal UI. Typewords ran at `http://localhost:5567/words`, project `superadmin_personal`.
- Real Ruby Playwright+Cucumber run used a fresh isolated BrowserContext for every Scenario. The passing UI interaction opened the dictionary picker and verified its heading and CET-4 entry; no dictionary selection, settings write, user session reuse, or server reset was performed.
- Versions: Ruby 3.4.2, Cucumber 10.2.0, `playwright-ruby-client` 1.62.0, Node Playwright 1.62.1.
- Final launch: `typewords-m2-20261005T021139-b16ae5`, ID `25`, UUID `136c29c6-9577-4a2f-9b38-5dcb3a8591cd`. API statistics and UI showed total 3, passed 2, failed 1. Native Cucumber recorded 3 Scenarios / 6 steps, 5 passed and only the intentional missing-button click failed with the original `Playwright::TimeoutError`; the actual child exit status `1` is captured and bound to Launch25 in `tmp/m2-typewords-live/run-observation.json`.
- RP topology: Suite639 has stats; its three stats Scenarios are direct children. The passed filter showed exactly Scenarios640 and645. Manual Scenario645 -> Gherkin action646 -> manual group647; INFO assertion log246 renders a PASS Expected/Actual table and `api_key=[REDACTED]`. Failed Scenario650 -> Gherkin action651; assertion/error/evidence logs247-250 are owned by action651. After hook652 is a separate passed item.
- The open-step target accepted evidence; the closed After-hook probe returned false. Evidence includes the failed assertion, concise Playwright error summary, and caller-owned PNG. The PNG attachment is ReportPortal file14 on log249; local and fetched bytes are both 98,793 bytes with SHA-256 `8b8b6ade3d8087b82afef2876dbf5ad649046d15cde133455374a1a9e91aa0cd`.
- Generated diagnostic text was redacted, and the RP UI displays `api_key=[REDACTED]`. The canary was absent from raw generated terminal/JSON/HTML/formatter output and inspected ReportPortal API text. All 16 machine acceptance validations passed.
- Master’s in-app browser review passed: Suite statistics and Passed2 filter, manual assertion rendering/redaction, failed-step logs and attachment ownership, separate passing After hook, and the native PNG attachment preview showing the Typewords Words page.
- UI evidence screenshots: `tmp/m2-typewords-live/master-rp-feature-statistics.jpg`, `master-rp-passed-filter.jpg`, `master-rp-manual-assertion.jpg`, `master-rp-failed-evidence.jpg`, and `master-rp-png-preview.jpg`.

## Original local/mock-backed baseline

Date: 2026-09-25. Scope: local RSpec, WebMock ReportPortal API, and ordinary stubbed Cucumber regression. At that point no live ReportPortal UI or Playwright run had been performed.

## Delivered

- Caller-owned evidence API: `rp_capture_target` and `rp_evidence`; an opaque target binds evidence to one open Gherkin step, hook, or manual step in one attempt. A closed, foreign, or expired target is rejected without a Scenario/next-hook fallback. Explicit handles can be used by a helper thread while the owning formatter remains alive.
- Failure presentation: concise redacted `ERROR` summary, bounded diagnostic text, optional path-backed or at-most-1-MiB in-memory attachments. An invalid artifact causes no partial evidence write. The original test exception remains primary.
- Structured `AppLog.assertion`: concise terminal result plus bounded Markdown expected/actual comparison through native Cucumber and RP routing, without changing test status.
- Target closure: blocks new writes, drains accepted writers up to the configured exit deadline, cancels tardy publication, flushes, then finishes the item. A timeout warns rather than claiming delivery.
- Tester-owned Playwright example in README. No Playwright runtime dependency or automatic screenshot/video policy was added.

## Checks

| Command | Result |
| --- | --- |
| `bundle exec rspec` | 132 examples, 0 failures; rerun 2026-10-05 |
| `bundle exec rspec --seed 20260925` | 132 examples, 0 failures (baseline) |
| `bundle exec cucumber` | 1 scenario, 3 steps passed; rerun 2026-10-05; ordinary profile excludes live and duration scenarios |
| `git diff --check` | Passed |

New specs assert RP log `itemUuid` and log-before-finish ordering, retry/foreign/late-handle isolation, two concurrent scenarios on one formatter, hook and manual-step attribution, bounded close cancellation, path-backed MIME and no full-file read, invalid-byte rejection without logs, sanitized text in a 503-triggered spool file, and assertion behavior. A real Cucumber subprocess test exercises the public World DSL and confirms one RP assertion log, one evidence log under the same Step, and one native Cucumber assertion attachment. These are local/mock-backed checks; they do not prove the visual RP UI layout or real browser attachment rendering.

## Scope and limitations

- The new diagnostic APIs redact generated text. Caller-supplied binary artifacts and legacy low-level `rp_log`/`rp_attach` payloads are not universally sanitized; testers must avoid attaching secrets. Video capture, retention, conversion, and playback remain framework/deployment choices.
- If closing or flushing exceeds the configured deadline, delivery can be unconfirmed or canceled. A successful local enqueue is not a server persistence guarantee.
- The browser harness owns its PNG and console excerpt. It does not record or upload video; screenshot capture, video lifecycle, retention, conversion, and playback remain consumer decisions.
- This live run validates one Cucumber process and scenario-local contexts. It makes no live multi-process or concurrency claim; concurrency behavior remains covered only by the local/mock-backed specs.
- Launches23 and24 were incomplete acceptance attempts and are excluded from the final result. Launch25 was visually reviewed and no further live run was made.

## VIDEO extension: 2026-10-05

The optional consumer framework extension in `examples/typewords_m2_video/` records a real Playwright viewport video. It extends the scope recorded for the earlier core Launch25 while preserving that launch and its artifacts. Desktop screen capture, SDK-owned recording, and new recording dependencies were not introduced.

- Deployment: the same existing `docker-desktop` Kubernetes context, ReportPortal at `http://localhost`, project `superadmin_personal`, Typewords at `http://localhost:5567/words`. The existing MinIO video ingress accepted authenticated S3 requests directly at `http://localhost`; public base `http://localhost` produced one `/automation-videos/videos/...` prefix. No deployment, policy change, or port-forward was needed.
- Versions: Ruby 3.4.2, Cucumber 10.2.0, Ruby `playwright-ruby-client` 1.62.0, official Node Playwright 1.62.1. The existing installed official Chromium and Playwright recording encoder were reused. FFmpeg and ffprobe versions are preserved in `tmp/m2-typewords-video/result-manifest.json`.
- Real launch: `typewords-m2-video-20261005T152800-52501d`, ID26, UUID `476911f9-f22c-4691-b40a-76a16db0445b`. Actual child exit1 is stored immediately in `run-observation.json` and bound to this launch. Native Cucumber has one passed navigation step, one intentionally failed missing-control click, and one successful After hook. RP stats are total1 / failed1; the original `Playwright::TimeoutError` object is identical to the exception seen by the After hook.
- The fresh BrowserContext enabled viewport recording before navigation. The identifiable 8.72-second recording shows Words -> Dictionary List with CET-4 visible -> Words, with no dictionary selection or settings persistence. After the original exception was re-raised, the After hook closed the context and completed official `Video#path` / `Video#save_as` before conversion or publication.
- Original generated WebM: VP8/yuv420p, 1280x720, 407,134 bytes, duration8.72s, SHA-256 `3c8b4d2884d9deb9a0cf1e4d38d6fb2a095b2b4eab0b2a9b6def29f8681dcbac`. The original remains in `tmp/m2-typewords-video/recordings/`, with an identical official saved copy `typewords-original.webm` and `source-ffprobe.json`.
- Tester-owned FFmpeg conversion reads only that finalized real source: `ffmpeg -y -i ORIGINAL.webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart -an RECORDING.mp4`. MP4 is H.264/yuv420p/faststart, 1280x720, 318,325 bytes, duration8.72s, SHA-256 `b036f3e9bb3465680f72e20c275861e513db93ffce70b4622160e76fc08a9b4a`.
- Topology: Suite653 `SUITE(hasStats=true)` -> Scenario654 `STEP(hasStats=true)`. Its failed Gherkin action656 is `STEP(hasStats=false)`. Its successful After hook657 is `AFTER_METHOD(hasStats=false)` -> successful manual658 `STEP(hasStats=false)`, named `Finalize and publish testcase recording`. The narrowly approved classifier fix reads real Cucumber10 `HookStep#hook?`; tests use installed native event/HookStep objects for Before/After and a nonhook Step named After.
- The closed failed-step target was rejected in After; a newly captured target inside manual658 accepted text evidence. `rp_attach(path, mime_type: 'video/mp4')` was called within that open manual node. The existing MinIO route streamed the MP4 and emitted exactly one HTML5 video/Open-video Markdown log255 owned by manual658, with no native video `binaryContent`. Video was not passed through `rp_evidence` multipart.
- Anonymous GET returned200 with `Content-Type: video/mp4`; byte-range GET returned206 and exact `bytes 0-1023/318325`. The downloaded MP4 equals the local file's SHA-256. Source/output/downloaded ffprobe JSON, native Cucumber JSON/HTML, diagnostic redaction checks, local UI screenshots, lifecycle events, and exact ownership checks are preserved in `tmp/m2-typewords-video/`.
- Machine/API checks: all21 validations passed. Master RP in-app playback verdict: PASS, recorded at `2026-10-05T15:33:05.996Z` in `tmp/m2-typewords-video/master-ui-video-verdict.json`, bound to Launch26 / log255 / publishing item658.
- Master expanded After Hook657 -> manual658 and used RP's native Show more chevron to reveal the full player beyond the default approximately 200-pixel long-log height. The actual inline video's currentSrc matched the manifest's same-origin MP4 URL; duration8.72, readyState4, errornull. After a native Play click, a 1.2-second DOM sample advanced currentTime4.571198 ->5.795145 with pausedfalse and endedfalse. A native timeline click from ended8.72 sought4.330738 with pausedtrue, endedfalse, and errornull; Dictionary List/CET-4 was visible at the seek point and Words appeared during playback around5.8s. No script media.play/currentTime setter or downloaded-file substitution was used.
- Master UI evidence: `tmp/m2-typewords-video/master-rp-video-topology.jpg`, `master-rp-video-playing.jpg`, and `master-rp-video-seek.jpg`. Future UI reviewers should use the native Show more control before operating the full player.
- Regression: targeted formatter suite16 examples passed; full root RSpec135 examples / 0 failures; ordinary root Cucumber1 Scenario / 3 steps passed; `git diff --check` passed. Actual output and child statuses are in `tmp/m2-typewords-video/{rspec.log,cucumber.log,diff-check.log,regression-results.json}`.

Observed synchronous timings from this one short recording:

| Measurement | Actual |
| --- | --- |
| Context close | 240.893 ms |
| Context close through official video path/save finalization | 249.235 ms |
| FFmpeg conversion | 492.380 ms |
| `rp_attach` enqueue | 0.317 ms |
| Manual node total | 619.125 ms |
| Manual-node return/flush | 77.291 ms |
| Video enqueue through manual return | 77.915 ms |
| Native Cucumber After hook total | 927.563 ms |
| Full observed child process | 11,466.899 ms |

These are real monotonic measurements and the native Cucumber hook duration. Total After time includes acceptance-only ffprobe, hashing, and target probes, so it is not incremental overhead measured against a no-video baseline. Upload and RP flush are measured only as an aggregate through the existing public DSL. One short clip does not certify 100-case throughput. No asynchronous evidence lifecycle or live concurrency benchmark was added; recording, finalization, conversion, retention, and binary privacy remain tester/framework responsibilities.
