# Day2 Fault Validation Results

Date: October 13, 2026. Branch: `codex/day2-security-endurance`.

## Scope

Changes are confined to new `examples/day2_faults/**` and
`spec/day2/fault_*` files. No SDK/library, Helm, Rakefile, Cucumber profile,
duration, deployment, Git commit, or descendant-agent changes were made here.

The actual SDK was exercised through a bounded stdlib TCP/HTTP streaming reverse
proxy. Local tests require no RP credentials. Native Cucumber tests used the
root bundle's Cucumber 10.2.0 and the prescribed Ruby/gem environment.

## Local Evidence

Latest portable focused run: **49 examples, 0 failures** in 15.43 seconds,
including the 14-scenario local rehearsal and a separate executable 14-case run
using normal `RP_API_KEY`/`RP_PROJECT` environment credentials with an unavailable
helper path. No historical backend-info or authentication file is required.

Evidence:
`/private/tmp/reportportal-day2-faults-20261013/local-20261013T114157-095186/`

Final focused-plus-existing delivery/replay/native regression rerun: **85
examples, 0 failures** in 16.26 seconds, saved as `regression-rerun.json`.
The first combined run's three failures in older 200 ms delivery tests remain
preserved in `regression.json`: two refusal cases timed out before settlement,
and the hidden-response case saw only one request within its budget. All 36
older tests passed separately in 3.44 seconds (`legacy-regression-rerun.json`),
then the combined run passed without source changes. These observations are
timing-sensitive; no SDK defect or specific cause is established. No SDK or
legacy test edits were made. No full-repository acceptance is claimed.

## Real RP Reconciliation

Manager explicitly authorized the supported Traefik gateway before real faults
ran. Endpoint: `http://rp-latest.localhost:80`. Namespace:
`reportportal-latest`. Project: `superadmin_personal`. Release bundle: 26.0.5;
verified source repository: `reportportal/service-api`; explicitly expected API
component: 5.15.4; optionally pinned instance:
`37a0d07e-2b74-4060-bf9d-0af7de57a549`. No historical backend file was read to
verify these values. Release bundle and component versions remain distinct.

Final portable harness run: **14 scenarios validated**, with unique
`day2-fault-` launches and proxy-only faults. `RP_API_KEY` was unset; credentials
came only from the explicitly configured local `DAY2_AUTH_HELPER` environment
path, recorded as `auth_source: local_helper`. The helper is optional, not
hardcoded in the harness. The bearer remained in memory. No malformed requests
or invalid credentials were forwarded to RP. No backend service was interrupted.

Evidence:
`/private/tmp/reportportal-day2-faults-20261013/real-20261013T114304-e813ff/summary.json`

The local and real runs share executed-input SHA256:
`1549a35e922b0751e0a314027e3c691dfff4849a6cc2ad461eed47cd826bc3fc`.
Each saved `source-manifest.json` records matching before/after harness, fault
tests, SDK, and bundle hashes. The real summary's manifest SHA256 is
`4ba2329421cdd49d824e8c45a693d04b0ed4295aa88771e37d678fbaccfd8ef7`.
`VALIDATION.md` is the explicitly excluded generated report; this results update
does not change the verified executed-input SHA. Runnable shebangs are portable
`#!/usr/bin/env ruby`, and README setup uses normal bundle commands.

| Scenario | SDK/Process Observation | Actual RP Observation |
| --- | --- | --- |
| Slow response | 1 confirmed | 1 owned log |
| 503, 504, success | 1 confirmed, 1 possible duplicate; identical multipart request digests | 1 log; artifact bytes/SHA verified |
| Synthetic 400/401 | Failed and spooled; one request, no retry | 0 logs; metadata forwarded normally |
| Disconnect/timeout | Ambiguous and spooled | 0 logs; faults occurred before forwarding |
| Accepted but hidden acknowledgement | 1 confirmed, duplicate risk retained after retry | 2 logs, not exactly once |
| Partial acknowledgement | 1 confirmed, 1 ambiguous/spooled; default uncertain replay refused | 3 logs after explicit duplicate replay; known-confirmed sibling stored once |
| Durable replay | Failed multipart retained; controlled replay confirmed | 1 log under original owner; artifact bytes/SHA verified; confirmed checkpoint caused no second send |
| Finish outage | Completion API failed | Original owner IN_PROGRESS before separately recorded controlled cleanup |
| Expired budget | Timed out, pending 1, spooled 0 | 0 logs; no retention guarantee |
| Queue saturation | Admitted 3, rejected 97; peak 3 records / 3,477 bytes within 4 / 4,096 bounds | 0 logs; pending 3 at deadline |
| Native SIGINT | Process exit 2; signal-to-exit 0.160 seconds; incomplete/spooled receipt | Launch FAILED; no open native items |
| Native business failure with strict 401 reporting | Original business message retained; exit 1 | Launch FAILED; no open native items |

Downloaded PNG artifacts were 68 bytes with SHA256
`2b4522f601eab119dfb31bba74a59a6757645c09820c8e78790cc68726998742`.
Harness-owned standalone owners were finished FAILED only after reconciliation;
native owners retain their actual formatter business outcome.

The first real run's 13/14 result remains preserved at
`real-20261013T112928-442749/`: the transient log was visible before its binary
attachment link. A read-only follow-up found the attachment. The harness was
corrected to wait under a shared three-second read-only visibility deadline;
the latest retry case needed two visibility queries. No SDK runtime was changed,
and no SDK defect was established by that observation.

## Limits

Confirmed acknowledgement does not mean exactly once. Accepted-but-hidden
responses remain uncertain and may duplicate on retry/replay. Expired budgets,
rejected admission, and storage quota failure are not zero-loss outcomes.
**SIGKILL cannot guarantee pending in-memory records**, because no shutdown hook
or flush runs. Only already published durable transactions are recoverable,
subject to integrity, quota, original endpoint/project binding, and open-owner
validation. No zero-loss or exactly-once claim is made.
