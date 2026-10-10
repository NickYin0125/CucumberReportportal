# M4 Independent QA Review

Status: SCOPED PASS on final 30uRDE installed package and stated M4 journeys; IQ1-IQ6 closed by independent runtime repro. Earlier reds are retained below.
Date: 2026-10-10. Branch observed: `codex/reporting-experience-m4`.
HEAD observed: `c9eacad5f1320e84f9660a413ef307d39f48d2de` (dirty working tree).

## Final Scoped Verdict (2026-10-10 15:27 UTC)

**SCOPED PASS.** No remaining reproduced M4 P1, security P2, or user-facing
blocker in the evaluated cases. This verdict applies only to the exact final
artifact and stated Ruby 3.4.2 / native Cucumber 10.2.0 scope, not universal GA,
native Cucumber 9 certification, exactly-once delivery, or SIGKILL zero-loss.

Candidate: `/tmp/m4-20261010-candidate.30uRDE`.
Manifest SHA-256: `49607259f627ca6818c37e863ed4bc55a38ab271102a62818cd605135b8c2357`.
Exact gem SHA-256: `20a537c3cf708c0bf37191a3759fc962f2b9ce5b64c39c259c95a3ae31e0552e`.
Fresh normal installation used an independent GEM_HOME/consumer and cleared
inherited `RUBYOPT`, `RUBYLIB`, `BUNDLE_*`, and `RP_*`. SDK loading was through
RubyGems, without workspace `lib` injection. All 35 packaged libraries plus
the executable match the manifest; the package audit matches 131 known
packaged manifest files, including README and examples. Loaded SDK paths and
hashes match the fresh installed root: 33 direct/storage, 32 native, 32 live
reader. This does not falsely claim every library was runtime-loaded.

| Independent final installed execution | Actual result / evidence under `tmp/m4-independent-20261010/installed-v4/` |
| --- | --- |
| IQ1-IQ5, HTTP/CLI, cutoff/counter overlap, refusal/binding and replay/resume | 32 cases, 32 passed, 0 failed; `journeys/results.json` |
| Native Cucumber business/strict/automatic-warning and evidence ownership | 9 cases, 9 passed, 0 failed; `cucumber-journeys-v2/results.json` |
| Store publication/private modes, reserved names, concurrent quota, charged staging residue, checkpoint peak quota, actual replay-child kill/restart, tamper guards and IQ6 dry-run | 9 cases, 9 passed, 0 failed; `storage-journeys/results.json` |
| Total named final installed cases | **50 cases, 50 passed, 0 failed**; not the earlier 48-case claim |

IQ1 healthy real-Store attachment replay preserves owner/time/bytes; IQ2 reserved
and duplicate logical names remain recoverable; IQ3 symlink refusal leaves the
outside lock untouched; IQ4 resumed counts preserve confirmed siblings. IQ5 now
names `RP_SPOOL_MAX_BYTES` for all five invalid-value probes in API and installed
CLI, without raw values/paths; missing published blobs and checksum corruption
produce distinct safe reasons, exit 2, and no HTTP. IQ6 explicit/default dry-run
requires no credentials/HTTP, preserves checkpoints, reports exact unavailable
counts for one/mixed/1000-marker transactions with only `source_unavailable`,
and never fabricates bytes. Actual missing/corrupt published blobs still fail.

The installed README/help expose opt-in execution, duplicate consent, transaction
discovery, local durable versus server-confirmed outcomes, original open-target
policy, and unavailable-marker versus missing/corrupt-blob inspection semantics.
Strict remains exception-based: the actual log-only 503/strict case exits 0 with
`complete=false`; synchronous launch-finish 403 fails a passing business run at
exit 2, but retains the original intentional business failure at exit 1. The
packaged README now explicitly documents this distinction, not a new completeness
enforcement policy. Diagnostic/explicit Evidence privacy does not imply automatic
redaction of opted-in raw artifacts or logs.

