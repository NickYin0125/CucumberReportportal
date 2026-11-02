# M3C Scenario Links Verification

Status: **LOCAL VERIFICATION PASS; PHYSICAL UI ACCEPTANCE PASS (2026-10-08)**.
The source and fixture/test paths were frozen after Master review. Pinned UI
source evidence and the dated live closeout are described in the
[implementation contract](reporting-experience-m3c-links-implementation.md).

## Dated Live Closeout (2026-10-08)

Master physically accepted the links in ReportPortal UI 5.15.3/API 5.15.2 on
launch 35. Source opened the immutable synthetic Git snapshot at the highlighted
Examples line, CI Run opened this run's explicitly local record, and TMS opened
the synthetic case page with the slash ID decoded. Item details preserved
Scenario/Rule prose and the formatted Examples table; the no-ID case displayed
only Source and CI Run. This is local fixture-link/UI acceptance, not external
GitLab/GitHub, CI-provider, Jira, or TMS integration coverage. The exact
physical observations and screenshots/DOM receipts are in the
[M3C-C live verification record](reporting-experience-m3c-live-verification.md)
and `tmp/m3c-live-20261008/browser/`.

## Acceptance Matrix

The isolated Cucumber subprocesses use the existing M3C attributes fixture
capture pattern, WebMock-only ReportPortal API transport, and actual request
bodies and routes. The supported lanes are Cucumber 10.2.0 and 9.2.1; direct
Cucumber 11 execution is excluded. Each lane must capture and assert its loaded
version and candidate manifest, and write evidence to its own directory.

The matrix runs the same two `.feature` files at the same URI and source-line
layout with links disabled, enabled, and changed destinations under both
`legacy` and `stable_v1` identity. The changed case alters only source commit
and the configured CI/TMS/source URL bases, not feature bytes or paths. It
checks two peer Suites, Rule and description metadata, Scenario Outline rows,
TMS tag selection and environment override precedence, a no-ID case in the
second Suite, and flaky retry grouping.

Request-body comparisons remove only description and volatile UUID/time/parent
fields. Within each individual run, every Scenario request route and
`parentUuid` must resolve to that feature's actual Suite; parent UUIDs are not
compared between executions. Description assertions compare the full original
Scenario/Rule/Examples prose and table with the generated References block
removed, then assert exact fixed-order link text and the actual Examples-row
line. Feature prose remains a Suite description and is not expected to appear
on Scenarios. Suite/action/hook descriptions must not receive references.

The attribute mapper is explicitly enabled in all link configurations. Its
captured attributes, names, parameters, `codeRef`, test-case identity, retry
group, topology, and attempt-owned logs must remain unchanged. No extra `links`
field, generated link log, or statistical item is accepted. URL rejection
cases use fixture credential markers and check that safe sibling links survive
without raw IDs, paths, credentials, URLs, or exception text in diagnostics or
captured descriptions.

## Candidate and Results

Master restored the accepted 153-path list and verified the prior 76 `lib/` and
`spec/` paths against the installed accepted gem with zero mismatches/extras.
The links candidate `/tmp/m3c-links-20261007-clean` was exported from that
list, excluding seven `tmp/` outputs, then overlaid only with the approved links
paths. It has 157 source paths before generated test output. All 84 candidate
`lib/` and `spec/` files match the frozen workspace versions; the sole ignored
workspace difference is `spec/.DS_Store`. The restored attributes baseline was
read-only. The 157-entry path and SHA-256 receipts, excluding generated
`.reportportal-spool/` and `tmp/` output, are under
`tmp/m3c-links-20261007/candidate-source-paths.txt` and
`tmp/m3c-links-20261007/candidate-source-sha256.txt`.

| Gate | Exit | Result and raw evidence |
| --- | ---: | --- |
| Locked Cucumber 10.2.0 full RSpec | 0 | 255 examples, 0 failures; `tmp/m3c-links-20261007/full-rspec.stdout` and `.stderr`. |
| Ordinary Cucumber | 0 | 1 scenario, 3 steps passed; `tmp/m3c-links-20261007/ordinary-cucumber.stdout` and `.stderr`. |
| Focused M3A/B/attributes regression | 0 | 73 examples, 0 failures; `tmp/m3c-links-20261007/focused-m3a-m3b-attributes.stdout` and `.stderr`. |
| Links integration, Cucumber 10.2.0 | 0 | 2 examples, 0 failures; `tmp/m3c-links-20261007/verified-cucumber-10.2.0/final-focused.stdout` and `.stderr`. |
| Links integration, Cucumber 9.2.1 | 0 | 2 examples, 0 failures; `tmp/m3c-links-20261007/verified-cucumber-9.2.1/focused.stdout` and `.stderr`; candidate-specific manifest and isolated bundle. |
| Gem build / isolated install | 0 | Version 1.1.0; `tmp/m3c-links-20261007/gem-build.stdout`/`.stderr` and `gem-install.stdout`/`.stderr`. Existing gemspec warnings are preserved. |
| Installed-gem Config/helper smoke | 0 | Config and helper resolve from isolated installed path; `tmp/m3c-links-20261007/gem-smoke.stdout` and `.stderr`. |

Each focused Cucumber lane produced eight JSON subprocess captures, each with
six Scenario start requests and `5 scenarios (1 flaky, 4 passed)`. The 10.2.0
captures are under `tmp/m3c-links-20261007/verified-cucumber-10.2.0/final-focused/`;
the 9.2.1 captures are under
`tmp/m3c-links-20261007/verified-cucumber-9.2.1/focused/`. Captures assert child
version and the exact candidate Gemfile. The full RSpec run also retained its
separate 10.2.0 captures under `tmp/m3c-links-20261007/verified-cucumber-10.2.0/`.

These historical local acceptance gates use WebMock for RP API transport and
do not by themselves establish behavior in a deployed ReportPortal/browser
combination. The later physical run and UI inspection are separately recorded
in the dated live closeout above.

## Master Closeout

Master reviewed the frozen implementation and confirmed all 84 `lib/` and
`spec/` paths match the workspace with no blocking findings. Final local
verification is **PASS**. Physical UI certification is recorded in the dated
live closeout above; this historical section remains the local verification
record.

## Exploratory Run

The first focused draft run completed **2 examples, 0 failures** with
Cucumber **11.0.0**. This version is unsupported and the result is exploratory,
not acceptance. Its captures are not part of the verified 10.2.0 or 9.2.1
acceptance directories.
