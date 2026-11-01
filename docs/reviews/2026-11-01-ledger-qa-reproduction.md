# Ledger QA Evidence Reproduction

This is a packaging/reproduction guide, not a product verdict or authorization to
run live tests, change assertions, publish, or overwrite primary QA reports.
Keep all original Q, historical WP5 and current checks inline. The final report
writer uses `JSON.generate(data) + "\n"`; do not pretty-print it or introduce shards.

## Roots And Frozen Inputs

Both QA checkouts are required. The central WP5 control scripts live in QA2x,
including when they process legacy evidence. Historical paths below are recorded
data, not links to another user's workstation.

| Role | Recorded location | Required product commit |
| --- | --- | --- |
| QA2x | `/Users/nick/Documents/crr-qa-2.0.1` | QA history/selection, not a runtime head |
| QA1x | `/Users/nick/Documents/crr-qa-1.3.2` | QA history/selection, not a runtime head |
| Candidate 2x | `/Users/nick/Documents/crr-2.0.1` | `3f20313c20b25071fbc49b31e1c6bc772bd599e4` |
| Candidate 1x | `/Users/nick/Documents/crr-1.3.2` | `f41888a9fdd6896630765cbbf350353a7f803e59` |
| Baseline 2x | `/Users/nick/Documents/crr-qa-baseline-2.0.0` | `79e5e9cfde4be6d29ca2293e549460c6c71fe87a` |
| Baseline 1x | `/Users/nick/Documents/crr-qa-baseline-1.3.1` | `4ca2f770e0a84e83688f165ba04b4db8ef855cf9` |

Use the final packaged QA revisions supplied by Master, not the current product
HEAD as a substitute for a QA revision. Verify candidate/baseline commits with
`git rev-parse HEAD` in disposable checkouts. Recover older source references from
their own recorded SHAs, never by silently substituting the new candidate.

For relocated offline publication checks, set `QA_CURATE_ROOT_2_0_1` and
`QA_CURATE_ROOT_1_3_2`. The curator maps each recorded QA prefix to that checkout;
cross-QA browser references are routed into the owning checkout's selection.
The guide is bundled in QA2x; each manifest identifies its guide's QA version.
The older analysis/execution runners still contain canonical absolute roots.
Run those in a disposable Linux VM/container namespace with the above paths
mapped to your checkouts. Do not edit recorded paths, process arguments, stack
frames or product assertions to make them look like new observations.

## Offline Inspection And Recalculation

No Docker daemon, ReportPortal account, browser or credentials are needed to
inspect selected JSON/checks, verify fingerprints, or recompute timing summaries.
Do not run fresh suites or hash the entire selection during an active G11 run.

1. Obtain both final curated manifests and their selected files. Verify each
   selected entry's repository-relative path, byte count and SHA256. Reject
   symlink components, escapes and any selected blob at or above 104,857,600 bytes.
   52,428,800 bytes is only the GitHub warning threshold, not the hard limit.
2. For each `tracked_archive_coverage` dependency, obtain its already tracked
   manifest and archive. Verify both against the fingerprints recorded in the
   new manifest, then verify the archive's own entry index. Restore only in an
   empty disposable evidence checkout, after rejecting absolute/parent-traversal
   and symlink entries. The three historical archives use `tar -xJf ARCHIVE -C .`.
   They are existing historical evidence, not newly selected package binaries.
3. Use each criterion's `check_ids` to resolve unchanged objects in the inline
   `checks` array. Preserve failed/blocked original objects and the complete
   approved failure input; a green rerun never replaces them. Resolve source
   references through selected leaves, verified historical archives, or the
   manifest's explicit provenance-only explanations.
4. Timing recalculation reads the exact `performance_stamp` tree, normally
   `wp5-ci-final-20261101-quiet`. For each Cucumber cohort, take the median of the
   three `wall-*-MODE/F07/process.json` `seconds` samples for baseline/plain/rich.
   Group `presentation-timings.json` `samples` by entry across `micro-*` and
   `parallel-micro-*`; p95 is sorted index `ceil(n * 0.95) - 1`. Preserve all
   `replay_errors` and apply the unchanged scorer assertions. This recalculates
   recorded measurements; it does not execute or certify a new benchmark.