Fresh independent read-only API reconciliation of Master-created Launch **47**,
UUID `41b91550-97b8-4f73-81a4-2b20489f8ae4`, confirms all 14 listed item UUID/numeric
bindings, 9 acknowledgement/log rows with owner/original time/message hashes, and
3 downloaded PNG SHA/CRC/decode checks. Statistics are 3 total, 2 passed, 1 deliberate
failure. Evidence: `package-live-read.json`; credentials stayed in process memory.
The affected packaged example contains `--no-profile` and its generated PNG is
valid. Only Config, Store, Replay and the CLI differ from LF0BhD's 36 runtime
fingerprints; no claim that the final SDK is identical to that earlier package.

Independent separate Edge tab 148296580 also inspected the exact Launch 47:
two suite rows with 3/2/1 totals; Scenario 1028's actual table and pretty JSON;
Scenario 1033's original deliberate error with failed Then and passed After Hook;
and original replay Scenario 1025's retained action evidence. All three native
passing/native failed/replay PNG modals were opened and visibly decoded at 80x40
(`complete=true`, positive natural dimensions), not inferred from HTTP 200. The
read-only QA tab was closed afterward. CUA observations are in this evaluator's
tool trace. Master's separately attributed screenshots are under
`/tmp/m4-final-ui/launch47-*.jpg`; the passing-filter selection is Master evidence.

Read the final handed-off gate receipts: core **211/0**, security **89/0**, full
**507/0**, seeded 20261010 **507/0**, named M2/M3 **80/0**, installed exit 0. These
are tester-run gates, not independently rerun suites or additions to the 50-case
count. Current final provenance and evidence hashes are consolidated in
`installed-v4/final-verdict.json`; reproduction uses `run-installed-final.rb`
with the three named own-scratch suites and `package-and-live-read.rb`.
Legacy `provisional_artifact` labels in two harness outputs are retained unchanged;
their exact package SHA and active installed-root guards identify the final gem.

Earlier v2/v3 failing results, initial evaluator harness/setup errors and source
probes remain retained, not relabeled green. Historical M3 findings, the native9
loader gap, accepted lossy reject-new/open-target/join/video limitations remain
outside scope. No production/spec/Git/infra changes, commits or tags were made.
Protected Gemfile.lock, Rakefile and cucumber.yml hashes still match their earlier
observations. There is no independent M4 QA hold remaining for this exact scope;
release/tag ownership remains with Master.

## Prior Installed Verdict (Superseded)

**HOLD, not a full M4/package PASS.** IQ1-IQ4 repairs are independently confirmed
in the freshly installed package. IQ5 remains reproduced and Master has accepted
its repair. IQ6 remains a locally known unavailable-artifact dry-run UX gap.
No further demonstrated P1 or security P2 was found in the executed cases.

Previously evaluated candidate: `/tmp/m4-20261010-candidate.wGrvJf`.
Manifest SHA-256: `83c33df5cf5a0ac1329f33a904e9b20322a3a53e580e2221f61926c6fd812225`.
Exact gem SHA-256: `55808c8882864ace4d963fe34c961afbdc6e71b10a613e2418be007014a7d1e1`.
Fresh normal installation and provenance: `tmp/m4-independent-20261010/installed-v3/installation.json`.
All 35 packaged SDK library files plus the executable match the manifest; the
36 hashes also exactly match LF0BhD's runtime, with no differing SDK paths.
The later package audit matches 128 known packaged files, including README and
the affected examples. All runtime SDK loads were checked against the fresh
installed root and expected hashes: direct/replay consumers load 33 SDK files;
native Cucumber consumers and the live reader load 32, not falsely claimed 35.

