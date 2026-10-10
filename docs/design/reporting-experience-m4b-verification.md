# M4-B Verification Record

Status: FOCUSED CLEAN-CANDIDATE GATE PASSED; MASTER ACCEPTANCE PENDING.

This records actual execution evidence for one clean candidate. It is not a
claim of full-suite completion, M4-C spool acceptance, live ReportPortal
certification, or release readiness. The candidate was exported from the M3
manifest using `tmp/m4a-20261010/export-clean-candidate.sh`; protected root
dependency/task manifests were not overlaid.

## Required Receipts

| Gate | State | Evidence |
| --- | --- | --- |
| Queue B cutoff, partial response, malformed/short response, zero timeout, repeated shutdown, monotonic deadline, bounded bookkeeping, failure isolation | Passed | Included in the 27-example focused run below |
| Tester-owned public formatter completion integration | Passed | Included in the 27-example focused run below |
| Tester-owned transport retry/deadline cases | Passed | Included in the 27-example focused run below |
| Historical API `log_batch` instrumentation and spool regression | Passed | `api_spec.rb` and `security_spool_spec.rb` in the focused run |
| Full regression suite | Pending | Clean candidate required |
| Source identity and candidate provenance audit | Passed | Candidate manifest and SHA-256 below |

## Executed Gate

Candidate: `/tmp/m4a-20261010-candidate.ncJi25`

Command targets:

```text
bundle exec rspec \
  spec/reportportal_cucumber/service/queue_processor_m4b_spec.rb \
  spec/reportportal_cucumber/cucumber/m4b_completion_integration_spec.rb \
  spec/reportportal_cucumber/transport/deadline_m4b_spec.rb \
  spec/reportportal_cucumber/reportportal/api_spec.rb \
  spec/reportportal_cucumber/service/security_spool_spec.rb
```

The command ran under a 90-second monotonic watchdog with stdout/stderr retained
at `/tmp/m4b-gate-ncJi25.log`. Result: exit 0; 27 examples, 0 failures; 31.73
seconds. No full-suite run was part of this B checkpoint.

## Source Identity

M3 base commit: `c9eacad5f1320e84f9660a413ef307d39f48d2de`.

Candidate source manifest:
`/tmp/m4a-20261010-candidate.ncJi25/tmp/m4a-20261010/candidate-source-manifest.json`

Manifest SHA-256: `7e69364b977b73f0a64ca0d80892ac81a3f8599c22313eebd1f0265a137f250f`.

Selected source SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `lib/reportportal_cucumber/service/queue_processor.rb` | `7de877aa4675ffb3106a3424318a910603a29d1987f25dbeaa46aff7585b625c` |
| `lib/reportportal_cucumber/service/delivery_receipt.rb` | `e2cf43166cf88f0085d0d907535b295d1f4d3930a4e8a33b80f078f1f5b0b904` |
| `lib/reportportal_cucumber/service/log_response_parser.rb` | `4ea7ea58524b39355c53f51634d0b4bfc0cdd53c661a12edf4de12f82e579998` |
| `lib/reportportal_cucumber/service/reporting_deadline.rb` | `9a55cf0e68ea7f29283e43460e230a2ba51f64066d0e94ccdbb3df96f774ff79` |
| `lib/reportportal_cucumber/reportportal/api.rb` | `b4e59c59f37dd44d5e3f9843ef1bc04ec2ad1a1fb2a93b8d8a3cec7b98bfc2fb` |
| `lib/reportportal_cucumber/transport/http_client.rb` | `01761db07ed2d6f1492b516ffb48806ce27a9ad78349bda9713e3fa7383a30dc` |
| `spec/reportportal_cucumber/service/queue_processor_m4b_spec.rb` | `d218d89a2f186ab8d2dace4203a93dd49b3a766f53c825f1e94482392918301a` |
| `spec/reportportal_cucumber/cucumber/m4b_completion_integration_spec.rb` | `f0c3f48d67451abd05bdc565527dc406a0f023b2ce8888710862c3b9decb1c9f` |
| `spec/reportportal_cucumber/transport/deadline_m4b_spec.rb` | `8be566f5c4b3219aa6b57f4caa52fbf00f56e27f41640ee2ea02bf23e3219673` |

The manifest records M3-derived protected hashes for `Gemfile.lock`, `Rakefile`,
`cucumber.yml`, and the gemspec. No live ReportPortal API/browser run is
included in M4-B; that remains M4-D.
