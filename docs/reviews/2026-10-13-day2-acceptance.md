# Day-2 Security And Endurance Acceptance

## Scope And Environment

Implemented on `codex/day2-security-endurance` after SDK v1.2.0. The SDK library
itself was not changed. This work hardens the companion Chart and adds repository
QA harnesses, not a new SDK release or M5 certification.

Local acceptance used Docker Desktop Kubernetes, namespace `reportportal-latest`,
ReportPortal bundle 26.0.5 / upstream Chart 26.8.12, API component 5.15.4 and UI
5.15.5. The canonical origin is `http://rp-latest.localhost:80`.
Traefik Chart 41.7.1 / Proxy 3.7.14 replaced the retired ingress-nginx controller.
The paused historical RP namespace and its data were preserved, not migrated.

## Actual Results

| Gate | Result |
| --- | --- |
| Full RSpec | 824 examples, 0 failures, 0 pending; final portable-source run |
| Focused endurance/CLI | 107 examples, 0 failures |
| Default Cucumber | 1 passed Scenario / 3 passed Steps; no mock listener autostart |
| Real sequential endurance | 900.257309 seconds in one Ruby PID, native exit 0 |
| Generative contracts | 750 ingest + 750 margin calls checked; 241 expected rejection contracts; 31 JSON logs over 500 KB |
| Delivery | 811 admitted / settled / confirmed; complete receipt; no pending, rejected, failed, ambiguous, spooled or possible-duplicate records |
| Real RP reconciliation | 8 passed Scenarios, 45 items and exactly 811 logs; parentage and per-iteration ownership/uniqueness checked |
| Queue | Peak 2 records / 744,592 bytes; final empty, closed, worker stopped |
| Actual uploads | 770 requests; maximum body 747,447 bytes / maximum 2 entries, within 2 MiB / 20-entry caps; one streamed CSV multipart request |
| Resources after 120-second warmup | 661 samples; maximum RSS 124.109375 MiB; OLS trend -0.13009 MiB/min; maximum 13 OS threads |
| CSV | Original owner `8ca608e0-c424-41d3-a6d0-ce642df1bc40`, 273 downloaded bytes; SHA-256 `d46dd212f54f5f0802fb451341ff463410bca8f63e45b9ba93540b5a7ac142a4` matched |
| Fresh real RP fault matrix | 14/14; normal private `RP_API_KEY` environment path; current gemspec/source manifest |
| Anonymous reads | Actual GET/HEAD 200 and 64-byte Range 206; original MP4 bytes/SHA retained |
| Anonymous mutation/listing | PUT, DELETE and bucket listing all 403 |
| Authenticated storage through Ingress | Signed S3 upload/download through Traefik succeeded and matched SHA; anonymous read allowed and DELETE denied; only the disposable probe was cleaned up |
| Revocation | Final-source `makePublic=false` and `enabled=false` both revoked access; original authenticated MP4 bytes/SHA unchanged |
| Absent disabled bucket | Actual pinned mc image completed safely; failed inspection remains a Job failure |
| Retention/quota | One stable 30-day current/noncurrent expiry rule; hard quota readback 4,294,967,296 bytes; MinIO PVC nominal capacity 8 GiB |
| Gateway | RP API and same-origin video healthy on port 80; aliased-header probe rejected with 400 |
| Browser | Launch 94 shows 3 Suites, Total 8, Passed 100%; clicking the first Suite's Passed 6 shows its 6 Scenarios rather than an empty result |
| Playback | Existing finalized Playwright MP4 loaded with readyState 4, duration 9.56 seconds; played to completion and sought to 2.58097 seconds while playing |

Resource and delivery results are observations for this specific bounded workload,
not a universal zero-leak, zero-loss, exactly-once or production-HA guarantee.
The RP UI rounds native Launch duration to 14m 59s; the acceptance clock includes
runner initialization and was independently monotonic, not inferred from that UI.

The [independent GPT-6.1 Sol review](2026-10-13-day2-independent-review.md) returned
**PASS for this scoped task**, recomputing the saved duration, wire/resource
observations, ownership/counts and CSV hash. It did not claim a second independent
live execution or certify Huawei/production HA.

