# reportportal-cucumber-ruby

`reportportal-cucumber-ruby` 是一个 Ruby Cucumber formatter gem，用于把 Cucumber 运行时事件实时映射到 ReportPortal Launch、Test Item 和 Log API。

实现遵循本项目的调研结论与约束：

- 最小上报流：`start launch -> start item -> save log -> finish item -> finish launch`
- 默认层级：`Launch -> Feature(SUITE) -> Scenario(STEP, hasStats=true) -> nested step/hook(STEP/HOOK, hasStats=false)`
- 支持 `rerun`、最小可用 `retry`、批量日志、附件、多进程 join、HTTP 重试与退出 flush
- 提供 World DSL：`rp_log`、`rp_attach`、`rp_step`
- Gherkin step 会保留 `Given/When/Then` 语义，并把 DataTable / DocString 渲染成 Markdown 描述
- JSON、文本、图片、视频等附件会自动做 MIME 识别与更友好的 RP 日志预览

> ReportPortal UI 的 Suite/Launch 统计链接会按 `type=STEP&hasStats=true&hasChildren=false` 查询统计叶子。
> 因此本 formatter 与官方 pytest-reportportal 的 BDD 拓扑对齐：Scenario 作为统计叶子 `STEP` 上报，Gherkin step/hook 作为非统计子 item 承载日志和附件。

## Installation

```ruby
# Gemfile
gem "reportportal-cucumber-ruby"
```

```bash
bundle install
```

## Usage

最小运行方式：

```bash
RP_ENDPOINT=https://reportportal.example.com \
RP_PROJECT=demo \
RP_API_KEY=token \
RP_LAUNCH="Ruby Cucumber Demo" \
bundle exec cucumber examples/minimal/features \
  --require examples/minimal/features \
  --format ReportPortal::Cucumber::Formatter
```

也可以使用 YAML 配置。默认会读取当前目录下的 `.reportportal.yml` 或 `config/reportportal.yml`。

```yaml
default:
  endpoint: https://reportportal.example.com
  project: demo
  api_key: token
  launch: Ruby Cucumber Demo
  launch_mode: DEFAULT
  launch_attributes:
    - key: build
      value: "0.1"
    - value: smoke
  batch_size_logs: 2
  join: true
```

如果使用 profile，可通过 `CUCUMBER_PROFILE` 选择：

```bash
CUCUMBER_PROFILE=ci bundle exec cucumber --format ReportPortal::Cucumber::Formatter
```

如果需要同时在终端查看 `pretty` 输出并启用 ReportPortal formatter，Cucumber 10+
要求其中一个 formatter 显式指定 `--out`，否则两个 formatter 都会默认写
STDOUT 并报错：

```bash
bundle exec cucumber features/deep_water \
  --format ReportPortal::Cucumber::Formatter --out tmp/reportportal-formatter.log \
  --format pretty
```

本地调试 `rp_log` 时可以开启控制台镜像，避免一边看终端一边等 UI
刷新时出现“暗箱感”。开启后，`rp_log` 会继续实时上报 ReportPortal，同时向
STDOUT 打印一份带 `[RP-MIRROR]` 前缀的日志：

```bash
RP_CONSOLE_MIRROR=true bundle exec rake rp:regression
```

DSL 同时支持 keyword 与位置参数两种 level 写法：

```ruby
rp_log(JSON.pretty_generate(response), level: :info)
rp_log(JSON.pretty_generate(response), "INFO")
```

## Configuration

支持的主要环境变量：

