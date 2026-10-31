# Cucumber 12 UI aesthetics review handoff

## Environment and review target

Open <http://rp-2607.localhost:18080/ui/> and use project
`superadmin_personal`. The local administrator is `superadmin`; the authenticated
deployment password was provided directly to the owner, not stored in this
document or the repository.

Review the **corrected SDK 2.0.0 candidate**, SHA-256
`c6bf0aae1fa9bd1e356fa116934cebebd582353afd381ec4b16bf9fc67ca62f3`.
It is not a formally published release. Launches 63-76 are its live acceptance
results. Earlier SDK 2.0.0 Launches 13-62 preserve baseline failures and harness
experiments; do not judge the corrected client from those alone. Launches 1-12
belong to earlier deployment/1.x verification and are outside this handoff.

The complete 64-Launch snapshot, including actual full names and timestamps, is
available locally at `tmp/cucumber12-independent/sdk2-launch-catalog.json` and
`tmp/cucumber12-independent/sdk2-launch-catalog.md`. No credentials are included.
The long `c12-independent-C-...` Launch names were deliberately configured by the
acceptance harness for traceability; they are not the SDK's default naming style.

## Recommended review route

| Launch | What to inspect | Expected state |
| --- | --- | --- |
| [64](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/64) | PNG, text and JSON in one Step; code blocks, filenames and native preview dialogs | PASSED |
| [72](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/72/1295/1296/log) | Combined DocString/DataTable Outline; formatted table with `TABLE_ONLY_AMBER`, not a placeholder | PASSED |
| [73](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/73/1300/1301/log) | Reverse multiline-argument order and the separate Examples rows | PASSED |
| [76](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/76/1363/1364/log) | Failure, skipped follower, error/backtrace and the image attached under After Hook | FAILED intentionally |
| [75](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/75) | Ten distinct 640x360 PNGs, thumbnail readability and precise per-Scenario/Step ownership | PASSED |
| [70](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/70) | Four-worker aggregation; Suite navigation, Passed filters and Hook labels | PASSED |
| [63](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/63) | Fifty rapid Steps; long-report scanning, repeated text and evidence density | PASSED |

The PNG cards are explicitly synthetic, not screenshots of a business UI. The
After-hook JPEG is a real RP browser capture supplied as a fixture; this is an
attachment/ownership test, not a failed Playwright application capture.

## Other corrected Launches

| Launch | Purpose | Expected state |
| --- | --- | --- |
| [65](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/65) | Bounded at_exit fallback after deliberate exit code 7 | INTERRUPTED intentionally |
| [66](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/66/1160/1162/log) | Escaped NUL preview with original text attachment retained | PASSED |
| [67](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/67) | Single worker using an externally owned Launch | PASSED |
| [68](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/68) | Native NUL log safely displayed and persisted | PASSED |
| [69](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/69) | Fifty-Step API v2 acceptance and persistence reconciliation | PASSED |
| [71](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/71) | Literal angle-bracket values follow native interpolation without a second expansion | PASSED |
| [74](http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/74) | File, path, bytes and explicitly encoded attachment inputs | PASSED |

Launch 74 deliberately includes a plain-Base64-with-plain-MIME negative control.
That input remains literal bytes; a bad image for that control is not evidence
that correctly declared binary/base64 attachments are broken. Do not add content
guessing or silently alter source bytes to make that negative control pretty.

## Baseline comparisons

Compare Launches 57/60 with 72/73 for the raw-placeholder display fix. Compare
Launch 62 with 66 for the missing-NUL-log correction, and 49 with 74 for complete
attachment persistence. These earlier baseline defects are intentionally kept
visible; no reports were deleted or repaired in place.

## Aesthetic review boundaries

Prioritize useful item names, succinct failure summaries, readable Markdown
tables/code blocks, attachment naming, excessive repetition and scanability of
long reports. Distinguish client-controlled content from RP-owned navigation,
fonts and attachment-dialog chrome. Provide before/after proposals and a small
set of acceptance screenshots before implementing cosmetic changes.

Preserve the verified wire contract: Feature/Rule suites, statistical Scenario
`STEP` items, nonstatistical action Steps, native Hook ownership, timestamps and
retry identity. An After screenshot must not be moved onto an already-closed
business Step merely for a cleaner screenshot. Do not hide real failures, change
raw evidence bytes, remove redaction, exceed preview limits or change Launch
completion ownership.

The functional candidate is frozen for independent verification. Begin with a
read-only visual review. Implement subsequent aesthetic changes in an isolated
branch/worktree after that baseline is committed, rather than editing the same
working tree while acceptance evidence is being collected.
