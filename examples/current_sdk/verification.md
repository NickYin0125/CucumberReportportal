# Independent verification

Freshly executed on **2026-10-12 Asia/Shanghai** (2026-10-11 UTC), against the
current working-tree SDK, not historical screenshots or release promises.

## Installation And Runtime

- Built `1.2.0.pre.1` with `gem build ... --output <external-scratch>/candidate.gem`.
  Normally installed that archive into an isolated `/private/tmp` GEM_HOME using
  `ruby bin/setup /absolute/path/candidate.gem`. No SDK Bundler path dependency.
- Runtime: Ruby **3.4.2**, Bundler **2.6.6**, Playwright Ruby **1.62.0**, compatible
  Playwright CLI **1.62.1**, real Chromium. Existing browser downloads were reused;
  a fresh npm/browser download was not exercised.
- Cucumber **9.2.1** and **10.2.0** ran in separate external consumer copies and
  lockfiles. Dependencies could be reused from the installed Ruby toolchain; the
  SDK itself loaded from the isolated normal gem installation.
- `bin/runtime` verifies the installed version/path and the complete set and
  SHA-256 hashes of **36** `lib/**/*.rb` files against the working tree. The JSON
  manifest also records the archive SHA-256 and installed dependency versions.
  Both lane manifests reported `source_matches: true`.
- Expressions/native HTML: **17.1.0 / 21.15.1** on Cucumber 9; **18.0.1 / 22.3.0**
  on Cucumber 10. A rebuilt archive was installed into a second isolated GEM_HOME;
  the example copied from that installed gem passed the complete verifier too.

## Executed Outcomes

| Check | Fresh result |
| --- | --- |
| `bin/verify`, Cucumber 9.2.1 | Passed; offline 5 scenarios / 20 steps, exit 0 |
| `bin/verify`, Cucumber 10.2.0 | Passed; offline 5 scenarios / 20 steps, exit 0 |
| Separate `intentional` run, both lanes | 1 scenario / 2 steps: 1 failed, 1 passed; exit 1 |
| Native evidence, both lanes | Offline 46 attachments; intentional 6, including exactly 1 valid PNG |
| Failure ownership | Original `Playwright::TimeoutError`; missing locator unchanged; screenshot owned by an After Hook starting after the failed Step finished |
| HTML/messages reconciliation | Matching evidence bodies and Step/Hook owners; formatter-specific run/start IDs/timestamps and known HTML backtrace escaping normalized |
| Console, both lanes | DEBUG/INFO one-line summaries; cyan INFO; expected 400 at INFO; no Markdown/JSON bodies |
| `NO_COLOR=1`, both lanes | Passing 5-scenario rerun, exit 0, no ANSI escapes |
| `bin/check_fixture` | Real HTTP 200, 201, expected/malformed 400, 404, 405, body/header-size 413; clean shutdown |
| `bin/check_config` | 10 credential-free endpoint-policy checks, no network requests |
| `bin/check_rerun` | Two acceptance runs succeeded; pre-existing spool sentinel preserved |
| Exact README manual command | `--no-profile`, five distinct formatter output paths; 5 scenarios / 20 steps passed, exit 0 |
| `bin/run live` | Real Typewords at `http://localhost:5567/`, title smoke: 1 scenario / 2 steps passed, exit 0 |
| `TYPEWORDS_SCREENSHOT=true bin/run live` | Private local PNG captured and attached to the title-check Step; RP disabled |
| Browser review | Opened native HTML in Chromium; API JSON under matching steps, original browser error and screenshot attachment under After visible |
| Ruby syntax | All 14 Ruby support/helper/step/script files passed syntax checks |

Every acceptance run forces RP off and compares spool inventories before/after,
including existing evidence. It checks logger cleanup, fixture shutdown, and
rejects unexpected failed/skipped/undefined/pending steps. Unique run directories
prevent stale screenshots from passing validation. An intentional-failure exit
is accepted only after the original error, exact failed-step count, PNG bytes,
and Hook event ordering are verified; the ordinary runner still exits 1.

External receipts/reports are under `/private/tmp/current-sdk-qa.xAzGQ2/`, including
lane `artifacts/acceptance/*/{runtime.json,acceptance.json,fixture.txt,config.txt}`
and the native HTML/messages/console transcripts. No generated reports,
dependency directories, lockfiles, browser/tool state, or screenshots were added
to the source example tree. This matters because the gemspec's broad examples
glob does not honor `.gitignore`.

## Limits And Recommendations

**Real ReportPortal ingestion and RP UI were not independently exercised in this
task.** RP is a documented opt-in, not freshly certified server/UI evidence. No
credentials were retrieved, saved, or embedded. Local endpoint validation was
tested without auth or network requests. No MinIO, video, deployment change,
parallel CI launch lifecycle, or strict reporting-gate integration was tested.
The optional Typewords check is a landing-page smoke, not full app coverage.

Two upstream native-reporting details surfaced: Cucumber 10.2.0 with expressions
19.x crashes on nil group children, so the example pins expressions `< 19`;
HTML formatter 22.3.0 changes `<` to literal `x3C` in backtrace text. Raw NDJSON
retains the original trace. The RP formatter reserves a distinct `--out` path but
does not write to it, so `reportportal.txt` may be absent and is not a receipt.

For the root README, retain the external-consumer install/copy workflow,
`--no-profile` on explicit multi-formatter commands, supported Cucumber 9/10
boundaries, diagnostic-vs-business assertion distinction, current open Hook
target restriction, and honest RP/receipt/privacy limits. Link this example and
its verifier rather than presenting an intentional failing run as all-pass.
