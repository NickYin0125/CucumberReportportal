# M4-C Persistence Verification

Status: bounded persistence/core gate recorded; this is not whole-M4 acceptance.

## Final Candidate Receipt

- Candidate: `/tmp/m4a-20261010-candidate.ZKjhM0`
- Export base: `c9eacad5f1320e84f9660a413ef307d39f48d2de`
- Source manifest SHA-256: `d504ba2c807796f87b4cffb2275079edbc83b12b5b8e9abedf6580334aa1016e`
- Manifest: `/tmp/m4a-20261010-candidate.ZKjhM0/tmp/m4a-20261010/candidate-source-manifest.json`
- Command: `perl -e 'alarm 180; exec @ARGV' /opt/homebrew/opt/ruby/bin/bundle exec /opt/homebrew/opt/ruby/bin/ruby -S rspec spec/reportportal_cucumber/config_m4a_spec.rb spec/reportportal_cucumber/config_m4c_spec.rb spec/reportportal_cucumber/service/spool_store_m4c_spec.rb spec/reportportal_cucumber/service/spool_replay_m4c_spec.rb spec/reportportal_cucumber/reportportal/spool_replay_api_spec.rb spec/reportportal_cucumber/service/queue_processor_m4a_spec.rb spec/reportportal_cucumber/service/queue_processor_m4b_spec.rb spec/reportportal_cucumber/cucumber/m4a_public_delivery_integration_spec.rb spec/reportportal_cucumber/cucumber/m4b_completion_integration_spec.rb spec/reportportal_cucumber/transport/deadline_m4b_spec.rb spec/reportportal_cucumber/service/security_spool_spec.rb spec/reportportal_cucumber/runtime/log_buffer_spec.rb spec/reportportal_cucumber/cucumber/formatter_spec.rb`
- Result: `101 examples, 0 failures`, finished in 33.28 seconds; the external harness alarm was 180 seconds.
- Coverage included Store/config/replay service and API, M4-A/B queue and integration/deadline specs, historical security spool and runtime log-buffer specs, and formatter specs including strict manual-step exception preservation.

## Source Identity

Candidate SHA-256 values:

- `lib/reportportal_cucumber/cucumber/formatter.rb`: `3f944e79afc741e2c8aac6aaaad85f061530414fcdd0bb005c9a90c2b5f60201`
- `lib/reportportal_cucumber/service/queue_processor.rb`: `e4745b4143285ffa232434f8cd4eee2eb6ee9c288173e1ca5662c35b58546530`
- `lib/reportportal_cucumber/service/spool_store.rb`: `80ce1047d00e347eb3bb7f482b7731ec8b3dc9dfe125de4ca70ba5a6dbea5ae5`
- `lib/reportportal_cucumber/config.rb`: `a899d113caf8898a4c24fdd576b737af39817c12e5ec975f9467c3b19c96d828`
- `lib/reportportal_cucumber.rb`: `0488ad6afbe4256b2c34c0b885ef906ccaa48dc7c5f29ae919f7c53476e042bd`
- `spec/reportportal_cucumber/cucumber/formatter_spec.rb`: `9643fffa09c6d50b7006f63c38e40382c20527c6bac082f3f76635e9dfc1cbdd`
- `spec/reportportal_cucumber/config_m4c_spec.rb`: `6f654b86c68ec71e251bb9e9a4e338cdc02be1fbecee042ac98293c8b91739ce`
- `spec/reportportal_cucumber/service/spool_store_m4c_spec.rb`: `1562a3250749e4898628b1c9489fb2d7a8ed1cf580d696a2603ea4e73930f84d`

## Public Contract

- `Service::SpoolStore.new(config:)` exposes `persist(entries:, files:, outcome:, diagnostics: {}, deadline: nil)`, `transactions`, `load_transaction(id:)`, `with_transaction(id:, deadline: nil)`, and `update_checkpoint(id:, states:, deadline: nil)`.
- `Service::QueueProcessor` exposes `flush_receipt(timeout:, deadline:)`, `shutdown_receipt(timeout:, deadline:)`, and `reporting_receipt(...)`; the legacy `flush` and `shutdown` Boolean results continue to mean local settlement only.
- `Cucumber::Formatter#reporting_receipt` exposes the whole-run receipt. Final incomplete reporting warns with bounded sanitized counters while preserving business outcomes if either the reporting operation or warning logger fails.

## Scope And Remaining Gates

The clean-candidate exporter overlays `lib/`, `spec/`, and README files, but not the separately owned `exe/` directory. An initial attempt including `spool_replay_cli_integration_spec.rb` therefore produced three harness `LoadError`s for missing `exe/reportportal-spool`; those are not counted as product assertions or in the 101-example result. The CLI executable integration spec remains outside this candidate receipt.

Earlier M4-B queue diagnostic receipts, all superseded and not PASS evidence:

- `/tmp/m4a-20261010-candidate.tIQI3J`, manifest SHA-256 `e56a987ca2b7e69e43c4476e90e1457f46f9dd58230f65fa16254652991ef5e4`: `41 examples, 5 failures` (control timeout double-count, fatal-worker charge accounting, adapter deadline signature, and two raw-spool fallback cases).
- `/tmp/m4a-20261010-candidate.Ut1QO2`, manifest SHA-256 `93e10fab1bdc6f38facca9c3b5950184a51b7c4d8494b07bc18cebdf8d38b676`: `41 examples, 3 failures` (worker reservation and raw fallback/zero-shutdown fallback mechanics).
- `/tmp/m4a-20261010-candidate.eNoP1r`, manifest SHA-256 `b3310782d14c9102435ce491e6db896d2b5e1bc74262497689dddf26bef2b7de`: `50 examples, 2 failures` (legacy log-buffer spy calls and raw attachment metadata/path expectations).
- `/tmp/m4a-20261010-candidate.atBgRn`: `50 examples, 1 failure` (runtime LogBuffer test double did not capture calls because the wrapper passed a keyword deadline); its manifest digest was not recorded.

This gate does not claim full-suite, whole-M4, installed-gem, or release acceptance. Independent final integration and Master source review remain separate gates.
