# API, UI, and logger best practices

Start with the [minimal integration](getting-started.md) so `AppLog` is bound to a
Scenario World. The examples below use **synthetic test data**. HTTP requests,
assertions, browsers, and capture policies belong to your test framework.

## Keep responsibilities easy to find

| Layer | Owns | Useful evidence |
| --- | --- | --- |
| Feature | Business behavior and examples | Intent, DataTables, DocStrings |
| Step definition | Orchestration and real assertions | Expected/actual business checks |
| API client | HTTP calls, authentication, timeouts | One observed exchange per call |
| Page object | Locators and user actions | Meaningful action/checkpoint |
| Support hooks | World/logger scope, browser lifecycle, failure capture | Hook failures and teardown evidence |
| CI | Worker outcomes, report artifacts, shared-Launch lifecycle | Exit status and final receipt |

Keep clients/page objects reusable: call `AppLog` without passing Cucumber World
through every method. Keep Scenario state in World instance variables, not global
pages, responses, or mutable loggers. For a clearing workflow, log a meaningful
checkpoint such as submission status or reconciliation totals rather than every
Ruby call or every grid cell.

## Bind one logger per Scenario

In **`features/support/env.rb`**:

```ruby
require "reportportal_cucumber"
World(ReportportalCucumber::Cucumber::World)

Around do |_scenario, run|
  AppLog.with_logger(Automation::CucumberLogger.new(world: self)) { run.call }
end
```

`with_logger` restores the previous logger in `ensure`, including on failure.
Use this once. If you already have an Around hook for a browser, wrap its setup,
`run.call`, and cleanup in this logger scope. Avoid `AppLog.bind(self)` without a
matching cleanup: it can leak the active logger into later work.

Binding is thread/fiber-local. A new helper thread/fiber does not automatically
inherit the Scenario's logger or action ownership. The simplest approach is to
return helper results and log them synchronously inside the Step. For background
RP failure evidence, capture an explicit target while the action is open, publish
with that target, and join the worker before the action returns. A retained
target cannot reopen a completed Step.

## Choose a route before choosing a level

| Call | Terminal | Native HTML/messages | RP |
| --- | --- | --- | --- |
| `AppLog.info("message")` (also trace/debug/warn/error/fatal) | One-line summary | No | No |
| `AppLog.info("message", report: true, json: payload)` | Summary; full JSON is omitted | Markdown JSON | Same native evidence at the active action |
| `AppLog.error("failure", report: true, file: path)` | Summary and filename | Log and attachment | Same native evidence at the active action |
| `AppLog.http(...)` | Compact exchange summary | Request/response Markdown by default | Same native evidence |
| `AppLog.assertion(...)` | Compact comparison summary | Expected/actual Markdown by default | Same native evidence |
| Native `log(...)` / `attach(...)` | Depends on formatter | Yes | Forwarded when the RP formatter is active |
| `rp_log(...)` | Optional console mirror only | No | RP-only log |
| `rp_attach(...)` | No | No | RP-only attachment |

The native/RP tracks require a bound World; RP also requires enabled/configured
transport and the formatter. With no bound World, `AppLog` is a terminal logger.
In normal Cucumber execution it forwards through the native event bus rather than
submitting the same evidence twice. The terminal `(Attached to Report)` suffix
describes requested routing, not confirmed delivery to the RP server.

Ordinary level methods accept `report:`, `json:`, and `file:`. The legacy
`attach: true` option enables reporting when `report:` is omitted; it does not
mean that a physical attachment is required. Explicit `report: false` wins over
`attach: true`. Supplying `json:`/`file:` alone does not enable reporting.

```ruby
AppLog.debug("Waiting for the batch", report: false)
AppLog.info("Batch completed", report: true, json: {accepted: 10, rejected: 0})
AppLog.warn("Retry used for a transient failure", report: true)
```

| Level | Recommended meaning |
| --- | --- |
| TRACE / DEBUG | Useful diagnostics for investigation; opt into report routing selectively |
| INFO | Business milestones, successful checks, expected negative responses |
| WARN | Recoverable or unexpected conditions that deserve attention |
| ERROR / FATAL | Failure diagnostics; actual test failure still needs an assertion/exception |

