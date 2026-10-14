# Configuration reference

Most projects start with only an endpoint, project, API key, and Launch name.
Keep defaults for batching, retry, identity, and video until a concrete need
appears. See [getting started](getting-started.md) for the first working run and
[advanced reporting](advanced-reporting.md) before tuning delivery behavior.

## Configuration files and profiles

The formatter loads configuration relative to the **process working directory**:

1. Built-in defaults.
2. YAML `default:` plus the selected YAML profile.
3. Environment variables, which override YAML values.

Programmatic `Config.load(overrides: ...)` applies explicit overrides last; normal
Cucumber consumers do not need it. Set `RP_CONFIG` to select a YAML path;
otherwise `.reportportal.yml` is searched before `config/reportportal.yml`.

Example **`.reportportal.yml` in your automation project root**:

```yaml
default:
  endpoint: https://reportportal.example.com
  project: clearing_tests
  launch: Ruby Cucumber
  launch_description: Synthetic clearing regression
  launch_attributes:
    - key: component
      value: clearing
    - value: smoke
  join: false

profiles:
  local:
    enabled: false
  ci:
    launch: Clearing CI
    require_complete_reporting: true
```

Inject `RP_API_KEY` externally; omit it from committed YAML. The configuration
file does not interpolate shell placeholders such as `${RP_API_KEY}`. A
top-level profile mapping (for example `ci:`) is also accepted, but using
`profiles:` keeps the intent clear. Canonical YAML keys are shown below; legacy
dotted `rp.*` names are normalized through the same environment-key map.