| Independent installed execution | Actual result / retained evidence |
| --- | --- |
| IQ1-IQ4 / J1-J5 HTTP, receipt and CLI cases | 32 cases: 27 passed, 5 failed option-label assertions, all manifestations of IQ5; `installed-v3/journeys/results.json` |
| Native Cucumber 10.2.0 business/strict/automatic-warning cases | 9/9 stated assertions passed; `installed-v3/cucumber-journeys-v2/results.json` |
| Store publication/private modes, direct reserved names, two-process quota, staging residue, checkpoint peak quota, actual replay-process kill/restart and tamper guards | 7/7 safety/observation cases passed; `installed-v3/storage-journeys/results.json`. Its unavailable-marker observation is the separate IQ6 UX finding, not UX acceptance. |
| Total named installed cases | 48 cases: 43 passed, 5 failed assertions; no all-green relabeling |
| Packaged changed example | `--no-profile` present; generated PNG CRC and zlib decode valid, SHA-256 `5b7a247dac8fc35737fe3485fd1242dfe15e9505f6b8eaba12c6065a85a4a5d2`; not itself browser-preview proof |

At this historical stage, `run-installed-final.rb` ran `installed-journeys.rb`,
`installed-cucumber-journeys.rb`, and `installed-storage-journeys.rb` with a cleared
environment and `installed-v3/installation.json`, never checkout SDK load paths.
The current runner selects v4; these prior v3 result files remain unchanged. Expected
business scenario exit 1 and strict metadata exit 2 are asserted outcomes,
not failed QA suites. Invalid quotas are rejected correctly; the five failures
are their misleading diagnostic labels, not acceptance of invalid limits.

Own read-only live reconciliation used the installed SDK and fresh HTTP reads
of Master-created Launch 46 (`238c43c8-bc86-4a36-a6cb-a02fd8bf958c`): all 14 listed
item UUID-to-numeric-row bindings, nine listed acknowledgement/log rows with
owner/time/message hashes, and three downloaded PNG byte hashes/CRC/decode
checks match. Launch execution statistics are 3 total, 2 passed, 1 intentionally
failed. Evidence: `installed-v3/package-live-read.json`. This is independent
reconciliation of the same live launch, NOT an independently created live run,
an exactly-once assertion, or a browser image-preview PASS. Master browser
evidence remains separately required.

The first read-only live-reader attempts failed due to the evaluator's restricted
PATH omitting `/usr/local/bin/kubectl` and then its use of nullable `query_uuid`
instead of the actual acknowledgement UUID. Their stderr is retained separately;
neither is classified as an SDK regression. Authentication stays process-only;
no credential, raw auth response or auth header is retained in these reports.

Full/seed 465/0 and other regression gates are handed-off Master/tester evidence,
not independently rerun or claimed here. Native Cucumber 9's historical loader
gap is disclosed, not certified as unadapted PASS. Historical M3 findings and
accepted reject-new/open-target/join/video limitations remain outside this verdict.
No production/spec/Git/infra edits or tagging were performed by this evaluator.
Protected workspace Gemfile.lock, Rakefile and cucumber.yml hashes still match
the preliminary observations; packaging/dependency edits by other agents are not
reverted or included in an evaluator commit.

Historical next gate, now completed above: fresh frozen post-IQ5/IQ6 package plus actual regression
receipts; rerun affected installed CLI/config/Store/replay and public cases on
that package, and review the exact live/browser identity before any scoped PASS.

## Preliminary Scope And Evidence (Historical)

Read the [M4 contract](reporting-experience-m4-implementation.md),
[M4A Master review](reporting-experience-m4a-review.md), and current README.
Read only the configuration surface as supplemental discoverability evidence.
Input hashes are retained in `tmp/m4-independent-20261010/preliminary-provenance.json`.
These are working-tree observations, not a frozen production/package identity.

M4A's accepted local/mock gates are reported by Master, not independently rerun
here. B/C/D remain unaccepted. No suite, installed consumer, replay, live API or
browser run was executed for this preliminary review. No PASS, zero-loss or
exactly-once claim is made. The unstable B implementation was not exhaustively
audited. Only this review and the allowed QA scratch directory may be written.

## Installed Interim Finding IQ5 (2026-10-10)

