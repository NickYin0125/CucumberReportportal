# M2/M3 Security Verification, 2026-10-10

## Status

**Final scoped security verification PASS: F1/F3/F4 closed on Final6 SDK.**
Requested test execution is complete. Master subsequently confirmed Hume's
final SCOPED PASS for Reviewer5Lib/Final6SDK, with all 30 lib hashes equal, and
confirmed 90 versioned source files against the candidate6 receipts before
accepting the scoped checkpoint. Git/tag actions remain Master's responsibility.
Candidate6 is the tests-only sibling of
READY5/candidate5: all `lib` and README bytes are identical. Candidate5 was
retained after a fixture-coverage failure, not silently changed into a pass.
Candidate4 remains HOLD despite its earlier green gate receipts: six additional
same-scope F1 inputs were independently reproduced red on its frozen source.

All final focused, full, seed 20261010, M2/M3 integration, child-runtime audits,
normal gem build/install/consumer, and source post checks have actual receipts.
The adapted Cucumber 9 result is not a native/unshimmed full-suite pass. This
is neither blanket M2/M3 acceptance nor M4, duration acceptance, a release,
or universal PII/raw-binary privacy certification. Master owns Git/tag actions.

The write scope preserves the accepted M3/duration work and the root lockfile.
No live ReportPortal endpoint, browser, or real credential was used. All
canaries are synthetic. Existing expectations were not removed or weakened.

## Final Snapshot And Source Integrity

Final frozen path: `/tmp/m2m3-regression-20261010-candidate6`.
Execution copy:
`/Users/nick/Documents/New project/tmp/m2m3-security-fixes-20261010/acceptance/runtime/candidate6`.
The execution copy receives temporary/spool files; the frozen candidate is never
used as a writable run directory. Both were made from the original 2026-10-09
clean manifest plus current `lib`, all latest specs/fixtures, and README only.
Root's dirty dependency manifests were never used to resolve or install gems.

| Snapshot | Source files | Source-manifest SHA-256 | Disposition |
| --- | ---: | --- | --- |
| candidate4 | 91 | `b9846736c56022d81aaea52685181789d9fb1a5d86499387239bf02d5e3e2dfe` | Historical gates complete; new F1 red cases; HOLD |
| candidate5 | 91 | `7fa901a2dd557a3f80dbba8d1b826206c2a6549daefb8413f7d8ae8e3922ce50` | READY5 product; fixture coverage failure retained |
| candidate6 | 91 | `422f20ee3b794ccc652742d1f9aa29b1b436d30dbce7ff4f937c3e34ff3d3263` | Same READY5 product; corrected tests; final execution green |

READY5 product hashes, identical in candidate5, candidate6, installed package,
and root's final source receipts:

| Source | SHA-256 |
| --- | --- |
| `lib/reportportal_cucumber/service/evidence_presenter.rb` | `b06ac52013e0596e7df8013be9e7df4645a2c83fb600e8aa6cc2b9e508bd6704` |
| `lib/reportportal_cucumber/automation/evidence_redactor.rb` | `866d8f797e17117d7294aafe05837243967405172240243ebe800ee5e843df95` |
| `lib/reportportal_cucumber/cucumber/formatter.rb` | `0718be974d292684469ad15203a287bfd31a34dfd8118396021022565c92cc06` |
| `lib/reportportal_cucumber/automation/credential_keys.rb` | `3b95a3c8f94cf3b870af6ddd50762862262387b34a9eb34b6b8effa97e83bdb3` |
| `lib/reportportal_cucumber/service/queue_processor.rb` | `d865b54287ce0934075eb3ac3b1d081e8acae1f1c2ec49b77fe8352938a5c62a` |

Evidence base for every receipt below:
`/Users/nick/Documents/New project/tmp/m2m3-security-fixes-20261010/acceptance`.
`candidate6-source-pre.json` equals `candidate6-source-post.json` byte-for-byte;
the 194-file whole inventory, root `lib/spec/README` inventory, and root protected
dependency hashes also have equal pre/post receipts. The execution-copy source
post inventory equals frozen source. `candidate6-post-manifest.exit` is 0.
`candidate6-preservation-receipt.json` confirms frozen candidate3/4/5 whole
inventories and candidate2 source remain intact. No frozen snapshot was mutated.

