# reportportal-cucumber-ruby

`reportportal-cucumber-ruby` 是一个 Ruby Cucumber formatter gem，用于把 Cucumber 运行时事件实时映射到 ReportPortal Launch、Test Item 和 Log API。

实现遵循本项目的调研结论与约束：

- 最小上报流：`start launch -> start item -> save log -> finish item -> finish launch`
- 默认层级：`Launch -> Feature(suite) -> Scenario(hasStats=true) -> nested step/hook(hasStats=false)`
- 支持 `rerun`、最小可用 `retry`、批量日志、附件、多进程 join、HTTP 重试与退出 flush
- 提供 World DSL：`rp_log`、`rp_attach`、`rp_step`

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

## DSL

在 step definitions 里可直接使用：

```ruby
rp_log("business checkpoint")

rp_attach(File.binread("tmp/screenshot.png"),
  name: "screenshot.png",
  mime: "image/png",
  message: "screenshot after login")

rp_step("Prepare data") do
  rp_log("seed user")
end
```

`attachment` 结构参考 `pytest-reportportal` 的使用体验，支持 `name`、`bytes`、`mime` 三元组。

## Design Notes

- 所有 HTTP 请求都经过 `ReportportalCucumber::Http::Client`
- 支持同步 `/api/v1` 与异步 `/api/v2` 前缀切换
- launch/item 创建请求会预生成 `uuid`，重试时复用，降低重复创建风险
- `Runtime::LogBuffer` 在后台线程按 `batch_size_logs` 或 `flush_interval` 触发批量发送
- 发送失败会按指数退避重试；最终失败则写入 spool 目录
- 多进程 join 通过文件锁和 sync 文件共享 `launchUuid`

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

## Runtime Dependencies

- `cucumber`：formatter 需要挂接 Cucumber 事件总线

其余实现尽量使用 Ruby 标准库：`Net::HTTP`、`JSON`、`Time`、`SecureRandom`、`Base64`、`File`、`Mutex`、`Queue`。

## Known Limitations

- 多机 join 暂不支持，当前仅支持同机文件锁协作
- join 模式下默认只有 primary 进程负责 `finish launch`
- Scenario Outline 参数提取提供了通用入口，但对不同 Cucumber 事件对象的细节兼容仍以常见结构为主
- spool 文件当前采用 NDJSON + 附件目录的简化格式

## License

MIT
