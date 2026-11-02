# M1 Reporting Experience Verification

Date: 2026-09-25

Branch: `codex/reporting-experience-v1-2`

Result: AC01-AC12 pass on the final shared worktree after Luna's JSON byte-preservation fix. This is M1 mock/integration verification, not live ReportPortal browser acceptance.

## Final Run

Commands were run from `/Users/nick/Documents/New project` after the implementation owner declared the patch complete.

| Command | Result |
| --- | --- |
| `bundle exec rspec` | 114 examples, 0 failures. Includes the final JSON-byte-preservation regression. |
| `bundle exec cucumber --publish-quiet` | 1 scenario, 3 steps passed. |
| `bundle exec cucumber examples/reporting_experience/features --require examples/reporting_experience/features --format html --out tmp/reporting-experience-m1.html` | Exit 0; deterministic sample ran without making a business HTTP request. |
| Native HTML envelope assertion (below) | Passed: Request/Response exchange is associated with the expected Gherkin step; credential sentinel is absent. |
| `gem build reportportal-cucumber-ruby.gemspec --output tmp/reporting-experience-m1.gem` | Built `reportportal-cucumber-ruby` 1.1.0. |
| `gem install --local tmp/reporting-experience-m1.gem --install-dir tmp/m1-installed --ignore-dependencies --no-document --force` | Installed successfully under `tmp/m1-installed`. |
| `env -u RUBYOPT -u BUNDLE_GEMFILE GEM_HOME="$PWD/tmp/m1-installed" GEM_PATH="$PWD/tmp/m1-installed:$(ruby -e 'print Gem.path.join(":")')" ruby -I "$PWD/tmp/m1-installed/gems/reportportal-cucumber-ruby-1.1.0/lib" -e 'require "reportportal_cucumber/automation/http_exchange"; abort unless defined?(Automation::HttpExchange); require "reportportal_cucumber"; puts "installed gem helper and full load: ok"'` | Passed for standalone helper and full entry-point load from the installed gem. |
| `git diff --check` | Passed. |

Native HTML proof command:

```sh
ruby -rjson -e 'html = File.read(ARGV.fetch(0)); block = html[/window\.CUCUMBER_MESSAGES = \[(.*?)\];/m, 1] or abort "native messages not found"; block = block.sub(/,\s*\z/, ""); messages = JSON.parse("[#{block}]"); envelope = messages.find { |e| e["attachment"]&.dig("body")&.include?("### Request") }; abort "exchange attachment missing" unless envelope; exchange = envelope.fetch("attachment"); step_id = exchange.fetch("testStepId"); test_case = messages.find { |e| e["testCase"]&.dig("testSteps")&.any? { |s| s["id"] == step_id } }.fetch("testCase"); step = test_case.fetch("testSteps").find { |s| s["id"] == step_id }; pickle_id = step.fetch("pickleStepId"); pickle = messages.find { |e| e["pickle"]&.dig("steps")&.any? { |s| s["id"] == pickle_id } }.fetch("pickle").fetch("steps").find { |s| s["id"] == pickle_id }; abort "wrong Gherkin step" unless pickle.fetch("text") == "I record an expected trade rejection"; body = exchange.fetch("body"); ["Request", "Response", "POST", "INVALID_AMOUNT", "400", "84", "[REDACTED]"].each { |s| abort "missing #{s}" unless body.include?(s) }; abort "credential leaked" if html.include?("example-secret"); puts "native HTML proof passed: Request/Response attached to expected step, credentials redacted"' tmp/reporting-experience-m1.html
```

Artifacts: `/Users/nick/Documents/New project/tmp/reporting-experience-m1.html` (native Cucumber HTML with embedded message envelopes) and `/Users/nick/Documents/New project/tmp/reporting-experience-m1.gem` (97 KiB M1 load-smoke package). HTML proof found the exchange attached to `I record an expected trade rejection`, and confirmed Request/Response, POST, status 400, 84 ms, redaction markers, and no `example-secret` value.

## AC Evidence

| AC | Result and evidence |
| --- | --- |
| AC01 | Pass. AppLog and logger specs cover legacy `attach` behavior, `report: true`, and `report: false` precedence. |
| AC02 | Pass. Reporting-routing specs and real Cucumber subprocess/stateful RP mock verify one DEBUG and ERROR each at original levels and active step UUID; native `world.log` arrives once at INFO. |
| AC03 | Pass. Specs cover nested/exceptional context restoration and thread isolation of level and active step UUID. |
| AC04 | Pass. Disabled-RP World routing plus standalone helper subprocess specs verify no-RP use and helper loading without ReportPortal/Cucumber. |
| AC05 | Pass. HTTP helper and integration specs verify body-free terminal summary and Request/Response Markdown; HTML proof confirms the native exchange attachment. |
| AC06 | Pass. Helper specs cover expected 400 as INFO, unexpected status/transport error as ERROR, unspecified server error as WARN, without turning logging into an assertion. |
| AC07 | Pass. Adversarial redactor tests cover case-insensitive credential headers, recursive/JSON-string bodies, repeated query secrets, URL userinfo, custom keys, frozen input, and idempotence. |
| AC08 | Pass. HTTP preview specs cover byte/line limits, truncation marker, Unicode boundaries, and valid UTF-8. |
| AC09 | Pass. Payload specs compare small file-backed JSON and equivalent byte previews and spy on bounded file reads; transport remains path-backed. |
| AC10 | Pass. Payload specs cover byte/line caps and full attachment retention. Luna's final regression confirms JSON attachment bytes remain unchanged while the inline preview is formatted. |
| AC11 | Pass. Video preview specs verify a safe fallback link and no binary file read. |
| AC12 | Pass for M1 verification: full RSpec, ordinary Cucumber, gem build/install/load, clean diff check; no new runtime dependency was added and no duration work was modified or removed. See limitations below for why this is not release certification. |

## Limits And Deferred Gates

- No live ReportPortal endpoint, browser, or UI renderer was exercised. Native HTML proof is the local Cucumber HTML formatter and a stateful local/mock API integration, not ReportPortal's browser UI.
- Actual ReportPortal severity display, Suite filtering, Markdown rendering, video playback/seek/authentication/retention, and supported browser matrix remain unverified and deferred to live acceptance in later milestones, especially M5.
- Installed-gem loading is an M1 smoke check, not clean-room release certification. Installation used `--ignore-dependencies`; load resolution retained the host's installed gem paths. The gemspec's broad `examples/**/*`, `features/**/*`, and `spec/**/*` globs package unrelated dirty duration feature/spec files into this worktree-built gem. The artifact must not be treated as a release candidate.
- `gem build` succeeds with gemspec advisories: open-ended dependency requirements and `example.com` used for both homepage and source-code metadata. These were not changed as part of this verification task.
- The worktree remains intentionally dirty with implementation changes and unrelated duration-test work (`features/duration/`, related step definitions, and mock support). No production files, gemspec, or duration files were edited by the verification owner. No commit, push, merge, tag, or release was made.