Clean candidate Gemfile.lock SHA-256 remains
`dcf22fbb18ce883239be2ebec9432e2e1b33cc6c8f1b34f365e57125d2da4b11`.
Root dirty protected hashes, recorded without editing or resolving them:

| Root file | Unchanged pre/post SHA-256 |
| --- | --- |
| `Gemfile` | `bbf84bea967ac012444426fb7d35999ebb3e2fc9ceb7d76ba129e6466f1d8d2b` |
| `Gemfile.lock` | `e1137102577f032e2fd15ad1065e91846fc5e2cccf069af89f1d0453783845ed` |
| `reportportal-cucumber-ruby.gemspec` | `aaed20ea97c82d7b7c14d4fc59414c9bb163da6006fdf92700f98321354b397e` |

## Final READY5 Product / Candidate6 Gate Table

Counts are RSpec examples/failures, not counts of native Cucumber scenarios.
Each gate has `.command.json`, `.stdout`, `.stderr`, `.exit`, `.spawns.jsonl`,
`.children.jsonl`, and `.child-audit.json` in the evidence base. Exact commands,
working directories, and isolated environments are recorded, not inferred.

| Gate / receipt prefix | Examples | Failures | Exit | Audited actual children |
| --- | ---: | ---: | ---: | --- |
| `candidate6-focus10` | 89 | 0 | 0 | 6/6: 5 Cucumber + 1 standalone |
| `candidate6-full10` | 290 | 0 | 0 | 31/31: 29 Cucumber + 2 standalone |
| `candidate6-seed10` (20261010) | 290 | 0 | 0 | 31/31: 29 Cucumber + 2 standalone |
| `candidate6-m2m3-10` | 220 | 0 | 0 | 31/31: 29 Cucumber + 2 standalone |
| `candidate6-focus9` (adapted) | 89 | 0 | 0 | 6/6: 5 Cucumber + 1 standalone |
| `candidate6-adapted9` | 290 | 0 | 0 | 31/31: 29 Cucumber + 2 standalone |
| `candidate6-m2m3-9` (adapted) | 220 | 0 | 0 | 31/31: 29 Cucumber + 2 standalone |
| `candidate6-native9` (unadapted) | 0 | 0; 1 collection error | 1 | Blocked before examples |

All seven actual child audits exit 0: no missing spawned PID, wrong runtime or
formatter source/hash, or missing standalone mapping. The 29 Cucumber-bearing
children include actual CLI/API integrations and runtime probes; this is not a
claim of 29 separate feature invocations. The unchanged standalone mapping
checks still require that Cucumber core is not loaded.

| Actual identity | Cucumber 10 lane | Isolated Cucumber 9 lane |
| --- | --- | --- |
| Ruby | 3.4.2 | 3.4.2 |
| Bundler | 2.6.6 | 2.6.3 |
| Cucumber | 10.2.0 | 9.2.1 |
| cucumber-core | 16.2.0 | 13.0.3 |
| RSpec core | 3.13.6 | 3.13.6 |
| SDK | 1.1.0 | 1.1.0 |

`candidate6-identity10/identity9.stdout` records loaded entrypoint and formatter
paths under the candidate6 execution copy, with the expected formatter hash.
Actual 9 child receipts load Cucumber/core from the original isolated
`tmp/m2m3-regression-20261009/local/lane9/vendor/bundle/ruby/3.4.0`, not a root
bundle or Cucumber 10/11. The old isolated lock SHA-256 is
`970ffacec0106371ea22060b73e668637abdf78ae25b58bd55d1266eaaba45c6`.
Candidate6 uses a separate evidence-only `acceptance/lane9-candidate6/Gemfile`
and `bundle lock --local` receipt (exit 0) to update only its local SDK path.
No root bundle install or network dependency resolution occurred.

