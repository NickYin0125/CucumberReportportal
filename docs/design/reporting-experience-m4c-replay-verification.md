# M4-C Replay Verification

Status: replay source is frozen and the focused candidate receipts are retained.
This is evidence for scoped Master review only; Core integration and important
fault tests remain pending.

## Frozen Candidate

- Candidate: `/tmp/m4-20261010-candidate-replay-final`
- Source manifest: `/tmp/m4-20261010-candidate-replay-final/tmp/m4-20261010/candidate-source-manifest.json`
- Manifest SHA-256: `d9b9768cfae26afb4d921b693cf091576fd77e3e4c61021127175158f7d58f67`
- The exporter verified the approved executable-only gemspec additions and
  recorded 125 source/documentation files. A post-test audit rechecked every
  manifest entry; all hashes matched.

The manifest carries hashes for the replay service, API wrapper, HTTP client,
CLI, README, and all three replay/API/CLI specs. Those paths in the candidate
are the exact sources used by both normal RSpec runs below.

| Candidate source path | SHA-256 |
| --- | --- |
| `lib/reportportal_cucumber/service/spool_store.rb` | `e3ef1a5fc2ed92158eb1c6af03e0f1a29ae23b93de0936596e6621fdb4489ab9` |
| `lib/reportportal_cucumber/service/spool_replay.rb` | `3907948099ba7252b6d380c141ba96727dec0560e40d9d0f904908c8943fc2bf` |
| `lib/reportportal_cucumber/reportportal/api.rb` | `69a44781fe0c1980bb6a223cfaeccd8f3e7f5205ce9de6584e5cc3a26535145f` |
| `lib/reportportal_cucumber/transport/http_client.rb` | `8e9ab28a9aeeda543da75f93fd04e2d0dc83d022069d8fcfd12a1178daf58c8a` |
| `exe/reportportal-spool` | `8bc6360f056aa3f38eb748eb7207a60bd67596e8530a797f770c59725d30addc` |
| `README.md` | `96d42448f6c257e77c9657254b4b519bd47f3b47c1d0692a65e2d311562c6736` |
| `spec/reportportal_cucumber/service/spool_replay_m4c_spec.rb` | `4c4c9cf8b8b24d47b9c10b1fa0674f64eb597db8e823b9b0c0a73bc9bb76e01e` |
| `spec/reportportal_cucumber/reportportal/spool_replay_api_spec.rb` | `7356ef75ac3859e2a7be7830103572090ca5d77153f2ce6d3ed1e8fedea0f4a6` |
| `spec/reportportal_cucumber/service/spool_replay_cli_integration_spec.rb` | `f3f520516d9f65c4360f1648bd8a80f9120ea91879785f39e1d6dd6be34584cb` |

Master's subsequent audit of 108 `lib/`, `spec/`, and `exe/` files found only
Queue changed after this candidate; replay, Store, API, and executable sources
matched the scoped candidate. The receipts below therefore remain source-bound
for the replay-owned files.

## Receipts

Normal RSpec with the candidate's ordinary `spec_helper` and the guarded
support glob, replay/API/CLI only: **22 examples, 0 failures, exit 0**.

- Output: `/tmp/m4-20261010-candidate-replay-final/tmp/m4-20261010/c-replay/20261010T220100Z-normal-focused/output.log`
- Command: sibling `command.txt`
- Exit status: sibling `exit-status.txt`
- Manifest digest receipt: sibling `source-manifest.sha256`
- Output SHA-256: `5ebd9151b0e19067580002653b0e74bbe54ec460d61c0f9e01dba1db355b0e5b`

Normal RSpec for all focused C specs (configuration, Store, replay, API, and
CLI) on the same candidate: **31 examples, 0 failures, exit 0**.

- Output: `/tmp/m4-20261010-candidate-replay-final/tmp/m4-20261010/c-replay/20261010T220400Z-c-all-focused/output.log`
- Command: sibling `command.txt`
- Exit status: sibling `exit-status.txt`
- Manifest digest receipt: sibling `source-manifest.sha256`
- Output SHA-256: `b6f692f9c919a9edf8a289f8957b19e7c2e8e90e8199b2e9acccd4b455aca280`
- Exit status: `0`

Coverage added for final replay semantics includes two real-Store entries
confirmed before a second execute against closed-target stubs; resume makes no
GET or POST and exits successfully. The service specs also verify zero timeout
refuses before Store load and a positive timeout bounds initial transaction
validation. No network request escaped WebMock in the tests.

## Earlier Source Run

The earlier **19 examples, 0 failures** result was run against the source
workspace with an isolated RSpec bootstrap that bypassed `spec_helper`'s then
unguarded installed-consumer support file. Its console output is retained in
the task transcript, but that run wrote no output log or source manifest. Its
source path was `/Users/nick/Documents/New project`; no honest manifest SHA can
be assigned retroactively. It is superseded by the normal-helper candidate
receipts above; do not use it as the scoped candidate receipt.

The all-focused result is not C acceptance. Core integration and important
fault tests remain pending for Master's coherent Core gate. No full-regression,
installed-gem consumer, or live ReportPortal result is claimed here. The
aggregate M4-C verification document remains Master-owned.
