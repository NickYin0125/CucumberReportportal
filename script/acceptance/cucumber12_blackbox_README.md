# Independent Cucumber 12 Audit

This explicit installed-package audit is not part of default RSpec discovery.
It does not edit SDK implementation, existing tests, credentials, or release state.
`spec/acceptance/cucumber12_independent_spec.rb` contains portable harness guards only.

## Corrected Retest

The independently installed corrected archive SHA256 is
`c6bf0aae1fa9bd1e356fa116934cebebd582353afd381ec4b16bf9fc67ca62f3`.
Its local source is
`pkg/cucumber12-independent-corrected-20261031-0BKVAS/reportportal-cucumber-ruby-2.0.0.gem`;
select it explicitly using `C12_PACKAGE` and `C12_PACKAGE_SHA256`. The default
archive/hash below deliberately remain the preserved failing baseline.

The corrected run passed 15 explicit RSpec checks across 48 real Cucumber CLI
runs and 625 HTTP requests, with 1,474 passed assertions and no failing
assertions. All 203 installed files, including 37 library files, matched the
manifest. Full frozen-worktree RSpec passed 958 examples with zero failures or
pending cases; offline Cucumber passed 7 scenarios and 21 steps. The 37 SDK
library hashes were unchanged after verification. No SDK implementation was
edited by reviewer A.

The per-case classification remains 10 `PASS`, 3 `APPLICABILITY` (TC01/03/08),
and 1 `UNSUPPORTED` upstream invocation (TC04). TC04's plain and Outline
reporting-display checks now pass; this does not add two-multiline-argument
invocation support to Core 20. TC09's five NUL preview forms are escaped while
their original raw attachment bytes/hashes remain unchanged. All three hard
gates pass: 34 owned launches and 212 items closed, no unhandled thread
exceptions across all 48 runs, and ten distinct PNG hashes with exact UUID
ownership.

Evidence is in `tmp/cucumber12-independent/runtime/corrected-c6bf0aae/`,
including `reviewer-a-corrected-handoff.json`, `report.json`, `cross-checks.json`,
`blackbox.json`, `full-rspec.json`, and `offline-cucumber.txt`. The baseline
cohort and failed assertions remain separate and unchanged. Real ReportPortal
read-back belongs to reviewer C, who subsequently confirmed both corrected
Outline orders, all 18 media records persisted/downloaded, ten distinct 640x360
PNG test cards, and the original JPEG After artifact with correct MIME/name and
hook ownership. C's final evidence is
`tmp/cucumber12-independent/live/corrected-c6bf0aae-20261031T033152Z/final-review.json`;
this is attributed live confirmation, not a repeated live audit by A. The
remaining TC15-18 checks belong to their assigned reviewers. This result is not release
authorization, complete literal acceptance, or a 100% reliability claim.

## Inputs

- `C12_RUBY`: consumer Ruby executable; defaults to `RbConfig.ruby`.
- `C12_DEPENDENCIES`: gem search path containing the locked dependencies; defaults to current `Gem.path`, joined with the platform path separator.
- `C12_PACKAGE`: candidate archive; defaults to `pkg/reportportal-cucumber-ruby-2.0.0.gem` under this checkout.
- `C12_PACKAGE_SHA256`: expected archive hash; defaults to the requested `68b1ab8889f1e3448f6809b498c0aa7ff9ef9a03f4f1f5ae6d4e01fe2f6d17b3` baseline.
- `C12_EVIDENCE_ROOT`: generated output root; defaults to `tmp/cucumber12-independent/runtime`.

The measured baseline pins actual Ruby 3.4.2, Cucumber 12.0.1, Core 20.0.0,
Gherkin 42.0.1, and Messages 34.2.1. A configurable executable path is not a claim
that alternative runtime versions were tested. No personal Ruby/cache paths are
required by committed code. Exact machine-specific invocations are in evidence.

With the repository's locked development dependencies available:

