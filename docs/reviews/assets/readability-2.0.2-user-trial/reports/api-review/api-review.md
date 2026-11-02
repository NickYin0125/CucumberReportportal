# SDK 2.0.2 independent API usability re-review

Date: 2026-11-02. Live evidence was captured for the Master-supplied candidate `9bf3356cff350d8e2ba11bad1c33aa89881ac456`. Master subsequently identified final source head `d1725d3ab9e796c008fe9e80a11ea0ce29bde762` and attested that runtime, examples, Gemfile and gemspec are identical, with follow-up changes limited to CI and one integration assertion. That equivalence was not independently inspected or rerun; the evidence is not relabeled as a new-head execution. This is an independent consumer usability recheck of my six original findings, not SDK implementation review or release certification.

## Findings and dispositions

**Four original issues are fixed; two are partly fixed. No original issue is silently waived. R02 remains not fixed by explicit owner choice.**

| Original issue | Disposition | Residual concern |
| --- | --- | --- |
| API01 Automatic exception evidence disappears, S2 | PARTLY FIXED | Class and source/backtrace restored; metadata exception message still withheld in both modes. Multiline-string exception restored. |
| API02 Small object comparison hides actual value, S3 | PARTLY FIXED | Missing-key summary is immediately useful, but the unchanged own Hash comparison still clips actual until expanded. |
| API03 Passing negative example advertises assertion failure, S3 | FIXED | Ordinary INFO observation, no Error Logs, real status/body assertions retained. |
| API04 Sample logs full response twice, S3 | FIXED | One HTTP card per inspected request; redundant snapshot removed, useful input/assertions retained. |
| API05 HTTP preview limits unspecified, S3 | FIXED for the operational documentation gap | HTTP-specific shared limit, marker and explicit full-body route are documented; no worked before/after clipping example or runtime boundary test. |
| API06 Unexplained version/internal terms, S4 | FIXED | Ambiguous terms absent in reviewed public guides; SDK and infrastructure versions distinguished. |

### API01 Partly fixed automatic exception evidence

The old report recorded complete omission at plain logs 20177/20189 and rich 20408/20420. Those old artifacts were not reopened; my original report is the sole prior-finding baseline.

The metadata failure now retains `RuntimeError`, the feature location, `helpers/world.rb:15`, project frames, and a full backtrace, but still says **Message withheld: unsafe or ambiguous input**. The business mismatch is understandable from the separate comparison and actual-response attachment. This is materially better than losing the entire exception, but not restoration of the ordinary synthetic exception message.

| Final Launch | Scenario | Failed step | Comparison | Automatic exception | Actual JSON attachment |
| --- | --- | --- | --- | --- | --- |
| 3849 plain | 31692 | 31695 | 21110 | 21111 | 4979, log 21109 |
| 3851 rich | 31842 | 31845 | 21302 | 21303 | 4984, log 21301 |

The second original failure, two-line expected text versus `line one`, now retains its actual RuntimeError message and source: plain Launch 3849 / scenario 31697 / step 31700 / comparison 21120 / exception 21121; rich Launch 3851 / scenario 31847 / step 31850 / comparison 21312 / exception 21313. The unchanged own Hash case still retains exception context at Launch 3847 / scenario 31585 / step 31587 / log 20961, although its heading abbreviates the long message. All these cases remain FAILED.

Four corresponding ERROR messages are **byte-identical** between final plain and rich: 21110=21302, 21111=21303, 21120=21312, 21121=21313. This was checked on persisted message strings, without normalization, not inferred from screenshots. Stack Trace shows raw Markdown but no new rich HTML decoration in these cases. Full comparison hashes are in [verification.json](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/verification.json).

Evidence: [plain logs 31695](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/logs-31695.json), [rich logs 31845](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/logs-31845.json), [plain Stack Trace](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/plain-contract-stack.jpg), [rich Stack Trace](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/rich-contract-stack.jpg), [plain restored multiline failure](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/plain-multiline-stack.jpg), [rich restored multiline failure](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/rich-multiline-stack.jpg).

![Class and source restored, metadata exception message still withheld](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/rich-contract-detail.jpg)

### API02 Partly fixed small-object readability

The old assertion was log 20508 in Launch 3842. Its unchanged final counterpart is **Launch 3847, scenario 31585, Then 31587, assertion 20960**, with field-delta attachment **4975** on log **20959**.

