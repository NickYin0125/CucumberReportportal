# Typewords M2 viewport video extension

This optional consumer harness records the real Typewords browser viewport with Ruby Playwright 1.62.0 and official Node Playwright 1.62.1. It uses the existing Docker Desktop Kubernetes ReportPortal deployment and does not manage infrastructure. Runtime packages and browser binaries stay under `tmp/`, outside the gem's packaged `examples/**/*` files.

## Setup

Ruby 3.1+ and Node.js are required, plus `ffmpeg`, `ffprobe`, and `kubectl` with access to the existing `docker-desktop` context. On this machine Homebrew Ruby must come first on `PATH`. From any directory inside this repository:

```bash
repo_root="$(git rev-parse --show-toplevel)"
PATH=/opt/homebrew/opt/ruby/bin:$PATH \
BUNDLE_GEMFILE="$repo_root/examples/typewords_m2_video/Gemfile" bundle install
mkdir -p "$repo_root/tmp/m2-typewords-video/node" "$repo_root/tmp/m2-typewords-video/browsers"
npm --prefix "$repo_root/tmp/m2-typewords-video/node" install --no-save --no-package-lock --no-audit --no-fund playwright-core@1.62.1
PLAYWRIGHT_BROWSERS_PATH="$repo_root/tmp/m2-typewords-video/browsers" \
  "$repo_root/tmp/m2-typewords-video/node/node_modules/.bin/playwright-core" install chromium
if [ -L /tmp/m2-typewords-video ]; then
  test "$(readlink /tmp/m2-typewords-video)" = "$repo_root/tmp/m2-typewords-video" || { printf 'Inspect the existing /tmp/m2-typewords-video symlink before proceeding.\n' >&2; exit 1; }
elif [ -e /tmp/m2-typewords-video ]; then
  printf 'Inspect the existing /tmp/m2-typewords-video path before proceeding.\n' >&2
  exit 1
else
  ln -s "$repo_root/tmp/m2-typewords-video" /tmp/m2-typewords-video
fi
```

The `/tmp` alias lets the Ruby driver's CLI subprocess use an executable path without spaces. Existing official clients/browser binaries from the original M2 example may instead be reused by overriding the two Playwright paths below.

## Run

From any directory inside the repository, with Typewords available at `http://localhost:5567/words`:

```bash
repo_root="$(git rev-parse --show-toplevel)"
PATH=/opt/homebrew/opt/ruby/bin:$PATH \
BUNDLE_GEMFILE="$repo_root/examples/typewords_m2_video/Gemfile" \
PLAYWRIGHT_CLI_EXECUTABLE_PATH=/tmp/m2-typewords-video/node/node_modules/.bin/playwright-core \
PLAYWRIGHT_BROWSERS_PATH=/tmp/m2-typewords-video/browsers \
M2_VIDEO_RESULTS_DIR="$repo_root/tmp/m2-typewords-video" \
bundle exec ruby "$repo_root/examples/typewords_m2_video/run.rb"
```

The runner reads the existing chart's video-bucket credentials in memory from Kubernetes, or accepts explicit `RP_MINIO_ACCESS_KEY_ID` / `RP_MINIO_SECRET_ACCESS_KEY`. The RP login uses the established local demo defaults or explicit `RP_USERNAME` / `RP_PASSWORD` / `RP_API_KEY`. These values are passed only through process memory/environment and are not printed or persisted. The authenticated S3 API endpoint and public base URL both default to `http://localhost`; the uploader appends `/automation-videos/videos/...` once. No bucket policy or infrastructure change is performed.

The single Scenario intentionally fails a real missing-button click. Native Cucumber must report one passed navigation step, one failed Playwright step, and a successful After hook, with the observed child exit `1`. A strict API/HTTP verifier then decides whether this exact profile was accepted; it does not equate arbitrary exit `1` with success. `run-observation.json` immediately records the actual child status/duration and binds it to the exact RP launch ID/UUID. Read-only reconciliation uses `RP_EXISTING_LAUNCH_ID=<matching-id>` and requires that saved observation.

## Recording and publication ownership

The fresh BrowserContext enables recording before any navigation. The viewport video shows Words -> Dictionary List with CET-4 visible -> Words, with several seconds of identifiable UI states. It does not capture the desktop, reuse a user profile, select a dictionary, or save settings.

The failed Gherkin step captures its own opaque target, emits text diagnostics, and re-raises the same original `Playwright::TimeoutError`. Its target closes normally. The After hook closes the recording context, then calls the installed official `Video#path` and `Video#save_as`; both the original generated WebM and saved copy remain available. This follows Playwright's [context-close recording lifecycle](https://playwright.dev/docs/videos).

Only after finalization does the After hook open `rp_step('Finalize and publish testcase recording')`. This manual node has its own valid target and belongs to the same Scenario attempt through `AFTER_METHOD`. The closed failed-step target is tested and rejected; diagnostic `rp_evidence` against the new manual target succeeds. The consumer transcodes the real original source and calls `rp_attach(path, mime_type: 'video/mp4')` in that open node. The existing `minio_markdown` route streams it to MinIO and replaces the native attachment with one video Markdown log owned by that manual node. No video is sent through `rp_evidence` multipart.

The captured transcode command is equivalent to:

```bash
ffmpeg -y -i ORIGINAL.webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart -an RECORDING.mp4
```

The framework/tester owns recording, finalization, conversion, retention, and binary privacy. The SDK has no new recording or transcoding dependency.

## Results and timings

`tmp/m2-typewords-video/` contains the WebM, MP4, source/output/downloaded ffprobe JSON, original failure identity, lifecycle events/timings, UI screenshots, native Cucumber JSON/HTML, terminal capture, and exact launch-bound manifest. The verifier checks H.264/yuv420p/faststart, exact uploaded/downloaded SHA-256, anonymous `video/mp4` GET, exact byte-range responses, node ancestry, and lack of a native RP video binary attachment.

Monotonic timings measure context closure/finalization, conversion, `rp_attach` enqueue, manual-node duration/return-flush, and enqueue-through-return. The manifest also records the Cucumber After-hook duration and full observed child-process duration. Total After time includes acceptance-only ffprobe, hashing, and target probes; it is not incremental video overhead measured against a no-video baseline. S3 upload and RP flush cannot be separated through the existing public DSL; the corresponding timing is an aggregate. One short clip does not certify throughput for 100 serial cases, and this example does not implement an asynchronous evidence-worker design.

Future runs require a separate human check of actual RP browser playback. Expand `After Hook: After hook`, then `Finalize and publish testcase recording`. RP limits long logs to roughly 200 pixels by default; use its native **Show more** chevron to reveal the complete video player, then use the native Play button and timeline to verify playback and seeking.

The real 2026-10-05 run is Launch26, `typewords-m2-video-20261005T152800-52501d`: one intentional Playwright failure, successful After/manual publication, and an 8.72-second recording. All 21 machine/API validations passed, and master confirmed actual in-app RP native playback and timeline seeking with no media error. The DOM-based verdict and UI screenshots are saved under `tmp/m2-typewords-video/`. Full root regression recorded 135 RSpec examples with zero failures and the ordinary Cucumber profile passed one Scenario / three steps. The [dated VIDEO verification record](../../docs/design/reporting-experience-m2-verification.md#video-extension-2026-10-05) preserves the exact launch, file digests, observed timings, and master playback evidence.
