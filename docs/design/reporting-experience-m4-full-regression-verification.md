# M4 Full Regression Verification

Status: FINAL COMBINED IQ5/IQ6 AUTOMATED, INSTALLED AND LIVE API GATES PASS.
Master relayed Sol's final SCOPED PASS: final-installed 50/0, IQ1-IQ6 closed,
and his own read-only launch 47 API/UI reconciliation complete.
All results below were actually executed after both diagnostic freezes and the
IQ6 Replay/README freeze. Earlier candidates remain historical receipts, not
the final package. Master reported successful launch 47 statistics, PASSED
filtering, table/JSON/PNG, native PNG-preview, original replay action and original
failed-business browser checks. Browser and independent-review results are
attributed external evidence, not sidecar-performed reviews; no independent
journey remains pending in this handoff. Additional native CI passed 1 scenario /
3 steps, exit 0, with the expected legacy stub warning retained, not a claim
of complete RP delivery from that fixture. Master owns the final overview,
C aggregate, Git commit and tag. The tester is finished; no commit or tag was made.

## Final Combined Artifact

Candidate `/tmp/m4-20261010-candidate.30uRDE`.
Manifest `/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/candidate-source-manifest.json`,
SHA-256 `49607259f627ca6818c37e863ed4bc55a38ab271102a62818cd605135b8c2357`.
All 146 candidate entries passed the initial audit and the post-live audit.
All 131 non-document workspace files matched exactly. Master independently
reported the same zero-mismatch comparison. Final verification documents are
post-run outputs; no frozen candidate file or receipt was overwritten.

Package:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/gates/20261010T151830Z-12049/installed-package/reportportal-cucumber-ruby.gem`.
SHA-256 `20a537c3cf708c0bf37191a3759fc962f2b9ce5b64c39c259c95a3ae31e0552e`.
This exact artifact was supplied to Master for Sol's independent verification.
It includes the final Config, Store, CLI and Replay diagnostics; the package's
35 library sources, executable and actual loaded SDK/alias paths match the
frozen manifest under the installed root. No global gem was changed.

```sh
M4_C_D_STABILIZED=1 M4_GATE_TIMEOUT_SECONDS=240 \
  bash tmp/m4-20261010/run-gates.sh \
  /tmp/m4-20261010-candidate.30uRDE core security installed full seed m2m3
```

| Gate | Actual Result | Exit |
| --- | --- | --- |
| C/B/D core plus replay API/CLI and IQ5/IQ6 diagnostics | 211 examples, 0 failures (49.83s) | 0 |
| Historical security/native privacy | 89 examples, 0 failures (3.90s) | 0 |
| Actual installed consumer | JSON/PNG, three physical POSTs, UUID/checkpoint/resume PASS | 0 |
| Installed all-library provenance | 35 libraries including two compatibility aliases PASS | 0 |
| Named M2/M3 | 80 examples, 0 failures (11.05s) | 0 |
| Full | 507 examples, 0 failures (66.19s) | 0 |
| Seed 20261010 | 507 examples, 0 failures (66.72s) | 0 |
| Native default-profile Cucumber CI smoke | 1 scenario / 3 steps, all passed | 0 |

Aggregate exit 0. Evidence:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/gates/20261010T151830Z-12049/`.
Matrix gates had a finite 240-second outer limit. Runtime: Ruby 3.4.2,
Bundler 2.6.6, native Cucumber 10.2.0. No native Cucumber 9 PASS is claimed.
Actual consumer execution clears stale Ruby/Bundler/RP state, runs outside the
source cwd, and verifies every loaded SDK path rather than trusting only gem
metadata or CLI help. Its mock POST sequence is JSON 200, PNG 503, then the
same PNG 200 after explicit duplicate opt-in; confirmed JSON is never resent.