At the actual 1504 x 710 review viewport, the unexpanded card shows `missing in actual: difficulty` immediately. However, its expected object is faded midway and the actual line is not initially visible. Clicking the small down-chevron reveals the complete expected and actual values. The new summary successfully explains this failure without expansion, but the original comparison visibility defect is mitigated rather than eliminated. Complete actual data is present in the API and after UI expansion, so this is not transport loss.

Evidence: [exact logs](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/logs-31587.json), [before expansion](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/own-contract-clipped.jpg), [after expansion](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/own-contract-expanded.jpg).

![Missing-key summary is visible but actual still requires expansion](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/own-contract-clipped.jpg)

### API03 Fixed misleading negative example

Old misleading diagnostic logs 20062/20293 are replaced by ordinary INFO observations: **Launch 3849, scenario 31617, step 31626, log 21012** and **Launch 3851, scenario 31774, step 31779, log 21211**. Both actual UIs say **PASSED** and **No Error Logs**.

Expected HTTP 400 remains INFO at plain step 31620/log 21006 and rich step 31776/log 21207. Real status assertions remain at 31622/21008 and 31777/21208; response-field assertions remain at 31624/21011 and 31778/21210. The consumer [step code](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/features/step_definitions/api_steps.rb:23) still calls the actual comparison helper, which raises on mismatch. Removing the erroneous optional assertion card did not remove the business assertions.

Evidence: [plain diagnostic logs](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/logs-31626.json), [rich diagnostic logs](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/logs-31779.json), [plain UI](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/plain-negative-detail.jpg), [rich UI](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/rich-negative-detail.jpg), [rich expected-400 card](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/rich-negative-http.jpg).

### API04 Fixed duplicated full response

Old sample pairs 20022/20023 and 20253/20254 had an HTTP card plus a redundant full response snapshot. Final passing POST actions have exactly three records:

| Launch / scenario / step | Complete log list | Result |
| --- | --- | --- |
| 3849 / 31593 / 31595 | 20966 DocString, 20967 DEBUG send, 20968 HTTP | One response card; no snapshot |
| 3851 / 31756 / 31758 | 21176 DocString, 21177 DEBUG send, 21178 HTTP | One response card; no snapshot |

The single cards retain method, URL, expected/actual status, timing, both bodies, and headers. Rich header controls expand correctly, with ordinary media-type text and one name/value per line. Assertions remain under Then. The unchanged own requests remain single logs: Launch 3847, POST step 31582/log 20953 and GET step 31586/log 20956. These are bounded observations of the inspected exchanges, not an exactly-once delivery guarantee.

Evidence: [plain complete action logs](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/logs-31595.json), [rich complete action logs](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/logs-31758.json), [plain expanded card](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/plain-post-expanded.jpg), [rich expanded card](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/rich-post-expanded.jpg), [rich headers](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/rich-post-headers.jpg).

### API05 Fixed operational HTTP-limit documentation

[Best practices line 130](/Users/nick/Documents/crr-2.0.2/docs/best-practices.md:130) now explicitly gives `AppLog.http` a **shared 16 KiB / 100 lines** budget across bodies and headers. It states redaction precedes clipping, gives the literal `[preview truncated]` marker, explains response-first RP ordering and tells the consumer to attach a redacted file when the full body matters. This no longer requires guessing whether the separate `rp_attach` limit applies.

This fixes the original operational-information gap. There is still no worked before/after truncated-output example; the inline marker is the only small output illustration. No large-body boundary experiment was run, and this disposition does not certify the implementation of the documented thresholds.

Evidence: final document checksum and numbered excerpts in [verification.json](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/verification.json). Launch/item/log IDs and RP screenshots are **N/A: documentation-only finding**, not missing runtime evidence.

### API06 Fixed onboarding terminology

`AppLog 1.3.1` and `pre-Ledger` have no matches in the reviewed README, getting-started, best-practices, configuration and advanced-reporting documents. [Best practices line 96](/Users/nick/Documents/crr-2.0.2/docs/best-practices.md:96) describes AppLog behavior directly. [Configuration line 123](/Users/nick/Documents/crr-2.0.2/docs/configuration.md:123) says original safe fallback text instead of requiring internal Ledger vocabulary. [README line 10](/Users/nick/Documents/crr-2.0.2/README.md:10) identifies the unpublished SDK 2.0.2 candidate and [line 20](/Users/nick/Documents/crr-2.0.2/README.md:20) separately versions Helm/ReportPortal.