Native 9 collection fails at `formatter_spec.rb:7` requiring
`cucumber/core/events/test_step_started`, absent in core 13.0.3. The external
adapter intercepts only that require and loads `cucumber/core/events`; its
meaning matches the historical 255-example shim. It changes no SDK/model/spec
expectation. Adapted 290/0 must not be relabeled native 290/0.

Primary commands, all under the clean execution-copy cwd:

```sh
/opt/homebrew/opt/ruby/bin/bundle exec rspec spec --format progress
/opt/homebrew/opt/ruby/bin/bundle exec rspec spec --seed 20261010 --format progress
```

Focused and M2/M3 commands use the seven and 27 explicit spec paths recorded in
their command receipts and `run_gate.rb`. Lane 9 adds the external require-only
adapter in RUBYOPT. Every environment excludes inherited real RP credentials;
HTTP in native fixtures is disabled except WebMock.

## Normal Installed Consumer

`candidate6-gem-build`, `candidate6-gem-install`,
`candidate6-consumer-webmock-install`, `candidate6-installed-consumer-smoke`,
and `candidate6-installed-consumer-cucumber` all exit 0. Normal `gem build`
uses the clean baseline gemspec; normal `gem install --local --no-document
--install-dir` uses a fresh `acceptance/package6/gem-home`, with 33 cached local
dependency gems and no network. This is not `-I` source injection or a
Bundler-path consumer. Installed SDK version is 1.1.0; no publishing occurred.

Built `.gem` SHA-256:
`8ecd24f6efd624a060fb70c743e1f3889e457a08103951ab0b147f0d5d9e2d60`.
Installed source root:
`/Users/nick/Documents/New project/tmp/m2m3-security-fixes-20261010/acceptance/package6/gem-home/gems/reportportal-cucumber-ruby-1.1.0`.
Installed entrypoint and each of these seven public APIs are verified under
that root, with source location and per-file SHA-256 in
`package6/installed-provenance.json`:

- `AppLog.assertion`
- `World.rp_evidence`
- `EvidencePresenter.failure`
- `CredentialKeys.sensitive?`
- `ScenarioIdentity.build`
- `ScenarioAttributes.build`
- `ScenarioLinks.build`

All 90 packaged non-hidden `lib/spec/README` files match frozen candidate6.
Installed dependency requirement is exactly `>= 9.0, < 11.0`; actual consumer
activation loads Cucumber 10.2.0/core 16.2.0. Its actual native CLI run records
**3 scenarios / 3 passed, 10 steps / 10 passed, 55 logs, 3 multipart batches**,
zero failed native steps, current Step/After UUID routing, safe business text
readable, and no synthetic canary in checked sinks. Multipart JSON names align
with file-part names. Known PNG and long legitimate bytes/path names (>128)
retain `image/png` with MIME omitted and exact opted-in raw bytes. Evidence:
`package6/installed-consumer-protocol.json` and `package6/consumer/` native and
formatter output. These assertions do not generalize to raw binary privacy.

## Candidate4 And Candidate5 Retained Receipts

Candidate4 gates were already complete and were not rerun wholesale on resume:

| Candidate4 gate | Examples / failures | Exit | Child audit |
| --- | --- | ---: | --- |
| `focus10-retry2` / `focus9-retry1` | 82/0 each | 0 each | 6/6 each |
| `full10-retry1` / `seed10-retry1` (20261010) | 283/0 each | 0 each | 31/31 each |
| `m2m3-10-retry1` / `m2m3-9-retry1` | 213/0 each | 0 each | 31/31 each |
| `adapted9-retry1` | 283/0 | 0 | 31/31 |
| Native 9 collection | 0 examples; 1 collection error | 1 | Not a pass |