5. For a full offline comparator recalculation, restore the selected evidence
   and pinned source/docs in disposable canonical-path copies. From the central
   QA2x harness, `final_wp5_analyze.rb` reads captured snapshots and produces
   `live-checks.json` despite its historical filename; it does not create live
   Launches. `final_wp5_ui_score.rb` reads retained UI observations, and
   `final_wp5_score.rb` combines retained live/UI/matrix/probe/repository inputs.
   Run these only in the disposable copies and compare results to published
   objects. Do not run `final_wp5_report.rb`, `report.rb` or `publication.rb guide`
   against primary QA roots: they write reports or prior publication artifacts.

Generated native HTML template copies are intentionally omitted from new
selections. Their recorded paths are provenance-only, not promised download
links. Retain the sibling `native.ndjson`; if a comparator needs HTML, regenerate
it only in the disposable evidence copy with the exact locked
`cucumber-html-formatter` version:

```sh
bundle exec ruby -rjson -rcucumber/html_formatter -e '
  File.open(ARGV[1], "w") do |out|
    Cucumber::HTMLFormatter::Formatter.new(out).process_messages(
      File.readlines(ARGV[0]).map { |line| JSON.parse(line) })
  end
' native.ndjson native.html
```

Use any recorded model/template fingerprints to distinguish regenerated HTML
from original CLI output. Source-clone paths, old temporary package names,
container paths and cache locations are execution provenance, not downloadable
assets. Their adjacent selected provenance/package-verification JSON and Git
SHAs remain evidence; no claim is made that an omitted `.gem`, template or cache
is independently available. Exact referenced browser JPG/PNG originals and saved
PNG/JPG/TXT/JSON downloads are selected as real files, not replaced by filenames
or header observations. The only source-clone file exceptions are the tiny exact
per-cell `Gemfile`/`Gemfile.lock` dependency inputs; no SDK source tree is selected.

## Fresh Execution Bootstrap

Fresh execution is separate work requiring authorization, new output stamps and
new provenance. It is not necessary to inspect published evidence. Never reuse
an original output directory or change the protected product trees. All setup
below belongs in a disposable reproduction environment, not primary QA roots.

| Cells | Ruby recorded in completed matrix | Cucumber |
| --- | --- | --- |
| M1 / M2, legacy | 3.1.7p261, aarch64-linux | 9.2.1 / 10.2.0 |
| M3 / M4, legacy | 3.3.12, aarch64-linux | 9.2.1 / 10.2.0 |
| M5, 2x | 3.3.12, aarch64-linux | 12.0.1 |
| M6, 2x | 3.4.12, aarch64-linux | 12.0.1 |

The live/probe driver uses Ruby 3.4 for 2x and 3.3 for legacy. Use Bundler 2.6.6.
These are Linux ARM64 tools/images; do not execute their binaries directly on
macOS or substitute x86 native gems without recording a different environment.

The historical matrix's image files recorded these **local Docker image IDs**:

| Ruby | Local image ID |
| --- | --- |
| 3.1 | `sha256:7849744f16559a7fc88547a7f6f0b55ea853ee8130b002ff67f59c73c643656c` |
| 3.3 | `sha256:ce3b866e0d22c71ec576f9de6d6860be38a73b445df80ae1e0318f08a988848d` |
| 3.4 | `sha256:fc42b34e62e2bf3f65adddc30ef55260b208b1f2d1dfe4e95ee4662eb9b237d1` |