Evidence: scoped term-search results, numbered excerpts and unchanged preparation-to-final document hashes in [verification.json](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/verification.json). Launch/item/log IDs and RP screenshots are **N/A: documentation-only finding**.

### N01 Newly recorded usability limitation in small HTTP cards

**S3, RP UI row clipping interacting with the client card layout; not established as a new 2.0.2 regression.** The response-first order makes the outcome easier to see, but even the 20-byte request / 33-byte response POST has its request body hidden by the generic row-height fade. The investigator must expand the whole log; rich headers then have their own disclosure controls. There is no data loss, and the supplied DocString also contains the input, but reading a complete exchange requires recognizing this extra control.

Exact evidence: plain Launch 3849 / step 31595 / log 20968 and rich Launch 3851 / step 31758 / log 21178. The expected-negative 11-byte request is similarly clipped at rich Launch 3851 / step 31776 / log 21207. Initial and expanded screenshots establish the interaction: [plain initial](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/plain-post-initial.jpg), [plain expanded](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/plain-post-expanded.jpg), [rich initial](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/rich-post-initial.jpg), [rich expanded](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/rich-post-expanded.jpg). Treat this as discoverability guidance and a possible compact-layout improvement, not a reason to restore duplicate snapshots.

## Owner tradeoff and adoption

### R02 remains not fixed

I directly checked **UI plain Launch 3850, scenario 31708, failed action 31710, passed After 31711**. The action retains the Playwright timeout at **log 21129**. After has exactly **one ERROR log 21130 with PNG attachment 4980**, containing the failure caption, last passed browser action and uniquely named PNG. The attachment opens successfully in RP.

With **Hide All Passed Logs off**, this entry is visible under passed After. With the filter on, its caption and PNG disappear while the After row remains PASSED; the visible error count drops from two to one. Turning the filter back off restores access. This is the owner-approved unresolved condition, not missing upload evidence or a fixed ownership API.

Evidence: [After raw log](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/logs-31711.json), [filter off](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/after-filter-off.jpg), [filter on](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/after-filter-on-collapsed.jpg), [PNG preview](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/after-png-preview.jpg).

Decision 27 deliberately trades the current example's native HTML failure PNG for this single RP caption-and-PNG entry, retaining a uniquely named local file and original native failure records by contract. The local screenshot filename exists in the supplied UI-plain artifact directory. **I could not independently verify native HTML rendering:** the browser policy rejected the local `file:` URL. I did not parse native reports, serve them through a workaround, or claim they were visually checked. The native screenshot omission is recorded as an intentional tradeoff, not an accidental regression; native failure-record preservation remains unverified in this re-review.

### Adoption decision

**Limited adoption with retained native/local evidence is reasonable for everyday serial API testing. Do not treat RP alone as the complete original failure record yet.**

The comparison summary, restored exception source/class, cleaner passing-negative example and removal of duplicated responses make triage noticeably better. All inspected API failures can be understood without rerunning because the comparison, HTTP evidence and source location complement one another. I still prefer rich for routine browsing: headers fold, successful outcomes are easy to scan, and ERROR content now stays plain.

Keep the original exception/native artifacts available when RP withholds or abbreviates a message. Teach investigators to expand clipped cards and disable Hide All Passed Logs when looking for After evidence. Consumers requiring native screenshots should deliberately choose the documented AppLog/native route instead of assuming the current sample still supplies them. No S1 was demonstrated; the partial exception fix prevents an unconditional approval as the sole investigation record.

The original minor onboarding friction remains: the three entry guides provide arithmetic smoke plus a GET recipe, with POST/PUT through a linked runnable example. No fresh install or human setup-time measurement was performed here, so the old 20-40 minute estimate is neither remeasured nor strengthened.

## Evidence scope and verification