Additional native CI-style gate executed the exact default-profile command
`bundle _2.6.6_ exec cucumber` from this candidate, with all inherited `RP_*`
unset and a 180-second outer watchdog. Actual result: 1 scenario passed,
3 steps passed, exit 0 (0.74s process elapsed; 0.050s Cucumber-reported).
Unique command/output/exit/input-hash receipts:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/native-default-ci-20261010T152705Z-14652/`.
Candidate cucumber.yml SHA remains the M3 value
`3abbe0bf2c241fd8f0694ec7c7088f1ce06486479b46aad0b244df15eca48428`.
All 14 native input hashes match the M3 commit exactly (`m3-input-audit.json`).
No live feature, duration overlay, new code or changed assertion was used.
The legacy formatter-contract mock log response is `responses:[{message:ok}]`
without an acknowledgement ID. The retained output therefore truthfully warns
confirmed 0 / spooled 1 / pending 0 / reporting incomplete. This smoke proves
native scenario/call-sequence compatibility, not remote delivery confirmation;
actual acknowledgement/bytes acceptance is supplied by the installed and live gates.

Existing localhost ReportPortal was healthy (all running pods Ready, migrations
Succeeded; health and UI HTTP 200). New launch
[47](http://localhost/ui/#superadmin_personal/launches/all/47), UUID
`41b91550-97b8-4f73-81a4-2b20489f8ae4`, is deliberately FAILED: total 3 / passed 2 /
failed 1, exact 14 items / 9 logs. Two actual native scenarios preserved the
deliberate business exit 1. All nine acknowledgement UUID GETs matched numeric
logs 382 through 390. Data 19/20/21 downloaded as image/png, 327 bytes each,
SHA `5b7a247dac8fc35737fe3485fd1242dfe15e9505f6b8eaba12c6065a85a4a5d2`.
Open-original-target replay confirmed 2; completed resume exited 0/no HTTP;
new unconfirmed closed-target replay exited 2/no POST/unchanged checkpoint.

Live receipt:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/live/run-20261010T152208Z-13322/receipt.json`.
Exact API reconciliation (15 read-only GETs, all HTTP 200):
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/live/run-20261010T152208Z-13322/api-reconcile-20261010T152214Z-13356/receipt.json`.
Health and post-live source/protected provenance receipts:
`/tmp/m4-20261010-candidate.30uRDE/tmp/m4-20261010/final-health/`.
Protected candidate hashes retain the M3 baseline shown below, except only the
two approved executable-packaging lines; protected dirty workspace hashes
remain unchanged. No service teardown, credential mutation, new infrastructure,
video recording, production edit, commit or tag was performed by this tester.

## IQ5 Matrix (Pre-IQ6)

Candidate `/tmp/m4-20261010-candidate.n3saaM`, manifest SHA-256
`a8b25e9c9b4dfeb7cc742f379abea7ec820c476ab81332cde2692444c640eb44`.
The audit verified all 145 source entries and protected candidate hashes.
Core 201/0, security 89/0, installed actual consumer and all-library audit PASS,
named M2/M3 80/0, full 497/0 (64.3s), and seed 20261010 497/0; every gate
and the aggregate runner exited 0. Each gate had a 240-second outer limit.
Evidence: `/tmp/m4-20261010-candidate.n3saaM/tmp/m4-20261010/gates/20261010T151104Z-9515/`.
No live launch was created for this intermediate candidate after Master's IQ6
hold. Final combined regression, package and live proof must use a new export.

## Pre-IQ5 Artifact

Candidate `/tmp/m4-20261010-candidate.wGrvJf`, manifest SHA-256
`83c33df5cf5a0ac1329f33a904e9b20322a3a53e580e2221f61926c6fd812225`.
Its source audit covered all 143 files before execution. A final comparison
against the workspace found zero differences in all 127 lib/spec/exe/example
files. The final verification documents are generated afterwards; the frozen
candidate and older receipts have not been overwritten.

Package:
`/tmp/m4-20261010-candidate.wGrvJf/tmp/m4-20261010/gates/20261010T145527Z-4150/installed-package/reportportal-cucumber-ruby.gem`.
SHA-256 `55808c8882864ace4d963fe34c961afbdc6e71b10a613e2418be007014a7d1e1`.
This pre-IQ5 package contains the corrected `--no-profile` live runner and valid
shared PNG helper, not the superseded examples in `LF0BhD` or `ZFBoP9`.

## Pre-IQ5 Executed Gates

```sh
M4_C_D_STABILIZED=1 M4_GATE_TIMEOUT_SECONDS=240 \
  bash tmp/m4-20261010/run-gates.sh \
  /tmp/m4-20261010-candidate.wGrvJf core security installed full seed m2m3