The compact guarantee applies to **AppLog's own output**. Native formatters,
including `progress` and `pretty`, can separately echo `world.log` Markdown/JSON
when they own STDOUT. To keep the terminal to AppLog summaries, give native
formatters their own output files, as in the current SDK runner; changing the
formatter name alone does not suppress rich evidence. `NO_COLOR=1` disables
automatically selected colors. RP DEBUG/TRACE logs may be hidden by the UI filter
even when they were uploaded.

## API tests: observe real calls, then assert

Instrument the client at the request boundary. Record the actual method, URL,
status, relevant headers/body, and elapsed time; return the response unchanged so
Steps can assert the business contract. `AppLog.http` performs **no HTTP request**
and **no assertion**.

Put this small GET client in **`lib/clients/observed_http.rb`**. It uses Ruby's
standard library and is suitable for a synthetic test endpoint; adapt headers
and bodies to your application's permitted evidence policy.

```ruby
require "net/http"
require "uri"
require "reportportal_cucumber"

class ObservedHttp
  def self.get(url, expected_status: nil)
    uri = URI(url)
    raise ArgumentError, "Expected an HTTP(S) URL" unless %w[http https].include?(uri.scheme) && uri.host
    request = Net::HTTP::Get.new(uri)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    response = begin
      Net::HTTP.start(uri.host, uri.port,
                     use_ssl: uri.scheme == "https",
                     open_timeout: 3, read_timeout: 10, write_timeout: 10) do |http|
        http.request(request)
      end
    rescue StandardError => error
      observe(method: :get, url: uri.to_s, error: error,
              expected_status: expected_status, duration_ms: elapsed_ms(started))
      raise # Preserve the transport exception and backtrace.
    end

    observe(method: :get, url: uri.to_s,
            request: {headers: request.to_hash},
            response: {status: response.code.to_i, headers: response.to_hash, body: response.body},
            duration_ms: elapsed_ms(started), expected_status: expected_status)
    response
  end

  def self.elapsed_ms(started)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
  end

  def self.observe(**exchange)
    AppLog.http(**exchange)
  rescue StandardError => error
    warn("HTTP evidence unavailable: #{error.class}")
  end
  private_class_method :elapsed_ms, :observe
end
```

Load the client from **`features/support/env.rb`**:

```ruby
require_relative "../../lib/clients/observed_http"
```

Add to **`features/step_definitions/api_steps.rb`**:

```ruby
When("I retrieve {string} expecting HTTP {int}") do |url, expected|
  @response = ObservedHttp.get(url, expected_status: expected)
end

Then("the HTTP status is {int}") do |expected|
  actual = @response.code.to_i
  passed = actual == expected
  AppLog.assertion(name: "HTTP response status",
                   expected: expected, actual: actual, passed: passed)
  raise "HTTP status: expected #{expected}, got #{actual}" unless passed
end
```

The When step owns the request/response diagnostic. The Then step owns the
comparison and the actual assertion. Replace the `raise` with your framework's
matcher if preferred; keep the assertion even though the logger already records
`passed: false`.

| Observed exchange | `AppLog.http` level | Does logging fail the test? |
| --- | --- | --- |
| 200, expected 200 | INFO | No |
| 400, expected 400 | INFO | No; an expected rejection can be a passing contract |
| 500, expected 200 | ERROR | No; assert the result separately |
| 4xx/5xx, no explicit expectation | WARN | No |
| Transport exception | ERROR | No; the client re-raises the original exception |

`AppLog.http` defaults to `report: true`; use `report: false` only when you
deliberately want terminal diagnostics. Request/response Hashes use `headers:`
and `body:`, with `status:` on the response. Do not invent options such as
`sensitive_keys:` on `AppLog.http`; its public signature does not accept them.
Pre-redact application-specific fields in the client before logging.

For POST/PUT bodies and a real local fixture, copy the
[current SDK API client](../examples/current_sdk/helpers/api_client.rb) and read
its [runnable example](../examples/current_sdk/README.md). Avoid logging the same
full response a second time as JSON unless that extra evidence answers a specific
question. For a large required body, store a redacted file and attach it explicitly;
the HTTP diagnostic's truncated preview does not automatically attach the full body.

