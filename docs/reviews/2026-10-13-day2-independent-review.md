# Day 2 Independent Scoped Review

## Verdict And Boundary

**PASS for the agreed Day 2 scoped task**, independently concluded at
2026-10-13T12:36:36Z from completed source-bound evidence. The reviewer verified
the 900.257309-second single-process result, clean complete 811-confirmed receipt,
actual wire/resource traces, native/RP outcomes and original-owner CSV bytes/SHA.
Saved full-suite evidence is exactly 824/0; the fresh real fault matrix is 14/14
with matching current executable/test/gemspec hashes. All recorded finding
conditions are resolved within scope; no unresolved P1/P2 is identified.

The tested 210-file snapshot remains immutable. After result completion, only
`examples/day2_endurance/README.md` changed to portable setup instructions and
annotated local acceptance context. That documentation-only delta is explicitly
recorded below; no executable harness, SDK, test or deployment input changed.
Earlier PENDING decisions and failed/aborted observations remain dated audit
history, not the current verdict. Manager's forthcoming browser/operations
report is supplementary and is not claimed as evidence already inspected here.

Workspace: `/Users/nick/Documents/New project`; observed branch:
`codex/day2-security-endurance`. Reviewer changed only this new review document.
No implementation, tests, deployment, child chats, commits, branch changes,
cluster mutations, authentication, or live upload tests were performed. Fresh
local check output is confined to
`/private/tmp/reportportal-day2-review-20261013`.

Intentional anonymous intranet object-read access is in scope and is not itself
a defect. Full M5 certification, registry publication, historical migration,
new authenticated-media delivery, production HA, and Huawei production proof
are outside this review's acceptance claims.

## Actionable Findings

### P2-01: Batch Bounds Are Configured But Not Independently Checked

Status at second scoped review: **source-addressed; new 900-second evidence
pending**. The reviewer inspected the actual wire observer, negative tests,
runner gate and per-iteration server reconciliation. Details follow in the
second-review section. Original finding is retained below as audit history.

Location:
[support.rb](/Users/nick/Documents/New project/examples/day2_endurance/support.rb:103),
[run.rb](/Users/nick/Documents/New project/examples/day2_endurance/run.rb:131), and
[QueueProcessor diagnostics](/Users/nick/Documents/New project/lib/reportportal_cucumber/service/queue_processor.rb:136).

`Session#sample` enforces queue peak records and bytes. However, the configured
`batch_max_bytes=2097152` and `batch_size_logs=20` are only recorded in the
result. Current queue diagnostics expose occupancy and counters, not observed
maximum request bytes or batch record count. Consequently, an upload-batching
regression can exceed those bounds while the endurance acceptance still passes
its resource, receipt, and server-reconciliation checks. This is an acceptance
coverage gap, not evidence that the current SDK actually sends oversized batches.

Requested owner action: measure actual SDK upload request bytes and contained
log record counts through harness-only observation, record observed maxima,
and fail acceptance when either exceeds the effective SDK limit. Add negative
unit checks showing a bound breach fails even with complete receipt/server logs.
Do not infer an observed bound from configuration or successful HTTP responses.
The endurance README's reference to batch diagnostics should match the actual
evidence available.

### P2-02: Default Video Quota Exceeds The Provisioned MinIO Volume

Status after independent follow-up: **source-addressed; final evidence pending**.
Current defaults explicitly request an 8Gi MinIO PVC and set a 4GiB video quota.
The fresh 16-example Helm check includes renders of all four shipped profiles
and passes the 8Gi/4GiB sizing assertions. The operations runbook warns that the
nominal 50% reserve does not constrain other buckets and requires actual
capacity/usage preflight. Original finding and initial reproduction follow for
audit history; the 20GiB default below is no longer current.

Location:
[values.yaml](/Users/nick/Documents/New project/helm/reportportal-rich-experience/values.yaml:47),
[local profile](/Users/nick/Documents/New project/helm/reportportal-rich-experience/values-local-latest.yaml:29), and
[production example](/Users/nick/Documents/New project/helm/reportportal-rich-experience/values-production.example.yaml:34).

The initial fresh read-only render with the local profile produced MinIO PVC `day2-minio`
requesting **8Gi**, while the wrapper applies a **20GiB** hard quota to the video
bucket. The packaged MinIO dependency defaults `persistence.size` to `8Gi`; none
of the inspected wrapper/local/production-example values overrides it. The video
bucket also shares MinIO storage with RP attachments. On a capacity-enforcing
8Gi volume, physical exhaustion can therefore occur before this video quota is
reached, even ignoring the other buckets. A local provisioner exposing a larger
backing filesystem would not make this profile a portable capacity guard.

The runbook correctly warns that quota must fit physical capacity and that ILM
alone is not a disk-pressure guarantee, but the shipped fresh-install defaults
do not satisfy that guidance.

Requested owner action: align quota and fresh-install volume sizing with an
explicit reserve for other MinIO buckets/overhead, and add a rendered sizing
check or explicit preflight gate. Existing/external volume capacity requires
operator verification; do not silently resize existing PVCs or claim a general
zero-DiskPressure guarantee. Preserve the documented asynchronous ILM limit.

### P2-03: README Promised Unsupported Multipart Cleanup

Status: **source-addressed during follow-up**. The first read still promised
one-day cleanup; a final re-read at approximately 2026-10-13T11:47:11Z confirmed
that the README now disclaims unsupported bucket-level incomplete-upload expiry
and points to the separate runbook checks. Initial observation follows for history.
Location:
[chart README](/Users/nick/Documents/New project/helm/reportportal-rich-experience/README.md:94).