Its normally installed consumer passed 2 scenarios/3 steps, 30 logs, and three
multipart batches. Seven API provenance checks and 90 packaged-file comparisons
passed. Package SHA-256 is
`37b5f1e9f6f661d2b9827d9cd8c07d4d86e69489b69b46809cff2fb19744d6ad`.
Candidate4 Presenter and redactor hashes were respectively
`8cf5d1f13ac1c2a78f3a36d8f23ad8a6407d402b3f77351a5ea38b4a15fe7de9`
and `ca67cbf4ccf890d8bf50960fa95f611b8473dc563175491ca2bb6a678e516128`;
formatter hash was unchanged. Pre/post candidate/root/source inventories were
equal at that run. These real receipts are retained in
`candidate4-acceptance-summary.json` with an explicit HOLD, not final PASS.

The next six finite inputs are `{]` and `[}` before an escaped sensitive key,
unquoted `{\\u0070assword:...}`, and plaintext `_password`, `password_`,
`-password-`. First helper attempt was 7/6 plus a test-side wrong output-key
error. The correctly keyed retry is **7/6**, exit 1, with safe business control
passing. The first public run also had an insufficient-transport-coverage
assertion, so it is not used as a complete natural-spool privacy reproduction.
The separately saved corrected candidate4 public run is **3/3**, exit 1,
failing actual canary absence on successful multipart metadata, ordinary
spool, and natural fallback sinks. It induced all seven transport cases.
Paths: `candidate4-ready5-red-corrected-finite-helper10.*`,
`candidate4-ready5-red-corrected-finite-public10.*`, and corresponding
`protocol/` receipts. Neither frozen candidate4 nor old clean baseline changed.

Candidate5 actual focused was **89/2**, M2/M3 **220/2**, and full plus seed
20261010 were **290/2** each, all exit 1. Both failures were new fixture
coverage assertions: only four real requests occurred, leaving three transport
exceptions uninduced. Helper and successful HTTP cases were green; these two
failures are not observed SDK canary or PNG protocol regressions. The failed
candidate5 9 attempts exited before examples due to the evidence lane's frozen
lock still pointing at candidate4; do not confuse those with native9 collection.
Candidate5 pre/post root/source/194-file inventories match its frozen manifest.

Master required a new snapshot after test edits. Candidate6 fixes the driver
through seven ordinary real Step boundaries, not a stub formatter or private
spool invocation. The original coverage expectation and all canary/MIME/raw-byte
checks remain. No production source changed between candidate5 and candidate6.
All failed attempt receipts, including earlier harness errors, remain separate;
`harness-failed-attempts.md` explains them.

## Finite Sink Verification

The six added inputs independently exercise failure action/error/details and
artifact-summary fields, plus assertion name/expected/actual/details Markdown.
The helper checks the actual contracts (`:details` for failure, `:markdown` for
assertion), their 512-byte/16 KiB bounds, and input immutability. Controls retain
safe business keys (`password_policy`, `token_count`, `monkey`, `component`),
ordinary bracket prose, and a safe partially encoded URL fragment.

The actual native fixture publishes the same six inputs independently through
AppLog assertions and World evidence, including real PNG artifact names through
successful multipart HTTP and ordinary/fallback spool. Each finite transport
exception is separately raised by mocked HTTP, naturally invoking the real
QueueProcessor/formatter warning route. Fallback deletes the synthetic PNG
path after the request is built, causing normal spool payload rebuild failure;
no private spool method is called.

`candidate6-finite-sink-comparison.json` checks each canary separately across
terminal, native messages, API log entries, artifact metadata, warning output,
ordinary/fallback records, and exception metadata. Candidate4 retains canaries;
candidate6 has none. Candidate6 ordinary spool has **51 records / 0 raw**;
natural fallback has **51 records / 41 raw**. All seven transport labels were
actually induced in each mode. Maximum exception metadata lengths are 70/158
bytes in these finite cases, within the documented 2048-byte bound; these
observations do not impose an unsupported stricter limit. Safe business control
is readable in both spool modes. Raw native results/requests/warnings remain in
`protocol/candidate6-focus10/`; all other completed gates have their own protocol
directories. Oversized and in-budget existing transport cases remain in the
suite; ambiguous prefixed encoded JSON may safely degrade to a fixed omission.

