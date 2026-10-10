# M2 + M3 Independent Model Review, 2026-10-09

## Findings First

No P0 identified. One P1 release blocker and seven P2 findings require Master triage. This is a separate model review, not an external-firm assessment or a regression-executor PASS. No implementation patch is proposed for automatic application.

### F1 [P1] Clipping before redaction leaks credentials across M2 sinks

Source: [evidence_presenter.rb:26](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/service/evidence_presenter.rb:26), [evidence_presenter.rb:27](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/service/evidence_presenter.rb:27), and [evidence_presenter.rb:74](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/service/evidence_presenter.rb:74).

Impact/repro: `failure(url: "https://user:CANARY_LONG_USERINFO_" + "x" * 600 + "@example.test/", ...)` leaks the password prefix. The 512-byte input slice removes the userinfo terminator before the sanitizer sees it. Separately, valid JSON beginning with `{"\u0070assword":"CANARY_ESCAPED_KEY", "padding":"..."}` and exceeding 16 KiB leaks that password in details; exceeding 256 bytes leaks it in the error summary. Clipping invalidates JSON, so the redactor's JSON-key decoding is replaced by a plain-text regex that does not recognize the escaped key. Repeating redaction in the formatter cannot recover the missing structure.

Observed: the pinned probe exposes synthetic canaries in the failure presenter, real formatter's enqueued message, ordinary QueueProcessor NDJSON spool, and assertion terminal/native-World/RP-fallback sinks. These are generated diagnostic text, not opted-in screenshot bytes. No live RP request/UI was used. The short structured-URL control is sanitized correctly, so this is a boundary-specific defect, not an assertion that all redaction fails.

Basis: M2-08 and the M2 implementation contract require sanitization before all diagnostic output/spool routes; the structural plan explicitly says redact before truncation. Existing [m2_assertion_spec.rb:24](/tmp/m2m3-regression-20261009-candidate/spec/reportportal_cucumber/automation/m2_assertion_spec.rb:24) covers ordinary quoted JSON and dangling escapes, not escaped sensitive keys or userinfo whose terminator lies beyond the prefix budget.

Request to Master: prioritize a bounded, fail-closed sanitization strategy that does not discard credential syntax before determining what to mask. Do not fix this by whole-reading/parsing arbitrary large inputs without a memory bound. Add public API, native event bus, outbound payload, and normal/fallback-spool canary cases at every clipping boundary. Hold unconditional M2 privacy/release sign-off until verified.

### F2 [P2] Stable source identity interprets relative Cucumber URIs against the wrong directory

Source: [scenario_identity.rb:231](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/service/scenario_identity.rb:231); formatter forwards the unexpanded URI at [formatter.rb:1037](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/cucumber/formatter.rb:1037).

Impact/repro: run from `/tmp/m2m3-regression-20261009/review`, with identity root `/tmp/m2m3-regression-20261009`. The actual feature `features/prose.feature` is `review/features/prose.feature` relative to that root. The helper instead hashes `features/prose.feature`. Passing the same file's absolute URI produces a different testCaseId. This splits source-based history when monorepo jobs invoke Cucumber from a subdirectory or change absolute/relative CLI notation. It can also conflate same-named module-relative features. Explicit-ID identities bypass this source-path defect.

Basis: M3B promises checkout-root-relative source identity and source-edit stability. Canonical data ordering is not enough if the actual source path is misresolved. Existing identity tests assume relative URIs are already root-relative; no cwd-below-root equivalent-URI test was found.

Request to Master: resolve native runtime URIs against their actual execution/source base before relativizing to the configured identity root, or explicitly constrain and validate invocation layout. Add formatter/subprocess coverage for subdirectory cwd, absolute/relative URI equivalence, checkout relocation, and spaces. Avoid silently redefining already-piloted stable-v1 histories; assess migration consequences of any correction.

### F3 [P2] Custom attribute allowlists bypass the promised credential-key prohibition

Source: [scenario_attributes.rb:9](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/service/scenario_attributes.rb:9) and [scenario_attributes.rb:124](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/service/scenario_attributes.rb:124).

Impact/repro: `allowed_keys: ["access_token"]`, with scoped tag `@access_token:CANARY_ATTRIBUTE_TOKEN`, returns a publishable attribute containing the canary. Common aliases such as `client_secret`, `refresh_token`, and `x-api-key` are likewise outside the exact reserved-key list. This requires attributes to be enabled and a custom allowlist; the default allowlist does not expose this example.

Basis: [attributes contract:34](/Users/nick/Documents/New%20project/docs/design/reporting-experience-m3c-attributes-implementation.md:34) prohibits credential names, not just the few exact strings in the reserved list. Existing allowlist tests reject `token` and `password` but do not establish this broader policy.

Request to Master: agree on and enforce a normalized credential-key policy, including common aliases and separators, independently of caller allowlisting. Add custom-allowlist and configuration tests proving credential values never enter Scenario attributes or diagnostics. Alternatively narrow the public prohibition explicitly, with a security review of that weaker contract.

### F4 [P2] An explicitly invalid false target is silently retargeted

Source: [formatter.rb:131](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/cucumber/formatter.rb:131).

Impact/repro: while an action is open, `rp_evidence(..., target: false)` returns `true` and queues the evidence on that active action. `target || capture_target` treats a false invalid handle as an omitted handle. An adapter using false as a failed-capture sentinel can consequently attach evidence to a later Step/hook instead of receiving rejection. Arbitrary truthy objects and genuinely closed/foreign capabilities follow the registry rejection path; this finding is specifically the false value.