- `RP_ENDPOINT`
- `RP_PROJECT`
- `RP_API_KEY`
- `RP_LAUNCH`
- `RP_LAUNCH_DESCRIPTION`
- `RP_LAUNCH_MODE`
- `RP_ATTRIBUTES`，例如 `build:0.1,smoke`
- `RP_RERUN`
- `RP_RERUN_OF`
- `RP_REPORTING_ASYNC`
- `RP_BATCH_SIZE_LOGS`
- `RP_BATCH_MAX_BYTES`
- `RP_QUEUE_MAX_RECORDS`
- `RP_QUEUE_MAX_BYTES`
- `RP_QUEUE_OVERFLOW_POLICY`
- `RP_QUEUE_ADMISSION_TIMEOUT_MS`
- `RP_FLUSH_INTERVAL`
- `RP_FAIL_ON_REPORTING_ERROR`
- `RP_CONFIG` (YAML profile path; environment variables override YAML values)
- `RP_SPOOL_DIR`
- `RP_SPOOL_MAX_BYTES`
- `RP_EXIT_FLUSH_TIMEOUT_MS` (one shared monotonic shutdown/finalization budget)
- `RP_CLIENT_JOIN`
- `RP_CLIENT_JOIN_LOCK_FILE_NAME`
- `RP_CLIENT_JOIN_SYNC_FILE_NAME`
- `RP_CLIENT_JOIN_FILE_WAIT_TIMEOUT_MS`
- `RP_CONSOLE_MIRROR`
- `RP_DEBUG_CURL_MODE`
- `RP_DEBUG_CURL_DIR`
- `RP_VIDEO_UPLOAD_MODE`，默认 `reportportal_multipart`；设置为 `minio_markdown` 时会把 MP4 上传到 MinIO，并把可播放 `<video>` 片段作为普通 log 写入当前 step
- `RP_MINIO_ENDPOINT`
- `RP_MINIO_PUBLIC_BASE_URL`
- `RP_MINIO_BUCKET`
- `RP_MINIO_ACCESS_KEY_ID`
- `RP_MINIO_SECRET_ACCESS_KEY`
- `RP_MINIO_REGION`

Log delivery is bounded by default: at most 1,000 reserved records and 16 MiB
of accounted resident data (including 256 bytes of metadata allowance per
record), with requests limited to 20 entries and 8 MiB of complete serialized
body. Queue overflow rejects new logs and is visible in
`Formatter#reporting_diagnostics`; `RP_QUEUE_OVERFLOW_POLICY=block` opts into a
bounded admission wait (100 ms by default). Configure positive integer limits
in YAML or with the corresponding `RP_*` variables. File-backed attachments
retain their paths for streaming. `StringIO` contributes its complete backing
string without changing its cursor; other non-path IO sources are explicitly
rejected without reading them. The default rejection policy is intentionally
observable but lossy under overload, not a zero-loss guarantee. The
`sent_batches` diagnostic counts successful local API calls, not ReportPortal
log receipts.

`Runtime::LogBuffer#flush` and `#shutdown` (backed by
`Service::QueueProcessor`) retain Boolean compatibility and mean only that
accepted work locally settled before the call returned. The receipt-returning
`flush_receipt(timeout:)` and `shutdown_receipt(timeout:)` methods are also on
those classes; `Cucumber::Formatter` exposes only `reporting_receipt`. Use that
formatter method for the final frozen `DeliveryReceipt`. Its `cutoff`
is the accepted sequence captured when the barrier began; producers accepted
later do not extend it. Receipt fields include `settled`, v1 `confirmed`,
v2 `accepted_awaiting_persistence`, `spooled`, `failed`, `ambiguous`,
`possible_duplicates`, `pending`, and `rejected`. For a flush/shutdown receipt,
`rejected` is the cumulative rejection count observed at that cutoff call;
rejections have no accepted sequence and do not extend the cutoff. In
`reporting_receipt`, it is the whole-run cumulative total. `ambiguous` may also
be represented in the local spool; a spool copy does not make server
acceptance known. Async v2 acceptance is explicitly not proof of persistence.

`local_settled` is separate from `complete`. Whole-report `complete` is false
when any accepted log remains unconfirmed, an admission was rejected, evidence
capture did not close in time, a reporting start/finish call failed, or video
upload degraded to plaintext. `RP_FAIL_ON_REPORTING_ERROR` opts into propagating
reporting exceptions from synchronous formatter calls when there is no original
business failure. This is an exception-based opt-in, not a complete-report
policy: a background log-only failure can leave a passing run at exit `0` with
`complete=false`, even when strict reporting is enabled. Consumers requiring
reporting completeness must inspect the final `reporting_receipt`. Strict
reporting does not replace or mask an original business exception. The receipt
uses cumulative bounded counters and a bounded number of
active cutoff waiters; it does not retain per-log payloads or a run-long
outcome map. Shutdown/finalization shares one monotonic budget across its
barrier, transport retries, capture closure, item/launch finishes, and worker
join. A zero-timeout shutdown returns immediately and does not synchronously
spool outstanding work.