Fresh normal installation of handoff gem SHA-256
`9dbcb21e5960db140cb6d03d0c318e074ce72756d55193a9fbc70b3b0920f701`
verified all 35 library files plus `exe/reportportal-spool` against manifest
`a49c3c4cb98fde1474be956679173451829cb3dd04a69bb2ec585171fd2a4d33`.
Active SDK root is `tmp/m4-independent-20261010/installed-v2/gem-home/gems/reportportal-cucumber-ruby-1.1.0`.
Child environments omit inherited `RUBYOPT`, `RUBYLIB`, `BUNDLE_*` and `RP_*`;
only controlled synthetic test settings are added. SDK loading is by RubyGems,
never workspace `lib`. Package/example replacement is expected; no final
artifact verdict is made on this package.

### IQ5 / P2 Usability: Refusal Diagnostics Hide The Recovery Action

Installed source: `config.rb` positive-integer/spool validation and
`exe/reportportal-spool:10-25,66-68` error formatting.
Repro: run `run-installed.rb` with `installed-followup.rb`, or set
`RP_SPOOL_MAX_BYTES=0` on installed `reportportal-spool --spool-dir DIR
--transaction VALID_ID --dry-run`. Public Config correctly rejects `0`, `-1`,
`1.5`, `1e3`, `256MiB`, but misidentifies every error as
`Invalid ReportPortal queue configuration`. CLI further replaces that with
`Replay was refused or incomplete; inspect the selected transaction and local configuration`.
The same generic CLI refusal occurs for a checksum mismatch and a missing
attachment (independent J4 dry-run probes), without distinguishing those causes.
Expected: identify `RP_SPOOL_MAX_BYTES` and its positive-decimal requirement,
or a safe missing/corrupt-artifact reason and the need to recover original bytes;
never print raw values, payloads, credential data or local paths.
Impact: a QA operator cannot distinguish a fixable setting from unavailable or
tampered evidence without reading implementation details; this fails the agreed
actionable-failure UX gate. Refusal/no-HTTP safety is correct; this is not a quota
bypass or security disclosure claim.
Acceptance fix: preserve a bounded safe configuration-option label and Store
reason taxonomy in API/CLI errors; verify distinct reasons for invalid quota,
missing artifact and checksum mismatch while retaining privacy assertions.
Evidence: `installed-v2/followup-results.json` and
`installed-v2/journeys/results.json` under the independent scratch directory.

The first 32-case independent SDK exploratory run contains 26 passing checks
and six failed expectations: five are IQ5 option-label expectations; one was
an evaluator filename expectation, not a product failure (`.attachments-data`
is normalized by the normal batch builder to `.attachments-data.bin`, and CLI
execution succeeded). Retain this first report; do not relabel it all green.
Installed IQ1/IQ3/IQ4 and duplicate-name byte/owner reconciliation passed.
Broader J2/J6 and final replacement-package checks are still in progress.

### IQ6 / P2 Usability: Dry-Run Hides A Known Unavailable Artifact

Repro: public Store `persist` with a missing source `path` commits an explicit
`unavailable: true` artifact marker, as designed. Installed CLI `--dry-run`
returns exit 0, `pending=1, retained=true`, no unavailable-artifact field/reason
and empty stderr. `--execute` then refuses with `Transaction attachment is unavailable`
and sends no log POST. The operator can discover IDs and follow the prescribed
dry-run but cannot see that this record is already locally non-replayable.
Expected: retain dry-run's no-HTTP and schema-inspection semantics, but surface a
bounded unavailable-artifact count/reason before execute. Exit 0 may remain a
successful inspection if the summary clearly identifies the missing evidence;
do not fabricate empty bytes or fetch server targets in dry-run.
Acceptance fix: expose locally known unavailable artifacts in CLI dry-run,
and test both an explicit unavailable marker and a removed/corrupted published
blob. Evidence: `installed-v2/storage-journeys/results.json`, case
`J4_unavailable_artifact_marker_dryrun_observation`. This is a QA UX blocker,
not a new data-loss/security claim. Fresh-package confirmation is in progress.

### Strict Mode Policy Observation