`candidate6-acceptance-summary.json` compiles actual counts, versions, source
hashes, child audits, package provenance, and preservation results. Its
review-pending label records the compilation-time state and is preserved, not
rewritten after acceptance. Master's subsequent scoped acceptance and Hume
SCOPED PASS are recorded in `acceptance/final-handback.md` and this status.
`candidate6-acceptance-evidence-manifest.json` hashes the completed evidence
inventory. No final PASS is assigned to candidate4 or candidate5.

## Red Evidence

The frozen 2026-10-09 candidate was copied to a separate baseline overlay;
only the new security specs and synthetic fixtures were added to that copy.
The original red run is **65 examples, 9 failures**, retained at
`tmp/m2m3-security-fixes-20261010/frozen-baseline-red-security-rspec.log`.
Its latest red run is `tmp/m2m3-security-fixes-20261010/frozen-baseline-red-security-rspec-v2.log`:
**66 examples, 10 failures**. Failures cover escaped/oversized diagnostics,
unsupported object rendering, percent-fragment URLs, false-target retargeting,
public Cucumber sinks, custom credential aliases, and ordinary/fallback spool
metadata. The original frozen candidate and its historical manifests were not
modified.
The subsequent expanded baseline overlay run is
`tmp/m2m3-security-fixes-20261010/frozen-baseline-red-security-rspec-v3.log`:
**71 examples, 15 failures**. Use v3 as the latest red-count receipt; both
baseline logs and exit receipts are retained.

The READY1/pre-READY2 structural probe is retained at
`tmp/m2m3-security-fixes-20261010/focused-pre-ready2.log` and its focused
rerun at `focused-pre-ready2-v2.log`. At that intermediate source state,
percent-encoded fragment redaction, rejected-key traversal accounting, and
sanitizer limits below three bytes were red. Builder then corrected the latter
two boundedness holes. The latest pre-READY2 focused run is
`tmp/m2m3-security-fixes-20261010/focused-pre-ready2-v2.log`: **71 examples,
1 failure** (percent-encoded URL fragment canary).

After that run, the source changed again. The then-unfrozen pre-ready snapshot
passes **74 examples, 0 failures** across the focused security paths; receipt:
`tmp/m2m3-security-fixes-20261010/focused-current-source-pre-ready.log` and
`.exit`. The public Cucumber/native lifecycle, malformed diagnostic and
artifact metadata API/spool paths pass **8 examples, 0 failures** in
`tmp/m2m3-security-fixes-20261010/public-cli-spool-current-source-pre-ready.log`
and `.exit`. These are pre-freeze receipts only, not final candidate gates.
Coverage now includes complete malformed escaped-key JSON, embedded malformed
key/quote/colon, malformed Unicode, mixed URL fragment and dotted plaintext
keys; public two-step plus actual After-hook target rejection/acceptance; and
malformed/oversized artifact names. A normal synthetic PNG retains its exact
bytes, `known-good.png` name and `image/png` MIME. No live endpoint or
credential was used.

The initial-candidate review has since raised additional HOLD cases, including
malformed embedded JSON and artifact metadata. The current-source green results
do not erase those earlier red runs or constitute independent final-candidate
acceptance; READY freeze and complete replay remain required.

The original independent reproduction remains in
`docs/design/reporting-experience-m2m3-independent-review-20261009.md` and
`tmp/m2m3-regression-20261009/review/continuation/`. It observed canaries on
normal Cucumber CLI paths, native message attachments, terminal output,
formatter queue/API records, and ordinary transport-failure spool. The
historical 9.2.1 lane report is
`docs/design/reporting-experience-m2m3-regression-local-20261009.md`; it
explicitly labels its 255-example pass as compatibility-shim-loaded and audits
child mappings, rather than calling it native/unshimmed.

## Retained Coverage

- Public Cucumber CLI fixture exercises AppLog assertions, World evidence,
  formatter, actual queue/API JSON or multipart path, and native messages.
- Formatter transport failure captures warning output and spool records; all
  synthetic error canaries are asserted absent.