## UI tests: log actions and own capture explicitly

The logger works with any UI driver. The snippets here use the same Playwright
Ruby API as the current example. Your project must install
`playwright-ruby-client`, its compatible Node CLI/browser, and create `@page`.
The SDK adds no Playwright dependency and does not capture anything automatically.

Keep locators and actions in page objects. For example, in
**`lib/pages/trade_page.rb`**:

```ruby
class TradePage
  def initialize(page)
    @page = page
  end

  def submit(quantity)
    AppLog.info("Submit synthetic trade", report: true, json: {quantity: quantity})
    @page.get_by_label("Quantity").fill(quantity.to_s)
    @page.get_by_role("button", name: "Submit", exact: true).click
  end
end
```

Adapt labels to the actual application. Keep your assertions in Steps and wait
for the application outcome using your driver's supported waits; this SDK does
not add retry/wait behavior to browser actions.

### Choose Step evidence or After-hook evidence

| Capture point | Owner | When to choose it |
| --- | --- | --- |
| Inside the failing action's rescue, before it returns | That still-open Gherkin/manual Step | Precise action ownership |
| Framework After hook, before browser cleanup | The open After Hook | Centralized Scenario-failure capture |

Use one default capture policy. Installing both examples below without a guard
can produce duplicate screenshots. An After hook cannot use a target saved from
the failed Step after that Step has closed.

For **Step-owned evidence**, put this module in
**`features/support/ui_evidence.rb`**. It assumes your framework has a live
`@page`, and its browser stays open until the action completes.

```ruby
require "fileutils"
require "securerandom"

module UiEvidence
  def with_ui_evidence(action)
    target = rp_capture_target # Called inside the currently executing Step.
    yield
  rescue StandardError => error
    begin
      directory = ENV.fetch("REPORT_DIR", "artifacts")
      FileUtils.mkdir_p(directory)
      path = File.join(directory, "failure-#{SecureRandom.hex(6)}.png")
      @page.screenshot(path: path, fullPage: true, timeout: 5000)
      AppLog.error("UI action failed: #{action}", report: true, file: path)
      # The screenshot already went through AppLog; do not attach it again here.
      rp_evidence(action: action, error: error, url: @page.url, target: target)
    rescue StandardError => evidence_error
      warn("UI evidence unavailable: #{evidence_error.class}")
    end
    raise # Preserve the original browser/assertion exception and backtrace.
  end
end

World(UiEvidence)
```

Call it **inside a step definition** after loading your page class:

```ruby
When("I submit a synthetic trade with quantity {int}") do |quantity|
  with_ui_evidence("Submit synthetic trade") { TradePage.new(@page).submit(quantity) }
end
```

The PNG follows AppLog's native-report route and is forwarded once to RP. The
`rp_evidence` call adds the RP failure diagnostic without resubmitting the PNG.
With `RP_ENABLED=false`, native evidence still works and `rp_evidence` returns
false. A capture failure remains secondary and the original action still fails.

For **After-hook evidence instead**, add to **`features/support/hooks.rb`** with
`fileutils`/`securerandom` loaded. Your browser lifecycle must keep `@page` open
through After and close it in the enclosing Around ensure:

```ruby
After do |scenario|
  next unless scenario.failed? && @page

  begin
    directory = ENV.fetch("REPORT_DIR", "artifacts")
    FileUtils.mkdir_p(directory)
    path = File.join(directory, "failure-#{SecureRandom.hex(6)}.png")
    @page.screenshot(path: path, fullPage: true, timeout: 5000)
    AppLog.error("Failed Scenario screenshot", report: true, file: path)
    rp_evidence(action: scenario.name, error: scenario.exception,
                url: @page.url, target: rp_capture_target)
  rescue StandardError => evidence_error
    warn("After-hook evidence unavailable: #{evidence_error.class}")
  end
end
```