From **your automation project root**, after the [integration setup](getting-started.md#3-connect-reportportal-and-integrate-an-existing-project):

```sh
mkdir -p artifacts
CUCUMBER_PROFILE=ci RP_ENABLED=true bundle exec cucumber --profile rp
```

Expected: Cucumber uses the `rp` command profile from `cucumber.yml`; the SDK uses
the YAML `ci` profile. `CUCUMBER_PROFILE` explicitly selects the reporting profile.
When it is absent, the SDK infers a profile from Cucumber's `-p`/`--profile` argument.
Use the explicit environment variable when the two profile names differ.

## Connection and Launch

| Environment variable | YAML key | Default | Type / use |
| --- | --- | --- | --- |
| `RP_ENABLED` | `enabled` | `true` | Boolean; `false` deliberately disables transport |
| `RP_ENDPOINT` | `endpoint` | Unset | RP base URL; do not append `/api/v1/<project>` |
| `RP_PROJECT` | `project` | Unset | RP project identifier |
| `RP_API_KEY` | `api_key` | Unset | Secret; required for enabled transport |
| `RP_LAUNCH` | `launch` | `Cucumber` | Launch display name |
| `RP_LAUNCH_UUID` | `launch_uuid` | Unset | UUID of an already-open, CI-owned Launch |
| `RP_LAUNCH_DESCRIPTION` | `launch_description` | Unset | Launch description |
| `RP_LAUNCH_MODE` | `launch_mode` | `DEFAULT` | RP Launch mode |
| `RP_ATTRIBUTES` | `launch_attributes` | `[]` | Environment: `build:42,smoke`; YAML: list of key/value or value-only objects |
| `RP_RERUN` | `rerun` | `false` | Boolean; request rerun Launch creation |
| `RP_RERUN_OF` | `rerun_of` | Unset | Original Launch reference for rerun |
| `RP_REPORTING_ASYNC` | `reporting_async` | `false` | Boolean; `true` selects `/api/v2` instead of synchronous `/api/v1` |
| `RP_CONFIG` | — | First existing default path | YAML file path, relative to the working directory unless absolute |
| `CUCUMBER_PROFILE` | — | Inferred from Cucumber CLI, otherwise none | Reporting YAML profile selector |

With `RP_ENABLED=true`, missing endpoint/project/key leaves transport inert and
the requested report incomplete (`metadata_failures=1`). No API/join/queue worker
is created. Set `RP_ENABLED=false` for local-only runs rather than relying on
missing credentials. A CI-owned UUID cannot be combined with `rerun`/`rerun_of`;
the conflict is rejected. See [shared Launches](ci.md#parallel-workers-and-a-shared-launch).

## Logger and reporting policy

| Environment variable | YAML key | Default | Type / use |
| --- | --- | --- | --- |
| `RP_CONSOLE_MIRROR` | `console_mirror` | `false` | Boolean; mirror RP-only `rp_log` to STDOUT as `[RP-MIRROR]` |
| `RP_FAIL_ON_REPORTING_ERROR` | `fail_on_reporting_error` | `false` | Boolean; propagate synchronous reporting exceptions when no original business failure exists |
| `RP_REQUIRE_COMPLETE_REPORTING` | `require_complete_reporting` | `false` | Strict Boolean; require a complete final whole-run receipt after native execution/teardown |
| `RP_DEBUG_CURL_MODE` | `debug_curl_mode` | `false` | Boolean; emit transport replay diagnostics; evidence may be sensitive |
| `RP_DEBUG_CURL_DIR` | `debug_curl_dir` | `.reportportal-curl` | Directory for multipart replay data |

`RP_CONSOLE_MIRROR` does not add native HTML evidence or change AppLog routing.
AppLog's per-call `report:` choice is separate from configuration. Use
`NO_COLOR=1` for uncolored auto-selected AppLog output; it is not an RP YAML key.
The completeness policy differs from exception propagation: a background upload
failure can leave business execution successful while its receipt is incomplete.
See [CI reporting policies](ci.md#choose-the-reporting-policy).

## Batching, queue, and finalization

| Environment variable | YAML key | Default | Unit / use |
| --- | --- | --- | --- |
| `RP_BATCH_SIZE_LOGS` | `batch_size_logs` | `20` | Positive record count per batch |
| `RP_BATCH_MAX_BYTES` | `batch_max_bytes` | `8388608` | Positive bytes; complete serialized HTTP batch body (8 MiB) |
| `RP_QUEUE_MAX_RECORDS` | `queue_max_records` | `1000` | Positive reserved-record count |
| `RP_QUEUE_MAX_BYTES` | `queue_max_bytes` | `16777216` | Positive accounted resident bytes (16 MiB) |
| `RP_QUEUE_OVERFLOW_POLICY` | `queue_overflow_policy` | `reject_new` | `reject_new` or `block` |
| `RP_QUEUE_ADMISSION_TIMEOUT_MS` | `queue_admission_timeout_ms` | `100` | Positive milliseconds; bounded admission wait for `block` |
| `RP_FLUSH_INTERVAL` | `flush_interval` | `1.0` | Seconds; minimum normalized value `0.1` |
| `RP_EXIT_FLUSH_TIMEOUT_MS` | `exit_flush_timeout_ms` | `5000` | Milliseconds; one shared finalization budget |
| `RP_SPOOL_DIR` | `spool_dir` | `.reportportal-spool` | Private durable transaction directory |
| `RP_SPOOL_MAX_BYTES` | `spool_max_bytes` | `268435456` | Positive bytes; spool quota (256 MiB) |

Queue accounting includes a 256-byte metadata allowance per record. Overflow
can reject evidence; `block` is bounded waiting, not unlimited buffering.
An accepted queued record is not a server confirmation. Finalization's budget
is shared across closure, flushing, retries, item/Launch completion, and worker
join. Retain queued source files until finalization settles.

## ReportPortal HTTP transport

| Environment variable | YAML key | Default | Unit / use |
| --- | --- | --- | --- |
| `RP_HTTP_OPEN_TIMEOUT` | `open_timeout` | `5` | Seconds, normalized to at least 1 |
| `RP_HTTP_READ_TIMEOUT` | `read_timeout` | `15` | Seconds, normalized to at least 1 |
| `RP_HTTP_WRITE_TIMEOUT` | `write_timeout` | `15` | Seconds, normalized to at least 1 |
| `RP_HTTP_RETRY_ATTEMPTS` | `retry_attempts` | `5` | Total attempt limit, including the initial attempt |
| `RP_HTTP_RETRY_BASE_INTERVAL` | `retry_base_interval` | `0.5` | Seconds; exponential-backoff base |
| `RP_HTTP_RETRY_MAX_INTERVAL` | `retry_max_interval` | `10.0` | Seconds; backoff cap |

These timeouts govern the SDK's RP HTTP client, not your test application's
HTTP client or browser. Configure those separately. A successful log response
after retry can still imply a duplicate from an earlier lost response; the
receipt records `possible_duplicates`.

## Scenario identity and business metadata

| Environment variable | YAML key | Default | Type / use |
| --- | --- | --- | --- |
| `RP_IDENTITY_STRATEGY` | `identity_strategy` | `legacy` | `legacy` or explicit `stable_v1` migration |
| `RP_IDENTITY_ROOT` | `identity_root` | Working directory | Root for source-derived identity |
| `RP_IDENTITY_NAMESPACE` | `identity_namespace` | Unset | Keep fixed across workers sharing history |
| `RP_SCENARIO_ATTRIBUTES_ENABLED` | `scenario_attributes_enabled` | `false` | Boolean; allowlisted Scenario attributes |
| `RP_SCENARIO_ATTRIBUTE_KEYS` | `scenario_attribute_keys` | `component,team,owner,layer,priority,browser,tms` | Comma-separated allowlist, or YAML list |
| `RP_SCENARIO_ATTRIBUTES` | `scenario_attributes` | `[]` | Environment: JSON object/list; YAML: defaults for business attributes |
| `RP_SCENARIO_LINKS_ENABLED` | `scenario_links_enabled` | `false` | Boolean; description links, independent from attributes |
| `RP_SOURCE_URL_TEMPLATE` | `source_url_template` | Unset | Source URL template with `{commit}`, `{path}`, `{line}` |
| `RP_SOURCE_COMMIT` | `source_commit` | Unset | Full hexadecimal commit ID |
| `RP_SOURCE_ROOT` | `source_root` | Working directory | Root for source-link paths |
| `RP_CI_RUN_URL` | `ci_run_url` | Unset | Explicit complete CI run URL; no automatic provider detection |
| `RP_TMS_URL_TEMPLATE` | `tms_url_template` | Unset | TMS URL template with `{id}` |

`RP_TEST_CASE_ID` is read by the formatter as an explicit Scenario ID override;
it is not a `Config` YAML key. Otherwise ID tags such as `@tms:CASE-42` are used.
A process-wide override applies to every Scenario in that process, so prefer
per-Scenario tags for a suite containing distinct cases. Stable-v1 hashes an ID
seed into the wire `testCaseId`; it does not send the raw TMS ID as that field or
merge existing history. See [identity and metadata](advanced-reporting.md#scenario-identity-attributes-and-links).

## Legacy same-host join

| Environment variable | YAML key | Default | Unit / use |
| --- | --- | --- | --- |
| `RP_CLIENT_JOIN` | `join` | `false` | Boolean; explicit legacy local-file coordination |
| `RP_CLIENT_JOIN_LOCK_FILE_NAME` | `join_lock_file_name` | `.reportportal.lock` | Lock filename |
| `RP_CLIENT_JOIN_SYNC_FILE_NAME` | `join_sync_file_name` | `.reportportal-launch.json` | Launch synchronization filename |
| `RP_CLIENT_JOIN_FILE_WAIT_TIMEOUT_MS` | `join_wait_timeout_ms` | `30000` | Milliseconds |

File join is deprecated for production shared completion. It is not a distributed
CI barrier: a primary can finish early, and late workers can split into another
Launch. `RP_LAUNCH_UUID` bypasses this local join and delegates the lifecycle to CI.

## Optional video / S3 storage

Ordinary image/JSON/text attachments need no MinIO configuration. Read
[video and storage boundaries](advanced-reporting.md#video-and-external-storage)
before using this optional route.

| Environment variable | YAML key | Default | Type / use |
| --- | --- | --- | --- |
| `RP_VIDEO_UPLOAD_MODE` | `video_upload_mode` | `reportportal_multipart` | Default multipart; optional `minio_markdown` video route |
| `RP_MINIO_ENDPOINT` | `minio_endpoint` | `http://localhost:9000` | S3 upload endpoint; development default |
| `RP_MINIO_PUBLIC_BASE_URL` | `minio_public_base_url` | `http://localhost:9000` | Browser-readable base URL; development default |
| `RP_MINIO_BUCKET` | `minio_bucket` | `automation-videos` | Dedicated video bucket |
| `RP_MINIO_ACCESS_KEY_ID` | `minio_access_key_id` | `minioadmin` | Development-only default; inject a real storage identity |
| `RP_MINIO_SECRET_ACCESS_KEY` | `minio_secret_access_key` | `minioadmin` | Development-only default; inject secret externally |
| `RP_MINIO_REGION` | `minio_region` | `us-east-1` | S3 region |
| `RP_MINIO_SSL_VERIFY_PEER` | `minio_ssl_verify_peer` | `true` | Strict Boolean; verify the S3 HTTPS certificate |
| `RP_MINIO_SSL_CA_BUNDLE` | `minio_ssl_ca_bundle` | Unset | Readable trusted PEM CA-bundle path |

`RP_MINIO_PUBLIC_ENDPOINT` is a compatibility alias for `minio_public_base_url`;
prefer `RP_MINIO_PUBLIC_BASE_URL` and avoid setting both. TLS options apply to the
optional storage uploader, not to the RP transport/browser or bucket access
policy. Use HTTPS, a trusted CA, explicit access controls, and retention settings
for real data; these development defaults are not production credentials.

## Validation and reference source

Use explicit `true`/`false` values for Booleans. Required-reporting and S3 peer
verification options reject invalid Boolean values rather than silently guessing.
Queue/batch/spool sizes and admission limits must be positive decimal integers.
Inspect configuration diagnostics by option name rather than printing secret
values. The [configuration implementation](https://github.com/NickYin0125/CucumberReportportal/blob/main/lib/reportportal_cucumber/config.rb)
is the source of these mappings/defaults.