HTTP retries remain enabled, but a successful log response after a retry is
marked in `possible_duplicates`: an earlier attempt may have reached
ReportPortal before its response was lost. Such a record can be confirmed and
flagged as possibly duplicated; the whole-run receipt will not claim `complete`.

A Cucumber consumer can retain the reporter while Cucumber is active and inspect
the reporting result after normal formatter completion, without changing the
business result:

```ruby
reporter = nil

Before do
  reporter ||= ReportportalCucumber.current_runtime
end

at_exit do
  receipt = reporter&.reporting_receipt
  warn("ReportPortal report incomplete: #{receipt.to_h}") if receipt && !receipt.complete
  # Preserve the process/business exit status; reporting completeness is separate.
end
```

The runtime can be cleared after a normal Cucumber run, so retain the reporter
in the lexical `reporter` variable in `Before`. The formatter exposes
`reporting_receipt`; it does not expose `flush`, `shutdown`, `flush_receipt`, or
`shutdown_receipt`. During interruption, `at_exit` ordering is best-effort and
can precede formatter shutdown; the receipt may still be pending.

See the [M4-B implementation contract](docs/design/reporting-experience-m4b-implementation.md)
and [M4-B verification record](docs/design/reporting-experience-m4b-verification.md)
for the receipt schema and acceptance evidence.

### Durable spool and controlled replay

New failures are stored as private, versioned spool transactions under
`RP_SPOOL_DIR` (default `.reportportal-spool`). `RP_SPOOL_MAX_BYTES` defaults to
`268435456` bytes and must be a positive decimal integer. Existing unversioned
NDJSON remains available for inspection but is not imported or replayed
automatically. Spool data may contain sensitive test evidence; protect and
retain the directory accordingly.
`RP_CONFIG` supplies YAML defaults/profile values; environment variables
override those values. For replay, `--spool-dir` explicitly selects the spool
root. `RP_EXIT_FLUSH_TIMEOUT_MS` is shared across finalization rather than
multiplied per item. `RP_FAIL_ON_REPORTING_ERROR` is the exception-based strict
opt-in described above, not a requirement that every log be confirmed.

Replay is transaction-scoped and dry-run by default. Dry-run reads and validates
the selected transaction without credentials or HTTP requests. Execution
requires an explicit `--execute`, checks that the original launch and item are
still open, and refuses endpoint/project mismatches. It does not reopen or
recreate ReportPortal targets. A previously interrupted `in_flight` entry is
uncertain; `--allow-duplicates` explicitly consents to possible duplicate
delivery for this selected transaction only. Confirmed entries are never sent
again. Each entry receives one HTTP attempt, so a lost response remains
ambiguous rather than being retried automatically. Async v2 replay is not
confirmed and is refused.

Successful dry-run inspection does not mean the transaction is replayable.
Its `unavailable_artifacts` count is bounded to `0..1000` and includes known
unavailable markers on confirmed siblings; `unavailable_artifact_reasons` is
either `[]` or `["source_unavailable"]`, without artifact names or paths.
These markers have no replayable source bytes; retain the transaction and
recover original evidence separately. Replay never fabricates replacement
bytes. A missing published blob or checksum mismatch remains a hard error
(exit `2`), not a successful unavailable-marker inspection.

To discover transaction IDs without printing evidence contents, list the
committed marker filenames. This shows candidates only; the selected
transaction is still fully validated by the dry-run command, and malformed
committed transactions are reported as errors rather than treated as clean.

```bash
spool_dir="${RP_SPOOL_DIR:-.reportportal-spool}"
for marker in "$spool_dir"/tx-*.ndjson; do
  [ -f "$marker" ] || continue
  printf '%s\n' "${marker##*/}" | sed 's/\.ndjson$//'
done
```

