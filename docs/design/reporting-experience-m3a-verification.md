# M3A verification record

Status: M3A accepted within documented scope. Master UI verdict: PASS, 2026-10-07. The RP GET parameter-order observation and Cucumber 10 native message/HTML formatter failures remain disclosed, accepted limitations; they are not represented as passing checks.

## Candidate and regression gates

The clean candidate was exported from base commit `d9688b74a177cb359747fcd81e599d3528e9f3c3` into `/tmp/m3a-20261006-clean.pdw748`, then populated only with the approved M3A source, fixture, test, example, and documentation paths. README was unchanged and not copied. Source/candidate SHA-256 pairs and the base binding are recorded in `tmp/m3a-20261006/clean-candidate-hashes.txt`; all listed pairs matched at candidate creation. The candidate was not staged or committed, and the source worktree's duration changes and dirty manifests were left untouched.

| Gate | Result | Evidence |
| --- | --- | --- |
| Fixture runner, Cucumber 10.2.0 | Passed, 8 scenarios / 40 steps; child exit 0 | `tmp/m3a-20261006/clean-example.log` |
| Optional example wrapper, progress + ReportPortal formatter | Passed, 8/8 scenarios and 40/40 steps; `RP_ENABLED=false`, formatter output separate from progress STDOUT; child exit 0 | `tmp/m3a-20261006/clean-optional-wrapper.log` |
| Optional example wrapper, pretty + ReportPortal + native JSON | Passed, 8/8 scenarios and 40/40 steps; native JSON has 8 scenarios; child exit 0 | `tmp/m3a-20261006/clean-pretty-wrapper.log`, `tmp/m3a-20261006/clean-native.json` |
| Full RSpec on clean candidate | Passed, 159 examples / 0 failures; child exit 0 | `tmp/m3a-20261006/clean-rspec.log` |
| Ordinary Cucumber on clean candidate | Passed, 1 scenario / 3 steps; child exit 0. The repository's ordinary profile excludes `@reportportal_live`, so this is the existing base-profile check, not the M3A fixture run. | `tmp/m3a-20261006/clean-cucumber.log` |
| Clean-candidate load smoke | Passed requiring the package and Cucumber formatter; child exit 0. | `tmp/m3a-20261006/clean-load-smoke.log` |
| Focused M3A subprocess integration | Passed, 2 examples / 0 failures. Mock ReportPortal assertions cover 2 Suites, 8 statistical Scenarios, 40 actions, unique UUIDs/parents, 16 one-to-one rich logs before finish, exact substituted action titles, outline metadata, rich table/JSON content, and 8/8 mock statistics. | `tmp/m3a-20261006/focused-rspec.log`, `tmp/m3a-20261006/mock-api.json` |
| Outgoing outline parameter order | Passed in strict WebMock-recorded POST payloads: all six outline Scenario requests carry parameter keys in AST order `record,value,template`; values are asserted separately. This is the SDK/request-payload gate. | `tmp/m3a-20261006/mock-api.json`; integration assertion in `spec/reportportal_cucumber/cucumber/m3a_integration_spec.rb` |
| Cucumber 9.2.1 targeted compatibility | Passed in an isolated candidate-only bundle. Fixture wrapper: 8/8 scenarios, 40/40 steps, child exit 0. Targeted M3A/AST/StepDesc RSpec: 22 examples / 0 failures, child exit 0. No repository Gemfile or lockfile was changed. | `tmp/m3a-20261006/cucumber9-wrapper.log`, `tmp/m3a-20261006/cucumber9-rspec.log` |
| Cucumber 10.2.0 native message formatter control | Standalone, without ReportPortal, with the correct `{string}` + DataTable callback arity `|record, table|`, `--format message` exits 2 with `undefined method 'map' for nil` at `cucumber/formatter/message_builder.rb:144` (`argument_group_to_message`). This is a version-specific native formatter limitation, not a general Cucumber or reporter conclusion. | `tmp/m3a-20261006/native-no-rp.stderr.log`, `tmp/m3a-20261006/native-no-rp.stdout.log` |
| RP + progress captured-argument control, no native message formatter | Passed on Cucumber 10.2.0: 8/8 scenarios, 40/40 steps; child exit 0. The same fixture exercises the standard captured `{string}` + DataTable callback while ReportPortal is loaded; progress remained on STDOUT. With `RP_ENABLED=false`, no ReportPortal output file is produced. | `tmp/m3a-20261006/rp-progress-capture.log` |

