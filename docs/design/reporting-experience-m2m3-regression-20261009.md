# M2/M3 Full Regression And Independent Review

Status: **REGRESSION AND INDEPENDENT REVIEW COMPLETE; SIGN-OFF ON HOLD (2026-10-09)**. No M4 implementation, release, tag, push,
or infrastructure change is authorized by this regression task.

## Frozen Scope

Product checkout: `codex/reporting-experience-v1-2`, HEAD
`d9688b74a177cb359747fcd81e599d3528e9f3c3` plus accepted M3 source overlays.
The checkout also contains unrelated, unfinished duration/dependency work.
That work must remain untouched and is not part of this acceptance candidate.

The Master exported `/tmp/m2m3-regression-20261009-candidate` from the previously
accepted `/tmp/m3c-links-20261007-clean`, excluding generated `tmp/`, spool
directories, and `.DS_Store`. Before export, all `lib/` and `spec/` contents
matched the current checkout; the only non-source difference was
`spec/.DS_Store`. The execution agent must bind every gate to the candidate
manifest, actual dependency versions, and loaded SDK source paths. Generated
gate outputs must not be mistaken for candidate source files.

## Responsibilities

| Owner | Responsibility | Write scope |
| --- | --- | --- |
| Master | Freeze scope, define gates, review evidence/findings, physically inspect RP, issue final verdict | This aggregate record and generated browser evidence |
| Cicero, GPT-6 Luna | Execute local regression, supported-version lanes, and installed-gem consumer checks | Local evidence and local verification record |
| Turing, GPT-6 Luna | Execute real RP/Playwright and M3 live fixtures; independent API reconciliation | New regression harness, live evidence, and live verification record |
| Boole, independent fresh-context reviewer | Audit implementation, public API usability, compatibility and limits; report findings without a required PASS | Independent review record and isolated reproduction probes |

The first three agents stopped on account limits after leaving partial evidence.
Their agent IDs were no longer resumable when the user requested continuation.
Only unfinished work was reassigned: Euclid (GPT-6 Luna) owns the Cucumber 9
test-harness continuation, Locke (GPT-6 Luna) owns outstanding live reconciliation
and M3B/C execution, and Peirce independently rechecks the existing findings.
The prior outputs remain intact; replacement does not erase failed gates.

The reviewer is independent of implementation and test execution within this
task, not an external organization or formal third-party certification.
Execution agents must not modify SDK code or weaken existing assertions.
Blocking findings require Master triage and a separately scoped correction,
followed by fresh affected gates.

## Fresh Gates

| Gate | Required evidence | Status |
| --- | --- | --- |
| Full Cucumber 10.2.0 RSpec | Complete suite and independent seeded run, actual counts/exits, source manifest | Passed: clean-env 255/0; seed 20261009: 255/0; source reconciliation passed in local report |
| Cucumber 9.2.1 compatibility | Separate candidate-specific bundle, full suite attempt and focused M2/M3 gates, ordinary Cucumber | Compatibility-harness full 255/0, 23/23 actual child processes on 9.2.1; native unshimmed collection still blocked; focused 123/0 |
| Existing Cucumber regressions | Ordinary and relevant mocked reporting/rich-BDD examples; supported version and explicit formatter outputs | Ordinary 1/3, reporting-experience 1/2 and formatter contract 1/3 passed on 10.2; 9.2 ordinary/reporting examples passed; live-tagged full examples not claimed |
| Installed gem | Build/install/normal activation outside source; public API and loaded-source receipts; clean-consumer check | Passed: normal isolated install, provenance, consumer 1 scenario / 2 steps; onboarding limitations F5/F7 remain |
| M2 live core | New launch, 2 passed / 1 intentional failure where unchanged fixture applies; assertion/evidence, PNG integrity, rejection/privacy checks | Launch 36: API gates passed; Master Passed-filter, manual assertion and PNG preview passed |
| M2 caller-owned video extension | Finalized real recording, After/manual ownership, uploaded byte/range checks; Master inline playback/seek review | Launch 37: API integrity gates and Master native playback/seek passed |
| M3A live AST | Complex BDD fixture, independent expected counts, descriptions/Examples/tables/localization and peer suites | Launch 38: 11/11 detailed read-only oracle checks passed; 2 suites / 8 cases / 40 expanded actions; visual description limitations F6/F8 remain |
| M3B live identity/history | Two equivalent source variants, stable IDs/hashes, retry-owned logs and native history navigation | Launches 40/41: 8/8 reconciled API checks passed; IDs/hashes unchanged despite moved codeRefs, retry UUIDs separate; Master history grid and older-execution click passed |
| M3C live attributes/links | Exact scoped attributes, raw-ID links, immutable Source row, no-ID case; Master filter/click review | Final Launch 43: 22/22 API checks passed; Master attribute/Failed filters, Source/CI/TMS clicks and no-ID negative case passed |
| Independent review | Findings-first report, severity/reproduction, usability assessment and residual coverage limits | Completed with independent continuation: final 1 P1 + 6 P2 + 1 P3; confirmed HOLD; no unconditional approval |