The first README read said the bucket lifecycle included one-day incomplete
multipart cleanup. Current values/template had removed that unsupported field, and the
operations runbook now correctly explains the separate server-wide cleanup
concern. A tester following the README could wrongly consider abandoned-upload
cleanup configured merely because the Job succeeded. Align the README with the
runbook before freezing the final snapshot; do not restore the unsupported field
or claim server-wide cleanup was configured by this wrapper. This is a remaining
wording issue during Manager's announced repair, not a request for implementation
changes by this reviewer.

### P2-04: Host Tools Masked An Absent-Bucket Runtime Failure

Status at second review: **actual absent-bucket v3 success observed; strict
failure/source-binding finalization pending**. Earlier v2 remained failed; see
the second-review section for the verified v3 image, script and exit status.
Location:
[reconciliation script](/Users/nick/Documents/New project/helm/reportportal-rich-experience/files/reconcile-video-bucket.sh:24).

Manager reports that the actual pinned mc image lacks `grep`, so the original
absent-bucket Job failed although the host-based unit example passed. The initial
failed Job logs were preserved. This failed closed rather than falsely proving
revocation, but violated the intended safe absent-bucket no-op and demonstrates
why rendered/mocked success cannot prove the container's command environment.

The reviewer inspected the replacement: the disabled-bucket branch captures
the failing `mc --json stat` result and uses POSIX `case` to match explicit
`Code`/`code` `NoSuchBucket` fragments. All other failures exit nonzero with
`revocation was NOT verified`; there is no generic 'not found' fallback and no
external grep/jq in this branch. The unit helper now shadows `grep` with an
executable that exits 99. The enabled branch still uses other utilities for the
optional `.keep` write; this inspection does not certify every image utility.

The single focused existing example covers both explicit absent-bucket success
and an opaque failed-stat exit. It does not independently exercise real MinIO
AccessDenied, network failures, or every error-JSON shape. Final closure requires
the actual pinned-image v2 absent-bucket result and strict inspection failures,
not another host unit PASS. Preserve the original failure as separate evidence.

## Fresh Reviewer Checks

Executed serially with Homebrew Ruby, the supplied v2 GEM_HOME plus Homebrew
GEM_PATH, the absolute root BUNDLE_GEMFILE, frozen Bundler configuration,
`CLEARING_MOCK_AUTOSTART=false`, and private scratch TMPDIR. The usable private
Helm executable is `/private/tmp/reportportal-day2-bin/helm`; its observed
version is `v3.18.4+gd80839c`. The separately named `helm3.18.4` path supplied in
the initial brief did not exist, so it was not used.

| Check | Fresh Result | Evidence Meaning |
| --- | --- | --- |
| `spec/helm/day2_security_spec.rb` | 9 examples passed | Rendered policies/routes and mocked mc command/failure behavior, not real MinIO authorization |
| `spec/day2/endurance_contract_spec.rb` | 31 examples passed | Includes 500 seeded Rack-level ingest/margin pairs, arithmetic, rejection, deterministic generation, workflow and CSV contracts |
| `spec/day2/fault_live_gate_spec.rb` | 3 examples passed | Local URL and readiness opt-in validation without authentication or API mutations |
| Combined targeted suite | 43 examples, 0 failures; 9.76 seconds | Fresh unit evidence only, not 900-second endurance or real RP-fault acceptance |
| Local-profile Helm render | MinIO PVC requests 8Gi | Independent read-only reproduction of P2-02 |

Unit output:
[initial-targeted-unit.txt](/private/tmp/reportportal-day2-review-20261013/initial-targeted-unit.txt).
No heavy regression, live fault rehearsal, deployment upgrade, or security
mutation suite was run by this reviewer. Prior PASS reports were not reused as
fresh provenance. These tests ran against a changing working tree; the hashes
below were captured afterward and are not a final frozen test/source binding.

## Scoped Source Observations

| Scope | Initial Observation | Remaining Acceptance Boundary |
| --- | --- | --- |
| Anonymous object reads and revocation | Policy has only `s3:GetObject` on bucket objects, no List/Put/Delete. Empty private policy replaces previous grants. Disabling the extension retains Job/config/credentials when `revokeOnDisable=true`; absent bucket is safe, failed inspection is not. | Obtain actual anonymous GET/HEAD/206 Range, PUT/DELETE/list 403 and both revocation transitions with retained original object bytes/hash. |
| Portable controller migration | Video Prefix remains `/automation-videos`, without stripping the path or inherited nginx annotations. Separate local Traefik profile initially exposes 18080; the documented cutover is deliberate. Huawei overlay keeps an unresolved class placeholder and disclaims execution. | Confirm final actual controller/chart/image, port 80 listener, RP/browser/video route behavior and safe rollback evidence. Local success is not Huawei certification. |
| Single-process endurance | Runner rejects live duration below 900 seconds and iteration counts outside 500-1000. PBT uses deterministic seeded inputs and independent decimal margin/rejection contracts, not just HTTP 2xx. Same process samples monotonic elapsed, RSS and threads and checks queue peaks. | Final real >=900-second trace, thresholds and source binding; resolve P2-01 before claiming observed batch bounds. |
| Receipt/server/CSV reconciliation | Queries paginate; checks native/RP outcomes, launch statistics, parentage, unique item UUIDs, log-owner filters, exact confirmed log count, huge log preservation and downloaded CSV bytes/SHA on original owner. | Actual final reconciliation result, complete clean receipt and original CSV/download hashes. Unit examples cannot prove server persistence. |
| RP upload-chain faults | Actual SDK points at bounded loopback reverse proxy before RP. Status/disconnect/timeout are pre-forward faults; hidden/partial acknowledgement modes forward real uploads before hiding acknowledgements. Finish faults target harness-owned metadata; no direct backend disruption is required. | Immutable real-RP evidence for timeout/disconnect/partial/hidden ACK, controlled replay, checkpoint no-resend, native SIGINT and original business outcomes. |
| Retention/quota operations | Shell `set -eu` makes policy/import/quota failures fatal. Stable lifecycle rule import replaces whole policy on a documented dedicated bucket. Disabling retention/quota management explicitly leaves existing settings intact. Runbook covers failed Jobs, readback, capacity monitoring, backup/restore and revocation before uninstall. | Real repeat-run readback proving one stable lifecycle rule and intended quota; resolve P2-02 and record physical capacity/other-bucket reserve. No ILM-only zero-DiskPressure claim. |

