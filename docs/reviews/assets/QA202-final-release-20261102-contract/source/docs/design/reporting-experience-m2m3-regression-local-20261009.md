# M2+M3 Independent Local Regression (2026-10-09)

## Scope and identity

Executed against frozen candidate `/tmp/m2m3-regression-20261009-candidate`,
exported from `/tmp/m3c-links-20261007-clean`, with root HEAD
`d9688b74a177cb359747fcd81e599d3528e9f3c3`. This is local/packaged evidence
only; it does not replace the separate live/UI gate and makes no unconditional
delivery or zero-loss claim.

Candidate inventory contains 157 files (excluding generated `tmp/`, spool,
and `.DS_Store`). Its pre/post SHA-256 inventory is identical. All 84 `lib/`
and `spec/` files in the candidate match the root checkout; root `spec/.DS_Store`
is excluded. The 67 files covered by the initial protected-root SHA receipt
also match their post-run hashes. Receipts are in
`../../tmp/m2m3-regression-20261009/local/baseline/`.

The candidate locked lane is Ruby 3.4.2 / Bundler 2.6.6 / Cucumber 10.2.0 /
gem 1.1.0. Gate commands used a clean environment and explicit Homebrew Ruby
path. Lane 9 uses an evidence-only Gemfile and lockfile pointing at the frozen
candidate, with Cucumber exactly 9.2.1 and an isolated bundle under
`../../tmp/m2m3-regression-20261009/local/lane9/`. No candidate manifest or
root dependency file was changed.

## Gate matrix

| Lane / gate | Result | Evidence and limits |
| --- | --- | --- |
| Cucumber 10.2.0 `bundle check` | PASS, exit 0 | `lane10/verified-bundle-check.*` |
| Cucumber 10.2.0 full RSpec | PASS, 255 examples, 0 failures | Fresh clean-env rerun; `lane10/verified-full-rspec.*` |
| Cucumber 10.2.0 randomized full RSpec, seed 20261009 | PASS, 255 examples, 0 failures | `lane10/randomized-rspec.*` |
| Cucumber 10.2.0 focused M2+M3 set | PASS, 123 examples, 0 failures | Explicit M2 redaction/assertion/evidence, M3A AST, M3B identity/retry, M3C attributes/links unit and integration specs; `lane10/expanded-m2m3-rspec.*` |
| Cucumber 10.2.0 ordinary Cucumber | PASS, 1 scenario / 3 steps | `lane10/ordinary-cucumber.*` |
| Cucumber 10.2.0 reporting-experience consumer example | PASS, 1 scenario / 2 steps | `lane10/reporting-experience-cucumber.*` |
| Cucumber 10.2.0 formatter contract feature | PASS, 1 scenario / 3 steps | `lane10/formatter-contract-cucumber.*` |
| Cucumber 9.2.1 independent bundle install/runtime | PASS, exit 0 | Exact Cucumber 9.2.1; `lane9/Gemfile`, `Gemfile.lock`, `bundle-lock.*`, `bundle-install.*`, `runtime-identity.*` |
| Cucumber 9.2.1 full RSpec load | BLOCKED, exit 1 before examples | `bundle exec rspec` loads `spec/reportportal_cucumber/cucumber/formatter_spec.rb:7`, which directly requires `cucumber/core/events/test_step_started`. That file exists in the 10.2.0 lane's cucumber-core 16.2.0 and is absent from the 9.2.1 lane's cucumber-core 13.0.3. This is a test-loader/API compatibility issue, not an SDK assertion failure. Raw failed attempt: `lane9/full-rspec.stdout` and `.stderr`; 0 examples ran. |
| Cucumber 9.2.1 remaining RSpec set | PASS, 239 examples, 0 failures | Only `formatter_spec.rb` excluded because it cannot load under 9.2.1. Lane-only `GEM_HOME`/`GEM_PATH`; `lane9/remaining-rspec-laneonly-probed.*`. Do not report as the full 255-example suite. |
| Cucumber 9.2.1 child-runtime proof for remainder | PASS, 23/23 child processes | Probe receipts show each child as Cucumber 9.2.1 / cucumber-core 13.0.3 with both gem paths under the isolated lane; `lane9/full-remainder-child-runtime.jsonl` and `full-remainder-child-runtime-audit.*`. No child was counted as Cucumber 9 based only on its parent process. |
| Cucumber 9.2.1 focused M2+M3 set | PASS, 123 examples, 0 failures | Explicit M2/M3 scope; child runtime independently audited as above. `lane9/probed-expanded-m2m3-rspec-retry.*`, `child-runtime-receipt.jsonl`, and `child-runtime-audit.*`. |
| Cucumber 9.2.1 ordinary Cucumber | PASS, 1 scenario / 3 steps | `lane9/ordinary-cucumber.*` |
| Cucumber 9.2.1 reporting-experience example | PASS, 1 scenario / 2 steps | `lane9/reporting-experience-cucumber.*` |
| Gem build / normal isolated RubyGems install | PASS, version 1.1.0 | Built to `package/reportportal-cucumber-ruby-1.1.0.gem`; installed with dependencies into `package/gem-home`. Existing gemspec warnings are retained in `package/gem-build.stderr`. |
| Installed-gem provenance | PASS | Entrypoint, `AppLog.assertion`, `rp_evidence`, AST metadata, identity, attributes, and links source locations all resolve under `package/gem-home/gems/reportportal-cucumber-ruby-1.1.0`; Cucumber 10.2.0. `package/installed-smoke.*`. |
| Installed-gem consumer Cucumber | PASS, 1 scenario / 2 steps | Deterministic reporting-experience feature, no ReportPortal endpoint; `package/consumer-cucumber.*` and generated `package/consumer/reporting-experience.html`. |