This target belongs to **After**, and its screenshot belongs there too. The
[current SDK support setup](../examples/current_sdk/features/support/env.rb) and
[World helpers](../examples/current_sdk/helpers/world.rb) show the complete
Around/After/cleanup lifecycle in a runnable consumer. Each Scenario creates its
own BrowserContext. Teardown closes page/context/browser even on failure; cleanup
errors are surfaced on otherwise successful runs while an original test failure
keeps precedence. Avoid converting a failed locator into a newly raised generic
`RuntimeError`, suppressing it, or making a screenshot failure replace it.

### Use manual groups sparingly

Inside a Step, a meaningful group can help explain a multi-action workflow:

```ruby
rp_step("Prepare synthetic trade") do
  AppLog.info("Trade inputs ready", report: true, json: {quantity: 2})
end
```

`rp_step` adds a nonstatistical RP child; it does not create another Scenario
test. When RP is unavailable it still executes the block. Native Cucumber reports
keep their own Gherkin action structure; manual RP groups are not native Steps.
Use the Step wrapper above inside the group when its failure evidence should
belong to that group. Avoid a nested group for every Ruby method.

## Select attachments according to size and audience

| Evidence | Recommended route | Tradeoff |
| --- | --- | --- |
| Small selected response fields | `AppLog.info(..., report: true, json: safe_payload)` | Readable in all tracks; caller must redact it |
| Scenario failure PNG | `AppLog.error(..., report: true, file: path)` | Native and RP attachment; reads file into memory for native Cucumber |
| Large RP-only file | `rp_attach(path, name: ..., mime: ...)` | Path-backed streaming; no native copy |
| Structured RP failure plus RP-only artifacts | `rp_evidence(..., artifacts: [{path: ..., name: ..., mime: ...}], target: ...)` | Explicit open-action ownership; avoid also sending the same file via AppLog |
| Video | Caller-finalized recording, optional RP upload route | Browser, codec, storage, and renderer are separate concerns |

Inside **an open Cucumber Step/Hook**, an RP-only file attachment looks like:

```ruby
rp_attach("artifacts/reconciliation.csv", name: "reconciliation.csv",
          mime: "text/csv", message: "Sanitized reconciliation result")
```

The path must point to a real file and remain available until reporting settles.
`rp_attach` accepts a file path, File/Tempfile, StringIO, or byte string; arbitrary
non-path IO is refused without reading it. Text/JSON previews are bounded to
16 KiB and 100 lines; the full attached file is distinct from the preview.
`rp_evidence` accepts at most 16 artifacts per call and at most 1 MiB for each
in-memory `bytes:` artifact; use paths for larger artifacts. Its `true` return
means evidence admission succeeded, not server persistence. See
[advanced evidence limits](advanced-reporting.md#failure-evidence-and-action-ownership).

Video requires caller-owned recording/finalization, often context closure before
the finalized path is available. Publish to the then-open After/manual Hook node,
not the already-closed failed Step. See [video delivery](advanced-reporting.md#video-and-external-storage)
before enabling storage or assuming inline playback.

## Keep private data out at the producer

Structured HTTP diagnostics redact common credential headers, URL credentials,
and structured sensitive keys with bounded previews. Assertion/failure diagnostic
text has separate bounded credential redaction. **These are not general PII
filters**. Ordinary AppLog text/JSON, low-level `rp_log`, native logs, files,
screenshots, videos, and original exception/backtrace channels may contain private
data. Redaction in one diagnostic does not mutate a re-raised browser exception.

Use synthetic identifiers and an allowlisted set of response fields. Redact
application-specific sensitive fields before logging. Avoid authentication bodies,
cookies, real account balances, entire clearing exports, and screenshots of
secret-bearing pages unless your project's evidence policy explicitly permits
them. Apply the same access/retention rules to native HTML/messages, RP, spool,
and CI artifacts. Debug-curl replay files can contain full evidence; enable them
only for a controlled investigation.

## Check the useful result

For an API run, find the exchange under its action Step, the assertion under its
Then Step, and an expected negative response at INFO. For a UI failure, find the
original failed Step and the PNG under your selected Step/Hook policy. Inspect
native HTML/messages as well as RP, and collect the Cucumber exit status and
reporting receipt separately in [CI](ci.md). Do not use log severity or an
attachment-routing suffix as proof that a test or its reporting succeeded.