```sh
bundle exec rspec spec/acceptance/cucumber12_independent_spec.rb
bundle exec rspec script/acceptance/cucumber12_blackbox_spec.rb --format documentation
```

`ruby script/acceptance/cucumber12_blackbox.rb` is also an explicit matrix entry
point when the configured dependency gem path is available without Bundler.
The consumer clears both `BUNDLE_` and `BUNDLER_` settings plus `RUBYOPT`/`RUBYLIB`.
It activates the isolated installed gem and checks every loaded SDK file path.
The archive and consumer installation are retained under their SHA256, so a new
candidate cannot overwrite the baseline's installed code or package bytes.
Formatter-disabled controls must activate/load no SDK at all. Provenance failures
remain failures; no fallback to source loading is accepted.

## Interpretation

TC01 and TC03 are top-level `APPLICABILITY`, with supported contracts checked
separately. Directories are not suites, arbitrary tags are not automatically RP
attributes, and scoped allowlisted attributes require explicit opt-in.

TC04 separates three observations: Gherkin 42.0.1 accepts both argument orders;
Core 20.0.0 supplies only one multiline argument; and compatible one-argument
steps permit independent testing of both arguments' reporting. Plain combined
display works. The requested baseline has a reproducible combined Outline gap:
a table-only placeholder is expanded in native pickles but remains literal in
the RP Step description and rich log. That baseline regression remains
reproducibly red; it passes against the explicitly selected corrected archive.
No Core monkeypatch
or formatter callback injection is used.

TC08 records native `log` delivery and timestamps but classifies actual Ruby
`puts` as stdout-only. TC09 checks File objects independently of StringIO/pipe;
valid MIME Strings and `;base64` are not conflated with an extra invalid
JavaScript-style options Hash. That Hash is observed, not treated as a supported
Ruby attachment signature or an upstream failure when no failure occurred.
The baseline also has a TC09 text-preview NUL defect independently observed on
real RP: HTTP 201 acknowledgements do not imply persisted logs/files when the
preview message carries PostgreSQL-incompatible NUL. The wire regression rejects
that preview while still requiring the original attachment bytes, including NUL,
unchanged. Live persistence/download evidence remains owned by reviewer C.

Each run preserves feature source, actual child command, native messages,
emission records, stdout/stderr, loaded-code provenance, and HTTP request bodies.
Each new run also copies and hashes its own fixture support file; the child
requires that snapshot, not the mutable shared fixture. Earlier cohorts remain
untouched and are distinguished from the final snapshot-based cohort.
Multipart bytes are retained as base64 with decoded SHA256 assertions. Reports
and replay manifests have distinct cohorts so exploratory failures are retained.
The hard gates concern every emitted owned launch/item, unhandled thread
exceptions, and ten distinct PNG hashes with exact Step/Scenario UUID ownership.
This is not a claim of complete literal acceptance or 100% reliability.

Live replay is owned separately. Optional `INDEPENDENT_PNG_DIR` supplies exact
named PNG files, and `INDEPENDENT_AFTER_SCREENSHOT_PATH` supplies an actual
browser screenshot for the failed After hook. `INDEPENDENT_AFTER_SCREENSHOT_MIME`
and `INDEPENDENT_AFTER_SCREENSHOT_NAME` select its actual MIME and filename
(only when the path override is set; defaults remain `image/png` and
`after-failure.png`). A browser capture that
contains JPEG bytes must use `image/jpeg` and, for example, `after-failure.jpg`.
The earlier live JPEG incorrectly labeled PNG is a preserved fixture mismatch,
not a verified real-PNG capture and not an SDK defect. Both overrides use native
`attach` and record actual bytes/hashes. The fixture rejects an obvious PNG/JPEG
header mismatch before emitting it. Absent overrides, PNG fixtures are synthetic,
not represented as browser screen captures. Live credentials must never be
copied into this audit's evidence.
