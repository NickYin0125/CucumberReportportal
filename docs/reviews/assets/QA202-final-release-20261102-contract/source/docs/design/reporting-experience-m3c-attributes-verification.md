# M3C Scenario Attributes Verification

Status: **LOCAL M3C GATES PASS; PHYSICAL REPORTPORTAL ACCEPTANCE PASS (2026-10-08)**.
Master approved the frozen A/B source after review. The Cucumber 11.0.0
direct-RSpec run below is exploratory only and excluded from acceptance.

## Dated Live Closeout (2026-10-08)

Master's later physical UI acceptance is **PASS** for final ReportPortal launch
35. The UI showed two peer Suites and 5 Scenarios (4 passed, 1 deliberate
failure), verified Scenario-only attributes and native filtering, and checked
Rule/Scenario/Examples precedence in rendered Item details. This does not
replace or rewrite the historical local gates below. The full live API/UI
record, click destinations, screenshot/DOM matrix, fixture preconditions, and
reference-server lifecycle are in the [M3C-C live verification record](reporting-experience-m3c-live-verification.md).

## Acceptance Matrix

The supported acceptance commands use `bundle exec` with Cucumber 10.2.0 or
the separate Cucumber 9.2.1 manifest. The direct-RSpec command below is retained
only to document the exploratory, unsupported Cucumber 11 run; it is not a
recommended command for acceptance.

Focused command:

```text
PATH=/opt/homebrew/opt/ruby/bin:$PATH ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(ARGV)' spec/reportportal_cucumber/cucumber/m3c_attributes_integration_spec.rb
```

Exploratory result: **3 examples, 0 failures** using installed Cucumber
**11.0.0** outside the declared support bundle. Nine
child runs passed: legacy and stable-v1 each ran disabled, enabled, and
attribute-mutated fixtures at the same two feature URIs and source-line layout,
followed by environment-ID precedence, custom allowlist, and empty-allowlist
cases. Each matrix run captured two Suites, six statistical Scenario starts
(including both retry attempts), and `5 scenarios (1 flaky, 4 passed)`.
Assertions cover literal attributes, identity/name/parameters/retry invariance,
attempt-owned logs and unique UUIDs, and Scenario-to-Suite/action-to-Scenario
parent UUIDs.

The direct AST example pins both outline rows to the actual `Checkout API` Rule
and their respective Examples tags; retry is under the separate `Retry
behavior` Rule. Three permutations of three conflicting configured defaults
all ignore the conflicting key. Every child scrubs inherited `RP_*` variables
and uses WebMock with external networking disabled. Cucumber's error buffer,
actual host stdout/stderr, and formatter output are privacy-scanned before the
safe evidence is saved. Captured host stderr contains safe diagnostics and is
preserved in the capture JSON.

Request captures and process/formatter evidence are under
`tmp/m3c-attributes-20261007/`. Disabled attributes are asserted as the API
builder's normalized empty `attributes` array. Child captures record and assert
the loaded Cucumber version and `BUNDLE_GEMFILE` for each lane.

The final clean candidate must start from the frozen M3B baseline at
`/tmp/m3b-20261007-clean-final`, exclude generated output and unrelated dirty
duration/manifests, and overlay only reviewed M3C paths plus the README addition.
Record source/test hashes, base and overlay paths, and file counts. All gates
below ran from the clean candidate, not the dirty workspace, using `bundle exec`
and its locked Cucumber 10.2.0. The Cucumber 9.2.1 run used a new M3C-specific
manifest pointing at this candidate; the prior M3B manifest was not used.

## Final Local Results

Clean candidate: `/tmp/m3c-attributes-20261007-clean`, based on
`/tmp/m3b-20261007-clean-final`. The frozen base snapshot contributed 142 files
after excluding its two spool artifacts and M3A API capture. Fifteen approved
overlay paths comprise four existing-path updates and eleven new files, for 153
source files before test-generated outputs. Only README, Config/AST/formatter/
resolver, M3C specs/fixtures, and the two M3C design records were overlaid.
Unrelated root manifests, duration work, and generated package files were not
copied. `candidate-paths.txt` records the source snapshot;
`candidate-overlay-sha256.txt` binds the overlay paths to hashes.