## Boundaries

- Real services are the existing Docker Desktop Kubernetes deployment at
  `http://localhost`, project `superadmin_personal`, and Typewords at
  `http://localhost:5567/words`; environment/version probes are required anew.
- Cucumber 11 is outside the accepted runtime range. Never present an
  unsupported exploratory run as compatibility evidence.
- A deliberately failing fixture is accepted only when the original failure,
  exact scenario/step counts, reporting ancestry, and actual child exit code
  match its contract. An arbitrary nonzero exit is not a passing test.
- Preserve old launches, recorded artifacts, configuration, and local reference
  server on port 8873. New controlled reference destinations use a separate
  loopback service; they are not claims of external CI/TMS authorization.
- No test resets user data, reuses a personal browser profile, changes dictionary
  settings, alters public bucket policy, or prints/persists credentials.
- The framework owns browser capture, recording, conversion and media policy.
  The SDK keeps the accepted Suite/Scenario/action topology and explicit
  evidence/attempt ownership; M4 queue/delivery redesign remains out of scope.
- Mock green results, server responses, and physical RP UI observations are
  separate gates. A blocked or failed gate must be reported as such.

## Evidence And Final Decision

Fresh outputs belong under `tmp/m2m3-regression-20261009/`, separated into
`local/`, `live/`, `review/`, and `browser/`. Each execution record must include
commands, versions, actual exit statuses, expectations, raw sanitized evidence,
and pre/post candidate/source checks. This record will summarize the final
gate matrix, independent findings, Master dispositions, and physical UI verdict
after the agents finish. Historical acceptance is context, not a fresh result.

### Master Physical Observations

- Launch 36 Suite 855: clicking Passed `2` returned Scenarios 856 and 861, not
  an empty result. Scenario 861 displayed its structured PASS comparison on
  manual node 863 under Gherkin action 862. Scenario 866 displayed the original
  Playwright timeout, redacted diagnostics, and PNG evidence on failed action
  867; opening the PNG displayed the native attachment preview. After Hook was
  a separate node. The API receipt reports identical local/remote PNG SHA256.
- Launch 37 Scenario 870: After Hook 873 contained manual publishing node 874.
  The finalized recording log used the same-origin public MP4 URL, not an RP
  binary video attachment. After expanding the long log, Master clicked the
  browser's native Play control: `currentTime=0.305981`, `paused=false`,
  `readyState=4`. Clicking the native timeline yielded `currentTime=5.324438`
  of `duration=8.52`, still playing without a media error. Upload/download bytes
  and SHA256 matched, and Range returned 206. This is one recording's
  completeness/playback evidence, not a multi-process throughput benchmark.
- Launch 38 displayed peer English/Chinese suites with 5/3 cases and Total 8.
  English beta and Chinese second Example rendered five-column DataTables with
  literal `A|B`, multiline cells and a blank trailing cell. DocStrings rendered
  as code with substituted Example values and an embedded fence. Feature and
  Rule Background actions had `[Background]` prefixes while ordinary Given did
  not. Chinese Scenario details displayed Rule context, Example row 56 and
  parameters. Raw `<record>` prose was swallowed by RP Markdown and is referred
  to independent review; it is not claimed to be correct visual rendering.