```bash
reportportal-spool --spool-dir .reportportal-spool --transaction TRANSACTION_ID --dry-run
RP_ENDPOINT=https://reportportal.example RP_PROJECT=project RP_API_KEY=... \
  reportportal-spool --spool-dir .reportportal-spool --transaction TRANSACTION_ID \
  --execute --timeout 30
```

Exit `0` means dry-run inspection completed or requested confirmations were
persisted; execute exits `2` if evidence remains refused, pending, failed, or
ambiguous; invalid CLI syntax exits `1`. A dry-run never sends data.

### Scenario identity migration

Scenario identity remains `legacy` by default. To pilot stable identities, opt in
explicitly and keep the namespace fixed across CI workers that should share
history:

```bash
RP_IDENTITY_STRATEGY=stable_v1 \
RP_IDENTITY_ROOT="$PWD" \
RP_IDENTITY_NAMESPACE="payments-ci" \
bundle exec cucumber features --format ReportPortal::Cucumber::Formatter
```

In `stable_v1`, `RP_TEST_CASE_ID` and `@tms:` values seed an opaque
`rp:stable-v1:<digest>` ReportPortal `testCaseId`; the raw seed is not the wire
ID, and UI search by the raw TMS value is not guaranteed. The default `legacy`
strategy preserves existing IDs and histories. Stable-v1 starts a separate
history baseline; it does not rewrite, merge, or backfill server history. Review
the [M3B migration contract](docs/design/reporting-experience-m3b-implementation.md)
before opting in.

### Scenario business attributes (M3C)

Scenario attributes are opt-in; set `RP_SCENARIO_ATTRIBUTES_ENABLED=true` to
publish allowlisted business values on Scenario items only. The default keys are
`component,team,owner,layer,priority,browser,tms`; defaults are an empty JSON
object/list, for example `RP_SCENARIO_ATTRIBUTES='{"component":"payments"}'`.
Tags use `@key:value` and inherit from Feature, Rule, Scenario, then the executed
Examples row. A later scope overrides an earlier value; conflicting values for
one key in the same scope are ignored for that scope. `tms` is derived only from
the effective explicit test-case ID (`RP_TEST_CASE_ID` first, otherwise the
existing scenario ID tag selection). Existing `@tms:` identity tags still work;
the attribute mapper does not independently reselect the ID from inherited
tags or configured defaults. See the [usage example](examples/m3c_attributes/README.md)
and [M3C implementation contract](docs/design/reporting-experience-m3c-attributes-implementation.md).

### Scenario source, CI, and TMS links (M3C)

Scenario references are separately opt-in and default to disabled. Set
`RP_SCENARIO_LINKS_ENABLED=true` to append configured Source, CI Run, and TMS
Markdown links to the existing Scenario description. Configure source links with
`RP_SOURCE_URL_TEMPLATE`, `RP_SOURCE_COMMIT`, and `RP_SOURCE_ROOT`; the template
uses `{commit}`, `{path}`, and `{line}`. Configure an explicit run URL with
`RP_CI_RUN_URL`, and a TMS template with `{id}` using
`RP_TMS_URL_TEMPLATE`. No CI provider or environment variables are detected
automatically. See the [links example](examples/m3c_links/README.md) and
[M3C links contract](docs/design/reporting-experience-m3c-links-implementation.md).

Links are description-only metadata. This does not add ReportPortal link fields,
logs, or test items, and does not affect scenario identity or the separate
business-attribute setting. The implementation uses bounded, validated URLs;
invalid references are skipped without including their raw values in diagnostics.
This repository's local request-capture tests do not certify a live ReportPortal
UI deployment.

## DSL

在 step definitions 里可直接使用：

```ruby
rp_log("business checkpoint")

rp_attach(File.binread("tmp/screenshot.png"),
  name: "screenshot.png",
  mime: "image/png",
  message: "screenshot after login")

rp_attach("tmp/failure-recording.mp4",
  mime_type: nil,
  message: "screen recording for the failed step")

rp_step("Prepare data") do
  rp_log("seed user")
end
```

`attachment` 结构参考 `pytest-reportportal` 的使用体验，支持 `name`、`bytes`、`mime` 三元组；文件路径形式会以 path-backed multipart 上传，适合大附件，避免在 step 里整文件读入内存。

