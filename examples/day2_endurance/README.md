# Day 2 Sequential Endurance Acceptance

This runner exercises the existing clearing drafts in one Ruby process. Its
business target is the in-process Sinatra/Puma clearing mock, not a production
clearing service. It uses an available loopback port to avoid concurrent QA
listener conflicts. The reporting target in `live` mode is real ReportPortal.
No deployment changes, Git commits, or parallel workers are needed.

## Portable Setup

From the repository checkout, install its dependencies with a supported Ruby
(this acceptance was validated on Ruby 3.4.2):

```sh
bundle install
bundle exec ruby examples/day2_endurance/run.rb --mode smoke
```

Inject `RP_API_KEY` into the process environment using your CI or secret manager;
do not place its value in command arguments, source files, or evidence files.
Set the non-secret endpoint and project for your ReportPortal installation:

```sh
export RP_ENDPOINT='https://your-reportportal.example'
export RP_PROJECT='your_project'
bundle exec ruby examples/day2_endurance/run.rb --mode rp-smoke
bundle exec ruby examples/day2_endurance/run.rb --mode live --seconds 900 --iterations 750 --seed 20261013
```

The short reporting smoke is explicitly not duration acceptance. Start the
complete acceptance only after it passes and the reporting endpoint is stable.
Portable authentication uses an already-provided `RP_API_KEY` environment value
and `RP_ENDPOINT` / `RP_PROJECT`; `--endpoint` and `--project` can override those
non-secret settings. No local helper is loaded when `RP_API_KEY` is present.
Only an explicitly provided absolute `DAY2_AUTH_HELPER` can load a helper, and
only for a loopback/localhost target. There is no hardcoded helper fallback.
Empty/multiline credentials, endpoint userinfo, and project path injection are
rejected before authentication. Other environments do not need a helper.

`live` rejects durations below 900 seconds and iteration counts outside 500-1000.
The same process performs endpoint contracts, workflow/polling/CSV generation,
and seeded boundary JSON traffic. Iterations are evenly paced to the real
monotonic deadline, not simulated elapsed time. Default workload: 750 ingest
and 750 margin calls, plus endpoint/workflow calls. Invalid boundary ingest
requests must return the documented rejection contract; successful margin
responses must agree with an independent decimal oracle and its floor.
Margin tolerance is explicitly the larger of 0.01 and relative 1e-15 to account
for the mock's JSON floating-point representation of enormous values.
JSON serialization must preserve nested values and huge integers. At iteration
1 and every 25 iterations, a JSON log over 500 KB passes through real AppLog.
Mock latency is explicitly scaled to 0.01; chaos is disabled for reproducibility.
Request identifiers, timestamps, and nested generator choices are seeded or
fixed, and the ordered request stream has a SHA-256 digest. Server-generated
UUIDs and timestamps are intentionally not deterministic.

## Bounds And Evidence

Samples include actual process RSS and OS threads (Darwin `ps` / `ps -M`,
Linux `/proc/PID/status` with a bounded 16 KiB read), Ruby
threads, QueueProcessor admission/occupancy/peak/batch diagnostics, and delivery
receipts. Each sample checks queue peak records/bytes against the actual SDK
configuration. Defaults: 128 queue records, 8 MiB queue bytes, 2 MiB batch bytes.

`wire.ndjson` observes the actual Net::HTTP upload bodies, counts serialized
JSON entries, and hashes bytes consumed from streamed CSV multipart requests.
The final gate checks every actual body (including multipart framing) against
the effective 2 MiB / 20-entry limits, content length against consumed bytes,
request count against QueueProcessor sent batches, and uploaded entry totals
against the confirmed receipt. Authorization headers and raw bodies are not
stored. HTTP headers are outside the SDK's body-byte bound. Per-iteration
AppLog invariant summaries exercise reporting continuously rather than leaving
the reporting connection idle between large JSON logs.