Nine independent installed Cucumber/real-HTTP cases in
`installed-v2/cucumber-journeys-v2/results.json` passed their stated assertions.
With retry attempts explicitly one and a sufficient finalization budget, a
passing business scenario plus log-only HTTP 503 failure exits 0 even with
`RP_FAIL_ON_REPORTING_ERROR=true`: `spooled=3, ambiguous=3, metadata_failures=0,
complete=false`. A launch-finish HTTP 403 in strict mode exits 2 for an otherwise
passing scenario. When the original business assertion has already failed,
strict launch-finish failure preserves its marker and exit 1.
Master directs truthful documentation of this legacy exception-based scope,
not a new requirement to fail every incomplete receipt. Therefore no P1 is
claimed here and strict mode is NOT certified as whole-report completeness
enforcement. Consumers requiring that policy must explicitly inspect the final
receipt rather than infer it from this flag or the business exit.

The first Cucumber attempt retained under `installed-v2/cucumber-journeys/`
used an incorrect evaluator retry-option name and denied earlier item finishes
before the intentional assertion ran. Its two failed expectations do not
demonstrate assertion masking. The corrected nine-case run uses
`RP_HTTP_RETRY_ATTEMPTS=1` and faults Launch completion after the assertion.

## Historical Stage 1 Findings (2026-10-10 14:20 UTC)

These are actual current-source exploratory reproductions, not static risk
opinions or final-package acceptance. Ruby 3.4.2 loaded this workspace's SDK.
Both retained probe reports record matching before/after source hashes.
Store SHA-256: `80ce1047d00e347eb3bb7f482b7731ec8b3dc9dfe125de4ca70ba5a6dbea5ae5`.
Replay SHA-256: `3907948099ba7252b6d380c141ba96727dec0560e40d9d0f904908c8943fc2bf`.
Queue SHA-256: `e4745b4143285ffa232434f8cd4eee2eb6ee9c288173e1ca5662c35b58546530`.
No installed package or live RP was used. API-seam responses are synthetic.
Only permitted QA artifacts were written; no production fix was made here.

Reproduction commands from the workspace (scripts create fixtures only under the
allowed scratch directory):

```bash
/opt/homebrew/opt/ruby/bin/ruby tmp/m4-independent-20261010/stage1-probes.rb
/opt/homebrew/opt/ruby/bin/ruby tmp/m4-independent-20261010/stage1-binding-probes.rb
```

### IQ1 / P1: Healthy Real-Store Attachments Cannot Replay

Source: `spool_store.rb:487-502`, `spool_replay.rb:209-223,336-339`.
Repro: `ordinary-real-store-attachment-replay` in
`tmp/m4-independent-20261010/stage1-binding/probe-results.json`.
Persist one ordinary attachment through public Store, validate/load it, then
execute public Replay with open original targets and a capturing API.
Expected: one POST containing the original artifact bytes, followed by durable
confirmation. Actual: `Transaction attachment is unavailable`, zero POSTs,
checkpoint still pending, although the validated artifact contains
`healthy-artifact`. Store supplies symbol keys; Replay's helper called with
string keys never checks their symbol equivalents. This blocks valid attachment
recovery, not merely duplicate-name fixtures.
Acceptance fix: consume the actual public Store descriptor shape for name,
path, mime and availability; add real-Store attachment execute/resume coverage.
Also bind by `entry_index` and name, not name alone, when adding duplicate-name
coverage. The derived duplicate fixture is currently blocked by IQ1; wrong-byte
replay from that fixture is NOT claimed as reproduced.

### IQ2 / P1: Logical Filenames Can Destroy Failure Recovery