These are not pullable registry digests. An exact historical image requires an
available trusted image export/registry copy whose loaded `.Id` matches. Do not
run `docker pull sha256:LOCAL_ID` or claim a new build is byte-identical. If such
images are unavailable, build a new, explicitly labelled environment from
`spec/acceptance/ledger_qa/Dockerfile`, pin the base to the required Ruby patch
and a recorded registry digest, and record the new resolved image ID. The
Dockerfile installs gcc, make, libc6-dev, libffi-dev, git, curl, ca-certificates
and Bundler 2.6.6. Historical live commands used mutable `ruby:3.3-slim` and
`ruby:3.4-slim` tags; the historical matrix IDs do not prove those live base IDs.
Freeze/record a suitable image before a fresh run rather than inferring a digest.

In Linux ARM64, retrieve the following pinned tools. The executable fingerprints
come from the recorded tools manifest; verify extracted binaries, not tar bytes:

| Tool | Retrieval | Executable SHA256 |
| --- | --- | --- |
| Docker 27.5.1 | `https://download.docker.com/linux/static/stable/aarch64/docker-27.5.1.tgz`, member `docker/docker` | `3e2d3307e386e59268ab1b17c195f5f224b7c616f06c553d22c0d10f90e5e618` |
| Compose 2.39.4 | `https://github.com/docker/compose/releases/download/v2.39.4/docker-compose-linux-aarch64` | `49082844b87f03cdcd5f5bbef1ba8c9c897b7a2dfb80cea18d61ec8ca6117e0c` |
| Helm 3.18.4 | `https://get.helm.sh/helm-v3.18.4-linux-arm64.tar.gz`, member `linux-arm64/helm` | `a20bcb898184a3e824c92eafffcb04a3343066e33f25a7867ca2cd28420f562c` |

The recorded Helm tar SHA256 is
`c0a45e67eef0c7416a8a8c9e9d5d2d30d70e4f4d3f7bea5de28241fffa8f3b89`.
Place only the three verified executables under
`/private/tmp/ledger-pinned-tools/linux-arm64/` in the disposable host namespace;
the runner mounts them at `/tools`. No Docker configuration or credentials are
part of this bootstrap.

Reconstruct dependencies from each selected exact per-cell `source/Gemfile` and
`source/Gemfile.lock` (or an indexed historical `dependency-inputs/*.txt` pair),
in a disposable checkout of that cell's product SHA. Do not resolve floating
ranges as if they were the captured lock. The original legacy preparation added
`gem "cucumber", "= VERSION"` and removed the product lock only in scratch;
the resulting selected lock is the reproducibility input. The 2x product lock
already pins Cucumber 12.0.1. Install the exact Bundler and locked gems in the
matching Linux ARM64 Ruby image, with `BUNDLE_IGNORE_CONFIG=1`,
`BUNDLE_GEMFILE=/scratch/source/Gemfile`, `BUNDLE_PATH=/bundle`,
`BUNDLE_FROZEN=true`. Try `bundle _2.6.6_ install --local`; if packages are absent,
fetch the locked versions from their recorded public gem source before going
offline. Keep checksums/platforms from the captured lock and native extensions
for that Ruby ABI. Do not load the workstation's `.bundle` or Docker config.

Populate only disposable host seeds
`/private/tmp/ledger-matrix-bundles/ruby31`, `ruby33`, and `ruby34`, mounted at
`/bundle`. Install both legacy Cucumber locks into the relevant ABI seed without
discarding the other cohort. Keep `ruby/3.1.0`, `ruby/3.3.0`, and `ruby/3.4.0`
layout. A fresh package download/build may not reproduce the old cache's byte
fingerprint; record that honestly. The local-copy proof compares each new seed
to its container copy, not to an invented historical cache. Never publish the
whole bundle, source mirror or cache to satisfy reproduction.

Retrieve the canonical historical JPEG from a selected 2x F04 snapshot's
base64 attachment, without contacting ReportPortal:

