# Production Candidate Packaging Acceptance

Date: 2026-10-11. Scope: consumer packaging/DX patch on
`codex/reporting-experience-m4`. This is not a release, GA approval, tag, registry
publication, deployment, or certification of the optional external-video path.

## Identity And Installed Documentation

The gem candidate is `1.2.0.pre.1`; the chart candidate is `1.2.0-rc.1` with
`appVersion: "1.2.0.pre.1"`. Neither reuses the earlier `1.1.0` artifact identity.
Record SHA-256 checksums of locally built artifacts, the source HEAD, and the
dirty candidate file manifest together: HEAD alone does not identify an
uncommitted candidate. Repository metadata uses the configured GitHub origin;
the `main/README.md` metadata destination is historical repository documentation,
not a claim that unpushed candidate changes are available there. No author email
is asserted.

The consumer gem includes `lib`, `exe`, examples, LICENSE, README, all top-level
`docs/design/*.md` contracts/verification records, and the Helm operator README.
Root development scaffolding (`features`, `spec`, workflows, Gemfile, Rakefile)
is excluded. In particular, untracked duration/clearing-mock experiments cannot
enter the package via a root feature glob. The four existing development
dependencies (puma, rackup, rantly, sinatra) remain unchanged in the gemspec;
none is a runtime dependency or required by the isolated consumer.

Historical design/verification and Helm documents describe earlier milestones
and demo setup. The candidate README's CI/TLS restrictions take precedence over
their earlier production assumptions. D4/D10 anonymous bucket-policy defects
remain unresolved, and external playback must remain disabled pending a separate
effective-policy review. This patch changes only chart version/appVersion, never
templates, values, dependency pins, or live services.

## Reproducible Local Checks

Use Homebrew Ruby 3.4.2 in this environment (the declared range is Ruby >=3.1),
Bundler 2.6.6, and the copied locked Cucumber 10.2.0 dependency environment.
Cucumber 11 is outside the declared `>=9,<11` support range. Pinning only a parent
Ruby process is insufficient: native children must inherit Bundler isolation.
The packaging spec explicitly requires `BUNDLE_GEMFILE`, creates a private
consumer Gemfile, and launches installed native Cucumber through that bundle.

Create a private source staging directory, copying the current candidate source
and the protected root lockfile there. Do not update the shared root lockfile.
Resolve candidate version changes only in that private staging copy. Set an
absolute scratch path before every Bundler invocation:

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export BUNDLE_GEMFILE="/absolute/private/staging/Gemfile"
bundle _2.6.6_ lock --local
RUBYOPT=-rbundler/setup bundle _2.6.6_ exec rspec \
  /absolute/private/staging/spec/packaging/candidate_package_spec.rb --format documentation