Source: `spool_store.rb:77-91,298-309`, `queue_processor.rb:662-670`.
Repro: `store-name-1..4`, `store-duplicate` and `queue-reserved` in
`tmp/m4-independent-20261010/stage1/probe-results.json`.
Expected: caller logical names are isolated from private spool filenames, and
two same-name attachments remain mapped to their own entry indices/bytes.
Actual: `.entries.ndjson`, `.checkpoint.json`, `.manifest.json`, and
`.attachments-data` fail persistence; two `same.bin` descriptors fail too.
The store creates logical-name hard links beside its private files/directories.
An offline queue log named `.checkpoint.json` is admitted (`true`) but settles
with `spooled=0`, `spool_failed=1`, and zero published transactions. This is a
deterministic recovery failure under ordinary shutdown, not the accepted
reject-new/SIGKILL limitations. The queue emits no standalone warning for this
spool error; its final receipt remains correctly incomplete, not a false PASS.
Ordinary names spool; normal queue duplicate batches correctly become
`same.bin`/`same-1.bin` (the direct public Store case is separate).
Acceptance fix: use generated storage names independent of logical filenames;
preserve entry-index alignment and private metadata. Exercise these names through
Store, queue, installed CLI execute and per-owner attachment-byte reconciliation.
Make failed durable retention visible with a safe reason, without raw paths.

### IQ3 / P2 Security: Root Refusal Occurs After An Outside Mutation

Source: `spool_store.rb:180-193` versus root validation at `704-718`.
Repro: `symlink-root-lock-side-effect` in the binding probe report. Point the
configured root symlink at a separate owned fixture with a valid transaction
directory name and an existing `.replay.lock` mode 0644; call public
`with_transaction`. Expected: `unsafe_root` before opening/chmodding/creating
any descendant lock. Actual: it raises `unsafe_root`, but first changes the
outside-root lock to mode 0600. File contents remain unchanged in this repro;
no overwrite, credential disclosure or live attack is claimed.
Acceptance fix: validate the configured root and relevant directory ancestry
before lock side effects; assert no creation/chmod outside a rejected root.

### IQ4 / P2 Usability: Resume Summary Mislabels Confirmed Siblings

Source: `spool_replay.rb:138-171,304-314`.
Repro: `confirmed-sibling-summary` in the binding probe report. Persist two logs;
set states to `[failed, confirmed(existing-sibling-ack)]` through public Store;
execute with a malformed/empty acknowledgement for the first log.
Expected: `confirmed=1, ambiguous=1, pending=0`, matching durable state and the
next inspection; the confirmed sibling is never resent. Actual execute summary:
`confirmed=0, ambiguous=1, pending=1`. Immediate dry-run reports the correct
`1/1/0`. Only the first log was sent, so no sibling duplicate is claimed. Stop
paths count every unvisited index as pending, ignoring existing confirmation.
Acceptance fix: summarize all final per-entry states after a stop, preserving
already-confirmed/failed/uncertain siblings, including budget and checkpoint
failure exits. Execute and immediate inspection must agree on durable counts
while separately identifying any uncheckpointed current ambiguity.

Stage 1 disposition: IQ1/IQ2 require repair before final recovery acceptance;
IQ3/IQ4 require security/QA-UX repair and affected reruns. Final D/full/installed/
live verdict remains PENDING. No historical M3 finding is reclassified here.

## Historical Pre-C Contract Questions

Priorities below describe implementation risks to resolve, NOT reproduced product
findings. Existing safeguards are acknowledged; the questions make their observable
failure behavior testable before C is implemented.