```sh
ruby -rjson -rbase64 -rdigest -e '
  expected = "8c472e5064d09cd6d7f8aca0ce5da74e4ff29073ac5f8f45ae96093f46bed1a9"
  file = JSON.parse(File.read(ARGV[0])).fetch("files").find { |f| f["sha256"] == expected }
  abort "Canonical JPEG absent" unless file
  bytes = Base64.strict_decode64(file.fetch("base64"))
  abort "JPEG fingerprint differs" unless bytes.bytesize == 36612 && Digest::SHA256.hexdigest(bytes) == expected
  File.binwrite(ARGV[1], bytes)
' "$QA2/docs/reviews/assets/ledger-qa-live/wp5-ci-final-20261101-c12.0.1-plain-1/F04/snapshot.json" "$SCRATCH/jpeg.jpg"
```

Define `QA2` as the restored 2x evidence root and `SCRATCH` as a disposable
directory first. The JPEG is 36,612 bytes, 754 x 790; the developer harness also
enforces its SHA256. Place it in the disposable canonical candidate-2x path
`script/acceptance/presentation_ledger_developer/evidence/baseline2-all/media/jpeg.jpg`;
the matrix mounts that directory at `/qa-media`. Do not substitute an image
with the same dimensions. The progressive F17 input is separately committed in
`script/acceptance/presentation_ledger_developer/progressive_jpeg.json`.

Recover the Helm dependency without publishing chart packages:

```sh
helm repo add reportportal https://k8s.reportportal.io/
helm repo update reportportal
helm pull reportportal/reportportal --version 26.10.26 --destination "$CHART_SEED"
```

Use the pinned Linux ARM64 Helm binary. Verify `reportportal-26.10.26.tgz` is
236,682 bytes with SHA256
`399d95da23dcc6775acb5010f3f93b42f602ee75cecf7cce012a5d45fa9e0867`.
Stop on a mismatch; do not silently update the lock. Chart.lock records dependency
26.10.26 and lock digest
`sha256:73d08050c64fb31b1e1c9a93bbdc724af73ba440116ca23f90e0e9c85723850f`;
this lock digest is not the tgz checksum. Map `CHART_SEED` to the runner's recorded
host mount
`/private/tmp/ledger-final-matrix-20261031T063546Z-62ce39/M6-ruby34-cucumber12/source/helm/reportportal-rich-experience/charts`.
The legacy chart itself remains version 1.3.1/appVersion 26.0.7.

Only after setup and explicit authorization, use the central driver commands
`final_wp5_driver.rb matrix`, `live`, or `probes` in disposable canonical roots,
with a fresh `QA_WP5_STAMP` accepted by `final_wp5_context.rb` and never an
existing output directory. The context recognizes only its frozen head/stamp
mapping; an arbitrary new stamp is not currently supported. An authorized fresh
reproduction therefore needs either an empty disposable copy at the existing
stamp, clearly labelled as a separate run, or a separately reviewed context
extension. Do not change primary context here. Live execution also requires the
matching RP UI/server environment and Master-only secure environment injection;
this guide supplies no credentials and does not authorize new Launches.

## Publication Check

After primary QA finishes final reports, use the central curator's read-only
mode first, with the same performance override as the scorer:

```sh
QA_WP5_STAMP=wp5-ci-final-20261101 \
QA_WP5_PERF_STAMP=wp5-ci-final-20261101-quiet \
ruby "$QA2/spec/acceptance/ledger_qa/final_wp5_curate.rb" --check
```

It hashes bounded selected leaves and already tracked archive dependencies,
closes historical/current source and browser references, and writes nothing.
Inspect `provenance_only_paths`, `cross_qa_root_references`, and any missing roots
before calling a selection final. A missing planned/BLOCKED observation is
labelled as such, never substituted with another run or promoted to PASS.

Only when final reports are stable, omit `--check` and set an unused
`QA_MANIFEST_REVISION` such as `publication-review-1`. Creation is exclusive:
older manifests are never replaced. Both versions are preflighted before any
manifest write. No staging, commit or push is performed by this helper. Master
must separately check exact staged blob sizes (`git cat-file -s :PATH`), manifest
fingerprints, actual credentials, and current remote refs before any commit.
