# Day2 Upload-Chain Failure Validation

This harness connects the **actual SDK** to a bounded loopback HTTP fault proxy,
then to either a local in-memory HTTP sandbox or the explicitly authorized local
ReportPortal 26.0.5 installation. No SDK, Helm, duration, or deployment edits are
required. All launches use unique `day2-fault-` prefixes.

## Local Validation

Run from the repository root with Ruby and Bundler on PATH. The existing root
bundle pins Cucumber 10.2.0. The runner loads RSpec directly through Ruby, so it
does not depend on an RSpec executable wrapper. Executable scripts use
`#!/usr/bin/env ruby`; child processes use that Ruby's `RbConfig.ruby`.

```sh
bundle install
bundle exec ruby examples/day2_faults/run_local.rb
```

No credentials, cluster, or external network are needed. Tests use real TCP/HTTP;
WebMock is disabled only within the new real-HTTP example groups and restored
afterward. Sanitized receipts, occupancy diagnostics, request digests, spool
manifests, artifact SHA256s, native process output, and RSpec results are saved
under `reportportal-day2-faults/local-*` in Ruby's system temporary directory.
Set `DAY2_EVIDENCE_DIR` to choose another destination. Temporary local spools are
removed after their sanitized evidence is recorded.

Covered faults: slow RP; 503 then 504 then success; deterministic pre-forward
disconnect and timeout; accepted-but-hidden acknowledgement; partial batch
acknowledgements; item/launch finish outage; native Cucumber SIGINT; expired total
flush budget; queue record/byte saturation; spool quota failure; and durable
artifact replay to the original open owner. Replay checkpoint tests reconstruct
the proxy and replay objects before verifying that confirmed entries are not
sent again. Native tests preserve the original business failure under 400/401 in
both strict and non-strict reporting modes.

## Real ReportPortal: Explicit Opt-In

**Wait for Manager's ready notice. Do not use the old gateway or a preview merely
because it appears reachable.** The live script will not authenticate or send
fault traffic without all required gates. Normal use requires `RP_ENDPOINT`,
`RP_PROJECT`, `RP_API_KEY`, and an explicit `DAY2_EXPECTED_API_VERSION`. Supply
the API key through your existing secret environment, never a command argument
or checked-in file. No historical backend-info file or local auth helper is
required.

```sh
export DAY2_MANAGER_READY=true
export RP_ENDPOINT=http://127.0.0.1:8080
export RP_PROJECT=your_authorized_project
export DAY2_EXPECTED_API_VERSION=5.15.4
# RP_API_KEY must already be present in the secret environment.
bundle exec ruby examples/day2_faults/run_live.rb --execute-local-rp
```

The script restricts destinations to the allowed local hosts (`localhost`,
`127.0.0.1`, `::1`, `rp-latest.localhost`) and verifies `/api/info` reports source
repository `reportportal/service-api` and the explicit expected component
version. `DAY2_EXPECTED_INSTANCE` optionally pins `server.details.instance`.
`DAY2_RP_ENDPOINT` overrides `RP_ENDPOINT` if supplied. `DAY2_RP_READY_URL`
optionally selects the Manager-approved local readiness route; otherwise it
defaults to the origin's `/api/info`. These options never permit remote
production targets. The key stays in memory; child credentials travel through a
private pipe, not command arguments, files, or inherited credential environment.

`/api/info` reports an API component version, not the release bundle number.
The authorized 26.0.5 bundle uses API component 5.15.4. Manager's October 13 ready
notice authorized `http://rp-latest.localhost:80/api/info` through Traefik.

For Manager's local run only, an explicit absolute `DAY2_AUTH_HELPER` Ruby path
can supply credentials instead of `RP_API_KEY`. The helper must implement
`LatestRP.login` and `LatestRP.bearer`; it is loaded only after local-target,
readiness, and backend checks. There is no implicit helper path or fallback to
historical files. `RP_PROJECT` remains required. Environment credentials take
precedence if both paths are configured. The supplied helper may retain its own
existing sanitized backend-info write behavior; the harness does not read that
file. A local example, with the path obtained from Manager:

```sh
export RP_ENDPOINT=http://rp-latest.localhost
export RP_PROJECT=superadmin_personal
export DAY2_MANAGER_READY=true
export DAY2_EXPECTED_API_VERSION=5.15.4
export DAY2_AUTH_HELPER="$MANAGER_APPROVED_AUTH_HELPER"
unset RP_API_KEY
bundle exec ruby examples/day2_faults/run_live.rb --execute-local-rp
```