Standard Prefix matching is path-element based and longest matching paths take
precedence; the source's portable route design is consistent with the
[Kubernetes Ingress specification](https://kubernetes.io/docs/concepts/services-networking/ingress/#path-types).
This verifies the design contract, not a particular controller's execution.
Public MinIO documentation lookups failed during this review and supply no
additional verification of the pinned mc/server runtime.

## Tester Usability And Reported Evidence

The harness documentation distinguishes smoke, reporting smoke, real endurance,
local fault sandbox, and opt-in real RP runs. It explains partial ACKs as hidden
acknowledgements after acceptance, duplicate-consent replay, original open-owner
binding, SIGINT deadlines, and why SIGKILL cannot guarantee pending memory.
Storage documentation explicitly warns that direct video URLs are not user-
authenticated and that rollback must not restore old anonymous write policies.
These are useful tester/operator boundaries, not production certifications.

Manager's initial brief reports real pre-cutover read-only/revocation checks,
retained recording SHA, a running Traefik 41.7.1 / Proxy 3.7.14 in `rp-ingress`,
the old controller removed after Deployment/Service backup, and no DB migration.
It also reports that with the video route disabled, the RP fallback gives 302
while direct MinIO gives 403. None of those observations was repeated here.
The fallback redirect must not be treated as proof of revoked bucket access.

The initial brief's `rplatest` naming ambiguity is resolved by Manager's follow-up:
the canonical endpoint is **`http://rp-latest.localhost:80`**, consistent with the
checked profile hostname. The final evidence should use this exact origin.

## Follow-Up At 2026-10-13T11:45:37Z

The reviewer independently re-read current quota/lifecycle values, the template,
runbook, README and sizing tests, then reran only the lightweight read-only/mocked
Helm suites with the same private runtime/scratch arrangement as above:
`spec/helm/day2_security_spec.rb` (10 examples) and
`spec/helm/latest_chart_spec.rb` (6 examples). Fresh result: **16 examples,
0 failures**, 8.55 seconds. This is new evidence, not reuse of Manager's reported
16-test result. Output:
[quota-followup-helm.txt](/private/tmp/reportportal-day2-review-20261013/quota-followup-helm.txt).
No live API, auth, storage mutation, heavy regression or endurance run was started.

Manager reports actual MC Job readback of hard quota **4294967296 bytes**, video
usage **945981 bytes / 4 objects**, and actual PVC capacity **8Gi**. These support
the sizing repair but were not independently queried here. Keep the actual
readback artifact and source/run binding for final review.

Manager also reports authorized local-Secret browser sign-in, an existing MP4
with `readyState=4`, duration **9.56s**, playback to ended, seeking to **2.58097s**
and `paused=false`. The reviewer inspected
[the supplied screenshot](/private/tmp/reportportal-day2-ui-20261013/traefik-readonly-video.jpg):
it shows the embedded video frame and player at approximately 0:02 / 0:09 with a
pause control. A still image does not independently prove readyState, elapsed
playback-to-ended, successful seeking, or the complete browser/network trace.
Those dynamic results remain Manager-reported evidence, not new reviewer tests.
Screenshot SHA-256:
`e61500670ff522bf14600f7675a56d4ed6d63bed9acace07cc5a3e2f5bb9c5b1`.

For the lifecycle limitation, the reviewer independently fetched the pinned
[MinIO rule.go source](https://raw.githubusercontent.com/minio/minio/RELEASE.2025-07-23T15-54-02Z/internal/bucket/lifecycle/rule.go).
Its `Rule` structure has no active `AbortIncompleteMultipartUpload` field and
explicitly marks that capability unsupported. This corroborates the source-level
limitation; Manager's real readback stripping the field was not repeated here.
The current template omits the field and the updated runbook distinguishes
server-wide stale-upload settings and authorized manual cleanup from bucket ILM.
The wrapper does not configure either automatically. P2-03 records the misleading
README claim found on the first read; it was corrected before this follow-up
completed, and the final re-read confirms alignment with the runbook. That
concurrent documentation change is another reason these fingerprints are not a
frozen source/test binding.

Follow-up fingerprints captured after the check, still not an immutable final
test/source binding:

```text
900947367c2d0fdcd827c354aa028b344ab6762a551b8b91d48799310d9332a4  helm/reportportal-rich-experience/values.yaml
61342e77eb9832212098ce5a6221dfa12fe59c9196cd1df87eaa210dff449297  helm/reportportal-rich-experience/templates/minio-bucket-config.yaml
cfba15ff7a56305bb75ab0a23136fc15df6f35aa0b29590db78ebc44ae92f926  helm/reportportal-rich-experience/OPERATIONS.md
ed4fa7c22b61946bb622c7ec7accd5812deea11b58c9c7f82d988d6911262176  helm/reportportal-rich-experience/README.md
849c08d0cb0a90c73e0f4a99201995654fb427c4045f90926c27e0a6d6484ea0  spec/helm/day2_security_spec.rb
c0fedd681c129fae9ed25f6cb9b8442f17950ccd17efdee890dcf49887e5040f  spec/helm/latest_chart_spec.rb
```

## Absent-Bucket Follow-Up At 2026-10-13T11:51:35Z

Fresh reviewer command selected only the `absent disabled bucket` example in
`spec/helm/day2_security_spec.rb`, using the same private runtime/TMPDIR arrangement.
Result: **1 example, 0 failures**, 1.7 seconds. Both absent and failed-inspection
branches run within this example, with the hostile grep stub present. Output:
[absentbucket-followup-unit.txt](/private/tmp/reportportal-day2-review-20261013/absentbucket-followup-unit.txt).
This is fresh mocked unit evidence, not an executed mc-image Job. Manager's v2
Job remained pending in the supplied update. No cluster mutations, authentication,
live API tests, or heavy regression were performed by the reviewer.

Source fingerprints captured after this check, not immutable final bindings:

```text
d0d7737fafa6ddd729156d5eef8ae06f8535fe8c96d099bb47dcc4ce4d06c064  helm/reportportal-rich-experience/files/reconcile-video-bucket.sh
24bd75efe6492be5918e766ebd43cf4053379a608c815f14994314a2828cc55b  spec/helm/day2_security_spec.rb
```

## Second Scoped Review At 2026-10-13T12:04:18Z

This pass inspected current source and saved artifacts and made read-only
Kubernetes Job/Pod/ConfigMap/log queries. It did not run tests, a heavy/full suite,
authentication, new uploads, mutations or an endurance process. Historical
results inspected below are not new reviewer-executed PASS results. Manager
reports runtime/chart/spec/gemspec/Rake frozen since approximately 11:55 UTC;
endurance repairs are still changing and final snapshots remain forthcoming.

### Source-Addressed Batch Observation

[wire_observer.rb](/Users/nick/Documents/New project/examples/day2_endurance/wire_observer.rb:76)
counts actual Net::HTTP entity bytes: direct JSON body bytes or bytes consumed
from the counted multipart stream, including framing and CSV. It retains a
bounded body for entry parsing, hashes consumed bytes, and records entries,
owner UUIDs, status, Content-Length and transport/parse failures without storing
raw bodies or Authorization. The final gate rejects byte/count overflow,
length mismatch, failed transport/parsing, missing observations and mismatches
against sent batches/confirmed receipt; at least one streamed CSV is required.

[Negative wire tests](/Users/nick/Documents/New project/spec/day2/endurance_wire_spec.rb:72)
exercise actual byte overflow despite a small declared Content-Length, 21-entry
overflow, boundary count, byte-length mismatch, sent-batch/receipt mismatch,
malformed JSON and a real loopback streamed multipart comparison. These were
read, not re-executed during this pass. Per-iteration invariant summaries now
exercise AppLog continuously; reconciliation requires every iteration exactly
once and on the original PBT action, in addition to periodic huge logs and the
original CSV owner's downloaded bytes/hash. P2-01's missing measurement is
addressed in source, but not yet proved by a final uninterrupted 900-second run.

### Actual Storage Evidence

The supplied
[absent-bucket log](/private/tmp/reportportal-day2-storage-20261013/disabled-absent-final.txt)
contains the safe absent-bucket message. Independent read-only cluster queries
identify the successful Job as `day2-video-disabled-absent-v3`, not v2:
Complete=True at 11:54:00Z, succeeded=1; its Pod exited 0 with reason Completed.
The image is `minio/mc:RELEASE.2025-07-21T05-28-08Z`, resolved to
`docker.io/minio/mc@sha256:fb8f773eac8ef9d6da0486d5dec2f42f219358bcb8de579d1623d518c9ebd4cc`.
ConfigMap `day2-absent-test-v3` contains a script exactly matching current source,
SHA-256 `95be3e46caaba214105d99ea3852cd1b2a86825d0dd907425fdc36cb5f73ead6`.

Both prior Jobs remain Failed=True. Their logs preserve, respectively, missing
grep plus 'revocation was NOT verified', and the same strict failure message
after mc stat stripped the typed error. Current source instead uses authenticated
`mc --json anonymous get-json`: explicit NoSuchBucket exits safely; explicit
NoSuchBucketPolicy still applies the empty policy; all other inspection failures
remain nonzero. Thus the physical missing-tool and unclassified-error failures
are preserved, not replaced with a retrospective PASS. Actual final authorization/
network inspection failures and the final deployment binding remain required.

The actual available file is
[admin-settings-final.txt](/private/tmp/reportportal-day2-storage-20261013/admin-settings-final.txt),
not `realadmin-settings-final.txt` (which was absent). The reviewer read its
GetObject-only policy, single stable 30-day current/noncurrent rule, hard quota
4294967296, usage 945981 bytes / 4 objects, stale-upload expiry 24h and cleanup
interval 6h. The wrapper does not configure that server-wide cleanup or promise
one-day bucket abort support. The saved
[PVC](/private/tmp/reportportal-day2-storage-20261013/pvc-final.json)
is Bound with requested and reported capacity 8Gi. The saved filesystem readback
shows a larger shared local backing disk at 73% usage, so 8Gi is nominal PVC
capacity, not evidence of enforced isolated physical capacity. The 4GiB video
quota does not constrain other buckets or shared node consumers.

### Fault Evidence And Final Binding Gap

The reviewer read the saved results linked by
[VALIDATION.md](/Users/nick/Documents/New project/examples/day2_faults/VALIDATION.md):
49 focused tests passed in 15.431s; the preserved initial 85-test combined run had
three failures; a separate 36-test run passed, followed by an 85-test rerun with
zero failures in 16.256s. Timing sensitivity remains a disclosed residual risk,
not evidence that the original three failures never occurred. No tests were
rerun by this reviewer.

The real summary records all 14 scenarios validated. Selected per-case artifacts
corroborate partial ACK [confirmed=1, ambiguous=1, spooled=1], three owned logs
after consented replay and one observed duplicate; hidden ACK produced two owned
logs; durable replay preserved a 68-byte PNG with its recorded SHA under the
original owner. Expired budget retains pending=1/spooled=0 and queue saturation
pending=3/rejected=97, not zero-loss or complete delivery. Receipt categories
remain honest even where the scenario's fault-contract assertion passes.

The source manifest's before/after digests agree and its actual SHA matches the
report: `4ba2329421cdd49d824e8c45a693d04b0ed4295aa88771e37d678fbaccfd8ef7`.
Comparing every recorded file hash against current files found one difference:
`reportportal-cucumber-ruby.gemspec`. All recorded fault harness and SDK files
still match. This is a final provenance gap, not an established runtime defect.
Supply the exact reviewed gemspec delta or fresh source-bound evidence before
claiming the 14-scenario run applies to the entire final tree. Do not discard
the valid matching harness/SDK evidence or silently rewrite its manifest.

### Additional Endurance Conditions

Manager identified the following during this review and instructed Gauss to
interrupt the in-progress run gracefully, preserve it as aborted, fix these
conditions, run focused tests/smoke and begin a fresh 900-second run. At the
reviewer's latest source read, the four conditions below were still present;
they must not be described as resolved until updated source and focused evidence
are inspected. The reviewer did not signal or restart any process.

| Priority / Condition | Observed Source | Required Resolution Before Final Run |
| --- | --- | --- |
| P1-01: Implicit private helper can route authentication to a remote endpoint | `auth.rb` automatically selects the private LOCAL_HELPER when RP_API_KEY is absent; its adapter redirects helper HTTP requests to any endpoint accepted by the runner. This is a potential credential-routing risk, not a claim of observed disclosure. | Require explicit DAY2_AUTH_HELPER and a credential-free, exact allowlisted local destination before loading/calling it. Standard user-provided RP_API_KEY remains the portable remote path. Negative tests must prove remote/missing-opt-in helper paths never load or authenticate. |
| P2-05: macOS-only temporary roots | Runner and wire/metric tests require `/private/tmp/reportportal-day2-endurance-20261013`. The test helpers assume that parent exists; Linux/non-privileged clean CI may fail before any assertions. | Use Dir.tmpdir or explicit configurable evidence root; create only owned test directories. Verify clean nonexistent-parent behavior without requiring an earlier live run or private macOS paths. |
| P2-06: Darwin thread sensor used unconditionally | `Session#sample` invokes `ps -M` and subtracts a header row without platform selection. This is not a portable Linux thread-count contract. | Use supported OS-specific thread enumeration with explicit parsing/failure checks, and focused Linux/Darwin selection/count tests. Do not infer Linux resource validation from macOS results or a permissive command exit. |
| P2-07: Fixed 750-log floor conflicts with supported 500 iterations | Runner permits 500-1000 iterations but requires confirmed logs >=max(750, iterations), independent of actual selected workload. | Base the sustained minimum on selected iterations and reconcile every iteration. Cover both 500 and 1000 options; a valid 500 run must not fail merely because it produces fewer than 750 summaries/logs. |

References for the inspected conditions:
[auth.rb](/Users/nick/Documents/New project/examples/day2_endurance/auth.rb:15),
[temporary roots](/Users/nick/Documents/New project/spec/day2/endurance_wire_spec.rb:11),
[thread sampling](/Users/nick/Documents/New project/examples/day2_endurance/support.rb:93), and
[minimum count](/Users/nick/Documents/New project/examples/day2_endurance/run.rb:135).
Any interrupted or earlier completed run must retain its own source hashes and
outcome; no partial elapsed interval may be added to a later process to make 900s.
Final acceptance requires one fresh uninterrupted process on the resolved source,
with native results, resources, wire bounds, receipt/server ownership and CSV
bytes reconciled. TLS/HA/Huawei production certification remains excluded.

Second-review fingerprints (before the announced remaining endurance repairs):

```text
02daa7404146a3e8975786672ed39aa461294d71984ebdab5bedaffa5688ced1  examples/day2_endurance/wire_observer.rb
5c899bcd2ca3d12be43e71b47d82a6238594dcc53d70263058ef6bc178ea38b4  examples/day2_endurance/auth.rb
bd751aed22032b777d25a5b7f23e0b5c0a15791fa9c1d3e61b1b706ba87d966d  examples/day2_endurance/support.rb
2682fcf92d7428de2e934e1bb658c7a0126dd1d553aa2e4e0467b7d091ac8e7e  examples/day2_endurance/run.rb
3405b21260d346522439d987b6c1851991b034cc80f2c6f5748eccb4ef89a3fb  examples/day2_endurance/reconcile.rb
c8f7818228c04ab5501841486c0931ec31b77ecd86b848352835425dcd25fe4d  spec/day2/endurance_wire_spec.rb
6e37ff54b37559db11442d8ad1eabdfb925f3417010d663cfa2a7324680a2cc9  spec/day2/endurance_metrics_spec.rb
e5c2cc1979583b0eae8cee76156c5a710809a07c5d98883d6a0ca10bd214490d  reportportal-cucumber-ruby.gemspec
89a28bcbefc72f33d44cdc4e0063df171f07a921d815641d8fa138417345dca8  Rakefile
720c26bcef27d4e1ae500042c5d118decc33c9253183807bb34cad4d86c2fed1  disabled-absent-final.txt
a6c694b28542c07af0d2d6177fa4f31f971cacd1d5284de11b09fbd610b45e50  admin-settings-final.txt
0164e1b32ec7440479e487406ee1eee2ad932c829504b526d20e3389cf1f8758  pvc-final.json
```

Storage evidence basenames above are under
`/private/tmp/reportportal-day2-storage-20261013`.

## Frozen-Source Status At 2026-10-13T12:23:32Z

The reviewer inspected the supplied
[final source manifest](/private/tmp/reportportal-day2-final-source-20261013.json),
captured at 12:21:50 UTC. All **210** recorded files match current source. Recomputed
aggregate digest equals `a7fcda88bac2c9f43d39a3d3288b0ce9b3b74d38787d598789e1b46dbbddff62`.
Generated review documents are not in that source manifest, so this review-only
update does not mutate the frozen implementation/test inputs. No tests, uploads,
authentication or deployment mutations were initiated during this pass.

| Recorded Condition | Verified Current Disposition |
| --- | --- |
| P2-01: Missing observed batch bounds | Source-addressed by actual body-byte/entry observation, negative tests and final wire/receipt gate; final live result still pending. |
| P2-02: 20GiB quota on 8Gi PVC | Addressed by explicit 4GiB quota/8Gi PVC, reserve/preflight wording, rendered-profile checks and actual saved quota/PVC readback. No claim of isolated physical capacity or zero DiskPressure. |
| P2-03: Unsupported one-day multipart cleanup claim | Addressed: unsupported bucket field removed; README/runbook accurately distinguish server-wide expiry 24h/cleanup 6h from wrapper-managed lifecycle. |
| P2-04: Host grep masked container absent-bucket failure | Addressed by POSIX typed-code handling, get-json rather than lossy stat, hostile-grep unit coverage and actual pinned-image v3 completion. Original/v2 failures remain preserved. Strict inspection-failure behavior remains part of final acceptance evidence. |
| P1-01: Implicit private helper/remote credential routing | Addressed: no fallback helper; explicit absolute DAY2_AUTH_HELPER is required and local-target guard runs before file access/loading/authentication. Normal user-provided RP_API_KEY is preferred; malformed/whitespace/non-visible-ASCII credentials are rejected. Focused tests reject remote/deceptive hosts and missing opt-in without loading the helper. |
| P2-05: macOS-only temp roots/precreated test parent | Addressed: runner uses configurable absolute evidence root or Dir.tmpdir; wire/metric tests use owned temporary directories without a fixed parent. |
| P2-06: Darwin-only thread sensor | Addressed: Linux uses bounded 16384-byte `/proc/<pid>/status` parsing of VmRSS/Threads; Darwin retains its ps sensor. Missing Linux fields and unsupported OS fail explicitly. Focused Linux/Darwin tests exist; this is not a claim of an actual Linux live run. |
| P2-07: 750 floor rejecting valid 500 iterations | Addressed: minimum confirmed logs is selected iterations, not max(750, iterations); 500 succeeds and 499 for 500 fails in focused examples. Per-iteration server uniqueness/ownership remains independently checked. |
| Prior fault gemspec provenance gap | Closed by a new source-bound real 14-case run after the gemspec change, using ordinary environment credentials. Old run/manifest remain historical evidence. |

The reviewer read
[full-suite-final-portable-1.json](/private/tmp/reportportal-day2-endurance-20261013/full-suite-final-portable-1.json):
**824 examples, 0 failures, 0 pending, 0 errors outside examples**, duration
172.020294s. The file contains no failed examples. This is inspected saved test
evidence, not a full suite executed by this reviewer. Focused portability/auth/
sensor/minimum-count tests were also inspected in current source.

The new real fault run is
[real-20261013T121454-242a70](/private/tmp/reportportal-day2-faults-final-20261013/real-20261013T121454-242a70/summary.json).
It records `auth_source: environment`, all **14** scenarios validated, unchanged
before/after inputs and a source-manifest SHA matching the actual file:
`3c5f106a35a4f483cd0e3263f92bc07d6a9f19c16f9eb176673475371f0f000d`.
Every recorded source hash now matches current files, including gemspec
`e5c2cc1979583b0eae8cee76156c5a710809a07c5d98883d6a0ca10bd214490d`.

The reviewer read the supplied final-source deployment/security artifacts:
[upgrade log](/private/tmp/reportportal-day2-storage-20261013/final-source-private-upgrade.txt),
[makePublic=false](/private/tmp/reportportal-day2-storage-20261013/private-make-public-false-final-source.json),
[enabled=false](/private/tmp/reportportal-day2-storage-20261013/private-disabled-final-source.json),
[restored Job](/private/tmp/reportportal-day2-storage-20261013/restored-final-source-job.txt), and
[restored route verification](/private/tmp/reportportal-day2-storage-20261013/verify-80-final-source.json).
Both private-transition records retain all five checks true, including data/
bytes retained. Gateway statuses remain 403 for makePublic=false and 302 fallback
for enabled=false; the latter record separately asserts anonymous denial, so the
redirect itself is not used as security proof. Restored route evidence records
HEAD/GET 200, Range 206, PUT/DELETE/list 403, GetObject-only policy, one stable
30-day rule and recording SHA
`8c5fd90857471ea65ea7fa850e96e704bf6d3d1834b455971acedf43fe266883`.
The reviewer did not repeat these mutations or independently observe the reported
absence of API Pod rollouts during deployment.

### Live Endurance Still Pending

Current run:
`/private/tmp/reportportal-day2-endurance-20261013/live-20261013T121643-c8d687`.
Manager reports start 12:16:43 UTC; no verdict can precede 12:31:43 UTC, and wall
time alone will not establish acceptance. The reviewer read only current metric
progress: 346 samples, one PID (38671), latest elapsed 407.663963s at pbt-335,
RSS 50.578125 MiB, 13 threads, confirmed 378/pending 1, no failed/spooled/ambiguous/
duplicate/rejected records, queue peaks 2 records / 705855 bytes. No `result.json`
existed at inspection. The in-progress receipt is incomplete, as expected; it
must not be represented as the final clean receipt or a successful 900-second run.
Wait for completed native/wire/resource/receipt/server/CSV reconciliation and
source_unchanged verification. Preserve interrupted/prior outcomes separately.

Read evidence fingerprints:

```text
40c880e4b7f03f5987b6bb685b6e63215c616e59494045186d489a5d0eccb369  reportportal-day2-final-source-20261013.json
42e0377de3ca0c68974c69a1e8e30293dde78ae3f82978bb6a2d64e7c28d3bb6  full-suite-final-portable-1.json
ce35e2ef7705cd43993b67516f08bb2019429e499fa8d3856dd93a35bd7a67c8  real-20261013T121454-242a70/summary.json
a986981df2e2bb95eea595c763313b57f97aa9284458d86fceaf60185c5f7801  verify-80-final-source.json
5209aa37285b52a6621613e102c110d748883cad86b21a335fb3e751f8dcdfa6  private-make-public-false-final-source.json
4e642aa482ebe9dc2d692f4dce3538556f1ce7b817c365a89980fefc2462b6e8  private-disabled-final-source.json
```

Absolute evidence locations are linked above; live metrics are not frozen and
are deliberately not included as completed-result fingerprints. **Verdict PENDING.**

## Acceptance Checklist

The following earlier final-review requirements are retained as the closure
checklist. Completed source/artifact inspection is documented above and in the
final decision below; none authorizes out-of-scope production certification.

1. Immutable final source snapshot and per-file hashes for wrapper, operators,
   SDK, features, harnesses and tests, with matching runtime versions and fresh
   commands/results. Explain any changes after a test began.
2. Security/controller evidence with exact origin/controller version, policy
   readback, anonymous read/write/list matrix, both revocation transitions and
   retained bytes/hash, plus gateway/browser playback and rollback record.
3. Actual >=900-second single-process endurance evidence: one PID, monotonic
   start/end, iterations/seed/request digest, resource trace/limits, observed
   queue and batch bounds, native outcomes, complete receipt, RP ownership/
   counts/statistics and CSV byte/SHA reconciliation.
4. Actual proxy-to-real-RP fault evidence: sanitized events identifying whether
   uploads were forwarded, honest delivery categories and observed server logs/
   artifacts, original owners, replay/checkpoints, duplicate observations and
   native interrupt/business-failure outcomes. Preserve failed runs as failures.
5. Strict failure/idempotence evidence for storage operations and safe final
   sizing, including stable lifecycle rule count and quota/capacity readback.
   Include the actual pinned-image absent-bucket v3 Job, original and v2 failed Job logs,
   and strict inspection failures. Explicit `NoSuchBucket` must succeed without
   creating a bucket or changing policies/data; authorization, unreachable-server
   and unclassified inspection errors must remain failed, never 'already private'
   or 'revocation verified'. Bind results to the exact image and rendered script,
   and never classify free-text 'not found' alone as an absent bucket.
6. Resolved source/focused evidence for all four additional endurance conditions,
   preserved aborted-run outcome, and exact disposition of the fault manifest's
   gemspec delta. Only then bind a fresh uninterrupted >=900-second run and the
   complete scoped evidence set to the immutable final snapshot.

The final scoped decision below supersedes earlier PENDING entries. No heavy
validation was rerun by this reviewer, and no implementation or deployment
mutation was performed.

## Final Decision At 2026-10-13T12:36:36Z

**PASS: scoped Day 2 security, portable ingress, endurance, upload-chain faults
and storage-operations repairs.** The reviewer independently read and recomputed
the completed artifacts, rather than adopting Manager's requested verdict or
relabeling an earlier PASS as new evidence. Prior failure/abort history remains
preserved. This is acceptance of the tested bounded local workload and deployed
configuration, not a universal reliability or production certification.

Primary result:
[result.json](/private/tmp/reportportal-day2-endurance-20261013/live-20261013T121643-c8d687/result.json).
Launch **94**, UUID `a1c5117a-1c84-4106-9510-067fc75a6714`, is recorded PASSED at
`http://rp-latest.localhost:80` in `superadmin_personal`.

| Independently Inspected/Recomputed Gate | Completed Evidence |
| --- | --- |
| Real sequential duration and source | 900.257309s, native_exit=0, PID 38671, source_unchanged=true. All 50 run-source hashes match the immutable baseline; current executable inputs still match. |
| Native and RP outcomes | 8 native cases with all steps passed; 8 RP cases passed, 45 items with unique UUIDs/valid parentage, 811 unique owned logs and matching launch statistics. |
| Delivery and final queue | Complete/local-settled receipt, cutoff=settled=confirmed=811; all loss/ambiguity/rejection/duplicate/metadata/degraded counters zero; timed_out=false. Queue closed, records/bytes zero, worker_alive=false. |
| Actual upload bounds | Re-read all 770 wire records: 811 serialized entries, maximum entity body 747447 bytes <2097152, maximum entries 2 <=20, one streamed CSV, matching Content-Length, all successful statuses and no parse/transport errors. |
| Resource and queue bounds | Recomputed 763 monotonic samples in one PID; 661 after 120s warmup, RSS maximum 124.109375 MiB, slope -0.1300900022 MiB/min, maximum 13 threads. Every sample respects 128-record/8388608-byte queue bounds; final peaks 2 / 744592. |
| Seeded business invariants and sustained reporting | 750 iterations, 1500 checked requests (750 ingest +750 margin), seed 20261013, 241 expected rejections, 31 huge JSON logs. All 750 summary iteration numbers present exactly once under original PBT action 1041; no mere-2xx acceptance substitution. |
| CSV original owner and integrity | Locally recomputed 273 bytes and SHA d46dd212f54f5f0802fb451341ff463410bca8f63e45b9ba93540b5a7ac142a4; saved server download matches under owner UUID 8ca608e0-c424-41d3-a6d0-ce642df1bc40, owner id 1037, log id 923. |
| Regression and real faults | Inspected 824/0 full-suite artifact and new source-bound 14/14 real fault matrix using RP_API_KEY environment. Earlier 49/0, initial 85/3 and rerun 85/0 remain historical results, not substituted final counts. |
| Bucket/gateway/operations | Previously inspected final-source GET/HEAD/206 Range and write/delete/list denial matrix, both revocation/data-preservation transitions, stable 30-day lifecycle/4GiB quota readback, and pinned-image absent-bucket v3 exit 0/script binding. Runbook correctly separates server-wide stale-upload settings and documents capacity/reserve/failure handling. |

The isolated PBT phase itself was 887.750049s; acceptance duration is the full
single process's endpoint/workflow/PBT/native-finalization interval, not PBT-only
time and not a sum of interrupted processes. Last recorded metric elapsed is
900.289359s. Recomputed RSS trend/maxima and wire counts agree with result.json.
The request-stream digest is
`743c1c717c3db0e80b74bc5228fa7f459712fb3cfc030d4ec28d4a12a00b4267`.

### Documentation-Only Post-Run Delta

The immutable manifest and run both record README SHA
`bb8e82445ed22d31e4708c1d5765dc895f4b1f692831d3007eb96ebf5428d5e7`.
Current README SHA is
`d525dd83c26a39eefc65a2da72508418c8c47c161c9c2eec640e7bd6c76e369c`.
Its recorded modification time is 12:32:31 UTC, after result.json at 12:31:45 UTC.
The reviewer read the updated portable setup and local-evidence annotation.
Comparing all immutable snapshot entries and all run-source entries to current
files found **only this README difference**; executable/test/deployment inputs
remain identical. The frozen manifest is not rewritten to hide the delta.

### Limits And Provenance

The reviewer recomputed saved evidence, but did not repeat authenticated live
tests, mutations or the full suite. CSV remote bytes/ownership are the harness's
recorded authenticated query result checked against the actual local file, not
a second reviewer download. Strict inspection failure is supported by the
current failing-default branch/unit coverage and preserved real unclassified
failure; the reviewer did not newly inject authorization/network outages into
MinIO. This does not imply every failure mode was separately exercised live.

No claim is made for production HA, Huawei cloud/class compatibility, TLS/full
M5 certification, live Linux endurance, backup/restore readiness, registry
publication, historical migration, new authenticated-media delivery, exactly
once, SIGKILL zero loss, universal zero memory leak, or ILM/quota eliminating
DiskPressure. Clearing business traffic targets the documented mock. Anonymous
intranet object reads remain intentional; listing/write/delete stay denied.
Manager's browser Launch 94 visual/operations report was still forthcoming and
is not needed to fabricate or extend these completed evidence claims.

Completed run fingerprints, all under the linked run directory:

```text
c5ce641f0d74b272e23a19e708f8fb1bd7e4bb41c1f044f23147010067122ea4  result.json
2cf806bf344eed93b69e65e775aa176c452def42b33691d7c8e50d4e9a5bd57a  receipt.json
81d37b67d09dc5ca3af46aa7bb7d46d99b2face04ac151db39550e6845f16a37  wire.ndjson
87b1d23761d8d854733965a8ebbf86be500368b35cecfe875b9474fbee4bae49  metrics.ndjson
3cc44d5a7addd04b72e378548540ec152036d587c238a97c960edcfdb73624bb  pbt.json
791e27c328266f0d0602420b98507d1a0a005dd46e6956ae4fa55f240450c0aa  cucumber.json
```

## Initial Source Fingerprints

Captured after the initial targeted checks; not the immutable final snapshot.

```text
7d61814536d1ea8abd19a92ec25c2106916365eaa1a5d6b942ddc0330f95055b  helm/reportportal-rich-experience/templates/minio-bucket-config.yaml
727cd714ee896d77b7cb1d2d47485ec539c3516591d484e783e3318d406c0057  helm/reportportal-rich-experience/files/reconcile-video-bucket.sh
59e9be44506c7cad9e6efb048c00b77b23a00ad7f02a2a22ae844f5028d51776  helm/reportportal-rich-experience/templates/minio-init-job.yaml
8457598df3b713523f4936e26690c96814b38e21e4cbfb567194e8a1c2e2ba08  helm/reportportal-rich-experience/templates/ingress-extension.yaml
bd751aed22032b777d25a5b7f23e0b5c0a15791fa9c1d3e61b1b706ba87d966d  examples/day2_endurance/support.rb
22979e05111512b14d9944651ca03701ec403b1d9daccd6ec4b340ed8f5295e2  examples/day2_endurance/run.rb
1c186fd118bf0591f8d3bb81a131cfa5cbaa9999033623a94d629bf8d030b88a  examples/day2_endurance/reconcile.rb
be1d9f8a5eb8c8988009e56a70f0187db8a2873fbe95ae89e1dc3b03d3ddee60  examples/day2_faults/http.rb
66b58b6288059409f51075b9b5846400c3fc2ea18ace9b869a5e0a3ebe3755d1  examples/day2_faults/live_validation.rb
a1a37e76b67eaa369fd711ce4249f2fc78459a99a7f3cccad3f64c66a9982077  examples/day2_faults/run_live.rb
5b17e762b53f75937ddf2aa58939113e80a3091a45efc2bffbf17778ad39c42a  spec/helm/day2_security_spec.rb
08529d107284a65969070e33e1a25000e95b5d2650e5e75ea443c1646e4f900e  spec/day2/endurance_contract_spec.rb
baf29aff228a4b97bc3e0e354f68cf1c9e9e18ca003e8419a26cf09a25431695  spec/day2/fault_live_gate_spec.rb
```