## Coverage boundaries and follow-up

- The 9.2.1 full-suite gate is not green: one spec file is un-loadable due to a direct Cucumber 10-era event require. The other 239 examples pass under an isolated 9.2.1-only RubyGems path. Recommend a separate test-harness compatibility review; no SDK or test source was changed here.
- Cucumber 11 was not tested and is outside the declared supported range (`< 11`).
- Triple-track and deep-water feature files are tagged `@reportportal_live`; their hook requires a configured endpoint, project, and API key. The repository declares no mocked profile for these feature files, so they were not run or represented as passed. Their applicable local contracts were exercised by the formatter contract and mocked integration specs.
- No live ReportPortal, browser, UI, release, push, tag, SDK, or infrastructure operation was performed. Queued-delivery gaps already tracked for M4 are not addressed by these gates.
- Failed attempts remain in evidence: the Cucumber 9 full-load failure (`full-rspec.*`), an initial Bundler-path remainder attempt (`remaining-rspec-retry.*`), and an instrumentation path-quoting attempt (`probed-expanded-m2m3-rspec.*`). The corrected lane-only/probed reruns are separately named; failed logs were not presented as passes.
- Executor-owned writes are confined to `tmp/m2m3-regression-20261009/local/**`, this report, and the generated probe under the frozen candidate's `tmp/m2m3-regression-20261009/`. An untracked root `examples/m2m3_regression/` tree appeared during the run and was left untouched as concurrent workspace material. No git index, tags, or remote were changed.

## Continuation: Cucumber 9.2.1 Formatter Spec Compatibility

The original 9.2.1 full-suite collection blocker was isolated to the test's
require path, not the SDK: cucumber-core 13.0.3 defines the public
`Cucumber::Core::Events::TestStepStarted` in `cucumber/core/events`; the
9.2.1 public wrapper `Cucumber::Events::TestStepStarted` is provided by
`cucumber/events/test_step_started` and subclasses that same core event. The
event exposes the same `test_step` object. A manual API probe records before
hook, after hook, and ordinary Gherkin Step round-trips under Ruby 3.4.2 /
Cucumber 9.2.1 / cucumber-core 13.0.3 in
`continuation/event-api-harness-retry.stdout` (exit 0); its initial harness
coding error is retained as `event-api-harness.*`.

| Continuation gate | Result | Evidence and limits |
| --- | --- | --- |
| Original candidate `spec/`, compatibility-loaded full RSpec | PASS, 255 examples, 0 failures, exit 0 | `continuation/final-full-rspec.*`; run from the frozen candidate root using the lane9 Gemfile/bundle, UTF-8 locale, and `CUCUMBER_PUBLISH_QUIET=true`. An external `-r` shim intercepts only `require "cucumber/core/events/test_step_started"` and loads `cucumber/core/events`; no candidate spec or assertion was edited. |
| Cucumber 9.2.1 child-runtime audit for that run | PASS, 23/23 actual subprocesses | `continuation/final2-child-runtime.jsonl`; all report Cucumber 9.2.1 / cucumber-core 13.0.3 and isolated lane9 gem paths. `final2-standalone-child-bundle-map.log` records the two standalone-process specs' `env -u BUNDLE_GEMFILE` children mapped back to lane9 only; their assertions remained enabled. |
| Formatter test-copy compatibility diff | Review artifact only; not the final full-suite input | `continuation/candidate-copy/spec/reportportal_cucumber/cucumber/formatter_spec.rb` changes only the require and two event constant references; `continuation/candidate-copy.patch` shows the exact three-line adaptation. Assertion bodies are unchanged. The final PASS instead used the original candidate `spec/` plus the require shim. |
| Native, unshimmed 9.2.1 full RSpec | BLOCKED | The original `lane9/full-rspec.*` still records the direct-require collection failure before examples. Therefore this is a compatibility-harness PASS, not an unqualified/native full-suite PASS. |

The successful full run loaded the SDK from
`/private/tmp/m2m3-regression-20261009-candidate/lib/reportportal_cucumber/cucumber/formatter.rb:47`
(`continuation/final-runtime-source.*`). Candidate inventory pre/post hashes
are identical (157 files); all 84 candidate `lib/` and `spec/` hashes match
the root baseline, and the 67-entry protected-root pre/post hash diff is empty.
The candidate formatter spec SHA-256 remains
`23d8bd8e881715c1b3eacab688d8b0412da0f999bf9649125f9aa126368dc6be`.
The local report's pre-append and post-append SHA-256 values are recorded in
`continuation/report-hash-receipt.txt`.
The package installation and smoke receipts remain exit 0; all seven
source-location receipts resolve inside the installed 1.1.0 gem directory,
with Cucumber 10.2.0 (`package/installed-smoke.*`).

Failed continuation attempts were retained and are not green evidence:
`full-rspec-final.*` (copied lib duplicated the candidate gem and unset locale
caused 9 UTF-8 child failures), `full-rspec-finalretry.*` (missing copied
`spec_helper` load path), `original-spec-full-rspec.*` (two standalone child
processes discovered the candidate's unrelated 10.2.0 lock),
`original-spec-full-rspec-lane-root.*` (lane9 cwd broke a relative-path CLI
spec), and `final-candidate-root-full-rspec.*` (first env-observer argument
forwarding attempt). The corrected, separately named `final2-full-rspec.*`
is the only compatibility-loaded full-suite PASS. No candidate SDK/spec,
root manifest/spec, Git state, infrastructure, or duration/dependency work
was changed.