Basis: M2's public contract makes only `nil` implicit-current and requires invalid targets to be rejected without retargeting. Existing invalid-handle tests do not cover false versus nil through a real formatter.

Request to Master: distinguish nil from explicit invalid inputs before selecting a target; test false, arbitrary objects, closed handles, foreign handles, and a newly active hook together. Do not introduce Scenario/Launch fallback.

### F5 [P2] Documented clean no-RP setup does not register the World DSL

Source: [README.md:247](/Users/nick/Documents/New%20project/README.md:247), [README.md:303](/Users/nick/Documents/New%20project/README.md:303), and [formatter.rb:339](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/cucumber/formatter.rb:339).

Impact/repro: a fresh consumer support file using exactly `require "reportportal_cucumber"` plus the documented Around logger binding, without the RP formatter, raises `NameError` on `rp_capture_target`; it does not return the documented disabled-reporting nil. The same native Cucumber 10.2.0 one-step probe passes when a separate adapter adds `World(ReportportalCucumber::Cucumber::World)`. The module exists, but automatic registration only happens when the RP formatter is instantiated.

Basis: the public disabled fallback and no-RP usability promises must be reachable from documented tester setup. World PORO specs manually include the module; they do not catch this clean consumer setup gap. AppLog's native log route itself remains usable without RP.

Request to Master: show explicit World registration in an installed-gem, consumer-owned support example, including Around/ensure cleanup and disabled RP behavior. Keep browser capture policy in the framework. Also protect the entire example capture pipeline, including directory creation, so a secondary filesystem error cannot replace the browser error.

### F6 [P2] Executed Examples prose is absent from Scenario descriptions

Source: [ast_metadata.rb:58](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/cucumber/ast_metadata.rb:58) and [formatter.rb:1277](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/cucumber/formatter.rb:1277).

Impact/repro: the review feature has Feature, Rule, Scenario Outline, and Examples prose. The Scenario description includes Scenario/Rule prose, the Examples name, row number, and parameter table, but drops `EXAMPLES_PROSE_CANARY`. AstMetadata never extracts Examples.description. Testers lose dataset-specific preconditions/explanations even though the AST contains them.

Basis: the user requested preserved prose/descriptions, and [links example:24](/Users/nick/Documents/New%20project/examples/m3c_links/README.md:24) explicitly says Rule and Examples prose/tables remain unchanged. This is an M3A ingestion/description gap already present before the M3C toggle, not a claim that ScenarioLinks overwrites existing description bytes. Existing multi-Examples fixtures have names/tables but no Examples prose to assert.

Request to Master: decide whether executed Examples prose is in the acceptance contract. If yes, carry only the executed block's description without changing identity, statistics, or item topology; test multiple English/localized blocks and links enabled/disabled. If intentionally excluded, correct the tester-facing promise and record the limitation rather than counting prose preservation as complete.

### F7 [P2] Installed-gem readers cannot follow the new design/migration links

Source: [reportportal-cucumber-ruby.gemspec:21](/tmp/m2m3-regression-20261009-candidate/reportportal-cucumber-ruby.gemspec:21); affected entry point [README.md:142](/Users/nick/Documents/New%20project/README.md:142).

Impact/repro: evaluating the candidate gemspec's file inventory includes README and examples but no `docs/design/**`. Its installed README instructs users to review relative M3B migration and M3C contracts that are not shipped. New users cannot discover the full identity migration, unsupported native reporter lane, source-root, or metadata safety boundaries from those links without finding the repository themselves. The sample CLI also assumes repository-relative `examples/...` files exist in the consumer's cwd; installation does not copy them there.

Basis: clean installed-gem usability requested by this review. This is a source/package-inventory finding, not a claim to have installed or certified a built gem. No clean-package documentation navigation test was found.

Request to Master: ship the referenced contracts or provide verified release-pinned documentation URLs, and distinguish consumer project setup from repository demonstration commands. Add a minimal clean-gem reader/run smoke without a checkout. This is M2/M3 onboarding debt to resolve or explicitly accept, not an M4 queue defect.

### F8 [P2] Literal outline placeholders become invisible HTML in Markdown descriptions

Source: [formatter.rb:1272](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/cucumber/formatter.rb:1272), [ast_metadata.rb:55](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/cucumber/ast_metadata.rb:55), and [zh-CN.feature:36](/tmp/m2m3-regression-20261009-candidate/spec/fixtures/m3a/zh-CN.feature:36).

Impact/repro: the actual Chinese fixture's source description is `<record> 的大纲描述。`. The short pinned probe reads the real AST, runs extract_scenario_description and builds the actual item-start payload; the wire description still contains raw `<record>`, not escaped literal text. Master reports that M3A38 Scenario 919 Itemdetails displays only `的大纲描述。`, with screenshot reference `browser/m3a-scenario-description.jpg`. That is user-supplied physical evidence, not a screenshot/GUI inspected by this reviewer. The source-level reproduction independently confirms the unsafe presentation input; this review does not claim to have reproduced the deployed renderer itself.