| ID / Risk | Contract basis | Concrete decision needed / proposed acceptance |
| --- | --- | --- |
| G1 / P1 | M4 lines 59-71, 76-77: quota includes checkpoints; confirmation must persist before continuing | Define peak quota accounting for atomic checkpoint replacement, including simultaneous old/new files. Reserve checkpoint headroom or stop safely when it is unavailable. ENOSPC after server acceptance must stop replay before the next entry, retain evidence and classify the uncheckpointed entry as uncertain on restart; never claim durable confirmation or replay it automatically. Concurrent writer/replayer must not exceed the quota. |
| G2 / P1 | M4 lines 15-16, 76-78: crash ambiguity and explicit duplicate consent | Define a durable pre-send/in-flight state and startup interpretation. Kill after RP acceptance but before the success checkpoint; restart without duplicate consent must refuse that entry. Ordinary HTTP retries, not just manual replay, must also disclose possible duplicates after a lost response. Confirmed siblings remain skipped. Consent must be explicit and scoped to the selected transaction, not inferred from execute mode. |
| G3 / P1 | M4 lines 42-47, 55-58: one deadline and atomic durability | Define what a receipt says if its budget expires during lock acquisition, evidence copy or fsync. Only published, complete transactions count as durably spooled. Zero timeout must not hide a blocking disk fallback. Cancellation/crash residue must stay non-replayable and visible in quota accounting; any ongoing work after the call returns must be disclosed rather than counted as completed. Specify a numeric timeout tolerance for the test workload. |
| G4 / P1 | M4 lines 78-81, 96-102: closed targets fail usefully, original ownership preserved | Define the supported recovery lifecycle: a normal failed run may already have finished its original Step/Launch before an operator replays. Demonstrate controlled replay into the original still-eligible target and a separate closed/missing-target refusal. Do not silently reopen, recreate, retarget or waive the check. Tell the QA user when evidence is retained but not replayable and what action remains available. |
| G5 / P2 | M4 lines 28-33; README lines 142-162: cutoff versus whole-report result | Document which counters are cutoff-scoped versus cumulative, whether ambiguous/spooled overlap, and how local settlement differs from completeness. Example: A/B accepted before the barrier, C admitted after it, one rejection after capture. The early receipt must be immutable and exclude C from cutoff delivery counts, while whole-run incompleteness remains discoverable. Provide a public Cucumber-consumer example for retrieving the final receipt, not only formatter method names. |
| G6 / P2 | M4 lines 64-81, 104-112; README configuration/recovery surface | Freeze CLI syntax, exit/status semantics, safe config precedence and legacy NDJSON disposition. README/help should expose spool location, 268435456-byte default, strict decimal validation, shutdown budget, strict mode, dry-run, execute, resume and duplicate consent. Show separate business/report outcomes and preserve the original business failure under strict mode. Unsupported old spool/schema must produce an actionable refusal, not disappear or be treated as committed. |

The current config maps `RP_CONFIG`, `RP_SPOOL_DIR` and
`RP_EXIT_FLUSH_TIMEOUT_MS` (config.rb lines 131-135 and 97-98), but README's main
configuration list omits them. README lines 164-166 link to B documents not
present at this read; line 516 still describes simplified NDJSON spool. These
are provisional documentation observations during ongoing work, not release bugs
or grounds to reject unfinished B/C. Close them in the frozen consumer-facing docs.

## Consumer Journeys And Critical Negatives

All rows are planned final installed-consumer tests; their final outcomes remain
NOT RUN. Stage 1 exploratory results are recorded separately above.
Use bounded, synthetic evidence without real credentials in retained output.