### Triple-Track Smart Logger

深层业务 helper 可以不依赖 Cucumber World 参数，直接使用线程局部代理
`AppLog`。它会把同一条诊断路由到三个轨道：终端摘要、Cucumber
Event Bus / HTML 报告，以及 ReportPortal 当前 Step。

```ruby
AppLog.info("Margin Payload", attach: true, json: { status: "ok" })
AppLog.error("Payment failed", attach: true, file: "tmp/failure.png")
```

`attach: false` 时只输出终端摘要，不会污染 Cucumber/RP 报告。`json:`
payload 会在终端保持一行摘要，并在 Cucumber/RP 中写入 Markdown fenced
JSON。Cucumber 的 stdout formatter 可能会额外展示 `world.log` 内容；这是
Cucumber 原生报告轨道的输出，不是 ReportPortal 重复上报。

最小黑盒验证：

```bash
RP_ENDPOINT=http://localhost \
RP_PROJECT=superadmin_personal \
RP_API_KEY="$TOKEN" \
RP_LAUNCH="triple-track-smart-logger-$(date +%Y%m%d%H%M%S)" \
bundle exec cucumber -P features/triple_track/triple_track_logger.feature \
  --format ReportPortal::Cucumber::Formatter --out tmp/triple-track-rp.log \
  --format html --out tmp/triple-track-report.html
```

附件和 step 的绑定规则：

- `rp_attach` 默认挂到当前 active step，而不是漂到 scenario 外层
- `application/json` 附件会自动 prettify，并把 JSON 代码块追加到日志消息
- `text/plain` / `.log` 附件会在日志消息中展示前 100 行预览，完整内容仍保留在附件文件中
- 图片、JSON、文本、PDF 等附件继续走 ReportPortal multipart
- ReportPortal 当前通用附件视图对 MP4 内联播放支持有限；如需浏览器内播放录屏，设置 `RP_VIDEO_UPLOAD_MODE=minio_markdown`，客户端会将 `.mp4` 流式上传到 MinIO/S3，并在当前 step 写入包含 HTML5 `<video>` 的普通 log

## Reporting Experience (Improvement Branch)

`AppLog` keeps the existing terminal-only default. Use `report: true` to send a
message through Cucumber and the active RP formatter without requiring a physical
file attachment. `report: false` overrides `attach: true`; omitting `report:` keeps
the legacy `attach:` behavior. DEBUG and ERROR retain their levels in RP; plain
Cucumber `log` messages remain INFO.

Bind a logger in your consumer project's `features/support/env.rb`:

```ruby
require "reportportal_cucumber"

Around do |_scenario, run|
  AppLog.with_logger(Automation::CucumberLogger.new(world: self)) { run.call }
end
```

The scope restores the previous thread/fiber-local logger even when the scenario
raises. Native Cucumber reporting also works when the RP formatter is not enabled.

```ruby
AppLog.debug("Margin inputs", report: true, json: { account: "A-17", amount: 100 })
AppLog.info("Local diagnostic", report: false)

# Record an already observed exchange; this helper performs no HTTP request.
AppLog.http(
  method: :post,
  url: "https://clearing.example.test/trades",
  request: { headers: { "Authorization" => "Bearer token" }, body: { amount: -1 } },
  response: { status: 400, body: { code: "INVALID_AMOUNT" } },
  duration_ms: 84,
  expected_status: 400
)
```

`AppLog.http` defaults to report delivery, prints only a concise terminal summary,
and reports Request/Response Markdown with bounded body/header previews. It
redacts common credential headers, URL credentials, and structured sensitive keys
before rendering. An explicitly expected 400 is INFO; an unexpected status or
transport error is ERROR; an unspecified 4xx/5xx is WARN. These levels do not
replace test assertions or change a scenario's result.

Cucumber's `pretty` formatter may also echo the native `world.log` content to the
terminal. The compact summary guarantee applies to AppLog's own output, not to
other formatters independently rendering the same evidence.

