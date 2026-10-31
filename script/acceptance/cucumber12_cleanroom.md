# Independent Clean-Room Consumer Checks

The accepted baseline is the immutable run
`20261031T030934Z-17bff3` at revision
`e7dae2b2bc7559339a796d657a4e1219e7f6b0aa`. Its files, report, verifier outputs,
and `latest.json` pointer are not rewritten by the updated harness.

Current workflow: wait for the parent to provide the corrected archive path and
SHA-256; do not rerun the old package now. This is a workflow instruction, not a
hash blacklist: the general harness also permits explicitly pinned baseline
reproduction later, always in a NEW run directory. From the repository root on
`codex/cucumber-12`:

```sh
export CLEANROOM_CANDIDATE_ARCHIVE="/absolute/path/from-parent.gem"
export CLEANROOM_CANDIDATE_SHA256="<64-lowercase-hex-from-parent>"
ruby script/acceptance/cucumber12_cleanroom.rb --preflight
ruby script/acceptance/cucumber12_cleanroom.rb
ruby script/acceptance/cucumber12_cleanroom_verify.rb
```

Both environment settings are mandatory. There is NO archive default or hash
auto-detection. Any explicitly supplied hash, including the accepted baseline
hash, must exactly match the supplied archive. Runs are labeled `baseline` when
that hash matches the accepted archive, and `candidate` otherwise. A different
hash is not itself proof of corrected behavior.
Preflight checks the archive identity, exact hash and unchanged runtime/Ruby
contract without creating evidence, contacting Docker or installing anything.
The source archive may have any filename, but must identify the Ruby-platform
`reportportal-cucumber-ruby` gem version 2.0.0. The canonical staged name is always
`reportportal-cucumber-ruby-2.0.0.gem`, and its bytes are checked again after copy
and inside the container before installation/indexing. Original archive hashes
are rechecked at the end of a run. Legacy 1.3.1's path and SHA-256 remain fixed,
with no environment override.

`CLEANROOM_EXPECTED_SOURCE_HEAD` optionally pins a 40-character Git revision.
Otherwise the actual revision and dirty status are recorded, not presumed to
identify an uncommitted post-fix archive; the archive SHA is its identity.

Host-only configuration and security checks (synthetic metadata fixtures, no
containers, gem installation or TC17/18 rerun):

```sh
ruby script/acceptance/cucumber12_cleanroom_config_spec.rb
```

Prerequisites: Docker, host Ruby with its standard libraries, and local official
`ruby:3.1-slim`, `ruby:3.3-slim`, and `ruby:3.4-slim` images. Missing images can be
downloaded explicitly with `docker pull`. The runner records their full immutable
image IDs, registry digests, architecture, and actual interpreter versions. It
executes by image ID so a tag change cannot alter a later case.

## Cases

| Check | Ruby | Consumer inputs | Expected SDK |
| --- | --- | --- | --- |
| TC17 | 3.3 | Candidate gem and exact Cucumber 12.0.1 | 2.0.0 |
| TC17 | 3.4 | Candidate gem and exact Cucumber 12.0.1 | 2.0.0 |
| TC18 | 3.1 | Two-gem Gemfile, Cucumber 9.2.1 | 1.3.1 |
| TC18 | 3.3 | Two-gem Gemfile, Cucumber 12.0.1 | 2.0.0 |

TC17 downloads Cucumber and its runtime dependencies, then installs only the
supplied candidate and its runtime dependencies. It does not install development
dependencies or manually bootstrap base64, logger, or mutex_m.

TC18 uses Bundler 2.6.9 and an unpinned SDK in a scoped private source. Each case
starts without a lockfile, installed bundle, gem cache, path dependency, or Git
dependency, and runs `bundle _2.6.9_ update`. Only these two gems are declared:

```ruby
source "https://rubygems.org"
source "http://candidate-index:8808" do
  gem "reportportal-cucumber-ruby"
end
gem "cucumber", "=12.0.1" # =9.2.1 in the Ruby 3.1 case
```

The private index contains BOTH the explicitly selected SDK 2.0.0 archive and the
unchanged legacy 1.3.1 package, with real gemspecs and exact verified gem bytes.
Consumers obtain the SDK through the actual
Bundler resolver and HTTP gem download, not a `path`, `git`, `--local`, or
preinstalled-SDK workaround. Public runtime dependencies are allowed.

**This is real resolver selection against a private candidate index, NOT SDK
publication to RubyGems or proof of public-registry SDK selection.**

## Isolation And Evidence

Each consumer has a new container and writable layer, empty private gem home,
cleared inherited environment, and only two host mounts: a minimal read-only
input directory and its writable evidence directory. There are no gem volumes,
repository mounts, copied project Gemfiles, shared bundles, or shared gem caches.
Native-extension build tools are installed as OS packages inside each consumer;
they do not add Ruby gems. Ruby's genuine default gems are retained and audited.