```

| Gate | Result | Exit |
| --- | --- | --- |
| C/B/D core and replay API/CLI | 170 examples, 0 failures | 0 |
| Historical security/native privacy | 89 examples, 0 failures | 0 |
| Installed consumer | Actual requests, UUIDs, bytes, checkpoints/resume PASS | 0 |
| Installed all-library audit | 35 libraries including 2 aliases PASS | 0 |
| Full | 466 examples, 0 failures (57.54s) | 0 |
| Seed 20261010 | 466 examples, 0 failures | 0 |
| Named M2/M3 | 80 examples, 0 failures | 0 |

Aggregate gate exit 0. Evidence directory:
`/tmp/m4-20261010-candidate.wGrvJf/tmp/m4-20261010/gates/20261010T145527Z-4150/`.
Receipts include commands, outputs, individual exits, source/runtime audits,
manifest SHA, tooling SHA, package SHA and actual installed-consumer evidence.
Runtime: Ruby 3.4.2, Bundler 2.6.6, native Cucumber 10.2.0. No native 9 PASS.

The consumer runs outside any source cwd with Ruby/Bundler state cleared,
activates the selected installed package before Cucumber, and retains strict
actual `$LOADED_FEATURES` path/hash checks. It invokes installed help,
no-network dry-run, closed-target refusal, faulted JSON/PNG replay and resume.
Exactly three physical mock POSTs return 200/503/200; JSON is confirmed once,
PNG retains its original bytes/UUIDs and retries only after explicit opt-in.
All 35 installed libraries and the CLI source match the frozen manifest;
normal requires of the guarded support file do not execute/exit/network.

## Shared Protected Baseline And Pre-IQ5 Live

Detailed D/SIGINT, earlier red receipts, exact production source hashes, live
UUIDs/numeric IDs and downloaded attachment evidence are in
`reporting-experience-m4d-verification.md`.

The exporter starts from M3 commit
`c9eacad5f1320e84f9660a413ef307d39f48d2de`, overlays lib/spec/README/M4 docs,
exe, and only `examples/m4_delivery_acceptance/`. Candidate Gemfile.lock,
Rakefile and cucumber.yml retain their base hashes. The candidate gemspec contains
only the two approved executable-packaging additions over M3, excluding all four
unrelated development dependencies. Each manifest retains the protected base
and candidate SHA-256 values plus every allowlisted source/example hash.

Candidate Gemfile.lock SHA is
`dcf22fbb18ce883239be2ebec9432e2e1b33cc6c8f1b34f365e57125d2da4b11`;
Rakefile `13c9de0560d2d515c2b3f99d7f5df428417beef28f62c11ba4a963b35819752c`;
cucumber.yml `3abbe0bf2c241fd8f0694ec7c7088f1ce06486479b46aad0b244df15eca48428`.
These equal the M3 base. Base gemspec SHA
`e597f10c2a4119e57ae512901fbc25407b6f720ef88bafce4ba3401ac45b1b81` becomes
`b83529d64dd80263b373084e84fee8bd9b6bbb369d94c518c2a5d8eb4d0e8bbf`
only for the two approved executable packaging lines. Four unrelated dirty
development dependencies and duration work are absent from the candidate.
The sidecar never edited the dirty workspace's protected files.

Existing localhost ReportPortal live launch
[46](http://localhost/ui/#superadmin_personal/launches/all/46) is deliberately
FAILED: total 3 / passed 2 / failed 1, exact 14 items / 9 logs. All nine real
acknowledgement UUID lookups returned HTTP 200 and matched their numeric log
rows 373 through 381. PNG data 16/17/18 each downloaded as image/png, 327 bytes,
SHA `5b7a247dac8fc35737fe3485fd1242dfe15e9505f6b8eaba12c6065a85a4a5d2`.
Original open-target replay confirms 2; completed resume exits 0/no HTTP;
new unconfirmed closed-target replay exits 2/no POST/unchanged checkpoint.
The two actual native scenarios preserve the intentional business exit 1.
No service teardown, new infrastructure, credential mutation or video recording.