- Launch 39 Suite 925 Passed `5` returned five logical cases, including the
  latest retry result. In the retry page, attempt 2 had only its own marker and
  passed action; clicking Retries `1` displayed the failed action, marker 1 and
  original deliberate exception. Launch 41 Suite 951's native History grid
  displayed five logical rows across three executions (39/40/41). Clicking the
  retry row's Execution 2 navigated to Launch 40 Suite 938's retry scenario.
- Final M3C Launch 43: staff Scenario 985 showed seven scoped attributes,
  Examples row 22 and retained prose. Master clicked Source and observed the
  immutable fixture commit `d99245b42274e66c25bcca475fd307295b5b70c8`, encoded
  spaced feature path and highlighted executed row 22. Clicking CI Run showed
  this run's Launch 43 receipt; clicking TMS opened synthetic case `CASE-UI/42`,
  not the stable hash. These are controlled loopback reference pages, not an
  external CI/TMS integration certification.
- Master submitted `browser:webkit` through RP's Attribute filter and observed
  only staff Scenario 985. Clicking Suite 984's Failed `1` returned Scenario
  997 and its original error log under action 998. Profile Scenario 1000 had no
  TMS attribute and only Source/CI Run links, with no fabricated TMS reference.

Browser screenshots and DOM receipts are under
`tmp/m2m3-regression-20261009/browser/`; the video interaction receipt is
`m2-video-playback-verdict.json`.

### Master Findings Triage

The unchanged product candidate is under regression, not automatically repaired.
Passing existing tests does not invalidate adversarial counterexamples. Master
reviewed the implicated product paths and the pinned synthetic probe receipts.
Independent continuation must confirm the final severity and public-route basis.

| Finding | Master disposition | Acceptance needed before claiming the issue closed |
| --- | --- | --- |
| F1 P1: clip before sanitize | Release/privacy blocker. The current presenter clips error, URL and JSON strings before credential syntax is interpreted; repeated downstream redaction cannot restore removed syntax. | Bounded fail-closed rendering and adversarial public-API tests at every prefix limit; canaries absent from terminal, native World output, RP enqueue and ordinary/fallback spool. No real credential probe. |
| F2 P2: relative source URI | Identity/history defect for cwd below configured root; not disproved by same-cwd source-variant happy path. | Actual Cucumber subprocess absolute/relative equivalence, monorepo cwd and relocation checks; explicit migration treatment for piloted stable-v1 histories. |
| F3 P2: custom credential allowlist | Conditional metadata safety defect: default allowlist is conservative, but a custom list can admit common credential aliases. | Normalized reserved credential policy independent of caller allowlisting; configuration and outbound-attribute canary tests. |
| F4 P2: false evidence target | Attribution contract defect: only omitted/nil should select current target; false is currently treated as omission. | False/object/foreign/closed target rejection while a later action or hook is open, with zero retargeting. |
| F5 P2: no-RP World setup | Clean-consumer documentation/integration gap; native AppLog itself still works. | Installed-gem example explicitly registers World DSL and ensures logger cleanup; secondary filesystem/capture failures preserve the original browser exception. |
| F6 P2: Examples prose | Metadata ingestion/promise gap, not a ScenarioLinks mutation. | Executed Examples block prose preserved across English/localized multiple blocks, or an explicit accepted limitation with corrected documentation. |
| F7 P3: shipped contract docs | Installed-gem onboarding gap; continuation downgraded original P2 to non-blocking P3. Source-relative design links point to files omitted by gemspec. | Ship referenced contracts or release-pinned reachable documentation; demonstrate consumer setup outside the checkout. |
| F8 P2: literal angle placeholders | Master physically confirmed the visible description loss; raw AST bytes are intact, but that is not readable UI fidelity. | Explicit Markdown presentation policy preserving intended prose/links/tables and visible literal placeholders, with English/localized UI checks. |