## Failure Evidence And Limits

The first 900-second run remains FAILED: business execution passed, but the receipt
retained one possible-duplicate risk and required-reporting mode exited 2. An
intermediate run stopped for portability fixes remains ABORTED/FAILED. Neither
was relabeled as passing. Earlier unit and storage-probe failures are preserved.

Real proxy faults verified timeout/disconnect, 400/401 fail-fast, 503/504 retry,
partial/hidden acknowledgements, finish outage, deadline expiry, bounded admission,
native SIGINT and original-business-failure preservation. Accepted-but-hidden
responses actually duplicated logs; explicit uncertain replay also duplicated its
uncertain sibling. Confirmed checkpoints prevented further resend. SIGKILL cannot
retain records that exist only in memory; expired deadlines or quota failures can
leave data unretained. The suite does not stop shared backend services or fill the
host filesystem to simulate a physical disk-full condition.

The pinned community MinIO image ignores `AbortIncompleteMultipartUpload`; no
one-day bucket cleanup is falsely advertised. Actual server readback was
`stale_uploads_expiry=24h`, `stale_uploads_cleanup_interval=6h`. These are separate
server-wide settings, not changes made by the wrapper. ILM expiration is asynchronous.
The local backing filesystem was 73% used, with about 20.7 GiB available; monitoring
and other-bucket capacity remain necessary despite the 4 GiB video quota.

Huawei private-cloud procedures are documented but not executed: product/version,
controller class, ELB backend mode, TLS and storage sizing still require the platform
team. Anonymous intranet object reads remain intentional. No registry publication,
new GitHub Release, historical migration or M5 certification was performed.

## Evidence And Reproduction

- [Endurance Launch](http://rp-latest.localhost/ui/#superadmin_personal/launches/all/94).
- Authoritative endurance: `/private/tmp/reportportal-day2-endurance-20261013/live-20261013T121643-c8d687/result.json` plus metrics, wire observations, receipt, native HTML/JSON/messages and generated CSV.
- Full regression: `/private/tmp/reportportal-day2-endurance-20261013/full-suite-final-portable-1.json`.
- Fresh fault evidence: `/private/tmp/reportportal-day2-faults-final-20261013/real-20261013T121454-242a70/`.
- Security/controller evidence: `/private/tmp/reportportal-day2-storage-20261013/`; browser screenshots: `/private/tmp/reportportal-day2-ui-20261013/`.
- Executed-source snapshot: `/private/tmp/reportportal-day2-final-source-20261013.json`, 210 inputs, aggregate SHA-256 `a7fcda88bac2c9f43d39a3d3288b0ce9b3b74d38787d598789e1b46dbbddff62`.

Endurance executable inputs remained unchanged throughout the accepted run.
After completion, only its README's installation instructions were made portable;
the documentation-only delta is separately recorded by the implementation agent.
Generated acceptance/review reports are not executable inputs. Credentials are not
stored in these evidence files or source manifests.

From a source checkout with the development bundle and privately injected RP
credentials, use `bundle exec rake rp:duration`; use `bundle exec rake
rp:failure_stress` for the offline matrix. Live faults require the explicit local
readiness/version opt-in documented in `examples/day2_faults/README.md`.
Storage and Huawei procedures are in the Chart's `OPERATIONS.md` and
`HUAWEI_PRIVATE_CLOUD.md`; the candidate package is
`pkg/reportportal-rich-experience-1.2.0-rc.3.tgz`, not the older published rc.2 asset.

## Release Promotion

The accepted Day-2 source is promoted to SDK and companion Chart **1.3.0**.
ReportPortal remains **26.0.5** with upstream dependency **26.8.12**. The original
duration, fault and storage evidence above retains its actual candidate versions
and timestamps; version promotion does not retroactively change that evidence.
Fresh 1.3.0 packaging, regression and GitHub workflow results are recorded in the
release acceptance report. Subsequent cloud CI also identified and fixed an
older-JSON-parser binary Multipart compatibility issue; that follow-up is
documented separately and does not rewrite the original physical-run evidence.