- Queue tests exercise ordinary spool and naturally triggered raw fallback.
  The fallback path is produced by an in-flight payload object's second
  `to_s` raising during normal spool payload rebuilding; no private spool
  method is called. Oversized and in-budget escaped-key JSON cases and a
  standalone URL with userinfo beyond byte 512 are covered. Metadata bounds
  are asserted at the documented 2048-byte limit.
- F3 tests cover helper and public Config alias rejection, separator/case
  variants, safe custom keys, seven defaults, disabled behavior, and existing
  scope precedence assertions.
- F4 tests verify explicit false does not retarget or enqueue while the next
  action is available; existing valid nil/current, original, cross-thread,
  closed, and foreign capability coverage remains intact. The public CLI
  fixture additionally captures a first-step target, rejects false/arbitrary/
  closed targets on the next step and actual After hook without evidence logs,
  then verifies nil and explicit-open targets log against the current step and
  hook item UUIDs. `AppLog.clear!` runs in the hook's ensure block.
- The original exception-identity assertion is preserved.

F1 also retains bounded 64 KiB input omission, limit 0/1/2/3, giant/unsupported
Numeric no-custom-serialization, rejected Hash-key traversal <=256, depth 8,
invalid UTF-8, cyclic/nested immutable inputs, no unknown-object `to_s`, complete
malformed escaped/unicode JSON, long userinfo, partial percent fragments, and
all earlier escaped-key handbacks. F3 directly exercises the helper as well as
Config, not configuration alone. These tests coexist with unchanged old suite
assertions; no weak expectations or synthetic successful private-helper shortcut
replace actual Cucumber/queue/model lifecycle coverage.

Candidate3's earlier full10 **275/0** was before the additional edge cases.
Its separately preserved review-red overlay ran **82/8**, including embedded
hashrocket/equal/escaped-space/long-key and partially encoded fragment leaks,
public multipart names, and natural spool. Neither result is candidate4/6 PASS.

## Candidate2 HOLD Receipt

Candidate2 is at `/tmp/m2m3-regression-20261010-candidate2`. Its source
manifest is
`/tmp/m2m3-regression-20261010-candidate2-source-manifest.json` with digest
`aa1ffa3d7bb9490ba7da9a1a8e771fb502eabeae1c04db92f740bc8340684f50`; its
Gemfile.lock remains the 2026-10-09 clean lock. Candidate2 reproduces the
reported consumer regression: a public `rp_evidence` artifact whose legitimate
name is longer than 128 bytes, ends in `.png`, and omits explicit MIME is sent
as `application/octet-stream` rather than `image/png`. Synthetic PNG bytes are
preserved. No production file was edited by this test run.

Receipts are under
`tmp/m2m3-security-fixes-20261010/final/`: focused security RSpec **74 examples,
1 failure** (`focused-security-rspec.*`), and full Cucumber 10.2 RSpec **275
examples, 1 failure** (`full-rspec.*`). Both failures are the same long-PNG
MIME case. The minimal focused reproduction is `long-png-mime-focused.*`.
Seed 20261010, adapted Cucumber 9 with child-runtime audit, M2/M3 integration,
and normal installed-gem consumer gates are deliberately deferred until
candidate3, so none are claimed as candidate2 passes.

This verification is not a universal PII/raw-binary privacy claim or blanket
M2/M3 release acceptance. Historical P2 findings F2, F5, F6, and F8 and the
documentation P3 remain separately tracked.

## Remaining Limits

Native unadapted Cucumber 9 collection remains open and explicitly disclosed.
Expected teardown warning output also remains in otherwise green suite stderr:
`ReportPortal log flush timed out before item finish; delivery is unconfirmed`.
No delivery-reliability/M4 claim is made from these offline successes. Automatic
Step/manual-step exception/backtrace logs, native core genuine failure payloads,
legacy logs/`rp_attach`, and opted-in raw bytes remain outside this diagnostic
guarantee. The original reporting-failure exception-identity expectation passes.
Independent review and Master final acceptance/tag decisions are not performed
by this tester; Master's final message confirms the scoped review/acceptance.
Historical F2/F5/F6/F8 P2 and F7 documentation P3 remain open;
unaccepted duration work and unrelated dirty files were untouched.