Primary renderer basis: ReportPortal UI 5.15.3 [descriptionTooltip.jsx](https://github.com/reportportal/service-ui/blob/5.15.3/app/src/pages/inside/common/infoLine/parentInfo/description/descriptionTooltip/descriptionTooltip.jsx) passes the description to MarkdownViewer. Its [markdownViewer.jsx](https://github.com/reportportal/service-ui/blob/5.15.3/app/src/components/main/markdown/markdownViewer/markdownViewer.jsx) renders Markdown, sanitizes HTML with DOMPurify, then parses HTML. Interpreting `<record>` as an HTML tag rather than literal prose explains the reported disappearance; deployment-version equivalence is not independently established here.

Basis: [M3A contract:17](/Users/nick/Documents/New%20project/docs/design/reporting-experience-m3a-implementation.md:17) deliberately keeps source descriptions unbounded and unsubstituted. That boundary explains why the value is not replaced with a dataset value; it does not explain away loss of the literal placeholder from visible prose. This is a tester-facing presentation defect, not evidence that DataTable/DocString substitution, localized keywords, Background scope, or statistics are broken. Existing request-string tests prove raw bytes, not visible literal fidelity in Markdown.

Request to Master: retain raw AST metadata and the no-substitution identity/design boundary, but decide an explicit description presentation policy. Prefer escaping known literal outline placeholder tokens at the Markdown presentation boundary, with idempotent handling for already escaped text, rather than globally escaping all prose (which would break intended Markdown tables/links). Keep M3C appending references without undoing presentation safety. Add English/Chinese placeholder rendering checks, prose with existing Markdown, and feature/Rule/Examples descriptions where applicable. If byte-exact wire prose intentionally takes priority over visible literals, document this renderer limitation prominently and obtain explicit scoped acceptance; do not count raw-byte preservation alone as complete readable-description acceptance. No SDK edit was made.

## Review Scope And Evidence

Reviewed frozen SDK and specs in `/tmp/m2m3-regression-20261009-candidate`, current repository README, the v1.2 plan, and M2/M3 implementation contracts. Historical PASS headings were not used as proof. No other agent's regression report or conclusion was used. For F8 only, official pinned UI source was fetched read-only to verify the Markdown/HTML rendering boundary. The user's coordination update reports local10 255 + randomized 255, runtime9 239/focused123 with a separate require-collection issue, and Master live M2/video and M3A checks; these are not independently rerun or treated as proof against the adversarial findings.

Repository observed: `/Users/nick/Documents/New project`, branch `codex/reporting-experience-v1-2`, HEAD `d9688b74a177cb359747fcd81e599d3528e9f3c3`. Read-only `diff -qr` found candidate/root `lib` identical and `spec` identical except an extra root `.DS_Store`. Existing dirty files, duration work, Git state, configs, and infrastructure were left untouched. Frozen SDK/spec line references above also locate byte-equal overlay code, but they intentionally identify the reviewed snapshot.

Probe artifacts: [adversarial_probe.rb](/tmp/m2m3-regression-20261009/review/adversarial_probe.rb), [pinned output](/tmp/m2m3-regression-20261009/review/probe-10.2.0.txt), [no-RP failure](/tmp/m2m3-regression-20261009/review/no-rp-10.2.0.txt), [explicit-World control](/tmp/m2m3-regression-20261009/review/no-rp-with-adapter-10.2.0.txt), and synthetic NDJSON under `/tmp/m2m3-regression-20261009/review/spool/`. The fake-buffer formatter probe uses actual validation/rendering/enqueue code without constructing network clients or lifecycle event subscribers; spool code is invoked directly on those records. It proves message/spool contents, not successful server delivery.

Pinned probes use Ruby 3.4.2 and Cucumber 10.2.0. Cucumber 9.2.1 activation failed because installed cucumber-core 13.0.3 requires absent cucumber-gherkin 27.x; [failure output](/tmp/m2m3-regression-20261009/review/probe-9.2.1.txt) is an environment gap, not an SDK failure. Initial unpinned exploration is not version acceptance. Plain `bundle` in the frozen cwd resolved to system Ruby 2.6 without Bundler 2.6.6; explicit Homebrew Ruby was used rather than changing dependency/configuration state.

Reproduce the short pinned module probes from the review directory:

```bash
cd /tmp/m2m3-regression-20261009/review
/opt/homebrew/opt/ruby/bin/ruby adversarial_probe.rb
```

Reproduce the native no-RP probe with the documented setup; adding the separate `explicit_world_adapter.rb` require is the control, not an edited expectation:

```bash
/opt/homebrew/opt/ruby/bin/ruby -I /tmp/m2m3-regression-20261009-candidate/lib \
  -e 'gem "cucumber", "10.2.0"; require "cucumber/cli/main"; exit Cucumber::Cli::Main.new(ARGV).execute!' -- \
  /tmp/m2m3-regression-20261009/review/features/no_rp.feature \
  --require /tmp/m2m3-regression-20261009/review/support/no_rp.rb \
  --format progress --publish-quiet
```

No full suites, real browser capture, gem installation, live ReportPortal calls, RP UI, shared launch, or production configuration operations were performed. Test executor A retains regression execution ownership; Master retains physical RP acceptance.

## AC Coverage Matrix

`Source/spec` means code and existing test assertions inspected, not executed or independently PASS-certified. `Probe` means the short checks above actually ran. M3B/C rows name contract dimensions because those contracts do not define a numbered AC list. No all-PASS inference is made.

| AC / Contract | Independent Basis | Assessment / Remaining Gate |
| --- | --- | --- |
| M2-01 failed locator + supplied screenshot/console | Source/spec: World, formatter, M2 API-ordering and subprocess assertions | Explicit UUID ownership design is reasonable; real Playwright capture/rendering not exercised here. |
| M2-02 no artifact | Source/spec + formatter probe with no attachments | Summary enqueues without fabricated file; F1 affects its safety. |
| M2-03 retries/next Step/invalid handles | Source/spec: frozen capabilities, registry membership, closed/foreign rejection, retry specs; probe false target | F4 fails one invalid-handle branch; closed capabilities do not intentionally retarget. |
| M2-04 Before/After/manual Step | Source/spec: registration on native actions/hooks/manual items, close/flush before finish | Reasonable common-path ordering; hook/manual native lifecycle not rerun here. |
| M2-05 concurrent scenarios/helpers | Source/spec: thread-local stacks/runtime, mutex registry, explicit capability owner recovery, concurrent test assertions | Evidence registry isolation is sound in inspected paths; arbitrary asynchronous Cucumber event dispatch and all formatter maps are not certified thread-safe. |
| M2-06 original exception priority | Source/spec: rp_evidence rescues StandardError with class-only warnings, caller re-raises; README capture catch | New evidence call degrades safely under ordinary errors; protect all framework capture operations. Legacy strict rp_step/finalization behavior is not a blanket original-error guarantee. |
| M2-07 files/bytes/MIME | Source/spec: bounded IO read 1 MiB + 1, 1 MiB rejection, path descriptors, 16 KiB + 1 previews, multipart chunks/tempfile | No new whole-file preview read identified; large-file RSS not measured. Files must survive queue/upload; declared/name-derived MIME is not content authentication. |
| M2-08 cross-sink privacy | Probe: presenter, AppLog sinks, real formatter queue, actual spool | FAIL for F1. Generic raw attachment/legacy logging sanitization is not promised. |
| M2-09 assertions | Source/spec + native-World/RP-fallback probe | Diagnostic-only, expected/actual Markdown, no deliberate assertion raise; F1 invalidates privacy sign-off. Output callback failures still need caller protection. |
| M2-10 legacy/no-RP/regression | Source/spec: legacy signatures/routes; native no-RP probe | F5 setup gap. Full RSpec/Cucumber and installed-gem regression not executed by this reviewer. No Playwright dependency added. |
| M3A-01/03 Rule/localized AST | Source/spec: official Gherkin AST and EN/zh-CN fixtures | Scope and no-extra-Rule-item implementation reasonable; localized CLI fixture not rerun. |
| M3A-02/04 multiple Examples rows | Source/spec: source-line index and row-specific examples/tags/values | No row scope conflation found; F6 covers unrepresented Examples prose. |
| M3A-05/06 compiled DataTable/DocString | Source/spec: runtime text/multiline arguments ahead of source, trailing cells, pipe/backslash/newline escapes, fence selection | Reasonable bounded representation; no physical renderer or all-language matrix exercised. |
| M3A-07 Background + hooks | Source/spec: source-node line matching, distinct duplicate text, unique-text fallback | Correct scope strategy; no new Background statistical item. |
| M3A-08 topology/order/count | Source/spec: Suite true -> Scenario STEP true -> actions/hooks false; outbound fixture assertions | No TEST remap or statistics mutation identified. Counts/order require executor run and Master physical gate. |
| M3A-09 bounded/fallback/descriptions | Source/spec: bounded UTF-8 action content/fences, AST fallback, untouched existing prose in link helper; prose/real Chinese payload probes + pinned UI source | F6 incomplete Examples prose and F8 invisible literal placeholder. Feature/Scenario source prose intentionally is not size-clipped like action previews. |
| M3B legacy default | Source/spec: Config default legacy, formatter leaves legacy builders/parameter order in place | No intentional default history migration found. |
| M3B canonical dataset identity | Source/spec + positive canonical nested/parameter-order probe | Equivalent values/order produce identical detached frozen wire parameters/IDs; every parameter participates, including volatile ones. |
| M3B source edits + explicit IDs | Source/spec: no line in stable hash, explicit seed, Rule/source-name fallback, ambiguity warnings; path probe | F2 breaks equivalent path notation below root. Explicit seed avoids source naming/path identity, not server topology/name constraints. |
| M3B namespace/migration | Source/spec + current contracts | Opt-in new opaque baseline, no rewrite/backfill/merge; frozen namespace required. Raw TMS ID is not stable wire testCaseId. |
| M3B native history/retries | Source/spec: group key launch/parent/wire-name/uniqueId, fresh UUIDs, latest-outcome Suite aggregation + class-hook failures | Client logic is coherent; real server TestCaseHash/history/statistics not verified here. Identical datasets may collapse as retries by design. |
| M3C attributes off/allowlist/precedence | Source/spec: defaults -> Feature -> Rule -> Scenario -> executed Examples, scoped conflict fallback, sorted frozen output; custom-key probe | Defaults off and broad-to-narrow strategy reasonable; F3 breaks credential-key prohibition under custom allowlist. |
| M3C effective TMS selection | Source/spec: same explicit_test_case_id_for supplies identity, derived-only attribute and TMS link | ENV wins existing flat-tag selection; mapper does not independently choose scoped TMS. Colon/control/length policy may omit an attribute while identity remains selected. |
| M3C immutable Source/Examples row | Source/spec + positive space-path/row-link probe | Hex commit only, path confinement/encoding, row line selected; source files assumed to correspond to configured immutable commit. No Git checkout/commit verification performed by SDK. |
| M3C URL safety/CI/TMS encoding | Source/spec + unsafe access_token CI URL/encoded TMS positive control | Safe diagnostic enum, independent sibling fallback, bounded HTTP(S) destinations; not a universal secret detector or URL availability check. |
| M3C preserved prose/fallback | Source/spec + original-prose positive control, Examples-prose negative probe, real Chinese payload | Existing description bytes preserved by link helper; F6 ingestion omission and F8 literal rendering defect predate links. Unexpected optional metadata failures are nonfatal, including strict mode. |
| M3C no identity/type/statistics mutation | Source/spec: helper insertion points and on/off payload comparisons in specs | Attributes only on statistical Scenario, references only description; no new item/log/wire-link field or changed identity inputs identified. |
| Clean package / Cucumber 9 and 10 | Gem inventory + pinned 10.2.0 one-step probe; 9.2.1 activation failure | F5/F7 onboarding gaps. No version-matrix or installed-gem certification. |

## Practical QA Usage Assessment

| Tester Task | Classification | Practical Assessment |
| --- | --- | --- |
| AppLog diagnostic in same-thread helpers | Easy after setup | Around-scoped logger binding restores prior state with ensure. Without binding, report:true cannot create a World/report sink. Assertion does not replace a real test assertion. |
| Before/After/manual action evidence | Easy with RP enabled | Capture while that action is open. Use the capability rather than a raw UUID. Hooks remain non-statistical children in established topology. |
| Playwright Ruby 1.62 missing-locator evidence | Requires framework adapter | Framework owns Page/BrowserContext, screenshot/console collection, failure catch, retention, and cleanup. Installed 1.62 source exposes screenshot and console_messages; no real browser was run. Protect capture, mkdir, URL access, and reporting independently, then re-raise the original error. |
| Background/helper thread evidence | Requires framework adapter | Pass the original target explicitly and complete before action close. AppLog bindings are not automatically inherited by new threads/fibers; do not invoke native World event callbacks asynchronously without a supported framework contract. |
| Capture after Step or retry ended | Limitation | Closed target must be rejected, not moved to After/retry. Framework must capture during the open action; F4 requires triage for false sentinels. |
| Large exportable artifacts | Requires framework adapter | Prefer rp_evidence path descriptors or legacy rp_attach(path), retain file until delivery/spool completes, validate artifacts first. Binary content is explicit opt-in, not sanitized. AppLog(file:) native route still whole-reads files by documented legacy limitation. |
| Rejection/delivery status | Limitation | true means queued, not uploaded/rendered; false is aggregate rejection/unavailability, not an artifact-by-artifact reason. Generic class-only warnings protect privacy but make oversize/missing-file errors harder to diagnose. Adapter should surface a safe status to the tester without masking the original test failure. |
| Run without RP | Requires setup correction | AppLog native reporting works with World logger binding; RP DSL needs explicit World inclusion (F5). rp_evidence's false/no-export behavior is not a native evidence exporter; use framework/native attachment routes when RP is disabled. |
| Metadata flags | Easy for documented defaults | Identity legacy, attributes off, links off; the independent flags and basic env names are discoverable in README. Unsupported identity strategy/malformed attribute JSON fail configuration. Boolean parser accepts unknown truthy strings; metadata enabled with no configured links can produce no block and no useful configuration signal. Validate consumer configuration in CI. |
| Stable history in a monorepo | Requires framework/CI agreement | Freeze namespace and dataset semantics, use correct root/cwd layout (F2), choose explicit IDs for renamed source, and pilot migration. Equal client IDs alone do not certify native RP history grouping. |
| Source/CI/TMS navigation | Easy with supplied safe metadata | No provider autodetection. Full immutable commit recommended; source root must contain executing feature; spaces are encoded. CI supplies shared-launch coordination and run URL. Root defaults to cwd; outside-root files safely omit Source rather than invent a path. |
| Multiple reporters/stdout | Easy for basic lane; limitation for retry HTML | Give RP formatter a separate --out when sharing stdout with pretty/progress. AppLog terminal summary plus native pretty echo is not duplicate RP delivery. Inspected logger has an event-bus/direct-route guard. M3B contract explicitly excludes its native message/HTML retry lane on 10.2.0; do not turn that into a universal HTML compatibility claim. |
| Recording/video extension | Optional framework-owned | SDK does not own browser or recording lifecycle/capture policy. Existing explicitly selected attachment/MinIO link transport is not automatic capture. Access, codec, retention, and physical playback remain framework/deployment gates. |
| Installed gem onboarding | Limitation until triaged | README install is straightforward, but repo-relative demos/contracts are not a complete clean consumer recipe (F5/F7). A quoted cwd containing spaces is supported by Ruby path APIs; shell examples and CI scripts must preserve quoting. |

## M4 Boundary And Independent Verdict

The architecture is broadly reasonable for an incremental reporter: opaque frozen action capabilities, mutex-protected registry membership, explicit opt-ins, real AST metadata, detached canonical identity, description-only links, and unchanged `SUITE(hasStats=true) -> Scenario STEP(hasStats=true) -> actions/hooks(hasStats=false)`. No browser ownership or TEST remap is recommended. The findings do not justify weakening tests to match implementation.

Do not reclassify existing delivery limitations as newly discovered M2/M3 regressions: QueueProcessor retains an unbounded record array, flush/shutdown can drain all records in one count-unlimited batch, timeout/spool outcomes do not certify zero loss or exactly-once delivery, and joined-process completion/replay coordination remains M4. See [queue_processor.rb:43](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/service/queue_processor.rb:43), [queue_processor.rb:112](/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/service/queue_processor.rb:112), and [plan:24](/Users/nick/Documents/New%20project/docs/design/reporting-experience-v1-2.md:24). M2's target close prevents intentional late publication and invokes bounded flush, but a flush deadline is not proof that the server received every log before finish. CI, not this SDK review, owns shared Launch coordination.

Verdict: **HOLD unconditional M2+M3 release/acceptance sign-off; request Master triage, with F1 blocking privacy certification.** M4 implementation may be planned separately without pretending M2/M3 are all PASS or changing their topology/browser boundary. F2-F8 need correction or explicit scoped acceptance with tester-facing limitations. No automatic patch, commit, release, infrastructure change, or delegated work was made. Residual gates remain full executor regression, supported Cucumber 9/10 dependency matrix, clean installed-gem consumer setup, real Playwright-adapter failures, memory measurements, and Master's physical RP history/statistics/description/evidence review.

## Continuation Review

### Early Handoff To Master: F1 Confirmed P1 Blocker

Independent continuation on 2026-10-09 confirms F1 through normal native Cucumber 10.2.0 execution and the public World DSL, not merely a presenter/helper call. **HOLD unconditional M2 privacy and M2+M3 release sign-off.** The reviewer is independent of Master/test execution, not an external certification institution. No SDK fix is applied or requested automatically.

Homebrew `/opt/homebrew/opt/ruby/bin/ruby` (3.4.2) runs the frozen candidate. [Isolated runner](/tmp/m2m3-regression-20261009/review/continuation/run.rb) and [support](/tmp/m2m3-regression-20261009/review/continuation/support.rb) instantiate the real formatter through Cucumber CLI, register actual native steps/World capabilities, and retain real LogBuffer, QueueProcessor, API, and payload models. Only HTTP I/O is substituted with offline synthetic responses/failure; enqueue observation calls `super`. No formatter allocation, direct private spool invocation, fake World, network request, real credential, browser, full RSpec rerun, or agent spawn is involved.

Both `normal-relative-v2` and `spool-absolute-v2` complete one Scenario/two Steps with exit 0. In [normal trace](/tmp/m2m3-regression-20261009/review/continuation/normal-relative-v2/trace.ndjson), public `rp_evidence` returns true and its real enqueue/API log messages retain `CONT_URL_PASSWORD_`, `CONT_JSON_DETAILS`, and `CONT_JSON_ERROR`. Intact-input redactor controls and short URL/escaped-JSON controls remove their credentials. In [failure trace](/tmp/m2m3-regression-20261009/review/continuation/spool-absolute-v2/trace.ndjson), the substituted HTTP log error naturally sends those same records to two ordinary NDJSON spool files. This is generated diagnostic text, not unsanitized opt-in artifact bytes, and proves clipping destroys syntax before redaction. Native assertion sink confirmation and final scope/priorities follow below; no deployed-server delivery/GUI acceptance is claimed.

Early handoff was also emitted in commentary. The app messaging API refused a message to the native ancestor; this shared report is the durable handoff, not a claim that a direct message was delivered.

### F1 Final Confirmation And Sink Boundaries

The additional tiny native-message runs resolve the remaining sink question. [RP-enabled native messages](/tmp/m2m3-regression-20261009/review/continuation/native-rp-v2/native.ndjson) and [no-RP native messages](/tmp/m2m3-regression-20261009/review/continuation/native-no-rp-v2/native.ndjson) each contain one actual `text/x.cucumber.log+plain` assertion attachment, 16,384 bytes, with `CONT_JSON_DETAILS` and a real native `testStepId`. Their terminal summaries also retain that canary. With RP enabled, the same assertion is enqueued once on the first real Step and reaches the real API's serialized log batch; the native log/direct-RP guard does not sanitize it. The no-RP control explicitly registers the SDK World module, so it tests assertion delivery, not the disputed F5 setup recipe. The assertion uses a long JSON diagnostic name and actual value, both accepted public fields; this terminal example does not mean an ordinary short assertion name leaks a secret supplied only in `actual` into its terminal summary.

The lightweight envelope-only observer in the earlier runs recorded zero attachments because Cucumber's native formatter attachment callbacks are a separate route. That zero is not evidence that native output is safe or absent. The real `message` formatter, without patching World/log/attachment behavior, supplies the confirmation above. All four final recorded runs exit 0; that means the diagnostic calls do not change Scenario outcome, **not** acceptance of privacy behavior.

The ordinary transport-failure spool contains seven records in two NDJSON files, `rawSpool` absent/false, including all three F1 canaries. The queue worker reaches it through normal `flush_batch -> safe_spool -> spool`; no private spool entry point is called. Real server delivery, raw fallback spool, and deployed GUI are not independently exercised in this continuation. F1 remains a P1 confidentiality blocker even when all regression examples are green: valid URL/JSON input is damaged by the 512/256/16-KiB input prefix before the redactor classifies it, and the subsequent formatter redaction cannot reconstruct the credential boundary.

### F2-F4 Conditional User Impact

**F2 [P2], confirmed native source-fallback identity defect.** Both native runs execute the exact same feature, Scenario name, and dataset from `/private/tmp/m2m3-regression-20261009/review/continuation`, with the same configured identity root `/private/tmp/m2m3-regression-20261009/review` and namespace. Cucumber emits `features/canary.feature` in one invocation and the same file's absolute URI in the other. The source-root-relative path should be `continuation/features/canary.feature`; the relative URI instead resolves as root-relative. Actual wire `testCaseId` values are `rp:stable-v1:02042799022698e0dfd5df11bad02dded704a200d457c3a55880b43d4489845d` and `rp:stable-v1:77641acdc4812fce38e771559159e1cbb41b975cc370eadb056bfc0dfcf69efa`, with different `uniqueId` values. The log-transport failure in the second run happens after Scenario identity publication and is not an identity input.

Affected scope is opt-in `stable_v1`, without an explicit ID seed, when native relative URIs are cwd-relative and cwd differs from identity root. This splits one case's identity/history key across CLI notation or monorepo working directories; potential same-named module collisions are an inference from the incorrect path mapping, not an independently observed server-history collision. It does not invalidate legacy IDs, explicit-seed stable identities, or the canonical dataset algorithm. Using correctly normalized absolute runtime URIs or an identity root equal to execution cwd avoids this particular mismatch. No SDK correction or history migration is performed; migration effects need deliberate Master triage.

**F3 [P2], confirmed custom-allowlist safety-policy bypass.** The real Config consumes `RP_SCENARIO_ATTRIBUTES_ENABLED=true` and `RP_SCENARIO_ATTRIBUTE_KEYS=access_token,client_secret,refresh_token,x-api-key`. Native scoped tags with four synthetic values then appear verbatim in the actual Scenario item-start attributes; this is not just a standalone mapper result. Preconditions are explicit attribute enablement, an unsafe custom allowlist, and caller-supplied credential-like values in tags/defaults. Default allowlist and disabled attributes do not reproduce this case. The SDK does not read credentials from the environment or browser for this finding. The defect is that common credential aliases, already recognized by EvidenceRedactor, escape the separate exact reserved-name list despite the M3C contract's prohibition. Its output surface is Scenario business attributes, not a claim of credential leakage through every M3C link, diagnostic, or item type. Retain P2 because the opt-in custom configuration materially limits exposure; resolve the policy or explicitly accept a narrowed contract rather than treating unsafe aliases as approved simply because they were allowlisted.

**F4 [P2], confirmed explicit-false retargeting only.** The first real Step captures an opaque frozen target. On the next real Step, `target: false` returns true and queues `false-sentinel` under the next Step's UUID; `nil-current` goes to that same UUID as intended. Supplying the genuinely closed first-Step capability or `Object.new` returns false with no evidence record. The current Step UUID differs from the original target's UUID. A framework adapter's false capture sentinel can therefore silently attribute evidence to a later action instead of rejecting it. This does not prove arbitrary closed/foreign handles retarget, nor does it show Scenario/Launch fallback. The boundary is the formatter's `target || capture_target` branch; only `nil` is promised as implicit current. A narrow API regression test/fix decision is warranted, not redesign of capability ownership or browser lifecycle.

### F5-F8 Scope And Priority Triage

The original findings/evidence remain intact. The continuation does not rerun or expand them into new issues; the following scoped triage supersedes any implication that all seven original P2s are unconditional release blockers.

| Finding | Final Priority / Basis | Acceptance Scope |
| --- | --- | --- |
| F5 no-RP World setup | P2, documented consumer setup fails before the promised disabled fallback is reachable; prior native failure/explicit-registration control retained. | Documentation/registration integration, not failure of `rp_capture_target` once the World module is included. RP formatter setup and ordinary AppLog native logging are separate working paths. Protecting `mkdir_p` in the browser example is caller-error-priority guidance, not a newly reproduced SDK failure. |
| F6 Examples prose | P2 if preserved executed-block prose is in tester acceptance; actual native Scenario description again lacks `CONT_EXAMPLES_PROSE`, while retaining Scenario prose, Examples name/row/table. | M3A ingestion completeness and overbroad example documentation, not proof that M3C overwrites an already built description or loses compiled DataTable/DocString content. Master may explicitly document/accept exclusion instead of requiring an artificial overall failure. |
| F7 unshipped design docs | P3 in this continuation, a packaging/navigation debt established by gemspec inventory; original P2 retained historically above. | Relative migration/contract links in the installed README are not packaged. No built-gem installation/navigation test or broken runtime is claimed. Repair or explicitly accept the documentation delivery gap; not an independent privacy blocker. |
| F8 raw placeholder rendering | P2 presentation fidelity, not a security/XSS or topology finding. Original Chinese AST/wire probe retained; native continuation also leaves raw `<case>` prose on the wire. | Source/wire behavior independently confirmed; the disappearing literal in M3A38 and `browser/m3a-scenario-description.jpg` are Master's supplied GUI evidence, not this reviewer's own GUI observation. Preserve raw AST/no-substitution semantics while choosing a documented Markdown presentation policy; a scoped renderer limitation can be accepted explicitly. |

Master's reported Launch 36 M2 core evidence, Launch 37 real video native Play/seek, and Launch 38 DataTable/DocString/Background checks are not recast as this reviewer's physical acceptance. They are compatible with the conditional defects above and do not invalidate F1. Pending/current Master M3B/C physical checks remain owned by Master.

### Root Line Calibration

The frozen/root `lib/spec` bytes match, so the original frozen source locations map to these verified root locations without a line offset. Documentation references were independently calibrated rather than inferred from file equality.

| Finding | Verified Root Anchor |
| --- | --- |
| F1 | [EvidencePresenter error prefix:26](/Users/nick/Documents/New project/lib/reportportal_cucumber/service/evidence_presenter.rb:26), [URL prefix:27](/Users/nick/Documents/New project/lib/reportportal_cucumber/service/evidence_presenter.rb:27), [string details:74](/Users/nick/Documents/New project/lib/reportportal_cucumber/service/evidence_presenter.rb:74); [formatter re-redaction:149](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/formatter.rb:149), [real enqueue:153](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/formatter.rb:153), [ordinary spool:243](/Users/nick/Documents/New project/lib/reportportal_cucumber/service/queue_processor.rb:243). |
| F2 | [relative expansion:231](/Users/nick/Documents/New project/lib/reportportal_cucumber/service/scenario_identity.rb:231), [formatter native URI forwarding:1037](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/formatter.rb:1037). |
| F3 | [reserved keys:9](/Users/nick/Documents/New project/lib/reportportal_cucumber/service/scenario_attributes.rb:9), [exact-name rejection:124](/Users/nick/Documents/New project/lib/reportportal_cucumber/service/scenario_attributes.rb:124), [real formatter attributes:1102](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/formatter.rb:1102); [credential-name contract:36](/Users/nick/Documents/New project/docs/design/reporting-experience-m3c-attributes-implementation.md:36), refining the original contract:34 paragraph anchor. |
| F4 | [false-to-current selection:131](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/formatter.rb:131), [public World dispatch:69](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/world.rb:69). |
| F5 | [consumer require:247](/Users/nick/Documents/New project/README.md:247), [disabled fallback promise:298](/Users/nick/Documents/New project/README.md:298), [capture example:303](/Users/nick/Documents/New project/README.md:303), [formatter-only injection:339](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/formatter.rb:339). |
| F6 | [metadata Examples name only:58](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/ast_metadata.rb:58), [Examples description assembly:1277](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/formatter.rb:1277), [prose promise:24](/Users/nick/Documents/New project/examples/m3c_links/README.md:24). |
| F7 | [package inventory:21](/Users/nick/Documents/New project/reportportal-cucumber-ruby.gemspec:21), [actual migration link:140](/Users/nick/Documents/New project/README.md:140), correcting the original README:142 blank-line anchor; [attribute link:156](/Users/nick/Documents/New project/README.md:156), [links contract:168](/Users/nick/Documents/New project/README.md:168). |
| F8 | [raw Scenario description:1272](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/formatter.rb:1272), [raw AST extraction:55](/Users/nick/Documents/New project/lib/reportportal_cucumber/cucumber/ast_metadata.rb:55), [actual Chinese fixture:36](/Users/nick/Documents/New project/spec/fixtures/m3a/zh-CN.feature:36). |

### Source Integrity And Evidence Ledger

[Pre manifest](/tmp/m2m3-regression-20261009/review/continuation/source-pre.json) and [post manifest](/tmp/m2m3-regression-20261009/review/continuation/source-post.json) are byte-identical. Each includes SHA-256 values for 84 non-hidden regular files across frozen `lib/spec` and 84 across root `lib/spec`. Both trees' sorted inventory digest is `79c6f8f1c7991ee4d77786eb06aaa26d630e220132e50e6a39b37235e13f2c78`. Both manifest-file digests are `4cea37a120f331958cec0ac68395766095147e4786d4c9d6fc0fbebae5a63809`. Independent pre/post `diff -qr` finds no `lib` differences and only root `spec/.DS_Store`; that hidden metadata is excluded from the manifests. These hashes cover SDK/spec source, not a claim that the whole dirty repository or all documentation is frozen.

[Machine-derived summary](/tmp/m2m3-regression-20261009/review/continuation/summary.json) records exact IDs, attributes, enqueue ownership, controls, ordinary-spool paths/records, native attachments, terminal canaries, exit codes, and source digests. Each run directory retains its command/environment JSON and stdout/stderr. All credentials and transport failures in these artifacts are synthetic. The first formatter preparation attempt failed because the isolated YAML path did not exist; its `normal-relative`/`spool-absolute` outputs are retained and not counted as product failures or successful reproductions. The isolated snapshot script's initial syntax typo was fixed before the captured pre manifest. An initial native no-RP run also exited 0. No original review artifact was overwritten or rerun.

Continuation runtime is explicitly Homebrew Ruby 3.4.2, Cucumber 10.2.0; all new artifacts are confined to `/tmp/m2m3-regression-20261009/review/continuation`, except this authorized report append. No full regression suite, real RP endpoint, browser action, gem installation, SDK/spec/config patch, Git commit, infrastructure operation, automatic fix, new task, or delegated agent was performed. Existing dirty project work remains untouched. The prior Cucumber 9 dependency failure is read as historical evidence only, not reproduced or broadened into a new finding.

### Final Continuation Verdict / Master Handoff

**CONFIRMED HOLD. F1 remains the independently reproduced P1 release/privacy blocker.** F2/F3/F4 are confirmed conditional P2s on actual public/native formatter paths, with the limited scopes above; F5/F6/F8 require scoped correction or explicit acceptance, and F7 is non-blocking P3 documentation delivery debt in this continuation. No blanket acceptance or external certification is issued. A green executor regression and Master's real GUI checks establish their respective evidence only; they cannot cancel the synthetic-canary privacy counterexample. Master has acknowledged reading the F1 handoff and its blocking status. This review-only task is closed without SDK modification; Master owns release triage, any separately authorized remediation, and remaining physical M3B/C acceptance.