Detailed independent findings and reproduction instructions are in
`reporting-experience-m2m3-independent-review-20261009.md`. These findings are
not silently deferred to M4, and no PASS statement is required of the reviewer.

### Supported-Lane Qualification

Cucumber 10.2.0's unchanged suite passes normally and with seed 20261009.
Cucumber 9.2.1's original spec assertions also pass 255/0 under an evidence-only
loader shim, which maps one version-specific event-file require to the event
definition supplied by cucumber-core 13.0.3. The original spec remains unchanged.
Two standalone subprocesses need an isolated-bundle mapping because they unset
`BUNDLE_GEMFILE`; all 23 actual subprocesses were version-audited. This closes
the assertion coverage gap, but it is not a native unmodified collection PASS.
The collection defect requires a separate repository test-harness correction.
Only Ruby 3.4.2 was executed; the gem's entire Ruby >= 3.1 matrix is not certified.

The local, live and independent execution/review agents completed and were closed.
No implementation, formatter mapping, evidence privacy policy, dependency
manifest, tag, commit or infrastructure change was made by this acceptance work.

### Final Evidence Index And Decision

- Local execution record: `reporting-experience-m2m3-regression-local-20261009.md`.
  Cucumber 9's authoritative compatibility-loaded full-suite output is
  `tmp/m2m3-regression-20261009/local/continuation/final2-full-rspec.stdout`;
  the exit receipt is 0 and the actual 23-process audit is
  `final2-child-runtime.jsonl`. Earlier exploratory failures are retained.
- Live execution record: `reporting-experience-m2m3-regression-live-20261009.md`.
  M3B's authoritative 8/8 history reconciliation is
  `tmp/m2m3-regression-20261009/live/m3b/variants-r03-reconciled-v02/result-manifest.json`.
  The initial aggregate remains false; it is superseded, not rewritten as PASS.
  M3A detailed-r02 is 11/11; M3C Launch 43's oracle is 22/22 with 11/11
  provenance checks. Intentional failures have verified nonzero child exits.
- Independent record: `reporting-experience-m2m3-independent-review-20261009.md`.
  The continuation's final verdict is authoritative for priorities: F1 P1,
  F2/F3/F4/F5/F6/F8 P2, and F7 P3. F1 was reproduced via public World calls,
  native Cucumber execution, real enqueue/API models, and ordinary spool under
  substituted offline HTTP failure. It was not uploaded as a real credential.
- Master screenshots/DOM/interaction receipts: `tmp/m2m3-regression-20261009/browser/`.
  UI review is separate from executor API checks. The latest user-facing
  results are Launch 43, with M2 Launches 36/37 and M3A Launch 38 retained.
- After all execution agents were closed, the loopback reference daemon on
  8883 still had PPID 1 and returned HTTP 200. Historical 8873 was untouched.
  These fixture links remain available for user review.

**Master verdict: tests and review are completed, but unconditional M2/M3
acceptance and release readiness are HOLD.** The core topology, metadata
representation, explicit ownership and default opt-ins are reasonable and the
covered live happy paths work. F1 blocks privacy approval; conditional identity,
attribute safety, false-target attribution and onboarding/presentation findings
need correction or explicit scoped acceptance. No M4 code is started. This task
does not silently repair product behavior, waive findings, or certify production
throughput, zero loss, every supported Ruby version or an external CI/TMS system.

### Closeout Recheck, 2026-10-10

On the user's continuation request, Master re-read the three complete-suite exit
receipts and outputs: normal 10.2.0, seeded 10.2.0 and compatibility-loaded 9.2.1
each report exit 0 and 255 examples / 0 failures. The authoritative M3A/B/C API
receipts remain 11/11, 8/8 and 22/22. Current root `lib/` still matches the frozen
candidate byte-for-byte; `spec/` differs only by `.DS_Store`. `git diff --check`
passes. This is a closeout evidence recheck, not a claim that every test was
rerun on October 10. No additional agents were spawned, and the final independent
HOLD verdict remains unchanged. Findings are not fixed by this review/test task.