```

The test exports only the locked runtime dependency closure from existing local
gem caches, builds the candidate in temporary storage, installs it in an isolated
gem home with `gem install --local`, and resolves the isolated consumer with
`bundle lock --local`. It neither downloads missing dependencies nor installs
gems in the system/production gem home. A missing cached dependency is an explicit
setup failure, not a runtime SDK failure. The test's private directory is removed
afterward. To retain the exact tested artifacts and generated checksum/load
manifest, set `RP_PACKAGING_EVIDENCE_DIR` to a private scratch output directory.
Set `RP_PACKAGING_SOURCE_HEAD` to the verified source HEAD for provenance; the
per-file checksums in that manifest identify uncommitted candidate content.

If Helm is installed, the same spec packages the chart from a private copy using
its existing vendored ReportPortal dependency and checks packaged versions,
dependencies and exact protected template/value hashes. It does not run
dependency update, install, upgrade, template hooks, Kubernetes commands, MinIO
policy commands, or contact a live ReportPortal service. A missing Helm executable
is a pending chart example, not a chart pass; use `HELM_BIN` for a non-Homebrew path.

## Patch Acceptance Matrix

| Gate | Concrete regression | Boundary |
| --- | --- | --- |
| Distinct candidate identity | Built gem version and prerelease flag; chart/appVersion | No registry release or GA claim |
| Useful installed README | Resolve every local Markdown link inside the installed gem, including design contracts; Helm operator README exists | Historical docs are not new live certification |
| Honest metadata | Verified origin, main README metadata, no invented email | Candidate provenance belongs in a local manifest |
| Protected development work | Four gemspec additions retained; actual package excludes all root features/specs and duration/mock paths | Experiments remain untouched in the workspace |
| Isolated dependencies | Offline normal install; only three SDK runtime dependencies; installed-path provenance; no source-path SDK loading | Bundler is a test tool, not an SDK dependency |
| Native portability | Isolated bundled Cucumber >=9,<11 executes a native logging scenario | Executed runtime version must be recorded; not the full Ruby/Cucumber matrix |
| Installed executable | Normal generated spool executable runs `--help` | No spool execution or live HTTP |
| Chart policy isolation | Source and packaged templates/values match exact baseline SHA-256; dependency pin unchanged | D4/D10 deliberately not fixed; no deployment |

## Runtime Support Boundary

Local `join` defaults to `false`: workers without `RP_LAUNCH_UUID` create and
finish independent launches. Legacy local join requires an explicit opt-in and
is not a production shared-completion barrier. For a CI-owned UUID, workers
neither start nor finish the shared launch; CI collects every worker's actual
business exit and final reporting receipt before finishing it.

Native Cucumber 9/10 runs `BeforeAll` before formatter construction. An abort
there creates no formatter-owned launch or fabricated class-hook item. A
per-registry observer finalizes reporting only after the real `AfterAll` hook;
hook errors produce credential-sanitized launch-level ERROR evidence without
replacing the original business/hook exception. Native run hooks are not fake
`BEFORE_CLASS`/`AFTER_CLASS` test-step items. Reporting completeness is distinct
from business/hook success. Sequential runtimes and duplicate formatter cases
now pass source-level native Cucumber 9.2.1 and 10.2.0 subprocess regressions, including
event-bus isolation, original hook-exception precedence and strict reporting
completeness faults. The observer depends on Cucumber 9/10's private DSL
registry/configuration association. These checks do not certify native
class-hook items, other Ruby versions, rebuilt installed-package execution or
live server teardown-status behavior; the fresh independent matrix remains
pending.

Requested reporting with a missing endpoint, project or API key creates no API,
Join, worker or network resources, but returns an incomplete receipt with one
metadata failure. Diagnostics expose missing option names without values.
`RP_REQUIRE_COMPLETE_REPORTING=true` defers its configuration error until
business execution and genuine `AfterAll` finish; original business/hook
failures take precedence. Best-effort mode does not change the business exit,
and explicit `RP_ENABLED=false` intentionally bypasses the reporting gate.

`rp_evidence` allows at most 16 artifacts per call; larger batches are rejected,
not truncated. Queue admissions share one monotonic configured exit-flush budget
per call and can be cancelled when the original target closes, without holding
the context lock across a queue wait. Finalization's shared budget includes lock
acquisition/capture closure. Rejections/timeouts remain incomplete-reporting
signals; a failed admission does not roll back earlier accepted entries or
establish server confirmation. Caller-owned capture itself is not forcibly
interrupted by this contract.

These are Master's clarified implementation boundaries, not additional live
certification by the packaging suite. Fresh independent review/test follows
Master integration; packaging checks do not replace those gates.

## Executed Packaging Result

The focused packaging suite passed all 8 examples on Homebrew Ruby 3.4.2,
Bundler 2.6.6 and installed Cucumber 10.2.0. The native installed-consumer case
passed 1 scenario/1 step. Both local gem and Helm packages built successfully;
source and packaged chart policy files retained their baseline hashes. All
README relative Markdown links existed in the isolated installed gem. This is
offline/local evidence only; no live reporting, playback or deployment was tested.

The first harness attempt failed before assertions because macOS temporary-path
aliases loaded Bundler twice; canonical scratch paths and cleared inherited
Bundler bookkeeping fixed setup. A subsequent assertion-only rerun exposed that
RubyGems represents an omitted email as nil; the test now correctly accepts that
absence. Neither attempt establishes a runtime SDK failure. The final passing
receipts and exact artifacts are retained in the private packaging scratch
directory reported to Master, not in the production installation.

The subsequent README/guide-only support-boundary update is not included in
those earlier retained artifacts. A frozen integrated rebuild will follow.
