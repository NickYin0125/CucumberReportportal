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
- `RP_FLUSH_INTERVAL`
- `RP_FAIL_ON_REPORTING_ERROR`
- `RP_CLIENT_JOIN`
- `RP_CLIENT_JOIN_LOCK_FILE_NAME`
- `RP_CLIENT_JOIN_SYNC_FILE_NAME`
- `RP_CLIENT_JOIN_FILE_WAIT_TIMEOUT_MS`
- `RP_DEBUG_CURL_MODE`
- `RP_DEBUG_CURL_DIR`
- `RP_VIDEO_UPLOAD_MODE`，默认 `reportportal_multipart`；设置为 `minio_markdown` 时会把 MP4 上传到 MinIO，并把可播放 `<video>` 片段作为普通 log 写入当前 step
- `RP_MINIO_ENDPOINT`
- `RP_MINIO_PUBLIC_BASE_URL`
- `RP_MINIO_BUCKET`
- `RP_MINIO_ACCESS_KEY_ID`
- `RP_MINIO_SECRET_ACCESS_KEY`
- `RP_MINIO_REGION`

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

附件和 step 的绑定规则：

- `rp_attach` 默认挂到当前 active step，而不是漂到 scenario 外层
- `application/json` 附件会自动 prettify，并把 JSON 代码块追加到日志消息
- `text/plain` / `.log` 附件会在日志消息中展示前 100 行预览，完整内容仍保留在附件文件中
- 图片、JSON、文本、PDF 等附件继续走 ReportPortal multipart
- ReportPortal 当前通用附件视图对 MP4 内联播放支持有限；如需浏览器内播放录屏，设置 `RP_VIDEO_UPLOAD_MODE=minio_markdown`，客户端会将 `.mp4` 流式上传到 MinIO/S3，并在当前 step 写入包含 HTML5 `<video>` 的普通 log

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