The HTTP helper's redaction is not a universal PII filter. Existing `rp_log`,
ordinary `AppLog` messages/JSON, raw files, screenshots, and videos are not
automatically sanitized by that helper. Review artifacts before uploading them.
Failure-evidence and assertion diagnostic text is separately credential-redacted
before clipping; inputs above 64 KiB, malformed JSON-shaped diagnostics, and URLs
that cannot be parsed safely are replaced with a fixed omission marker. This
bounded policy also applies to transport-error warning text and spool exception
metadata. It does not sanitize raw file/video bytes, ordinary `AppLog`
messages/JSON, legacy `rp_log` content, arbitrary attachment contents, automatic
Step/manual-step exception or backtrace logs, or native Cucumber core failure
payloads. If a framework publishes safe `rp_evidence` and then re-raises the
original browser error, separate legacy failure logs may still carry it; this
sanitizer does not mutate or suppress that error. The HTTP helper does not
automatically attach complete HTTP bodies when its preview is truncated.

RP text/JSON attachment previews are bounded to 16 KiB and 100 lines for both
paths and bytes; the full attachment remains available. Path-backed previews use
bounded reads. The native Cucumber `AppLog(file:)` route still reads the file into
memory, so prefer direct `rp_attach(path)` for large RP-only artifacts. External
video logs include an ordinary **Open video** link alongside the video markup;
playback still depends on the deployed RP renderer, browser, codec, and access policy.

### Failure Evidence API

Capture the active Step target while that Step is open. `rp_capture_target`
returns an opaque handle, or `nil` when reporting is disabled or there is no open
action. Pass it explicitly when evidence is produced by a helper thread; the
handle remains valid only while its original action is open.

```ruby
target = rp_capture_target # Capture inside the open Gherkin Step.
begin
  perform_risky_action
rescue StandardError => error
  rp_evidence(action: "Submit order", error: error, target: target)
  raise
end
```

The API signatures are:

```ruby
rp_capture_target
rp_evidence(action:, error:, url: nil, details: nil, artifacts: [], target: nil)
```

`rp_evidence` returns `true` when evidence is queued and `false` when reporting
is unavailable or the target is invalid, foreign, or already closed. Omitting
`target:` uses only the currently open action. It never falls back to a Scenario,
Launch, later Step, or hook when the original Step has closed; a rejected late
call does not retarget evidence.

Each artifact is a hash with either `path:` or `bytes:`, and optional `name:` and
`mime:`. Path-backed artifacts remain paths for streaming upload, so large files
do not need to be read into memory by the caller. In-memory `bytes:` artifacts
are limited to 1 MiB and larger values are rejected. The tester owns screenshot,
console, and video capture and decides which binary artifacts to provide.

### Caller-Owned Browser Failure Evidence

`AppLog.assertion` records a redacted, bounded diagnostic comparison; it does not
raise or affect Cucumber pass/fail. Browser capture remains entirely caller-owned.
For example, with Playwright Ruby 1.62, a consumer can keep a screenshot and
console excerpt when a locator fails, report them, and re-raise the original error:

```ruby
require "fileutils"

target = rp_capture_target # Save attribution while the Gherkin Step is open.
begin
  page.get_by_role("button", name: "Submit").click
rescue Playwright::TimeoutError => error
  FileUtils.mkdir_p("tmp")
  screenshot = "tmp/submit-failure.png"
  begin
    page.screenshot(path: screenshot) # Explicit caller-owned capture.
  rescue StandardError
    screenshot = nil # A secondary capture failure must not replace the locator error.
  end
  begin
    console_excerpt = page.console_messages.last(20).map(&:text).join("\n")
    AppLog.assertion(
      name: "Submit button is actionable",
      expected: "click succeeds",
      actual: error.message,
      passed: false,
      details: "Console:\n#{console_excerpt}"
    )
    artifacts = screenshot ? [{ path: screenshot, name: "submit-failure.png" }] : []
    rp_evidence(
      action: "Submit order", error: error, url: page.url,
      details: "Console:\n#{console_excerpt}",
      artifacts: artifacts, target: target
    )
  rescue StandardError
    # Reporting failures must not replace the original Playwright error.
  end
  raise
end
```

This consumer-side example adds no Playwright dependency and does not
automatically inspect pages, capture screenshots, or record video.

