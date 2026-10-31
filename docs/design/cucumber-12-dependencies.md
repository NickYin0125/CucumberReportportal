# Cucumber 12 Dependency And Migration Brief

Verified locally on 2026-10-31 with Ruby 3.4.2 (arm64-darwin24), RubyGems 3.6.3,
and development Bundler 2.6.6. Isolated current consumers used Bundler 2.6.3.
This is dependency and packaging evidence, not a release
approval or a claim that other Ruby versions or remote CI ran.

## Release Lines And Shared Environment

- `maintenance/1.x` remains at immutable `v1.3.1`, commit
  `4ca2f770e0a84e83688f165ba04b4db8ef855cf9`, with Ruby >= 3.1 and Cucumber >= 9,
  < 11. The unchanged source is separately available at
  `/private/tmp/rp-cucumber12-legacy`.
- `codex/cucumber-12` prepares SDK 2.0.0 with Ruby >= 3.3 and Cucumber `~> 12.0`,
  >= 12.0.1. The SDK no longer constrains cucumber-expressions independently.
- Chart 1.3.1 / ReportPortal 26.0.7 are independent deployment versions and are
  not changed by this SDK dependency migration. Tags/publication require review.
- Main development dependencies are installed outside the checkout. Other agents
  can run commands from the target checkout with the following environment;
  neither local nor user Bundler configuration was modified, and no global gem
  was replaced:

```sh
export PATH=/opt/homebrew/opt/ruby/bin:$PATH
export BUNDLE_IGNORE_CONFIG=1
export BUNDLE_PATH=/tmp/reportportal-cucumber12-bundle-ruby342
bundle check
```

## Verified Upstream Requirements