Post-warmup limits are configurable before running:

| Variable | Default | Meaning |
| --- | --- | --- |
| `DAY2_WARMUP_SECONDS` | 120 | Exclude startup from RSS trend |
| `DAY2_RSS_MAX_MB` | 768 | Maximum observed post-warmup RSS |
| `DAY2_RSS_SLOPE_MB_MIN` | 8 | Maximum ordinary least-squares RSS growth/minute |
| `DAY2_THREADS_MAX` | 32 | Maximum observed post-warmup OS threads |
| `DAY2_QUEUE_MAX_RECORDS` | 128 | Actual SDK admission record cap |
| `DAY2_QUEUE_MAX_BYTES` | 8388608 | Actual SDK admission byte cap |

These are explicit operational acceptance limits for this bounded workload,
not a universal zero-memory-leak claim. RSS includes native formatter retention
of rich logs. Acceptance elapsed excludes subsequent RP query reconciliation;
resource samples include workload and native finalization, not reconciliation.

Every run creates a new private directory under configurable `DAY2_EVIDENCE_DIR`
or a portable `Dir.tmpdir` default. This local acceptance explicitly uses
`/private/tmp/reportportal-day2-endurance-20261013`. It contains native progress,
JSON, messages and HTML; console diagnostics; monotonic metric samples; PBT
seed/counts/request hash; generated CSV; final receipt; and `result.json` with
source hashes, versions, configured bounds, observed resources and checks.

Real reconciliation paginates launch/items/logs, compares native and RP case
names/outcomes/statistics, verifies parentage and exact log count against the
receipt's confirmed count, checks huge AppLog content, and downloads the CSV
from its original RP owner to compare byte length and SHA-256. All delivery
loss/ambiguity/rejection counters must be zero and the final receipt complete.
Reporting errors cannot replace an already-failed native business exit.

The optional local authentication path reuses `LatestRP.login` with its bearer only in memory. Its
historical constants and evidence paths are never changed; its information
write is redirected only for this process to the fresh directory. No raw
Secrets, credentials in command arguments, or credential files are used.
Default Cucumber never starts a listener: the draft server requires explicit
`CLEARING_MOCK_AUTOSTART=true`, and only the runner sets that option.

## Local Acceptance Evidence

The completed local run used Ruby 3.4.2 at `/opt/homebrew/opt/ruby/bin/ruby`,
the existing QA gem pool at
`/private/tmp/reportportal-round2-qa-20261011/v2/gems`, and the checkout's absolute
root `BUNDLE_GEMFILE` with `BUNDLE_IGNORE_CONFIG=1`. These machine-specific paths
are evidence context, not prerequisites for the portable commands above.
The explicit loopback-only authentication helper provisioned a bearer in memory;
the final harness itself selected the standard `RP_API_KEY` environment path.
Its fresh evidence is at
`/private/tmp/reportportal-day2-endurance-20261013/live-20261013T121643-c8d687`.
The executable inputs and this README stayed unchanged during the 900-second
run. This portable setup documentation was updated only after `result.json`
was written; the run's source manifest intentionally retains the prior README
hash. No executable harness or SDK source changed afterward.

## Unit Tests

```sh
bundle exec ruby -rrspec/core -e 'exit RSpec::Core::Runner.run(ARGV)' -- spec/day2/endurance_contract_spec.rb spec/day2/endurance_metrics_spec.rb spec/day2/endurance_inertness_spec.rb spec/day2/endurance_wire_spec.rb spec/day2/endurance_portability_spec.rb
```

Also run `spec/day2/endurance_portability_spec.rb` for explicit helper isolation,
credential/path validation, portable evidence directories, Linux/Darwin probes,
and the valid 500-iteration logging minimum. Unit temporary directories do not
require any precreated manager folder.

The contract unit suite includes 500 actual Rack-level ingest/margin pairs;
it is not evidence of elapsed duration or real RP delivery.