| Gate | Result | Evidence under `tmp/m3c-attributes-20261007/` |
| --- | --- | --- |
| Locked Cucumber 10.2.0 M3C integration | **PASS**, 3 examples / 0 failures, exit 0 | `verified-cucumber-10.2.0/` contains stdout/stderr and nine JSON captures with version and candidate Gemfile. |
| Isolated Cucumber 9.2.1 M3C integration | **PASS**, 3 examples / 0 failures, exit 0 | `verified-cucumber-9.2.1/` contains stdout/stderr, manifest/lock, and nine captures with version and M3C-only Gemfile. |
| Full RSpec | **PASS**, 225 examples / 0 failures, exit 0 | `full-rspec.stdout` / `.stderr`; existing reporting-failure warnings retained. |
| Ordinary Cucumber | **PASS**, 1 scenario / 3 steps, exit 0 | `ordinary-cucumber.stdout` / `.stderr`. |
| M3A integration | **PASS**, 2 examples / 0 failures, exit 0; asserts 8 scenarios / 40 steps | `m3a-integration.stdout` / `.stderr`. |
| M3B integration | **PASS**, 2 examples / 0 failures, exit 0 | `m3b-integration.stdout` / `.stderr`. |
| Gem build / isolated install / Config+resolver smoke | **PASS**, exit 0 for each | `gem-build.*`, `gem-install.*`, `gem-smoke.*`, and `gem-proof.*`; built version 1.1.0. |

The Cucumber 9.2.1 development bundle installed 40 locked gems only under
`tmp/m3c-attributes-20261007/bundle`; no root dependency files changed. Gem
build emitted existing open-ended gemspec warnings. The installed gem path and
Config/ScenarioAttributes/ScenarioIdentity source locations are recorded in
`gem-proof.stdout`; all resolve inside that isolated activation directory, and
`RUBYLIB` was unset. The installed ScenarioIdentity source hash matches the
frozen value. Validated Cucumber 10.2.0 and 9.2.1 captures are in separate
directories; exploratory 11.0.0 captures are isolated under
`exploratory-cucumber-11.0.0/`. `gate-status.md` records actual exit codes and
stdout/stderr paths. No physical ReportPortal, browser, or infrastructure gate
was run.

## Protected Baselines And Scope

Master supplied these protected SHA-256 baselines; verify they remain unchanged:

| Path | SHA-256 |
| --- | --- |
| `Gemfile.lock` | `e1137102577f032e2fd15ad1065e91846fc5e2cccf069af89f1d0453783845ed` |
| `Rakefile` | `c5583ea794d2945c0a3d03d6ba54b69f8ef9f5369e5bef8e90b32f5e73dcbe62` |
| `cucumber.yml` | `567a4fdb9f10913140e25aaaef588d07d1fa3ef4e5c698a63568058dfd6d7355` |
| `reportportal-cucumber-ruby.gemspec` | `aaed20ea97c82d7b7c14d4fc59414c9bb163da6006fdf92700f98321354b397e` |
| `lib/reportportal_cucumber/service/scenario_identity.rb` | `ce6b6737726a8783291f957f8265d4bbb5199d779a24a0003c6e230b398e78ae` |
| `spec/reportportal_cucumber/cucumber/m3b_integration_spec.rb` | `30a10d200b28375e2a719590a4b0cb4aab5061b47f6276e6d1a4921e166010e7` |

Master's post-review frozen M3C source hashes:

| Path | SHA-256 |
| --- | --- |
| `lib/reportportal_cucumber/service/scenario_attributes.rb` | `3ac6c1485604b7e3f77cf1a5ce83565df247dfa9486b0dc3f231e51ebc145178` |
| `lib/reportportal_cucumber/config.rb` | `cdcadf55833545f5892d3fc5db46bedc5d5a164d52a484b9927a710708733e6e` |
| `lib/reportportal_cucumber/cucumber/ast_metadata.rb` | `d94d5aa8a72925bc175d6651d61bbd9226660e90434e1b7a0df04b8ed42ee71b` |
| `lib/reportportal_cucumber/cucumber/formatter.rb` | `9170a98b88e66e1ef3f58cc0a6bfaada362e0dbccfe3ed76cc05ae87cbb908d1` |

At the time this local slice was frozen, no commit, tag, push, infrastructure
change, live ReportPortal run, browser acceptance, or new dependency was part of
its local gates. The later physical acceptance is recorded separately in the
dated live closeout above; it must not be conflated with these local mock
results.

This fixture resolves available AST source directly. It does not claim a new
fallback for native AST lookup exceptions; B's final reviewed source preserves
the original `document_for` behavior, and missing scope metadata resolves only
defaults plus the already-selected explicit ID without inferring flat-tag scope.

## Master Closeout

Final review on 2026-10-07: **PASS for the local attributes-mapping slice**.
Master independently checked all 76 `lib/` and `spec/` files against the tested
candidate, confirmed nine successful captures with the correct child version
in each supported Cucumber lane, and checked the installed-gem source-location
proof. The six protected baseline hashes remain unchanged. No blocking findings
remain within this slice.

The usage example and documentation were corrected after testing to export
configuration variables and clarify that existing `@tms:` identity selection
remains authoritative. These are documentation-only changes; no source or test
file changed after the final gates. The later live links and ReportPortal UI
filtering acceptance is documented in the dated closeout and live verification
record; the historical local-gate results above remain unchanged.