## Live ReportPortal API and UI

Read-only preflight found Docker Desktop Kubernetes context `docker-desktop`, active namespace `reportportal`, and `http://localhost/ui/` returned HTTP 200. The established local demo credentials were used only in memory; no token was written to evidence. The real API run used the clean candidate and both fixtures, progress/pretty output on STDOUT and ReportPortal/native JSON on separate output files. Child exit was 0.

Launch: [M3A-20261006-114924-bbe391f9](http://localhost/ui/#superadmin_personal/launches/all/27), Launch ID `27`, UUID `0bd58d5a-7e6f-4f6b-ac49-71baf0684d0c`.

API observed 2 Suites, 8 statistical Scenarios, 40 actions, 16 rich actions and 16 rich logs; all UUIDs were unique, parent nesting and exact substituted action titles were correct, and statistics were total 8 / passed 8. All checks in the API result are true except `outline_parameter_header_order`; `all_checks_passed` therefore remains **false** in `tmp/m3a-20261006/live-api-result-verified.json`.

The false check is specifically the order returned by ReportPortal's GET item API. That endpoint returned outline parameters in varying orders for some items. In contrast, the strict WebMock capture verifies that all six outgoing SDK POST payloads preserve AST/header order `record,value,template`. No library acceptance guarantee is inferred for the server's GET response ordering; the API observation remains recorded as false, not normalized into a pass.

Master's UI verdict is **PASS (2026-10-07)**. Launch `27` is [http://localhost/ui/#superadmin_personal/launches/all/27](http://localhost/ui/#superadmin_personal/launches/all/27). Master confirmed 2 Suites (5 English + 3 Chinese), 8/8 passed, visible Feature descriptions, no extra Rule nodes, and a Passed-5 drill-down returning all five English Scenarios with Rule/Examples context, parameters, and Markdown table without empty results. The ReportPortal topology is `SUITE(hasStats=true) -> STEP(hasStats=true) -> STEP(hasStats=false)`.

English action UI passed: alpha table DOM is exactly `[['key','value','escaped','newline','trailing'],['alpha','first','A|B','line\nnext','']]`; the JSON preview shows record `alpha`, template `token-a`, escaped newline/backslash and literal ```` ```json ````. Chinese UI passed at `http://localhost/ui/#superadmin_personal/launches/all/27/690`; its action log is `http://localhost/ui/#superadmin_personal/launches/all/27/690/697/log`. Master confirmed 3 Chinese cases with Rule/Examples/parameter table; duplicate ordinary/background text is attributed distinctly while both Feature Background and Rule Background are visible. Chinese table DOM is exactly `[['key','value','escaped','newline','trailing'],['一组','first','A|B','line\nnext','']]`; JSON preview shows record `一组`, template `token-1`, escaped newline/backslash, and literal ```` ```json ````.

Master-provided screenshots: `tmp/m3a-20261006/ui-launch.jpg`, `tmp/m3a-20261006/ui-passed-cases.jpg`, `tmp/m3a-20261006/ui-table-alpha.jpg`, `tmp/m3a-20261006/ui-rich-alpha.jpg`, `tmp/m3a-20261006/ui-zh-cases.jpg`, and `tmp/m3a-20261006/ui-rich-zh.jpg`.

## Rendering and formatter limitations

The 16 KiB bound applies to rich action previews/`StepDesc`, not to original Feature or Scenario AST descriptions. Original descriptions are not bounded or placeholder-substituted. The source Scenario description intentionally retains `<record>`; the UI renders that literal as HTML and it is not visible in the current UI. The AST payload preserves it. Record this as a rendering limitation; do not change frozen implementation without review.

An independent no-ReportPortal Cucumber 10.2.0 native HTML formatter control also failed in the same `MessageBuilder#argument_group_to_message` path. Native JSON passed. The live gate therefore used pretty progress and native JSON alongside the ReportPortal formatter, not native message/HTML. Do not claim native message/HTML compatibility from the reporter run.

Evidence files are under `tmp/m3a-20261006/`. The candidate hash manifest binds copied inputs to source paths and base commit. No credentials/token are present in the recorded result. No cluster state was changed. M3A is accepted within this documented scope; the server GET-order behavior, unbounded/unsubstituted AST descriptions, and Cucumber 10 native formatter control failures remain explicit limitations. M3B/M3C are not included.