| Launch actually collected | Purpose | Independently observed persisted result | Items / logs |
| --- | --- | --- | --- |
| 3849 | API plain, comparable to 3837 | 16 scenarios: 14 passed, 2 intentional failures | 97 / 141 |
| 3851 | API rich, comparable to 3839 | 16 scenarios: 14 passed, 2 intentional failures | 97 / 141 |
| 3847 | Unchanged own API tester, comparable to 3842 | 2 scenarios: 1 passed, 1 intentional failure | 10 / 10 |
| 3850 | Narrow R02/PNG routing observation only | Launch has 8 passed, 2 failed; one selected failure visually inspected | 53 / 51 |

Launches 3843-3846 are excluded from comparisons. UI-rich 3852 and UI-tester 3848 were not re-reviewed by this API reviewer. The four API-side independent input files were independently SHA-256 compared to their originals and are identical; Master's statement that all eight API/UI inputs match is not recast as my verification of the UI files.

The live-capture SHA, normal gem installation, Ruby 3.4.2, Cucumber 12.0.1, core 20.1.0 and Playwright 1.62.0 were supplied by Master. Rich/API-tester Launch attributes corroborate SDK/Ruby/Cucumber versions, and inspected failure logs name the installed 2.0.2 gem and Cucumber/core paths. I did not independently attest the gem archive back to the full Git SHA or inspect SDK implementation. Public-doc hashes recorded at the live-review stage match the preparation snapshots; source files were not reopened during offline completion.

I used one own authenticated Edge tab through CUA, RP UI build **5.15.6**, default screenshot size **1504 x 710**, All log levels and passed-log filtering off except the explicit R02 experiment. Initial/expanded states and times are recorded in [ui-captures.json](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/ui-captures.json); corresponding `.ax.txt` files preserve observed UI text. Screenshots are real browser captures, not reconstructions.

Read-only API collection used the opaque authorized key-injection launcher, without opening it or printing credentials. All 257 collected items had logs queried **by item**, with pagination retained in `logs-<item>.json`. There are 343 collected log records across the four Launches. The master raw file supplied item identities only; its Launch-level log collection was not used to infer missing logs. [read_evidence.rb](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/read_evidence.rb) and the per-Launch capture receipts describe this read-only collection. [verify_evidence.rb](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/verify_evidence.rb) checks my own evidence and allowed public/consumer inputs only.

No Cucumber executions were performed by this reviewer. No test result was produced by changing an assertion, fixture, helper or profile. No SDK edits, commits, pushes, tags, releases, credential-file reads or other reviewers' report reads occurred. Authored and generated artifacts are confined to this review folder. Not exercised: new boundary scenarios, failure injection, retries, parallelism, delivery completeness, attachment byte-for-byte download comparison, general privacy certification, fresh dependency installation, and native report rendering. Empty/whitespace assertion-label behavior was not separately exercised by the supplied API assertion cases; empty HTTP payload coverage is not misrepresented as that assertion test.

### Offline completion after the pause

The saved evidence inventory was validated without browser actions, API calls, new captures or test executions. Before report edits, **all 320 files in the original manifest matched their saved SHA-256 checksums**. The original manifest, API snapshots, screenshots, UI text and prior verification record remain unchanged. Only this report and the checklist were revised, with small offline-validation files added inside this review folder.

Saved pagination, item-parent relationships and log ownership reconcile to **257 items and 343 unique logs**. Seventeen critical log/item references and all four exact plain/rich ERROR-message comparisons were rechecked. All **23 JPEGs** report valid dimensions of **1504 x 710**; **22 indexed captures** have corresponding UI text. The additional `plain-contract-top.jpg` is the retained initial overview, not a substitute for the issue-specific screenshots. All own-folder report references resolve.

The [pre-edit validation](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/offline-baseline-validation.json) records the original checksums matching. The [offline validation receipt](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/offline-validation.json) records the final report/checklist fingerprints and the deliberately revised files; the original [evidence manifest](/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2/reports/api-review/evidence-sha256.json) is retained rather than rewritten.

**Conclusions remain unchanged:** four original issues fixed, two partly fixed; limited adoption with retained native/local evidence, and R02 not fixed. Applying the prior runtime observations to final source head `d1725d3` relies on Master's equivalence attestation, not fresh testing. The reported disk/Docker/RP outage is outside this usability evidence set: no cause, SDK regression, recovery or service health is inferred or certified.

Pending boundaries remain the native HTML visual check blocked earlier by browser policy, and any separately requested live follow-up after Master's explicit health clearance. Offline report completion does not authorize renewed live access or close those verification gaps. No commits or pushes were performed.