Live tests send valid SDK traffic only. Synthetic 400/401/503/504 refusals are
returned **before forwarding**; no intentionally invalid credentials, oversized
requests, or malformed multipart are submitted to RP. Metadata passes normally
for log-only faults. The separate finish-outage case records the owner's open
state before controlled cleanup. Harness-owned launches/items are explicitly
finished as FAILED after evidence reconciliation, not presented as business
successes. Native launches keep the formatter's actual business outcome.

Artifact reconciliation uses a three-second shared read-only deadline because
RP can expose a log before its attachment link becomes visible. This does not
repeat an upload or change the SDK's delivery receipt.

Evidence under `real-*` includes actual SDK receipts, original launch/item UUIDs,
proxy status/digests, durable spool manifests/checkpoints, RP log ownership/counts,
downloaded artifact byte lengths/SHA256s, observed duplicates, and cleanup state.
An assertion/reconciliation failure stays a failure in `summary.json` and makes
the script exit nonzero; runtime bugs are reported to Manager rather than fixed
in SDK code here.

Both runners save `source-manifest.json` with before/after SHA256s of the harness,
fault tests, SDK sources, and bundle inputs. Source changes during a run cause a
nonzero exit. The live summary records the manifest SHA and source-input SHA.
`VALIDATION.md` is an explicitly excluded generated report so updating results
after a run does not invalidate the executed-source manifest.

## Standalone Proxy

The proxy is a reverse proxy, not an HTTP CONNECT proxy. Point `RP_ENDPOINT` at
its printed loopback endpoint; keep the actual project and credentials in the
SDK's normal private configuration. Upstream Host and request paths/query strings
are preserved for RP routing. Authorization is forwarded but never captured in
events. End-to-end headers, status, and entity bytes pass through; hop-by-hop
headers and HTTP transfer framing are necessarily regenerated. Request bodies
stream in at most 16 KiB chunks; there is no request-sized proxy buffer.

```sh
bundle exec ruby examples/day2_faults/proxy.rb \
  --upstream http://rp-latest.localhost --upstream-ip 127.0.0.1 \
  --scope logs --plan '[{"action":"status","status":503},{"action":"status","status":504}]'
```

Supported actions: `pass`, `status`, `disconnect`, `timeout`, `slow`, `hidden_ack`,
and `partial_ack`. `partial_ack` forwards the whole valid batch and hides all but
`keep` acknowledgements; it does **not** prevent RP accepting the hidden siblings.
`hidden_ack` forwards successfully and closes without delivering the response.
`--repeat` repeats only the final plan action. `--scope finish` targets PUT item
and launch completion; the default `logs` scope never faults metadata.

Defaults: 8 concurrent clients, 32 KiB headers, 8 MiB Content-Length request cap,
2 MiB response cap, 5-second request wall deadline, and 1,000 retained sanitized
events. Extra clients are closed rather than allocated new worker threads.
Normal responses stream; acknowledgement transformations buffer only within the
response cap. Inbound chunked requests, duplicate headers, and conflicting body
framing are rejected locally. The SDK uses Content-Length. The local sandbox
buffers bounded bodies for assertions; it is not a production RP emulator.

## Delivery and Replay Limits

`confirmed` means the SDK saw a supported acknowledgement, not exactly-once
delivery. `accepted_awaiting_persistence` is distinct from v1 confirmation.
`failed`, `ambiguous`, `pending`, `rejected`, `spooled`, and `possible_duplicates`
remain separate receipt categories. Spooling does not imply successful remote
delivery. Expired budgets or storage quotas can leave data unretained.

If RP accepted data but its acknowledgement was hidden, the proxy records
`uncertain: true`. The receipt may contain ambiguity or duplicate risk even when
RP visibly has the log. Retrying or explicitly replaying such entries can create
duplicates. Default replay refuses ambiguous entries. The controlled partial-ack
test explicitly enables duplicate replay, records its observed effect, and then
checks the persisted confirmed checkpoint prevents another resend. It never
claims exactly-once delivery.

Replay must retain the spool's original endpoint/project binding and original
open launch/item owners. When a spool was created through a proxy, restart the
same proxy endpoint with `--port ORIGINAL_PORT`, the same real upstream, and a
passing plan before executing the SDK's replay CLI. Do not rewrite the manifest
to change ownership or the endpoint. Successful dry-run validation alone does
not upload anything, and a closed owner is not silently replaced with a new one.

SIGINT is tested in a real subprocess, including its measured exit deadline.
**SIGKILL cannot guarantee pending in-memory records:** no signal handler,
at-exit hook, or flush can run. Already published durable transactions may be
recovered, subject to integrity, quota, and owner checks. This harness makes no
zero-loss, crash-atomic remote acceptance, or exactly-once guarantee.