| Journey | QA action and required observable outcome | Critical negatives |
| --- | --- | --- |
| J1: Understand a cutoff receipt | From the installed public API, admit A/B, start a barrier, then admit C while A/B responses are gated. Release only A/B. Check stable cutoff, bounded return, immutable receipt and explicit local/server/whole-report distinction. | Partial batch with one ID and one error; short/malformed 2xx; lost response; v2 acceptance; rejection before/after cutoff; zero timeout; repeated shutdown. Later traffic cannot extend the first barrier or make v2 persistence look confirmed. No automatic resend of confirmed siblings. |
| J2: Keep evidence within durable quota | In a private QA spool, force transport failure with a log and attachment. Verify complete publication, exact byte/hash metadata and private modes. Use two processes and a deliberately small quota. | Staging residue consumes capacity; file grows during copy; missing/unreadable attachment; ENOSPC at copy, publication and checkpoint; lock contention. No oversized commit, silent empty artifact, user-evidence deletion or unlimited temporary fallback. Failed durable publication is not a successful spool receipt. |
| J3: Recover without hiding duplicates | Use installed CLI help to select one transaction. Default invocation/dry-run sends no reporting mutations. Execute against controlled eligible targets, interrupt after one persisted confirmation, resume and verify only remaining eligible records are sent. | Kill after server acceptance before checkpoint; restart without consent; mixed acknowledgement siblings; corrupt/truncated checkpoint; unknown schema; legacy spool. Record selection and refusal reasons must distinguish confirmed, uncertain, failed and pending entries. Dry-run cannot advance confirmations or delete evidence. |
| J4: Preserve destination and evidence ownership | Replay synthetic evidence bound to its original endpoint/project/Launch/Step/attempt/time while another Step is active. Reconcile identifiers, ancestry and exact attachment bytes through API. | Different project/endpoint; missing/closed target; traversal or absolute evidence path; root/evidence symlink; checksum mismatch; oversized metadata; concurrent replay. Refuse before reporting mutations where locally detectable; never create a substitute tree or attach evidence to the active Step. |
| J5: Configure recovery without reading source | Fresh installed consumer follows README/help only: YAML profile, environment override, spool/quota/budget, dry-run then explicit execute. Inspect sanitized summaries and independent reporting status. | Quota `0`, `-1`, `1.5`, `1e3`, `256MiB`, whitespace and malformed text; missing auth; conflicting YAML/env settings; inaccessible spool. Fail with the option name and safe remediation, not raw config/payload/credential values. No silent coercion to an unintended disk cap. |
| J6: Keep business failure meaningful | Run a passing and an intentionally failing scenario under healthy and failed reporting, with strict mode off/on. Observe Cucumber exit, original exception/stack and a separately visible final report outcome. | Slow/429/502 recovery versus 400/401/403 fail-fast; capture closure timeout; reporting start/finish failure; shutdown deadline. Default reporting failure cannot fail a passing business test; a failed business assertion remains primary in either mode. Strict reporting behavior must match documented policy and not mask that assertion. |

For live J4/J6, use only the existing local RP at `http://localhost`, project
`superadmin_personal`, and uniquely named QA launches. Check browser evidence on
the exact API-reconciled launch. Synthetic fault-server results must remain
labelled synthetic; unsupported live recovery must be reported, not simulated
into a live PASS. Do not alter K8s deployment or existing user runs.

## Final Handoff And Acceptance

Wait for Master to hand off the final frozen C/D-complete candidate after full
regression. Required handoff: scoped source manifest and hashes, actual gem path
and SHA-256, package version/runtime/dependency provenance, full/seed/M2-M3/security
receipts (including failures/adapters), executable syntax and recovery eligibility.
Credentials must be supplied privately, never embedded in the manifest or report.

Install that exact gem into an isolated consumer under the allowed scratch root.
Do not use a checkout load path or old M4A package as final evidence. Verify loaded
gem paths/hashes and CLI executable provenance before running independent journeys.
Retain sanitized commands, exits, timing, receipts and API reconciliation keyed to
the same candidate; reruns after fixes must identify the new artifact explicitly.

QA UX acceptance: README/help alone enables safe setup; warnings explain what is
missing and whether evidence is durably retained; dry-run is visibly non-sending;
execute/resume/duplicate consent are distinguishable; refusal supplies a bounded,
actionable reason; business result and reporting completeness remain separate.

Final P1/P2 findings must include candidate/package identity, public reproduction,
expected versus actual behavior, retained evidence and a concrete acceptance fix.
Historical M3 F2/F5/F6/F8 P2 and F7 P3 remain out of scope unless a new M4 regression
is demonstrated by a same-input baseline comparison. Unrelated dirty dependency
manifests and duration work are not edited, reverted, committed or tagged here.

Final verdict: PENDING FROZEN HANDOFF. One direct message attempt to Master was
refused by the app because Master is this evaluator's native ancestor. No message
was delivered by that tool, and no native collaboration sender is exposed here.
This report is returned through the task result for Master; no repeated messaging,
ongoing polling or unstable-draft acceptance is implied.