Both passing and intentionally failing real Cucumber CLI cases run with the
installed SDK formatter in every runtime. Checks cover native logs, text
attachment bytes, hooks, World methods, and native success/failure exit codes.
The installed spool executable is also invoked with `--help`.

Installed and actual-CLI audits record gemspecs, runtime dependency satisfaction,
activated and installed private gems, complete load paths, SDK-loaded files,
standard-gem provenance, exact installed SDK archive hash, and byte hashes of
every packaged/installed SDK file. No pre-require of base64, logger, or mutex_m
masks an SDK load failure. The mutex_m audit distinguishes absent/unused from
activated; this harness does not promise that arbitrary consumer code can
require an unused undeclared gem.

Required installed entrypoints are checked explicitly: the main SDK require,
version, formatter, World module and spool executable, plus the separate parallel
formatter file in SDK 2.0.0 (not imposed on legacy 1.3.1). Each
must be declared in the supplied archive, exist within the installed gem, and
match its packaged bytes. The complete archive file set, count and per-file
hashes remain derived dynamically; no fixed 202/197-file count is imposed.

Evidence is kept under
`tmp/cucumber12-independent/cleanroom/<NEW-UTC-run-id>/`. Only
`latest-postfix.json` is updated for candidate runs; explicitly requested baseline
reproductions use `latest-baseline-reproduction.json`. The old `latest.json` and
all accepted baseline evidence stay intact. Verification selects the pointer
matching the supplied hash label, or accepts an explicit new-run summary path.
Inner and outer `commands.jsonl` files preserve exact commands, exit codes, and
timing. Individual stdout/stderr, minimal owned-container inspections, fresh
gem-home inventories, Gemfiles/locks, native messages, and private-index download
logs are retained before removal. Supplied package hashes are verified before
and after execution.

Docker evidence is limited to owned container identity, image ID, state and the
two required mounts; image ID/digests/architecture/size; and protected RP/kind
container identity/image/state. Full Docker configuration, image environment,
global container details, and `/proc` mount inventories are not copied into new
evidence. Existing baseline evidence is left as recorded.

The separate verifier checks all twelve installed/actual-CLI audits, all command
exits, fresh baselines, original private-index gem download hashes, and cleanup.
It uses the SAME explicit archive/hash environment settings as the runner,
derives payload counts from that archive and checks actual Ruby patches against
each fresh baseline (Ruby 3.1/3.3/3.4 series; Linux arm64 or amd64). It writes
`verification.json` and `report.md` once, refusing to overwrite either. Use
`--check-only [new-run/summary.json]` for read-only rechecks of a new-schema run.
Writes to old-schema accepted evidence are refused. A fresh reproduction of the
baseline archive uses the new schema without rewriting the historical evidence.
No new-schema TC17/18 results are claimed until the explicitly selected archive
has actually completed all four fresh consumer runs.

The four consumers run sequentially with CPU, memory, process, log-size, and
command-time limits. Each is removed immediately after its evidence is captured;
the private index and its dedicated Docker network are removed at the end.
Cleanup addresses only uniquely named resources owned by this run, never other
containers, networks, images, volumes, ReportPortal, or kind. There is no global
prune. The small downloaded official base image may remain in Docker's image
store for normal reuse; no installed gem layer is retained.

The private HTTP fixture publishes no host ports, serves only real paths within
its registry directory, rejects traversal/NUL/symlink escapes, limits headers,
uses four workers and enforces a request timeout. Containers cannot acquire new
privileges and do not receive the Docker socket or host credentials. This is an
isolated fixture, not a general-purpose or adversarially hardened gem service.

## Limits

- This certifies the exact supplied gem hashes on the recorded Linux runtime
  patches and architecture, not all operating systems or Ruby patches.
- Public dependencies are resolved live and may change; evidence pins what was
  actually installed, rather than reusing the repository lock/cache.
- `RP_ENABLED=false` prevents any ReportPortal/kind modifications. Live backend,
  storage, browser, and reporting-delivery certification are outside this check.
- TC18 checks automatic selection from fresh Gemfiles with `bundle update`, not
  an in-place migration of an existing application's lockfile.
- Base64/logger are exercised on actual SDK paths. Mutex_m is not artificially
  required or installed when the selected SDK/Cucumber runtime does not use it.
- No commit, push, tag, or publication is performed.
- These tests do not validate the separate combined-Outline source fallback or
  NUL text-preview persistence defects. Their fix certification belongs to the
  dedicated A/C checks; TC17/18 remain clean-room consumer/resolver checks.