The published `gem specification cucumber -v 12.0.1 --remote --yaml` matches
the [tagged upstream gemspec](https://github.com/cucumber/cucumber-ruby/blob/v12.0.1/cucumber.gemspec).
[RubyGems 12.0.1 metadata](https://rubygems.org/gems/cucumber/versions/12.0.1)
also confirms Ruby >= 3.3 and RubyGems >= 3.2.8. Exact runtime requirements:

| Dependency | Cucumber 12.0.1 requirement | Target lockfile |
| --- | --- | --- |
| base64 | `~> 0.2` | 0.3.0 |
| builder | `~> 3.2` | 3.3.0 |
| cucumber-ci-environment | `> 9`, `< 14` | 11.0.0 |
| cucumber-core | `>= 20`, `< 21` | 20.0.0 |
| cucumber-cucumber-expressions | `> 17`, `< 21` | 20.1.0 |
| cucumber-html-formatter | `> 21`, `< 25` | 24.2.0 |
| cucumber-query | `~> 16.1` | 16.1.1 |
| diff-lcs | `>= 1.5`, `< 3.0` | 1.6.2 |
| logger | `~> 1.6` | 1.7.0 |
| mini_mime | `~> 1.1` | 1.1.5 |
| multi_test | `> 1`, `< 4` | 1.1.0 |
| sys-uname | `~> 1.5` | 1.5.1 |

The [core 20.0.0 gemspec](https://github.com/cucumber/cucumber-ruby-core/blob/v20.0.0/cucumber-core.gemspec)
requires Gherkin `> 36, < 43`, messages `> 31, < 35`, and tag-expressions
`> 6, < 12`. These resolve to 42.0.1, 34.2.1, and 8.1.0 respectively.
Installed [query 16.1.1](https://github.com/cucumber/query/blob/v16.1.1/ruby/cucumber-query.gemspec)
requires messages `>= 34.1, < 36` and Ruby >= 3.3;
messages 34.2.1 satisfies both consumers. Query 16.0 is not a valid substitute
for Cucumber 12.0.1's `~> 16.1` requirement.

The SDK directly requires `base64`, `logger`, and `cgi`, so these are explicit
runtime dependencies (`~> 0.2`, `~> 1.6`, and `~> 0.4`). CGI resolves to 0.5.2;
two-component pessimistic constraints permit newer minor versions below the next
major. AWS and expressions already declare their directly used `bigdecimal`
(target lock: 4.1.3). `csv` and `mutex_m` are not used by the SDK and were not
added speculatively. Existing SDK AWS and MIME dependencies are unchanged.
[Ruby's 3.4 release notes](https://www.ruby-lang.org/en/news/2024/12/25/ruby-3-4-0-released/#standard-library-updates)
document the base64/bigdecimal extraction; explicit dependencies avoid relying
on a Ruby installation exposing bundled gems to Bundler implicitly.

The first conservative install retained expressions 18.0.1 from the old lock.
A focused `bundle update cucumber-cucumber-expressions` then resolved 20.1.0,
demonstrating that no legacy `< 19` constraint remains in the current manifests.
Historical labs and their locks deliberately retain their original environments.

## Adapter Gaps At The Legacy Baseline

These are migration findings against the immutable 1.3.1 source, not assertions
that another agent's in-progress implementation still has each defect. See
[the architecture contract](cucumber-12-architecture.md) for the selected design.

| Interface / legacy location | Verified Cucumber 12 contract | Required change / verification |
| --- | --- | --- |
| `formatter.rb#subscribe_to_events` tolerates nonexistent `test_suite_*` events | The actual event registry has case/step/run/envelope/attach events, not Feature-suite events; every event derives from `Core::Event::Base` | Build Feature/Rule hierarchy from AST/message metadata, not invented suite callbacks; retain real event objects in integration tests. |
| Legacy native media callbacks and `formatter.rb#handle_envelope` | Native `attach` emits `attach_called`; message-builder converts it to an attachment envelope. Native `log` uses the same attachment path | Consume native event/envelope records exactly once; retain binary encoding, filename, MIME type, and active Step/Hook ownership. Avoid callback interception and duplicate direct/envelope delivery. |
| `formatter.rb#handle_test_case_finished` and aggregate status | Core emits `testCaseFinished` envelope before the native case-finished event; only the message contains `will_be_retried` | Track per-attempt started IDs and effective final outcome. Preserve failed attempt items but do not poison a later passing retry. Verify `--retry-total` exhaustion. |
| Legacy status assumptions in formatter/result mocks | `strict` is removed; undefined/pending/ambiguous are non-passing without a strict flag | Use actual result statuses and native run success; preserve explicit skipped/interrupted distinctions and original exceptions. |
| `native_lifecycle.rb` private registry/AfterAll wrapper | Cucumber 12 emits `test_run_hook_started` / `test_run_hook_finished`; each hook-finished carries `test_result` | Prefer actual run-hook lifecycle; ensure teardown failure affects final reporting and original business exceptions are not hidden. |
| `AstMetadata`, `StepDesc`, and parameter/group mocks | Core 20 / Gherkin 42 / messages 34, expressions 20, query 16.1 | Verify Background, Rule, expanded Outline rows, DocString/DataTable, and native HTML/messages against real objects rather than legacy fake shapes. `AstLookup` still exists in 12.0.1; its removal must not be guessed. |
| No genuine `ParallelFormatter` in baseline | Native `parallel_tests` starts independent Ruby processes | Add explicit worker behavior with an externally owned launch; verify each worker's unique item IDs, queues, and no worker launch start/finish. |
| Current consumer Gemfiles/helper/runtime | 1.3.1, Ruby >= 3.1, Cucumber 9/10, and an expressions cap were hard-coded | Move current consumer to 2.0.0 / Ruby >= 3.3 / Cucumber >= 12.0.1, < 13, without relabeling archived evidence or inventing a published 2.0.0 URL. |

Primary implementation evidence:
[12.0.1 changelog](https://github.com/cucumber/cucumber-ruby/blob/v12.0.1/CHANGELOG.md),
[event registry](https://github.com/cucumber/cucumber-ruby/blob/v12.0.1/lib/cucumber/events.rb),
[native media event](https://github.com/cucumber/cucumber-ruby/blob/v12.0.1/lib/cucumber/runtime/user_interface.rb),
[message builder](https://github.com/cucumber/cucumber-ruby/blob/v12.0.1/lib/cucumber/formatter/message_builder.rb),
[core runner ordering/retries](https://github.com/cucumber/cucumber-ruby-core/blob/v20.0.0/lib/cucumber/core/test/runner.rb).

## Executed Checks

- Target `bundle install` completed, followed by the focused expressions update;
  `require "reportportal_cucumber"` printed 2.0.0 successfully. A final
  `RUBYOPT=-W:deprecated bundle install --local` completed with 55 gems and no
  warnings. `ruby -W:deprecated -Ilib -e 'require "reportportal_cucumber";
  require "cucumber/cli/main"'` also completed without warnings.
- Both `gem build` commands succeeded, outputting external scratch archives
  `/tmp/reportportal-cucumber-ruby-2.0.0-candidate.gem` and
  `/tmp/reportportal-cucumber-ruby-1.3.1-legacy.gem`. RubyGems emitted pre-existing
  open-ended dependency and duplicate homepage/source metadata advisories;
  the immutable legacy gemspec was not altered to suppress them.
- Legacy frozen-lock installation completed into
  `/tmp/reportportal-cucumber12-legacy-bundle-ruby342`. The separately built
  1.3.1 gem installed with Cucumber 10.2.0 / expressions 18.1.0 in
  `/tmp/reportportal-cucumber12-legacy-installed-gems`. From `/private/tmp`, all
  33 loaded SDK files were checked to be inside that installation, not either
  checkout. The frozen development lock uses expressions 18.0.1; the fresh
  consumer legitimately resolves 18.1.0 under the legacy `< 19` constraint.
- Target 2.0.0 independently installed with Cucumber 12.0.1 / expressions 20.1.0
  in `/tmp/reportportal-cucumber12-target-installed-gems`. Its 33 loaded SDK
  files likewise all came from the installation, not a checkout. Fresh consumer
  resolution additionally selected multi_test 2.0.0, diff-lcs 2.0.0, CI-environment
  13.0.0, and tag-expressions 11.0.1; these are allowed by upstream constraints,
  while the development lock conservatively retains the table's older versions.
- Package metadata checks accepted Ruby 3.3 and Cucumber 12.0.1, rejected Ruby
  3.1/3.2 and Cucumber 9.2.1/10.2.0/11.1.1/12.0.0/13.0.0, and confirmed no direct
  expressions cap. This tests declared requirements, not execution on those
  uninstalled Ruby versions. An actual external consumer `bundle lock --local`
  with `CUCUMBER_VERSION='= 10.2.0'` also rejected the incompatible constraints
  (expected exit 7).
- Unchanged legacy final baseline: `bundle exec cucumber` passed 1 Scenario /
  3 Steps; full `RUBYOPT=-rbundler/setup bundle exec rspec -Ilib -Ispec spec`
  passed **889 examples, 0 failures** in 2 minutes 35 seconds. Both used the
  frozen legacy bundle and `HELM_BIN=/private/tmp/reportportal-2607-mYdyRWqN/darwin-arm64/helm`
  (verified `v3.18.4+gd80839c`). An initial run's 17 missing-Helm-fixture failures
  were superseded by this complete clean rerun, not skipped or accepted.
- The only legacy test preparation was copying the existing official
  `reportportal-26.10.26.tgz` archive into its ignored
  `helm/reportportal-rich-experience/charts/` directory. The source and copied
  archives both verified SHA-256
  `399d95da23dcc6775acb5010f3f93b42f602ee75cecf7cce012a5d45fa9e0867`.
  This is the upstream chart version, not a change to ReportPortal appVersion
  26.0.7 or the SDK version. No legacy source, lockfiles, or deployment versions
  were edited; `git status --short` remained empty. No deployment/migration ran.
  Final logs: `/tmp/reportportal-cucumber12-legacy-rspec-with-helm.log` and
  `/tmp/reportportal-cucumber12-legacy-cucumber-with-helm.log`.
- The current consumer was copied outside the source checkout and used the
  installed 2.0.0 archive with RP disabled. `bin/setup` succeeded, `bin/run api`
  passed 4 Scenarios / 17 Steps, `bin/check_fixture` passed its real loopback HTTP
  cases, `bin/check_config` passed all 10 endpoint-policy checks, and `bin/runtime`
  verified the isolated installation. Its root check now canonicalizes symlinks
  so `/tmp` and `/private/tmp` are not falsely treated as different installations.
- `bin/verify` passed with Playwright Ruby 1.62.0 / CLI 1.62.1 and real Chromium
  from the existing browser cache: 5 passing Scenarios with 46 attachments; the
  intentional negative case retained its original error, exit 1, and one valid
  After-hook PNG among 6 attachments; the 5-Scenario no-color rerun passed with no
  ANSI escapes. Native HTML/messages matched. This was not real RP ingestion or
  a fresh browser download. Reports:
  `/private/tmp/reportportal-cucumber12-current-sdk-consumer/artifacts/acceptance/20261031T020743Z-e4d7d4`.
  `Gemfile.source` also resolved and produced a matching source-runtime manifest;
  that separate debug check is not installed-package evidence.
- All 19 current consumer/version/gemspec Ruby files passed syntax compilation;
  scoped `git diff --check` passed. Historical example verification and locks were
  left unchanged. Target full RSpec/Cucumber integration acceptance is owned by QA;
  example/API-only results do not substitute for those gates. Scratch 2.0.0
  archives are working-tree snapshots and must be rebuilt after all agents finish.
- Ruby 3.3 / other Ruby-version matrices are configured or planned elsewhere,
  not executed evidence from this host. No gem or release has been published.