Run the deterministic sample without RP (no external business request):

```bash
mkdir -p tmp
bundle exec cucumber examples/reporting_experience/features \
  --require examples/reporting_experience/features \
  --format pretty --format html --out tmp/reporting-experience.html
```

To also report it to your configured RP project, set `RP_ENDPOINT`, `RP_PROJECT`,
and `RP_API_KEY`, then append:

```bash
--format ReportPortal::Cucumber::Formatter --out tmp/reporting-experience-rp.log
```

The structural plan and acceptance gates are in
`docs/design/reporting-experience-v1-2.md`. This increment does not change the
Scenario statistics type or claim a native RP network-inspector component.

## Design Notes

- 所有 HTTP 请求都经过 `ReportportalCucumber::Http::Client`
- 支持同步 `/api/v1` 与异步 `/api/v2` 前缀切换
- launch/item 创建请求会预生成 `uuid`，重试时复用，降低重复创建风险
- `Runtime::LogBuffer` 在后台线程按 `batch_size_logs` 或 `flush_interval` 触发批量发送
- 发送失败会按指数退避重试；最终失败则写入 spool 目录
- 多进程 join 通过文件锁和 sync 文件共享 `launchUuid`
- `ReportPortal::Models::StepDesc` 负责把 Gherkin Step 转成 Markdown 描述
- `Transport::MultipartHelper` 负责 multipart `json_request_part` 与 binary parts 的一致性校验和 MIME 识别
- `Transport::MinioUploader` 负责可选的 MP4 外部存储链路，使用 path-style S3 API 直连 MinIO，避免视频文件进入 RP multipart 导致前端附件视图崩溃
- `RP_DEBUG_CURL_MODE=true` 会通过 logger 输出可复制的 `curl` 命令；multipart 请求会把临时 form 文件写入 `RP_DEBUG_CURL_DIR`

## Testing

```bash
bundle exec rspec
bundle exec cucumber
```

测试覆盖：

- 请求体映射与 `testCaseId` 生成
- HTTP retry/fail-fast
- 批量日志 flush
- fork 多进程 join
- formatter 事件序列、附件、失败日志、rerun 载荷

## Kubernetes / Helm

本仓库提供一个 ReportPortal umbrella chart，用于部署官方 ReportPortal
Helm chart，并额外创建 `automation-videos` Public Bucket 与同源 Ingress
路由，服务 `minio_markdown` 视频播放模式：

```bash
helm repo add reportportal https://k8s.reportportal.io/
helm dependency update helm/reportportal-rich-experience
helm install reportportal ./helm/reportportal-rich-experience \
  --namespace reportportal \
  --create-namespace
```

本地默认登录仍对齐 ReportPortal demo 习惯：`superadmin/erebus`。生产环境
请通过 `--set reportportal.uat.superadminInitPasswd.password=...` 覆盖。

默认会把 `/automation-videos(/|$)(.*)` 路由到 K8s 内部
`reportportal-minio:9000`，不做 path rewrite，因此浏览器访问
`http://localhost/automation-videos/videos/<file>.mp4` 时仍然是 MinIO
path-style bucket URL。

## Runtime Dependencies

- `cucumber`：formatter 需要挂接 Cucumber 事件总线
- `aws-sdk-s3`：可选 MP4 外部存储链路需要兼容 MinIO 的 S3 API；普通图片/JSON/TXT 附件不依赖该链路
- `mime-types`：根据文件名和 MIME 元数据自动补全附件 content type / 后缀，保证 RP 图片、视频和文本附件预览稳定

其余实现尽量使用 Ruby 标准库：`Net::HTTP`、`JSON`、`Time`、`SecureRandom`、`Base64`、`File`、`Mutex`、`Queue`。

## Known Limitations

- 多机 join 暂不支持，当前仅支持同机文件锁协作
- join 模式下默认只有 primary 进程负责 `finish launch`
- Scenario Outline 参数提取提供了通用入口，但对不同 Cucumber 事件对象的细节兼容仍以常见结构为主
- spool 文件当前采用 NDJSON + 附件目录的简化格式

## License

MIT
